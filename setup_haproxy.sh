#!/bin/bash

# Переменные
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"       # Конфигурационный файл HAProxy


### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ##
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# --------------------------------------------------------


# Проверка запуска через sudo
if [ -z "$SUDO_USER" ]; then
    errorprint "Пожалуйста, запустите скрипт через sudo."
    exit 1
fi

magentaprint "Установка HAProxy ..."
apt -y install haproxy

# Создание резервной копии конфигурационного файла:
#  - Проверяется наличие конфигурационного файла.
#  - Если файл существует, создается его резервная копия.
magentaprint "Создание резервной копии конфигурационного файла ..."
if [ -f "$HAPROXY_CONFIG" ]; then
    cp "$HAPROXY_CONFIG" "$HAPROXY_CONFIG.bak"
    greenprint "Резервная копия создана в файле haproxy.cfg.bak"
else 
    errorprint "Конфигурационный файл не найден, пропуск создания резервной копии."
fi

# Настройка конфигурации HAProxy:
#  - В конфигурационный файл записывается пример настройки с фронтендом и бекендом.
magentaprint "Настройка конфигурации HAProxy ..."
cat <<EOF > $HAPROXY_CONFIG
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon 

    # Default SSL material locations
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

    # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# ========== Configuration begin ==========

# Настройка веб-интерфейса для мониторинга статистики.
# Этот интерфейс будет доступен по HTTP и защищен аутентификацией.
listen stats
        bind 0.0.0.0:8989
        mode http
        stats enable
        stats uri /haproxy_stats
        stats realm HAProxy Statistics
        stats auth admin:pass123
        stats admin if TRUE
        # Т.е. доступ к статистике через http://<IP_или_Доменное_имя_вашего_сервера>:8989/haproxy_stats


# Обработка входящего HTTP-трафика:
frontend http_front
    bind *:80
    default_backend http_back   
   

# Обработка трафика на конечных серверах:
backend http_back
    balance roundrobin
    server nginx01 node-vm01.local:8080 check
    server nginx02 node-vm02.local:8080 check
    server nginx03 node-vm03.local:8080 check

# ========== Configuration end ==========

EOF

magentaprint "Проверка синтаксиса конфигурационного файла HAProxy:"
haproxy -c -f "$HAPROXY_CONFIG"

magentaprint "Запуск и добавление в автозагрузку HAProxy"
systemctl enable --now haproxy

magentaprint "Проверка статуса HAProxy:"
systemctl status haproxy --no-pager

magentaprint "Проверка версии HAProxy:"
haproxy -v

greenprint "Установка HAProxy завершена!"