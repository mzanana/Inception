# Inception — Developer Documentation

## Purpose

This document explains how to reproduce, build, run, inspect, and maintain the Inception infrastructure from a clean environment.

The project contains three mandatory services:

```text
NGINX
WordPress + PHP-FPM
MariaDB
```

Each service runs in its own container and is built from a custom Dockerfile.

## Prerequisites

The project must run inside a Linux virtual machine.

Required tools:

```text
Docker
Docker Compose
Make
```

Verify:

```bash
docker --version
docker compose version
make --version
```

The current implementation uses Debian Bookworm as the service base image.

## Repository Layout

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs
    ├── docker-compose.yml
    ├── .env
    └── requirements
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf
        │   │   └── mariadb.cnf
        │   └── tools
        │       └── init.sh
        ├── nginx
        │   ├── Dockerfile
        │   └── conf
        │       └── nginx.conf
        └── wordpress
            ├── Dockerfile
            └── tools
                └── init.sh
```

## Local Configuration

Create:

```text
srcs/.env
```

Example:

```env
DOMAIN_NAME=mzanana.42.fr

MARIADB_DATABASE=wordpress
MARIADB_USER=wpuser
MARIADB_PASSWORD=CHANGE_ME
MARIADB_ROOT_PASSWORD=CHANGE_ME

WP_TITLE=Inception
WP_ADMIN_USER=bob
WP_ADMIN_PASSWORD=CHANGE_ME
WP_ADMIN_EMAIL=bob@example.com

WP_USER=user1
WP_USER_PASSWORD=CHANGE_ME
WP_USER_EMAIL=user1@example.com
```

Never commit real credentials to Git.

If Docker secrets are introduced later, confidential values can be mounted into containers as files and read by the initialization scripts instead of being kept as normal environment variables.

## Required Host Storage

Persistent project data is stored under:

```text
/home/mzanana/data/mariadb
/home/mzanana/data/wordpress
```

The Makefile creates these directories before starting the stack.

## Domain Resolution

When the browser runs in the VM itself:

```text
127.0.0.1 mzanana.42.fr
```

may be added to `/etc/hosts`.

When evaluating from the 1337 host while Docker runs inside the VM, the host must resolve `mzanana.42.fr` to the VM's reachable IP, not to the host's `127.0.0.1`.

## Build and Launch

From the repository root:

```bash
make
```

The Makefile ultimately runs Docker Compose with:

```text
srcs/docker-compose.yml
```

A typical startup flow is:

```text
create host data directories
        |
        v
build service images
        |
        v
create Docker network/volumes/containers
        |
        v
start MariaDB
        |
        v
MariaDB becomes healthy
        |
        v
start WordPress
        |
        v
