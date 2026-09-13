=======================================================
               SING-BOX ON SMARTBOX / PADAVAN
=======================================================

1. CONFIGURATION SETUP:
-----------------------
This directory contains two sample configuration templates:
- config_vless.json  -> Template for VLESS + XTLS-Reality
- config_hy2.json    -> Template for Hysteria 2

Select the desired protocol and copy or rename it to config.json:
  cp config_vless.json config.json
(or paste your ready config.json provided by your server).

In config.json, replace placeholder values with your actual server credentials:
- YOUR_SERVER_IP          -> Your VPS IP address
- YOUR_UUID_HERE          -> Your client UUID (for VLESS)
- YOUR_REALITY_PUBLIC_KEY -> Server's Reality public key
- YOUR_SHORT_ID           -> Reality short_id (if used)
- YOUR_PASSWORD_HERE      -> Server password (for Hysteria 2)


2. MANAGEMENT VIA SSH / ROUTER CONSOLE:
---------------------------------------
Start service:
  /media/smartbox/sing-box/sing-box.sh start

Stop service:
  /media/smartbox/sing-box/sing-box.sh stop

Restart service:
  /media/smartbox/sing-box/sing-box.sh restart

Check status and live logs:
  /media/smartbox/sing-box/sing-box.sh status
  tail -f /var/log/sing-box.log


3. AUTOSTART ON ROUTER BOOT:
----------------------------
In Padavan Web UI:
  "Customization" -> "Scripts" -> "Run After Router Started"

Add the following command:
  /media/smartbox/sing-box/sing-box.sh start &

Click "Apply" at the bottom of the page.


=======================================================
               SING-BOX НА SMARTBOX / PADAVAN
=======================================================

1. НАСТРОЙКА КОНФИГУРАЦИИ:
--------------------------
В этой папке лежат два шаблона конфигурации:
- config_vless.json  -> шаблон для VLESS + XTLS-Reality
- config_hy2.json    -> шаблон для Hysteria 2

Выберите нужный вариант, скопируйте или переименуйте его в config.json:
  cp config_vless.json config.json
(или скопируйте готовый config.json от вашего сервера).

В файле config.json замените параметры-заглушки на ваши реальные данные:
- YOUR_SERVER_IP          -> IP-адрес вашего сервера VPS
- YOUR_UUID_HERE          -> ваш UUID (для VLESS)
- YOUR_REALITY_PUBLIC_KEY -> публичный ключ Reality
- YOUR_SHORT_ID           -> short_id (если используется)
- YOUR_PASSWORD_HERE      -> пароль (для Hysteria 2)


2. УПРАВЛЕНИЕ ЧЕРЕЗ SSH / КОНСОЛЬ РОУТЕРА:
------------------------------------------
Запуск:
  /media/smartbox/sing-box/sing-box.sh start

Остановка:
  /media/smartbox/sing-box/sing-box.sh stop

Перезапуск:
  /media/smartbox/sing-box/sing-box.sh restart

Статус и логи:
  /media/smartbox/sing-box/sing-box.sh status
  tail -f /var/log/sing-box.log


3. АВТОЗАПУСК ПРИ ВКЛЮЧЕНИИ РОУТЕРА:
-------------------------------------
В веб-интерфейсе роутера:
  «Персонализация» -> «Скрипты» -> «Выполнить после полного запуска маршрутизатора»:

Добавьте строку:
  /media/smartbox/sing-box/sing-box.sh start &

Нажмите «Применить» внизу страницы.
=======================================================
