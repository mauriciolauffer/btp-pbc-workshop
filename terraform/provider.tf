terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~>1.9.0"
    }
  }
}

provider "btp" {
  globalaccount = var.globalaccount_id
  // username      = var.btp_username
  // password      = var.btp_password
}
