extends Node3D

const DOOR_SCENE: PackedScene = preload("res://scenes/props/cabin_door.tscn")
const INTERACTION_SCRIPT: Script = preload("res://scripts/interaction/interaction_area.gd")

const CABIN_WIDTH: float = 7.0
const CABIN_DEPTH: float = 6.0
const WALL_HEIGHT: float = 2.7
const WALL_X: float = 3.5
const WALL_Z: float = 3.0
const BOARD_HEIGHT: float = 0.19
const BOARD_STEP: float = 0.205

var _wood_tool: SurfaceTool
var _stone_tool: SurfaceTool
var _roof_tool: SurfaceTool
var _fabric_tool: SurfaceTool
var _metal_tool: SurfaceTool
var _paper_tool: SurfaceTool
var _wood_material: StandardMaterial3D
var _bark_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _fabric_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _paper_material: StandardMaterial3D
var _glass_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_create_surface_tools()
	_build_foundation()
	_build_floor()
	_build_walls()
	_build_windows()
	_build_roof()
	_build_furniture()
	_add_door()
	_commit_surfaces()
	_build_collisions()
	_add_interaction_areas()
	_add_cabin_ambience()


func _create_materials() -> void:
	_wood_material = WorldMaterials.create("wood_planks", Color(0.78, 0.73, 0.64), 0.94, 1.0, 0.3)
	_wood_material.vertex_color_use_as_albedo = true
	_bark_material = WorldMaterials.create("bark", Color(0.68, 0.65, 0.6), 0.98, 1.0, 0.38)
	_stone_material = WorldMaterials.create("stone", Color(0.78, 0.79, 0.75), 0.97, 1.0, 0.38)
	_roof_material = WorldMaterials.create("shingle", Color(0.72, 0.7, 0.65), 0.96, 1.0, 0.3)
	_fabric_material = WorldMaterials.create("cloth", Color(0.68, 0.64, 0.57), 1.0, 1.0, 0.2)
	_metal_material = WorldMaterials.create("metal", Color(0.72, 0.74, 0.7), 0.8, 1.0, 0.22)
	_paper_material = WorldMaterials.create("paper", Color(0.9, 0.84, 0.68), 0.96, 1.0, 0.1)
	_glass_material = StandardMaterial3D.new()
	_glass_material.albedo_color = Color(0.12, 0.18, 0.17, 0.72)
	_glass_material.roughness = 0.3
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _create_surface_tools() -> void:
	_wood_tool = _new_surface_tool()
	_wood_tool.set_color(Color.WHITE)
	_stone_tool = _new_surface_tool()
	_roof_tool = _new_surface_tool()
	_fabric_tool = _new_surface_tool()
	_metal_tool = _new_surface_tool()
	_paper_tool = _new_surface_tool()


func _new_surface_tool() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _build_foundation() -> void:
	for side in [-1.0, 1.0]:
		_append_board(
			_stone_tool,
			Vector3(0.0, -0.12, side * (WALL_Z - 0.02)),
			Vector3.RIGHT,
			CABIN_WIDTH + 0.18,
			0.27,
			0.32,
			0.025
		)
		_append_board(
			_stone_tool,
			Vector3(side * (WALL_X - 0.02), -0.12, 0.0),
			Vector3.FORWARD,
			CABIN_DEPTH + 0.08,
			0.27,
			0.32,
			0.025
		)
	_append_board(
		_stone_tool,
		Vector3(0.0, -0.05, WALL_Z + 0.22),
		Vector3.RIGHT,
		1.42,
		0.15,
		0.48,
		0.025
	)


func _build_floor() -> void:
	var plank_count: int = 34
	var plank_width: float = CABIN_DEPTH / plank_count
	for index in range(plank_count):
		var z: float = -WALL_Z + plank_width * (float(index) + 0.5)
		var variation: float = sin(float(index) * 1.79) * 0.012
		_append_board(
			_wood_tool,
			Vector3(0.0, 0.055 + variation, z),
			Vector3.RIGHT,
			CABIN_WIDTH - 0.1,
			0.1,
			plank_width - 0.012,
			0.012
		)
	for beam_x in [-2.7, -0.9, 0.9, 2.7]:
		_append_board(
			_wood_tool,
			Vector3(beam_x, -0.13, 0.0),
			Vector3.FORWARD,
			CABIN_DEPTH,
			0.16,
			0.16,
			0.02
		)


