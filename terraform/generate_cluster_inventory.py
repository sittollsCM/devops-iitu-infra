import json

with open("terraform/terraform.tfstate") as f:
    tfstate = json.load(f)

outputs = tfstate.get("outputs", {})
masters = outputs.get("vm_ips", {}).get("value", {}).get("masters", [])
workers = outputs.get("vm_ips", {}).get("value", {}).get("workers", [])

with open("ansible/inventory/cluster/hosts.ini", "w") as f:
    f.write("[master]\n")
    for ip in masters:
        f.write(f"{ip} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=ubuntu@server'\n")

    f.write("\n[workers]\n")
    for ip in workers:
        f.write(f"{ip} ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=ubuntu@server'\n")

    f.write("\n[all:vars]\nansible_ssh_private_key_file=~/.ssh/id_rsa\n")

