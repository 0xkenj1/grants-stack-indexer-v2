terraform {
  backend "s3" {
    bucket  = "gitcoin-datalayer-staging-terraform-state"
    key     = "state"
    region  = "us-east-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.84.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}


data "aws_caller_identity" "current" {}

module "container_registry" {
  source   = "../../modules/container-registry"
  app_name = var.app_name
}



module "networking" {
  source          = "../../modules/networking"
  app_environment = var.app_environment
  app_name        = var.app_name
  region          = var.region
}

module "iam" {
  source          = "../../modules/iam"
  app_name        = var.app_name
  app_environment = var.app_environment
  region          = var.region
  account_id      = data.aws_caller_identity.current.account_id
  db_name         = var.DATALAYER_PG_DB_NAME
}

module "storage" {
  source                = "../../modules/storage"
  app_name              = var.app_name
  app_environment       = var.app_environment
  region                = var.region
  db_name               = var.DATALAYER_PG_DB_NAME
  rds_username          = var.DATALAYER_PG_USER
  rds_password          = var.DATALAYER_PG_PASSWORD
  rds_security_group_id = module.networking.rds_security_group_id
  rds_subnet_ids        = module.networking.private_subnets
  rds_subnet_group_name = module.networking.rds_subnet_group_name
}

module "bastion" {
  source                        = "../../modules/bastion"
  app_environment               = var.app_environment
  app_name                      = var.app_name
  subnet_id                     = module.networking.private_subnets[0]
  bastion_instance_profile_name = module.iam.bastion_instance_profile_name
  bastion_security_group_id     = module.networking.processing_security_group_id
}

module "load_balancer" {
  source                          = "../../modules/load_balancer"
  app_name                        = var.app_name
  app_environment                 = var.app_environment
  vpc_id                          = module.networking.vpc_id
  public_subnets                  = module.networking.public_subnets
  load_balancer_security_group_id = module.networking.load_balancer_security_group_id
}

module "compute" {
  source                                         = "../../modules/compute"
  app_name                                       = var.app_name
  app_environment                                = var.app_environment
  region                                         = var.region
  processing_repository_url                      = module.container_registry.processing_repository_url
  processing_service_role_arn                    = module.iam.processing_service_role_arn
  processing_image_tag                           = var.processing_image_tag
  processing_security_group_id                   = module.networking.processing_security_group_id
  api_image_tag                                  = var.api_image_tag
  api_repository_url                             = var.api_repository_url
  api_service_role_arn                           = module.iam.api_service_role_arn
  api_security_group_id                          = module.networking.api_security_group_id
  lb_target_group_arn                            = module.load_balancer.lb_target_group_arn
  NODE_ENV                                       = var.NODE_ENV
  RETRY_BASE_DELAY_MS                            = var.RETRY_BASE_DELAY_MS
  RETRY_MAX_DELAY_MS                             = var.RETRY_MAX_DELAY_MS
  RETRY_FACTOR                                   = var.RETRY_FACTOR
  RETRY_MAX_ATTEMPTS                             = var.RETRY_MAX_ATTEMPTS
  DATALAYER_HASURA_DATABASE_URL                  = "postgresql://${var.DATALAYER_PG_USER}:${var.DATALAYER_PG_PASSWORD}@${module.storage.rds_endpoint}/${var.DATALAYER_PG_DB_NAME}"
  DATALAYER_HASURA_EXPOSED_PORT                  = var.DATALAYER_HASURA_EXPOSED_PORT
  DATALAYER_HASURA_ENABLE_CONSOLE                = var.DATALAYER_HASURA_ENABLE_CONSOLE
  DATALAYER_HASURA_ADMIN_SECRET                  = var.DATALAYER_HASURA_ADMIN_SECRET
  DATALAYER_HASURA_UNAUTHORIZED_ROLE             = var.DATALAYER_HASURA_UNAUTHORIZED_ROLE
  DATALAYER_HASURA_CORS_DOMAIN                   = var.DATALAYER_HASURA_CORS_DOMAIN
  DATALAYER_HASURA_ENABLE_TELEMETRY              = var.DATALAYER_HASURA_ENABLE_TELEMETRY
  DATALAYER_HASURA_DEV_MODE                      = var.DATALAYER_HASURA_DEV_MODE
  DATALAYER_HASURA_ADMIN_INTERNAL_ERRORS         = var.DATALAYER_HASURA_ADMIN_INTERNAL_ERRORS
  DATALAYER_HASURA_CONSOLE_ASSETS_DIR            = var.DATALAYER_HASURA_CONSOLE_ASSETS_DIR
  DATALAYER_HASURA_ENABLED_LOG_TYPES             = var.DATALAYER_HASURA_ENABLED_LOG_TYPES
  DATALAYER_HASURA_DEFAULT_NAMING_CONVENTION     = var.DATALAYER_HASURA_DEFAULT_NAMING_CONVENTION
  DATALAYER_HASURA_BIGQUERY_STRING_NUMERIC_INPUT = var.DATALAYER_HASURA_BIGQUERY_STRING_NUMERIC_INPUT
  DATALAYER_HASURA_EXPERIMENTAL_FEATURES         = var.DATALAYER_HASURA_EXPERIMENTAL_FEATURES
  DATALAYER_HASURA_ENABLE_ALLOW_LIST             = var.DATALAYER_HASURA_ENABLE_ALLOW_LIST
  CHAINS                                         = var.CHAINS

  DATABASE_URL        = "postgresql://${var.DATALAYER_PG_USER}:${var.DATALAYER_PG_PASSWORD}@${module.storage.rds_endpoint}/${var.DATALAYER_PG_DB_NAME}"
  INDEXER_GRAPHQL_URL = var.INDEXER_GRAPHQL_URL
  # INDEXER_ADMIN_SECRET                           = var.INDEXER_ADMIN_SECRET
  PUBLIC_GATEWAY_URLS = var.PUBLIC_GATEWAY_URLS
  METADATA_SOURCE     = var.METADATA_SOURCE
  PRICING_SOURCE      = var.PRICING_SOURCE
  COINGECKO_API_KEY   = var.COINGECKO_API_KEY
  COINGECKO_API_TYPE  = var.COINGECKO_API_TYPE
  LOG_LEVEL           = var.LOG_LEVEL
  public_subnets      = module.networking.public_subnets
  private_subnets     = module.networking.private_subnets
}
