<!-- BEGIN_TF_DOCS -->
## Hub Network :
- 1.First we have to create the Resource Group for Hub.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnets for Firewall,VPN Gateway,Bastion and AppserviceSubnet.
- 5.Dedicated subnets : AzureFirewallSubnet, GatewaySubnet.
- 6.We should create the Local Network Gateway and Connection service for establish the connection between On\_premises and Hub.

## Architecture Diagram :
![HUB](https://github.com/user-attachments/assets/edf4829f-002d-43dd-9c6d-aef6ad956682)

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
resource "azurerm_resource_group" "Hub" {
   name     = var.rg_name
   location = var.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Hub_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Hub.name
    location = azurerm_resource_group.Hub.location
    depends_on = [ azurerm_resource_group.Hub ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Hub_vnet["Hub_vnet"].name
  resource_group_name = azurerm_resource_group.Hub.name
  depends_on = [ azurerm_virtual_network.Hub_vnet ]
}

# Create the Public IP's for Azure Firewall , VPN Gateway and Azure Bastion Host 
resource "azurerm_public_ip" "public_ips" {
  for_each = toset(local.subnet_names)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.Hub.location
  resource_group_name = azurerm_resource_group.Hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.Hub ]
}

# Creates the Azure Bastion
resource "azurerm_bastion_host" "bastion" {
  name                = "Bastion"
  location            = azurerm_resource_group.Hub.location
  resource_group_name = azurerm_resource_group.Hub.name
  sku = "Standard"
  ip_configuration {
    name = "ipconfig"
    public_ip_address_id = azurerm_public_ip.public_ips["AzureBastionSubnet"].id
    subnet_id = azurerm_subnet.subnets["AzureBastionSubnet"].id 
  }
  depends_on = [ azurerm_subnet.subnets , azurerm_public_ip.public_ips]
}
 
# Create the Azure Firewall policy
resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "example-firewall-policy"
  location            = azurerm_resource_group.Hub.location
  resource_group_name = azurerm_resource_group.Hub.name
  sku = "Standard"
  depends_on = [ azurerm_resource_group.Hub , azurerm_subnet.subnets ]
}
 
# Create the Azure Firewall to control the outbound traffic
resource "azurerm_firewall" "firewall" {
  name                = "Firewall"
  location            = azurerm_resource_group.Hub.location
  resource_group_name = azurerm_resource_group.Hub.name
   sku_name = "AZFW_VNet"
   sku_tier = "Standard"

  ip_configuration {
    name                 = "firewallconfiguration"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.public_ips["AzureFirewallSubnet"].id
  }
  firewall_policy_id = azurerm_firewall_policy.firewall_policy.id
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , 
  azurerm_subnet.subnets , azurerm_firewall_policy.firewall_policy ]
}

# Create the IP Group to store Spoke Ip addresses
resource "azurerm_ip_group" "Ip_group" {
  name                = "Spoke-Ip-Group"
  resource_group_name = azurerm_resource_group.Hub.name
  location            = azurerm_resource_group.Hub.location
  cidrs = [ "10.20.0.0/16" , "10.30.0.0/16" , "10.40.0.0/16" ]
  depends_on = [ azurerm_resource_group.Hub ]
}

# Create the Azure Firewall policy rule collection
resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_rule_collection" {
  name                = "app-rule-collection-group"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy.id
  priority            = 100
   
  network_rule_collection {     # Create the Network rule collection for forwarding the traffic betwwen Hub and OnPremises network
    name     = "network-rule-collection"
    priority = 200
    action   = "Allow"

    rule {
      name = "allow-spokes"
      source_addresses = [ "10.100.0.0/16" ]       # OnPremises network address
      # destination_addresses = [ "10.20.0.0/16" ]
      destination_ip_groups = [ azurerm_ip_group.Ip_group.id ]  # All Spoke network addresses
      destination_ports = [ "*" ]
      protocols = [ "Any" ]
    }
  }
 
  depends_on = [ azurerm_firewall.firewall , azurerm_ip_group.Ip_group ]
}

# Create the VPN Gateway in their Specified Subnet
resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "Hub-vpn-gateway"
  location            = azurerm_resource_group.Hub.location
  resource_group_name = azurerm_resource_group.Hub.name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.public_ips["GatewaySubnet"].id
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
}

# Fetch the data from On_premises Gateway Public_IP (IP_address)
data "azurerm_public_ip" "OnPrem-VPN-GW-public-ip" {
  name = "OnPremise-VPN-GatewaySubnet-IP"
  resource_group_name = "On_Premises_RG"
}

