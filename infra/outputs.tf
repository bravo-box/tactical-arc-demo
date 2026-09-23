output "network_resource_group_name" {
  description = "Resource group containing shared network resources."
  value       = module.networking.resource_group_name
}

output "cloud_resource_group_name" {
  description = "Resource group containing AKS and cloud services."
  value       = module.cloud.resource_group_name
}

output "edge_resource_group_name" {
  description = "Resource group reserved for Arc-managed edge resources."
  value       = module.edge.resource_group_name
}

output "aks_cluster_name" {
  description = "Cloud AKS cluster name."
  value       = module.cloud.aks_cluster_name
}

output "container_registry_name" {
  description = "Globally unique Azure Container Registry name."
  value       = module.cloud.container_registry_name
}

output "container_registry_login_server" {
  description = "Azure Government registry login server."
  value       = module.cloud.container_registry_login_server
}

output "application_gateway_public_ip" {
  description = "Public IP through which application traffic enters the platform."
  value       = module.networking.application_gateway_public_ip
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN Gateway."
  value       = module.networking.vpn_gateway_public_ip
}

output "servicebus_namespace_name" {
  description = "Service Bus namespace used by cloud and edge applications."
  value       = module.messaging.servicebus_namespace_name
}

output "servicebus_fully_qualified_namespace" {
  description = "Azure Government Service Bus namespace endpoint."
  value       = module.messaging.servicebus_fully_qualified_namespace
}

output "edge_heartbeat_topic_name" {
  description = "Service Bus topic receiving edge device heartbeat messages."
  value       = module.messaging.edge_heartbeat_topic_name
}

output "heartbeat_monitor_subscription_name" {
  description = "Service Bus subscription used to consume edge heartbeat messages."
  value       = module.messaging.heartbeat_monitor_subscription_name
}

output "take_picture_queue_name" {
  description = "Service Bus queue receiving TakePicture commands."
  value       = module.messaging.take_picture_queue_name
}

output "update_location_queue_name" {
  description = "Service Bus queue receiving UpdateLocationRequest commands."
  value       = module.messaging.update_location_queue_name
}

output "image_upload_topic_name" {
  description = "Service Bus topic receiving ImageUpload events."
  value       = module.messaging.image_upload_topic_name
}

output "image_web_subscription_name" {
  description = "Service Bus subscription consumed by the cloud image gallery."
  value       = module.messaging.image_web_subscription_name
}

output "image_storage_account_name" {
  description = "Storage account containing edge device images."
  value       = module.messaging.image_storage_account_name
}

output "image_storage_account_url" {
  description = "Private blob endpoint used by edge and cloud applications."
  value       = module.messaging.image_storage_account_url
}

output "workload_identity_client_id" {
  description = "Client ID to annotate on the telemetry Kubernetes service account."
  value       = module.cloud.workload_identity_client_id
}

output "cosmosdb_endpoint" {
  description = "Private Azure Government Cosmos DB endpoint used by the telemetry API."
  value       = module.cloud.cosmosdb_endpoint
}

output "cosmosdb_database_name" {
  description = "Cosmos DB database containing device documents."
  value       = module.cloud.cosmosdb_database_name
}

output "cosmosdb_container_name" {
  description = "Cosmos DB container containing one document per device."
  value       = module.cloud.cosmosdb_container_name
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace receiving AKS and platform diagnostics."
  value       = module.cloud.log_analytics_workspace_id
}
