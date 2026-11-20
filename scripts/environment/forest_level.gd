extends Node3D

const CABIN_SCENE: PackedScene = preload("res://scenes/environment/abandoned_cabin.tscn")

const TERRAIN_SIZE: float = 96.0
const TERRAIN_CELLS: int = 64
const TREE_TARGET: int = 165
const GRASS_TARGET: int = 1350
const SHRUB_TARGET: int = 125
const ROCK_TARGET: int = 64
const GROUND_FOG_COUNT: int = 36
const GROUND_FOG_HEIGHT: float = 0.6
const GROUND_FOG_UPDATE_INTERVAL: float = 0.12
const TREE_LEAF_TEXTURE: Texture2D = preload("res://assets/textures/tree_leaf_branch.png")
const GRASS_FLOOR_TEXTURE: Texture2D = preload("res://assets/textures/grass_floor.png")
const GROUND_FOG_SHADER: Shader = preload("res://assets/shaders/ground_fog.gdshader")

var _random := RandomNumberGenerator.new()
var _terrain_noise := FastNoiseLite.new()
var _tree_trunk_meshes: Array[ArrayMesh] = []
var _tree_foliage_meshes: Array[ArrayMesh] = []
var _trees: Array[Dictionary] = []
var _tree_transforms: Array = [[], [], []]
var _grass_transforms: Array[Transform3D] = []
var _dry_grass_transforms: Array[Transform3D] = []
var _shrub_transforms: Array = [[], [], []]
var _rock_transforms: Array = [[], [], []]
var _rock_collision_data: Array[Dictionary] = []
var _log_collision_data: Array[Dictionary] = []
var _ground_material: StandardMaterial3D
var _bark_material: StandardMaterial3D
var _foliage_materials: Array[StandardMaterial3D] = []
var _rock_materials: Array[StandardMaterial3D] = []
var _grass_material: StandardMaterial3D
var _tree_collision_count: int = 0
var _wind_player: AudioStreamPlayer
var _ground_fog_multimesh: MultiMesh
var _ground_fog_positions: Array[Vector3] = []
var _ground_fog_velocities: Array[Vector2] = []
var _ground_fog_rotations: Array[float] = []
var _ground_fog_scales: Array[float] = []
var _ground_fog_update_timer: float = 0.0


func _ready() -> void:
	_random.seed = 187351
	_terrain_noise.seed = 73191
	_terrain_noise.frequency = 0.023
	_terrain_noise.fractal_octaves = 3
	_terrain_noise.fractal_gain = 0.53
	_terrain_noise.fractal_lacunarity = 2.1
	_create_materials()
	_create_atmosphere()
	_build_terrain()
	_create_ground_fog()
	_add_cabin()
	_build_tree_meshes()
	_scatter_trees()
	_build_shrub_meshes()
	_scatter_ground_cover()
	_scatter_rocks()
	_scatter_fallen_logs()
	_add_ambient_audio()
	_add_play_area_boundary()


func _process(delta: float) -> void:
	_update_ground_fog(delta)
	if _wind_player == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var inside_cabin: bool = (
		absf(player.global_position.x) < 3.35
		and player.global_position.z > -2.85
		and player.global_position.z < 2.85
		and player.global_position.y < 3.0
	)
	var target_volume: float = -34.0 if inside_cabin else -16.0
	_wind_player.volume_db = move_toward(_wind_player.volume_db, target_volume, 12.0 * delta)


func _create_materials() -> void:
	_ground_material = WorldMaterials.create("earth", Color(0.82, 0.79, 0.7), 0.98, 5.0, 0.36)
	_ground_material.albedo_texture = GRASS_FLOOR_TEXTURE
	_ground_material.albedo_color = Color.WHITE
	_ground_material.normal_enabled = false
	_bark_material = WorldMaterials.create("bark", Color(0.76, 0.73, 0.67), 0.98, 1.0, 0.42)
	_grass_material = WorldMaterials.create("foliage", Color(0.68, 0.75, 0.55), 0.97, 2.0, 0.32)
	_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_foliage_materials = [
		WorldMaterials.create("foliage", Color(0.62, 0.75, 0.52), 0.96, 2.0, 0.38),
		WorldMaterials.create("foliage", Color(0.47, 0.62, 0.43), 0.98, 2.0, 0.4),
		WorldMaterials.create("foliage", Color(0.71, 0.78, 0.58), 0.96, 2.0, 0.38)
	]
	for rock_material in _rock_materials:
		rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for foliage_material in _foliage_materials:
		foliage_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		foliage_material.albedo_texture = TREE_LEAF_TEXTURE
		foliage_material.uv1_scale = Vector3.ONE
		foliage_material.normal_enabled = false
		foliage_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		foliage_material.alpha_scissor_threshold = 0.35
	_rock_materials = [
		WorldMaterials.create("stone", Color(0.82, 0.84, 0.8), 0.98, 1.0, 0.42),
		WorldMaterials.create("stone", Color(0.69, 0.72, 0.68), 0.98, 1.0, 0.42),
		WorldMaterials.create("stone", Color(0.91, 0.87, 0.76), 0.98, 1.0, 0.42)
	]


