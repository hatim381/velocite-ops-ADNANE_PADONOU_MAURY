output "contexte_kubectl" {
  description = "Contexte à passer à kubectl et aux autres couches."
  value       = "kind-${kind_cluster.velocite.name}"
}

output "endpoint" {
  description = "Adresse de l'API Kubernetes."
  value       = kind_cluster.velocite.endpoint
}

output "kubeconfig_path" {
  description = "Fichier kubeconfig écrit par kind."
  value       = kind_cluster.velocite.kubeconfig_path
}
