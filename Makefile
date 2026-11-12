PLUGIN_NAME := org.kde.ktaskwidget
PACKAGE_DIR := package/$(PLUGIN_NAME)
ARCHIVE     := ktaskwidget.plasmoid
KPACKAGE    := kpackagetool6 --type Plasma/Applet

# Force the real per-user data dir. Without this, running `make` from a
# snap-confined terminal (e.g. VS Code's snap) installs into
# ~/snap/<app>/<rev>/.local/share/, where plasmashell never looks.
export XDG_DATA_HOME := $(HOME)/.local/share

.PHONY: help package install upgrade remove reinstall restart dev logs check clean

help:
	@echo "Targets (Plasma 6 / Kubuntu 26.04):"
	@echo "  make package    Build $(ARCHIVE) for 'Install from local file'"
	@echo "  make install    Install (or upgrade if already installed) via kpackagetool6"
	@echo "  make upgrade    Upgrade an already-installed copy"
	@echo "  make remove     Uninstall"
	@echo "  make reinstall  Remove + install"
	@echo "  make restart    Restart plasmashell to load new QML"
	@echo "  make dev        Run in plasmoidviewer (needs plasma-sdk)"
	@echo "  make logs       Follow plasmashell logs filtered on the widget"
	@echo "  make check      Sanity-check the package layout"
	@echo "  make clean      Delete build artifacts"

package: $(ARCHIVE)

$(ARCHIVE): $(shell find $(PACKAGE_DIR) -type f 2>/dev/null)
	@rm -f $(ARCHIVE)
	cd $(PACKAGE_DIR) && zip -r ../../$(ARCHIVE) . -x "*.bak" "*~"

INSTALL_DIR := $(XDG_DATA_HOME)/plasma/plasmoids/$(PLUGIN_NAME)

install:
	@if $(KPACKAGE) --list 2>/dev/null | grep -qx $(PLUGIN_NAME); then \
		echo "Already installed — upgrading."; \
		$(KPACKAGE) --upgrade $(PACKAGE_DIR); \
	else \
		if [ -f "$(INSTALL_DIR)/metadata.desktop" ] && [ ! -f "$(INSTALL_DIR)/metadata.json" ]; then \
			echo "Removing legacy Plasma 5 copy in $(INSTALL_DIR) (tasks are kept, they live in plasma-org.kde.plasma.desktop-appletsrc)."; \
			rm -rf "$(INSTALL_DIR)"; \
		fi; \
		$(KPACKAGE) --install $(PACKAGE_DIR); \
	fi

upgrade:
	$(KPACKAGE) --upgrade $(PACKAGE_DIR)

remove:
	-$(KPACKAGE) --remove $(PLUGIN_NAME)

reinstall: remove install

restart:
	systemctl --user restart plasma-plasmashell.service

dev:
	plasmoidviewer --applet $(PACKAGE_DIR)

logs:
	journalctl --user -f -o cat | grep --line-buffered -i ktaskwidget

check:
	@test -f $(PACKAGE_DIR)/metadata.json || { echo "metadata.json missing"; exit 1; }
	@python3 -m json.tool $(PACKAGE_DIR)/metadata.json > /dev/null && echo "metadata.json: valid JSON"
	@test -f $(PACKAGE_DIR)/contents/ui/main.qml && echo "contents/ui/main.qml: present"
	@test -f $(PACKAGE_DIR)/contents/config/main.xml && echo "contents/config/main.xml: present"

clean:
	rm -f $(ARCHIVE)