func _create_atmosphere() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.34, 0.4, 0.44)
	sky_material.sky_horizon_color = Color(0.57, 0.61, 0.62)
	sky_material.ground_bottom_color = Color(0.12, 0.15, 0.15)
	sky_material.ground_horizon_color = Color(0.4, 0.44, 0.43)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.58, 0.61)
	environment.ambient_light_energy = 0.68
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.67, 0.69)
	environment.fog_density = 0.022
	environment.fog_sky_affect = 0.58
	environment.fog_aerial_perspective = 0.18
	world_environment.environment = environment
	add_child(world_environment)

	var daylight := DirectionalLight3D.new()
	daylight.name = "OvercastDaylight"
	daylight.rotation_degrees = Vector3(-38.0, -31.0, 0.0)
	daylight.light_color = Color(0.79, 0.84, 0.86)
	daylight.light_energy = 0.82
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 55.0
	daylight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(daylight)


func _create_ground_fog() -> void:
	var fog_material := ShaderMaterial.new()
	fog_material.shader = GROUND_FOG_SHADER
	fog_material.set_shader_parameter("fog_color", Color(0.72, 0.78, 0.79))
	fog_material.set_shader_parameter("opacity", 0.6)

	var fog_mesh := QuadMesh.new()
	fog_mesh.size = Vector2(20.0, GROUND_FOG_HEIGHT)
	fog_mesh.material = fog_material

	_ground_fog_multimesh = MultiMesh.new()
	_ground_fog_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_ground_fog_multimesh.mesh = fog_mesh
	_ground_fog_multimesh.instance_count = GROUND_FOG_COUNT
	_ground_fog_multimesh.custom_aabb = AABB(
		Vector3(-65.0, -3.0, -65.0),
		Vector3(130.0, 8.0, 130.0)
	)

	var fog_instance := MultiMeshInstance3D.new()
	fog_instance.name = "LowMovingFog"
	fog_instance.multimesh = _ground_fog_multimesh
	fog_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fog_instance)

	var half_size: float = TERRAIN_SIZE * 0.5
	for index in range(GROUND_FOG_COUNT):
		var x: float = _random.randf_range(-half_size, half_size)
		var z: float = _random.randf_range(-half_size, half_size)
		var angle: float = _random.randf_range(0.0, TAU)
		var speed: float = _random.randf_range(0.25, 0.72)
		var position := Vector3(x, _height_at(x, z) + GROUND_FOG_HEIGHT * 0.5, z)
		_ground_fog_positions.append(position)
		_ground_fog_velocities.append(Vector2(cos(angle), sin(angle)) * speed)
		_ground_fog_rotations.append(_random.randf_range(0.0, TAU))
		_ground_fog_scales.append(_random.randf_range(0.8, 1.45))
		_update_ground_fog_transform(index)


func _update_ground_fog(delta: float) -> void:
	if _ground_fog_multimesh == null:
		return
	_ground_fog_update_timer += delta
	if _ground_fog_update_timer < GROUND_FOG_UPDATE_INTERVAL:
		return

	var movement_delta: float = _ground_fog_update_timer
	_ground_fog_update_timer = 0.0
	var half_size: float = TERRAIN_SIZE * 0.5
	for index in range(GROUND_FOG_COUNT):
		var position: Vector3 = _ground_fog_positions[index]
		var velocity: Vector2 = _ground_fog_velocities[index]
		position.x = wrapf(position.x + velocity.x * movement_delta, -half_size, half_size)
		position.z = wrapf(position.z + velocity.y * movement_delta, -half_size, half_size)
		position.y = _height_at(position.x, position.z) + GROUND_FOG_HEIGHT * 0.5
		_ground_fog_positions[index] = position
		_update_ground_fog_transform(index)


