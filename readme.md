# Despliegue de WordPress en AWS con Alta Disponibilidad, en tres capas

Este proyecto contiene scripts de aprovisionamiento para desplegar un sitio de WordPress altamente disponible en infraestructura AWS. El despliegue consta de cuatro componentes principales:

1. **Servidor NFS** - Para almacenamiento compartido
2. **Servidor de Base de Datos** - MariaDB para WordPress
3. **Servidores Web** - Múltiples servidores Apache con PHP
4. **Balanceador de Carga** - HAProxy con terminación SSL

## 1. Aprovisionamiento del Servidor NFS ([AWS_NFS_CesarGarcia.sh](provisionamientos_AWS/AWS_NFS_CesarGarcia.sh))

Este script configura un servidor NFS (Network File System) para compartir archivos de WordPress entre múltiples servidores web.

### Componentes Clave:
- **Instalación de NFS**: Instala el paquete del servidor NFS
- **Configuración de Directorios**: Crea `/srv/nfs/wordpress` con los permisos adecuados
- **Exportación NFS**: Hace el directorio disponible para los servidores web
- **Gestión del Servicio**: Habilita y reinicia el servicio NFS

### Explicación Detallada:

```bash
# Establece el nombre del host
sudo hostnamectl set-hostname cesarGarciaNFS

# Actualiza e instala el servidor NFS
sudo apt update
sudo apt install -y nfs-kernel-server

# Crea el directorio compartido
sudo mkdir -p /srv/nfs/wordpress
sudo chown -R www-data:www-data /srv/nfs/wordpress
sudo chmod 755 /srv/nfs/wordpress

# Configura las exportaciones NFS
echo "/srv/nfs/wordpress 10.0.2.0/24(rw,sync,no_subtree_check)" | sudo tee /etc/exports

# Aplica los cambios
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server

```

## 2. Aprovisionamiento del Servidor de Base de Datos ([AWS_DB_CesarGarcia.sh](provisionamientos_AWS/AWS_DB_CesarGarcia.sh))

Este script configura un servidor MariaDB para WordPress con configuración segura.

Componentes Clave:
Instalación segura de MariaDB
Creación de base de datos y usuario para WordPress
Configuración de acceso remoto
Medidas de seguridad
Explicación Detallada:

```bash
# Establece el nombre del host
sudo hostnamectl set-hostname cesarGarciaDB

# Instala MariaDB y herramientas de red
sudo apt update
sudo apt install -y mariadb-server mariadb-client net-tools

# Securiza la instalación de MariaDB
sudo mysql_secure_installation

# Crea la base de datos y usuario para WordPress
sudo mysql -e "CREATE DATABASE wordpress;"
sudo mysql -e "CREATE USER 'wp_user'@'10.0.2.%' IDENTIFIED BY 'wp_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'10.0.2.%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Configura MariaDB para aceptar conexiones desde los servidores web
sudo sed -i 's/bind-address.*/bind-address = 10.0.3.113/' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
```

## 3. Aprovisionamiento de los Servidores Web ([AWS_WS_CesarGarcia.sh](provisionamientos_AWS/AWS_WS_CesarGarcia.sh))

Este script configura servidores web Apache con PHP y monta el recurso NFS compartido.

Componentes Clave:
- **Instalación de Apache y PHP**: Configura el servidor web y el runtime de PHP
- **Montaje del recurso NFS**: Accede al directorio compartido del servidor NFS
- **Permisos y seguridad**: Establece los permisos adecuados para WordPress
- **Instalación de WordPress**: Descarga e instala WordPress desde la fuente oficial
- **Configuración inicial de WordPress**: Prepara la instalación básica

```bash

#!/bin/bash
# Script de provisionamiento para el servidor web
# Instala Apache y configura los servicios básicos


# Credenciales de WordPress
user_wp="wpuser"
pass_wp="wppw"
ip_db="10.0.3.113"
db_wp="wordpress"


sudo hostnamectl set-hostname cesarGarciaWS

sudo apt update
sudo apt install apache2 -y
sudo apt install mariadb-client -y
sudo apt install libapache2-mod-php -y
sudo apt install php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl -y
sudo systemctl restart apache2.service

sudo apt install nfs-common -y
sudo mkdir -p /var/www/html
sudo mount 10.0.2.143:/srv/nfs/wordpress /var/www/html
echo "10.0.2.143:/srv/nfs/wordpress /var/www/html nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab

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
```

