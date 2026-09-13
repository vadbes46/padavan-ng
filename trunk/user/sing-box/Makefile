SRC_VER = 1.14.0
SRC_NAME = sing-box-$(SRC_VER)-linux-mipsle-softfloat
SRC_ARCHIVE = $(SRC_NAME).tar.gz
SRC_URL = https://github.com/SagerNet/sing-box/releases/download/v$(SRC_VER)/$(SRC_ARCHIVE)

THISDIR = $(shell pwd)

all: download_test extract_test

download_test:
	( if [ ! -f $(SRC_ARCHIVE) ]; then \
		wget -t5 --timeout=30 --no-check-certificate -O $(SRC_ARCHIVE) $(SRC_URL) || \
		curl -sL --connect-timeout 30 -o $(SRC_ARCHIVE) $(SRC_URL) || rm -f $(SRC_ARCHIVE); \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar -zxf $(SRC_ARCHIVE); \
	fi )

clean:
	rm -rf $(SRC_NAME) $(SRC_ARCHIVE) out

romfs:
	@if [ -n "$(FIRMWARE_MAXSIZE)" ] && [ $(FIRMWARE_MAXSIZE) -ge 60000000 ]; then \
		$(ROMFSINST) -p +x $(SRC_NAME)/sing-box /usr/bin/sing-box ; \
	fi
	$(ROMFSINST) -p +x sing-box.sh /usr/bin/sing-box.sh
	mkdir -p $(ROMFSDIR)/etc_ro/sing-box
	$(ROMFSINST) -d config.json.vless /etc_ro/sing-box/config.json.vless
	$(ROMFSINST) -d config.json.hysteria2 /etc_ro/sing-box/config.json.hysteria2
	$(ROMFSINST) -d README.txt /etc_ro/sing-box/README.txt

standalone: all
	rm -rf $(THISDIR)/out
	mkdir -p $(THISDIR)/out/sing-box
	cp -f $(SRC_NAME)/sing-box $(THISDIR)/out/sing-box/sing-box
	chmod +x $(THISDIR)/out/sing-box/sing-box
	cp -f sing-box.sh $(THISDIR)/out/sing-box/sing-box.sh
	chmod +x $(THISDIR)/out/sing-box/sing-box.sh
	cp -f config.json.vless $(THISDIR)/out/sing-box/config_vless.json
	cp -f config.json.hysteria2 $(THISDIR)/out/sing-box/config_hy2.json
	cp -f README.txt $(THISDIR)/out/sing-box/README.txt
	tar -czf $(THISDIR)/out/sing-box-usb.tar.gz -C $(THISDIR)/out sing-box
	@echo "Standalone sing-box package ready in $(THISDIR)/out/sing-box-usb.tar.gz"