func _update_ground_fog_transform(index: int) -> void:
	var basis := Basis(Vector3.UP, _ground_fog_rotations[index])
	basis = basis.scaled(Vector3(_ground_fog_scales[index], 1.0, 1.0))
	_ground_fog_multimesh.set_instance_transform(
		index,
		Transform3D(basis, _ground_fog_positions[index])
	)


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_size: float = TERRAIN_SIZE * 0.5
	var vertex_count: int = TERRAIN_CELLS + 1
	for z_index in range(vertex_count):
		var z: float = -half_size + float(z_index) * TERRAIN_SIZE / TERRAIN_CELLS
		for x_index in range(vertex_count):
			var x: float = -half_size + float(x_index) * TERRAIN_SIZE / TERRAIN_CELLS
			surface.set_uv(Vector2(x / 8.0, z / 8.0))
			surface.add_vertex(Vector3(x, _height_at(x, z), z))

	for z_index in range(TERRAIN_CELLS):
		for x_index in range(TERRAIN_CELLS):
			var a: int = z_index * vertex_count + x_index
			var b: int = a + 1
			var c: int = a + vertex_count
			var d: int = c + 1
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(b)
			surface.add_index(d)
			surface.add_index(c)

	surface.generate_normals()
	surface.generate_tangents()
	var terrain := MeshInstance3D.new()
	terrain.name = "UnevenForestFloor"
	terrain.mesh = surface.commit()
	terrain.material_override = _ground_material
	add_child(terrain)

	var ground_body := StaticBody3D.new()
	ground_body.name = "TerrainCollision"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 1
	var ground_collision := CollisionShape3D.new()
	ground_collision.shape = terrain.mesh.create_trimesh_shape()
	if ground_collision.shape == null:
		push_error("Could not create collision shape for the forest terrain.")
		return
	ground_body.add_child(ground_collision)
	add_child(ground_body)


func _height_at(x: float, z: float) -> float:
	var falloff: float = clampf(Vector2(x, z).length() / 8.0, 0.0, 1.0)
	falloff *= clampf(maxf(absf(x) - 4.0, absf(z) - 3.2) / 5.0, 0.0, 1.0)
	if absf(x) < 3.2 and z > 2.0 and z < 15.0:
		falloff *= clampf(absf(x) / 3.2, 0.0, 1.0)
	var broad: float = _terrain_noise.get_noise_2d(x, z)
	var detail: float = _terrain_noise.get_noise_2d(x * 2.5 + 71.0, z * 2.5 - 39.0)
	return falloff * (broad * 1.05 + detail * 0.16)


func _add_cabin() -> void:
	var cabin: Node3D = CABIN_SCENE.instantiate() as Node3D
	cabin.name = "AbandonedTimberCabin"
	add_child(cabin)


