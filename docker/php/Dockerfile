# syntax=docker/dockerfile:1
# ============================================================================
#  ToroGo - Imagen PHP para Laravel 12
#  Base: PHP 8.4 FPM (Debian). Laravel 12 requiere PHP >= 8.2.
# ============================================================================

ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm

# ----------------------------------------------------------------------------
# Librerias del sistema + extensiones de PHP que Laravel necesita:
#   pdo_pgsql / pgsql .... PostgreSQL
#   redis ................ cache y colas (via PECL)
#   intl ................. formatos de fecha/moneda (es_SV)
#   gd ................... procesar imagenes (logos, fotos de platos)
#   zip .................. composer y exports
#   bcmath ............... dinero / calculos con decimales
#   pcntl ................ colas y procesos en background
#   opcache .............. rendimiento
#
# NOTA: el "rm -rf" y el "purge" de abajo corren DENTRO de la imagen Docker
#       que se construye. NO tocan nada de tu PC.
# ----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        git \
        curl \
        unzip \
        zip \
        libpq-dev \
        libicu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libxml2-dev \
    # El paquete de desarrollo de freetype cambio de nombre en Debian 13 (trixie).
    # Probamos el nombre nuevo y si no existe caemos al viejo.
    && (apt-get install -y --no-install-recommends libfreetype-dev \
        || apt-get install -y --no-install-recommends libfreetype6-dev) \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        opcache \
        pcntl \
        pdo_pgsql \
        pgsql \
        sockets \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $PHPIZE_DEPS \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

# Composer 2 oficial, copiado desde su propia imagen (siempre actualizado)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configuracion de PHP propia del proyecto
COPY conf.d/zz-torogo.ini /usr/local/etc/php/conf.d/zz-torogo.ini

WORKDIR /var/www/html

EXPOSE 9000

CMD ["php-fpm"]