func _build_walls() -> void:
	var row_count: int = int(floor((WALL_HEIGHT - 0.15) / BOARD_STEP))
	for row in range(row_count):
		var y: float = 0.15 + float(row) * BOARD_STEP
		_add_wall_course("front", y)
		_add_wall_course("back", y)
		_add_wall_course("left", y)
		_add_wall_course("right", y)

	for row in range(10):
		var y: float = WALL_HEIGHT + 0.09 + float(row) * 0.17
		var half_width: float = maxf(0.12, WALL_X * (4.45 - y) / 1.75)
		var width: float = half_width * 2.0
		for side in [-1.0, 1.0]:
			_append_board(
				_wood_tool,
				Vector3(0.0, y, side * WALL_Z),
				Vector3.RIGHT,
				width,
				0.16,
				0.16,
				0.018
			)

	for x in [-3.42, 3.42]:
		for z in [-2.94, 2.94]:
			_append_board(
				_wood_tool,
				Vector3(x, WALL_HEIGHT * 0.5, z),
				Vector3.UP,
				WALL_HEIGHT,
				0.16,
				0.16,
				0.018
			)
	for x in [-0.57, 0.57]:
		_append_board(
			_wood_tool,
			Vector3(x, 1.06, WALL_Z + 0.07),
			Vector3.UP,
			2.12,
			0.12,
			0.23,
			0.018
		)
	_append_board(
		_wood_tool,
		Vector3(0.0, 2.12, WALL_Z + 0.07),
		Vector3.RIGHT,
		1.28,
		0.14,
		0.23,
		0.018
	)
	for z in [-2.9, 2.9]:
		_append_board(
			_wood_tool,
			Vector3(0.0, 2.68, z),
			Vector3.RIGHT,
			CABIN_WIDTH,
			0.15,
			0.18,
			0.018
		)
	for x in [-3.4, 3.4]:
		_append_board(
			_wood_tool,
			Vector3(x, 2.68, 0.0),
			Vector3.FORWARD,
			CABIN_DEPTH,
			0.15,
			0.18,
			0.018
		)


func _add_wall_course(side: String, y: float) -> void:
	var axis: Vector3
	var fixed_position: Vector3
	var intervals: Array[Vector2] = [Vector2(-WALL_X, WALL_X)]
	match side:
		"front":
			axis = Vector3.RIGHT
			fixed_position = Vector3(0.0, y, WALL_Z)
			if y < 2.1:
				intervals = [Vector2(-WALL_X, -0.57), Vector2(0.57, WALL_X)]
		"back":
			axis = Vector3.RIGHT
			fixed_position = Vector3(0.0, y, -WALL_Z)
			if y > 1.05 and y < 2.05:
				intervals = [
					Vector2(-WALL_X, -2.78),
					Vector2(-1.64, 1.64),
					Vector2(2.78, WALL_X)
				]
		"left":
			axis = Vector3.FORWARD
			fixed_position = Vector3(-WALL_X, y, 0.0)
			if y > 1.05 and y < 2.05:
				intervals = [Vector2(-WALL_Z, -1.08), Vector2(0.18, WALL_Z)]
		"right":
			axis = Vector3.FORWARD
			fixed_position = Vector3(WALL_X, y, 0.0)
			if y > 1.05 and y < 2.05:
				intervals = [Vector2(-WALL_Z, -1.08), Vector2(0.18, WALL_Z)]

	for interval in intervals:
		var center: Vector3 = fixed_position
		if axis == Vector3.RIGHT:
			center.x = (interval.x + interval.y) * 0.5
		else:
			center.z = (interval.x + interval.y) * 0.5
		_append_board(
			_wood_tool,
			center,
			axis,
			interval.y - interval.x,
			BOARD_HEIGHT,
			0.17,
			0.022,
			sin(y * 9.0 + interval.x) * 0.012
		)


func _build_windows() -> void:
	_add_window(
		Vector3(-2.2, 1.55, -WALL_Z - 0.025),
		Vector3.RIGHT,
		Vector3.FORWARD,
		1.08,
		0.88
	)
	_add_window(
		Vector3(2.2, 1.55, -WALL_Z - 0.025),
		Vector3.RIGHT,
		Vector3.FORWARD,
		1.08,
		0.88
	)
	_add_window(
		Vector3(-WALL_X - 0.025, 1.55, -0.45),
		Vector3.FORWARD,
		Vector3.LEFT,
		1.08,
		0.88
	)
	_add_window(
		Vector3(WALL_X + 0.025, 1.55, -0.45),
		Vector3.FORWARD,
		Vector3.RIGHT,
		1.08,
		0.88
	)


