extends RefCounted

# UI-S7a: Build the 3D world, camera, environment, lights, and ambient mesh.
# Main owns section nodes, signal connections, and viewport resize handling.
static func build(host: Node, ambient_shader: Shader, accent: Color) -> Dictionary:
	var collection_world: Node3D
	var camera: Camera3D
	var key_light: DirectionalLight3D
	var fill_light: DirectionalLight3D
	var rim_light: DirectionalLight3D
	var _game_ambient_mesh: MeshInstance3D
	var _game_ambient_material: ShaderMaterial
	collection_world = Node3D.new()
	collection_world.name = "CollectionWorld"
	host.add_child(collection_world)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 7.2)
	camera.current = true
	collection_world.add_child(camera)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.52, 0.56, 1.0)
	environment.ambient_light_energy = 0.08
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.18
	environment.ssao_intensity = 1.10

	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 1.0
	environment.glow_hdr_scale = 2.0
	environment.glow_hdr_luminance_cap = 12.0
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 0.5)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 1.0)
	environment.set_glow_level(5, 0.5)
	environment.set_glow_level(6, 0.0)
	world_environment.environment = environment
	collection_world.add_child(world_environment)

	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-24.0, -34.0, 0.0)
	key_light.light_energy = 0.38
	key_light.light_color = Color(0.94, 0.98, 1.0, 1.0)
	collection_world.add_child(key_light)

	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-8.0, 38.0, 0.0)
	fill_light.light_energy = 0.18
	fill_light.light_color = Color(0.62, 0.88, 1.0, 1.0)
	collection_world.add_child(fill_light)

	rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(12.0, 148.0, 0.0)
	rim_light.light_energy = 0.38
	rim_light.light_color = accent.lerp(Color.WHITE, 0.40)
	collection_world.add_child(rim_light)
	# ── 游戏板块背景 ──
	_game_ambient_mesh = MeshInstance3D.new()
	_game_ambient_mesh.name = "GameAmbient"
	_game_ambient_mesh.position = Vector3(0.0, 0.0, -6.0)
	var game_quad := QuadMesh.new()
	_game_ambient_mesh.mesh = game_quad
	_game_ambient_material = ShaderMaterial.new()
	_game_ambient_material.shader = ambient_shader
	_game_ambient_mesh.material_override = _game_ambient_material
	collection_world.add_child(_game_ambient_mesh)

	return {
		"world": collection_world,
		"camera": camera,
		"key_light": key_light,
		"fill_light": fill_light,
		"rim_light": rim_light,
		"ambient_mesh": _game_ambient_mesh,
	}

# UI-M3: Ambient quad sizing belongs with the world scene geometry.
static func quad_size(viewport_size: Vector2, camera_fov: float, camera_z: float, mesh_z: float) -> Vector2:
	var dist: float = absf(camera_z - mesh_z)
	var half_h: float = tan(deg_to_rad(camera_fov * 0.5)) * dist
	var aspect: float = viewport_size.x / viewport_size.y
	var overscan: float = 1.02
	return Vector2(
		half_h * 2.0 * aspect * overscan,
		half_h * 2.0 * overscan
	)