# Fetch the data from On_Premise Virtual Network (address_space)
data "azurerm_virtual_network" "On_Premises_vnet" {
  name = "On_Premises_vnet"
  resource_group_name = "On_Premises_RG"
}


# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "Hub_local_gateway" {
  name                = "Hub-To-OnPremises"
  resource_group_name = azurerm_virtual_network_gateway.gateway.resource_group_name
  location = azurerm_virtual_network_gateway.gateway.location
  gateway_address     = data.azurerm_public_ip.OnPrem-VPN-GW-public-ip.ip_address          # Replace the Hub-VPN Public-IP
  address_space       = [data.azurerm_virtual_network.On_Premises_vnet.address_space[0]]   # Replace the OnPremises Vnet address space
  depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway , 
              data.azurerm_public_ip.OnPrem-VPN-GW-public-ip ,data.azurerm_virtual_network.On_Premises_vnet ]
}

 # Create the VPN-Connection for Connecting the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" { 
  name                           = "Hub-OnPremises-vpn-connection"
  resource_group_name = azurerm_virtual_network_gateway.gateway.resource_group_name
  location = azurerm_virtual_network_gateway.gateway.location
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.Hub_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "YourSharedKey" 

  depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.Hub_local_gateway]
}

# Creates the route table
resource "azurerm_route_table" "route_table" {
  name                = "Hub-Gateway-RT"
  resource_group_name = azurerm_resource_group.Hub.name
  location = azurerm_resource_group.Hub.location
  depends_on = [ azurerm_resource_group.Hub , azurerm_subnet.subnets ]
}

# Creates the route in the route table
resource "azurerm_route" "route_02" {
  name                   = "ToSpoke01"
  resource_group_name = azurerm_route_table.route_table.resource_group_name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.20.0.0/16"     # destnation network address space
  next_hop_type          = "VirtualAppliance" 
  next_hop_in_ip_address = "10.10.0.4"   # Firewall private IP
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table with the their subnet
resource "azurerm_subnet_route_table_association" "RT-ass" {
   subnet_id                 = azurerm_subnet.subnets["GatewaySubnet"].id
   route_table_id = azurerm_route_table.route_table.id
  depends_on = [ azurerm_subnet.subnets , azurerm_route_table.route_table ]
}







```

### Deployments in Portal :

![hub_portal](https://github.com/user-attachments/assets/be7543e1-8fd4-421d-a123-6a0c47ab5f42)

### Resource Visualizer in Azure portal :

![hub_res_visual](https://github.com/user-attachments/assets/55f01a57-766f-448d-9094-b8ec17af5f75)

### Hub network Peering with Spoke networks :

![hub_peering](https://github.com/user-attachments/assets/5e8ed4cf-0b53-40e8-9ba4-a1b4d84f8fd4)

### Hub network connected OnPremises network through VPN :

![hub_vpn](https://github.com/user-attachments/assets/487372cb-b9d9-4006-acf1-20300c7da650)

### Firewall policy :

![fw_policy](https://github.com/user-attachments/assets/afafd93b-d5f2-4922-8ee1-bbbbba7c7c62)

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

- [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) (resource)
- [azurerm_firewall.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) (resource)
- [azurerm_firewall_policy.firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) (resource)
- [azurerm_firewall_policy_rule_collection_group.fw_policy_rule_collection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) (resource)
- [azurerm_ip_group.Ip_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ip_group) (resource)
- [azurerm_local_network_gateway.Hub_local_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) (resource)
- [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route.route_02](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route_table.route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.RT-ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)
- [azurerm_virtual_network_gateway_connection.vpn_connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) (resource)
- [azurerm_public_ip.OnPrem-VPN-GW-public-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) (data source)
- [azurerm_virtual_network.On_Premises_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

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

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_Bastion"></a> [Bastion](#output\_Bastion)

Description: n/a

### <a name="output_Firewall"></a> [Firewall](#output\_Firewall)

Description: n/a

### <a name="output_Hub_RG"></a> [Hub\_RG](#output\_Hub\_RG)

Description: n/a

### <a name="output_Hub_vnet_"></a> [Hub\_vnet\_](#output\_Hub\_vnet\_)

Description: n/a

### <a name="output_Public_ips"></a> [Public\_ips](#output\_Public\_ips)

Description: n/a

### <a name="output_Subnet_details"></a> [Subnet\_details](#output\_Subnet\_details)

Description: n/a

### <a name="output_VPN_Gateway"></a> [VPN\_Gateway](#output\_VPN\_Gateway)

Description: n/a

## Modules

No modules.

This is the Hub Network Configuration Terraform Files.
<!-- END_TF_DOCS -->