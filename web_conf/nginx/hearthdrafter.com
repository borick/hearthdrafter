upstream hearthdrafter.com {
  server 127.0.0.1:8080;
}

server {
  listen         80;
  server_name    www.hearthdrafter.com;
    
  # Deny all attempts to access hidden files such as .htaccess.
  location ~ /\. {
      deny all;
      access_log off;
      log_not_found off;
  }

  # Handling noisy favicon.ico messages
  location = /favicon.ico {
      access_log off;
      log_not_found off;
  }
  return         301 https://$server_name$request_uri;
}

server {
  listen 443;
  
  ssl on;
  ssl_certificate /etc/nginx/ssl-unified.crt;
  ssl_certificate_key /etc/nginx/ssl.key;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  
  server_name www.hearthdrafter.com;

  location / {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;

    proxy_pass http://hearthdrafter.com;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header  X-Forwarded-For $remote_addr;
    proxy_set_header  X-Forwarded-Base $scheme://$server_name;
  }

  location ~ ^/mail(.*) {
      alias /usr/share/apache2/roundcubemail$1;
      index index.php;
  }

  location ~ ^/mail/(bin|SQL|README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$ { deny all; }

  # Normal PHP scripts
  location ~ \.php$ {
      include fastcgi_params;
      fastcgi_pass php_workers;
  }

  # iRedAdmin: static files under /iredadmin/static
  location ~ ^/iredadmin/static/(.*)\.(png|jpg|gif|css|js) {
      alias /usr/share/apache2/iredadmin/static/$1.$2;
  }

  # iRedAdmin: Python scripts
  location ~ ^/iredadmin(.*) {
      rewrite ^/iredadmin(/.*)$ $1 break;
      include uwsgi_params;
      uwsgi_pass unix:/var/run/uwsgi_iredadmin.socket;
      uwsgi_param UWSGI_CHDIR /usr/share/apache2/iredadmin;
      uwsgi_param UWSGI_SCRIPT iredadmin;
      uwsgi_param SCRIPT_NAME /iredadmin;
  }
}

