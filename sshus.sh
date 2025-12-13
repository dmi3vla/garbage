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

# Set password for user admin
echo "Set password for user admin:"
passwd admin

# Add user to wheel group (for sudo)
gpasswd -a admin wheel

# Enable sshd on boot and start it (OpenRC)
rc-update add sshd default
/etc/init.d/sshd start

# Display sshd status
rc-status

echo "[✓] OpenSSH installed and configured. User 'admin' created."