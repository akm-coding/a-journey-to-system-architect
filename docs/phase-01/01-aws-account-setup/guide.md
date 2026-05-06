# AWS Account Setup Guide

## Why This Matters

When you create an AWS account, you get a **root user** that has unrestricted access to everything -- billing, resource creation, account deletion, the works. Using this root account for daily work is like running every program on your computer as administrator: one mistake and you could accidentally delete production databases, rack up thousands in charges, or expose credentials that give an attacker full control.

The principle of **least privilege** means every user (including you) should have only the permissions they actually need. For a solo learner, that means creating a separate IAM user with admin permissions -- still powerful, but isolated from root account actions like closing the account or changing billing settings. If your IAM user credentials leak, you can revoke them from the root account. If your root credentials leak, you have a much bigger problem.

**Budget alerts** are equally critical. AWS charges are usage-based and accrue silently. A forgotten NAT Gateway ($32/month), an accidentally large EC2 instance, or an undeleted RDS database can surprise you. Setting a budget alert at $10/month means AWS will email you before costs become painful. Do this before creating any resources.

## What You Need to Know

### IAM Users vs IAM Identity Center

AWS offers two approaches for human access:

**IAM Users** (what we will use):
- Each user gets a username, password, and optionally access keys
- Credentials are long-lived (they persist until you rotate or delete them)
- Simple to set up for a single learner
- Access keys go in `~/.aws/credentials`

**IAM Identity Center** (formerly AWS SSO):
- Centralized access management for organizations
- Issues temporary credentials that expire automatically
- The recommended approach for teams and production environments
- More complex initial setup

For this learning project, we use an **IAM user** because it is simpler for a solo learner and teaches the foundational concepts. In a real team environment, IAM Identity Center with temporary credentials is the best practice.

### Multi-Factor Authentication (MFA)

MFA adds a second verification step beyond your password. Even if someone steals your password, they cannot log in without the MFA code from your phone. Enable MFA on both your root account and your IAM user.

You can use:
- A virtual MFA app (Google Authenticator, Authy) -- recommended
- A hardware security key (YubiKey)

### AWS CLI v2

The AWS Command Line Interface lets you manage AWS resources from your terminal instead of clicking through the web console. You will use it extensively throughout this project. The CLI reads credentials from `~/.aws/credentials` and configuration from `~/.aws/config`.

### AWS Budgets

AWS Budgets lets you set a dollar threshold and receive email notifications when your actual or forecasted spending exceeds it. We will set a $10/month budget as a safety net.

## IAM Hierarchy

```
AWS Account (Root User)
|
|-- Has FULL unrestricted access
|-- Should only be used for:
|     - Initial setup
|     - Billing changes
|     - Account recovery
|
+-- IAM Users
    |
    |-- admin-user (you)
    |     |-- Policy: AdministratorAccess
    |     |-- MFA: Enabled
    |     |-- Access keys: For CLI
    |
    +-- (future users if needed)
         |-- Policy: Limited permissions
```

## Key Concepts

- **Root user**: The email/password you signed up with. Unrestricted access. Lock it away.
- **IAM user**: A separate identity within your account. Can have its own password and access keys.
- **Policy**: A JSON document that defines what actions are allowed or denied on which resources.
- **AdministratorAccess**: A managed policy that allows all actions on all resources (except some root-only operations).
- **Access keys**: A key ID + secret key pair used by the CLI. Treat these like passwords.
- **MFA**: Multi-factor authentication. A second factor (phone app) required at login.

## Further Reading

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [AWS CLI v2 Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [AWS Budgets Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [MFA for IAM Users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa.html)
