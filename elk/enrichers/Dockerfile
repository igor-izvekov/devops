FROM python:3.12-slim
WORKDIR /app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Копирование кода
COPY . .

# Скачивание GeoIP базы (опционально)
RUN mkdir -p /data && \
    wget -q https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz && \
    tar -xzf GeoLite2-City.tar.gz -C /data --strip=1 && \
    rm GeoLite2-City.tar.gz

# Запуск (будет переопределяться в docker-compose)
CMD ["python", "base_consumer.py"]
