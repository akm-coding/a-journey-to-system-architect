# Processes and Permissions Exercise

## Prerequisites

- A running EC2 instance with Amazon Linux 2023 (launch a new one if you terminated the previous instance -- follow [Linux Fundamentals Exercise](../02-linux-fundamentals/exercise.md) Step 1 and Step 2)
- SSH access to the instance

## Step 1: Explore Running Processes

List all running processes:

```bash
ps aux
```

Look at the output columns. Notice that most processes run as `root`. Find the SSH daemon:

```bash
ps aux | grep sshd
```

You should see at least two `sshd` entries: the main daemon and your active SSH session.

Now use `top` for a real-time view:

```bash
top
```

Observe the header: load averages, total tasks, CPU and memory usage. Each row is a process sorted by CPU usage. Press `q` to quit.

If you installed `htop` in the previous exercise:

```bash
htop
```

`htop` is a friendlier version of `top` with color coding and mouse support. Press `q` to quit.

## Step 2: Install and Manage Nginx as a Service

Install Nginx:

```bash
sudo yum install -y nginx
```

Start the service:

```bash
sudo systemctl start nginx
```

Check if it is running:

```bash
sudo systemctl status nginx
```

You should see **active (running)** in green. The output also shows the PID and recent log lines.

Verify Nginx is actually serving HTTP:

```bash
curl localhost
```

You should see HTML output (the default Nginx welcome page).

Now stop Nginx and verify:

```bash
sudo systemctl stop nginx
sudo systemctl status nginx
```

The status should now show **inactive (dead)**.

Try curl again:

```bash
curl localhost
```

It should fail with "Connection refused" -- Nginx is no longer listening.

### Enable vs Start

Start Nginx again and enable it for boot:

```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

Check both states:

```bash
sudo systemctl is-active nginx    # Should output "active"
sudo systemctl is-enabled nginx   # Should output "enabled"
```

**What this means:** If you reboot this instance, Nginx will start automatically. Without `enable`, you would have to manually start it after every reboot.

### View Service Logs

```bash
sudo journalctl -u nginx --no-pager -n 20
```

This shows the last 20 log lines for the Nginx service. You should see start/stop events from your actions above.

Follow logs in real time (useful for debugging):

```bash
sudo journalctl -u nginx -f
```

Press `Ctrl+C` to stop following.

## Step 3: Practice with Permissions

### Create and Run a Script

Create a simple script:

```bash
echo '#!/bin/bash
echo "Hello from script"
echo "Running as user: $(whoami)"
echo "Current time: $(date)"' > ~/test.sh
```

Check its permissions:

```bash
ls -la ~/test.sh
```

You should see `-rw-r--r--` -- no execute permission.

Try to run it:

```bash
./test.sh
```

This fails with `Permission denied` because the file lacks execute (`x`) permission.

Add execute permission and try again:

```bash
chmod +x ~/test.sh
ls -la ~/test.sh     # Now shows -rwxr-xr-x
~/test.sh            # Should work and print the messages
```

### Experiment with Permissions

Remove all permissions:

```bash
chmod 000 ~/test.sh
ls -la ~/test.sh     # Shows ----------

cat ~/test.sh        # Permission denied -- cannot read
```

Restore read permission for owner only:

```bash
chmod 644 ~/test.sh
ls -la ~/test.sh     # Shows -rw-r--r--
cat ~/test.sh        # Works again
```

### File Ownership

Create a file as root and try to edit as ec2-user:

```bash
sudo touch /opt/root-file.txt
sudo echo "root wrote this" | sudo tee /opt/root-file.txt
ls -la /opt/root-file.txt
```

Notice the owner is `root`. Try editing as ec2-user:

```bash
echo "ec2-user trying to write" >> /opt/root-file.txt
```

This fails -- you do not have write permission. Fix it by changing ownership:

```bash
sudo chown ec2-user:ec2-user /opt/root-file.txt
echo "ec2-user can write now" >> /opt/root-file.txt
cat /opt/root-file.txt    # Both lines should appear
```

## Step 4: Work with Environment Variables

### View Existing Variables

```bash
echo $HOME          # /home/ec2-user
echo $PATH          # The directories searched for commands
echo $USER          # ec2-user
env | head -20      # First 20 environment variables
```

### Set a Temporary Variable

```bash
export MY_VAR="hello from ec2"
echo $MY_VAR        # Outputs: hello from ec2
```

Now open a **new SSH session** (a second terminal window connected to the same instance):

```bash
echo $MY_VAR        # Outputs nothing -- the variable only exists in the first session
```

Close the second session and return to the first.

### Make a Variable Persistent

Add the variable to your shell profile:

```bash
echo 'export MY_VAR="persistent value"' >> ~/.bashrc
```

Reload the profile:

```bash
source ~/.bashrc
echo $MY_VAR        # Outputs: persistent value
```

Open a new SSH session and check:

```bash
echo $MY_VAR        # Outputs: persistent value -- it persists across sessions now
```

### Application Configuration Pattern

This is how you pass configuration to applications in production:

```bash
# Set database URL as an env var
export DATABASE_URL="postgres://user:pass@localhost:5432/mydb"

# An application would read this at startup
# Node.js: process.env.DATABASE_URL
# Python:  os.environ['DATABASE_URL']
# Bash:    $DATABASE_URL

echo "App would connect to: $DATABASE_URL"
```

You never put passwords in source code. You always use environment variables.

## Step 5: Process Control

Start a long-running background process:

```bash
sleep 300 &
```

The `&` puts it in the background. Note the PID that is printed.

Find it:

```bash
ps aux | grep sleep
```

You should see the `sleep 300` process with its PID.

Gracefully terminate it (SIGTERM):

```bash
kill <PID>           # Replace <PID> with the actual number
ps aux | grep sleep  # Should be gone
```

Start another and force-kill it (SIGKILL):

```bash
sleep 300 &
kill -9 <PID>        # Force kill -- no cleanup
ps aux | grep sleep  # Should be gone
```

**Remember:** Always try `kill` (SIGTERM) first. Only use `kill -9` (SIGKILL) if the process is stuck and refuses to stop.

## Verification

Run these checks to confirm everything is working:

```bash
# Nginx should be running
systemctl status nginx | grep "active (running)"

# Your script should have read/write permissions
ls -la ~/test.sh | grep "rw-r--r--"

# Your persistent env var should be set
source ~/.bashrc && echo $MY_VAR | grep "persistent"

# No orphan sleep processes
ps aux | grep "[s]leep 300" | wc -l   # Should output 0
```

## Clean Up

```bash
# Stop and disable Nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Clean up files
rm ~/test.sh
sudo rm /opt/root-file.txt
```

If you are done with the EC2 instance:
1. Go to EC2 Console > Instances.
2. Select your instance.
3. Actions > Instance State > **Terminate instance**.

## Rebuild Challenge

Launch a fresh EC2 instance. Without looking at this guide:

1. Inspect running processes with `ps aux` and `top`.
2. Install Nginx and manage it with `systemctl` (start, stop, enable, check status).
3. Create a bash script and make it executable.
4. Change file ownership with `chown`.
5. Set a persistent environment variable in `.bashrc`.
6. Start a background process and kill it.

**Time yourself.** Log your time in [rebuild-log.md](../rebuild-log.md).
