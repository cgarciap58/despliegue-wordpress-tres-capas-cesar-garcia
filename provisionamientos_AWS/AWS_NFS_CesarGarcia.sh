#!/bin/bash
sudo hostnamectl set-hostname cesarGarciaNFS

sudo apt update
sudo apt install -y nfs-kernel-server

# Create shared folder
sudo mkdir -p /srv/nfs/wordpress
sudo chown -R www-data:www-data /srv/nfs/wordpress
sudo chmod 755 /srv/nfs/wordpress

# Export to webservers only
echo "/srv/nfs/wordpress 10.0.2.0/24(rw,sync,no_subtree_check)" | sudo tee /etc/exports

# Apply exports and restart service
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
