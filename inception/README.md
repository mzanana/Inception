*This project has been created as part of the 42 curriculum by mzanana.*

# Inception

## Description

Inception is a system-administration project focused on learning Docker by building a small multi-container infrastructure inside a virtual machine.

The mandatory stack contains three services, each running in its own container and built from a custom Dockerfile based on Debian:

- **NGINX** — the only public entry point, exposed on port `443` and configured for TLS 1.2 / TLS 1.3.
- **WordPress + PHP-FPM** — runs WordPress and listens internally on port `9000`.
- **MariaDB** — stores the WordPress database and listens internally on port `3306`.

The containers communicate through a dedicated Docker network. WordPress files and MariaDB data are persisted with Docker named volumes whose data is stored under `/home/mzanana/data` on the host.

The project domain is:

```text
mzanana.42.fr
```

## Architecture

```text
                         Browser
                            |
                            | HTTPS :443
                            v
                        +-------+
                        | NGINX |
                        +-------+
                            |
                            | FastCGI
                            | wordpress:9000
                            v
                  +---------------------+
                  | WordPress + PHP-FPM |
                  +---------------------+
                            |
                            | SQL
                            | mariadb:3306
                            v
                       +---------+
                       | MariaDB |
                       +---------+

Persistent storage:

/home/mzanana/data/wordpress
        ^
        |
 wordpress_data
        |
        +----> WordPress /var/www/html
        |
        +----> NGINX     /var/www/html

/home/mzanana/data/mariadb
        ^
        |
  mariadb_data
        |
        +----> MariaDB /var/lib/mysql
```

Only NGINX publishes a port to the host. WordPress and MariaDB are reachable only through the internal Docker network.

## Project Structure

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

The exact local secret/configuration files may be ignored by Git when they contain credentials.

## Why This Directory Structure?

The directory structure separates responsibilities:

- The **Makefile** is the main entry point used to build and manage the project.
- `srcs/docker-compose.yml` describes the complete infrastructure.
- `srcs/.env` contains environment configuration used by the services.
- `requirements/` separates each service.
- Each service has its own **Dockerfile** describing how its image is built.
- `conf/` contains service configuration files.
- `tools/` contains initialization/runtime scripts.

This keeps the infrastructure understandable, reproducible, and easier to maintain.

## Instructions

### Prerequisites

The project must run inside a Linux virtual machine with:

- Docker
- Docker Compose
- Make

The following host directories are used for persistent data:

```text
/home/mzanana/data/mariadb
/home/mzanana/data/wordpress
```

The Makefile creates them when necessary.

The domain must resolve to the machine running the stack. When the browser is running inside the same VM, `/etc/hosts` can contain:

```text
127.0.0.1 mzanana.42.fr
```

If the website is accessed from another machine, `mzanana.42.fr` must resolve to the VM's reachable IP instead of `127.0.0.1`.

### Environment Configuration

Create `srcs/.env` locally before starting the stack.

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

Do not commit real credentials, passwords, or API keys to the repository.

### Build and Start

From the repository root:

```bash
make
```

or:

```bash
make up
```

Useful commands:

```bash
make ps
make logs
make down
make clean
make fclean
make re
```

### Access

Website:

```text
https://mzanana.42.fr
```

WordPress administration:

```text
https://mzanana.42.fr/wp-admin
```

Because the certificate is self-signed, the browser may display a certificate warning during local development/evaluation.

## Technical Overview

### Containerization, Containers, and Docker

**Containerization** is the technique of packaging and isolating an application together with the runtime dependencies and configuration it needs.

A **container** is an isolated execution environment created using operating-system mechanisms such as namespaces and cgroups. A container is not a virtual machine. The processes inside containers share the host Linux kernel.

**Docker** provides the tooling used to build images, create and run containers, manage networks and volumes, and control the container lifecycle.

The Docker CLI communicates with the Docker daemon, which manages Docker objects such as images, containers, networks, and volumes.

### Docker Images and Containers

A Docker image is a read-only template used to create containers.

A container is a running or stopped instance created from an image. It adds a writable container layer on top of the image.

The image itself is the same whether it is used manually with `docker run` or through Docker Compose. Docker Compose changes how the containers and related resources are orchestrated, not what an image fundamentally is.

### Docker Compose

Docker Compose is used to describe a multi-container application declaratively in YAML.

Without Compose, the same infrastructure would require many separate commands to:

- build images;
- create containers;
- create a network;
- create/mount volumes;
- publish ports;
- inject environment variables;
- define service dependencies.

With Compose, these relationships are declared in one file and managed with commands such as:

```bash
docker compose up
docker compose down
```

## Main Design Choices

