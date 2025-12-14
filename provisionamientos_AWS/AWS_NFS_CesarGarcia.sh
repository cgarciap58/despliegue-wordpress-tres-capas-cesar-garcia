#!/bin/bash
# Script para configurar servidor NFS en AWS para WordPress
# Configura el hostname
sudo hostnamectl set-hostname cesarGarciaNFS

# Instala el servidor NFS
sudo apt update
sudo apt install -y nfs-kernel-server

# Crea la carpeta compartida y da permisos al usuario de Apache
sudo mkdir -p /srv/nfs/wordpress
sudo chown -R www-data:www-data /srv/nfs/wordpress
sudo chmod 755 /srv/nfs/wordpress

# Exporta la carpeta a la subred donde están los webservers
echo "/srv/nfs/wordpress 10.0.2.0/24(rw,sync,no_subtree_check)" | sudo tee /etc/exports

# Aplica los exports y reinicia el servicio
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
