#!/usr/bin/env python3
# SPDX-License-Identifier: LGPL-2.1-or-later
"""Measure the bright selection frame in actual Luanti HUD screenshots."""
import sys
from subprocess import check_output


def read_pixels(prefix, suffix):
    path = f"{prefix}-{suffix}.png"
    width, height = map(int, check_output(["identify", "-ping", "-format", "%w %h", path]).split())
    data = check_output(["convert", path, "-alpha", "off", "-depth", "8", "rgb:-"])
    return width, height, data


def color_bounds(width, height, data, match):
    points = []
    for y in range(max(0, height - 260), height):
        for x in range(width // 5, width * 4 // 5):
            index = (y * width + x) * 3
            if match(*data[index:index + 3]):
                points.append((x, y))
    if not points:
        return None
    left, top = min(x for x, _ in points), min(y for _, y in points)
    right, bottom = max(x for x, _ in points), max(y for _, y in points)
    return left, top, right, bottom


def selected(r, g, b):
    return (r, g, b) == (250, 253, 255)


prefix, view = sys.argv[1:]
centers = []
tops = []
for slot in (1, 5, 9):
    width, height, pixels = read_pixels(prefix, slot)
    bounds = color_bounds(width, height, pixels, selected)
    assert bounds, f"No bright selection frame at slot {slot}"
    left, top, right, bottom = bounds
    assert abs((right - left) - (bottom - top)) <= 3, bounds
    assert height - bottom >= 17, f"Slot {slot} selection clips bottom margin"
    centers.append(((left + right) / 2, (top + bottom) / 2, right - left))
    tops.append(top)
    print(f"slot {slot}: frame {bounds}, bottom margin {height - 1 - bottom}px")

(x1, y1, w1), (x5, y5, w5), (x9, y9, w9) = centers
assert max(w1, w5, w9) - min(w1, w5, w9) <= 2
if view == "wrapped":
    assert y1 < y5 - 25 and y5 == y9, centers
    assert abs((x5 + x9) / 2 - width / 2) <= 2, centers
    assert abs((x9 - x5) / 4 - (x5 - x1) * -2) <= 3, centers
else:
    assert y1 == y5 == y9 and abs(x5 - width / 2) <= 2, centers
    assert abs((x5 - x1) - (x9 - x5)) <= 2, centers
health = color_bounds(width, height, pixels, lambda r, g, b: r >= 145 and r > 1.5 * max(g, b))
breath = color_bounds(width, height, pixels, lambda r, g, b: b >= 185 and b > r + 25 and g >= 100)
assert health and breath, "Expected visible health and breath bars"
assert health[2] < breath[0], (health, breath)
gap = min(tops) - max(health[3], breath[3])
assert 4 <= gap <= 40, f"Unexpected status-to-hotbar gap: {gap}px"
print(f"Health and breath clear the hotbar by {gap}px")
assert color_bounds(*read_pixels(prefix, "hidden"), selected) is None, "F1 did not hide the selection frame"