func _build_tree_meshes() -> void:
	for variant in range(3):
		var trunk := SurfaceTool.new()
		var needles := SurfaceTool.new()
		trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
		needles.begin(Mesh.PRIMITIVE_TRIANGLES)
		var shape_random := RandomNumberGenerator.new()
		shape_random.seed = 48381 + variant * 7919
		var height: float = 10.5 + float(variant) * 1.25
		var lean: float = 0.12 + float(variant) * 0.035
		var previous := Vector3.ZERO
		for segment in range(9):
			var t: float = float(segment) / 8.0
			var next_t: float = float(segment + 1) / 8.0
			var center_a := Vector3(sin(t * 2.3 + float(variant)) * lean * t, t * height, cos(t * 1.7) * lean * 0.5 * t)
			var center_b := Vector3(sin(next_t * 2.3 + float(variant)) * lean * next_t, next_t * height, cos(next_t * 1.7) * lean * 0.5 * next_t)
			var radius_a: float = lerpf(0.28, 0.045, t)
			var radius_b: float = lerpf(0.28, 0.045, next_t)
			ProceduralGeometry.append_tube(trunk, center_a, center_b, radius_a, radius_b, 9)
			previous = center_b

		for root_index in range(5):
			var root_angle: float = TAU * float(root_index) / 5.0
			var root_direction := Vector3(cos(root_angle), 0.0, sin(root_angle))
			ProceduralGeometry.append_tube(
				trunk,
				Vector3(0.0, 0.24, 0.0),
				root_direction * (0.55 + float(variant) * 0.08) + Vector3.UP * 0.025,
				0.15,
				0.035,
				6
			)

		var tier_count: int = 8 + variant
		for tier in range(tier_count):
			var t: float = float(tier) / tier_count
			var y: float = height * (0.23 + t * 0.66) + shape_random.randf_range(
				-height * 0.012,
				height * 0.012
			)
			var crown_radius: float = (
				(1.0 - t) * (2.05 + float(variant) * 0.18) + 0.22
			) * shape_random.randf_range(0.82, 1.18)
			var branch_count: int = shape_random.randi_range(4, 7)
			var ring_rotation: float = shape_random.randf_range(-0.32, 0.32)
			for branch in range(branch_count):
				var angle: float = (
					TAU * float(branch) / branch_count
					+ float(tier % 2) * 0.36
					+ ring_rotation
					+ shape_random.randf_range(-0.18, 0.18)
				)
				var direction := Vector3(
					cos(angle),
					shape_random.randf_range(-0.12, 0.18),
					sin(angle)
				).normalized()
				var start := Vector3(
					sin(y / height * 2.3 + float(variant)) * lean * y / height
						+ shape_random.randf_range(-0.08, 0.08),
					y,
					cos(y / height * 1.7) * lean * 0.5 * y / height
						+ shape_random.randf_range(-0.08, 0.08)
				)
				var branch_length: float = crown_radius * shape_random.randf_range(0.68, 1.24)
				var end := (
					start
					+ direction * branch_length
					+ Vector3.UP * shape_random.randf_range(-0.08, 0.3)
				)
				ProceduralGeometry.append_tube(
					trunk,
					start,
					end,
					0.075 * (1.0 - t * 0.45),
					0.018,
					5
				)
				var cluster_start: Vector3 = start.lerp(end, shape_random.randf_range(0.3, 0.46))
				var cluster_end: Vector3 = (
					end
					+ direction * shape_random.randf_range(0.08, 0.3)
					+ Vector3.UP * shape_random.randf_range(0.02, 0.22)
				)
				_append_needle_cluster(
					needles,
					cluster_start,
					cluster_end,
					(crown_radius * 0.42 + 0.12) * shape_random.randf_range(0.72, 1.18),
					shape_random.randi_range(4, 7)
				)
				_append_needle_cluster(
					needles,
					start.lerp(end, shape_random.randf_range(0.52, 0.72)),
					end
						+ direction * shape_random.randf_range(0.04, 0.2)
						+ Vector3.UP * shape_random.randf_range(0.06, 0.28),
					(crown_radius * 0.28 + 0.08) * shape_random.randf_range(0.7, 1.25),
					shape_random.randi_range(4, 6)
				)
		for crown_spray in range(3):
			var top_base := Vector3(
				shape_random.randf_range(-0.22, 0.22),
				height * shape_random.randf_range(0.68, 0.82),
				shape_random.randf_range(-0.22, 0.22)
			)
			var top_tip := top_base + Vector3(
				shape_random.randf_range(-0.26, 0.26),
				height * shape_random.randf_range(0.12, 0.22),
				shape_random.randf_range(-0.26, 0.26)
			)
			_append_needle_cluster(
				needles,
				top_base,
				top_tip,
				shape_random.randf_range(0.24, 0.46),
				shape_random.randi_range(4, 7)
			)
		trunk.generate_normals()
		trunk.generate_tangents()
		needles.generate_normals()
		needles.generate_tangents()
		_tree_trunk_meshes.append(trunk.commit())
		_tree_foliage_meshes.append(needles.commit())


func _append_needle_cluster(
	surface: SurfaceTool,
	base: Vector3,
	tip: Vector3,
	radius: float,
	sides: int
) -> void:
	var axis: Vector3 = (tip - base).normalized()
	var reference: Vector3 = Vector3.UP
	if absf(axis.dot(reference)) > 0.9:
		reference = Vector3.RIGHT
	var side_axis: Vector3 = axis.cross(reference).normalized()
	var front_axis: Vector3 = axis.cross(side_axis).normalized()
	var center_radius: float = radius * 0.56
	var shape_random := RandomNumberGenerator.new()
	shape_random.seed = int(
		absf(
			base.x * 127.1
			+ base.y * 311.7
			+ base.z * 74.7
			+ tip.x * 269.5
			+ tip.y * 183.3
			+ tip.z * 246.1
			+ radius * 719.0
		)
		* 10000.0
	)
	for side in range(sides):
		var next_side: int = (side + 1) % sides
		var angle_a: float = TAU * float(side) / sides + shape_random.randf_range(-0.14, 0.14)
		var angle_b: float = (
			TAU * float(next_side) / sides + shape_random.randf_range(-0.14, 0.14)
		)
		var radial_a: Vector3 = side_axis * cos(angle_a) + front_axis * sin(angle_a)
		var radial_b: Vector3 = side_axis * cos(angle_b) + front_axis * sin(angle_b)
		var base_a: Vector3 = base + radial_a * radius * shape_random.randf_range(0.58, 1.28)
		var base_b: Vector3 = base + radial_b * radius * shape_random.randf_range(0.58, 1.28)
		var shoulder_t_a: float = shape_random.randf_range(0.42, 0.76)
		var shoulder_t_b: float = shape_random.randf_range(0.42, 0.76)
		var shoulder_a: Vector3 = (
			base.lerp(tip, shoulder_t_a)
			+ radial_a * center_radius * shape_random.randf_range(0.55, 1.32)
		)
		var shoulder_b: Vector3 = (
			base.lerp(tip, shoulder_t_b)
			+ radial_b * center_radius * shape_random.randf_range(0.55, 1.32)
		)
		_add_triangle(surface, base_a, Vector2.ZERO, shoulder_a, Vector2.UP, base_b, Vector2.RIGHT)
		_add_triangle(surface, base_b, Vector2.ZERO, shoulder_a, Vector2.UP, shoulder_b, Vector2.RIGHT)
		_add_triangle(surface, shoulder_a, Vector2.ZERO, tip, Vector2.UP, shoulder_b, Vector2.RIGHT)


