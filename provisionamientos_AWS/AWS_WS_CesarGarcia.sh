#!/bin/bash
# Script de provisionamiento para el servidor web
# Instala Apache y configura los servicios básicos


# Credenciales de WordPress
user_wp="wpuser"
pass_wp="wppw"
ip_db="192.168.20.50"
db_wp="wordpress"


sudo apt update
sudo apt install apache2 -y
sudo apt install mariadb-client -y
sudo apt install libapache2-mod-php -y
sudo apt install php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl -y
sudo systemctl restart apache2.service

sudo apt install nfs-common -y
sudo mkdir -p /var/www/html
sudo mount 192.168.10.25:/srv/nfs/wordpress /var/www/html
echo "192.168.10.25:/srv/nfs/wordpress /var/www/html nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Troubleshoot: Test de php
echo "<?php phpinfo(); ?>" | sudo -u www-data tee /var/www/html/info.php > /dev/null

# Borramos el archivo de bienvenida de Apache para que WordPress sea la página principal
if [ -f /var/www/html/index.html ]; then
    sudo -u www-data rm /var/www/html/index.html
fi


sudo systemctl restart apache2


# # Setup de WordPress
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Aún no existe wordpress, descargándolo..."

    cd /tmp/
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo -u www-data cp -r wordpress/* /var/www/html/
    sudo rm -rf wordpress latest.tar.gz
    # sudo chown -R www-data:www-data /var/www/html
    # sudo find /var/www/html -type d -exec chmod 755 {} \;
    # sudo find /var/www/html -type f -exec chmod 644 {} \;
    cd /var/www/html
    sudo -u www-data cp wp-config-sample.php wp-config.php

    # Configuramos WordPress con nuestras credenciales
    echo "Configurando WordPress con las credenciales"
    sudo -u www-data sed -i "s/'database_name_here'/'$db_wp'/g" wp-config.php
    sudo -u www-data sed -i "s/'username_here'/'$user_wp'/g" wp-config.php
    sudo -u www-data sed -i "s/'password_here'/'$pass_wp'/g" wp-config.php
    sudo -u www-data sed -i "s/'localhost'/'$ip_db'/" wp-config.php
    sudo -u www-data sed -i "/That's all, stop editing!/i \
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { \
    \$_SERVER['HTTPS'] = 'on'; \
    \$_SERVER['SERVER_PORT'] = 443; \
} \
" wp-config.php
fi


sudo systemctl restart apache2