func _add_window(
	center: Vector3,
	horizontal_axis: Vector3,
	normal: Vector3,
	width: float,
	height: float
) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width - 0.1, height - 0.1)
	var glass := MeshInstance3D.new()
	glass.name = "AgedGlass"
	glass.mesh = plane
	glass.material_override = _glass_material
	var orientation := Basis(Vector3.RIGHT, PI * 0.5)
	if normal.x > 0.5:
		orientation = Basis(Vector3.UP, PI * 0.5) * orientation
	elif normal.x < -0.5:
		orientation = Basis(Vector3.UP, -PI * 0.5) * orientation
	elif normal.z < -0.5:
		orientation = Basis(Vector3.RIGHT, -PI * 0.5)
	glass.position = center
	glass.basis = orientation
	add_child(glass)

	for side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + horizontal_axis * side * (width * 0.5),
			Vector3.UP,
			height,
			0.09,
			0.16,
			0.015
		)
		_append_board(
			_wood_tool,
			center + Vector3.UP * side * (height * 0.5),
			horizontal_axis,
			width + 0.08,
			0.1,
			0.19,
			0.018
		)
	_append_board(
		_wood_tool,
		center + Vector3.UP * (height * 0.5 + 0.12),
		horizontal_axis,
		width + 0.24,
		0.11,
		0.23,
		0.018
	)
	_append_board(
		_wood_tool,
		center + Vector3.UP * 0.03,
		horizontal_axis,
		width - 0.12,
		0.035,
		0.05,
		0.008
	)
	_append_board(
		_wood_tool,
		center,
		horizontal_axis,
		width - 0.08,
		0.045,
		0.035,
		0.006
	)


func _build_roof() -> void:
	var roof_angle: float = atan2(1.8, 3.85)
	for side in [-1.0, 1.0]:
		var slope_axis := Vector3(side * cos(roof_angle), -sin(roof_angle), 0.0)
		_append_board(
			_wood_tool,
			Vector3(side * 1.925, 3.55, 0.0),
			slope_axis,
			4.35,
			0.11,
			CABIN_DEPTH + 0.5,
			0.025
		)
		for z_index in range(10):
			var z: float = -3.24 + float(z_index) * 0.72
			for row in range(7):
				var distance: float = 0.28 + float(row) * 0.58
				var stagger: float = 0.28 if row % 2 == 1 else 0.0
				var shingle_z: float = z + stagger
				if absf(shingle_z) > 3.3:
					continue
				var slope_position := Vector3(
					side * distance * cos(roof_angle),
					4.45 - distance * sin(roof_angle),
					shingle_z
				)
				_append_board(
					_roof_tool,
					slope_position,
					slope_axis,
					0.72,
					0.045,
					0.76,
					0.018
				)
		for z in [-2.8, -1.68, -0.56, 0.56, 1.68, 2.8]:
			var rafter_center := Vector3(side * 1.9, 3.55, z)
			_append_board(
				_wood_tool,
				rafter_center,
				slope_axis,
				4.45,
				0.16,
				0.19,
				0.02
			)

	_append_board(
		_wood_tool,
		Vector3(0.0, 4.48, 0.0),
		Vector3.FORWARD,
		CABIN_DEPTH + 0.55,
		0.2,
		0.22,
		0.025
	)


func _build_furniture() -> void:
	_build_rug()
	_build_table(Vector3(0.8, 0.0, 0.0))
	_build_chair(Vector3(-0.2, 0.0, 1.1))
	_build_chair(Vector3(1.8, 0.0, 1.1))
	_build_bed(Vector3(-2.25, 0.0, -1.3))
	_build_wardrobe(Vector3(-2.65, 0.0, 1.6))
	_build_shelves(Vector3(0.2, 0.0, -2.6))
	_build_stove(Vector3(2.3, 0.0, -1.75))
	_build_tabletop_details(Vector3(0.8, 0.0, 0.0))
	_build_wall_details()
	_build_firewood(Vector3(1.95, 0.0, -2.35))
	_build_cabin_lamp()


func _build_cabin_lamp() -> void:
	_append_board(
		_metal_tool,
		Vector3(0.0, 4.32, 0.0),
		Vector3.FORWARD,
		0.36,
		0.06,
		0.34,
		0.02
	)
	_append_tube(
		_metal_tool,
		Vector3(0.0, 4.29, 0.0),
		Vector3(0.0, 3.14, 0.0),
		0.018,
		0.018,
		8
	)
	_append_tube(
		_metal_tool,
		Vector3(0.0, 3.16, 0.0),
		Vector3(0.0, 2.91, 0.0),
		0.065,
		0.27,
		14
	)
	_append_tube(
		_metal_tool,
		Vector3(0.0, 2.92, 0.0),
		Vector3(0.0, 2.88, 0.0),
		0.27,
		0.27,
		14
	)

	var bulb := MeshInstance3D.new()
	bulb.name = "WarmLampBulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.075
	bulb_mesh.height = 0.15
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, 2.89, 0.0)
	var bulb_material := StandardMaterial3D.new()
	bulb_material.albedo_color = Color(1.0, 0.72, 0.42)
	bulb_material.emission_enabled = true
	bulb_material.emission = Color(1.0, 0.48, 0.2)
	bulb_material.emission_energy_multiplier = 1.4
	bulb.material_override = bulb_material
	add_child(bulb)

	var light := OmniLight3D.new()
	light.name = "CabinCeilingLight"
	light.position = Vector3(0.0, 2.72, 0.0)
	light.light_color = Color(1.0, 0.76, 0.56)
	light.light_energy = 1.65
	light.omni_range = 9.0
	light.light_specular = 0.18
	light.shadow_enabled = false
	add_child(light)


