# Processes and Permissions Guide

## Why This Matters

When you deploy an application, your application IS a process. It has a process ID, consumes CPU and memory, reads from disk, and listens on network ports. If you do not understand processes, you cannot debug why your app is slow, why it crashed, or why it is not starting. Every deployment problem eventually comes down to understanding what processes are running and what they are doing.

Permissions exist because Linux is a multi-user system. Even on a server where you are the only human, there are multiple system users -- nginx runs as the `nginx` user, PostgreSQL runs as `postgres`, your app might run as `www-data` or a custom user. Permissions prevent one user's process from reading another user's secrets, overwriting critical system files, or binding to privileged ports. Getting permissions wrong is one of the most common deployment failures: "Permission denied" is an error you will see many times.

Environment variables are how you configure applications in production. You never hardcode database passwords, API keys, or feature flags in source code. Instead, you pass them as environment variables. Every deployment platform -- EC2, ECS, Lambda, Kubernetes -- uses env vars as the primary configuration mechanism. Understanding how they work at the Linux level (process scope, inheritance, persistence) prevents a large category of "it works locally but not in production" bugs.

## Processes

A process is a running instance of a program. Every command you run, every service running in the background, is a process.

**Key concepts:**
- **PID (Process ID):** A unique number assigned to each process. PID 1 is `systemd` (the init system).
- **Parent/Child:** Every process has a parent. When you run `ls` from bash, bash (parent) creates an `ls` process (child).
- **Foreground vs Background:** A foreground process blocks your terminal. Add `&` to run in background.

### Reading `ps aux` Output

```
USER       PID %CPU %MEM    VSZ   RSS TTY  STAT START   TIME COMMAND
root         1  0.0  0.5 171234 10240 ?    Ss   May05   0:03 /usr/lib/systemd/systemd
ec2-user  1234  0.0  0.1  12345  2048 pts/0 S  10:30   0:00 bash
root       567  0.0  0.3  45678  6144 ?    Ss   May05   0:01 sshd: /usr/sbin/sshd
nginx      890  0.0  0.2  34567  4096 ?    S    10:35   0:00 nginx: worker process
```

| Column | Meaning |
|--------|---------|
| `USER` | Which user owns the process |
| `PID` | Process ID |
| `%CPU` | CPU usage percentage |
| `%MEM` | Memory usage percentage |
| `VSZ` | Virtual memory size (allocated) |
| `RSS` | Resident Set Size (actual physical memory used) |
| `TTY` | Terminal associated (? means no terminal -- a daemon) |
| `STAT` | State: S=sleeping, R=running, Z=zombie, T=stopped |
| `COMMAND` | The command that started this process |

### Signals

Signals are how you communicate with processes:

| Signal | Number | Meaning |
|--------|--------|---------|
| `SIGTERM` | 15 | Graceful shutdown -- "please stop, clean up first" (default for `kill`) |
| `SIGKILL` | 9 | Force kill -- "stop immediately, no cleanup" (use as last resort) |
| `SIGHUP` | 1 | Reload configuration (many daemons support this) |
| `SIGINT` | 2 | Interrupt -- what `Ctrl+C` sends |

**Always try SIGTERM first.** Only use SIGKILL if the process is truly stuck. SIGKILL does not let the process clean up (close database connections, flush writes, remove temp files).

## systemd and Services

systemd is the init system on modern Linux. It starts and manages all system services (called "units"). When your EC2 instance boots, systemd starts SSH, logging, networking, and any services you have enabled.

**Why it matters for deployment:** You want your application to:
- Start automatically when the server boots
- Restart automatically if it crashes
- Log output to a central location
- Be controllable with simple start/stop/restart commands

systemd does all of this.

### Process Tree

```
systemd (PID 1)
├── sshd
│   └── sshd: ec2-user
│       └── bash
│           └── htop
├── nginx: master process
│   ├── nginx: worker process
│   └── nginx: worker process
├── rsyslogd
└── crond
```

### systemctl Commands

