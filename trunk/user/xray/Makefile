THISDIR = $(shell pwd)
XRAY_BIN = $(THISDIR)/xray

all: build_or_fetch

build_or_fetch:
	@if [ ! -f $(XRAY_BIN) ]; then \
		if command -v go >/dev/null 2>&1; then \
			echo "Compiling Xray-core with host Go compiler for mipsle softfloat..."; \
			mkdir -p $(THISDIR)/src && \
			git clone --depth 1 https://github.com/XTLS/Xray-core.git $(THISDIR)/src && \
			cd $(THISDIR)/src && \
			GOOS=linux GOARCH=mipsle GOMIPS=softfloat CGO_ENABLED=0 go build -v -ldflags "-s -w -buildid=" -trimpath -o $(XRAY_BIN) ./main && \
			rm -rf $(THISDIR)/src && \
			echo "Xray-core successfully compiled: $(XRAY_BIN)"; \
		else \
			echo "ERROR: 'go' not found in PATH! Please install Go 1.27+ to compile Xray-core for MIPS32 softfloat, or place pre-built 'xray' binary into $(THISDIR)/xray"; \
			exit 1; \
		fi \
	fi

clean:
	rm -rf $(XRAY_BIN) $(THISDIR)/src $(THISDIR)/out

romfs:
	$(ROMFSINST) -p +x $(XRAY_BIN) /usr/bin/xray
	$(ROMFSINST) -p +x xray.sh /usr/bin/xray.sh
	mkdir -p $(ROMFSDIR)/etc_ro/xray
	$(ROMFSINST) -d config.json.vless /etc_ro/xray/config.json.vless
	$(ROMFSINST) -d README.txt /etc_ro/xray/README.txt

standalone: all
	rm -rf $(THISDIR)/out
	mkdir -p $(THISDIR)/out/xray
	cp -f $(XRAY_BIN) $(THISDIR)/out/xray/xray
	chmod +x $(THISDIR)/out/xray/xray
	cp -f xray.sh $(THISDIR)/out/xray/xray.sh
	chmod +x $(THISDIR)/out/xray/xray.sh
	cp -f config.json.vless $(THISDIR)/out/xray/config.json
	[ -f $(THISDIR)/geoip.dat ] && cp -f $(THISDIR)/geoip.dat $(THISDIR)/out/xray/ || true
	[ -f $(THISDIR)/geosite.dat ] && cp -f $(THISDIR)/geosite.dat $(THISDIR)/out/xray/ || true
	cp -f README.txt $(THISDIR)/out/xray/README.txt
	tar -czf $(THISDIR)/out/xray-usb.tar.gz -C $(THISDIR)/out xray
	@echo "Standalone Xray package ready in $(THISDIR)/out/xray-usb.tar.gz"