start NGINX
```

## Makefile Commands

Start/build:

```bash
make
make up
```

Stop:

```bash
make down
```

Show status:

```bash
make ps
```

Follow logs:

```bash
make logs
```

Clean/reset targets:

```bash
make clean
make fclean
make re
```

`fclean` is destructive if it removes the named volumes and `/home/mzanana/data`.

## Docker Compose Architecture

### Services

The Compose file defines:

```text
mariadb
wordpress
nginx
```

All three are attached to the dedicated:

```text
inception
```

network.

### NGINX

Only NGINX publishes a host port:

```text
443:443
```

NGINX forwards PHP requests to:

```text
wordpress:9000
```

### WordPress

WordPress uses PHP-FPM on:

```text
0.0.0.0:9000
```

inside the Docker network.

It connects to MariaDB using:

```text
mariadb:3306
```

It must not use `localhost:3306`, because each container has its own network namespace.

### MariaDB

MariaDB listens internally on:

```text
0.0.0.0:3306
```

It is not published to the host.

## Persistent Volumes

The Compose configuration defines two named volumes:

```text
mariadb_data
wordpress_data
```

`mariadb_data` is mounted at:

```text
/var/lib/mysql
```

inside MariaDB.

`wordpress_data` is mounted at:

```text
/var/www/html
```

inside both WordPress and NGINX.

NGINX and WordPress must use the exact same WordPress volume. Sharing only the same container path is not enough; they must mount the same Docker volume object.

## MariaDB Initialization

The MariaDB entrypoint script follows two paths.

### First Start

If:

```text
/var/lib/mysql/mysql
```

does not exist:

1. create `/run/mysqld`;
2. set filesystem ownership;
3. initialize MariaDB system tables;
4. start a temporary MariaDB server;
5. wait for it to become available;
6. create the WordPress database;
7. create the WordPress database user;
8. grant permissions;
9. configure the MariaDB root password;
10. shut down the temporary server;
11. create the runtime readiness marker;
12. `exec` the final MariaDB server.

### Later Starts

If the database is already initialized, the initialization phase is skipped and the existing persistent database is reused.

The final command is executed with `exec`, so MariaDB becomes the container's main process instead of leaving an unnecessary shell as PID 1.

## MariaDB Healthcheck

The MariaDB service uses a healthcheck that verifies:

- the initialization readiness marker exists;
- `mariadb-admin ping` can successfully reach the server.

WordPress depends on MariaDB reaching the healthy state before WordPress starts.

An unhealthy healthcheck status does not itself restart a running container. Restart policies react to container process exit, while healthchecks communicate application health.

## WordPress Initialization

The WordPress entrypoint script:

1. checks whether WordPress files exist;
2. downloads WordPress using WP-CLI if necessary;
3. creates `wp-config.php` if necessary;
4. checks whether WordPress is already installed;
5. installs the site on a fresh database;
6. creates the required second WordPress user;
7. applies appropriate ownership to `/var/www/html`;
8. starts PHP-FPM in the foreground.

The script must be idempotent enough to avoid reinstalling an already initialized site on every container restart.

## NGINX Configuration

NGINX:

- listens on `443 ssl`;
- uses the domain `mzanana.42.fr`;
- is configured for TLS 1.2 and TLS 1.3;
- serves static files from `/var/www/html`;
- forwards PHP requests to `wordpress:9000`;
- uses `SCRIPT_FILENAME` so PHP-FPM knows which PHP file to execute.

The WordPress front-controller behavior is handled with a fallback to `index.php` for routes that do not directly map to a static file.

## PID 1 and Foreground Processes

Containers must not be kept alive with commands such as:

```text
tail -f
sleep infinity
while true
```

The actual service should stay in the foreground.

The final processes are expected to behave approximately as:

```text
MariaDB container  -> mariadbd as main process
WordPress container -> php-fpm8.2 -F as main process
NGINX container    -> nginx -g "daemon off;" as main process
```

Using `exec` in shell entrypoint scripts replaces the shell with the final application so signals are delivered correctly to the service.

## Useful Docker Commands

Validate Compose configuration:

```bash
docker compose -f srcs/docker-compose.yml config
```

Show running services:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Show all Docker containers:

```bash
docker ps -a
```

Inspect the network:

```bash
docker network inspect inception
```

List volumes:

```bash
docker volume ls
```

Inspect one volume:

```bash
docker volume inspect <volume_name>
```

Open a service shell:

```bash
docker exec -it mariadb sh
docker exec -it wordpress sh
docker exec -it nginx sh
```

## Database Validation

Open MariaDB:

```bash
docker exec -it mariadb mariadb -u root -p
```

Then:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT ID, user_login FROM wp_users;
```

This verifies that the WordPress database exists, contains tables, and contains application data.

## WordPress Validation

Check installation:

```bash
docker exec wordpress wp core is-installed --allow-root
```

Check the site URL:

```bash
docker exec wordpress wp option get siteurl --allow-root
```

Check the site title:

```bash
docker exec wordpress wp option get blogname --allow-root
```

List users:

```bash
docker exec wordpress wp user list --allow-root
```

## NGINX/TLS Validation

Check NGINX configuration syntax:

```bash
docker exec nginx nginx -t
```

Test HTTPS:

```bash
curl -kI https://mzanana.42.fr
```

TLS 1.2:

```bash
openssl s_client -connect mzanana.42.fr:443 -tls1_2
```

TLS 1.3:

```bash
openssl s_client -connect mzanana.42.fr:443 -tls1_3
```

Old protocol versions should not be accepted.

## Persistence Test

Create a visible WordPress change such as a post or comment.

Then:

```bash
make down
make up
```

The change should remain.

This proves the data survives container recreation.

## Clean Reproduction Test

Before evaluation, perform a clean-room test.

1. Save/commit the project files.
2. Intentionally remove the current project runtime state using the project's destructive cleanup target.
3. Confirm the persistent data directories are empty/removed.
4. Run:

```bash
make
```

5. Verify:
   - all three images build;
   - MariaDB initializes;
   - MariaDB becomes healthy;
   - WordPress installs;
   - both WordPress users exist;
   - NGINX starts;
   - only port `443` is published;
   - `https://mzanana.42.fr` works.

The goal is to prove the submitted repository can rebuild the infrastructure without depending on stale containers, images, or existing database state.

## Git and Credential Safety

Before pushing:

```bash
git status
git ls-files
```

Verify no real credentials are tracked.

Never commit:

```text
real database passwords
real WordPress passwords
API keys
SSH private keys
```

If a secret was committed previously, simply adding it to `.gitignore` later does not remove it from Git history. Rotate exposed credentials and clean the repository history if necessary.

## Data Locations

Host:

```text
/home/mzanana/data/mariadb
/home/mzanana/data/wordpress
```

Inside containers:

```text
MariaDB:
  /var/lib/mysql

WordPress:
  /var/www/html

NGINX:
  /var/www/html
```

MariaDB owns database persistence.

The WordPress volume stores website files and is shared with NGINX.

Application-level WordPress content such as posts, users, comments, and settings is primarily stored in MariaDB.
