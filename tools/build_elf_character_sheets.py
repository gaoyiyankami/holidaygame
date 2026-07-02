from __future__ import annotations

from math import cos, pi, sin
from pathlib import Path

from PIL import Image, ImageDraw


FRAME_SIZE = (192, 144)
FRAMES = 16
ROWS = 9

LAYER_NAMES = [
    "body_head",
    "left_arm",
    "right_arm",
    "left_leg",
    "right_leg",
]

PALETTE = {
    "outline": (20, 17, 24, 255),
    "outline_soft": (44, 37, 50, 255),
    "skin": (128, 91, 145, 255),
    "skin_shadow": (82, 58, 104, 255),
    "blush": (176, 112, 166, 255),
    "hair": (229, 228, 232, 255),
    "hair_light": (255, 252, 246, 255),
    "hair_shadow": (134, 139, 158, 255),
    "ear": (142, 95, 158, 255),
    "dress": (29, 26, 33, 255),
    "dress_mid": (50, 43, 55, 255),
    "dress_light": (96, 80, 110, 255),
    "lace": (188, 172, 196, 255),
    "stocking": (35, 31, 39, 255),
    "boot": (24, 22, 28, 255),
    "metal": (191, 198, 213, 255),
    "metal_dark": (92, 94, 110, 255),
    "gold": (178, 130, 82, 255),
    "red": (112, 42, 94, 255),
    "magic": (180, 82, 238, 230),
    "magic_dark": (86, 38, 124, 210),
}


def rect(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], color: str) -> None:
    x0, y0, x1, y1 = xy
    draw.rectangle((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)), fill=PALETTE[color])


def poly(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str) -> None:
    draw.polygon(points, fill=PALETTE[color])


def line(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    color: str,
    width: int = 1,
) -> None:
    draw.line(points, fill=PALETTE[color], width=width)


def ellipse(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], color: str) -> None:
    draw.ellipse(xy, fill=PALETTE[color])


def draw_sword(draw: ImageDraw.ImageDraw, hand: tuple[int, int], angle: float, length: int = 30) -> None:
    hx, hy = hand
    tip = (round(hx + cos(angle) * length), round(hy + sin(angle) * length))
    guard_a = (round(hx + cos(angle + pi / 2) * 7), round(hy + sin(angle + pi / 2) * 7))
    guard_b = (round(hx + cos(angle - pi / 2) * 7), round(hy + sin(angle - pi / 2) * 7))
    line(draw, [(hx, hy), tip], "outline", 5)
    line(draw, [(hx, hy), tip], "metal", 3)
    line(draw, [(hx + 2, hy - 1), tip], "hair_light", 1)
    line(draw, [guard_a, guard_b], "gold", 4)
    ellipse(draw, (hx - 3, hy - 3, hx + 3, hy + 3), "gold")


