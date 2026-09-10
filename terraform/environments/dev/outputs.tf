output "kyverno_service_account_email" {
  description = "Email du SA à annoter sur le ServiceAccount Kubernetes kyverno-admission-controller"
  value       = module.registry_access.service_account_email
}
