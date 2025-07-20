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
#  - Добавляет пример настройки с фронтендом и бекендом в конец файла конфигурации.
magentaprint "Добавление конфигурации HAProxy в конец файла ..."
cat <<EOF >> $HAPROXY_CONFIG

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