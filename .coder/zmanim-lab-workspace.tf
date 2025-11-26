terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Coder provider configuration
provider "coder" {}

# Docker provider configuration
provider "docker" {}

# Variables
variable "web_port" {
  type        = number
  default     = 3001
  description = "Port for the Web App"
}

variable "api_port" {
  type        = number
  default     = 8080
  description = "Port for the API"
}

variable "zmanim_branch" {
  type        = string
  default     = "main"
  description = "Branch to checkout"
}

variable "zmanim_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/zmanim-lab.git"
  description = "Zmanim Lab repository URL"
}

# Database (Supabase)
variable "database_url" {
  type        = string
  sensitive   = true
  description = "Supabase PostgreSQL connection string"
}

variable "supabase_url" {
  type        = string
  description = "Supabase API URL"
}

variable "supabase_anon_key" {
  type        = string
  sensitive   = true
  description = "Supabase anonymous key"
}

variable "supabase_service_key" {
  type        = string
  sensitive   = true
  description = "Supabase service role key"
}

# Caching (Upstash Redis)
variable "upstash_redis_rest_url" {
  type        = string
  description = "Upstash Redis REST URL"
}

variable "upstash_redis_rest_token" {
  type        = string
  sensitive   = true
  description = "Upstash Redis REST token"
}

# Authentication (Clerk)
variable "clerk_publishable_key" {
  type        = string
  description = "Clerk publishable key"
}

variable "clerk_secret_key" {
  type        = string
  sensitive   = true
  description = "Clerk secret key"
}

variable "clerk_jwks_url" {
  type        = string
  default     = "https://engaged-sloth-39.clerk.accounts.dev/.well-known/jwks.json"
  description = "Clerk JWKS URL for JWT verification"
}

variable "clerk_issuer" {
  type        = string
  default     = "https://engaged-sloth-39.clerk.accounts.dev"
  description = "Clerk issuer for JWT verification"
}

# Workspace metadata
data "coder_workspace" "me" {}

# Docker network for workspace
resource "docker_network" "zmanim_network" {
  name = "coder-${data.coder_workspace.me.id}"
}

locals {
  web_port = var.web_port
  api_port = var.api_port
}

# Main development container (no local DB/Redis - using Supabase/Upstash)
resource "docker_container" "workspace" {
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace.me.id}"

  # Run as the coder user
  user = "coder"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # External services (from Coder template variables)
    "DATABASE_URL=${var.database_url}",
    "SUPABASE_URL=${var.supabase_url}",
    "SUPABASE_ANON_KEY=${var.supabase_anon_key}",
    "SUPABASE_SERVICE_KEY=${var.supabase_service_key}",
    "UPSTASH_REDIS_REST_URL=${var.upstash_redis_rest_url}",
    "UPSTASH_REDIS_REST_TOKEN=${var.upstash_redis_rest_token}",
    "CLERK_SECRET_KEY=${var.clerk_secret_key}",
    "CLERK_JWKS_URL=${var.clerk_jwks_url}",
    "CLERK_ISSUER=${var.clerk_issuer}",
    "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${var.clerk_publishable_key}",
    "NEXT_PUBLIC_SUPABASE_URL=${var.supabase_url}",
    "NEXT_PUBLIC_SUPABASE_ANON_KEY=${var.supabase_anon_key}",
    "NEXT_PUBLIC_API_URL=http://localhost:${local.api_port}",
    # CORS configuration for API
    "ALLOWED_ORIGINS=http://localhost:${local.web_port},http://127.0.0.1:${local.web_port},http://localhost:${local.api_port},http://127.0.0.1:${local.api_port},https://localhost:${local.web_port},https://127.0.0.1:${local.web_port},https://localhost:${local.api_port},https://127.0.0.1:${local.api_port}",
    # Service ports
    "WEB_PORT=${local.web_port}",
    "API_PORT=${local.api_port}",
    # Repository configuration
    "ZMANIM_REPO=${var.zmanim_repo}",
    "ZMANIM_BRANCH=${var.zmanim_branch}",
  ]

  networks_advanced {
    name = docker_network.zmanim_network.name
  }

  # Expose service ports for direct access
  ports {
    internal = local.api_port
    external = local.api_port
    protocol = "tcp"
  }

  ports {
    internal = local.web_port
    external = local.web_port
    protocol = "tcp"
  }

  # Mount workspace directory as a persistent volume
  volumes {
    volume_name    = "coder-${data.coder_workspace.me.id}-workspace"
    container_path = "/home/coder/workspace"
  }

  # Keep container running
  command = ["sh", "-c", coder_agent.main.init_script]
}

# Coder agent for the workspace
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = file("${path.module}/startup.sh")

  # Display apps
  display_apps {
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
    port_forwarding_helper = true
    ssh_helper             = true
  }
}

# Metadata for workspace
resource "coder_metadata" "workspace_info" {
  resource_id = docker_container.workspace.id

  item {
    key   = "Web App"
    value = "http://localhost:${local.web_port}"
  }

  item {
    key   = "API"
    value = "http://localhost:${local.api_port}"
  }

  item {
    key   = "Database"
    value = "Supabase (external)"
  }

  item {
    key   = "Cache"
    value = "Upstash Redis (external)"
  }
}

# Web-based access to services
# Note: These apps are proxied through Coder's web UI
# For direct access, use port forwarding to localhost:3001 and localhost:8080
resource "coder_app" "web_app" {
  agent_id     = coder_agent.main.id
  slug         = "web"
  display_name = "Web App"
  url          = "http://127.0.0.1:${local.web_port}"
  icon         = "/icon/nextjs.svg"
  external     = true
  # Note: external=true conflicts with healthcheck, subdomain, and share
  # External apps open directly in browser, bypassing Coder proxy
}

resource "coder_app" "api" {
  agent_id     = coder_agent.main.id
  slug         = "api"
  display_name = "API"
  url          = "http://localhost:${local.api_port}/health"
  icon         = "/icon/go.svg"
  external     = true
  # Note: external=true conflicts with healthcheck, subdomain, and share
}
