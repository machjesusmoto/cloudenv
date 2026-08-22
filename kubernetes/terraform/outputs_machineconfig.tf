# Temporary outputs for manual config apply
output "controlplane_machine_config" {
  description = "Complete controlplane machine configuration"
  value       = data.talos_machine_configuration.controlplane.machine_configuration
  sensitive   = true
}

output "client_ca" {
  value     = talos_machine_secrets.this.client_configuration.ca_certificate
  sensitive = true
}

output "client_cert" {
  value     = talos_machine_secrets.this.client_configuration.client_certificate
  sensitive = true
}

output "client_key" {
  value     = talos_machine_secrets.this.client_configuration.client_key
  sensitive = true
}
