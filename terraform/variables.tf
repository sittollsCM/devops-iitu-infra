variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 2
}

variable "image_path" {
  description	=	"Path to the cloud image Ubuntu 22.04"
  default		=	"cloud-images.ubuntu.com/releases/jammy/release-20250327/ubuntu-22.04-server-cloudimg-amd64.img"
}

variable "ssh_username" {
  description	=	"the ssh username to use"
  default		=	"ubuntu"
}

variable "ssh_private_key" {
  description	=	"the private ssh key to use"
  default		=	"~/.ssh/id_rsa"
}