func _build_rug() -> void:
	_append_board(
		_fabric_tool,
		Vector3(0.7, 0.09, 0.15),
		Vector3.RIGHT,
		2.0,
		0.035,
		1.45,
		0.015,
		0.018
	)
	for side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			Vector3(0.7, 0.11, 0.15 + side * 0.64),
			Vector3.RIGHT,
			1.9,
			0.018,
			0.025
		)
		_append_board(
			_wood_tool,
			Vector3(0.7 + side * 0.91, 0.11, 0.15),
			Vector3.FORWARD,
			1.28,
			0.018,
			0.025
		)


func _build_table(center: Vector3) -> void:
	var top_y: float = 0.82
	for index in range(4):
		var z: float = center.z - 0.48 + float(index) * 0.32
		_append_board(
			_wood_tool,
			Vector3(center.x, top_y, z),
			Vector3.RIGHT,
			1.72,
			0.075,
			0.3,
			0.02,
			0.014
		)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_append_board(
				_wood_tool,
				center + Vector3(x_side * 0.68, 0.4, z_side * 0.34),
				Vector3.UP,
				0.8,
				0.11,
				0.12,
				0.02
			)
		_append_board(
			_wood_tool,
			center + Vector3(x_side * 0.68, 0.56, 0.0),
			Vector3.FORWARD,
			0.72,
			0.09,
			0.1,
			0.015
		)
	for z_side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + Vector3(0.0, 0.56, z_side * 0.34),
			Vector3.RIGHT,
			1.32,
			0.09,
			0.1,
			0.015
		)


func _build_chair(center: Vector3) -> void:
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var leg_height: float = 0.52 if z_side < 0.0 else 1.15
			_append_board(
				_wood_tool,
				center + Vector3(x_side * 0.19, leg_height * 0.5, z_side * 0.19),
				Vector3.UP,
				leg_height,
				0.075,
				0.075,
				0.012
			)
	_append_board(
		_wood_tool,
		center + Vector3(0.0, 0.52, 0.0),
		Vector3.RIGHT,
		0.51,
		0.08,
		0.48,
		0.025,
		0.012
	)
	for index in range(3):
		var x: float = center.x - 0.16 + float(index) * 0.16
		_append_board(
			_wood_tool,
			Vector3(x, 0.91, center.z + 0.19),
			Vector3.UP,
			0.5,
			0.09,
			0.045,
			0.012,
			0.012
		)
	_append_board(
		_wood_tool,
		Vector3(center.x, 1.12, center.z + 0.19),
		Vector3.RIGHT,
		0.5,
		0.12,
		0.08,
		0.018,
		0.012
	)


func _build_bed(center: Vector3) -> void:
	_append_board(
		_wood_tool,
		center + Vector3(0.0, 0.37, 0.0),
		Vector3.RIGHT,
		1.45,
		0.12,
		2.25,
		0.025
	)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_append_board(
				_wood_tool,
				center + Vector3(x_side * 0.61, 0.2, z_side * 0.98),
				Vector3.UP,
				0.4,
				0.1,
				0.1,
				0.018
			)
	_append_board(
		_wood_tool,
		center + Vector3(0.0, 0.64, 0.0),
		Vector3.RIGHT,
		1.36,
		0.32,
		2.12,
		0.08,
		0.035
	)
	_append_board(
		_fabric_tool,
		center + Vector3(0.0, 0.84, 0.4),
		Vector3.RIGHT,
		1.33,
		0.19,
		1.28,
		0.07,
		0.055
	)
	for pillow_side in [-1.0, 1.0]:
		_append_board(
			_fabric_tool,
			center + Vector3(pillow_side * 0.3, 0.93, -0.48),
			Vector3.RIGHT.rotated(Vector3.UP, pillow_side * 0.035),
			0.56,
			0.14,
			0.62,
			0.07,
			0.035
		)
	_append_board(
		_wood_tool,
		center + Vector3(0.0, 0.82, -1.13),
		Vector3.RIGHT,
		1.5,
		1.12,
		0.15,
		0.035
	)


