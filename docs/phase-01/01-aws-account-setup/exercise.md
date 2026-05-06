# AWS Account Setup Exercise

## Overview

In this exercise, you will secure your AWS account and set up the tools you need for the rest of this project. By the end, you will have a non-root IAM user with MFA, a working AWS CLI, and a budget alert to prevent surprise charges.

**Time estimate**: 30-45 minutes

## Step 1: Enable MFA on the Root Account

Your root account should already exist (you signed up for AWS). Now lock it down.

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/) with your root email and password
2. Click your account name in the top-right corner, then **Security credentials**
3. Under **Multi-factor authentication (MFA)**, click **Assign MFA device**
4. Choose **Authenticator app**
5. Open your authenticator app (Google Authenticator, Authy, etc.) and scan the QR code
6. Enter two consecutive MFA codes to verify
7. Click **Assign MFA**

**Verify**: Sign out and sign back in. You should be prompted for an MFA code.

## Step 2: Create an IAM User

1. Go to the [IAM Console](https://console.aws.amazon.com/iam/)
2. In the left sidebar, click **Users**, then **Create user**
3. Username: `admin-learner` (or your preferred name)
4. Check **Provide user access to the AWS Management Console**
5. Select **I want to create an IAM user** (not Identity Center)
6. Set a strong password, uncheck "User must create a new password at next sign-in"
7. Click **Next**
8. On the permissions page, click **Attach policies directly**
9. Search for and check **AdministratorAccess**
10. Click **Next**, then **Create user**
11. Save the sign-in URL (it looks like `https://YOUR_ACCOUNT_ID.signin.aws.amazon.com/console`)

**Enable MFA on the IAM user**:
1. Click on your new user in the Users list
2. Go to the **Security credentials** tab
3. Under **Multi-factor authentication (MFA)**, click **Assign MFA device**
4. Follow the same process as Step 1

## Step 3: Create Access Keys for CLI

1. In the IAM Console, click on your user
2. Go to the **Security credentials** tab
3. Under **Access keys**, click **Create access key**
4. Select **Command Line Interface (CLI)**
5. Acknowledge the recommendation about alternatives, click **Next**
6. Click **Create access key**
7. **Copy both the Access Key ID and Secret Access Key NOW** -- you will not see the secret again

**WARNING**: NEVER commit these keys to git. They are stored in `~/.aws/credentials` which is already in our `.gitignore`.

## Step 4: Install and Configure AWS CLI v2

### Install AWS CLI v2

**macOS**:
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
rm AWSCLIV2.pkg
```

**Linux**:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

**Windows (WSL)**: Follow the Linux instructions above inside WSL.

### Configure the CLI

```bash
aws configure
```

Enter when prompted:
- **AWS Access Key ID**: (paste from Step 3)
- **AWS Secret Access Key**: (paste from Step 3)
- **Default region name**: `us-east-1` (or your preferred region)
- **Default output format**: `json`

This creates two files:
- `~/.aws/credentials` -- your access keys
- `~/.aws/config` -- your default region and output format

### Verify It Works

```bash
aws sts get-caller-identity
```

You should see output like:
```json
{
    "UserId": "AIDAEXAMPLE123456",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/admin-learner"
}
```

**Confirm the ARN shows your IAM user name, NOT "root".** If you see "root" in the ARN, you configured the CLI with root credentials -- go back to Step 3 and create keys for your IAM user instead.

## Step 5: Create a Budget Alert

### Option A: AWS Console (recommended for first time)

1. Go to [AWS Budgets](https://console.aws.amazon.com/billing/home#/budgets)
2. Click **Create budget**
3. Select **Use a template (simplified)**
4. Choose **Monthly cost budget**
5. Budget name: `monthly-spend-alert`
6. Enter budgeted amount: `10.00`
7. Enter email recipients: your email address
8. Click **Create budget**

### Option B: AWS CLI

```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "monthly-spend-alert",
    "BudgetLimit": {
      "Amount": "10",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 80,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        {
          "SubscriptionType": "EMAIL",
          "Address": "YOUR_EMAIL@example.com"
        }
      ]
    },
    {
      "Notification": {
        "NotificationType": "FORECASTED",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 100,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        {
          "SubscriptionType": "EMAIL",
          "Address": "YOUR_EMAIL@example.com"
        }
      ]
    }
  ]'
```

Replace `YOUR_EMAIL@example.com` with your actual email.

## Step 6: Verify the Budget

1. Go to [AWS Budgets Dashboard](https://console.aws.amazon.com/billing/home#/budgets)
2. You should see your `monthly-spend-alert` budget listed
3. Current spend should be $0.00 (or close to it)

**CLI verification**:
```bash
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text)
```

## Clean Up

Nothing to tear down from this exercise. Your IAM user and budget alert should remain active for the entire project. The budget alert is free (your first two budgets in AWS are free).

## Verification Checklist

Before marking this exercise complete:

- [ ] Root account has MFA enabled
- [ ] IAM user created with AdministratorAccess policy
- [ ] IAM user has MFA enabled
- [ ] AWS CLI installed and configured
- [ ] `aws sts get-caller-identity` shows your IAM user ARN (not root)
- [ ] Budget alert set at $10/month
- [ ] Budget visible in the Billing dashboard
