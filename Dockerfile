# ビルドコンテナー
FROM library/composer:1.9 AS builder

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
# https://github.com/docker-library/drupal/blob/master/8.9/apache/Dockerfile
FROM library/php:7.4-apache-buster

ENV APACHE_DOCUMENT_ROOT /var/www/html/web

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf; \
	sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf;

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
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
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

# xdebug install and enable
# RUN pecl install xdebug-2.9.8 && docker-php-ext-enable xdebug
RUN pecl install xdebug-2.9.8 && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

COPY --chown=www-data:www-data --from=builder /var/www/html /var/www/html