func _build_wardrobe(center: Vector3) -> void:
	var width: float = 1.25
	var depth: float = 0.65
	var height: float = 2.25
	for x_side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + Vector3(x_side * (width * 0.5 - 0.055), height * 0.5, 0.0),
			Vector3.UP,
			height,
			0.11,
			depth,
			0.025
		)
	_append_board(
		_wood_tool,
		center + Vector3(0.0, height - 0.06, 0.0),
		Vector3.RIGHT,
		width,
		0.12,
		depth,
		0.025
	)
	_append_board(
		_wood_tool,
		center + Vector3(0.0, 0.12, 0.0),
		Vector3.RIGHT,
		width,
		0.16,
		depth,
		0.025
	)
	for x_side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + Vector3(x_side * 0.31, height * 0.5, depth * 0.5 + 0.018),
			Vector3.UP,
			height - 0.32,
			0.58,
			0.07,
			0.03,
			0.018
		)
		for detail_side in [-1.0, 1.0]:
			_append_board(
				_wood_tool,
				center + Vector3(x_side * 0.31, 0.48 + detail_side * 0.48, depth * 0.5 + 0.06),
				Vector3.RIGHT,
				0.43,
				0.025,
				0.025
			)
		_append_tube(
			_metal_tool,
			center + Vector3(x_side * 0.11, 1.05, depth * 0.5 + 0.09),
			center + Vector3(x_side * 0.11, 1.24, depth * 0.5 + 0.09),
			0.025,
			0.025,
			10
		)


func _build_shelves(center: Vector3) -> void:
	var shelf_x: float = 1.55
	for level in [1.05, 1.58, 2.08]:
		_append_board(
			_wood_tool,
			center + Vector3(0.0, level, 0.0),
			Vector3.RIGHT,
			shelf_x,
			0.075,
			0.42,
			0.02
		)
	for x_side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + Vector3(x_side * 0.69, 1.57, 0.0),
			Vector3.UP,
			1.25,
			0.09,
			0.38,
			0.018
		)
	for level in range(3):
		var y: float = 1.15 + float(level) * 0.5
		for book_index in range(5):
			var x: float = -0.56 + float(book_index) * 0.27
			var book_height: float = 0.23 + float((book_index + level) % 3) * 0.045
			var book_depth: float = 0.16 + float(book_index % 2) * 0.025
			_add_book(
				Vector3(center.x + x, y + book_height * 0.5, center.z + book_depth * 0.12),
				0.2,
				book_height,
				book_depth,
				book_index
			)


func _add_book(center: Vector3, width: float, height: float, depth: float, variant: int) -> void:
	var cover_colors: Array[Color] = [
		Color(0.44, 0.18, 0.12),
		Color(0.22, 0.29, 0.24),
		Color(0.47, 0.36, 0.21),
		Color(0.24, 0.22, 0.19),
		Color(0.36, 0.28, 0.32)
	]
	_wood_tool.set_color(cover_colors[variant % cover_colors.size()])
	_append_board(
		_wood_tool,
		center,
		Vector3.UP,
		height,
		width,
		depth,
		0.018
	)
	_wood_tool.set_color(Color.WHITE)
	_append_board(
		_paper_tool,
		center + Vector3(0.0, 0.0, depth * 0.53),
		Vector3.UP,
		height * 0.92,
		width * 0.82,
		depth * 0.13,
		0.012
	)
	_append_board(
		_paper_tool,
		center + Vector3(0.0, height * 0.15, depth * 0.61),
		Vector3.RIGHT,
		width * 0.58,
		0.022,
		0.008,
		0.005
	)


func _build_stove(center: Vector3) -> void:
	for x_side in [-1.0, 1.0]:
		_append_board(
			_metal_tool,
			center + Vector3(x_side * 0.29, 0.5, 0.0),
			Vector3.UP,
			0.92,
			0.1,
			0.12,
			0.02
		)
	for z_side in [-1.0, 1.0]:
		_append_board(
			_metal_tool,
			center + Vector3(0.0, 0.5, z_side * 0.25),
			Vector3.RIGHT,
			0.62,
			0.1,
			0.12,
			0.02
		)
	_append_board(
		_metal_tool,
		center + Vector3(0.0, 0.98, 0.0),
		Vector3.RIGHT,
		0.82,
		0.11,
		0.72,
		0.025
	)
	_append_board(
		_metal_tool,
		center + Vector3(0.0, 0.55, 0.36),
		Vector3.RIGHT,
		0.48,
		0.42,
		0.045,
		0.02
	)
	_append_board(
		_metal_tool,
		center + Vector3(0.0, 0.55, 0.395),
		Vector3.RIGHT,
		0.31,
		0.25,
		0.02,
		0.012
	)
	for x_side in [-1.0, 1.0]:
		for y in [0.39, 0.72]:
			_append_tube(
				_metal_tool,
				center + Vector3(x_side * 0.25, y, 0.43),
				center + Vector3(x_side * 0.25, y, 0.47),
				0.032,
				0.032,
				10
			)
	_append_tube(
		_metal_tool,
		center + Vector3(0.0, 1.05, -0.08),
		center + Vector3(0.0, 2.58, -0.08),
		0.12,
		0.115,
		12
	)
	_append_tube(
		_metal_tool,
		center + Vector3(0.0, 2.5, -0.08),
		center + Vector3(0.0, 4.02, -0.08),
		0.12,
		0.11,
		12
	)
	_append_tube(
		_metal_tool,
		center + Vector3(0.0, 3.65, -0.08),
		center + Vector3(0.0, 3.72, -0.08),
		0.17,
		0.17,
		12
	)
	_append_board(
		_metal_tool,
		center + Vector3(0.0, 0.94, -0.08),
		Vector3.RIGHT,
		0.38,
		0.08,
		0.38,
		0.018
	)
	_append_tube(
		_metal_tool,
		center + Vector3(0.0, 0.72, 0.5),
		center + Vector3(0.0, 0.72, 0.56),
		0.045,
		0.045,
		12
	)


