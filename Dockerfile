# ビルドコンテナー
FROM composer:2.0 AS builder

RUN apk add \
		freetype \
		freetype-dev \
		libpng \
		libpng-dev \
		libjpeg-turbo \
		libjpeg-turbo-dev \
	&& docker-php-ext-configure gd \
	&& docker-php-ext-install -j$(nproc) gd \
	&& apk del \
		freetype-dev \
		libpng-dev \
		libjpeg-turbo-dev \
	\
	&& rm /var/cache/apk/*

WORKDIR /var/www/html

COPY . .

RUN composer install --no-dev

# Drupalランコンテナー
# https://github.com/docker-library/drupal/blob/717c4e342cf382d057690de0f833abdc0ff99f1a/9.5/php8.1/apache-bullseye/Dockerfile
FROM php:8.1-apache-bullseye

ENV APACHE_DOCUMENT_ROOT /var/www/html/web

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf; \
	sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf;

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libwebp-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

COPY --chown=www-data:www-data --from=builder /var/www/html /var/www/html
