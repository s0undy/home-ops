terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "3.6.4"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.2.0"
    }
  }
}

provider "minio" {
  // required
  minio_server   = data.sops_file.minio_secrets.data["minio_server"]
  minio_user     = data.sops_file.minio_secrets.data["minio_user"]
  minio_password = data.sops_file.minio_secrets.data["minio_password"]
  minio_ssl      = true
}