func _build_tabletop_details(center: Vector3) -> void:
	for index in range(6):
		var x: float = center.x - 0.55 + float(index) * 0.2
		_add_book(Vector3(x, 0.91 + float(index % 2) * 0.04, center.z - 0.18), 0.15, 0.055, 0.2, index)
	for paper_index in range(5):
		var position := Vector3(
			center.x + 0.14 + float(paper_index % 2) * 0.12,
			0.875 + float(paper_index) * 0.002,
			center.z + 0.12 + float(paper_index) * 0.035
		)
		_append_board(
			_paper_tool,
			position,
			Vector3.RIGHT.rotated(Vector3.UP, float(paper_index) * 0.21),
			0.31,
			0.007,
			0.22,
			0.002,
			0.004
		)
		for line in range(3):
			_append_board(
				_wood_tool,
				position + Vector3(-0.025, 0.005, -0.06 + float(line) * 0.045),
				Vector3.RIGHT,
				0.18,
				0.003,
				0.004
			)
	for cup_x in [center.x - 0.5, center.x + 0.48]:
		_add_cup(Vector3(cup_x, 0.88, center.z + 0.31))
	_add_bottle(Vector3(center.x + 0.55, 0.88, center.z - 0.28))


func _add_cup(position: Vector3) -> void:
	var cup := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.052
	cylinder.bottom_radius = 0.042
	cylinder.height = 0.12
	cylinder.radial_segments = 16
	cup.mesh = cylinder
	cup.material_override = _paper_material
	cup.position = position + Vector3.UP * 0.06
	add_child(cup)


func _add_bottle(position: Vector3) -> void:
	var bottle_tool := _new_surface_tool()
	var profile: Array[Vector2] = [
		Vector2(0.075, 0.0),
		Vector2(0.09, 0.035),
		Vector2(0.095, 0.19),
		Vector2(0.075, 0.24),
		Vector2(0.042, 0.28),
		Vector2(0.04, 0.35),
		Vector2(0.05, 0.37)
	]
	_append_lathe(bottle_tool, position, profile, 14)
	bottle_tool.generate_normals()
	var bottle := MeshInstance3D.new()
	bottle.mesh = bottle_tool.commit()
	bottle.material_override = _glass_material
	add_child(bottle)
	_append_tube(
		_wood_tool,
		position + Vector3.UP * 0.35,
		position + Vector3.UP * 0.4,
		0.039,
		0.039,
		12
	)


func _append_lathe(
	surface: SurfaceTool,
	center: Vector3,
	profile: Array[Vector2],
	sides: int
) -> void:
	for row in range(profile.size() - 1):
		for side in range(sides):
			var next_side: int = (side + 1) % sides
			var angle_a: float = TAU * float(side) / sides
			var angle_b: float = TAU * float(next_side) / sides
			var a: Vector3 = center + Vector3(
				cos(angle_a) * profile[row].x,
				profile[row].y,
				sin(angle_a) * profile[row].x
			)
			var b: Vector3 = center + Vector3(
				cos(angle_b) * profile[row].x,
				profile[row].y,
				sin(angle_b) * profile[row].x
			)
			var c: Vector3 = center + Vector3(
				cos(angle_b) * profile[row + 1].x,
				profile[row + 1].y,
				sin(angle_b) * profile[row + 1].x
			)
			var d: Vector3 = center + Vector3(
				cos(angle_a) * profile[row + 1].x,
				profile[row + 1].y,
				sin(angle_a) * profile[row + 1].x
			)
			_add_triangle(surface, a, Vector2(float(side) / sides, profile[row].y), c, Vector2(float(next_side) / sides, profile[row + 1].y), b, Vector2(float(next_side) / sides, profile[row].y))
			_add_triangle(surface, a, Vector2(float(side) / sides, profile[row].y), d, Vector2(float(side) / sides, profile[row + 1].y), c, Vector2(float(next_side) / sides, profile[row + 1].y))


func _build_wall_details() -> void:
	_add_clock(Vector3(-1.18, 2.04, -2.84))
	_add_picture(Vector3(1.45, 1.88, -2.86))


