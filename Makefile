PLUGIN_NAME := org.kde.ktaskwidget
PACKAGE_DIR := package/$(PLUGIN_NAME)
ARCHIVE     := ktaskwidget.plasmoid

# Force the real per-user data dir. Without this, running `make` from a
# snap-confined terminal (e.g. VS Code's snap) installs into
# ~/snap/<app>/<rev>/.local/share/, where plasmashell never looks.
export XDG_DATA_HOME := $(HOME)/.local/share

.PHONY: help package install upgrade remove reinstall dev clean

help:
	@echo "Targets:"
	@echo "  make package    Build $(ARCHIVE) for 'Install from local file'"
	@echo "  make install    Install via kpackagetool5"
	@echo "  make upgrade    Upgrade an already-installed copy"
	@echo "  make remove     Uninstall"
	@echo "  make reinstall  Remove + install"
	@echo "  make dev        Run in plasmoidviewer for development"
	@echo "  make clean      Delete build artifacts"

package: $(ARCHIVE)

$(ARCHIVE): $(shell find $(PACKAGE_DIR) -type f 2>/dev/null)
	@rm -f $(ARCHIVE)
	cd $(PACKAGE_DIR) && zip -r ../../$(ARCHIVE) . -x "*.bak" "*~"

install:
	@if kpackagetool5 -t Plasma/Applet --list 2>/dev/null | grep -qx $(PLUGIN_NAME); then \
		echo "Already installed — upgrading."; \
		kpackagetool5 -t Plasma/Applet -u $(PACKAGE_DIR); \
	else \
		kpackagetool5 -t Plasma/Applet -i $(PACKAGE_DIR); \
	fi

upgrade:
	kpackagetool5 -t Plasma/Applet -u $(PACKAGE_DIR)

remove:
	-kpackagetool5 -t Plasma/Applet -r $(PLUGIN_NAME)

reinstall: remove install

dev:
	plasmoidviewer -a $(PACKAGE_DIR)

clean:
	rm -f $(ARCHIVE)
