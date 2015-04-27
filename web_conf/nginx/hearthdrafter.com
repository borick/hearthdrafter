upstream hearthdrafter.com {
  server 127.0.0.1:8080;
}

etag off;

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
  return     301 https://$server_name$request_uri;
  add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
  add_header X-Frame-Options "DENY";
}

server {
  listen 443; 
  ssl on;
  ssl_certificate /etc/nginx/ssl-unified.crt;
  ssl_certificate_key /etc/nginx/ssl.key;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  
  server_name www.hearthdrafter.com;
  
  add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
  add_header X-Frame-Options "DENY";
  add_header X-Frame-Options SAMEORIGIN;
  add_header X-XSS-Protection: 1; mode=block;
  
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
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index  index.php;
    #fastcgi_param  SCRIPT_FILENAME /var/www/roundcubemail$fastcgi_script_name;
    fastcgi_param  SCRIPT_FILENAME /var/www/roundcubemail$1.php;
    include fastcgi_params;
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

