# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "random_pet" "server" {}

resource "azurerm_resource_group" "hashistack" {
  name     = "hcs-autosc-main-mws-${random_pet.server.id}"
  location = var.location
}
