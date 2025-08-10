terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
      version = "3.5.3"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.2.1"
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
