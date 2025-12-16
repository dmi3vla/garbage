chmod +x /home/admin/garbage/*.sh && ls -la /home/admin/garbage/
sudo /home/admin/garbage/full_grub_recovery.sh /mnt/gentoo /dev/sda
sudo /home/admin/garbage/full_grub_recovery.sh /mnt/gentoo /dev/sda
sudo /home/admin/garbage/full_grub_recovery.sh /mnt/gentoo /dev/sda
sudo /home/admin/garbage/full_grub_recovery.sh /mnt/gentoo /dev/sda
chmod +x /home/admin/garbage/install_kernel_and_grub.sh /home/admin/garbage/check_boot_files.sh && /home/admin/garbage/check_boot_files.sh /mnt/gentoo
sudo /home/admin/garbage/install_kernel_and_grub.sh /mnt/gentoo /dev/sda 2>&1 | head -100
chmod +x /home/admin/garbage/quick_kernel_install.sh && echo "[✓] Script ready" && ls -lh /home/admin/garbage/*.sh
sudo /home/admin/garbage/quick_kernel_install.sh /mnt/gentoo /dev/sda 2>&1
