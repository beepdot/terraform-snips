provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}
