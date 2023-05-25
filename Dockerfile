# ビルドコンテナー
FROM composer:2 AS builder

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

WORKDIR /opt/drupal

COPY . .

RUN composer install --no-dev

# Drupalランコンテナー
# https://github.com/docker-library/drupal/blob/master/10.0/php8.2/apache-bullseye/Dockerfile
FROM php:8.2-apache-bullseye

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

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

WORKDIR /opt/drupal

COPY --chown=www-data:www-data --from=builder /opt/drupal /opt/drupal

RUN set -eux; \
	rmdir /var/www/html; \
	ln -sf /opt/drupal/web /var/www/html;

ENV PATH=${PATH}:/opt/drupal/vendor/bin

# xdebug
RUN pecl install xdebug-3.2.1 \
	&& docker-php-ext-enable xdebug
