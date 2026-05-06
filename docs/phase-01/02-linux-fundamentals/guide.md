# Linux Fundamentals Guide

## Why This Matters

Every system you will deploy, monitor, and troubleshoot in your career runs on Linux. AWS EC2 instances, Docker containers, Kubernetes pods, CI/CD runners -- they all boot into a Linux environment. If you cannot navigate a Linux filesystem, read logs, install packages, or edit configuration files, you cannot operate infrastructure. There is no shortcut around this.

SSH (Secure Shell) is your primary tool for accessing remote servers. Unlike password-based authentication, SSH key-based auth uses a cryptographic key pair: a private key that stays on your machine and a public key that lives on the server. This is more secure because keys are nearly impossible to brute-force, unlike passwords. AWS enforces key-based SSH for EC2 instances by default -- you will use this in every phase of this course.

Understanding the filesystem is equally critical. When you deploy an application, you need to know where logs are written, where configuration files live, where your application binary should go, and how to check disk space before it fills up and crashes your service. These are not theoretical concerns -- they are daily operations tasks.

## SSH: Key-Based Authentication

SSH uses public-key cryptography to authenticate you to a remote server without transmitting a password.

```
  Your Machine                         EC2 Instance
  +-----------+                        +------------+
  | Private   |  --- SSH handshake --> | Public Key  |
  | Key (.pem)|                        | (in         |
  |           |  <-- challenge ------  |  authorized |
  |           |  --- signed response ->|  _keys)     |
  |           |  <-- access granted -- |             |
  +-----------+                        +------------+
```

**How it works:**

1. You generate a key pair (or AWS generates one when you create a key pair in EC2).
2. The public key is placed on the server in `~/.ssh/authorized_keys`.
3. When you connect, the server sends a challenge encrypted with your public key.
4. Your SSH client signs the challenge with your private key and sends it back.
5. The server verifies the signature. If it matches, you are in.

**Critical rule:** Your private key file must have restricted permissions (`chmod 400`). If anyone can read your private key, SSH will refuse to use it.

## The Linux Filesystem

Linux organizes everything as a single directory tree starting from `/` (root). Unlike Windows, there are no drive letters. Everything is mounted under `/`.

| Directory | Purpose | Why You Care |
|-----------|---------|-------------|
| `/` | Root of the filesystem | Everything lives under here |
| `/home` | User home directories | Your files, SSH keys, dotfiles (e.g., `/home/ec2-user`) |
| `/var` | Variable data (logs, caches, spool) | Application logs live in `/var/log` -- you will read these constantly |
| `/etc` | System and application config files | Nginx config, SSH config, systemd units -- all in `/etc` |
| `/opt` | Optional/third-party software | Many apps install here (e.g., `/opt/myapp`) |
| `/tmp` | Temporary files (cleared on reboot) | Useful for scratch work, but never store anything important here |
| `/usr` | User programs and libraries | Binaries in `/usr/bin`, libraries in `/usr/lib` |
| `/proc` | Virtual filesystem for process info | `cat /proc/cpuinfo` shows CPU details |

## Navigation Commands

| Command | What It Does | Example |
|---------|-------------|---------|
| `pwd` | Print current directory | `pwd` outputs `/home/ec2-user` |
| `ls` | List directory contents | `ls -la` shows all files with permissions |
| `cd` | Change directory | `cd /var/log` moves to the log directory |
| `find` | Search for files by name/type/size | `find /var/log -name "*.log" -mtime -1` finds logs modified today |
| `which` | Show full path of a command | `which nginx` outputs `/usr/sbin/nginx` |
| `tree` | Show directory structure visually | `tree -L 2 /home` shows 2 levels deep |

## File Operations

| Command | What It Does | Example |
|---------|-------------|---------|
| `cat` | Print file contents | `cat /etc/os-release` |
| `less` | Page through a file (q to quit) | `less /var/log/messages` |
| `head` | Show first N lines | `head -20 /var/log/messages` |
| `tail` | Show last N lines (-f to follow) | `tail -f /var/log/messages` watches live |
| `grep` | Search text inside files | `grep "error" /var/log/messages` |
| `cp` | Copy files/directories | `cp -r /opt/app /opt/app-backup` |
| `mv` | Move or rename | `mv old-name.txt new-name.txt` |
| `rm` | Delete files (-r for directories) | `rm -rf /tmp/scratch` (be careful!) |
| `mkdir` | Create directories (-p for nested) | `mkdir -p /home/ec2-user/projects/app` |
| `touch` | Create empty file or update timestamp | `touch newfile.txt` |

## Text Editing

**nano** is the beginner-friendly editor. Open a file with `nano filename.txt`, edit it, save with `Ctrl+O`, exit with `Ctrl+X`. This is all you need to start.

**vim** is the power-user editor. It is installed on virtually every Linux system. You will encounter it eventually (e.g., when git opens it for commit messages). For now, know that pressing `i` enters insert mode, `Esc` returns to command mode, and `:wq` saves and quits. You can always fall back to nano.

## Package Management

Linux distributions use package managers to install, update, and remove software.

| Distribution | Package Manager | Install Command |
|-------------|----------------|-----------------|
| Amazon Linux 2023 | dnf (yum) | `sudo yum install -y nginx` |
| Ubuntu/Debian | apt | `sudo apt install -y nginx` |

**Our exercises use Amazon Linux 2023**, which uses `yum` (a frontend for `dnf`).

Common operations:

```bash
sudo yum update -y              # Update all installed packages
sudo yum install -y tree htop   # Install specific packages
sudo yum remove tree            # Remove a package
yum search nginx                # Search for available packages
yum list installed              # List all installed packages
```

## Archives

```bash
# Create a tar.gz archive
tar -czf backup.tar.gz /home/ec2-user/projects/

# Extract a tar.gz archive
tar -xzf backup.tar.gz

# Create a zip archive
zip -r backup.zip /home/ec2-user/projects/

# Extract a zip archive
unzip backup.zip
```

Flags: `-c` create, `-x` extract, `-z` gzip compression, `-f` filename, `-v` verbose.

## Disk Space

```bash
df -h           # Show disk usage for all mounted filesystems (human-readable)
du -sh /var/log # Show total size of a specific directory
du -sh /*       # Show size of each top-level directory
```

Running out of disk space is one of the most common causes of application crashes. Check `df -h` regularly, especially `/var/log` which can grow quickly.

## Further Reading

- [Linux man pages online](https://man7.org/linux/man-pages/) -- the definitive command reference
- [SSH key-based authentication (DigitalOcean)](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server) -- detailed SSH setup walkthrough
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html) -- why directories are where they are
- [Amazon Linux 2023 User Guide](https://docs.aws.amazon.com/linux/al2023/ug/) -- specific to the AMI we use
