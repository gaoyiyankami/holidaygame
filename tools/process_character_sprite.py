from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image


def is_key_pixel(pixel: tuple[int, int, int, int], key: tuple[int, int, int] | None) -> bool:
    r, g, b, a = pixel
    if a <= 8:
        return True
    if key is not None:
        kr, kg, kb = key
        distance = abs(r - kr) + abs(g - kg) + abs(b - kb)
        if distance < 62:
            return True
    green_screen = g > 105 and g > r * 1.22 and g > b * 1.22
    bright_green = g > 150 and g > max(r, b) * 1.08
    return green_screen or bright_green


def border_key_color(image: Image.Image) -> tuple[int, int, int] | None:
    samples: list[tuple[int, int, int]] = []
    width, height = image.size
    pixels = image.load()
    for x in range(width):
        for y in (0, height - 1):
            r, g, b, a = pixels[x, y]
            if a > 0:
                samples.append((r, g, b))
    for y in range(height):
        for x in (0, width - 1):
            r, g, b, a = pixels[x, y]
            if a > 0:
                samples.append((r, g, b))
    if not samples:
        return None
    # Quantize lightly so compression/noise on chroma backgrounds still groups.
    buckets: dict[tuple[int, int, int], int] = {}
    for r, g, b in samples:
        key = (round(r / 8) * 8, round(g / 8) * 8, round(b / 8) * 8)
        buckets[key] = buckets.get(key, 0) + 1
    return max(buckets, key=buckets.get)


def remove_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    key = border_key_color(rgba)
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if is_key_pixel((r, g, b, a), key):
                pixels[x, y] = (r, g, b, 0)
            elif g > max(r, b) * 1.03:
                # Despill green fringes from chroma removal.
                pixels[x, y] = (r, max(r, b), b, a)
    return keep_large_components(rgba)


def keep_large_components(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    alpha_pixels = alpha.load()
    pixels = image.load()
    width, height = image.size
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if alpha_pixels[x, y] == 0 or (x, y) in visited:
                continue
            pending: deque[tuple[int, int]] = deque([(x, y)])
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            while pending:
                cx, cy = pending.pop()
                points.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if alpha_pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    pending.append((nx, ny))
            components.append(points)
    if not components:
        return image
    components.sort(key=len, reverse=True)
    keep_threshold = max(24, int(len(components[0]) * 0.015))
    keep = {point for component in components if len(component) >= keep_threshold for point in component}
    for y in range(height):
        for x in range(width):
            if alpha_pixels[x, y] > 0 and (x, y) not in keep:
                pixels[x, y] = (*pixels[x, y][:3], 0)
    return image


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getbbox()
    if bbox is None:
        raise ValueError("No visible pixels after background removal")
    return bbox


def center_of_alpha(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    total = 0
    weighted = 0
    for y in range(image.height):
        for x in range(image.width):
            a = alpha.getpixel((x, y))
            if a:
                total += a
                weighted += x * a
    return image.width * 0.5 if total == 0 else weighted / total


def process(
    input_path: Path,
    output_path: Path,
    metadata_path: Path,
    sprite_width: int,
    sprite_height: int,
    hitbox_width: int,
    hitbox_height: int,
    foot_padding: int,
) -> None:
    source = remove_background(Image.open(input_path))
    left, top, right, bottom = alpha_bbox(source)
    subject = source.crop((left, top, right, bottom))
    foot_y_in_subject = subject.height - 1

    # Keep the character inside the render canvas while preserving feet as the
    # anchor.  A little horizontal overflow is allowed for sword/cape, but the
    # body remains centered over the existing hitbox.
    max_visible_width = sprite_width - 4
    max_visible_height = sprite_height - foot_padding - 2
    scale = min(max_visible_width / max(subject.width, 1), max_visible_height / max(subject.height, 1))
    scaled_size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(scaled_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (sprite_width, sprite_height), (0, 0, 0, 0))
    pivot_x = sprite_width // 2
    foot_y = sprite_height - foot_padding
    body_center_x = center_of_alpha(subject)
    paste_x = round(pivot_x - body_center_x)
    paste_x = max(2 - subject.width, min(sprite_width - 2, paste_x))
    paste_y = foot_y - round(foot_y_in_subject * scale)
    canvas.alpha_composite(subject, (paste_x, paste_y))

    hitbox_x = round(pivot_x - hitbox_width * 0.5)
    hitbox_y = round(foot_y - hitbox_height)
    metadata = {
        "spriteWidth": sprite_width,
        "spriteHeight": sprite_height,
        "pivotX": pivot_x,
        "pivotY": foot_y,
        "footY": foot_y,
        "hitboxX": hitbox_x,
        "hitboxY": hitbox_y,
        "hitboxWidth": hitbox_width,
        "hitboxHeight": hitbox_height,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path)
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    print(output_path)
    print(metadata_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert raw character art into an anchored game sprite.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--width", type=int, default=128)
    parser.add_argument("--height", type=int, default=160)
    parser.add_argument("--hitbox-width", type=int, default=34)
    parser.add_argument("--hitbox-height", type=int, default=78)
    parser.add_argument("--foot-padding", type=int, default=10)
    args = parser.parse_args()
    process(
        args.input,
        args.out,
        args.metadata,
        args.width,
        args.height,
        args.hitbox_width,
        args.hitbox_height,
        args.foot_padding,
    )


if __name__ == "__main__":
    main()
