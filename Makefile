.PHONY: test e2e all screenshot screenshot-all measure check-design icons vendor-icons bgimg thumb

ICON_NAMES := play reload download search plus trash save settings-2 folder cloud package box
THEMES ?= synthwave

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

# スクショを取り直して幾何を数値化する (目視レビューの代わりに使う)。
# Usage: make measure SUBTAB=library
measure: screenshot
	python3 scripts/measure_ui.py /tmp/mainmenu_$(SUBTAB).png

# デザイン回帰テスト。指定解像度で撮り、spec/design/<SUBTAB>.json の幾何アサーション
# を評価する (#24 の red→green ゲート)。ISSUES で issue を絞れる (例: ISSUES='["#6"]')。
# Usage: make check-design SUBTAB=library [SCREEN_W=1600 SCREEN_H=900] [FIXTURE=three]
SCREEN_W ?= 1024
SCREEN_H ?= 600
check-design:
	SCREEN_W=$(SCREEN_W) SCREEN_H=$(SCREEN_H) FIXTURE=$(FIXTURE) \
	    bash scripts/screenshot_mainmenu.sh $(SUBTAB) /tmp/mainmenu_$(SUBTAB).png
	python3 scripts/measure_ui.py /tmp/mainmenu_$(SUBTAB).png \
	    --assert spec/design/$(SUBTAB).json

vendor-icons:
	bash scripts/vendor_pixelarticons.sh $(ICON_NAMES)

icons:
	bash scripts/build_icons.sh

bgimg:
	@for t in $(THEMES); do bash scripts/build_bgimg.sh $$t; done

thumb:
	@for t in $(THEMES); do bash scripts/build_thumb.sh $$t; done

all: test e2e
