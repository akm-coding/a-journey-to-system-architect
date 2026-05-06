# Processes and Permissions Cheatsheet

## Processes

| Command | Description |
|---------|-------------|
| `ps aux` | List all running processes |
| `ps aux \| grep name` | Find a specific process |
| `top` | Real-time process viewer (q to quit) |
| `htop` | Friendlier real-time viewer (install with yum) |
| `kill PID` | Send SIGTERM (graceful shutdown) |
| `kill -9 PID` | Send SIGKILL (force kill) |
| `kill -HUP PID` | Send SIGHUP (reload config) |
| `command &` | Run command in background |
| `jobs` | List background jobs in current shell |
| `fg %1` | Bring background job 1 to foreground |
| `pgrep -a name` | Find PIDs by process name |
| `pkill name` | Kill all processes matching name |

## Services (systemd)

### systemctl

| Command | Description |
|---------|-------------|
| `systemctl start nginx` | Start service now |
| `systemctl stop nginx` | Stop service now |
| `systemctl restart nginx` | Stop then start |
| `systemctl reload nginx` | Reload config without restart |
| `systemctl status nginx` | Show status and recent logs |
| `systemctl enable nginx` | Start on boot |
| `systemctl disable nginx` | Do not start on boot |
| `systemctl enable --now nginx` | Enable AND start immediately |
| `systemctl is-active nginx` | Check if running |
| `systemctl is-enabled nginx` | Check if boot-enabled |
| `systemctl list-units --type=service` | List all services |
| `systemctl list-units --failed` | List failed services |

### journalctl (Service Logs)

| Command | Description |
|---------|-------------|
| `journalctl -u nginx` | All logs for a service |
| `journalctl -u nginx -f` | Follow logs in real time |
| `journalctl -u nginx -n 50` | Last 50 lines |
| `journalctl -u nginx --no-pager` | Output without paging |
| `journalctl -u nginx --since "1 hour ago"` | Logs since time |
| `journalctl -u nginx --since today` | Today's logs |
| `journalctl -b` | Logs since last boot |
| `journalctl -p err` | Only error-level messages |

## Permissions

### Reading Permission Strings

```
-rwxr-xr-x  =  owner(rwx) group(r-x) others(r-x)  =  755
-rw-r--r--  =  owner(rw-) group(r--) others(r--)  =  644
-r--------  =  owner(r--) group(---) others(---)  =  400
drwxr-xr-x  =  directory with 755 permissions
```

### Common Permission Patterns

| Numeric | Symbolic | Use Case |
|---------|----------|----------|
| `755` | `rwxr-xr-x` | Executable files, public directories |
| `644` | `rw-r--r--` | Regular files, configs |
| `400` | `r--------` | SSH private keys (.pem files) |
| `600` | `rw-------` | Credential files, secrets |
| `700` | `rwx------` | Private directories (~/.ssh/) |
| `775` | `rwxrwxr-x` | Shared group directories |
| `664` | `rw-rw-r--` | Shared group files |

### chmod (Change Permissions)

| Command | Description |
|---------|-------------|
| `chmod 644 file` | Set exact permissions (numeric) |
| `chmod +x file` | Add execute for all |
| `chmod u+x file` | Add execute for owner only |
| `chmod g+w file` | Add write for group |
| `chmod o-r file` | Remove read for others |
| `chmod -R 755 dir/` | Recursive permission change |

### chown (Change Ownership)

| Command | Description |
|---------|-------------|
| `chown user file` | Change owner |
| `chown user:group file` | Change owner and group |
| `chown -R user:group dir/` | Recursive ownership change |
| `chgrp group file` | Change group only |

## Environment Variables

### Viewing

| Command | Description |
|---------|-------------|
| `echo $VAR_NAME` | Print one variable |
| `env` | List all environment variables |
| `env \| grep PATTERN` | Search variables |
| `printenv VAR_NAME` | Print one variable (alternative) |

### Setting

| Command | Scope | Persists? |
|---------|-------|-----------|
| `export VAR=value` | Current session + children | No |
| `VAR=value command` | Single command only | No |
| Add to `~/.bashrc` | User's future sessions | Yes |
| Add to `/etc/environment` | All users, all sessions | Yes |

### Common Environment Variables

| Variable | Purpose |
|----------|---------|
| `$HOME` | User's home directory |
| `$PATH` | Directories searched for commands |
| `$USER` | Current username |
| `$SHELL` | Current shell path |
| `$PWD` | Current working directory |
| `$NODE_ENV` | Node.js environment (production/development) |
| `$DATABASE_URL` | Database connection string |
| `$PORT` | Application listen port |
