terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  folder_id = local.folder-id
  cloud_id  = local.cloud-id
  token     = local.token
}
provider "random" {
}
provider "tls" {
}
provider "local" {
}