#!/bin/bash
# Script for HAProxy Load Balancer with HTTPS termination

DOMAIN="wpdecesar.ddns.net"
EMAIL="cgarciap58@iesalbarregas.es"

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