func _scatter_trees() -> void:
	var attempts: int = 0
	while _trees.size() < TREE_TARGET and attempts < TREE_TARGET * 45:
		attempts += 1
		var x: float = _random.randf_range(-43.0, 43.0)
		var z: float = _random.randf_range(-43.0, 43.0)
		if Vector2(x, z).length() < 7.0:
			continue
		if absf(x) < 3.7 and z > 2.0 and z < 15.5:
			continue
		var too_close: bool = false
		for tree in _trees:
			var existing: Vector3 = tree["position"]
			if Vector2(x - existing.x, z - existing.z).length_squared() < 11.5:
				too_close = true
				break
		if too_close:
			continue
		var variant: int = _random.randi_range(0, 2)
		var scale: float = _random.randf_range(0.82, 1.2)
		var tree_data := {
			"position": Vector3(x, _height_at(x, z), z),
			"variant": variant,
			"scale": scale,
			"rotation": _random.randf_range(0.0, TAU)
		}
		_trees.append(tree_data)
		var basis := Basis(Vector3.UP, tree_data["rotation"]).scaled(Vector3.ONE * scale)
		_tree_transforms[variant].append(Transform3D(basis, tree_data["position"]))

	for variant in range(3):
		_add_multimesh(
			_tree_trunk_meshes[variant],
			_bark_material,
			_tree_transforms[variant],
			"Trunks_%d" % variant,
			true
		)
		_add_multimesh(
			_tree_foliage_meshes[variant],
			_foliage_materials[variant],
			_tree_transforms[variant],
			"NeedleCanopies_%d" % variant,
			true
		)
	_add_tree_collisions()


func _add_tree_collisions() -> void:
	for tree in _trees:
		var position: Vector3 = tree["position"]
		if Vector2(position.x, position.z).length() > 35.0:
			continue
		var scale: float = tree["scale"]
		var variant: int = tree["variant"]
		var tree_height: float = (10.5 + float(variant) * 1.25) * scale
		var body := StaticBody3D.new()
		body.name = "TreeTrunkCollision"
		body.position = position
		var collision := CollisionShape3D.new()
		collision.position.y = tree_height * 0.5
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.26 * scale
		capsule.height = tree_height
		collision.shape = capsule
		body.add_child(collision)
		add_child(body)
		_tree_collision_count += 1


func _build_shrub_meshes() -> void:
	for variant in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 941 + variant * 73
		for leaf_index in range(9 + variant):
			var angle: float = TAU * float(leaf_index) / (9.0 + float(variant))
			var radius: float = rng.randf_range(0.18, 0.48)
			var base := Vector3(cos(angle) * radius * 0.7, 0.0, sin(angle) * radius * 0.7)
			var tip := Vector3(cos(angle) * radius, rng.randf_range(0.3, 0.85), sin(angle) * radius)
			_append_needle_cluster(surface, base, tip, rng.randf_range(0.18, 0.34), 5)
		surface.generate_normals()
		surface.generate_tangents()
		_tree_foliage_meshes.append(surface.commit())
		_shrub_transforms[variant] = _make_shrub_transforms(variant)
		_add_multimesh(
			_tree_foliage_meshes[3 + variant],
			_foliage_materials[variant],
			_shrub_transforms[variant],
			"UnderstoryShrubs_%d" % variant,
			false
		)


func _make_shrub_transforms(variant: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for index in range(int(SHRUB_TARGET / 3)):
		var x: float = _random.randf_range(-44.0, 44.0)
		var z: float = _random.randf_range(-44.0, 44.0)
		if _is_clear_path(x, z, 2.7) or Vector2(x, z).length() < 5.5:
			continue
		if (index + variant) % 4 == 0:
			continue
		var scale: float = _random.randf_range(0.7, 1.45)
		var y: float = _height_at(x, z)
		var basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
			Vector3(scale, scale * _random.randf_range(0.8, 1.25), scale)
		)
		transforms.append(Transform3D(basis, Vector3(x, y, z)))
	return transforms


