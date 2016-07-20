FROM php:apache
MAINTAINER Eric Rasche <esr@tamu.edu>

ENTRYPOINT ["/entrypoint.sh"]

# Provide compatibility for images depending on previous versions
RUN ln -s /var/www/html /app
# Update apache2 configuration for drupal
RUN a2enmod rewrite && a2enmod proxy && a2enmod proxy_http

# Install packages and PHP-extensions
RUN apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install \
    file libfreetype6 libjpeg62 libpng12-0 libpq-dev libx11-6 libxpm4 \
    postgresql-client wget patch && \
    BUILD_DEPS="libfreetype6-dev libjpeg62-turbo-dev libmcrypt-dev libpng12-dev libxpm-dev re2c zlib1g-dev"; \
    DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install $BUILD_DEPS \
 && docker-php-ext-configure gd \
        --with-jpeg-dir=/usr/lib/x86_64-linux-gnu --with-png-dir=/usr/lib/x86_64-linux-gnu \
        --with-xpm-dir=/usr/lib/x86_64-linux-gnu --with-freetype-dir=/usr/lib/x86_64-linux-gnu \
 && docker-php-ext-install gd mbstring pdo_pgsql zip \
 && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_DEPS \
 && rm -rf /var/lib/apt/lists/* \
 && pecl install uploadprogress

# Download Drupal from ftp.drupal.org
ENV DRUPAL_VERSION=7.50
ENV DRUPAL_TARBALL_MD5=f23905b0248d76f0fc8316692cd64753
WORKDIR /var/www
RUN rm -R html \
 && curl -OsS https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz \
 && echo "${DRUPAL_TARBALL_MD5}  drupal-${DRUPAL_VERSION}.tar.gz" | md5sum -c \
 && tar -xf drupal-${DRUPAL_VERSION}.tar.gz && rm drupal-${DRUPAL_VERSION}.tar.gz \
 && mv drupal-${DRUPAL_VERSION} html \
 && cd html \
 && rm [A-Z]*.txt install.php web.config sites/default/default.settings.php

# Install composer and drush by using composer
ENV COMPOSER_BIN_DIR=/usr/local/bin
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
 && composer global require drush/drush:7.* \
 && drush cc drush \
 && mkdir /etc/drush && echo "<?php\n\$options['yes'] = TRUE;\n\$options['v'] = TRUE;\n" > /etc/drush/drushrc.php

# Add PHP-settings
ADD php-conf.d/ $PHP_INI_DIR/conf.d/

# copy sites/default's defaults
WORKDIR html
ADD sites/ sites/

# Add README.md, entrypoint-script and scripts-folder
ADD entrypoint.sh README.md  /
ADD /scripts/ /scripts/

RUN wget https://cpt.tamu.edu/jenkins/job/Chado-Prebuilt-Schemas/19/artifact/compile-chado-schema/chado/default/chado-master-tripal.sql.gz -O /chado-master-tripal.sql.gz

ADD tripal_chado_install /scripts/setup.d/50tripal_chado_install
ADD tripal_apache.conf /etc/apache2/conf-enabled/tripal_apache.conf