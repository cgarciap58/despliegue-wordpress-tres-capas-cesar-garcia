#!/bin/bash
# Script de provisionamiento para el servidor web

# Credenciales de WordPress
user_wp="wpuser"
pass_wp="wppw"
ip_db="10.0.3.113"
db_wp="wordpress"


sudo hostnamectl set-hostname cesarGarciaWS

# Instala Apache y configura los servicios básicos

sudo apt update
sudo apt install apache2 -y
sudo apt install mariadb-client -y
sudo apt install libapache2-mod-php -y
sudo apt install php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl -y
sudo systemctl restart apache2.service

# Instala un cliente NFS y monta la carpeta del servidor NFS. 
# Añade la entrada al fstab para montaje permanente
sudo apt install nfs-common -y
sudo mkdir -p /var/www/html
sudo mount 10.0.2.143:/srv/nfs/wordpress /var/www/html
echo "10.0.2.143:/srv/nfs/wordpress /var/www/html nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Borramos el archivo de bienvenida de Apache para que WordPress sea la página principal
# Solo ejecuta si dicho archivo existe en la carpeta compartida del servidor NFS
if [ -f /var/www/html/index.html ]; then
    sudo -u www-data rm /var/www/html/index.html
fi

# Reinicia Apache para aplicar los cambios
sudo systemctl restart apache2


# En el caso de que no encuentre wp-config.php, instala WordPress y lo configura
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Aún no existe wordpress, descargándolo..."

    cd /tmp/
    # Descarga Wordpress
    wget https://wordpress.org/latest.tar.gz

    # Descomprime el archivo tar.gz
    tar -xzf latest.tar.gz

    # Copia los archivos de WordPress a la carpeta web 
    # Carpeta NFS. Por lo tanto utiliza el usuario www-data
    sudo -u www-data cp -r wordpress/* /var/www/html/
    sudo rm -rf wordpress latest.tar.gz

    cd /var/www/html
    # Mediante usuario permitido, copia el archivo de configuración
    sudo -u www-data cp wp-config-sample.php wp-config.php

    # Configura WordPress con nuestras credenciales
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

# Reinicia el servicio Apache para aplicar los cambios
sudo systemctl restart apache2
