terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = var.zone
  token     = var.yandex_token
}

# Создаем сеть
resource "yandex_vpc_network" "network" {
  name = "load-balancer-network"
}

# Создаем подсеть
resource "yandex_vpc_subnet" "subnet" {
  name           = "load-balancer-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Группа безопасности для ВМ
resource "yandex_vpc_security_group" "vm-sg" {
  name       = "vm-security-group"
  network_id = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Группа безопасности для балансировщика
resource "yandex_vpc_security_group" "lb-sg" {
  name       = "load-balancer-sg"
  network_id = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Локальная переменная с расширенным путем
locals {
  ssh_key_content = file(pathexpand(var.ssh_public_key_path))
}

# Создаем 2 идентичные виртуальные машины
resource "yandex_compute_instance" "web_server" {
  count    = var.vm_count
  name     = "web-server-${count.index + 1}"
  hostname = "web-server-${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    ip_address         = "192.168.10.${10 + count.index}"
    security_group_ids = [yandex_vpc_security_group.vm-sg.id]
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${local.ssh_key_content}"
    user-data = <<-EOF
      #cloud-config
      packages:
        - nginx
      runcmd:
        - systemctl enable nginx
        - systemctl start nginx
        - echo "<h1>Server ${count.index + 1}</h1>" > /var/www/html/index.html
    EOF
  }
}

# Создаем таргет-группу
resource "yandex_lb_target_group" "web_target_group" {
  name      = "web-target-group"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.web_server
    content {
      subnet_id = yandex_vpc_subnet.subnet.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# Создаем сетевой балансировщик нагрузки
resource "yandex_lb_network_load_balancer" "web_balancer" {
  name = "web-balancer"
  type = "external"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_target_group.id

    healthcheck {
      name = "http-healthcheck"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
    }
  }
}