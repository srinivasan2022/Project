# Create the Resource Group
resource "azurerm_resource_group" "On_Premises" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "On_Premises_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
    location = azurerm_resource_group.On_Premises["On_Premises_RG"].location
    depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.On_Premises_vnet["On_Premises_vnet"].name
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  depends_on = [ azurerm_virtual_network.On_Premises_vnet ]
}

# Create the Public IP for VPN Gateway 
resource "azurerm_public_ip" "public_ips" {
  name = "OnPremise-VPN-${azurerm_subnet.subnets["GatewaySubnet"].name}-IP"  
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the VPN Gateway in their Specified Subnet
resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "OnPremise-VPN-gateway"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.public_ips.id
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  depends_on = [ azurerm_resource_group.On_Premises , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
}

# Fetch the data from Hub Gateway Public_IP (IP_address)
data "azurerm_public_ip" "Hub-VPN-GW-public-ip" {
  name = "GatewaySubnet-IP"
  resource_group_name = "Hub_RG"
}

# Fetch the data from Hub Virtual Network (address_space)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "OnPremises_local_gateway" {
  name                = "OnPremises-To-Hub"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address
  address_space       = [data.azurerm_virtual_network.Hub_vnet.address_space[0]]
  depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway ,
               data.azurerm_public_ip.Hub-VPN-GW-public-ip , data.azurerm_virtual_network.Hub_vnet ]
}

# Create the VPN-Connection for Connecting the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                = "OnPremises-Hub-vpn-connection"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.OnPremises_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "YourSharedKey"

  depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.OnPremises_local_gateway]
}

 # ------------------

# Create the Network Interface card for Virtual Machines
resource "azurerm_network_interface" "subnet_nic" {
  name                = "DB-NIC"
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  location = azurerm_resource_group.On_Premises["On_Premises_RG"].location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["OnPremSubnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.On_Premises_vnet , azurerm_subnet.subnets ]
}

# Fetch the data from key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "MyKeyVault1603"
  resource_group_name = "Spoke_01_RG"
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

# Create the Virtual Machines(VM) and assign the NIC to specific VM
resource "azurerm_windows_virtual_machine" "VMs" {
  name = "OnPrem-VM"
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  location = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  size                  = "Standard_DS1_v2"
  admin_username        = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password        = data.azurerm_key_vault_secret.vm_admin_password.value
  network_interface_ids = [azurerm_network_interface.subnet_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_network_interface.subnet_nic , data.azurerm_key_vault_secret.vm_admin_password , data.azurerm_key_vault_secret.vm_admin_username]
}

# Creates the route table
resource "azurerm_route_table" "route_table" {
  name                = "Onprem-Spoke"
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  location = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  depends_on = [ azurerm_resource_group.On_Premises , azurerm_subnet.subnets ]
}

# Creates the route in the route table (OnPrem-Firewall-Spoke)
resource "azurerm_route" "route_01" {
  name                   = "ToSpoke01"
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.20.0.0/16"     # destnation network address space
  next_hop_type          = "VirtualNetworkGateway" 
  # vnext_hop_in_ip_address = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address   # Hub-Gateway public IP
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table with the subnet
resource "azurerm_subnet_route_table_association" "RT-ass" {
   subnet_id                 = azurerm_subnet.subnets["OnPremSubnet"].id
   route_table_id = azurerm_route_table.route_table.id
   depends_on = [ azurerm_subnet.subnets , azurerm_route_table.route_table ]
}
