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
      # Pod Security Admission : le niveau "restricted" refuse tout pod qui
      # tournerait en root, garderait des capacités ou monterait l'hôte.
      "pod-security.kubernetes.io/enforce"         = "restricted"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/warn"            = "restricted"
    }
  }
}

resource "kubernetes_resource_quota_v1" "plafonds" {
  metadata {
    name      = "plafonds"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"           = var.quota.cpu_demande
      "limits.memory"          = var.quota.memoire_limite
      "requests.storage"       = var.quota.stockage
      "persistentvolumeclaims" = var.quota.nb_pvc
      "pods"                   = var.quota.nb_pods
    }
  }
}

# Valeurs par défaut pour un conteneur qui n'a rien déclaré : avec un quota,
# un pod sans requests/limits serait refusé.
resource "kubernetes_limit_range_v1" "defauts" {
  metadata {
    name      = "defauts"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "tout_refuser" {
  metadata {
    name      = "tout-refuser"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "dns" {
  metadata {
    name      = "autoriser-dns"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      to {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
        pod_selector {
          match_labels = { "k8s-app" = "kube-dns" }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}

output "namespace" {
  value = kubernetes_namespace_v1.ns.metadata[0].name
}
