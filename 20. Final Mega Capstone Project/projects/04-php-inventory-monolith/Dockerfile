FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM composer:2.8 AS vendor
WORKDIR /app
COPY app/composer.json ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --classmap-authoritative

FROM php:8.3-apache
RUN apt-get update && apt-get install -y --no-install-recommends curl libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*
COPY app/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY app/ /var/www/html/
COPY --from=vendor /app/vendor /var/www/html/vendor
COPY --from=frontend /src/dist /var/www/html/public
RUN chown -R www-data:www-data /var/www/html /var/run/apache2 /var/lock/apache2
USER www-data
ENV APACHE_RUN_DIR=/tmp/apache2 APACHE_LOCK_DIR=/tmp/apache2 APACHE_PID_FILE=/tmp/apache2/apache2.pid APACHE_LOG_DIR=/tmp/apache2
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost:8080/health || exit 1
