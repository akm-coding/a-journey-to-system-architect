# Production environment -- mirrors staging with production-appropriate values
# =============================================================================
# Production Environment: Non-Sensitive Variable Values
# =============================================================================
#
# Sensitive values (db_username, db_password) are NOT stored here.
# Pass them via environment variables:
#
#   TF_VAR_db_username=produser TF_VAR_db_password=prodpass terraform plan
#
# =============================================================================

project_name  = "journey"
aws_region    = "ap-southeast-1"
environment   = "production"
instance_type = "t3.micro"
key_pair_name = "journey-key"
db_name       = "ecommerce"
