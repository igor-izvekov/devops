.PHONY: migrate rollback status init

# Переменные
DB_URL=jdbc:postgresql://localhost:5432/bookmanager
DB_USER=postgres
DB_PASS=postgres
CHANGELOG_FILE=./database/liquibase/changelog/db.changelog-master.xml

# Применить миграции
migrate:
		liquibase --url=$(DB_URL) \
				  --username=$(DB_USER) \
				  --password=$(DB_PASS) \
				  --changeLogFile=$(CHANGELOG_FILE) \
				  update

# Откатить последнюю миграцию
rollback:
		liquibase --url=$(DB_URL) \
		          --username=$(DB_USER) \
				  --password=$(DB_PASS) \
				  --changeLogFile=$(CHANGELOG_FILE) \
				  rollbackCount 1

# Посмотреть статус
status:
		liquibase --url=$(DB_URL) \
				  --username=$(DB_USER) \
			      --password=$(DB_PASS) \
				  --changeLogFile=$(CHANGELOG_FILE) \
				  status

# Сгенерировать новую миграцию
new-migration:
		@read -p "Enter migration name: " name; \
		timestamp=$$(date +%Y%m%d%H%M%S); \
		filename="database/liquibase/changelog/v1.1/$${timestamp}-$${name}.xml"; \
		touch $$filename; \
		echo "Created $$filename"
