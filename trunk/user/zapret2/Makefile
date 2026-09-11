SRC_VER = 1.0.5.1
SRC_NAME = zapret2-v$(SRC_VER)
SRC_ARCHIVE = zapret2-$(SRC_VER).tar.gz
SRC_URL = https://github.com/bol-van/zapret2/releases/download/v$(SRC_VER)/zapret2-v$(SRC_VER).tar.gz

all: download_test extract_test

download_test:
	( if [ ! -f $(SRC_ARCHIVE) ]; then \
		wget -t5 -T20 --no-check-certificate -O $(SRC_ARCHIVE) $(SRC_URL) || rm -f $(SRC_ARCHIVE); \
	fi )

extract_test:
	( if [ ! -d $(SRC_NAME) ]; then \
		tar -zxf $(SRC_ARCHIVE); \
	fi )

clean:
	rm -rf $(SRC_NAME) $(SRC_ARCHIVE)

romfs:
	$(ROMFSINST) -p +x $(SRC_NAME)/binaries/linux-mipsel/nfqws2 /usr/bin/nfqws2
	$(ROMFSINST) -p +x $(SRC_NAME)/binaries/linux-mipsel/mdig /usr/bin/mdig
	$(ROMFSINST) -p +x $(SRC_NAME)/binaries/linux-mipsel/ip2net /usr/bin/ip2net
	$(ROMFSINST) -p +x zapret2.sh /usr/bin/zapret2.sh
	mkdir -p $(ROMFSDIR)/usr/share/zapret2
	$(ROMFSINST) -d $(SRC_NAME)/lua /usr/share/zapret2/lua
	$(ROMFSINST) -d $(SRC_NAME)/files/fake /usr/share/zapret2/fake
	$(ROMFSINST) strategy /usr/share/zapret2/strategy
	$(ROMFSINST) strategy0 /usr/share/zapret2/strategy0
	$(ROMFSINST) strategy1 /usr/share/zapret2/strategy1
	$(ROMFSINST) strategy2 /usr/share/zapret2/strategy2
	$(ROMFSINST) strategy3 /usr/share/zapret2/strategy3
