PREFIX ?= /usr/local
VERSION ?= $(shell tr -d '[:space:]' < VERSION)

.PHONY: help detect build run install-deb clean

help:
	@echo "Grok Bot Linux port"
	@echo
	@echo "  make detect       Print the newest official Windows version on the CDN"
	@echo "  make build        Rebuild that version for Linux (tarball, .deb, AppImage)"
	@echo "  make run          Launch the staged app from dist/"
	@echo "  make install-deb  Build if needed and install the Ubuntu/Debian package"
	@echo "  make clean        Remove dist/ (keeps .cache/ downloads)"

detect:
	@./scripts/detect-version.sh

build:
	./scripts/build.sh $(VERSION)

run:
	@app="dist/Grok_Bot_$(VERSION)_linux_x64/grok-bot"; \
	if [ ! -x "$$app" ]; then $(MAKE) build; fi; \
	"$$app" --no-sandbox --ozone-platform-hint=auto --class=grok-bot

install-deb:
	./scripts/install-ubuntu.sh $(VERSION)

clean:
	rm -rf dist
