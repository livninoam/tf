output "alb_dns_name" {
  value       = module.alb.lb_dns_name
  description = "alb dns name "
}

output "rds_endpoint" {
  value       = module.rds_postgres.db_instance_endpoint
  description = "rds host "
}

output "rds_password" {
  value       = module.rds_postgres.db_master_password
  description = "rds password "
  sensitive = true
}
