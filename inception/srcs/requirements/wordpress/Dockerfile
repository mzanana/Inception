FROM debian:bookworm

RUN apt update && apt install -y php8.2-fpm php8.2-mysql curl \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

	
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf
	
WORKDIR /var/www/html

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]













# job of PHP-FPM

# receive request for .php
#         ↓
# execute PHP code
#         ↓
# return generated response

# in general: PHP-FPM's job is: Give me a PHP file and I will execute it.