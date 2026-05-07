# =============================================================================
# Staging Environment: Non-Sensitive Variable Values
# =============================================================================
#
# Sensitive values (db_username, db_password) are NOT stored here.
# Pass them via environment variables when running terraform:
#
#   TF_VAR_db_username=myuser TF_VAR_db_password=mypass terraform plan
#   TF_VAR_db_username=myuser TF_VAR_db_password=mypass terraform apply
#
# Or use a .tfvars file that is NOT committed to git:
#
#   echo 'db_username = "myuser"' >> staging.secret.tfvars
#   echo 'db_password = "mypass"' >> staging.secret.tfvars
#   terraform plan -var-file="staging.secret.tfvars"
#
# =============================================================================

project_name  = "journey"
aws_region    = "ap-southeast-1"
environment   = "staging"
instance_type = "t3.micro"
key_pair_name = "journey-key"
db_name       = "ecommerce"
