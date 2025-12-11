#!/bin/bash
# HAProxy Load Balancer + Let\u2019s Encrypt provisioning

DOMAIN="wpdecesar.ddns.net"
EMAIL="cgarciap58@iesalbarregas.es"  # Certbot notifications
WEBROOT="/var/www/certbot"

# --- 1. Update OS & install dependencies ---
sudo apt update -y
sudo apt install -y haproxy certbot python3-certbot-nginx

# --- 2. Create webroot for HTTP-01 challenge ---
sudo mkdir -p $WEBROOT
sudo chown -R www-data:www-data $WEBROOT

# --- 3. Start temporary HTTP server for Certbot ---
# Runs in background during cert request
sudo pkill -f "python3 -m http.server 8080" 2>/dev/null
nohup sudo python3 -m http.server 8080 --directory $WEBROOT >/dev/null 2>&1 &

# --- 4. Request certificate from Let\u2019s Encrypt ---
sudo certbot certonly --webroot -w $WEBROOT \
    -d $DOMAIN -d www.$DOMAIN \
    --email $EMAIL --agree-tos --non-interactive

# --- 5. Combine key + cert for HAProxy ---
sudo cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
         /etc/letsencrypt/live/$DOMAIN/privkey.pem \
         | sudo tee /etc/haproxy/haproxy.pem >/dev/null

# --- 6. Overwrite HAProxy config ---
sudo tee /etc/haproxy/haproxy.cfg >/dev/null <<EOF
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

# --- HTTP frontend ---
frontend http_front
    bind *:80
    # Allow Certbot challenges
    acl url_acme_challenge path_beg /.well-known/acme-challenge/
    use_backend acme_backend if url_acme_challenge
    # Redirect all other HTTP to HTTPS
    redirect scheme https code 301 if !{ ssl_fc }

backend acme_backend
    server local_certbot 127.0.0.1:8080

# --- HTTPS frontend ---
frontend https_front
    bind *:443 ssl crt /etc/haproxy/haproxy.pem
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    default_backend wordpress_nodes

# --- Backend webservers ---
backend wordpress_nodes
    balance roundrobin
    option httpchk GET /
    server ws1 10.0.2.235:80 check
    server ws2 10.0.2.141:80 check
EOF

# --- 7. Restart HAProxy ---
sudo systemctl restart haproxy

# --- 8. Set up automatic certificate renewal ---
(crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew --webroot -w $WEBROOT --post-hook 'systemctl reload haproxy'") | crontab -

echo "HAProxy configured with Let\u2019s Encrypt. HTTPS is active for $DOMAIN"
