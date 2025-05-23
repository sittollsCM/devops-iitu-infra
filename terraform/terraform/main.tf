provider "libvirt" {
  uri = "qemu+ssh://ubuntu@server/system"
}

locals {
  total_nodes = var.master_count + var.worker_count

  node_ips = concat(
    [for i in range(var.master_count) : "192.168.100.${(i+1)*10}"], # 10, 20, 30
    [for i in range(var.worker_count) : "192.168.100.${10 + i + 1}"] # 11, 12, 13
  )

  node_hostnames = concat(
    [for i in range(var.master_count) : "master-${i + 1}"],
    [for i in range(var.worker_count) : "worker-${i + 1}"]
  )
}

resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  
  target {
    path = "/var/lib/libvirt/images"
  }
}

resource "libvirt_network" "k8s" {
  name      = "k8s-network"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["192.168.100.0/24"]
  dhcp {
    enabled = false
  }
  autostart = true	
}

resource "libvirt_volume" "vm_disk" {
  count  = local.total_nodes
  name   = "k8s-node-${count.index}.qcow2"
  base_volume_id = libvirt_volume.base.id
  pool   = libvirt_pool.default.name
  format = "qcow2"
  size	 = 20 * 1024 * 1024 * 1024
}

resource "null_resource" "patch_disk" {
  count      = local.total_nodes

  provisioner "remote-exec" {
    inline = [
      "sudo virt-customize -a /var/lib/libvirt/images/${libvirt_volume.vm_disk[count.index].name} \\",
      "  --run-command 'systemctl mask systemd-networkd-wait-online.service' \\",
      "  --run-command 'systemctl mask NetworkManager-wait-online.service'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "server"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  depends_on = [libvirt_volume.vm_disk]
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-base.qcow2"
  source = var.image_path
  pool   = libvirt_pool.default.name
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  count     = local.total_nodes
  name      = "cloudinit-${count.index}.iso"
  pool      = libvirt_pool.default.name
  user_data = data.template_file.user_data[count.index].rendered
  network_config = data.template_file.network_config[count.index].rendered
}

data "template_file" "user_data" {
  count    = local.total_nodes
  template = file("${path.module}/cloud-init/user_data.yaml")
  vars = {
    hostname = "${local.node_hostnames[count.index]}"
    ssh_key  = file("~/.ssh/id_rsa.pub")
    hosts_string = join("\n", [for i in range(local.total_nodes) :
      "${local.node_ips[i]} ${local.node_hostnames[i]}"
    ])
  }
}

data "template_file" "network_config" {
  count    = local.total_nodes
  template = file("${path.module}/cloud-init/network_config.yaml")
  vars = {
    ip = local.node_ips[count.index]
  }
}

resource "libvirt_domain" "vm" {
  count = local.total_nodes
  name  = "${local.node_hostnames[count.index]}"
  memory = 2048
  vcpu   = 2

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  network_interface {
    network_id   = libvirt_network.k8s.id
    wait_for_lease = false
  }
  
  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit[count.index].id
  depends_on = [null_resource.patch_disk]
}

output "vm_ips" {
  value = {
    #masters = slice(libvirt_domain.vm[*].network_interface[0].addresses[0], 0, var.master_count)
    masters = slice(local.node_ips, 0, var.master_count)
    #workers = slice(libvirt_domain.vm[*].network_interface[0].addresses[0], var.master_count, local.total_nodes)
    workers = slice(local.node_ips, var.master_count, local.total_nodes)
  }
}
