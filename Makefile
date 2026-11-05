.PHONY: test e2e all screenshot screenshot-all measure check-design icons vendor-icons bgimg thumb gui-test gui-assets

gui-test:
	bash scripts/test_modern_gui.sh

gui-assets:
	python3 scripts/build_modern_gui.py

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
	@set -e; for s in library_empty library library_many library_page2 worlds multi mods info modal_import modal_create modal_create_mods modal_create_game modal_settings settings_keymap settings_keymap_end settings_scale_large settings_resize library_scale_large settings_expert settings_ui_test settings_controls settings_movement settings_actions settings_hotbar settings_graphics settings_audio settings_interface world_settings world_physics world_terrain world_hosting world_settings_test settings_advanced settings_interaction engine_settings_bool engine_settings_enum engine_settings_keys engine_settings_noise engine_settings_noise_end engine_settings_vector engine_settings_flags engine_settings_path engine_settings_test library_en modal_settings_en; do \
	    bash scripts/screenshot_mainmenu.sh $$s; \
	done

# Current clean UI: Lua geometry/overlap checks plus engine screenshot metrics.
# The cyan/composite checks in spec/design/library.json describe the old
# Synthwave theme and are retained as a historical fixture, not the new theme.
SCREEN_W ?= 1024
SCREEN_H ?= 600
PYTHON ?= python3
measure:
	WIN_W=$(SCREEN_W) WIN_H=$(SCREEN_H) \
	    bash scripts/screenshot_mainmenu.sh $(SUBTAB) .screenshots/measure_$(SUBTAB).png
	$(PYTHON) scripts/measure_ui.py .screenshots/measure_$(SUBTAB).png --bg 13171d

check-design: test measure

vendor-icons:
	bash scripts/vendor_pixelarticons.sh $(ICON_NAMES)

icons:
	bash scripts/build_icons.sh

bgimg:
	@for t in $(THEMES); do bash scripts/build_bgimg.sh $$t; done

thumb:
	@for t in $(THEMES); do bash scripts/build_thumb.sh $$t; done

all: test e2e
