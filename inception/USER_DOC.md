# Inception — User Documentation

## Overview

This project provides a WordPress website running through a three-service Docker infrastructure:

```text
NGINX -> WordPress/PHP-FPM -> MariaDB
```

### Services

**NGINX**

- Public entry point.
- Exposes HTTPS on port `443`.
- Uses TLS 1.2 / TLS 1.3.
- Serves static WordPress files.
- Forwards PHP requests to the WordPress container.

**WordPress + PHP-FPM**

- Runs the WordPress application.
- PHP-FPM listens internally on port `9000`.
- Is not directly published to the host.

**MariaDB**

- Stores WordPress database data.
- Listens internally on port `3306`.
- Is not directly published to the host.

## Website Addresses

Main website:

```text
https://mzanana.42.fr
```

WordPress administration:

```text
https://mzanana.42.fr/wp-admin
```

A self-signed certificate may cause a browser warning during local use.

## Domain Configuration

The domain must resolve to the machine where the Docker stack runs.

When using the browser inside the same VM:

```text
127.0.0.1 mzanana.42.fr
```

can be added to `/etc/hosts`.

When accessing the website from another machine, map `mzanana.42.fr` to the VM's reachable IP instead of `127.0.0.1`.

## Credentials

Project configuration is supplied through:

```text
srcs/.env
```

Typical variables include:

```text
DOMAIN_NAME
MARIADB_DATABASE
MARIADB_USER
MARIADB_PASSWORD
MARIADB_ROOT_PASSWORD
WP_TITLE
WP_ADMIN_USER
WP_ADMIN_PASSWORD
WP_ADMIN_EMAIL
WP_USER
WP_USER_PASSWORD
WP_USER_EMAIL
```

Real passwords and credentials must remain local and must not be committed publicly to Git.

To change credentials for a completely fresh installation, update the local configuration before initializing the persistent data.

Changing the values in `.env` after WordPress/MariaDB have already initialized does not automatically rewrite every password stored in the existing database.

## Starting the Project

From the repository root:

```bash
make
```

or:

```bash
make up
```

The Makefile creates the required data directories and starts the stack with Docker Compose.

## Checking Service Status

Run:

```bash
make ps
```

or:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
```

MariaDB should show a healthy status.

Only NGINX should publish a host port, normally:

```text
0.0.0.0:443->443/tcp
```

WordPress port `9000` and MariaDB port `3306` remain internal.

## Viewing Logs

All services:

```bash
make logs
```

A specific service:

```bash
docker compose -f srcs/docker-compose.yml logs -f mariadb
```

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

```bash
docker compose -f srcs/docker-compose.yml logs -f nginx
```

## Stopping the Project

Stop and remove the running Compose containers/network while keeping persistent data:

```bash
make down
```

A later:

```bash
make up
```

should bring the website back with its existing data.

## Persistence

Persistent data is stored under:

```text
/home/mzanana/data/mariadb
/home/mzanana/data/wordpress
```

The MariaDB directory contains the WordPress database files.

The WordPress directory contains the website filesystem, including files such as:

```text
wp-content/
wp-admin/
wp-includes/
wp-config.php
```

Depending on the type of change, WordPress data may live in either storage area:

```text
Posts/pages/comments/users/settings -> MariaDB
Uploads/themes/plugins/files        -> WordPress filesystem
```

Therefore deleting either persistent storage directory can remove important website state.

## Testing Persistence

1. Create a visible change in WordPress, such as a post or comment.
2. Run:

```bash
make down
```

3. Start the stack again:

```bash
make up
```

4. Reload:

```text
https://mzanana.42.fr
```

The previous change should still be present.

## Accessing MariaDB

You can open the MariaDB client directly:

```bash
docker exec -it mariadb mariadb -u root -p
```

After entering the root password:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
```

This can be used to verify that the WordPress database exists and contains data.

## Accessing a Container Shell

MariaDB:

```bash
docker exec -it mariadb sh
```

WordPress:

```bash
docker exec -it wordpress sh
```

NGINX:

```bash
docker exec -it nginx sh
```

A shell opened with `docker exec` is only for inspection/debugging. It is not the main container process.

## Full Reset

A full reset intentionally removes persistent project data.

Use:

```bash
make fclean
```

Only run this when you really want to destroy the current database and WordPress files.

Afterward:

```bash
make
```

performs a fresh installation.

## Common Checks

Check running containers:

```bash
docker ps
```

Check networks:

```bash
docker network ls
docker network inspect inception
```

Check volumes:

```bash
docker volume ls
```

Check that NGINX can see WordPress files:

```bash
docker exec nginx ls -la /var/www/html
```

Check that WordPress sees the same files:

```bash
docker exec wordpress ls -la /var/www/html
```

Check WordPress installation status:

```bash
docker exec wordpress wp core is-installed --allow-root
```

Check the configured site title:

```bash
docker exec wordpress wp option get blogname --allow-root
```

## Troubleshooting

### Website returns 403 Forbidden

Check whether both NGINX and WordPress mount the same `wordpress_data` volume at:

```text
/var/www/html
```

Compare:

```bash
docker exec wordpress ls -la /var/www/html
docker exec nginx ls -la /var/www/html
```

### WordPress cannot connect to MariaDB

Verify:

```bash
docker compose -f srcs/docker-compose.yml ps
```

MariaDB should be healthy.

WordPress must connect to:

```text
mariadb:3306
```

and not `localhost:3306`, because `localhost` inside the WordPress container refers to the WordPress container itself.

### Browser cannot open the domain

Check domain resolution:

```bash
getent hosts mzanana.42.fr
```

and verify NGINX publishes port `443`.

## Important Safety Note

Do not commit real credentials, passwords, API keys, SSH private keys, or other confidential information to the repository.
