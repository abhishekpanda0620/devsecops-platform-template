terraform {
  backend "s3" {
    # bucket         = "devsecops-platform-template"  # Configured via backend-config
    # key            = "devsecops/dev/addons/terraform.tfstate" # Configured via backend-config
    # region         = "us-east-1"                    # Configured via backend-config
    # encrypt        = true
    # use_lockfile   = true
  }
}
