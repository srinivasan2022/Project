# Hub-spoke network topology in Azure :

[![Documentation](https://img.shields.io/badge/Azure-blue?style=for-the-badge)](https://azure.microsoft.com/en-us/resources/cloud-computing-dictionary/what-is-azure) [![Documentation](https://img.shields.io/badge/Azure_Virtual_Network-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) [![Documentation](https://img.shields.io/badge/Azure_Firewall-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/firewall/overview) [![Documentation](https://img.shields.io/badge/Azure_Bastion-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview) [![Documentation](https://img.shields.io/badge/Azure_VPN_Gateway-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) 

#### Description :
This project will implement an Azure [Hub and Spoke](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) architecture to support a student details application, focusing on security and efficiency. This architecture will feature a centralized hub for shared resources and multiple spoke networks for isolated environments, ensuring high availability and resiliency. Key elements include guard rails to enforce governance, robust security measures including encryption and firewalls, and comprehensive monitoring and logging capabilities. The solution will also incorporate backup and recovery strategies to protect data integrity and ensure business continuity. 

<mark>NOTE : </mark><br>
- 1.First we have to create the [backend](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/backend) file for storing the state files. 
- 2.Next , we creates the [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) or [OnPremises](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) Network , then we creates the Onprem network.
- 3.If we creates the [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) network , we should creates still gateway in [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) network , because [Onprem](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) vnet address and gateway Ip addresss are required for [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) network , then we creates the [Onprem](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) network.
- 4.If not so , If we creates the [Onprem](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) network , we should creates still gateway in [Onprem](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) network , because [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) vnet address and gateway Ip address are required for [Onprem](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/On_Premises) network , then we creates the [Hub](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Hub) network. 
- 5.Then we can creates the other [Spoke-01](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Spoke_01) , [Spoke-02](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Spoke_02) and [Spoke-03](https://github.com/srinivasan2022/Azure_Hub_and_Spoke/tree/main/Spoke_03) Networks.

## Architecture Overview

The **Hub and Spoke** topology includes:
- A central Hub VNet for shared resources, such as firewalls and VPN gateways.
- Multiple Spoke VNets that connect to the Hub and are used for isolated environments like Dev, Test, and Prod.
- Communication between the Spokes through the Hub, ensuring centralized security and monitoring.

### Features
- **Centralized Network Management** : The Hub serves as the primary network for shared services, while Spokes are used to isolate different environments.
- **Secure Communication** : Secure connections are established between Spokes and the Hub for controlled traffic flow.
- **Scalable Design** : The architecture can easily scale to accommodate additional Spokes.

### Repository Structure

```bash
Azure_Hub_and_Spoke/
│
├── main.tf             # Main Terraform configuration file
├── variables.tf        # Input variables for customization
├── outputs.tf          # Outputs the deployment details
└── README.md           # Project documentation
```
## Getting Started

### Prerequisites

- **Terraform**: Make sure you have Terraform installed. You can download it [here](https://www.terraform.io/downloads.html).
- **Azure Subscription**: Ensure you have an active Azure subscription to deploy resources.
- **Service Principal**: You will need a service principal with appropriate permissions to deploy resources in Azure.
## Architecture Diagram :
<img src="Images/Overall.png" align="center">


### Workflow :
This hub-spoke network configuration uses the following architectural elements:

**Hub virtual network:**  The hub [virtual network](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) hosts shared Azure services. Workloads hosted in the spoke virtual networks can use these services. The hub virtual network is the central point of connectivity for cross-premises networks.

**Spoke virtual networks:** Spoke virtual networks isolate and manage workloads separately in each spoke. Each workload can include multiple tiers, with multiple subnets connected through Azure load balancers. Spokes can exist in different subscriptions and represent different environments, such as Production and Non-production.

**Virtual network connectivity:** This architecture connects virtual networks by using [virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview) connections or connected groups. Peering connections and connected groups are non-transitive, low-latency connections between virtual networks. Peered or connected virtual networks can exchange traffic over the Azure backbone without needing a router. Azure Virtual Network Manager creates and manages network groups and their connections.

**Azure Bastion host:** Azure Bastion provides secure connectivity from the Azure portal to virtual machines (VMs) by using your browser. An Azure Bastion host deployed inside an Azure virtual network can access VMs in that virtual network or in connected virtual networks.

**Azure VPN Gateway or Azure ExpressRoute gateway:** A virtual network gateway enables a virtual network to connect to a virtual private network (VPN) device or Azure ExpressRoute circuit. The gateway provides cross-premises network connectivity. For more information, see [Connect an on-premises network to a Microsoft Azure virtual network](https://learn.microsoft.com/en-us/microsoft-365/enterprise/connect-an-on-premises-network-to-a-microsoft-azure-virtual-network?view=o365-worldwide) and Extend an on-premises network using VPN.

**Azure Firewall:** An Azure Firewall managed firewall instance exists in its own subnet.

### Components:
<img src="https://www.checkpoint.com/wp-content/uploads/microsoft-azure-virtual-networks-vnet.png" width="60px" align="right">

**[Virtual Network:](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)** Azure Virtual Network is the fundamental building block for private networks in Azure. Virtual Network enables many Azure resources, such as Azure VMs, to securely communicate with each other, cross-premises networks, and the internet.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQf1tfUKFwY2aEQVeePMozBGvVWZvuU8HtEbw&s" width="80px" align="right">

**[Azure Firewall:](https://learn.microsoft.com/en-us/azure/firewall/overview)** Azure Firewall is a managed cloud-based network security service that protects Virtual Network resources. This stateful firewall service has built-in high availability and unrestricted cloud scalability to help you create, enforce, and log application and network connectivity policies across subscriptions and virtual networks.

<img src="https://azure.microsoft.com/svghandler/vpn-gateway/?width=600&height=315" width="80px" align="right">

**[VPN Gateway:](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways)** VPN Gateway is a specific type of virtual network gateway that sends encrypted traffic between a virtual network and an on-premises location over the public internet. You can also use VPN Gateway to send encrypted traffic between Azure virtual networks over the Microsoft network.

<img src="https://azure.microsoft.com/svghandler/azure-bastion/?width=600&height=315" width="80px" align="right">

**[Azure Bastion:](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview)** Azure Bastion is a fully managed PaaS service that you provision to securely connect to virtual machines via private IP address. It provides secure and seamless RDP/SSH connectivity to your virtual machines directly over TLS from the Azure portal, or via the native SSH or RDP client already installed on your local computer. When you connect via Azure Bastion, your virtual machines don't need a public IP address, agent, or special client software.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQhggq3ThuvGbOvBmSVBjZIvNoq-oK-P7rRlQ&s" width="50px" align="right">

**[Application Gateway:](https://learn.microsoft.com/en-us/azure/application-gateway/overview)** Azure Application Gateway is a web traffic (OSI layer 7) load balancer that enables you to manage traffic to your web applications. It can make routing decisions based on additional attributes of an HTTP request, for example URI path or host headers. For example, you can route traffic based on the incoming URL. So if /images is in the incoming URL, you can route traffic to a specific set of servers (known as a pool) configured for images. If /video is in the URL, that traffic is routed to another pool that's optimized for videos.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRnLhoOuv9e7NLuruhd4L9hiGRkVF0KGxlIJA&s" width="50px" align="right">

**[App Service:](https://learn.microsoft.com/en-us/azure/app-service/overview)** Azure App Service is an HTTP-based service for hosting web applications, REST APIs, and mobile back ends. You can develop in your favorite language, be it .NET, .NET Core, Java, Node.js, PHP, and Python. Applications run and scale with ease on both Windows and Linux-based environments.

<img src="https://www.techielass.com/content/images/2021/03/azuredns-1.png" width="50px" align="right">

**[Azure Private DNS zone:](https://learn.microsoft.com/en-us/azure/dns/private-dns-privatednszone)** Azure Private DNS provides a reliable, secure DNS service to manage and resolve domain names in a virtual network without the need to add a custom DNS solution. By using private DNS zones, you can use your own custom domain names rather than the Azure-provided names available today.

<img src="https://user-images.githubusercontent.com/37974296/113137352-59e74380-921c-11eb-97e4-bcaf90528ae7.png" width="60px" align="right">

**[Private Endpoint:](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)** A private endpoint is a network interface that uses a private IP address from your virtual network. This network interface connects you privately and securely to a service that's powered by Azure Private Link. By enabling a private endpoint, you're bringing the service into your virtual network.

The service could be an Azure service such as:

- Azure Storage
- Azure Cosmos DB
- Azure SQL Database
- Your own service, using Private Link service.

<img src="https://ms-azuretools.gallerycdn.vsassets.io/extensions/ms-azuretools/vscode-azurestorage/0.16.0/1720461176238/Microsoft.VisualStudio.Services.Icons.Default" width="50px" align="right">

**[Storage Account:](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview)** An Azure Storage account is a cloud-based storage product that allows users to store and manage large amounts of unstructured data in the form of tables, files, blobs, queues, and disks. It provides a <mark>unique namespace</mark> for Azure Storage data that is accessible from anywhere in the world over HTTP or HTTPS.

<img src="https://feras.blog/wp-content/uploads/File-shares.png" width="50px" align="right">

**[Azure File Share:](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-introduction)** Azure Files offers fully managed file shares in the cloud that are accessible via the industry standard <mark>Server Message Block (SMB) protocol, Network File System (NFS) protocol</mark>, and Azure Files REST API. Azure file shares can be mounted concurrently by cloud or on-premises deployments. <mark>SMB Azure file shares are accessible from Windows, Linux, and macOS clients</mark>. <mark>NFS Azure file shares are accessible from Linux clients</mark>. Additionally, SMB Azure file shares can be cached on Windows servers with Azure File Sync for fast access near where the data is being used.

<img src="https://azure.microsoft.com/svghandler/managed-disks/?width=600&height=315" width="90px" align="right">

**[Azure Disk Storage:](https://learn.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview)** Azure Disk Storage is a cloud-based block storage solution provided by Microsoft Azure. It is designed to provide high-performance, durable, and secure disk options for virtual machines (VMs), containers, and other Azure services. Azure Disk Storage is used as persistent storage, meaning that the data on the disks persists even after a VM is stopped or deallocated.It is a block storage service for Azure Virtual Machines (VMs) and Azure VMware Solution. It offers a variety of [disk types](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-types), including:
- Ultra Disk Storage
- Premium SSD v2
- Standard SSD
- Standard HDD

<img src="https://miro.medium.com/v2/resize:fit:600/1*b0oZ-Da1LxW4TdujAOiC9Q.png" width="90px" align="right">

**[Azure Key Vault:](https://learn.microsoft.com/en-us/azure/key-vault/general/basic-concepts)** Azure Key Vault is a cloud service that provides a secure way to <mark>manage and protect sensitive information such as secrets, keys, and certificates</mark>. It helps you safeguard cryptographic keys and secrets used by cloud applications and services, providing enhanced data protection and ensuring compliance with industry standards.
**Types :**
- **Keys:** Primarily used for cryptographic operations like encryption, decryption, and signing.
- **Secrets:** Store and manage sensitive data like passwords, API keys, and connection strings.
- **Certificates:** Manage SSL/TLS certificates and other digital certificates for secure communication and authentication.

<img src="https://github.com/user-attachments/assets/ba42966e-261d-42c0-9b46-a2bb49f27530" width="60px" align="right">

**[IP Groups:](https://learn.microsoft.com/en-us/azure/firewall/ip-groups)** IP Groups allow grouping and managing IP addresses for Azure Firewall rules as either source or destination addresses in network rules, as well as source addresses in DNAT and application rules​​.<mark>Maximum 5000 individual IP addresses or IP prefixes per each IP Group.</mark>

<img src="https://blog.kloud.com.au/wp-content/uploads/2020/02/AzureRecoveryServicesVault-650x547.png" width="70px" align="right">

**[Recovery Service Vault:](https://learn.microsoft.com/en-us/azure/backup/backup-azure-recovery-services-vault-overview)** A Recovery Services vault is an entity that stores the backups and recovery points created over time. The Recovery Services vault also contains the backup policies that are associated with the protected virtual machines. Azure Backup automatically handles storage for the vault. See how storage settings can be changed

<img src="https://azure.microsoft.com/svghandler/monitor/?width=600&height=315" width="100px" align="right">

**[Azure Monitor:](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)** Azure Monitor can collect, analyze, and act on telemetry data from cross-premises environments, including Azure and on-premises. Azure Monitor helps you maximize the performance and availability of your applications and proactively identify problems in seconds.

<h4 style= "color : skyblue">Azure Networking:</h4>
<img src="Images/IP.png" align="right">


[Azure reserves the first four addresses and the last address, for a total of five IP addresses within each subnet.](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#are-there-any-restrictions-on-using-ip-addresses-within-these-subnets)

For example, the IP address range of 10.10.1.0/24 has the following reserved addresses:

- 10.10.1.0: Network address.
- 10.10.1.1: Reserved by Azure for the default gateway.
- 10.10.1.2, 10.10.1.3: Reserved by Azure to map the Azure DNS IP - addresses to the virtual network space.
- 10.10.1.255: Network broadcast address.

### Virtual Network Subnets:
#### GatewaySubnet:
The virtual network gateway requires a specific subnet named <mark>GatewaySubnet</mark>. The gateway subnet is part of the IP address range for your virtual network and contains the IP addresses that the virtual network gateway resources and services use. It's best to specify /27 or larger (/26, /25, etc.) for your gateway subnet.
#### AzureFirewallSubnet:
The AzureFirewallSubnet is a specialized subnet in Azure Virtual Network for hosting the Azure Firewall, a cloud-based network security service.Requires at least a /26 subnet (64 IP addresses).<mark>This subnet doesn't support network security groups (NSGs)</mark>.
#### Dedicated Subnets:
A [dedicated subnet](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-for-azure-services#services-that-can-be-deployed-into-a-virtual-network) in Azure is a specific range of IP addresses allocated within a Virtual Network (VNet) for particular resources or services. These subnets provide isolation and specific network configurations, such as for Azure Virtual Machines, VPN Gateways, Application Gateways, and other Azure services. They are crucial for managing security and network policies effectively.

<details>
<summary>The dedicated subnets are ,</summary>
<h6>Azure Virtual Machines</h6>
<h6>Azure Application Gateway</h6>
<h6>Azure Kubernetes Service</h6>
<h6>Azure VPN Gateway</h6>
<h6>Azure Firewall</h6>
<h6>Azure Bastion</h6>
<h6>Azure SQL Database Managed Instance</h6>
<h6>Azure Container Instances</h6>
</details>

#### Spoke network connectivity:
Virtual network peering or connected groups are non-transitive relationships between virtual networks. If you need spoke virtual networks to connect to each other, add a peering connection between those spokes or place them in the same network group.

#### Spoke connections through Azure Firewall or NVA:
The number of virtual network peerings per virtual network is limited. If you have many spokes that need to connect with each other, you could run out of peering connections. Connected groups also have limitations.

In this scenario, consider using user-defined routes (UDRs) to force spoke traffic to be sent to Azure Firewall or another NVA that acts as a router at the hub. This change allows the spokes to connect to each other. To support this configuration, you must implement Azure Firewall with forced tunnel configuration enabled. For more information, see Azure Firewall forced tunneling.

The topology in this architectural design facilitates egress flows. While Azure Firewall is primarily for egress security, it can also be an ingress point. For more considerations about hub NVA ingress routing, see Firewall and Application Gateway for virtual networks.

#### Spoke connections to remote networks through a hub gateway:
To configure spokes to communicate with remote networks through a hub gateway, you can use virtual network peerings or connected network groups.

To use virtual network peerings, in the virtual network Peering setup:

- Configure the peering connection in the <mark>hub to Allow gateway transit.</mark>
- Configure the peering connection in <mark>each spoke to Use the remote virtual network's gateway.</mark>
- Configure <mark>all peering connections to Allow forwarded traffic.</mark>

For more information, see [Create a virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering?tabs=peering-portal#create-a-peering).

To use connected network groups:

- In Virtual Network Manager, create a network group and add member virtual networks.
- Create a hub and spoke connectivity configuration.
- For the Spoke network groups, select Hub as gateway.

#### Spoke network communications:
There are two main ways to allow spoke virtual networks to communicate with each other:

- 1.Communication via an NVA like a firewall and router. This method incurs a hop between the three spokes.
- 2.Communication by using virtual network peering or Virtual Network Manager direct connectivity between spokes. This approach doesn't cause a hop between the two spokes and is recommended for minimizing latency.


#### Communication through an NVA:
If you need connectivity between spokes, consider deploying Azure Firewall or another NVA in the hub. Then create routes to forward traffic from a spoke to the firewall or NVA, which can then route to the second spoke. In this scenario, you must <mark>configure the peering connections to allow forwarded traffic</mark>.

<img src="https://learn.microsoft.com/en-us/azure/architecture/networking/architecture/_images/spoke-spoke-routing.png">

You can also use a VPN gateway to route traffic between spokes, although this choice affects latency and throughput. For configuration details, see [Configure VPN gateway transit for virtual network peering](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-peering-gateway-transit).

Evaluate the services you share in the hub to ensure that the hub scales for a larger number of spokes. For instance, if your hub provides firewall services, consider your firewall solution's bandwidth limits when you add multiple spokes. You can move some of these shared services to a second level of hubs.



### Feedback
**Was this document helpful?** </br>
[![Documentation](https://img.shields.io/badge/Yes-blue?style=for-the-badge)](#) [![Documentation](https://img.shields.io/badge/No-blue?style=for-the-badge)](#)


<div align="right"><h4>Written By,</h4>
<a href="https://www.linkedin.com/in/seenu2002/">V.Srinivasan</a>
<h6>Cloud Engineer Intern @ CloudSlize</h6>
</div>

<div align="center">


[![Your Button Text](https://img.shields.io/badge/Thank_you!-Your_Color?style=for-the-badge)](#)

</div>

---
