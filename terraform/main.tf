resource "yandex_compute_disk" "boot_disk" {
  name     = "boot-disk"
  image_id = "fd8079v2kd3a5h10ba5k"
  zone     = "ru-central1-d"
  size     = "20"
}

resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "subnet"
  network_id     = yandex_vpc_network.network.id
  zone           = "ru-central1-d"
  v4_cidr_blocks = ["192.168.100.0/24"]
}

resource "yandex_compute_instance" "vm" {
  name        = "vm"
  zone        = "ru-central1-d"
  platform_id = "standard-v3"
  resources {
    cores  = 2
    memory = 4
  }
  network_interface {
    nat       = true
    subnet_id = yandex_vpc_subnet.subnet.id
  }
  boot_disk {
    disk_id = yandex_compute_disk.boot_disk.id
  }
  metadata = {
    ssh-keys = "almalinux:${tls_private_key.ssh_keys.public_key_openssh}"
  }
}

resource "tls_private_key" "ssh_keys" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "${local.key_dir}/${local.key_name}"
  content         = tls_private_key.ssh_keys.private_key_openssh
  file_permission = 600
}

resource "local_file" "ansible_inventory" {
  filename   = "${path.module}/../ansible/inventory.ini"
  content    = <<EOT
almalinux ansible_host=${yandex_compute_instance.vm.network_interface.0.nat_ip_address} ansible_user=almalinux ansible_ssh_private_key_file=${local.key_dir}${local.key_name}
  EOT
  depends_on = [yandex_compute_instance.vm]
}