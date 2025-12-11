#!/bin/bash
# Script for HAProxy Load Balancer with HTTPS termination

sudo apt update
sudo apt install -y haproxy openssl

# Create self-signed SSL certificate for Vagrant tests
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /etc/haproxy/selfsigned.key \
  -out /etc/haproxy/selfsigned.crt \
  -subj "/C=US/ST=None/L=None/O=LocalDev/OU=Dev/CN=lb.local"

# Combine key + cert into .pem for HAProxy
cat /etc/haproxy/selfsigned.key /etc/haproxy/selfsigned.crt \
  | sudo tee /etc/haproxy/selfsigned.pem >/dev/null

# Overwrite haproxy.cfg
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
    bind *:443 ssl crt /etc/haproxy/selfsigned.pem
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    default_backend wordpress_nodes

backend wordpress_nodes
    balance roundrobin
    option httpchk GET /
    server ws1 192.168.10.21:80 check
    server ws2 192.168.10.22:80 check
EOF

sudo systemctl restart haproxy
