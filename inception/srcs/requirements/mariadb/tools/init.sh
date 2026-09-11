#!/bin/sh

set -e #here we set the script if any error of any failure occure during the script running exit the script and don't continue

mkdir -p /run/mysqld #this is where mariadb can put its unix socket and pid related runtime data and -p create missing parent directories and bypass the warning message while the folder already exist 

chown mysql:mysql /run/mysqld # we change the user and the group of the mysqld/ to be managed by the user mysql and the group mysql not the root:root

chown -R mysql:mysql /var/lib/mysql #-R : recursive, this folder contain directories and sub-directories that contain the presistent database storage like system tables, wordpress database, table data ...

if [ ! -d /var/lib/mysql/mysql ]; then # check if /mysql/mysql exist which contain the system path of the core MySql database files, if not exist then the database is not initialized
	
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db
	
	mariadbd --user=mysql & #running a temporary mariadb server in the background used to execute the next SQL 
	temp_pid=$! # storing the pid of the last runned process in the background

	mariadb-admin --wait=30 ping --silent #make sure the server is initialized before running the sql queries

	mariadb <<EOF
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%'
IDENTIFIED BY '${MARIADB_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${MARIADB_DATABASE}\`.*
TO '${MARIADB_USER}'@'%';

ALTER USER 'root'@'localhost'
IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
EOF

	mariadb-admin -u root -p"${MARIADB_ROOT_PASSWORD}" shutdown

	wait "$temp_pid"

fi

touch /run/mysqld/.ready

exec mariadbd --user=mysql








#  Before:
#  
#  /var/lib/mysql
#        ↓
#     empty
#
#  
#    
#  After initialization:
#  
#  /var/lib/mysql/
#  ├── mysql/
#  ├── performance_schema/
#  ├── sys/
#  ├── internal engine files
#  └── ...