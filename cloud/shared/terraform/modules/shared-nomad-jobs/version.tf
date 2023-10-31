terraform {
  required_version = ">= 0.13"
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = ">= 2.0"
    }
  }
}
