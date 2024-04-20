variable "github_runner_scope" {
  type        = string
  description = "The scope of the runner"
  nullable    = true
  default     = null
}

variable "github_api_url" {
  type        = string
  description = "The URL of the GitHub API, defaults to https://api.github.com. You should only need to modify this if you have your own GitHub Appliance."
  default     = "https://api.github.com"
}

variable "github_owner" {
  type        = string
  description = "The owner of the GitHub repository, or the organization that owns the repository"
  nullable    = true
  default     = null
}

variable "github_repos" {
  type        = set(string)
  description = "The list of repositories to scale"
  nullable    = true
  default     = null
}