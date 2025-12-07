#!/bin/bash
# Script de provisionamiento para el servidor balanceador
# Instala HAProxy y configura el balanceo
sudo apt update
sudo apt install haproxy -y

sudo tee -a /etc/haproxy/haproxy.cfg >/dev/null <<'EOF'

frontend wordpress_front
        bind *:80
        default_backend wordpress_nodes

backend wordpress_nodes
        balance roundrobin
        server ws1 192.168.10.21:80 check
        server ws2 192.168.10.22:80 check
EOF

# Restart HAProxy to apply changes
sudo systemctl restart haproxy
