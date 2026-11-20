class_name ProceduralGeometry
extends RefCounted


static func append_board(
	surface: SurfaceTool,
	center: Vector3,
	orientation: Basis,
	length: float,
	height: float,
	depth: float,
	bevel: float = 0.025,
	warp: float = 0.0
) -> void:
	var half_height: float = height * 0.5
	var half_depth: float = depth * 0.5
	var edge: float = minf(bevel, minf(half_height, half_depth) * 0.45)
	var cross_section: Array[Vector2] = [
		Vector2(-half_height + edge, -half_depth),
		Vector2(half_height - edge, -half_depth),
		Vector2(half_height, -half_depth + edge),
		Vector2(half_height, half_depth - edge),
		Vector2(half_height - edge, half_depth),
		Vector2(-half_height + edge, half_depth),
		Vector2(-half_height, half_depth - edge),
		Vector2(-half_height, -half_depth + edge)
	]
	var segments: int = 4
	for segment in range(segments):
		var start_t: float = float(segment) / segments
		var end_t: float = float(segment + 1) / segments
		for side in range(cross_section.size()):
			var next_side: int = (side + 1) % cross_section.size()
			var a: Vector3 = _board_vertex(
				center, orientation, length, start_t, cross_section[side], warp
			)
			var b: Vector3 = _board_vertex(
				center, orientation, length, start_t, cross_section[next_side], warp
			)
			var c: Vector3 = _board_vertex(
				center, orientation, length, end_t, cross_section[next_side], warp
			)
			var d: Vector3 = _board_vertex(
				center, orientation, length, end_t, cross_section[side], warp
			)
			var uv_a := Vector2(float(side) / 8.0, start_t * length)
			var uv_b := Vector2(float(next_side) / 8.0, start_t * length)
			var uv_c := Vector2(float(next_side) / 8.0, end_t * length)
			var uv_d := Vector2(float(side) / 8.0, end_t * length)
			_add_triangle(surface, a, uv_a, b, uv_b, c, uv_c)
			_add_triangle(surface, a, uv_a, c, uv_c, d, uv_d)

	for side in range(1, cross_section.size() - 1):
		var start_center: Vector3 = _board_vertex(
			center, orientation, length, 0.0, Vector2.ZERO, warp
		)
		var end_center: Vector3 = _board_vertex(
			center, orientation, length, 1.0, Vector2.ZERO, warp
		)
		var start_a: Vector3 = _board_vertex(
			center, orientation, length, 0.0, cross_section[side], warp
		)
		var start_b: Vector3 = _board_vertex(
			center, orientation, length, 0.0, cross_section[side + 1], warp
		)
		var end_a: Vector3 = _board_vertex(
			center, orientation, length, 1.0, cross_section[side], warp
		)
		var end_b: Vector3 = _board_vertex(
			center, orientation, length, 1.0, cross_section[side + 1], warp
		)
		_add_triangle(surface, start_center, Vector2.ZERO, start_b, Vector2.ONE, start_a, Vector2.UP)
		_add_triangle(surface, end_center, Vector2.ZERO, end_a, Vector2.UP, end_b, Vector2.ONE)


static func append_tube(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	sides: int = 8
) -> void:
	var axis: Vector3 = (end - start).normalized()
	var reference: Vector3 = Vector3.UP
	if absf(axis.dot(reference)) > 0.94:
		reference = Vector3.RIGHT
	var side_axis: Vector3 = axis.cross(reference).normalized()
	var front_axis: Vector3 = axis.cross(side_axis).normalized()
	for side in range(sides):
		var next_side: int = (side + 1) % sides
		var angle_a: float = TAU * float(side) / sides
		var angle_b: float = TAU * float(next_side) / sides
		var radial_a: Vector3 = side_axis * cos(angle_a) + front_axis * sin(angle_a)
		var radial_b: Vector3 = side_axis * cos(angle_b) + front_axis * sin(angle_b)
		var a: Vector3 = start + radial_a * start_radius
		var b: Vector3 = start + radial_b * start_radius
		var c: Vector3 = end + radial_b * end_radius
		var d: Vector3 = end + radial_a * end_radius
		_add_triangle(surface, a, Vector2(0.0, float(side) / sides), c, Vector2(1.0, float(side + 1) / sides), b, Vector2(0.0, float(side + 1) / sides))
		_add_triangle(surface, a, Vector2(0.0, float(side) / sides), d, Vector2(1.0, float(side) / sides), c, Vector2(1.0, float(side + 1) / sides))


static func add_board_mesh(
	parent: Node3D,
	center: Vector3,
	axis: Vector3,
	length: float,
	height: float,
	depth: float,
	material: Material,
	warp: float = 0.0
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_board(
		surface,
		Vector3.ZERO,
		_basis_for_x_axis(axis),
		length,
		height,
		depth,
		0.035,
		warp
	)
	surface.generate_normals()
	surface.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


static func _basis_for_x_axis(axis: Vector3) -> Basis:
	var x_axis: Vector3 = axis.normalized()
	var reference: Vector3 = Vector3.UP
	if absf(x_axis.dot(reference)) > 0.94:
		reference = Vector3.FORWARD
	var z_axis: Vector3 = x_axis.cross(reference).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func _board_vertex(
	center: Vector3,
	orientation: Basis,
	length: float,
	t: float,
	cross_section: Vector2,
	warp: float
) -> Vector3:
	var x: float = lerpf(-length * 0.5, length * 0.5, t)
	var bend: float = sin(t * PI) * warp
	var local_position := Vector3(x, cross_section.x + bend, cross_section.y)
	return center + orientation * local_position


static func _add_triangle(
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
