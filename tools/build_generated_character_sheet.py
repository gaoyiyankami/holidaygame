from __future__ import annotations

from math import cos, radians, sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


FRAME_SIZE = (192, 144)
GRID_SIZE = (6, 2)
TARGET_HEIGHT = 88
BOTTOM_MARGIN = 10
SIDE_MARGIN = 8
SHEET_COLUMNS = 6

AURA_FRAME_SIZE = (144, 96)
AURA_ROWS = 4
AURA_COLUMNS = 3


def is_magic_pixel(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a > 0 and b > 135 and g > 115 and r < 115 and b > r * 1.55


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            green = g > 95 and g > r * 1.18 and g > b * 1.18
            near_green = g > 150 and g > max(r, b) * 1.08
            if green or near_green:
                pixels[x, y] = (r, g, b, 0)
            elif g > max(r, b) * 1.03:
                pixels[x, y] = (r, max(r, b), b, a)
    return rgba


def trim_alpha_noise(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < 18 else 255)
    output = image.copy()
    output.putalpha(alpha)
    return output


def normalize_frame(cell: Image.Image, scale: float) -> Image.Image:
    cell = trim_alpha_noise(cell)
    bbox = cell.getbbox()
    output = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    if bbox is None:
        return output
    subject = cell.crop(bbox)
    subject_width, subject_height = subject.size
    target_scale = scale
    max_width = FRAME_SIZE[0] - SIDE_MARGIN * 2
    if subject_width * target_scale > max_width:
        target_scale = max_width / max(subject_width, 1)
    target_scale = min(target_scale, (FRAME_SIZE[1] - 14) / max(subject_height, 1))
    size = (
        max(1, round(subject_width * target_scale)),
        max(1, round(subject_height * target_scale)),
    )
    subject = subject.resize(size, Image.Resampling.NEAREST)
    x = (FRAME_SIZE[0] - subject.width) // 2
    y = FRAME_SIZE[1] - BOTTOM_MARGIN - subject.height
    output.alpha_composite(subject, (x, y))
    return output


def extract_rows(path: Path) -> list[list[Image.Image]]:
    source = remove_green(Image.open(path))
    cell_width = source.width // GRID_SIZE[0]
    cell_height = source.height // GRID_SIZE[1]
    cells: list[list[Image.Image]] = []
    heights: list[int] = []
    for row in range(GRID_SIZE[1]):
        row_cells: list[Image.Image] = []
        for column in range(GRID_SIZE[0]):
            left = column * cell_width
            top = row * cell_height
            right = source.width if column == GRID_SIZE[0] - 1 else left + cell_width
            bottom = source.height if row == GRID_SIZE[1] - 1 else top + cell_height
            cell = source.crop((left, top, right, bottom))
            row_cells.append(cell)
            bbox = trim_alpha_noise(cell).getbbox()
            if bbox is not None:
                heights.append(bbox[3] - bbox[1])
        cells.append(row_cells)
    heights.sort()
    reference_height = heights[len(heights) // 2] if heights else TARGET_HEIGHT
    scale = TARGET_HEIGHT / max(reference_height, 1)
    return [[normalize_frame(cell, scale) for cell in row] for row in cells]


def remove_alpha_islands(
    frame: Image.Image,
    *,
    max_area: int,
    edge_margin: int = -1,
    require_magic: bool = False,
) -> None:
    alpha = frame.getchannel("A")
    alpha_pixels = alpha.load()
    pixels = frame.load()
    width, height = frame.size
    visited: set[tuple[int, int]] = set()
    for y in range(height):
        for x in range(width):
            if alpha_pixels[x, y] == 0 or (x, y) in visited:
                continue
            pending = [(x, y)]
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            magic_pixels = 0
            min_x = max_x = x
            min_y = max_y = y
            while pending:
                cx, cy = pending.pop()
                points.append((cx, cy))
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                if is_magic_pixel(pixels[cx, cy]):
                    magic_pixels += 1
                for nx, ny in (
                    (cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1),
                ):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if alpha_pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    pending.append((nx, ny))
            area = len(points)
            near_edge = edge_margin >= 0 and (
                min_x <= edge_margin
                or min_y <= edge_margin
                or max_x >= width - edge_margin - 1
                or max_y >= height - edge_margin - 1
            )
            should_remove = area <= max_area and (edge_margin < 0 or near_edge)
            if require_magic:
                should_remove = should_remove and magic_pixels > 0
            if should_remove:
                for px, py in points:
                    pixels[px, py] = (*pixels[px, py][:3], 0)


def erase_magic_colors(frame: Image.Image) -> None:
    pixels = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if is_magic_pixel(pixels[x, y]):
                pixels[x, y] = (*pixels[x, y][:3], 0)


def remove_detached_components(frame: Image.Image, keep_count: int = 1) -> None:
    alpha = frame.getchannel("A")
    alpha_pixels = alpha.load()
    pixels = frame.load()
    width, height = frame.size
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if alpha_pixels[x, y] == 0 or (x, y) in visited:
                continue
            pending = [(x, y)]
            visited.add((x, y))
            points: list[tuple[int, int]] = []
            while pending:
                cx, cy = pending.pop()
                points.append((cx, cy))
                for nx, ny in (
                    (cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1),
                ):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    if alpha_pixels[nx, ny] == 0 or (nx, ny) in visited:
                        continue
                    visited.add((nx, ny))
                    pending.append((nx, ny))
            components.append(points)
    components.sort(key=len, reverse=True)
    for component in components[keep_count:]:
        for px, py in component:
            pixels[px, py] = (*pixels[px, py][:3], 0)


def shifted_frame(frame: Image.Image, offset: tuple[int, int]) -> Image.Image:
    output = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    output.alpha_composite(frame, offset)
    return output


def rebuild_walk_cycle(rows: list[list[Image.Image]]) -> None:
    if len(rows) < 2 or len(rows[1]) < 6:
        return
    source = [frame.copy() for frame in rows[1][:6]]
    # Use every source frame instead of duplicating a few poses.  The tiny
    # offsets give a readable weight shift without making the body slide.
    offsets = [(-2, 0), (-1, -1), (0, 0), (1, -1), (2, 0), (1, 1)]
    rows[1] = [shifted_frame(source[index], offsets[index]) for index in range(6)]


def rebuild_attack_motion(rows: list[list[Image.Image]]) -> None:
    # Combat rows are kept as character poses only; the broad hit range is
    # drawn from sword_aura.png at runtime.  These shifts make the attack read
    # as windup -> contact -> recovery without stretching the sprite.
    attack_offsets = {
        4: [(-3, 0), (-1, 0), (1, -1), (3, 0), (2, 1), (0, 0)],
        5: [(-2, 1), (0, 0), (2, -1), (3, 0), (1, 1), (0, 0)],
    }
    for row, offsets in attack_offsets.items():
        if row >= len(rows) or len(rows[row]) < 6:
            continue
        frames = [frame.copy() for frame in rows[row][:6]]
        rows[row] = [shifted_frame(frames[index], offsets[index]) for index in range(6)]


def draw_cast_glow(frame: Image.Image, column: int) -> None:
    glow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    draw = ImageDraw.Draw(frame)
    if column == 3:
        center = (129, 86)
        radius = 5
    elif column == 4:
        center = (133, 78)
        radius = 8
    else:
        center = (134, 82)
        radius = 6
        draw.line([(142, 82), (153, 82)], fill=(150, 252, 255, 190), width=2)
        draw.line([(148, 77), (148, 87)], fill=(205, 255, 255, 150), width=1)
    glow_draw.ellipse(
        (
            center[0] - radius * 2,
            center[1] - radius * 2,
            center[0] + radius * 2,
            center[1] + radius * 2,
        ),
        fill=(106, 42, 172, 95),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(2.0))
    frame.alpha_composite(glow)
    draw.ellipse(
        (
            center[0] - radius,
            center[1] - radius,
            center[0] + radius,
            center[1] + radius,
        ),
        fill=(178, 80, 238, 220),
        outline=(236, 198, 255, 235),
        width=2,
    )
    draw.line(
        [(center[0] - radius - 5, center[1]), (center[0] + radius + 5, center[1])],
        fill=(236, 198, 255, 210),
        width=1,
    )
    draw.line(
        [(center[0], center[1] - radius - 5), (center[0], center[1] + radius + 5)],
        fill=(236, 198, 255, 180),
        width=1,
    )


def clear_effect_fragments(rows: list[list[Image.Image]]) -> None:
    # Keep the character and weapon style from the previous sheet, but remove a
    # few disconnected slash remnants that touched the old frame edge. The new
    # attack range is shown by sword_aura.png instead.
    cleanup_rects = {
        (4, 2): [(0, 0, 60, 144)],
        (4, 4): [(0, 0, 62, 144)],
        (5, 2): [(0, 0, 62, 144)],
        (5, 5): [(0, 0, 44, 144)],
        (6, 5): [(0, 0, 34, 144)],
    }
    for (row, column), rects in cleanup_rects.items():
        if row >= len(rows) or column >= len(rows[row]):
            continue
        frame = rows[row][column]
        pixels = frame.load()
        for left, top, right, bottom in rects:
            for y in range(max(0, top), min(frame.height, bottom)):
                for x in range(max(0, left), min(frame.width, right)):
                    pixels[x, y] = (*pixels[x, y][:3], 0)
    for row in rows:
        for frame in row:
            remove_alpha_islands(frame, max_area=140)
            remove_alpha_islands(frame, max_area=520, edge_margin=10)
    for column in [3, 4, 5]:
        if 6 >= len(rows) or column >= len(rows[6]):
            continue
        spell_frame = rows[6][column]
        erase_magic_colors(spell_frame)
        remove_alpha_islands(spell_frame, max_area=900, require_magic=True)
        remove_detached_components(spell_frame)
        draw_cast_glow(spell_frame, column)
    erase_attack_aura_from_character(rows)


def erase_attack_aura_from_character(rows: list[list[Image.Image]]) -> None:
    # Sword/hand pixels stay in the character sheet; wide cyan-white slash
    # ribbons are removed and drawn by sword_aura.png instead.  The regions
    # below only cover the old embedded effect arcs from the source sheet.
    cleanup_regions = {
        (4, 3): [(108, 64, 174, 130)],
        (4, 4): [(116, 8, 190, 128)],
        (4, 5): [(104, 20, 170, 136)],
        (5, 1): [(48, 86, 158, 136)],
        (5, 3): [(82, 64, 176, 136)],
    }
    for (row, column), regions in cleanup_regions.items():
        if row >= len(rows) or column >= len(rows[row]):
            continue
        frame = rows[row][column]
        pixels = frame.load()
        for left, top, right, bottom in regions:
            for y in range(max(0, top), min(frame.height, bottom)):
                for x in range(max(0, left), min(frame.width, right)):
                    r, g, b, a = pixels[x, y]
                    if a <= 24:
                        continue
                    is_bright_slash = g > 165 and b > 170 and r > 120 and max(r, g, b) - min(r, g, b) < 95
                    is_cyan_slash = b > 170 and g > 155 and b > r + 16
                    if is_bright_slash or is_cyan_slash:
                        pixels[x, y] = (r, g, b, 0)
        remove_alpha_islands(frame, max_area=120)


def draw_soft_arc(
    canvas: Image.Image,
    bbox: tuple[int, int, int, int],
    start: int,
    end: int,
    *,
    width: int,
    color: tuple[int, int, int, int],
    glow_color: tuple[int, int, int, int],
) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    draw_aura_arc(glow_draw, bbox, start, end, glow_color, width + 8)
    glow = glow.filter(ImageFilter.GaussianBlur(2.2))
    canvas.alpha_composite(glow)
    draw = ImageDraw.Draw(canvas)
    draw_aura_arc(draw, bbox, start, end, color, width)
    inset = (bbox[0] + 5, bbox[1] + 4, bbox[2] - 4, bbox[3] - 4)
    draw_aura_arc(draw, inset, start + 4, end - 4, (178, 246, 255, 225), max(2, width // 2))


def arc_ribbon_points(
    bbox: tuple[int, int, int, int],
    start: float,
    end: float,
    width: float,
    *,
    samples: int = 42,
    taper: float = 0.42,
) -> list[tuple[float, float]]:
    left, top, right, bottom = bbox
    center_x = (left + right) * 0.5
    center_y = (top + bottom) * 0.5
    radius_x = (right - left) * 0.5
    radius_y = (bottom - top) * 0.5
    outer: list[tuple[float, float]] = []
    inner: list[tuple[float, float]] = []
    for index in range(samples):
        t = index / max(samples - 1, 1)
        angle = radians(start + (end - start) * t)
        # Wider in the middle, tapered at both ends. This makes it read more
        # like a swung blade trail than a pasted-on geometric arc.
        local_width = width * (taper + (1.0 - taper) * sin(t * 3.14159))
        unit_x = cos(angle)
        unit_y = sin(angle)
        outer.append((
            center_x + (radius_x + local_width) * unit_x,
            center_y + (radius_y + local_width * 0.82) * unit_y,
        ))
        inner.append((
            center_x + (radius_x - local_width) * unit_x,
            center_y + (radius_y - local_width * 0.82) * unit_y,
        ))
    return outer + list(reversed(inner))


def draw_energy_ribbon(
    canvas: Image.Image,
    bbox: tuple[int, int, int, int],
    start: float,
    end: float,
    *,
    width: float,
    warm: tuple[int, int, int, int] = (187, 79, 236, 230),
    cool: tuple[int, int, int, int] = (237, 201, 255, 210),
) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(
        arc_ribbon_points(bbox, start, end, width + 7.0, samples=48, taper=0.18),
        fill=(112, 42, 168, 88),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(2.6))
    canvas.alpha_composite(glow)

    draw = ImageDraw.Draw(canvas)
    draw.polygon(
        arc_ribbon_points(bbox, start, end, width + 2.0, samples=46, taper=0.30),
        fill=(88, 34, 132, 205),
    )
    draw.polygon(
        arc_ribbon_points(bbox, start, end, width, samples=46, taper=0.38),
        fill=warm,
    )
    inner_bbox = (bbox[0] + 8, bbox[1] + 6, bbox[2] - 8, bbox[3] - 6)
    draw.polygon(
        arc_ribbon_points(inner_bbox, start + 5, end - 5, max(2.0, width * 0.36), samples=38, taper=0.25),
        fill=cool,
    )
    highlight_bbox = (bbox[0] + 14, bbox[1] + 10, bbox[2] - 14, bbox[3] - 10)
    draw.polygon(
        arc_ribbon_points(highlight_bbox, start + 11, end - 13, max(1.0, width * 0.16), samples=30, taper=0.2),
        fill=(255, 232, 255, 205),
    )


def draw_dash_slash(canvas: Image.Image, step: int) -> None:
    draw = ImageDraw.Draw(canvas)
    length = 108 + step * 8
    x0 = 12
    x1 = min(140, x0 + length)
    center_y = 48
    tip = (x1, center_y)
    body = [
        (x0, center_y),
        (x1 - 30, center_y - 19),
        tip,
        (x1 - 30, center_y + 19),
    ]
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(body, fill=(112, 42, 168, 88))
    glow = glow.filter(ImageFilter.GaussianBlur(2.4))
    canvas.alpha_composite(glow)
    draw.polygon(body, fill=(174, 70, 230, 205))
    draw.polygon(
        [
            (x0 + 8, center_y),
            (x1 - 32, center_y - 8),
            (x1 - 6, center_y),
            (x1 - 32, center_y + 8),
        ],
        fill=(236, 200, 255, 205),
    )
    draw.line([(x0 + 14, center_y), (x1 - 9, center_y)], fill=(255, 232, 255, 230), width=2)
    draw.line([(x0 + 2, center_y - 8), (x1 - 46, center_y - 14)], fill=(187, 94, 246, 130), width=2)
    draw.line([(x0 + 2, center_y + 8), (x1 - 44, center_y + 13)], fill=(187, 94, 246, 120), width=2)


def bezier_point(
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    t: float,
) -> tuple[float, float]:
    inv = 1.0 - t
    return (
        inv * inv * start[0] + 2.0 * inv * t * control[0] + t * t * end[0],
        inv * inv * start[1] + 2.0 * inv * t * control[1] + t * t * end[1],
    )


def draw_hitbox_slash(
    canvas: Image.Image,
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    *,
    width: float,
    warm: tuple[int, int, int, int] = (180, 76, 236, 230),
    cool: tuple[int, int, int, int] = (236, 202, 255, 220),
) -> None:
    samples = 36
    points = [bezier_point(start, control, end, index / (samples - 1)) for index in range(samples)]

    def ribbon(poly_width: float, taper: float) -> list[tuple[float, float]]:
        left: list[tuple[float, float]] = []
        right: list[tuple[float, float]] = []
        for index, point in enumerate(points):
            if index == 0:
                next_point = points[index + 1]
                direction = (next_point[0] - point[0], next_point[1] - point[1])
            elif index == len(points) - 1:
                prev_point = points[index - 1]
                direction = (point[0] - prev_point[0], point[1] - prev_point[1])
            else:
                prev_point = points[index - 1]
                next_point = points[index + 1]
                direction = (next_point[0] - prev_point[0], next_point[1] - prev_point[1])
            length = max((direction[0] * direction[0] + direction[1] * direction[1]) ** 0.5, 0.001)
            normal = (-direction[1] / length, direction[0] / length)
            t = index / (len(points) - 1)
            local_width = poly_width * (taper + (1.0 - taper) * sin(t * 3.14159))
            left.append((point[0] + normal[0] * local_width, point[1] + normal[1] * local_width))
            right.append((point[0] - normal[0] * local_width, point[1] - normal[1] * local_width))
        return left + list(reversed(right))

    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(ribbon(width + 10.0, 0.28), fill=(112, 42, 168, 88))
    glow = glow.filter(ImageFilter.GaussianBlur(2.4))
    canvas.alpha_composite(glow)

    draw = ImageDraw.Draw(canvas)
    draw.polygon(ribbon(width + 4.0, 0.32), fill=(90, 34, 132, 210))
    draw.polygon(ribbon(width, 0.42), fill=warm)
    draw.polygon(ribbon(max(2.0, width * 0.34), 0.28), fill=cool)
    draw.polygon(ribbon(max(1.0, width * 0.12), 0.18), fill=(255, 232, 255, 215))


def draw_hitbox_thrust(canvas: Image.Image, step: int) -> None:
    draw = ImageDraw.Draw(canvas)
    start_x = 8
    end_x = 136
    center_y = 48
    half_height = 16 + step * 2
    body = [
        (start_x, center_y - 5),
        (end_x - 33, center_y - half_height),
        (end_x, center_y),
        (end_x - 33, center_y + half_height),
        (start_x, center_y + 5),
    ]
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(body, fill=(112, 42, 168, 88))
    glow = glow.filter(ImageFilter.GaussianBlur(2.4))
    canvas.alpha_composite(glow)
    draw.polygon(body, fill=(180, 76, 236, 215))
    draw.polygon(
        [
            (start_x + 10, center_y - 2),
            (end_x - 35, center_y - 7),
            (end_x - 8, center_y),
            (end_x - 35, center_y + 7),
            (start_x + 10, center_y + 2),
        ],
        fill=(236, 202, 255, 215),
    )
    draw.line([(start_x + 18, center_y), (end_x - 12, center_y)], fill=(255, 232, 255, 225), width=2)


def build_action_sheet(source_dir: Path, output_path: Path) -> None:
    source_names = [
        "locomotion.png",
        "mobility.png",
        "combat.png",
        "magic_defense.png",
    ]
    action_rows: list[list[Image.Image]] = []
    for name in source_names:
        action_rows.extend(extract_rows(source_dir / name))
    rebuild_walk_cycle(action_rows)
    rebuild_attack_motion(action_rows)
    clear_effect_fragments(action_rows)

    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * SHEET_COLUMNS, FRAME_SIZE[1] * len(action_rows)),
        (0, 0, 0, 0),
    )
    for row, frames in enumerate(action_rows):
        for column, frame in enumerate(frames):
            sheet.alpha_composite(frame, (column * FRAME_SIZE[0], row * FRAME_SIZE[1]))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def draw_aura_arc(
    draw: ImageDraw.ImageDraw,
    bbox: tuple[int, int, int, int],
    start: int,
    end: int,
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    draw.arc(bbox, start=start, end=end, fill=color, width=width)


def make_aura_frame(kind: int, step: int) -> Image.Image:
    canvas = Image.new("RGBA", AURA_FRAME_SIZE, (0, 0, 0, 0))

    if kind == 0:
        draw_hitbox_thrust(canvas, step)
    elif kind == 1:
        draw_hitbox_slash(canvas, (8, 69), (72, 88), (138, 67), width=11.0 + step)
    elif kind == 2:
        draw_hitbox_slash(canvas, (45, 8), (82, 43), (118, 88), width=11.0 + step)
    else:
        draw_hitbox_thrust(canvas, step)
    return canvas


def build_aura_sheet(output_path: Path) -> None:
    sheet = Image.new(
        "RGBA",
        (AURA_FRAME_SIZE[0] * AURA_COLUMNS, AURA_FRAME_SIZE[1] * AURA_ROWS),
        (0, 0, 0, 0),
    )
    for row in range(AURA_ROWS):
        for column in range(AURA_COLUMNS):
            sheet.alpha_composite(
                make_aura_frame(row, column),
                (column * AURA_FRAME_SIZE[0], row * AURA_FRAME_SIZE[1]),
            )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    output_dir = project / "assets" / "characters" / "generated"
    source_dir = output_dir / "source"
    build_action_sheet(source_dir, output_dir / "hero_actions.png")
    build_aura_sheet(output_dir / "sword_aura.png")
    print(output_dir / "hero_actions.png")
    print(output_dir / "sword_aura.png")


if __name__ == "__main__":
    main()
