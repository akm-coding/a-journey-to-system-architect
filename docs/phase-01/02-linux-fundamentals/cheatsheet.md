# Linux Fundamentals Cheatsheet

## Navigation

| Command | Description |
|---------|-------------|
| `pwd` | Print current working directory |
| `ls` | List files in current directory |
| `ls -la` | List all files (including hidden) with details |
| `ls -lh` | List with human-readable file sizes |
| `cd /path` | Change to directory |
| `cd ~` | Go to home directory |
| `cd -` | Go to previous directory |
| `find /path -name "*.log"` | Find files by name pattern |
| `find /path -type f -mtime -1` | Find files modified in last 24 hours |
| `which command` | Show full path of an executable |
| `tree -L 2` | Show directory tree, 2 levels deep |

## File Operations

| Command | Description |
|---------|-------------|
| `touch file.txt` | Create empty file (or update timestamp) |
| `mkdir -p dir/subdir` | Create nested directories |
| `cp file.txt copy.txt` | Copy a file |
| `cp -r dir/ dir-backup/` | Copy a directory recursively |
| `mv old.txt new.txt` | Move or rename |
| `rm file.txt` | Delete a file |
| `rm -rf directory/` | Delete directory and contents (careful!) |
| `ln -s /path/to/target link-name` | Create symbolic link |

## Viewing and Searching Text

| Command | Description |
|---------|-------------|
| `cat file.txt` | Print entire file |
| `less file.txt` | Page through file (q to quit) |
| `head -20 file.txt` | Show first 20 lines |
| `tail -20 file.txt` | Show last 20 lines |
| `tail -f /var/log/messages` | Follow log file in real time |
| `grep "pattern" file.txt` | Search for text in file |
| `grep -r "pattern" /path/` | Search recursively in directory |
| `grep -i "pattern" file.txt` | Case-insensitive search |
| `grep -n "pattern" file.txt` | Show line numbers with matches |

## Text Editing (nano)

| Action | Keys |
|--------|------|
| Open file | `nano filename` |
| Save | `Ctrl+O`, then Enter |
| Exit | `Ctrl+X` |
| Cut line | `Ctrl+K` |
| Paste line | `Ctrl+U` |
| Search | `Ctrl+W` |

## Package Management (Amazon Linux 2023 / yum)

| Command | Description |
|---------|-------------|
| `sudo yum update -y` | Update all packages |
| `sudo yum install -y pkg` | Install a package |
| `sudo yum remove pkg` | Remove a package |
| `yum search keyword` | Search available packages |
| `yum list installed` | List installed packages |
| `yum info pkg` | Show package details |

## Archives

| Command | Description |
|---------|-------------|
| `tar -czf archive.tar.gz dir/` | Create gzipped tar archive |
| `tar -xzf archive.tar.gz` | Extract gzipped tar archive |
| `tar -tzf archive.tar.gz` | List contents without extracting |
| `zip -r archive.zip dir/` | Create zip archive |
| `unzip archive.zip` | Extract zip archive |

## Disk Space

| Command | Description |
|---------|-------------|
| `df -h` | Show disk usage for all filesystems |
| `du -sh /path` | Show total size of a directory |
| `du -sh /*` | Size of each top-level directory |
| `du -h --max-depth=1 /var` | Size of each subdirectory |

## SSH

| Command | Description |
|---------|-------------|
| `ssh -i key.pem user@host` | Connect with key file |
| `ssh my-ec2` | Connect using SSH config alias |
| `chmod 400 key.pem` | Set correct key permissions |
| `scp -i key.pem file user@host:/path` | Copy file to remote |
| `scp -i key.pem user@host:/path local` | Copy file from remote |
| `ssh-keygen -t rsa -b 4096` | Generate a new SSH key pair |

## Networking Diagnostics (Preview)

These commands are covered in depth in the networking section, but are useful to know early:

| Command | Description |
|---------|-------------|
| `curl http://localhost` | Make HTTP request |
| `curl -I http://example.com` | Show HTTP response headers only |
| `ping -c 4 google.com` | Test network connectivity (4 packets) |
| `dig example.com` | DNS lookup (detailed) |
| `nslookup example.com` | DNS lookup (simple) |
| `ss -tlnp` | Show listening TCP ports |
| `ip addr` | Show network interfaces and IPs |
