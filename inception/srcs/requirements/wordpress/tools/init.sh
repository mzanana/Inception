#!/bin/sh

set -e

if [ ! -f index.php ]; then
    wp core download --allow-root
fi

if [ ! -f wp-config.php ]; then
    wp config create \
        --dbname="$MARIADB_DATABASE" \
        --dbuser="$MARIADB_USER" \
        --dbpass="$MARIADB_PASSWORD" \
        --dbhost="mariadb:3306" \
        --allow-root
fi

if ! wp core is-installed --allow-root; then
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=subscriber \
        --allow-root
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 -F

# 1. wp core download
#         ↓
#    get WordPress PHP files
# 
# 2. wp config create
#         ↓
#    create wp-config.php
#    tell WordPress how to reach MariaDB
# 
# 3. wp core install
#         ↓
#    create WordPress tables in MariaDB
#    create the first WordPress admin user
#    configure the site

