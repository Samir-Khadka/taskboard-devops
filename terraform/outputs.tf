output "public_ip" {
  description = "Elastic IP of the TaskBoard host."
  value       = aws_eip.host.public_ip
}

output "app_url" {
  description = "TaskBoard web UI (docker compose stack)."
  value       = "http://${aws_eip.host.public_ip}:8080"
}

output "grafana_url" {
  description = "Grafana (restricted to admin_cidr)."
  value       = "http://${aws_eip.host.public_ip}:3001"
}

output "prometheus_url" {
  description = "Prometheus (restricted to admin_cidr)."
  value       = "http://${aws_eip.host.public_ip}:9090"
}

output "ssh_command" {
  description = "SSH command for the host (requires key_name to be set)."
  value       = "ssh ubuntu@${aws_eip.host.public_ip}"
}
