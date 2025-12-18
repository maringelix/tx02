output "ingress_class_name" {
  description = "Ingress class name to use in Ingress resources"
  value       = "nginx"
}

output "namespace" {
  description = "Namespace where NGINX Ingress is deployed"
  value       = helm_release.nginx_ingress.namespace
}
