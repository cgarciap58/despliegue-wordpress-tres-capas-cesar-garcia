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
