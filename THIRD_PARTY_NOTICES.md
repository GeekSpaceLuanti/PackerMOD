# Third-party notices

## Pixelarticons

Source: https://github.com/halfmage/pixelarticons

Files: `vendor/pixelarticons/svg/*.svg` and generated
`textures/packermod_icon_*.png`. The PNGs are recolored and rasterized by
`scripts/build_icons.sh`. Preserve this notice when distributing those PNGs,
including a menu-only installation without the vendor directory.

MIT License

Copyright (c) 2019 Gerrit Halfmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Minetest Game / PackerMOD Base

Source: https://github.com/luanti-org/minetest_game

The game in `games/packerbase` is a modified Minetest Game distribution.
Its upstream revision and modifications are recorded inside that directory.
Source code is generally LGPL-2.1-or-later. Media have their own licenses,
including CC BY-SA 3.0, CC BY 3.0 and CC0; the per-mod notices identify the
authors and applicable terms. Preserve **all** upstream notices, not only this
summary. The root PackerMOD license does not replace those notices.

## Luanti engine (runtime dependency)

Source: https://github.com/luanti-org/luanti

Luanti source code is LGPL-2.1-or-later. PackerMOD loads installed Luanti
builtin modules through `core.get_builtin_path()`; this repository does not
bundle an engine executable. An engine-bundled release must retain the engine's
own license files, media notices and dependency licenses, and provide the exact
corresponding source and build scripts for that binary, including modifications.

Official license inventory:
https://github.com/luanti-org/luanti/blob/master/LICENSE.txt

## Downloaded games and mods

ContentDB packages are not relicensed by PackerMOD. Pack authors distributing
bundled mods must include the licenses and attributions of every bundled
package. Merely being downloadable is not a grant of redistribution rights.
