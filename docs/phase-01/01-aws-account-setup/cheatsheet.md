# AWS Account Setup Cheatsheet

## Authentication & Identity

```bash
# Verify who you are (the "whoami" of AWS)
aws sts get-caller-identity

# Check CLI version
aws --version
```

## AWS CLI Configuration

```bash
# Initial configuration (interactive)
aws configure

# Set a specific profile
aws configure --profile myprofile

# Use a specific profile for a command
aws sts get-caller-identity --profile myprofile

# Set default profile via environment variable
export AWS_PROFILE=myprofile
```

**Credential file locations**:
- Credentials: `~/.aws/credentials`
- Config: `~/.aws/config`

**~/.aws/credentials format**:
```ini
[default]
aws_access_key_id = AKIAEXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE
```

**~/.aws/config format**:
```ini
[default]
region = us-east-1
output = json
```

## IAM Commands

```bash
# List all IAM users
aws iam list-users

# Get details about current user
aws iam get-user

# List access keys for a user
aws iam list-access-keys --user-name admin-learner

# List attached user policies
aws iam list-attached-user-policies --user-name admin-learner

# List MFA devices for a user
aws iam list-mfa-devices --user-name admin-learner
```

## Budget Commands

```bash
# List all budgets
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text)

# Create a monthly cost budget (see exercise.md for full example)
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "monthly-spend-alert",
    "BudgetLimit": {"Amount": "10", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[...]'

# Delete a budget
aws budgets delete-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget-name monthly-spend-alert
```

## Quick Checks

```bash
# Am I authenticated?
aws sts get-caller-identity

# Am I using root? (ARN will contain "root" if yes -- BAD)
aws sts get-caller-identity --query Arn --output text

# What region am I using?
aws configure get region

# What is my account ID?
aws sts get-caller-identity --query Account --output text
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Unable to locate credentials" | Run `aws configure` or check `~/.aws/credentials` |
| "An error occurred (ExpiredToken)" | Regenerate access keys in IAM console |
| "An error occurred (AccessDenied)" | Check your user has the right policies attached |
| CLI shows root ARN | Create access keys for your IAM user, not root |
| "command not found: aws" | Install AWS CLI v2 (see exercise.md) |
