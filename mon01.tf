
resource "proxmox_virtual_environment_vm" "ubuntu_vm3" {
  name      = "mon01"
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
    dedicated = 4096
  }

  disk {
    datastore_id = local.vm_storage_pool
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 200
  }

  initialization {
    user_account {
      username = "ubuntu"
      keys     = [trimspace(data.local_file.ssh_public_key.content)]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.54/24"
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
