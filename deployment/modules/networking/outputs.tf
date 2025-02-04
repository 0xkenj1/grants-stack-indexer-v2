output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

output "processing_security_group_id" {
  value = aws_security_group.processing.id
}

output "api_security_group_id" {
  value = aws_security_group.api.id
}

output "rds_subnet_group_name" {
  value = aws_db_subnet_group.rds_subnet_group.name
}
