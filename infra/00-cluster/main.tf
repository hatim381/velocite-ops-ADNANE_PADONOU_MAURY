# ---------------------------------------------------------------------------
# Couche 00 - le cluster.
#
# Compute : un control-plane et des workers (des conteneurs Docker, ici).
# Réseau  : sous-réseaux des pods et des services, ports publiés sur le poste.
# Stockage : la classe de stockage "standard" de kind (local-path), utilisée
#            par les volumes persistants des bases.
#
# Cette couche change rarement. La détruire détruit tout ce qui est au-dessus.
# ---------------------------------------------------------------------------

resource "kind_cluster" "velocite" {
  name           = var.nom_cluster
  node_image     = var.image_noeud
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      pod_subnet     = "10.244.0.0/16"
      service_subnet = "10.96.0.0/12"
    }

    node {
      role = "control-plane"

      # Le frontal de chaque environnement, joignable depuis le poste seulement.
      dynamic "extra_port_mappings" {
        for_each = var.ports_exposes
        content {
          container_port = extra_port_mappings.value.node_port
          host_port      = extra_port_mappings.value.port_poste
          listen_address = "127.0.0.1"
          protocol       = "TCP"
        }
      }
    }

    dynamic "node" {
      for_each = range(var.nb_workers)
      content {
        role = "worker"
        labels = {
          "velocite.fr/pool" = "applicatif"
        }
      }
    }
  }
}
