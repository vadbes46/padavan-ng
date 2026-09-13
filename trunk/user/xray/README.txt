===============================================================================
                     Xray-core for Padavan Router Firmware
===============================================================================

[EN]
This directory integrates Xray-core into the Padavan-ng firmware tree.

FEATURES:
- Native support for VLESS over xHTTP (SplitHTTP), WebSocket, HTTPUpgrade, gRPC
- TLS with uTLS fingerprinting (Firefox / Chrome)
- Inbound proxy services:
  * SOCKS5: port 1080 (TCP + UDP)
  * HTTP:   port 1081 (TCP)
  * Dokodemo-door (Transparent REDIRECT): port 1082 (TCP + UDP)

BUILD OPTIONS:
  To include Xray directly into the firmware image (ROM), enable in your board config:
    CONFIG_FIRMWARE_INCLUDE_XRAY=y
  (Recommended for routers with large Flash / NAND such as 128MB/256MB).

STANDALONE DEPLOYMENT (USB / NAND RWFS / microSD):
  For routers with standard 16MB SPI NOR Flash, keep CONFIG_FIRMWARE_INCLUDE_XRAY=n.
  Run 'make standalone' to build or package xray into 'out/' directory:
    make standalone
  Copy 'out/' files to your USB storage (/media/smartbox/xray/ or /media/AiDisk_a1/xray/)
  or to NAND user partition (/media/mtd_rwfs/xray/).

SERVICE CONTROL:
  /usr/bin/xray.sh start
  /usr/bin/xray.sh stop
  /usr/bin/xray.sh restart
  /usr/bin/xray.sh status

===============================================================================

[RU]
В этой директории находится интеграция Xray-core в дерево прошивки Padavan-ng.

ВОЗМОЖНОСТИ:
- Нативная поддержка протокола VLESS с транспортом xHTTP (SplitHTTP),
  WebSocket, HTTPUpgrade, gRPC
- TLS с маскировкой uTLS fingerprint (Firefox / Chrome)
- Входящие порты:
  * SOCKS5: порт 1080 (TCP + UDP)
  * HTTP:   порт 1081 (TCP)
  * Dokodemo-door (для прозрачного iptables REDIRECT): порт 1082 (TCP + UDP)

ОПЦИИ СБОРКИ:
  Для включения Xray непосредственно в образ прошивки (ROM) включите в конфиге платы:
    CONFIG_FIRMWARE_INCLUDE_XRAY=y
  (Рекомендуется для моделей с NAND/большой Flash 128/256 МБ).

АВТОНОМНАЯ РАБОТА (USB / NAND RWFS / microSD):
  Для роутеров со стандартной 16 МБ SPI NOR Flash оставьте CONFIG_FIRMWARE_INCLUDE_XRAY=n.
  Соберите автономный пакет:
    make standalone
  Скопируйте файлы из каталога 'out/' на флешку (/media/smartbox/xray/) или
  в раздел NAND (/media/mtd_rwfs/xray/).

УПРАВЛЕНИЕ:
  /usr/bin/xray.sh start
  /usr/bin/xray.sh stop
  /usr/bin/xray.sh restart
  /usr/bin/xray.sh status
===============================================================================
