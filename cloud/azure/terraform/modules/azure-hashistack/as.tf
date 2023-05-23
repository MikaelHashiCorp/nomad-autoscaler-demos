resource "azurerm_availability_set" "hashistack" {
  name                = "availability-set"
  resource_group_name = azurerm_resource_group.hashistack.name
  location            = azurerm_resource_group.hashistack.location
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
}