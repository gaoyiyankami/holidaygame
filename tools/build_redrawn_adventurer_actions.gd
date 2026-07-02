extends SceneTree

const FRAME_SIZE := Vector2i(192, 144)
const FRAME_COUNT := 8
const ROW_COUNT := 5
const BASELINE_Y := 138
const SOURCE_SCALES := [0.45, 0.54, 0.54, 0.45, 0.45]

const FRAME_SOURCES := [
	"res://assets/characters/redrawn/adventurer_actions_source.png",
	"res://assets/characters/redrawn/adventurer_attack_23_v2_source.png",
	"res://assets/characters/redrawn/adventurer_attack_23_v2_source.png",
	"res://assets/characters/redrawn/adventurer_actions_source.png",
	"res://assets/characters/redrawn/adventurer_actions_source.png",
]

const FRAME_BOXES := [
	[
		Rect2i(88, 70, 98, 195), Rect2i(271, 72, 99, 193),
		Rect2i(493, 41, 111, 224), Rect2i(709, 83, 202, 182),
		Rect2i(927, 89, 249, 176), Rect2i(1165, 87, 232, 178),
		Rect2i(1414, 88, 108, 177), Rect2i(1621, 71, 97, 194),
	],
	[
		Rect2i(0, 0, 230, 428), Rect2i(230, 0, 230, 428),
		Rect2i(460, 0, 229, 428), Rect2i(689, 0, 230, 428),
		Rect2i(919, 0, 230, 428), Rect2i(1149, 0, 230, 428),
		Rect2i(1379, 0, 229, 428), Rect2i(1608, 0, 230, 428),
	],
	[
		Rect2i(0, 428, 230, 428), Rect2i(230, 428, 230, 428),
		Rect2i(460, 428, 229, 428), Rect2i(689, 428, 230, 428),
		Rect2i(919, 428, 230, 428), Rect2i(1149, 428, 230, 428),
		Rect2i(1379, 428, 229, 428), Rect2i(1608, 428, 230, 428),
	],
	[
		Rect2i(71, 393, 114, 132), Rect2i(276, 386, 138, 141),
		Rect2i(472, 373, 178, 154), Rect2i(722, 378, 267, 149),
		Rect2i(977, 369, 290, 158), Rect2i(1298, 373, 178, 154),
		Rect2i(1582, 349, 99, 195), Rect2i(1582, 349, 99, 195),
	],
	[
		Rect2i(88, 610, 98, 194), Rect2i(303, 611, 107, 193),
		Rect2i(538, 612, 101, 193), Rect2i(802, 612, 113, 194),
		Rect2i(1070, 613, 104, 193), Rect2i(1319, 619, 108, 187),
		Rect2i(1567, 618, 103, 188), Rect2i(1567, 618, 103, 188),
	],
]


func _initialize() -> void:
	var output := Image.create(
		FRAME_SIZE.x * FRAME_COUNT,
		FRAME_SIZE.y * ROW_COUNT,
		false,
		Image.FORMAT_RGBA8
	)
	output.fill(Color(0.0, 0.0, 0.0, 0.0))
	for row in ROW_COUNT:
		var source := Image.load_from_file(FRAME_SOURCES[row])
		if source == null or source.is_empty():
			push_error("Unable to load redrawn action source: %s" % FRAME_SOURCES[row])
			quit(1)
			return
		for column in FRAME_COUNT:
			var frame := source.get_region(FRAME_BOXES[row][column])
			frame.resize(
				maxi(1, roundi(frame.get_width() * float(SOURCE_SCALES[row]))),
				maxi(1, roundi(frame.get_height() * float(SOURCE_SCALES[row]))),
				Image.INTERPOLATE_NEAREST
			)
			var used := frame.get_used_rect()
			var foot_center := _find_foot_center(frame, used)
			var destination := Vector2i(
				column * FRAME_SIZE.x + roundi(float(FRAME_SIZE.x) * 0.5 - foot_center),
				row * FRAME_SIZE.y + BASELINE_Y - used.end.y
			)
			output.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), destination)
	var output_path := ProjectSettings.globalize_path(
		"res://assets/characters/redrawn/adventurer_actions.png"
	)
	var error := output.save_png(output_path)
	if error == OK:
		print("Generated %s (%dx%d)" % [output_path, output.get_width(), output.get_height()])
	quit(0 if error == OK else 1)


func _find_foot_center(frame: Image, used: Rect2i) -> float:
	var sample_top := maxi(used.position.y, used.end.y - 10)
	var min_x := used.end.x
	var max_x := used.position.x
	for y in range(sample_top, used.end.y):
		for x in range(used.position.x, used.end.x):
			if frame.get_pixel(x, y).a <= 0.2:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	if min_x > max_x:
		return float(used.position.x + used.size.x / 2)
	return (float(min_x) + float(max_x)) * 0.5
