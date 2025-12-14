#!/bin/bash
# Script de provisionamiento para el servidor de base de datos
# Instala MariaDB y configura los servicios básicos

sudo hostnamectl set-hostname cesarGarciaDB

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
