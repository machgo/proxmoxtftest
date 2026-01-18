terraform {
  required_version = ">= 1.1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "= 3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://proxmox2.balou.in:8006/api2/json"
  pm_api_token_id     = "terraform-prov@pve!mytoken"
  pm_api_token_secret = "41ba7bfc-1af4-48d5-8140-2486436711e8"
  pm_tls_insecure     = true
}

locals {
  vm_name          = "awesome-vm"
  pve_node         = "proxmox2"
  vm_storage_pool  = "zfs1"
  iso_storage_pool = "local"
}

resource "proxmox_vm_qemu" "cloudinit-example" {
  name        = local.vm_name
  target_node = local.pve_node
  agent       = 1
  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }
  memory           = 1024
  boot             = "order=scsi0"                 # has to be the same as the OS disk of the template
  clone            = "noble-server-cloudimg-amd64" # The name of the template
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true
  bios             = "seabios"

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = local.vm_storage_pool
          size    = "80G"
        }
      }
      scsi1 {
        cdrom {
          iso = proxmox_cloud_init_disk.ci.id
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = local.vm_storage_pool
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}


resource "proxmox_cloud_init_disk" "ci" {
  name     = local.vm_name
  pve_node = local.pve_node
  storage  = local.iso_storage_pool

  meta_data = yamlencode({
    instance_id    = sha1(local.vm_name)
    local-hostname = local.vm_name
  })

  user_data = <<-EOT
  #cloud-config
  users:
    - default
  chpasswd:
    expire: false
    users:
    - {name: default, password: default, type: text}
  ssh_pwauth: true
  EOT

  network_config = yamlencode({
    version = 1
    config = [{
      type = "physical"
      name = "eth0"
      subnets = [{
        type    = "static"
        address = "192.168.0.52/24"
        gateway = "192.168.0.1"
        dns_nameservers = [
          "192.168.0.1"
        ]
      }]
    }]
  })
}
