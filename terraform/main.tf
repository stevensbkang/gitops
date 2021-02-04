##################################################################################
# PROVIDERS
##################################################################################

provider azurerm {
  version = "=2.21.0"
  features {}
}

provider azuread {
  version = "=1.0.0"
}

##################################################################################
# DATA
##################################################################################

data "azurerm_container_registry" "container_registry" {
  name                = var.container_registry_name
  resource_group_name = var.container_registry_resource_group_name
}

data "azuread_group" "aad_aks_admin_group" {
  name = var.azure_ad_aks_admin_group
}

##################################################################################
# RESOURCES
##################################################################################

resource "azurerm_resource_group" "kubernetes_resource_group" {
  name     = var.kubernetes_resource_group
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "storage_account" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.kubernetes_resource_group.name
  location                 = azurerm_resource_group.kubernetes_resource_group.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  account_kind             = var.storage_account_kind

  tags = var.tags
}

resource "azurerm_storage_container" "storage_account_container" {
  name                  = var.storage_account_container_name
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = var.storage_account_container_type
}

resource "azurerm_virtual_network" "kubernetes_virtual_network" {
  name                = var.kubernetes_virtual_network_name
  location            = var.location
  resource_group_name = azurerm_resource_group.kubernetes_resource_group.name
  address_space = [
    var.kubernetes_virtual_network_cidr
  ]

  tags = var.tags
}

resource "azurerm_subnet" "kubernetes_virtual_network_subnet" {
  name                 = var.kubernetes_virtual_network_subnet_name
  resource_group_name  = azurerm_resource_group.kubernetes_resource_group.name
  virtual_network_name = azurerm_virtual_network.kubernetes_virtual_network.name
  address_prefixes = [
    var.kubernetes_virtual_network_subnet_cidr
  ]
}

resource "azurerm_network_security_group" "kubernetes_subnet_network_security_group" {
  name                = var.network_security_group_name
  location            = var.location
  resource_group_name = azurerm_resource_group.kubernetes_resource_group.name

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg_association" {
  subnet_id                 = azurerm_subnet.kubernetes_virtual_network_subnet.id
  network_security_group_id = azurerm_network_security_group.kubernetes_subnet_network_security_group.id
}

resource "azurerm_kubernetes_cluster" "aks" {

  name                = var.kubernetes_cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.kubernetes_resource_group.name
  dns_prefix          = var.kubernetes_cluster_name

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true

    azure_active_directory {
      managed = true
      admin_group_object_ids = [
        data.azuread_group.aad_aks_admin_group.id
      ]
    }
  }

  kubernetes_version = var.kubernetes_version

  private_cluster_enabled = var.kubernetes_private_cluster_enabled

  api_server_authorized_ip_ranges = var.kubernetes_api_server_authorized_ip_ranges

  default_node_pool {
    name                 = var.kubernetes_default_node_pool_name
    type                 = var.kubernetes_default_node_pool_type
    node_count           = var.kubernetes_default_node_pool_count
    vm_size              = var.kubernetes_default_node_pool_vm_size
    vnet_subnet_id       = azurerm_subnet.kubernetes_virtual_network_subnet.id
    max_pods             = var.kubernetes_default_node_pool_max_pods
    node_labels          = var.kubernetes_default_node_pool_labels
    orchestrator_version = var.kubernetes_version
  }

  network_profile {
    network_plugin     = var.kubernetes_network_plugin
    network_policy     = var.kubernetes_network_policy
    dns_service_ip     = var.kubernetes_dns_service_ip
    service_cidr       = var.kubernetes_service_cidr
    docker_bridge_cidr = var.kubernetes_docker_bridge_cidr
    load_balancer_sku  = "standard"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "aks_mi_role_assignment" {
  scope                = azurerm_virtual_network.kubernetes_virtual_network.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity.0.principal_id
}

resource "azurerm_role_assignment" "aks_mi_container_registry" {
  scope                = data.azurerm_container_registry.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
}
