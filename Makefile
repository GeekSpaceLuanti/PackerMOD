.PHONY: test e2e all screenshot screenshot-all icons vendor-icons

ICON_NAMES := play reload download search plus trash save settings-2 folder cloud package box

test:
	busted spec/

e2e:
	bash spec/e2e/run.sh

# Capture a Luanti main menu tab to /tmp/mainmenu_<tab>.png under Xvfb.
# Usage: make screenshot TAB=create
TAB ?= create
screenshot:
	bash scripts/screenshot_mainmenu.sh $(TAB)

screenshot-all:
	@for t in packs import create settings; do \
	    bash scripts/screenshot_mainmenu.sh $$t /tmp/mainmenu_$$t.png; \
	done

vendor-icons:
	bash scripts/vendor_pixelarticons.sh $(ICON_NAMES)

icons:
	bash scripts/build_icons.sh

all: test e2e
