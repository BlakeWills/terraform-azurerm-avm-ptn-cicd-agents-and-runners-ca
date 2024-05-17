variable "github_runner_scope" {
  type        = string
  description = "The scope of the runner"
  validation {
    condition     = contains(["org", "ent", "repo"], var.github_runner_scope)
    error_message = "github_runner_scope must be one of 'org', 'ent', or 'repo'"
  }
}

variable "github_api_url" {
  type        = string
  description = "The URL of the GitHub API, defaults to https://api.github.com. You should only need to modify this if you have your own GitHub Appliance."
}

variable "github_owner" {
  type        = string
  description = "The owner of the GitHub repository, or the organization that owns the repository"
}

variable "github_repos" {
  type        = set(string)
  description = "The list of repositories to scale"
}