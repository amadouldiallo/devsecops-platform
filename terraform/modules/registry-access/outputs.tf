output "service_account_email" {
  description = "Email du SA à annoter sur le ServiceAccount Kubernetes de Kyverno"
  value       = google_service_account.kyverno.email
}
