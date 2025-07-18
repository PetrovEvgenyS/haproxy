#!/bin/bash

# Переменная для конфигурационного файла HAProxy
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"


# --------------------------------------------------------


# Проверка запуска через sudo
if [ -z "$SUDO_USER" ]; then
    errorprint "Пожалуйста, запустите скрипт через sudo."
    exit 1
fi

# Обновить список доступных пакетов.
apt -y update

# Установка HAProxy
apt -y install haproxy

# Создание резервной копии конфигурационного файла:
#  - Проверяется наличие конфигурационного файла.
#  - Если файл существует, создается его резервная копия.
echo "Создание резервной копии конфигурационного файла..."
if [ -f "$HAPROXY_CONFIG" ]; then
    cp "$HAPROXY_CONFIG" "$HAPROXY_CONFIG.bak"
    echo "Резервная копия создана в файле haproxy.cfg.bak"
else 
    echo "Конфигурационный файл не найден, пропуск создания резервной копии."
fi

# Настройка конфигурации HAProxy:
#  - В конфигурационный файл записывается пример настройки с фронтендом и бекендом.
echo "Настройка конфигурации HAProxy..."
bash -c "cat > $HAPROXY_CONFIG <<EOL
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

# ========== Configuration ==========

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
    server Nginx01 10.100.10.1:8080 check
    server Nginx02 10.100.10.2:8080 check
    server Nginx03 10.100.10.3:8080 check

# ========== Configuration ==========

EOL"

# Проверка синтаксиса конфигурационного файла HAProxy:
haproxy -c -f "$HAPROXY_CONFIG"

# Перезапустить службу HAProxy для применения изменений
systemctl restart haproxy

# Добавить HAProxy в автозапуск при загрузке системы
systemctl enable haproxy

echo "Установка HAProxy завершена!"
haproxy -v