def draw_shield(draw: ImageDraw.ImageDraw, center: tuple[int, int], scale: float = 1.0) -> None:
    cx, cy = center
    w = round(18 * scale)
    h = round(24 * scale)
    poly(draw, [(cx - w // 2, cy - h // 2), (cx + w // 2, cy - h // 2 + 3), (cx + w // 3, cy + h // 3), (cx, cy + h // 2), (cx - w // 2, cy + h // 4)], "outline")
    poly(draw, [(cx - w // 2 + 2, cy - h // 2 + 2), (cx + w // 2 - 2, cy - h // 2 + 5), (cx + w // 3 - 2, cy + h // 3 - 1), (cx, cy + h // 2 - 3), (cx - w // 2 + 2, cy + h // 4 - 1)], "dress_mid")
    line(draw, [(cx, cy - h // 2 + 4), (cx, cy + h // 2 - 4)], "lace", 2)


def pose(row: int, frame: int) -> dict[str, object]:
    t = frame / FRAMES
    wave = sin(t * pi * 2.0)
    alt = sin(t * pi * 2.0 + pi)
    p: dict[str, object] = {
        "body": (96, 67 + round(sin(t * pi * 2.0) * 1.2)),
        "lean": 0,
        "left_arm": (-12, -5, 0.70 + wave * 0.08),
        "right_arm": (12, -5, -0.32 - wave * 0.08),
        "left_leg": (-5, 26, -0.10 + wave * 0.14),
        "right_leg": (5, 26, 0.10 + alt * 0.14),
        "sword": -0.18,
        "shield": False,
        "magic": False,
    }
    if row == 1:
        p["body"] = (96 + round(wave * 1.2), 67 + round(abs(wave) * 1.8))
        p["left_arm"] = (-12, -4, -0.38 + alt * 0.34)
        p["right_arm"] = (12, -4, 0.30 + wave * 0.30)
        p["left_leg"] = (-5 + round(wave * 4), 26, -0.32 + wave * 0.48)
        p["right_leg"] = (5 + round(alt * 4), 26, 0.32 + alt * 0.48)
    elif row == 2:
        jump = sin(min(t, 0.94) * pi)
        p["body"] = (96, 67 - round(jump * 9.0) + (2 if frame > 11 else 0))
        p["left_arm"] = (-13, -8, -0.9)
        p["right_arm"] = (13, -8, -0.18)
        p["left_leg"] = (-5, 24, 0.28)
        p["right_leg"] = (6, 23, -0.34)
    elif row == 3:
        p["body"] = (99, 67)
        p["lean"] = 5
        p["left_arm"] = (-13, -2, -0.18)
        p["right_arm"] = (15, -6, -0.06)
        p["left_leg"] = (-6, 26, 0.80)
        p["right_leg"] = (5, 27, 0.58)
        p["sword"] = 0.04
    elif row == 4:
        swing = frame / max(FRAMES - 1, 1)
        anticipation = sin(swing * pi)
        p["body"] = (92 + round(swing * 10), 67 + round(anticipation * 1.5))
        p["lean"] = round(-3 + swing * 8)
        # A wide, readable attack storyboard: left arm opens backward, sword arm
        # pulls high, cuts through center, then follows through low.
        p["left_arm"] = (-13, -7, pi - 0.35 + anticipation * 0.22)
        p["right_arm"] = (13, -8, -1.25 + swing * 2.05)
        p["left_leg"] = (-6, 27, -0.42 + anticipation * 0.16)
        p["right_leg"] = (7, 26, 0.22 + anticipation * 0.20)
        p["sword"] = -1.10 + swing * 1.92
    elif row == 5:
        swing = frame / max(FRAMES - 1, 1)
        crouch = 5 if 4 <= frame <= 9 else 2
        p["body"] = (94 + round(swing * 6), 69 + crouch)
        p["left_arm"] = (-14, -1, pi - 0.06)
        p["right_arm"] = (14, 0, 0.78 - swing * 1.05)
        p["left_leg"] = (-7, 27, -0.62)
        p["right_leg"] = (8, 28, 0.62)
        p["sword"] = 0.42 - swing * 0.78
    elif row == 6:
        brace = 1 if frame < 8 else 0
        p["body"] = (94, 68 + brace)
        p["left_arm"] = (-14, -4, -0.08)
        p["right_arm"] = (12, -2, -0.30)
        p["left_leg"] = (-6, 26, -0.18)
        p["right_leg"] = (7, 26, 0.18)
        p["sword"] = -0.30
        p["shield"] = True
    elif row == 7:
        lift = sin(t * pi)
        p["body"] = (96, 67 - round(lift * 2))
        p["left_arm"] = (-14, -8, pi - 0.05)
        p["right_arm"] = (14, -8, -0.10 - lift * 0.45)
        p["left_leg"] = (-5, 26, -0.10)
        p["right_leg"] = (6, 26, 0.10)
        p["sword"] = -0.1
        p["magic"] = True
    elif row == 8:
        fall = min(frame, 10)
        p["body"] = (96 + fall * 2, 69 + fall * 3)
        p["lean"] = fall * 3
        p["left_arm"] = (-13, 1 + fall, 0.8)
        p["right_arm"] = (13, 1 + fall, 0.2)
        p["left_leg"] = (-6, 27 + fall, 0.4)
        p["right_leg"] = (6, 27 + fall, -0.1)
    return p


def draw_body_head(draw: ImageDraw.ImageDraw, p: dict[str, object]) -> None:
    bx, by = p["body"]  # type: ignore[misc]
    lean = int(p["lean"])
    # Back cape is part of the silhouette only; combat reach is handled by the
    # separate hitbox-bound aura sprite.
    poly(draw, [(bx - 18, by - 22), (bx + 15, by - 21), (bx + 27, by + 43), (bx + 11, by + 54), (bx + 1, by + 35), (bx - 17, by + 52), (bx - 27, by + 37)], "outline")
    poly(draw, [(bx - 15, by - 20), (bx + 13, by - 19), (bx + 23, by + 39), (bx + 10, by + 48), (bx + 1, by + 29), (bx - 15, by + 46), (bx - 23, by + 34)], "dress_mid")
    line(draw, [(bx + 14, by - 15), (bx + 20, by + 34)], "red", 2)
    # Hair: short silver bob with longer back locks, closer to the reference.
    poly(draw, [(bx - 15 - lean, by - 62), (bx + 13 + lean, by - 61), (bx + 21, by - 35), (bx + 15, by - 15), (bx - 4, by - 20), (bx - 21, by - 39)], "outline")
    poly(draw, [(bx - 13 - lean, by - 60), (bx + 11 + lean, by - 59), (bx + 18, by - 35), (bx + 12, by - 17), (bx - 4, by - 22), (bx - 18, by - 38)], "hair_shadow")
    poly(draw, [(bx - 12, by - 63), (bx + 11, by - 61), (bx + 15, by - 38), (bx + 4, by - 24), (bx - 12, by - 30), (bx - 17, by - 44)], "hair")
    line(draw, [(bx - 3, by - 61), (bx - 9, by - 34)], "hair_light", 2)
    line(draw, [(bx + 7, by - 58), (bx + 10, by - 35)], "hair_light", 1)
    # Elf ears.
    poly(draw, [(bx - 10, by - 45), (bx - 23, by - 48), (bx - 11, by - 39)], "outline")
    poly(draw, [(bx + 12, by - 45), (bx + 31, by - 50), (bx + 13, by - 37)], "outline")
    poly(draw, [(bx - 11, by - 44), (bx - 20, by - 47), (bx - 11, by - 40)], "ear")
    poly(draw, [(bx + 13, by - 44), (bx + 27, by - 48), (bx + 13, by - 39)], "ear")
    # Face.
    rect(draw, (bx - 9, by - 56, bx + 12, by - 33), "outline")
    rect(draw, (bx - 7, by - 54, bx + 10, by - 35), "skin")
    rect(draw, (bx - 5, by - 35, bx + 8, by - 29), "skin_shadow")
    rect(draw, (bx + 4, by - 47, bx + 7, by - 44), "outline")
    rect(draw, (bx + 5, by - 40, bx + 8, by - 38), "blush")
    rect(draw, (bx + 1, by - 37, bx + 7, by - 36), "skin_shadow")
    # Bangs and dark collar.
    poly(draw, [(bx - 10, by - 58), (bx - 1, by - 64), (bx + 12, by - 58), (bx + 7, by - 48), (bx + 1, by - 56), (bx - 7, by - 47)], "hair_light")
    rect(draw, (bx - 8, by - 30, bx + 8, by - 25), "dress")
    rect(draw, (bx - 5, by - 28, bx + 5, by - 23), "red")
    # Gothic battle dress armor with a sturdy core silhouette.
    poly(draw, [(bx - 20, by - 27), (bx + 20, by - 27), (bx + 16, by + 17), (bx - 16, by + 17)], "outline")
    poly(draw, [(bx - 17, by - 24), (bx + 17, by - 24), (bx + 13, by + 15), (bx - 13, by + 15)], "dress")
    poly(draw, [(bx - 14, by - 20), (bx, by - 7), (bx + 14, by - 20), (bx + 10, by + 10), (bx - 10, by + 10)], "dress_mid")
    poly(draw, [(bx - 21, by - 25), (bx - 12, by - 31), (bx - 5, by - 24), (bx - 15, by - 19)], "metal_dark")
    poly(draw, [(bx + 21, by - 25), (bx + 12, by - 31), (bx + 5, by - 24), (bx + 15, by - 19)], "metal_dark")
    line(draw, [(bx - 9, by - 20), (bx - 6, by + 12)], "dress_light", 1)
    line(draw, [(bx + 9, by - 20), (bx + 6, by + 12)], "dress_light", 1)
    line(draw, [(bx, by - 21), (bx, by + 13)], "gold", 1)
    rect(draw, (bx - 15, by + 13, bx + 15, by + 18), "lace")
    poly(draw, [(bx - 25, by + 17), (bx + 25, by + 17), (bx + 16, by + 32), (bx - 16, by + 32)], "outline")
    poly(draw, [(bx - 21, by + 18), (bx + 21, by + 18), (bx + 13, by + 29), (bx - 13, by + 29)], "dress_mid")
    line(draw, [(bx - 17, by + 22), (bx + 17, by + 22)], "lace", 1)


def limb_endpoint(root: tuple[int, int], angle: float, length: int) -> tuple[int, int]:
    return (round(root[0] + cos(angle) * length), round(root[1] + sin(angle) * length))


def draw_arm(draw: ImageDraw.ImageDraw, p: dict[str, object], side: str) -> None:
    bx, by = p["body"]  # type: ignore[misc]
    ox, oy, angle = p[f"{side}_arm"]  # type: ignore[misc]
    shoulder = (bx + int(ox), by - 17 + int(oy))
    elbow = limb_endpoint(shoulder, float(angle), 17)
    hand = limb_endpoint(elbow, float(angle) + (0.12 if side == "left" else -0.08), 17)
    line(draw, [shoulder, elbow, hand], "outline", 8)
    line(draw, [shoulder, elbow, hand], "skin", 5)
    rect(draw, (shoulder[0] - 4, shoulder[1] - 4, shoulder[0] + 4, shoulder[1] + 4), "dress_mid")
    rect(draw, (elbow[0] - 3, elbow[1] - 3, elbow[0] + 3, elbow[1] + 3), "lace")
    ellipse(draw, (hand[0] - 3, hand[1] - 3, hand[0] + 3, hand[1] + 3), "skin")
    if side == "left" and bool(p.get("shield", True)):
        draw_shield(draw, (hand[0] - 2, hand[1] + 2), 1.0)
    if side == "right":
        draw_sword(draw, hand, float(p["sword"]))
    if side == "right" and bool(p.get("magic", False)):
        radius = 4 + int(sin((hand[0] + hand[1]) * 0.13) > 0)
        ellipse(draw, (hand[0] + 10 - radius * 2, hand[1] - radius * 2, hand[0] + 10 + radius * 2, hand[1] + radius * 2), "magic_dark")
        ellipse(draw, (hand[0] + 16 - radius, hand[1] - radius, hand[0] + 16 + radius, hand[1] + radius), "magic")


def draw_leg(draw: ImageDraw.ImageDraw, p: dict[str, object], side: str) -> None:
    bx, by = p["body"]  # type: ignore[misc]
    ox, oy, angle = p[f"{side}_leg"]  # type: ignore[misc]
    hip = (bx + int(ox), by + int(oy))
    knee = limb_endpoint(hip, float(angle) + pi / 2, 25)
    foot = limb_endpoint(knee, float(angle) + pi / 2, 27)
    line(draw, [hip, knee, foot], "outline", 10)
    line(draw, [hip, knee, foot], "skin_shadow", 5)
    line(draw, [knee, foot], "stocking", 6)
    foot_dir = 1 if side == "right" else -1
    rect(draw, (foot[0] - 4, foot[1] - 3, foot[0] + 10 * foot_dir, foot[1] + 5), "outline")
    rect(draw, (foot[0] - 2, foot[1] - 2, foot[0] + 8 * foot_dir, foot[1] + 3), "boot")


def build() -> None:
    project = Path(__file__).resolve().parents[1]
    out_dir = project / "assets" / "characters" / "generated" / "elf"
    out_dir.mkdir(parents=True, exist_ok=True)
    sheets = {
        name: Image.new("RGBA", (FRAME_SIZE[0] * FRAMES, FRAME_SIZE[1] * ROWS), (0, 0, 0, 0))
        for name in LAYER_NAMES
    }
    composite = Image.new("RGBA", (FRAME_SIZE[0] * FRAMES, FRAME_SIZE[1] * ROWS), (0, 0, 0, 0))
    for row in range(ROWS):
        for frame in range(FRAMES):
            p = pose(row, frame)
            cell_layers = {name: Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0)) for name in LAYER_NAMES}
            draw_leg(ImageDraw.Draw(cell_layers["left_leg"]), p, "left")
            draw_leg(ImageDraw.Draw(cell_layers["right_leg"]), p, "right")
            draw_body_head(ImageDraw.Draw(cell_layers["body_head"]), p)
            draw_arm(ImageDraw.Draw(cell_layers["left_arm"]), p, "left")
            draw_arm(ImageDraw.Draw(cell_layers["right_arm"]), p, "right")
            x = frame * FRAME_SIZE[0]
            y = row * FRAME_SIZE[1]
            for name in LAYER_NAMES:
                sheets[name].alpha_composite(cell_layers[name], (x, y))
            for name in ["left_leg", "right_leg", "body_head", "left_arm", "right_arm"]:
                composite.alpha_composite(cell_layers[name], (x, y))
    for name, sheet in sheets.items():
        sheet.save(out_dir / f"{name}.png")
    composite.save(out_dir / "hero_actions.png")
    print(out_dir)


if __name__ == "__main__":
    build()
