# Linux Fundamentals Exercise

## Prerequisites

- AWS account with IAM user and CLI configured (completed in [01-aws-account-setup](../01-aws-account-setup/exercise.md))
- A terminal application (Terminal on macOS, WSL on Windows)
- Your IAM user must have EC2 permissions (the PowerUserAccess policy from the previous exercise covers this)

## Step 1: Launch an EC2 Instance

1. Open the [EC2 Console](https://console.aws.amazon.com/ec2/).
2. Click **Launch Instance**.
3. Configure:
   - **Name:** `linux-practice`
   - **AMI:** Amazon Linux 2023 (should be the default, confirm it says "Amazon Linux 2023 AMI")
   - **Instance type:** `t2.micro` (Free Tier eligible) or `t3.micro`
   - **Key pair:** Click "Create new key pair"
     - Name: `linux-practice-key`
     - Type: RSA
     - Format: `.pem`
     - Download and save to `~/.ssh/linux-practice-key.pem`
   - **Network settings:** Click "Edit"
     - Keep the default VPC
     - Auto-assign public IP: Enable
     - Security group: Create new, name it `ssh-access`
     - Rule: SSH (port 22) from "My IP" (do NOT use 0.0.0.0/0)
   - **Storage:** 8 GB gp3 (default is fine)
4. Click **Launch Instance**.
5. Wait for the instance state to show **Running** and note the **Public IPv4 address**.

## Step 2: SSH into the Instance

First, fix the key file permissions (SSH refuses keys that are readable by others):

```bash
chmod 400 ~/.ssh/linux-practice-key.pem
```

Now connect:

```bash
ssh -i ~/.ssh/linux-practice-key.pem ec2-user@<PUBLIC-IP>
```

Replace `<PUBLIC-IP>` with your instance's public IPv4 address.

**Troubleshooting:**
- `Permission denied (publickey)` -- Wrong key file or wrong username. Amazon Linux uses `ec2-user`.
- `Connection timed out` -- Security group is not allowing SSH from your IP, or the instance has no public IP.
- `WARNING: UNPROTECTED PRIVATE KEY FILE!` -- Run `chmod 400` on the key file.

You should see a prompt like: `[ec2-user@ip-172-31-xx-xx ~]$`

## Step 3: Explore the Filesystem

Confirm you are on Amazon Linux 2023:

```bash
cat /etc/os-release
```

Check where you are and what is here:

```bash
pwd                    # Should output /home/ec2-user
ls -la                 # List all files including hidden dotfiles
```

Navigate to key directories and look around:

```bash
ls /var/log/           # Application and system logs
ls /etc/               # Configuration files
ls /home/              # User home directories (just ec2-user)
```

Check disk usage:

```bash
df -h                  # How much disk space is used/available?
```

## Step 4: Create and Manipulate Files

Create a practice directory:

```bash
mkdir -p /home/ec2-user/practice/subdir
cd /home/ec2-user/practice
```

Create and edit files:

```bash
touch file1.txt file2.txt file3.txt
echo "Hello from Linux" > file1.txt
nano file2.txt
# Type some text, press Ctrl+O to save, Ctrl+X to exit
```

View file contents:

```bash
cat file1.txt
less file2.txt          # Press q to quit
```

Copy, move, and rename:

```bash
cp file1.txt file1-copy.txt
mv file3.txt renamed-file.txt
ls -la                   # Verify the changes
```

Search inside files:

```bash
echo "error: something went wrong" >> file1.txt
echo "info: everything is fine" >> file1.txt
grep "error" file1.txt   # Finds the error line
grep -r "Hello" .        # Search recursively in current directory
```

## Step 5: Install Packages

Update the system and install useful tools:

```bash
sudo yum update -y
sudo yum install -y tree htop
```

Visualize your directory structure:

```bash
tree /home/ec2-user/practice
```

You should see:

```
/home/ec2-user/practice
|-- file1-copy.txt
|-- file1.txt
|-- file2.txt
|-- renamed-file.txt
`-- subdir
```

Run `htop` to see a real-time process viewer (press `q` to quit).

## Step 6: Set Up SSH Config for Convenience

On **your local machine** (not the EC2 instance), create or edit `~/.ssh/config`:

```bash
nano ~/.ssh/config
```

Add this entry:

```
Host my-ec2
    HostName <PUBLIC-IP>
    User ec2-user
    IdentityFile ~/.ssh/linux-practice-key.pem
```

Now you can connect with just:

```bash
ssh my-ec2
```

This saves typing the full command every time. Update the `HostName` whenever the IP changes (it changes if you stop/start the instance).

## Verification

Run these commands on the EC2 instance to confirm everything worked:

```bash
ls -la /home/ec2-user/practice/
# You should see: file1.txt, file1-copy.txt, file2.txt, renamed-file.txt, subdir/

cat /home/ec2-user/practice/file1.txt
# You should see "Hello from Linux" plus the additional lines

which tree && which htop
# Both should return paths, confirming they are installed
```

## Clean Up

Terminate the EC2 instance to avoid charges:

1. Go to EC2 Console > Instances.
2. Select `linux-practice`.
3. Actions > Instance State > **Terminate instance**.
4. Confirm termination.
5. Wait until the state shows **Terminated**.

Also delete the security group (after the instance is terminated):

1. Go to EC2 Console > Security Groups.
2. Select `ssh-access`.
3. Actions > Delete security group.

## Rebuild Challenge

Terminate everything. Wait 5 minutes. Now do it all again without looking at this guide:

1. Launch an EC2 instance with Amazon Linux 2023.
2. SSH into it.
3. Create a directory structure, create files, search with grep.
4. Install a package with yum.
5. Set up your SSH config.

**Time yourself.** First attempt might take 20-30 minutes. By the third attempt, aim for under 10 minutes. Log your time in [rebuild-log.md](../rebuild-log.md).
