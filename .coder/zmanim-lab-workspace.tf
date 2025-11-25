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

# Workspace metadata
data "coder_workspace" "me" {}

# Docker network for workspace
resource "docker_network" "zmanim_network" {
  name = "coder-${data.coder_workspace.me.id}"
}

# Main development container (no local DB/Redis - using Supabase/Upstash)
resource "docker_container" "workspace" {
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace.me.id}"

  # Run as the coder user
  user = "coder"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # External services (set via .env file or Coder secrets)
    # DATABASE_URL - Supabase PostgreSQL connection string
    # UPSTASH_REDIS_REST_URL - Upstash Redis REST endpoint
    # UPSTASH_REDIS_REST_TOKEN - Upstash Redis auth token
    # CLERK_SECRET_KEY - Clerk backend secret
    # NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY - Clerk frontend key
    # Service ports
    "WEB_PORT=3001",
    "API_PORT=8080",
    # Repository configuration
    "ZMANIM_REPO=${var.zmanim_repo}",
    "ZMANIM_BRANCH=${var.zmanim_branch}",
  ]

  networks_advanced {
    name = docker_network.zmanim_network.name
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
    value = "http://localhost:3001"
  }

  item {
    key   = "API"
    value = "http://localhost:8080"
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
resource "coder_app" "web_app" {
  agent_id     = coder_agent.main.id
  slug         = "web"
  display_name = "Web App (Next.js)"
  url          = "http://localhost:3001"
  icon         = "/icon/nextjs.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:3001"
    interval  = 10
    threshold = 6
  }
}

resource "coder_app" "api" {
  agent_id     = coder_agent.main.id
  slug         = "api"
  display_name = "Go API"
  url          = "http://localhost:8080"
  icon         = "/icon/go.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080/api/health"
    interval  = 5
    threshold = 6
  }
}
