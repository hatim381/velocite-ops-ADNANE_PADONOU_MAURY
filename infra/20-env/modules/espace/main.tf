# Un namespace qui naît fermé : quota, limites par défaut, sécurité des pods
# imposée, aucun flux réseau autorisé sauf la résolution DNS.

terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

variable "namespace" { type = string }
variable "env" { type = string }
variable "quota" {
  type = object({
    cpu_demande    = string
    memoire_limite = string
    stockage       = string
    nb_pvc         = number
    nb_pods        = number
  })
}

resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = var.namespace
    labels = {
      "velocite.fr/env" = var.env
      pod-security.kubernetes.io/enforce = restricted 
      pod-security.kubernetes.io/warn    = restricted
    }
  }
}

# A FAIRE (atelier 4) : les garde-fous du namespace.
#
#   kubernetes_resource_quota_v1 "plafonds"
#     requests.cpu, limits.memory, requests.storage, persistentvolumeclaims
#     et pods, lus dans var.quota.
#
#   kubernetes_limit_range_v1 "defauts"
#     demande et limite par défaut d'un conteneur qui n'en déclare pas.
#     Question à se poser : pourquoi un quota rend-il cet objet nécessaire ?
#
#   kubernetes_network_policy_v1 "tout_refuser"
#     tous les pods, en entrée ET en sortie, aucun flux.
#
#   kubernetes_network_policy_v1 "dns"
#     tous les pods, en sortie seulement, vers les pods k8s-app=kube-dns du
#     namespace kube-system, port 53 en UDP et en TCP. Sans elle, plus aucun
#     nom de service ne se résout.

output "namespace" {
  value = kubernetes_namespace_v1.ns.metadata[0].name
}



resource "kubernetes_limit_range_v1" "defauts" {
  metadata { 
    name      = "defauts" 
    namespace = "exemple" 
  } 
  spec { 
    limit { 
      type = "Container" 
      default = {           # la limite 
        cpu = "500m", memory = "256Mi" } 
      default_request = {   # la réservation 
          cpu = "50m",  memory = "64Mi" } 
       } 
     } 
  }

  spec { 
    pod_selector {}                
    policy_types = ["Ingress", "Egress"]      
    ports { port = "53", protocol = ["UDP", "TCP"] 
    }   
  }   