func _scatter_ground_cover() -> void:
	var grass_mesh := _build_grass_mesh()
	for index in range(GRASS_TARGET):
		var x: float = _random.randf_range(-45.0, 45.0)
		var z: float = _random.randf_range(-45.0, 45.0)
		if _is_clear_path(x, z, 3.0):
			continue
		if Vector2(x, z).length() < 5.0 and _random.randf() > 0.22:
			continue
		var scale: float = _random.randf_range(0.55, 1.5)
		var height_scale: float = _random.randf_range(0.65, 1.55)
		var basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
			Vector3(scale, scale * height_scale, scale)
		)
		_grass_transforms.append(Transform3D(basis, Vector3(x, _height_at(x, z), z)))
	_add_multimesh(grass_mesh, _grass_material, _grass_transforms, "ForestGrass", false)

	var leaf_mesh := _build_leaf_mesh()
	var leaf_material := WorldMaterials.create("foliage", Color(0.36, 0.28, 0.19), 1.0, 1.0, 0.12)
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_transforms: Array[Transform3D] = []
	for index in range(430):
		var x: float = _random.randf_range(-44.0, 44.0)
		var z: float = _random.randf_range(-44.0, 44.0)
		if _is_clear_path(x, z, 1.2):
			continue
		var scale: float = _random.randf_range(0.45, 1.4)
		var basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
			Vector3(scale, scale, scale * 0.65)
		)
		leaf_transforms.append(
			Transform3D(basis, Vector3(x, _height_at(x, z) + 0.015, z))
		)
	_add_multimesh(leaf_mesh, leaf_material, leaf_transforms, "WindblownLeaves", false)
	_scatter_dead_grass(grass_mesh)


func _scatter_dead_grass(grass_mesh: ArrayMesh) -> void:
	var dry_material := WorldMaterials.create("foliage", Color(0.48, 0.43, 0.31), 0.99, 2.0, 0.24)
	dry_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for patch in range(8):
		var center_x: float = _random.randf_range(-32.0, 32.0)
		var center_z: float = _random.randf_range(-34.0, 34.0)
		if Vector2(center_x, center_z).length() < 7.0 or _is_clear_path(center_x, center_z, 5.0):
			continue
		for blade in range(36):
			var x: float = center_x + _random.randf_range(-2.2, 2.2)
			var z: float = center_z + _random.randf_range(-2.2, 2.2)
			if _is_clear_path(x, z, 2.5):
				continue
			var scale: float = _random.randf_range(0.75, 1.65)
			var basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
				Vector3(scale, scale * _random.randf_range(0.7, 1.25), scale)
			)
			_dry_grass_transforms.append(
				Transform3D(basis, Vector3(x, _height_at(x, z), z))
			)
	_add_multimesh(grass_mesh, dry_material, _dry_grass_transforms, "DeadGrassPatches", false)


