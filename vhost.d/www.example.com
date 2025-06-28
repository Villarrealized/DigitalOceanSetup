# ACME challenge location
location ^~ /.well-known/acme-challenge/ {
    default_type "text/plain";
    root /usr/share/nginx/html;
    try_files $uri =404;
}
