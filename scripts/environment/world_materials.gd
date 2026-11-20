class_name WorldMaterials
extends RefCounted


static func create(
	texture_name: String,
	tint: Color = Color.WHITE,
	roughness: float = 0.9,
	texture_scale: float = 1.0,
	normal_scale: float = 0.25
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/%s.png" % texture_name) as Texture2D
	material.albedo_color = tint
	material.roughness = roughness
	material.uv1_scale = Vector3(texture_scale, texture_scale, 1.0)
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/%s_normal.png" % texture_name) as Texture2D
	material.normal_scale = normal_scale
	return material
