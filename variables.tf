variable "yandex_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yandex_folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "zone" {
  description = "Zone"
  type        = string
  default     = "ru-central1-a"
}

variable "vm_count" {
  description = "Number of VMs"
  type        = number
  default     = 2
}

variable "image_id" {
  description = "Image ID for VMs"
  type        = string
  default     = "fd81hgrcv6lsnkremf32" # Ubuntu 20.04, уточните актуальный!
}

variable "vm_user" {
  description = "Username for SSH access"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "yandex_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}