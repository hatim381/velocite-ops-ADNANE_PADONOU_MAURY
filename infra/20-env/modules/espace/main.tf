# Un namespace qui naît fermé : quota, limites par défaut, sécurité des pods
# imposée, aucun flux réseau autorisé sauf la résolution DNS.
#
# Atelier 4, version du cours (mercredi) : les blocs sont écrits. Il vous
# reste les valeurs marquées A_REMPLIR (entourées de deux soulignés de
# chaque côté), chacune expliquée par le commentaire au-dessus d'elle. Tant
# qu'il en reste une, tofu validate ou tofu plan s'arrête et dit où. Les
# slides 22 à 24 du J2 donnent toutes les réponses.

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
      # Pod Security Admission : le niveau qui refuse tout pod root ou trop
      # privilégié. Le même niveau sur les deux lignes : enforce refuse,
      # warn prévient dès l'apply (slide 24).
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# Le plafond de tout l'environnement. Chaque valeur se lit dans var.quota,
# rempli par envs/dev.tfvars et envs/prod.tfvars : écrivez le nom du champ
# de l'objet quota (déclaré en haut de ce fichier) qui correspond à la clé.
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

# Les valeurs données à un conteneur qui ne déclare rien. Avec un quota, un
# pod sans requests ni limits serait refusé : le quota ne saurait pas le
# compter (slide 22). default est la limite, default_request la réservation ;
# la réservation est plus petite que la limite. Unités : m pour le CPU
# (500m = un demi-processeur), Mi pour la mémoire.
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

# Tout refuser : tous les pods (sélecteur vide), et les deux sens de trafic
# (slide 23). Aucun bloc ingress ni egress : rien n'est autorisé.
resource "kubernetes_network_policy_v1" "tout_refuser" {
  metadata {
    name      = "tout-refuser"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Egress", "Ingress"]
  }
}

# Puis rouvrir une seule sortie : la résolution des noms (DNS). Un seul
# bloc "to" qui pose les DEUX conditions à la fois : le namespace du
# système et les pods du DNS (slide 23). Le DNS écoute sur le port 53, dans
# deux protocoles.
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
