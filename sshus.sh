#!/bin/bash
# setup_gentoo_ssh.sh
# Script to install OpenSSH and create a user on Gentoo LiveCD

# Update the package tree
emerge --sync

# Install OpenSSH and sudo
emerge --ask net-misc/openssh app-admin/sudo

# Generate SSH host keys (required before starting sshd)
ssh-keygen -A

# Create user "admin" with home directory and bash shell
useradd -m -G users,wheel -s /bin/bash admin

# Set default password for admin user (non-interactive)
echo "admin:admin" | chpasswd

# Allow admin user to use sudo without password
echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/admin

# Enable sshd on boot and start it (OpenRC)
rc-update add sshd default
/etc/init.d/sshd start

# Display sshd status
rc-status

echo "[✓] OpenSSH installed and configured."
echo "[✓] User 'admin' created with password 'admin'"
echo "[✓] SSH daemon started and ready for connections"