func _build_grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(6):
		var angle: float = TAU * float(blade) / 6.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x) * _random.randf_range(0.035, 0.065)
		var height: float = _random.randf_range(0.24, 0.55)
		var lean: Vector3 = direction * _random.randf_range(0.05, 0.22)
		var base := direction * _random.randf_range(0.0, 0.08)
		var tip := base + Vector3.UP * height + lean
		var left := base - side
		var right := base + side
		_add_triangle(surface, left, Vector2.ZERO, tip, Vector2.UP, right, Vector2.RIGHT)
		_add_triangle(surface, right, Vector2.ZERO, tip, Vector2.UP, left, Vector2.RIGHT)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _build_leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var point_a := Vector3(-0.15, 0.0, 0.0)
	var point_b := Vector3(0.0, 0.0, 0.055)
	var point_c := Vector3(0.18, 0.0, 0.0)
	var point_d := Vector3(0.0, 0.0, -0.055)
	var center := Vector3(0.02, 0.012, 0.0)
	_add_triangle(surface, point_a, Vector2.ZERO, center, Vector2(0.5, 0.5), point_b, Vector2.UP)
	_add_triangle(surface, point_b, Vector2.ZERO, center, Vector2(0.5, 0.5), point_c, Vector2.RIGHT)
	_add_triangle(surface, point_c, Vector2.ZERO, center, Vector2(0.5, 0.5), point_d, Vector2.DOWN)
	_add_triangle(surface, point_d, Vector2.ZERO, center, Vector2(0.5, 0.5), point_a, Vector2.LEFT)
	_add_triangle(surface, point_b, Vector2.ZERO, center, Vector2(0.5, 0.5), point_a, Vector2.UP)
	_add_triangle(surface, point_c, Vector2.ZERO, center, Vector2(0.5, 0.5), point_b, Vector2.RIGHT)
	_add_triangle(surface, point_d, Vector2.ZERO, center, Vector2(0.5, 0.5), point_c, Vector2.DOWN)
	_add_triangle(surface, point_a, Vector2.ZERO, center, Vector2(0.5, 0.5), point_d, Vector2.LEFT)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _scatter_rocks() -> void:
	var meshes: Array[ArrayMesh] = []
	for variant in range(3):
		meshes.append(_build_rock_mesh(variant))
	for index in range(ROCK_TARGET):
		var x: float = _random.randf_range(-43.0, 43.0)
		var z: float = _random.randf_range(-43.0, 43.0)
		if Vector2(x, z).length() < 5.5 or _is_clear_path(x, z, 2.5):
			continue
		var variant: int = index % 3
		var scale: float = _random.randf_range(0.22, 0.9)
		var basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
			Vector3(scale * _random.randf_range(0.9, 1.3), scale * 0.62, scale)
		)
		_rock_transforms[variant].append(
			Transform3D(basis, Vector3(x, _height_at(x, z) + scale * 0.24, z))
		)
		if scale > 0.48:
			_rock_collision_data.append({
				"position": Vector3(x, _height_at(x, z) + scale * 0.3, z),
				"radius": scale * 0.58
			})
	for variant in range(3):
		_add_multimesh(
			meshes[variant],
			_rock_materials[variant],
			_rock_transforms[variant],
			"WeatheredRocks_%d" % variant,
			false
		)
	_add_rock_collisions()


func _add_rock_collisions() -> void:
	for rock_data in _rock_collision_data:
		var body := StaticBody3D.new()
		body.name = "RockCollision"
		body.position = rock_data["position"]
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = rock_data["radius"]
		collision.shape = sphere
		body.add_child(collision)
		add_child(body)


func _build_rock_mesh(variant: int) -> ArrayMesh:
	var size: float = 0.95 + float(variant) * 0.08
	var x: float = 0.525731
	var z: float = 0.850651
	var vertices: Array[Vector3] = [
		Vector3(-x, 0.0, z), Vector3(x, 0.0, z), Vector3(-x, 0.0, -z), Vector3(x, 0.0, -z),
		Vector3(0.0, z, x), Vector3(0.0, z, -x), Vector3(0.0, -z, x), Vector3(0.0, -z, -x),
		Vector3(z, x, 0.0), Vector3(-z, x, 0.0), Vector3(z, -x, 0.0), Vector3(-z, -x, 0.0)
	]
	var faces: Array[Vector3i] = [
		Vector3i(0, 4, 1), Vector3i(0, 9, 4), Vector3i(9, 5, 4), Vector3i(4, 5, 8),
		Vector3i(4, 8, 1), Vector3i(8, 10, 1), Vector3i(8, 3, 10), Vector3i(5, 3, 8),
		Vector3i(5, 2, 3), Vector3i(2, 7, 3), Vector3i(7, 10, 3), Vector3i(7, 6, 10),
		Vector3i(7, 11, 6), Vector3i(11, 0, 6), Vector3i(0, 1, 6), Vector3i(6, 1, 10),
		Vector3i(9, 0, 11), Vector3i(9, 11, 2), Vector3i(9, 2, 5), Vector3i(7, 2, 11)
	]
	for iteration in range(2):
		var midpoint_cache: Dictionary = {}
		var subdivided: Array[Vector3i] = []
		for face in faces:
			var ab: int = _midpoint_index(face.x, face.y, vertices, midpoint_cache)
			var bc: int = _midpoint_index(face.y, face.z, vertices, midpoint_cache)
			var ca: int = _midpoint_index(face.z, face.x, vertices, midpoint_cache)
			subdivided.append(Vector3i(face.x, ab, ca))
			subdivided.append(Vector3i(face.y, bc, ab))
			subdivided.append(Vector3i(face.z, ca, bc))
			subdivided.append(Vector3i(ab, bc, ca))
		faces = subdivided

	var rng := RandomNumberGenerator.new()
	rng.seed = 199 + variant * 83
	for index in range(vertices.size()):
		var point: Vector3 = vertices[index].normalized()
		var irregularity: Vector3 = Vector3(
			rng.randf_range(0.82, 1.16),
			rng.randf_range(0.72, 1.16),
			rng.randf_range(0.8, 1.18)
		)
		vertices[index] = point * irregularity * size

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face.x]
		var b: Vector3 = vertices[face.y]
		var c: Vector3 = vertices[face.z]
		_add_triangle(surface, a, Vector2.ZERO, b, Vector2.UP, c, Vector2.RIGHT)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _midpoint_index(
	a: int,
	b: int,
	vertices: Array[Vector3],
	cache: Dictionary
) -> int:
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	var key: String = "%d:%d" % [low, high]
	if cache.has(key):
		return cache[key]
	var midpoint: Vector3 = (vertices[a] + vertices[b]).normalized()
	var index: int = vertices.size()
	vertices.append(midpoint)
	cache[key] = index
	return index


