# Despliegue de WordPress en AWS con Alta Disponibilidad, en tres capas

Este proyecto contiene scripts de aprovisionamiento para desplegar un sitio de WordPress altamente disponible en infraestructura AWS. El despliegue consta de cuatro componentes principales:

1. **Servidor NFS** - Para almacenamiento compartido
2. **Servidor de Base de Datos** - MariaDB para WordPress
3. **Servidores Web** - Múltiples servidores Apache con PHP
4. **Balanceador de Carga** - HAProxy con terminación SSL


# Índice 

- [1. Aprovisionamiento del Servidor NFS](#nfs-server)
- [2. Aprovisionamiento del Servidor de Base de Datos](#database-server)
- [3. Aprovisionamiento de los Servidores Web](#web-servers)
- [4. Aplicación del Balanceador de Carga](#load-balancer)

<h2 id="nfs-server">1. Aprovisionamiento del Servidor NFS ([AWS_NFS_CesarGarcia.sh](provisionamientos_AWS/AWS_NFS_CesarGarcia.sh))</h2>

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

# Configuración inicial
sudo hostnamectl set-hostname cesarGarciaDB

# Instalación de MariaDB y herramientas de red
sudo apt update
sudo apt install mariadb-server -y
sudo apt install net-tools -y

root_pass="roottoor"
pass_wp="wppw"

# Script equivalente a mysql_secure_installation
sudo mariadb <<EOF
DELETE FROM mysql.user WHERE User='';

DROP USER IF EXISTS 'root'@'%';

ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_pass';

DROP DATABASE IF EXISTS test;

FLUSH PRIVILEGES;
EOF

# Configuración de base de datos y usuario
mysql -u root -p"$root_pass" -e "CREATE DATABASE wordpress;"
mysql -u root -p"$root_pass" -e "SHOW DATABASES;"
mysql -u root -p"$root_pass" -e "CREATE USER 'wpuser'@'10.0.2.%' IDENTIFIED BY '$pass_wp';"
mysql -u root -p"$root_pass" -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'10.0.2.%';"
mysql -u root -p"$root_pass" -e "FLUSH PRIVILEGES;"

echo "Base de datos y usuario configurados correctamente."
echo "Contraseña root: $root_pass"
echo "Contraseña wpuser: $pass_wp"

# Configurar MariaDB para aceptar conexiones remotas en su IP (10.0.3.113)
sudo sed -i "s/^bind-address\s*=.*/bind-address = 10.0.3.113/" /etc/mysql/mariadb.conf.d/50-server.cnf
echo "MariaDB configurado para aceptar conexiones remotas en 10.0.3.113"
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


## 4. Aplicación del Balanceador de Carga [AWS_LB_CesarGarcia.sh](provisionamientos_AWS/AWS_LB_CesarGarcia.sh)

Componentes Clave:

- **Instalación de Apache y reto de CertBot**: Configura el servidor web y obtiene el certificado SSL
- **Instalación de HAProxy**: Configura el balanceador de carga
- **Redirección HTTP a HTTPS**: Redirige todo el tráfico a HTTPS
- **Configuración de balanceo**: Configura el balanceo entre los servidores web


```bash
#!/bin/bash
# Script de balanceador de carga para WordPress utilizando HAProxy y CertBot

DOMAIN="wpdecesar.ddns.net"
EMAIL="cgarciap58@iesalbarregas.es"

sudo hostnamectl set-hostname cesarGarciaLB

sudo apt update
sudo apt install -y apache2 certbot python3-certbot-apache

sudo certbot --apache -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive

sudo cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
        /etc/letsencrypt/live/$DOMAIN/privkey.pem \
        | sudo tee /etc/haproxy/$DOMAIN.pem

sudo apt install -y haproxy

# Se reescribe haproxy.cfg
sudo tee /etc/haproxy/haproxy.cfg >/dev/null <<'EOF'
global
    maxconn 2048
    log /dev/log local0

defaults
    mode http
    option httplog
    option dontlognull
    timeout connect 5s
    timeout client 50s
    timeout server 50s

# HTTP -> HTTPS redirect
frontend http_front
    bind *:80
    redirect scheme https code 301

# HTTPS termination
frontend https_front
    bind *:443 ssl crt /etc/haproxy/$DOMAIN.pem
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    default_backend wordpress_nodes

backend wordpress_nodes
    balance roundrobin
    option httpchk GET /
    server ws1 10.0.2.235:80 check 
    server ws2 10.0.2.141:80 check
EOF

sudo systemctl restart haproxy
```