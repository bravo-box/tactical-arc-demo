# infra

Terraform templates that provision the Azure Government footprint for the demo:
resource group, Log Analytics workspace, Azure Container Registry, and the AKS
cloud cluster.

Authentication uses the **logged-in Azure CLI user** (no service principal):

```bash
az cloud set --name AzureUSGovernment
az login
az account set --subscription "<subscription-id>"

cd infra
cp terraform.tfvars.example terraform.tfvars   # adjust values
terraform init
terraform plan
terraform apply
```

Formatting and validation:

```bash
terraform fmt -recursive
terraform validate
tflint
```