func _scatter_fallen_logs() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log_count: int = 14
	for index in range(log_count):
		var x: float = _random.randf_range(-36.0, 36.0)
		var z: float = _random.randf_range(-36.0, 36.0)
		if Vector2(x, z).length() < 8.0 or _is_clear_path(x, z, 4.0):
			continue
		var angle: float = _random.randf_range(0.0, TAU)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var start := Vector3(x, _height_at(x, z) + 0.16, z)
		var length: float = _random.randf_range(1.6, 3.8)
		var end := start + direction * length + Vector3.UP * _random.randf_range(-0.08, 0.08)
		ProceduralGeometry.append_tube(
			surface,
			start,
			end,
			_random.randf_range(0.14, 0.23),
			0.11,
			8
		)
		_log_collision_data.append({
			"center": start.lerp(end, 0.5),
			"direction": direction,
			"length": length
		})
		_append_needle_cluster(
			surface,
			start + Vector3.UP * 0.15,
			start + Vector3.UP * 0.42,
			0.055,
			4
		)
	surface.generate_normals()
	surface.generate_tangents()
	var logs := MeshInstance3D.new()
	logs.name = "FallenTimber"
	logs.mesh = surface.commit()
	logs.material_override = _bark_material
	add_child(logs)
	_add_log_collisions()


func _add_log_collisions() -> void:
	for log_data in _log_collision_data:
		var body := StaticBody3D.new()
		body.name = "FallenLogCollision"
		body.position = log_data["center"]
		var direction: Vector3 = log_data["direction"]
		body.rotation.y = -atan2(direction.z, direction.x)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(log_data["length"], 0.3, 0.3)
		collision.shape = box
		body.add_child(collision)
		add_child(body)


func _add_multimesh(
	mesh: Mesh,
	material: Material,
	transforms: Array,
	node_name: String,
	casts_shadows: bool
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = 82.0
	instance.visibility_range_end_margin = 8.0
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if casts_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	instance.custom_aabb = AABB(Vector3(-48.0, -2.0, -48.0), Vector3(96.0, 22.0, 96.0))
	add_child(instance)


func _is_clear_path(x: float, z: float, width: float) -> bool:
	if Vector2(x, z).length() < 5.2:
		return true
	return absf(x) < width and z > 2.0 and z < 15.0


func _add_ambient_audio() -> void:
	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "ForestWind"
	var wind := load("res://assets/audio/forest_wind.wav") as AudioStreamWAV
	if wind == null:
		push_error("Forest wind WAV could not be loaded.")
		return
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_wind_player.stream = wind
	_wind_player.volume_db = -16.0
	_wind_player.autoplay = true
	add_child(_wind_player)


func _add_play_area_boundary() -> void:
	var wall_thickness: float = 1.2
	var wall_height: float = 9.0
	for side in [-1.0, 1.0]:
		var boundary_x := StaticBody3D.new()
		boundary_x.position = Vector3(side * (TERRAIN_SIZE * 0.5 - 0.3), wall_height * 0.5 - 1.0, 0.0)
		var shape_x := CollisionShape3D.new()
		var box_x := BoxShape3D.new()
		box_x.size = Vector3(wall_thickness, wall_height, TERRAIN_SIZE)
		shape_x.shape = box_x
		boundary_x.add_child(shape_x)
		add_child(boundary_x)

		var boundary_z := StaticBody3D.new()
		boundary_z.position = Vector3(0.0, wall_height * 0.5 - 1.0, side * (TERRAIN_SIZE * 0.5 - 0.3))
		var shape_z := CollisionShape3D.new()
		var box_z := BoxShape3D.new()
		box_z.size = Vector3(TERRAIN_SIZE, wall_height, wall_thickness)
		shape_z.shape = box_z
		boundary_z.add_child(shape_z)
		add_child(boundary_z)


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
