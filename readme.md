# Despliegue de WordPress en AWS con Alta Disponibilidad, en tres capas

Este proyecto contiene scripts de aprovisionamiento para desplegar un sitio de WordPress altamente disponible en infraestructura AWS. El despliegue consta de cuatro componentes principales:

1. **Servidor NFS** - Para almacenamiento compartido
2. **Servidor de Base de Datos** - MariaDB para WordPress
3. **Servidores Web** - Múltiples servidores Apache con PHP
4. **Balanceador de Carga** - HAProxy con terminación SSL

El Wordpress está alojado en <a href="https://wpdecesar.ddns.net">wpdecesar.ddns.net</a>

# Prueba de funcionamiento

![Prueba de funcionamiento](./CapturaPantallaWP.png)

# Índice 

- [1. Aprovisionamiento del Servidor NFS](#nfs-server)
- [2. Aprovisionamiento del Servidor de Base de Datos](#database-server)
- [3. Aprovisionamiento de los Servidores Web](#web-servers)
- [4. Aplicación del Balanceador de Carga](#load-balancer)
- [5. Configuración en AWS](#aws-configuration)

<a name="nfs-server"></a>

## 1. Aprovisionamiento del Servidor NFS ([AWS_NFS_CesarGarcia.sh](provisionamientos_AWS/AWS_NFS_CesarGarcia.sh))

Este script configura un servidor NFS (Network File System) para compartir archivos de WordPress entre múltiples servidores web.

### Componentes Clave

- **Instalación de NFS**: Instala el paquete del servidor NFS
- **Configuración de Directorios**: Crea `/srv/nfs/wordpress` con los permisos adecuados
- **Exportación NFS**: Hace el directorio disponible para los servidores web
- **Gestión del Servicio**: Habilita y reinicia el servicio NFS

### Explicación Detallada

```bash
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

```

<a name="database-server"></a>


## 2. Aprovisionamiento del Servidor de Base de Datos ([AWS_DB_CesarGarcia.sh](provisionamientos_AWS/AWS_DB_CesarGarcia.sh))

Este script configura un servidor MariaDB para WordPress con configuración segura.

### Componentes Clave

- **Instalación segura de MariaDB**: Instala el servidor y herramientas de red
- **Creación de base de datos y usuario**: Configura WordPress con credenciales seguras
- **Configuración de acceso remoto**: Permite conexiones desde los servidores web
- **Medidas de seguridad**: Elimina usuarios y bases de datos por defecto

### Explicación Detallada

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

<a name="web-servers"></a>

## 3. Aprovisionamiento de los Servidores Web ([AWS_WS_CesarGarcia.sh](provisionamientos_AWS/AWS_WS_CesarGarcia.sh))

Este script configura servidores web Apache con PHP y monta el recurso NFS compartido.

### Componentes Clave

- **Instalación de Apache y PHP**: Configura el servidor web y el runtime de PHP
- **Montaje del recurso NFS**: Accede al directorio compartido del servidor NFS
- **Permisos y seguridad**: Establece los permisos adecuados para WordPress
- **Instalación de WordPress**: Descarga e instala WordPress desde la fuente oficial
- **Configuración inicial de WordPress**: Prepara la instalación básica

### Explicación detallada

```bash

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
```

<a name="load-balancer"></a>


## 4. Aplicación del Balanceador de Carga ([AWS_LB_CesarGarcia.sh](provisionamientos_AWS/AWS_LB_CesarGarcia.sh))

### Componentes Clave

- **Instalación de Apache y reto de CertBot**: Configura el servidor web y obtiene el certificado SSL
- **Instalación de HAProxy**: Configura el balanceador de carga
- **Redirección HTTP a HTTPS**: Redirige todo el tráfico entrante a HTTPS
- **Configuración de balanceo**: Configura el balanceo entre los servidores web

### Explicación detallada

```bash
#!/bin/bash
# Script para balanceador de carga en AWS para WordPress pero que permite pasar el reto Certbot

# Establece variables de dominio y correo
DOMAIN="wpdecesar.ddns.net"
EMAIL="cgarciap58@iesalbarregas.es"

# Configura nombre del servidor
sudo hostnamectl set-hostname cesarGarciaLB

# Instala Apache y Certbot para obtener el certificado SSL
sudo apt update
sudo apt install -y apache2 certbot python3-certbot-apache

sudo certbot --apache -d $DOMAIN -d www.$DOMAIN --email $EMAIL --agree-tos --non-interactive


# Combina certificado y clave privada en un solo archivo para HAProxy
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

# Redirección HTTP -> HTTPS
frontend http_front
    bind *:80
    redirect scheme https code 301

# Terminación HTTPS, apuntando a nuestro certificado SSL para el dominio
frontend https_front
    bind *:443 ssl crt /etc/haproxy/$DOMAIN.pem
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    default_backend wordpress_nodes


# Backend para los servidores WordPress
backend wordpress_nodes
    balance roundrobin
    option httpchk GET /
    server ws1 10.0.2.235:80 check
    server ws2 10.0.2.141:80 check
EOF

# Necesario parar y deshabilitar apache para que no se pelee con HAProxy en los puertos 80 y 443
sudo systemctl stop apache2
sudo systemctl disable apache2

# Reinicia HAProxy para aplicar la configuración
sudo systemctl restart haproxy

```

## 5. Configuración en AWS

### Subredes

![Subredes AWS](./capturasAWS/subredes.png)

Las subredes están configuradas para soportar la arquitectura de alta disponibilidad con balanceo de carga.

- **Subred pública**: 10.0.1.0/24 (para el balanceador)
- **Subred privada**: 10.0.2.0/24 (para los servidores web y el servidor NFS)
- **Subred de base de datos**: 10.0.3.0/24 (para la instancia RDS, totalmente inaccesible al LB)

### Instancias

![Instancias AWS](./capturasAWS/instancias.png)

Contamos con cinco instancias en total: una para el balanceador de carga y cuatro para los servidores web.
- **Balanceador**: Asociado a una ip elástica para acceso externo. Más detalles en la sección de IP Elástica. La IP privada es la 10.0.1.90 (asignada dinámicamente por AWS). Esta es la única instancia en la red pública.

- **Servidores web**: WS1 (10.0.2.235) y WS2 (10.0.2.141). Tienen Apache instalados, y la carpeta NFS montada. Se encargan de descargar Wordpress si aún no está instalado, y de servir las páginas web después de que el balanceador se lo pide. Se alternan, mediante sistema round robin.

- **Servidor NFS**: nfs (10.0.2.101), aloja los archivos de WordPress compartidos entre los servidores web y es accesible solo desde los servidores web. Le da permisos a los usuarios www-data para escribir en el directorio compartido, de tal forma que WordPress puede funcionar sin problema.

- **Base de datos**: Servidor con BBDD MariaDB, alojado en la subred de base de datos y accesible solo desde los equipos en la subred 10.0.2.0/24 para dar acceso a los servidores web, evitando el acceso directo desde la red pública.

### Route tables


### Grupos de seguridad

### IP Elástica