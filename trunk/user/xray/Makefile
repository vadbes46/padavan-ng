THISDIR = $(shell pwd)
XRAY_VER = v26.11.9
XRAY_BIN = $(THISDIR)/xray
VER_FILE = $(THISDIR)/.xray_version

all: build_or_fetch

build_or_fetch:
	@if [ ! -f $(XRAY_BIN) ] || [ "$$(cat $(VER_FILE) 2>/dev/null)" != "$(XRAY_VER)" ]; then \
		rm -f $(XRAY_BIN); \
		if command -v go >/dev/null 2>&1; then \
			echo "Compiling Xray-core $(XRAY_VER) from source with host Go compiler for mipsle softfloat..."; \
			rm -rf $(THISDIR)/src && \
			mkdir -p $(THISDIR)/src && \
			git clone --depth 1 --branch $(XRAY_VER) https://github.com/XTLS/Xray-core.git $(THISDIR)/src && \
			cd $(THISDIR)/src && \
			GOOS=linux GOARCH=mipsle GOMIPS=softfloat CGO_ENABLED=0 go build -v -ldflags "-s -w -buildid=" -trimpath -o $(XRAY_BIN) ./main && \
			cd $(THISDIR) && \
			rm -rf $(THISDIR)/src && \
			echo "$(XRAY_VER)" > $(VER_FILE) && \
			echo "Xray-core $(XRAY_VER) successfully compiled: $(XRAY_BIN)"; \
		elif command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1; then \
			echo "Host Go compiler not found. Downloading official release Xray-core $(XRAY_VER) for mips32le..."; \
			ZIP_FILE="$(THISDIR)/Xray-linux-mips32le-$(XRAY_VER).zip"; \
			ZIP_URL="https://github.com/XTLS/Xray-core/releases/download/$(XRAY_VER)/Xray-linux-mips32le.zip"; \
			( wget -t3 --timeout=30 --no-check-certificate -O "$$ZIP_FILE" "$$ZIP_URL" || \
			  curl -sL --connect-timeout 30 -o "$$ZIP_FILE" "$$ZIP_URL" ) && \
			unzip -o "$$ZIP_FILE" xray -d $(THISDIR) && \
			rm -f "$$ZIP_FILE" && \
			chmod +x $(XRAY_BIN) && \
			echo "$(XRAY_VER)" > $(VER_FILE) && \
			echo "Xray-core $(XRAY_VER) pre-compiled binary extracted: $(XRAY_BIN)"; \
		else \
			echo "[WARNING] Neither Go nor wget/curl is available to obtain Xray binary. Skipping Xray binary."; \
		fi; \
	fi

clean:
	rm -rf $(XRAY_BIN) $(VER_FILE) $(THISDIR)/src $(THISDIR)/out $(THISDIR)/*.zip

romfs:
	@if [ -n "$(FIRMWARE_MAXSIZE)" ] && [ $(FIRMWARE_MAXSIZE) -ge 60000000 ]; then \
		$(ROMFSINST) -p +x $(XRAY_BIN) /usr/bin/xray ; \
	fi
	$(ROMFSINST) -p +x xray.sh /usr/bin/xray.sh
	mkdir -p $(ROMFSDIR)/etc_ro/xray
	$(ROMFSINST) -d config.json.vless /etc_ro/xray/config.json.vless
	$(ROMFSINST) -d README.txt /etc_ro/xray/README.txt

standalone: all
	@if [ -f $(XRAY_BIN) ]; then \
		rm -rf $(THISDIR)/out && \
		mkdir -p $(THISDIR)/out/xray && \
		cp -f $(XRAY_BIN) $(THISDIR)/out/xray/xray && \
		chmod +x $(THISDIR)/out/xray/xray && \
		cp -f xray.sh $(THISDIR)/out/xray/xray.sh && \
		chmod +x $(THISDIR)/out/xray/xray.sh && \
		cp -f config.json.vless $(THISDIR)/out/xray/config.json && \
		[ -f $(THISDIR)/geoip.dat ] && cp -f $(THISDIR)/geoip.dat $(THISDIR)/out/xray/ || true && \
		[ -f $(THISDIR)/geosite.dat ] && cp -f $(THISDIR)/geosite.dat $(THISDIR)/out/xray/ || true && \
		cp -f README.txt $(THISDIR)/out/xray/README.txt && \
		tar -czf $(THISDIR)/out/xray-usb.tar.gz -C $(THISDIR)/out xray && \
		echo "Standalone Xray package ready in $(THISDIR)/out/xray-usb.tar.gz" ; \
	else \
		echo "[NOTICE] Xray binary not available. Standalone package skipped." ; \
	fi