func _add_clock(center: Vector3) -> void:
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.28
	rim_mesh.bottom_radius = 0.28
	rim_mesh.height = 0.07
	rim_mesh.radial_segments = 24
	rim.mesh = rim_mesh
	rim.material_override = _wood_material
	rim.position = center
	rim.rotation.x = PI * 0.5
	add_child(rim)

	var face := MeshInstance3D.new()
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.235
	face_mesh.bottom_radius = 0.235
	face_mesh.height = 0.015
	face_mesh.radial_segments = 24
	face.mesh = face_mesh
	face.material_override = _paper_material
	face.position = center + Vector3(0.0, 0.0, 0.045)
	face.rotation.x = PI * 0.5
	add_child(face)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		_append_board(
			_wood_tool,
			center + Vector3(sin(angle) * 0.16, cos(angle) * 0.16, 0.06),
			Vector3.RIGHT.rotated(Vector3.FORWARD, angle),
			0.045,
			0.012,
			0.012
		)
	_append_board(
		_wood_tool,
		center + Vector3(0.045, 0.02, 0.07),
		Vector3.UP,
		0.16,
		0.012,
		0.009
	)
	_append_board(
		_wood_tool,
		center + Vector3(-0.03, -0.045, 0.075),
		Vector3.RIGHT,
		0.11,
		0.012,
		0.009
	)


func _add_picture(center: Vector3) -> void:
	for side in [-1.0, 1.0]:
		_append_board(
			_wood_tool,
			center + Vector3(side * 0.31, 0.0, 0.0),
			Vector3.UP,
			0.75,
			0.065,
			0.07,
			0.012
		)
		_append_board(
			_wood_tool,
			center + Vector3(0.0, side * 0.37, 0.0),
			Vector3.RIGHT,
			0.68,
			0.06,
			0.07,
			0.012
		)
	_append_board(
		_paper_tool,
		center + Vector3(0.0, 0.0, 0.025),
		Vector3.RIGHT,
		0.52,
		0.6,
		0.018,
		0.01,
		0.04
	)
	_append_board(
		_wood_tool,
		center + Vector3(-0.04, -0.02, 0.045),
		Vector3.RIGHT,
		0.13,
		0.15,
		0.01,
		0.008
	)


func _build_firewood(center: Vector3) -> void:
	for row in range(3):
		for index in range(3 - row):
			var start := center + Vector3(-0.34 + float(index) * 0.3, 0.1 + float(row) * 0.17, 0.0)
			var end := start + Vector3(0.62, 0.02 * sin(float(index + row)), 0.02)
			_append_tube(_wood_tool, start, end, 0.085, 0.073, 8)


func _add_door() -> void:
	var door: Node3D = DOOR_SCENE.instantiate() as Node3D
	door.position = Vector3(-0.52, 0.0, WALL_Z + 0.03)
	add_child(door)


func _commit_surfaces() -> void:
	_commit_surface(_stone_tool, _stone_material, "StoneFoundation")
	_commit_surface(_wood_tool, _wood_material, "CabinWoodwork")
	_commit_surface(_roof_tool, _roof_material, "RoofShingles")
	_commit_surface(_fabric_tool, _fabric_material, "WornTextiles")
	_commit_surface(_metal_tool, _metal_material, "OldIronwork")
	_commit_surface(_paper_tool, _paper_material, "PaperAndBookPages")


func _commit_surface(surface: SurfaceTool, material: Material, node_name: String) -> void:
	surface.generate_normals()
	surface.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _build_collisions() -> void:
	_add_static_box(Vector3(0.0, -0.13, 0.0), Vector3(CABIN_WIDTH, 0.26, CABIN_DEPTH))
	_add_static_box(Vector3(-2.0, 1.35, WALL_Z), Vector3(3.0, 2.7, 0.18))
	_add_static_box(Vector3(2.0, 1.35, WALL_Z), Vector3(3.0, 2.7, 0.18))
	_add_static_box(Vector3(0.0, 2.39, WALL_Z), Vector3(1.0, 0.62, 0.18))
	_add_static_box(Vector3(0.0, 1.35, -WALL_Z), Vector3(CABIN_WIDTH, 2.7, 0.18))
	_add_static_box(Vector3(-WALL_X, 1.35, 0.0), Vector3(0.18, 2.7, CABIN_DEPTH))
	_add_static_box(Vector3(WALL_X, 1.35, 0.0), Vector3(0.18, 2.7, CABIN_DEPTH))
	_add_static_box(Vector3(0.0, 3.55, -WALL_Z), Vector3(CABIN_WIDTH, 1.7, 0.14))
	_add_static_box(Vector3(0.0, 3.55, WALL_Z), Vector3(CABIN_WIDTH, 1.7, 0.14))

	var roof_angle: float = atan2(1.8, 3.85)
	for side in [-1.0, 1.0]:
		var position := Vector3(side * 1.925, 3.55, 0.0)
		var slope_collision := _add_static_box(
			position,
			Vector3(4.45, 0.18, CABIN_DEPTH + 0.5)
		)
		slope_collision.rotation.z = -side * roof_angle
	_add_static_box(Vector3(0.8, 0.45, 0.0), Vector3(1.7, 0.9, 0.95))
	_add_static_box(Vector3(-0.2, 0.55, 1.1), Vector3(0.56, 1.1, 0.5))
	_add_static_box(Vector3(1.8, 0.55, 1.1), Vector3(0.56, 1.1, 0.5))
	_add_static_box(Vector3(-2.25, 0.55, -1.3), Vector3(1.5, 1.1, 2.3))
	_add_static_box(Vector3(-2.65, 1.12, 1.6), Vector3(1.3, 2.25, 0.7))
	_add_static_box(Vector3(2.3, 0.8, -1.75), Vector3(0.95, 1.6, 0.9))
	_add_static_box(Vector3(0.2, 1.6, -2.6), Vector3(1.7, 1.25, 0.5))


