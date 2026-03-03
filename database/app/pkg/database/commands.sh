# Применить миграции
make migrate

# Или через Docker
docker-compose run --rm liquibase

# Посмотреть статус
make status

# Откатить миграцию
make rollback

# Создать новую миграцию
make new-migration