### Virtual Machines vs Docker

A virtual machine virtualizes hardware and normally runs a complete guest operating system with its own kernel.

Docker containers share the host Linux kernel and isolate processes and resources using Linux mechanisms. Containers are therefore usually lighter, start faster, and consume fewer resources than full virtual machines.

This project still runs **inside a VM** because the subject requires an isolated machine in which the Docker infrastructure is built and tested.

### Secrets vs Environment Variables

Environment variables are convenient for configuration such as:

- domain name;
- database name;
- database username;
- WordPress site title;
- email addresses.

Passwords and other confidential values require more care.

A `.env` file is used to provide environment variables to Docker Compose, but a `.env` file is not automatically secure simply because it is named `.env`. Real credentials must not be committed to Git.

Docker secrets provide a file-based mechanism for making sensitive values available to containers, commonly under `/run/secrets/`. They are preferable for confidential values when used, while normal environment variables remain useful for non-secret configuration.

### Docker Network vs Host Network

The project uses a dedicated Docker network.

This gives each service its own isolated network namespace while allowing containers on the same Docker network to communicate using service names such as:

```text
mariadb
wordpress
nginx
```

For example:

```text
wordpress -> mariadb:3306
nginx     -> wordpress:9000
```

Host networking would make containers share the host's network namespace, reduce isolation, and create direct port conflicts. It is not used in this project.

### Docker Volumes vs Bind Mounts

A Docker named volume is managed as a Docker volume and can be attached to containers using a stable logical name.

A direct bind mount maps an arbitrary host path directly into a container.

For this project, the services mount **named volumes**:

```text
mariadb_data
wordpress_data
```

The named volumes are configured so their persistent data is stored under:

```text
/home/mzanana/data/mariadb
/home/mzanana/data/wordpress
```

The WordPress volume is shared between WordPress and NGINX because both services need access to the website files.

## Service Details

### MariaDB

MariaDB stores the WordPress database.

During the first startup, its initialization script:

1. prepares runtime directories;
2. initializes the database files if needed;
3. starts a temporary MariaDB server;
4. creates the WordPress database and database user;
5. configures the root password;
6. stops the temporary server;
7. starts the final MariaDB process in the foreground.

The final MariaDB server becomes the main process of the container.

A healthcheck is used so WordPress starts only after MariaDB is ready.

### WordPress

The WordPress container contains WordPress and PHP-FPM, but not NGINX.

Its initialization script:

1. downloads WordPress if the files do not exist;
2. creates `wp-config.php` if necessary;
3. installs WordPress if the database has not already been initialized;
4. creates the required administrator and normal WordPress users;
5. gives the website files the appropriate ownership;
6. starts PHP-FPM in the foreground.

PHP-FPM listens on port `9000` inside the Docker network.

### NGINX

NGINX is the only public entry point.

It:

- listens on port `443`;
- uses a TLS certificate;
- accepts TLS 1.2 and TLS 1.3;
- serves static WordPress files directly;
- forwards PHP requests to `wordpress:9000` using FastCGI.

## Persistence

Containers are disposable. Persistent application data is not stored only in the container writable layer.

MariaDB data persists in:

```text
/home/mzanana/data/mariadb
```

WordPress filesystem data persists in:

```text
/home/mzanana/data/wordpress
```

WordPress posts, pages, users, comments, settings, and many site-editor changes are stored in MariaDB. Uploaded media, installed plugins, themes, and WordPress files are stored in the WordPress filesystem volume.

A normal:

```bash
docker compose down
docker compose up -d
```

recreates containers while keeping the persistent data, unless the volumes/data are explicitly deleted.

## Resources

The following resources were useful while studying and implementing the project:

- Docker documentation: https://docs.docker.com/
- Docker Compose documentation: https://docs.docker.com/compose/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- NGINX documentation: https://nginx.org/en/docs/
- MariaDB documentation: https://mariadb.com/kb/en/documentation/
- WordPress documentation: https://wordpress.org/documentation/
- WP-CLI documentation: https://wp-cli.org/
- Linux namespaces documentation: `man 7 namespaces`
- Linux cgroups documentation: `man 7 cgroups`
- The Inception project subject provided by 42.

## AI Usage

AI was used as a learning and review assistant during this project.

It was used to:

- explain Docker/container concepts;
- discuss PID 1, namespaces, networks, images, volumes, and Docker Compose;
- review Dockerfiles, Compose configuration, shell initialization scripts, and NGINX configuration;
- help reason about errors observed during testing;
- review documentation for clarity.

All generated suggestions were reviewed, tested, and adapted to the actual project. The final implementation and technical choices are understood and can be explained during evaluation.
