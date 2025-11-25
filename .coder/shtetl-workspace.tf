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

# Variables for repository URLs and branch (can be overridden when creating workspace)
variable "shtetl_branch" {
  type        = string
  default     = "main"
  description = "Branch to checkout for all repositories"
}

variable "shtetl_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/shtetl.git"
  description = "Main shtetl repository URL"
}

variable "shtetl_infra_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/shtetl-infra.git"
  description = "Infrastructure repository URL"
}

variable "shtetl_api_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/shtetl-api.git"
  description = "API services repository URL"
}

variable "shtetl_web_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/shtetl-web.git"
  description = "Web application repository URL"
}

variable "shtetl_mobile_repo" {
  type        = string
  default     = "git@github.com:jcom-dev/shtetl-mobile.git"
  description = "Mobile application repository URL"
}

# Workspace metadata
data "coder_workspace" "me" {}

# Docker network for all services
resource "docker_network" "shtetl_network" {
  name = "coder-${data.coder_workspace.me.id}"
}

# PostgreSQL 18 container
resource "docker_container" "postgres" {
  image    = "postgres:18-alpine"
  name     = "coder-${data.coder_workspace.me.id}-postgres"
  hostname = "postgres"

  env = [
    "POSTGRES_USER=shtetl",
    "POSTGRES_PASSWORD=shtetl_dev",
    "POSTGRES_DB=shtetl_dev"
  ]

  ports {
    internal = 5432
    external = 5432
  }

  networks_advanced {
    name = docker_network.shtetl_network.name
  }

  volumes {
    volume_name    = "coder-${data.coder_workspace.me.id}-postgres-data"
    container_path = "/var/lib/postgresql/data"
  }
}

# Redis 8.4 container
resource "docker_container" "redis" {
  image    = "redis:8.4-alpine"
  name     = "coder-${data.coder_workspace.me.id}-redis"
  hostname = "redis"

  ports {
    internal = 6379
    external = 6379
  }

  networks_advanced {
    name = docker_network.shtetl_network.name
  }

  volumes {
    volume_name    = "coder-${data.coder_workspace.me.id}-redis-data"
    container_path = "/data"
  }
}

# Main development container
resource "docker_container" "workspace" {
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace.me.id}"

  # Run as the coder user
  user = "coder"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # Database connection
    "DATABASE_URL=postgresql://shtetl:shtetl_dev@postgres:5432/shtetl_dev",
    "POSTGRES_HOST=postgres",
    "POSTGRES_PORT=5432",
    "POSTGRES_USER=shtetl",
    "POSTGRES_PASSWORD=shtetl_dev",
    "POSTGRES_DB=shtetl_dev",
    # Redis connection
    "REDIS_URL=redis://redis:6379",
    "REDIS_HOST=redis",
    "REDIS_PORT=6379",
    # Service ports (sequential from 8100)
    "WEB_PORT=8100",
    "ZMANIM_REST_PORT=8101",
    "SHUL_REST_PORT=8103",
    "KEHILLA_PORT=8105",
    # GitHub repository URLs (can be overridden via Coder parameters)
    "SHTETL_REPO=${var.shtetl_repo}",
    "SHTETL_INFRA_REPO=${var.shtetl_infra_repo}",
    "SHTETL_API_REPO=${var.shtetl_api_repo}",
    "SHTETL_WEB_REPO=${var.shtetl_web_repo}",
    "SHTETL_MOBILE_REPO=${var.shtetl_mobile_repo}",
    # Branch to checkout (defaults to main)
    "SHTETL_BRANCH=${var.shtetl_branch}",
  ]

  networks_advanced {
    name = docker_network.shtetl_network.name
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
    value = "http://localhost:8100"
  }

  item {
    key   = "Zmanim Service"
    value = "REST: 8101"
  }

  item {
    key   = "Shul Service"
    value = "REST: 8103"
  }

  item {
    key   = "Kehilla Service"
    value = "REST: 8105"
  }

  item {
    key   = "PostgreSQL"
    value = "localhost:5432"
  }

  item {
    key   = "Redis"
    value = "localhost:6379"
  }
}

# Web-based access to services
resource "coder_app" "web_app" {
  agent_id     = coder_agent.main.id
  slug         = "web"
  display_name = "Web App (Next.js)"
  url          = "http://localhost:8100"
  icon         = "/icon/nextjs.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8100"
    interval  = 10
    threshold = 6
  }
}

resource "coder_app" "zmanim_service" {
  agent_id     = coder_agent.main.id
  slug         = "zmanim"
  display_name = "Zmanim Service (REST)"
  url          = "http://localhost:8101"
  icon         = "/icon/http.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8101/health"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "shul_service" {
  agent_id     = coder_agent.main.id
  slug         = "shul"
  display_name = "Shul Service (REST)"
  url          = "http://localhost:8103"
  icon         = "/icon/http.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8103/health"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "kehilla_service" {
  agent_id     = coder_agent.main.id
  slug         = "kehilla"
  display_name = "Kehilla Service (REST)"
  url          = "http://localhost:8105"
  icon         = "/icon/http.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8105/health"
    interval  = 5
    threshold = 6
  }
}