func _add_static_box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	add_child(body)
	return body


func _add_interaction_areas() -> void:
	_add_interaction_area(
		"TablePapers",
		Vector3(0.9, 1.03, 0.15),
		Vector3(0.78, 0.42, 0.66),
		"Examinar os papéis",
		"Anotações antigas, contas vencidas e uma frase repetida com tanta força que rasgou o papel."
	)
	_add_interaction_area(
		"Stove",
		Vector3(2.3, 0.9, -1.75),
		Vector3(0.95, 1.5, 0.9),
		"Examinar o fogão",
		"O ferro ainda guarda cheiro de cinza fria. Há marcas recentes na porta da fornalha."
	)
	_add_interaction_area(
		"WallClock",
		Vector3(-1.18, 2.04, -2.78),
		Vector3(0.72, 0.72, 0.5),
		"Examinar o relógio",
		"Os ponteiros pararam pouco depois das três. O mecanismo continua fazendo um clique irregular."
	)
	_add_interaction_area(
		"Photograph",
		Vector3(1.45, 1.88, -2.78),
		Vector3(0.8, 0.88, 0.5),
		"Examinar a fotografia",
		"A imagem está desbotada. Uma das pessoas foi riscada até o papel quase desaparecer."
	)
	_add_interaction_area(
		"BedsideBook",
		Vector3(-2.2, 0.95, -0.6),
		Vector3(0.75, 0.5, 0.65),
		"Examinar o livro",
		"Algumas páginas foram arrancadas. As restantes estão inchadas pela umidade."
	)


func _add_interaction_area(
	area_name: String,
	position: Vector3,
	size: Vector3,
	prompt: String,
	description: String
) -> void:
	var area := Area3D.new()
	area.name = area_name
	area.position = position
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_script(INTERACTION_SCRIPT)
	area.set("interaction_prompt", prompt)
	area.set("description", description)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	area.add_child(collision)
	add_child(area)


func _add_cabin_ambience() -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "CabinAmbience"
	var ambience := load("res://assets/audio/cabin_ambience.wav") as AudioStreamWAV
	if ambience == null:
		push_error("Cabin ambience WAV could not be loaded.")
		return
	ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = ambience
	player.volume_db = -21.0
	player.max_distance = 15.0
	player.autoplay = true
	add_child(player)


func _append_board(
	surface: SurfaceTool,
	center: Vector3,
	axis: Vector3,
	length: float,
	height: float,
	depth: float,
	bevel: float = 0.025,
	warp: float = 0.0
) -> void:
	_append_oriented_board(
		surface,
		center,
		_basis_for_x_axis(axis),
		length,
		height,
		depth,
		bevel,
		warp
	)


func _append_oriented_board(
	surface: SurfaceTool,
	center: Vector3,
	orientation: Basis,
	length: float,
	height: float,
	depth: float,
	bevel: float = 0.025,
	warp: float = 0.0
) -> void:
	ProceduralGeometry.append_board(
		surface,
		center,
		orientation,
		length,
		height,
		depth,
		bevel,
		warp
	)


func _append_tube(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	sides: int = 8
) -> void:
	ProceduralGeometry.append_tube(surface, start, end, start_radius, end_radius, sides)


func _basis_for_x_axis(axis: Vector3) -> Basis:
	var x_axis: Vector3 = axis.normalized()
	var reference: Vector3 = Vector3.UP
	if absf(x_axis.dot(reference)) > 0.94:
		reference = Vector3.FORWARD
	var z_axis: Vector3 = x_axis.cross(reference).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _add_triangle(
	surface: SurfaceTool,
	a: Vector3,
	uv_a: Vector2,
	b: Vector3,
	uv_b: Vector2,
	c: Vector3,
	uv_c: Vector2
) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)
