<!-- BEGIN_TF_DOCS -->
## Spoke\_02 Network :
- 1.First we have to create the Resource Group for Spoke\_02.
- 2.We should create the Virtual Network for Spoke\_02 with address space.
- 3.The Spoke\_02 Virtual Network has multiple subnets with address prefixes.
- 4.Atleast one spoke must host a high-availability virtual machine Scale Set(VMSS) service.
- 5.The VMSS should support layer 7 capabilities and SSL certificate termination (Use Application Gateway).
- 6.Each Network Security Group should associate with their respective Subnets.
- 7.We have to establish the peering between Hub and Spoke\_02.

## Architecture Diagram :
![SPOKE\_02](https://github.com/user-attachments/assets/8f4dbe12-420c-4fa0-bf92-367976fdf9e4)

###### Apply the Terraform configurations :
Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```

```hcl
# Create the Resource Group
resource "azurerm_resource_group" "Spoke_02" {
   name     = var.rg_name
   location = var.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_02_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_02.name
    location = azurerm_resource_group.Spoke_02.location
    depends_on = [ azurerm_resource_group.Spoke_02 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_02.name
  depends_on = [ azurerm_virtual_network.Spoke_02_vnet ]
}

# Create the Network Security Group with Rules
resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.Spoke_02.name
  location = azurerm_resource_group.Spoke_02.location

  dynamic "security_rule" {                           
     for_each = { for rule in local.rules_csv : rule.name => rule }
     content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  depends_on = [ azurerm_subnet.subnets ]
  
}

# Associate the NSG for their Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_ass" {
  subnet_id = azurerm_subnet.subnets["VMSS"].id
  network_security_group_id = azurerm_network_security_group.nsg["VMSS"].id
  depends_on = [ azurerm_network_security_group.nsg ]
}

# Create the Public IP for Application Gateway
resource "azurerm_public_ip" "public_ip" {
  name                = "AppGW-Pub-IP"
  resource_group_name = azurerm_resource_group.Spoke_02.name
  location = azurerm_resource_group.Spoke_02.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Fetch the data from key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "AzMyKeyVault160322"
  resource_group_name = "On_Premises_RG"
}

# Get the username from key vault secret store
data "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "Spokevmvirtualmachineusername"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Get the password from key vault secret store
data "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "Spokevmvirtualmachinepassword"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Get the Certificate from key vault certificate
data "azurerm_key_vault_certificate" "key_vault_Cert" {
  name = "ssl-cert"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}


# Creates the Managed user identity
resource "azurerm_user_assigned_identity" "user_ass_identity" {
  name                = "appgw-user_identity"
  resource_group_name = azurerm_resource_group.Spoke_02.name
  location            = azurerm_resource_group.Spoke_02.location
  depends_on = [ azurerm_resource_group.Spoke_02 ]
}

# Creates the Key vault access policy
resource "azurerm_key_vault_access_policy" "key_vault_policy" {
  key_vault_id = data.azurerm_key_vault.Key_vault.id
  tenant_id    = "3060b492-90b8-4040-80ae-612072ce9037"
  object_id    = azurerm_user_assigned_identity.user_ass_identity.principal_id

  certificate_permissions = ["Get", "List"]
  secret_permissions      = ["Get", "List"]
  key_permissions         = ["Get", "List"]
  depends_on = [ data.azurerm_key_vault.Key_vault ]
}

# Create the Application for their dedicated subnet
resource "azurerm_application_gateway" "appGW" {
  name                = "App-Gateway"
  resource_group_name = azurerm_resource_group.Spoke_02.name
  location = azurerm_resource_group.Spoke_02.location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  } 

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.user_ass_identity.id]
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnets["App-GW"].id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  frontend_port {
    name = "frontend-port"
    port = 443
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "appgw-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
    
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontend-port"
    protocol                       = "Https"
    ssl_certificate_name = "ssl-cert"
  }

  ssl_certificate {
    name = "ssl-cert"
    key_vault_secret_id = data.azurerm_key_vault_certificate.key_vault_Cert.secret_id
  }

  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
  }
    depends_on = [azurerm_resource_group.Spoke_02 ,azurerm_subnet.subnets ,azurerm_public_ip.public_ip , 
    data.azurerm_key_vault_certificate.key_vault_Cert , azurerm_user_assigned_identity.user_ass_identity ,azurerm_key_vault_access_policy.key_vault_policy]
 }


# Create windows Virtual Machine Scale Set (VMSS)
resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "myvmss"
  resource_group_name = azurerm_resource_group.Spoke_02.name
  location = azurerm_resource_group.Spoke_02.location
  sku = "Standard_DS1_v2"
  instances = 2
  admin_username = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password = data.azurerm_key_vault_secret.vm_admin_password.value
  network_interface {
    name = "myvmss"
    primary = true
    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.subnets["VMSS"].id
      application_gateway_backend_address_pool_ids = [local.application_gateway_backend_address_pool_ids[0]]
    }
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}


# Fetch the data from Hub Virtual Network for peering the Spoke_02 Virtual Network (Spoke_02 <--> Hub)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Establish the Peering between Spoke_02 and Hub networks (Spoke_02 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_02-To-Hub" {
  name                      = "Spoke_02-To-Hub"
  resource_group_name       = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].resource_group_name
  virtual_network_name      = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_02_vnet , data.azurerm_virtual_network.Hub_vnet  ]
}

# Establish the Peering between and Hub Spoke_01 networks (Hub <--> Spoke_02)
resource "azurerm_virtual_network_peering" "Hub-Spoke_02" {
  name                      = "Hub-Spoke_02"
  resource_group_name       = data.azurerm_virtual_network.Hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.Hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_02_vnet , data.azurerm_virtual_network.Hub_vnet ]
}


```
### Deployments in Portal :
![spoke02_portal](https://github.com/user-attachments/assets/75b84b91-8de2-40ff-93ea-7ec70e7a6314)

### Resource Visualizer in Azure portal :
![spoke02_res_visual](https://github.com/user-attachments/assets/794efe43-efd2-4234-8226-4570e908ea1a)

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_application_gateway.appGW](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway) (resource)
- [azurerm_key_vault_access_policy.key_vault_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_access_policy) (resource)
- [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.Spoke_02](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_network_security_group_association.nsg_ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_user_assigned_identity.user_ass_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) (resource)
- [azurerm_virtual_network.Spoke_02_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Hub-Spoke_02](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.Spoke_02-To-Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_windows_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine_scale_set) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_certificate.key_vault_Cert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_certificate) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_rg_location"></a> [rg\_location](#input\_rg\_location)

Description: The Location of the Resource Group

Type: `string`

### <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name)

Description: The name of the Resource Group

Type: `string`

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: The details of the Subnets

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: The details of the VNET

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_Spoke_02_RG"></a> [Spoke\_02\_RG](#output\_Spoke\_02\_RG)

Description: n/a

### <a name="output_Spoke_02_vnet"></a> [Spoke\_02\_vnet](#output\_Spoke\_02\_vnet)

Description: n/a

### <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip)

Description: n/a

### <a name="output_subnet_details"></a> [subnet\_details](#output\_subnet\_details)

Description: n/a

## Modules

No modules.

This is the Spoke\_02 Network Configuration Terraform Files.
<!-- END_TF_DOCS -->