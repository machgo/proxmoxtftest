terraform {
  required_version = ">= 1.1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.93.0"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://proxmox2.balou.in:8006/"
  api_token = "terraform-prov@pve!mytoken=41ba7bfc-1af4-48d5-8140-2486436711e8"
  insecure  = true
}


locals {
  vm_name          = "awesome-vm"
  pve_node         = "proxmox2"
  vm_storage_pool  = "zfs1"
  iso_storage_pool = "local"
}

data "local_file" "ssh_public_key" {
  filename = "./id_rsa.pub"
}


resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = "app01"
  node_name = local.pve_node

  agent {
    enabled = true
    timeout = "1m"
    wait_for_ip {
      ipv4 = false
      ipv6 = false
    }
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = local.vm_storage_pool
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  initialization {
    user_account {
      username = "ubuntu"
      keys     = [trimspace(data.local_file.ssh_public_key.content)]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.52/24"
        gateway = "192.168.0.1"
      }
    }
    dns {
      servers = ["192.168.0.1"]
    }
  }

  network_device {
    bridge = "vmbr0"
  }

}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = local.iso_storage_pool
  node_name    = local.pve_node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  # need to rename the file to *.qcow2 to indicate the actual file format for import
  file_name = "noble-server-cloudimg-amd64.qcow2"
}

