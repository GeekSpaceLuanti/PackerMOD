#!/usr/bin/env python3
# SPDX-License-Identifier: LGPL-2.1-or-later
"""Copy the shared PMUI runtime and its game textures into PackerMOD Base."""

import argparse
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="check without writing")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    source = root / "mainmenu/lib/pmui/modern"
    mod = root / "games/packerbase/mods/packer_ui"
    paths = [
        (source / filename, mod / "lib/pmui" / filename)
        for filename in ("init.lua", "html.lua", "style.lua", "layout.lua", "components.lua", "theme.lua")
    ]
    paths += [
        (path, mod / "textures" / path.name)
        for path in sorted((source / "textures").glob("pmui_*.png"))
        if not any(ch.isupper() for ch in path.stem)
    ]

    for original, target in paths:
        if target.exists() and target.read_bytes() == original.read_bytes():
            continue
        if args.check:
            parser.exit(1, f"Out of date: {target.relative_to(root)}. Run scripts/sync_packer_ui.py.\n")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)


if __name__ == "__main__":
    main()
