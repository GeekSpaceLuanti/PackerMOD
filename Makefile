.PHONY: test e2e all screenshot screenshot-all icons vendor-icons

ICON_NAMES := play reload download search plus trash save settings-2 folder cloud package box

test:
	busted spec/

e2e:
	bash spec/e2e/run.sh

# Capture a Library subtab to /tmp/mainmenu_<subtab>.png under Xvfb.
# Phase 8+: メインメニューは 1 画面化されたので引数は subtab を指す。
# Usage: make screenshot SUBTAB=worlds
SUBTAB ?= library
screenshot:
	bash scripts/screenshot_mainmenu.sh $(SUBTAB)

screenshot-all:
	@for s in library worlds multi mods info modal_import modal_create modal_settings; do \
	    bash scripts/screenshot_mainmenu.sh $$s /tmp/mainmenu_$$s.png; \
	done

vendor-icons:
	bash scripts/vendor_pixelarticons.sh $(ICON_NAMES)

icons:
	bash scripts/build_icons.sh

all: test e2e
