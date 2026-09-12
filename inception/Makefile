NAME = inception

COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_PATH = /home/mzanana/data

DATA_DIRS = $(DATA_PATH)/mariadb \
			$(DATA_PATH)/wordpress

all: up

$(DATA_DIRS):
	@mkdir -p $@

up: $(DATA_DIRS)
	@$(COMPOSE) up -d --build

down:
	@$(COMPOSE) down

clean:
	@$(COMPOSE) down
	@sudo rm -rf $(DATA_PATH)

fclean:
	@$(COMPOSE) down -v --rmi local
	@sudo rm -rf $(DATA_PATH)

re: fclean all

logs:
	@$(COMPOSE) logs -f

ps:
	@$(COMPOSE) ps

.PHONY: all up down clean fclean re logs ps