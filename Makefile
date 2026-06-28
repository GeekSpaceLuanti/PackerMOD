.PHONY: test e2e all screenshot

test:
	busted spec/

e2e:
	bash spec/e2e/run.sh

# Capture a Luanti main menu tab to /tmp/mainmenu_<tab>.png under Xvfb.
# Usage: make screenshot TAB=create
TAB ?= create
screenshot:
	bash scripts/screenshot_mainmenu.sh $(TAB)

all: test e2e
