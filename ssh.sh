#!/bin/bash
# setup_gentoo_ssh.sh
# Script to install OpenSSH and create a user on Gentoo LiveCD

# Generate SSH host keys (required before starting sshd)
ssh-keygen -A

# Create user "admin" with home directory and bash shell
useradd -m -s /bin/bash admin 2>/dev/null || true

# Set default password for admin user (non-interactive)
echo "admin:admin" | chpasswd

# Configure SSH to allow password authentication
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Verify SSH config syntax
sshd -t
if [ $? -ne 0 ]; then
    echo "SSH config error!"
    exit 1
fi

# Stop old SSH daemon if running
killall sshd 2>/dev/null || true
sleep 1

# Start SSH daemon directly (without rc-update)
/usr/sbin/sshd

echo "[✓] OpenSSH started on port 22"
echo "[✓] User 'admin' with password 'admin'"
echo "[✓] SSH ready for connections"