# Azure Government infrastructure

This Terraform stack provisions the tactical Arc demo footprint in Azure
Government:

- `az-tactical-demo-network`: VNet, dedicated subnets, Azure Bastion,
  Entra-authenticated point-to-site VPN, optional edge site-to-site VPN, and
  WAF_v2 Application Gateway.
- `az-tactical-demo-cloud`: private AKS, Premium private ACR, Premium private
  Service Bus, private image Blob Storage, Cosmos DB for NoSQL, workload
  identity, Log Analytics, and Application Insights.
- `az-tactical-demo-edge`: landing resource group for Arc-managed edge
  resources created during device onboarding.

Application traffic enters through Application Gateway. The AKS Application
Gateway ingress add-on manages its backend configuration. ACR, Service Bus, image storage, and Cosmos DB disable public access and use
Azure Government private DNS zones. AKS uses managed identity for image pulls
and a federated workload identity for Service Bus, Blob Storage, and Cosmos DB
data-plane access.

## Prerequisites

```bash
az cloud set --name AzureUSGovernment
az login
az account set --subscription "<subscription-id>"
```

The deploying identity needs permission to create resource groups, networking,
managed identities, role assignments, AKS, ACR, and Service Bus resources.
Confirm that `VpnGw1AZ` and availability zones are supported in the selected
Azure Government region. If they are not, override `vpn_gateway_sku` and remove
zonal settings before deployment.

## Configure and validate

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars. Never store the edge VPN shared key in this file.
export TF_VAR_edge_shared_key="<ipsec-pre-shared-key>" # only for S2S

terraform init
terraform fmt -check -recursive
terraform validate
checkov -d .
terraform plan
```

The default configuration enables Entra/OpenVPN point-to-site access for
laptops. Set `edge_vpn_enabled = true`, `edge_gateway_address`, and
`edge_address_spaces` to add the site-to-site edge tunnel.

After onboarding an edge device to Azure Arc, set
`edge_arc_principal_id` to its managed identity principal ID to grant it
`Azure Service Bus Data Sender` on the `edge-heartbeat` topic. The topic also
has a `heartbeat-monitor` subscription for heartbeat consumers.

The image pipeline adds the `take-picture` queue, `image-upload` topic with an
`image-web` subscription, and a private `device-images` blob container. The
Arc principal receives camera commands, sends upload events, and contributes
blobs. The AKS workload identity receives upload events and reads blobs.
The command queue requires sessions so the cloud monitor can target the
selected device by using its device name as the session ID.

Cosmos DB stores one JSON document per device in the `telemetry/devices`
container, partitioned by `/deviceId`. Each document contains bounded heartbeat
and image-metadata histories plus the latest location and device specs. Image
bytes remain in Blob Storage. Local Cosmos keys are disabled, and the workload
identity receives only the built-in Cosmos DB data contributor role.

## AKS workload identity

Configure the cloud Helm chart to use namespace `tactical-arc` and service
account `telemetry-api`, annotate the service account with the
`workload_identity_client_id` output, and add the label
`azure.workload.identity/use: "true"` to the pod template. The application
authenticates with `DefaultAzureCredential`; no Cosmos DB key or connection
string is created.

## Remote state

`backend.tf` declares an AzureRM backend without embedded values. Supply the
Government-cloud storage backend settings during initialization, for example:

```bash
terraform init \
  -backend-config="resource_group_name=<state-rg>" \
  -backend-config="storage_account_name=<state-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=tactical-arc-demo.tfstate"
```

Use a pre-created, private state storage account with Entra authentication and
shared-key access disabled.
