#!/bin/bash

echo "=== Тестирование BookManager API ==="

# Базовый URL
BASE_URL="http://localhost:8080/api"

echo "1. Создаем книгу..."
curl -X POST $BASE_URL/books \
     -H "Content-Type: application/json" \
     -d '{
        "title": "Война и мир",
        "author": "Лев Толстой",
        "pages": 1225,
        "tags": ["классика", "роман"]
        "rating": 4.8
    }' | json_pp

echo -e "\n2. Создаем еще одну книгу..."
curl -X POST $BASE_URL/books \
     -H "Content-Type: application/json" \
     -d '{
        "title": "Преступление и наказание",
        "author": "Федор Достоевский",
        "pages": 672,
        "tags": ["классика", "роман", "психология"],
        "rating": 4.9
    }' | json_pp

echo -e "\n4. Фильтр по тегу 'классика'..."
curl $BASE_URL/books?tag=классика | json_pp

echo -e "\n5. Обновляем прогресс чтения..."
curl -X PUT $BASE_URL/books/1/progress \
     -H "Content-Type: application/json" \
     -d '{"current_page": 500}' | json_pp
    
echo -e "\n6. Получаем статистику..."
curl $BASE_URL/stats | json_pp

echo -e "\n=== Тестирование завершено ==="