| Command | What It Does |
|---------|-------------|
| `systemctl start nginx` | Start the service now |
| `systemctl stop nginx` | Stop the service now |
| `systemctl restart nginx` | Stop then start |
| `systemctl reload nginx` | Reload config without stopping |
| `systemctl status nginx` | Show current status, recent logs |
| `systemctl enable nginx` | Start automatically on boot |
| `systemctl disable nginx` | Do not start on boot |
| `systemctl is-active nginx` | Check if running (returns "active" or "inactive") |

**enable vs start:** `enable` sets up boot-time startup but does not start the service now. `start` starts it now but it will not survive a reboot. You usually want both: `systemctl enable --now nginx`.

### journalctl (Logs)

systemd captures all service output (stdout/stderr) in the journal:

```bash
journalctl -u nginx                  # All logs for nginx
journalctl -u nginx -f               # Follow logs in real time
journalctl -u nginx --since "1 hour ago"  # Recent logs
journalctl -u nginx --no-pager -n 50     # Last 50 lines, no paging
```

## Permissions

Every file and directory has three permission sets: owner, group, and others.

```
-rw-r--r-- 1 ec2-user ec2-user 1234 May  5 10:00 config.txt
│├──┤├──┤├──┤  │        │
│ │   │   │    owner    group
│ │   │   └── others: r-- (read only)
│ │   └────── group:  r-- (read only)
│ └────────── owner:  rw- (read + write)
└──────────── type:   - (file), d (directory)
```

### Permission Types

| Symbol | Numeric | Meaning | For Files | For Directories |
|--------|---------|---------|-----------|----------------|
| `r` | 4 | Read | View contents | List contents |
| `w` | 2 | Write | Modify contents | Create/delete files inside |
| `x` | 1 | Execute | Run as program | Enter (cd into) directory |

### Common Permission Patterns

| Numeric | Symbolic | Use Case |
|---------|----------|----------|
| `755` | `rwxr-xr-x` | Executable scripts, directories |
| `644` | `rw-r--r--` | Regular files (configs, text) |
| `400` | `r--------` | SSH private keys |
| `600` | `rw-------` | Credential files, secrets |
| `700` | `rwx------` | Private directories (`.ssh/`) |

### chmod and chown

```bash
chmod 644 file.txt          # Set permissions using numeric notation
chmod +x script.sh          # Add execute permission
chmod -w file.txt           # Remove write permission
chmod -R 755 /opt/app/      # Recursive permission change

chown ec2-user:ec2-user file.txt    # Change owner and group
chown -R www-data:www-data /var/www # Recursive ownership change
```

### sudo

`sudo` runs a command as root (the superuser). Use it for system administration tasks (installing packages, editing system configs, managing services). Do NOT run everything as root -- if you `sudo rm -rf /`, you will destroy the entire system.

## Environment Variables

Environment variables are key-value pairs that configure processes. Every process inherits its parent's environment.

```bash
echo $HOME          # /home/ec2-user
echo $PATH          # Directories where the shell looks for commands
echo $USER          # Current username
env                 # List all environment variables
```

### Scope and Persistence

| Method | Scope | Survives Logout? |
|--------|-------|-----------------|
| `export MY_VAR=value` | Current session + child processes | No |
| Add to `~/.bashrc` | All future sessions for this user | Yes |
| Add to `/etc/environment` | All users, all sessions | Yes (system-wide) |

**Common pattern in production:** Pass config as env vars:

```bash
DATABASE_URL=postgres://localhost:5432/mydb node app.js
NODE_ENV=production npm start
```

The application reads `process.env.DATABASE_URL` (Node.js) or `os.environ['DATABASE_URL']` (Python) at startup.

## Further Reading

- [systemd documentation](https://www.freedesktop.org/software/systemd/man/) -- official reference for unit files and commands
- [Linux permissions explained (Red Hat)](https://www.redhat.com/sysadmin/linux-file-permissions-explained) -- visual guide to permissions
- [The Twelve-Factor App: Config](https://12factor.net/config) -- why env vars are the standard for app configuration
