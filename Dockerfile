ARG codename=trixie
FROM debian:${codename} AS debian

ENV	DEBIAN_FRONTEND=noninteractive \
	TZ="Asia/Taipei"

ARG S6_VERSION=v3.2.1.0
ARG TARGETARCH
	
WORKDIR /
RUN	set -eux; \
    case "$TARGETARCH" in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="aarch64" ;; \
        arm) ARCH="arm" ;; \
        *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
    esac; \
	apt-get update -y && apt-get dist-upgrade -y && \
	apt-get install --no-install-recommends --no-install-suggests -y \
	  bash bash-completion sudo openssl ca-certificates apt-transport-https \
#	  cron postfix \
	  gnupg dirmngr curl wget xz-utils jq git net-tools dnsutils procps vim.tiny && \
	apt-get -y autoremove && apt-get -y autoclean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -L -o /tmp/s6-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.xz; \
    curl -L -o /tmp/s6-arch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${ARCH}.tar.xz; \
	curl -L -o /tmp/s6-overlay-symlinks-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-symlinks-noarch.tar.xz; \
	curl -L -o /tmp/s6-overlay-symlinks-arch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-symlinks-arch.tar.xz; \
    curl -L -o /tmp/syslogd-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/syslogd-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-arch.tar.xz; \
	tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz; \
	tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz; \
	tar -C / -Jxpf /tmp/syslogd-overlay-noarch.tar.xz; \
    rm -f /tmp/*.tar.xz


FROM debian AS php
ARG	PHP=8.4

RUN	apt-get update -y && apt-get dist-upgrade -y && \
	apt-get install --no-install-recommends --no-install-suggests -y extrepo && \
	extrepo enable nginx && \
	extrepo enable sury && \
	apt-get update -y && apt-get dist-upgrade -y && \
	apt-get install --no-install-recommends --no-install-suggests -y nginx php${PHP}-fpm php${PHP}-cli && \
	apt-get purge -y extrepo && \
	apt-get -y autoremove && apt-get -y autoclean && \
	curl https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin && \
	mkdir -p /.composer && chmod 777 /.composer && \
	mkdir -p /run/php/ && chmod 777 /run/php/ && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV	TZ="Asia/Taipei" \
	PHP=${PHP} \
	PHP_ERROR_LOG=syslog \
	PHP_LOG_ERRORS=1 \
	PHP_DISPLAY_ERRORS=1 \
	PHP_ERROR_REPORTING=-1 \
	PHP_SHORT_OPEN_TAG=0 \
	PHP_MAX_EXECUTION_TIME=300 \
	PHP_MAX_INPUT_TIME=300 \
	PHP_MEMORY_LIMIT=1024M \
	PHP_CLI_MEMORY_LIMIT=1024M \
	PHP_POST_MAX_SIZE=512M \
	PHP_UPLOAD_MAX_FILESIZE=512M \
	PHP_SESSION_NAME=PHPSESSID \
	PHP_SESSION_SAVE_HANDLER=files \
	PHP_SESSION_SAVE_PATH=/tmp \
	PHPFPM_LISTEN=127.0.0.1:9000 \
	PHPFPM_USER=nobody \
	PHPFPM_GROUP=nogroup \
	PHPFPM_PM=ondemand \
	PHPFPM_PM_MAX_CHILDREN=32 \
	PHPFPM_PM_START_SERVERS=4 \
	PHPFPM_PM_MIN_SPARE_SERVERS=2 \
	PHPFPM_PM_MAX_SPARE_SERVERS=6 \
	PHPFPM_PM_MAX_REQUESTS=16

FROM php AS phpext

RUN	apt-get update -y && apt-get dist-upgrade -y && \
	apt-get install --no-install-recommends --no-install-suggests -y \
#   almost everything
#	$(apt-cache search php | grep ^php${PHP}- | grep -v dbgsym | grep -v php${PHP}-dev | grep -v php${PHP}-gmagick | grep -v php${PHP}-phalcon | grep -v php${PHP}-redis | grep -v php${PHP}-yac | grep -v php${PHP}-uopz | awk '{print $1}' | xargs echo) \
#   or minimum requirement for Laravel
    php${PHP}-curl php${PHP}-gd php${PHP}-intl php${PHP}-mbstring php${PHP}-mysql php${PHP}-opcache php${PHP}-readline php${PHP}-xml php${PHP}-zip php${PHP}-bcmath php${PHP}-bz2 php${PHP}-dba php${PHP}-enchant php${PHP}-gmp php${PHP}-ldap php${PHP}-pgsql php${PHP}-soap php${PHP}-sqlite3 php${PHP}-tidy php${PHP}-xsl && \
	apt-get -y autoremove && apt-get -y autoclean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM phpext AS phpdev

RUN	apt-get update -y && apt-get dist-upgrade -y && \
	apt-get install --no-install-recommends --no-install-suggests -y \
	gettext-base libmcrypt4 unzip make \
	php-pear \
	php${PHP}-dev build-essential libpcre3-dev pkg-config libmcrypt-dev && \
	# pecl script here...
	apt-get purge -y php${PHP}-dev build-essential libpcre3-dev pkg-config libmcrypt-dev && \
	apt-get -y autoremove && apt-get -y autoclean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY	s6-overlay /etc/s6-overlay
COPY	cont-init.d /etc/cont-init.d
COPY	index.php /app/public/index.php
COPY	nginx /etc/nginx/conf.d/
COPY	php-fpm-www.conf /etc/php/${PHP}/fpm/php-fpm-www.conf


VOLUME /app

EXPOSE	80

ENTRYPOINT	["/init"]
