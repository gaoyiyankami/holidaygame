from pathlib import Path
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "maps" / "generated"
OUT.mkdir(parents=True, exist_ok=True)


def clamp(value: int) -> int:
    return max(0, min(255, value))


def shade(color: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    return (
        clamp(color[0] + amount),
        clamp(color[1] + amount),
        clamp(color[2] + amount),
        color[3],
    )


def save_platform(index: int, base: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    image = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 5, 127, 31), fill=shade(base, -18), outline=shade(base, -55))
    draw.rectangle((0, 0, 127, 10), fill=shade(base, 22))
    draw.line((0, 11, 127, 11), fill=shade(base, -35))

    if index == 0:
        for x in range(0, 128, 21):
            draw.line((x, 11, x + 9, 31), fill=shade(base, -45))
        for x in range(4, 128, 28):
            draw.rectangle((x, 4, x + 18, 8), fill=accent)
    elif index == 1:
        for x in range(0, 128, 16):
            draw.rectangle((x, 4, x + 11, 8), fill=accent)
            draw.line((x + 2, 18, x + 14, 22), fill=shade(accent, -25))
    elif index == 2:
        for y in range(8, 32, 8):
            draw.line((0, y, 127, y), fill=shade(base, -35))
        for x in range(0, 128, 32):
            draw.line((x, 8, x, 31), fill=shade(base, -42))
    elif index == 3:
        for x in range(5, 128, 24):
            draw.polygon([(x, 5), (x + 8, 2), (x + 16, 6), (x + 11, 13)], fill=accent)
        draw.line((4, 24, 123, 18), fill=shade(accent, -18))
    else:
        for x in range(0, 128, 18):
            draw.line((x, 2, x + 20, 30), fill=shade(base, 32))
        for x in range(10, 128, 31):
            draw.ellipse((x, 14, x + 7, 21), fill=accent)

    image.save(OUT / f"platform_{index}.png")


def save_wall(index: int, base: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    image = Image.new("RGBA", (64, 64), shade(base, -12))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 63, 63), outline=shade(base, -28))

    if index == 0:
        for y in range(0, 64, 16):
            draw.line((0, y, 63, y), fill=shade(base, -35))
            offset = 0 if (y // 16) % 2 == 0 else 16
            for x in range(-offset, 64, 32):
                draw.line((x, y, x, y + 16), fill=shade(base, -42))
        for x in range(6, 64, 22):
            draw.rectangle((x, 7, x + 8, 56), fill=accent)
    elif index == 1:
        for x in range(8, 64, 18):
            draw.line((x, 0, x - 8, 63), fill=shade(base, 28), width=2)
        for y in range(8, 64, 16):
            draw.rectangle((4, y, 60, y + 4), fill=accent)
    else:
        for y in range(0, 64, 12):
            draw.line((0, y, 63, y + 6), fill=shade(base, -30))
        for x in range(5, 64, 20):
            draw.polygon([(x, 16), (x + 7, 8), (x + 15, 18), (x + 8, 32)], fill=accent)
            draw.polygon([(x + 4, 42), (x + 12, 32), (x + 20, 46), (x + 11, 58)], fill=accent)

    image.save(OUT / f"wall_{index}.png")


def save_background(index: int, base: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    image = Image.new("RGBA", (128, 128), base)
    draw = ImageDraw.Draw(image)
    for y in range(0, 128, 32):
        draw.line((0, y, 127, y), fill=shade(base, 18))
    for x in range(0, 128, 32):
        draw.line((x, 0, x, 127), fill=shade(base, -16))

    if index == 0:
        for x in range(14, 128, 38):
            draw.rectangle((x, 12, x + 13, 116), fill=accent)
    elif index == 1:
        for x in range(8, 128, 28):
            draw.arc((x, 28, x + 32, 92), 200, 340, fill=accent, width=2)
    else:
        for x in range(12, 128, 34):
            draw.polygon([(x, 16), (x + 9, 8), (x + 18, 16), (x + 9, 32)], fill=accent)
            draw.polygon([(x + 18, 82), (x + 28, 69), (x + 39, 83), (x + 29, 104)], fill=accent)

    image.save(OUT / f"background_{index}.png")


def save_marker() -> None:
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((6, 4, 26, 24), fill=(255, 92, 70, 230), outline=(255, 235, 130, 255), width=2)
    draw.polygon([(16, 29), (10, 21), (22, 21)], fill=(255, 92, 70, 230))
    draw.rectangle((14, 10, 18, 18), fill=(255, 245, 150, 255))
    draw.rectangle((10, 14, 22, 18), fill=(255, 245, 150, 255))
    image.save(OUT / "enemy_spawn_marker.png")


def main() -> None:
    platforms = [
        ((78, 94, 112, 255), (120, 160, 120, 255)),
        ((112, 72, 44, 255), (176, 124, 70, 255)),
        ((92, 64, 82, 255), (150, 96, 122, 255)),
        ((48, 102, 118, 255), (90, 196, 220, 255)),
        ((104, 92, 52, 255), (210, 174, 76, 255)),
    ]
    walls = [
        ((64, 73, 92, 255), (92, 112, 130, 255)),
        ((72, 48, 68, 255), (122, 80, 112, 255)),
        ((44, 86, 88, 255), (80, 164, 160, 255)),
    ]
    backgrounds = [
        ((24, 35, 55, 255), (46, 58, 86, 255)),
        ((43, 22, 40, 255), (70, 42, 68, 255)),
        ((22, 48, 54, 255), (42, 84, 90, 255)),
    ]

    for index, colors in enumerate(platforms):
        save_platform(index, *colors)
    for index, colors in enumerate(walls):
        save_wall(index, *colors)
    for index, colors in enumerate(backgrounds):
        save_background(index, *colors)
    save_marker()
    print(f"Generated map tiles in {OUT}")


if __name__ == "__main__":
    main()
