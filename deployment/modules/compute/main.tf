locals {
  log_group_name = "/ecs/${var.app_name}-${var.app_environment}"
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.12.0"

  ####################################
  # ECS Cluster
  ####################################
  cluster_name = "${var.app_name}-${var.app_environment}-cluster"


  ####################################
  # Log Group
  ####################################

  cloudwatch_log_group_name              = local.log_group_name
  cloudwatch_log_group_retention_in_days = 7

  ####################################
  # Services
  ####################################
  services = merge(
    {
      api_service = {
        create_security_group  = false
        name                   = "${var.app_name}-api-service"
        create_task_definition = false
        task_definition_arn    = aws_ecs_task_definition.api_task.arn
        desired_count          = 1
        platform_version       = "LATEST"
        force_new_deployment   = true
        assign_public_ip       = true
        subnet_ids             = var.public_subnets
        security_group_ids     = [var.api_security_group_id]

        autoscaling = {
          min_capacity = 1
          max_capacity = 3
          cpu = {
            target_value       = 75
            scale_in_cooldown  = 300
            scale_out_cooldown = 300
          }
        }
      }
    },
    {
      for chain in var.CHAINS :
      "processing_service_${chain.id}" => {
        create_security_group  = false
        name                   = "processing-service-${chain.id}"
        create_task_definition = false
        task_definition_arn    = aws_ecs_task_definition.processing_tasks[chain.id].arn
        enable_autoscaling     = false
        desired_count          = 1
        platform_version       = "LATEST"
        force_new_deployment   = true
        subnet_ids             = var.private_subnets
        security_group_ids     = [var.processing_security_group_id]
        tags = {
          Name = "${var.app_name}-${var.app_environment}-processing-${chain.id}"
        }
      }
    }
  )
}


# API Task Definition
resource "aws_ecs_task_definition" "api_task" {
  family                   = "${var.app_name}-${var.app_environment}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.api_service_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-${var.app_environment}-api"
      image     = "${var.api_repository_url}:${var.api_image_tag}"
      essential = true
      environment = [
        for key, value in {
          HASURA_GRAPHQL_DATABASE_URL                  = var.DATALAYER_HASURA_DATABASE_URL
          HASURA_GRAPHQL_EXPOSED_PORT                  = var.DATALAYER_HASURA_EXPOSED_PORT
          HASURA_GRAPHQL_ENABLE_CONSOLE                = var.DATALAYER_HASURA_ENABLE_CONSOLE
          HASURA_GRAPHQL_ADMIN_SECRET                  = var.DATALAYER_HASURA_ADMIN_SECRET
          HASURA_GRAPHQL_UNAUTHORIZED_ROLE             = var.DATALAYER_HASURA_UNAUTHORIZED_ROLE
          HASURA_GRAPHQL_CORS_DOMAIN                   = var.DATALAYER_HASURA_CORS_DOMAIN
          HASURA_GRAPHQL_ENABLE_TELEMETRY              = var.DATALAYER_HASURA_ENABLE_TELEMETRY
          HASURA_GRAPHQL_EXPERIMENTAL_FEATURES         = var.DATALAYER_HASURA_EXPERIMENTAL_FEATURES
          HASURA_GRAPHQL_DEFAULT_NAMING_CONVENTION     = var.DATALAYER_HASURA_DEFAULT_NAMING_CONVENTION
          HASURA_GRAPHQL_BIGQUERY_STRING_NUMERIC_INPUT = var.DATALAYER_HASURA_BIGQUERY_STRING_NUMERIC_INPUT
          HASURA_GRAPHQL_DEV_MODE                      = var.DATALAYER_HASURA_DEV_MODE
          HASURA_GRAPHQL_ENABLED_LOG_TYPES             = var.DATALAYER_HASURA_ENABLED_LOG_TYPES
          HASURA_GRAPHQL_ADMIN_INTERNAL_ERRORS         = var.DATALAYER_HASURA_ADMIN_INTERNAL_ERRORS
          } : {
          name  = key
          value = value
        }
      ]
      port_mappings = [
        {
          containerPort = var.DATALAYER_HASURA_EXPOSED_PORT
          hostPort      = var.DATALAYER_HASURA_EXPOSED_PORT
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "${var.app_name}-api"
        }
      }
      tags = {
        Name = "${var.app_name}-${var.app_environment}-api"
      }
    }
  ])
}

# Processing Task Definitions
resource "aws_ecs_task_definition" "processing_tasks" {
  for_each                 = { for chain in var.CHAINS : chain.id => chain }
  family                   = "processing-${each.value.id}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = var.processing_service_role_arn

  container_definitions = jsonencode([
    {
      name      = "processing-${each.value.id}"
      image     = "${var.processing_repository_url}:${var.processing_image_tag}"
      essential = true
      environment = [
        {
          name  = "NODE_ENV"
          value = var.NODE_ENV
        },
        {
          name  = "RETRY_MAX_ATTEMPTS"
          value = var.RETRY_MAX_ATTEMPTS
        },
        {
          name  = "RETRY_BASE_DELAY_MS"
          value = var.RETRY_BASE_DELAY_MS
        },
        {
          name  = "RETRY_MAX_DELAY_MS"
          value = var.RETRY_MAX_DELAY_MS
        },
        {
          name  = "RETRY_FACTOR"
          value = var.RETRY_FACTOR
        },
        {
          name  = "CHAINS"
          value = jsonencode([each.value])
        },

        {
          name  = "DATABASE_URL"
          value = var.DATABASE_URL
        },
        {
          name  = "INDEXER_GRAPHQL_URL"
          value = var.INDEXER_GRAPHQL_URL
        },
        # {
        #   name  = "INDEXER_ADMIN_SECRET"
        #   value = var.INDEXER_ADMIN_SECRET
        # },
        {
          name  = "METADATA_SOURCE"
          value = var.METADATA_SOURCE
        },
        {
          name  = "PUBLIC_GATEWAY_URLS"
          value = jsonencode(var.PUBLIC_GATEWAY_URLS)
        },
        {
          name  = "PRICING_SOURCE"
          value = var.PRICING_SOURCE
        },
        {
          name  = "COINGECKO_API_KEY"
          value = var.COINGECKO_API_KEY
        },
        {
          name  = "COINGECKO_API_TYPE"
          value = var.COINGECKO_API_TYPE
        },
        {
          name  = "LOG_LEVEL"
          value = var.LOG_LEVEL
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "${var.app_name}-processing-${each.value.id}"
        }
      }
      tags = {
        Name = "${var.app_name}-${var.app_environment}-processing-${each.value.id}"
      }
    }
  ])
}
