@tool
extends SceneTree
## 一次性：生成 `resources/vfx/rank2_trail_smoke_material.tres` 与 `scenes/vfx/Rank2ProjectileTrail.tscn`。在项目根执行：
## Godot --headless --path . --script tools/build_rank2_trail_vfx_once.gd


func _init() -> void:
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(-1, 0, 0)
	pm.spread = 0.55
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 92.0
	pm.angular_velocity_min = -1.8
	pm.angular_velocity_max = 1.8
	pm.radial_accel_min = -12.0
	pm.radial_accel_max = 18.0
	pm.tangential_accel_min = -8.0
	pm.tangential_accel_max = 8.0
	pm.gravity = Vector3(0, -18, 0)
	pm.damping_min = 14.0
	pm.damping_max = 32.0
	pm.scale_min = 0.35
	pm.scale_max = 1.35
	pm.hue_variation_min = -0.04
	pm.hue_variation_max = 0.04
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.88, 0.88, 0.9, 0.62))
	grad.set_color(1, Color(0.45, 0.45, 0.48, 0.0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	var mat_path: String = "res://resources/vfx/rank2_trail_smoke_material.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/vfx/"))
	var err: int = ResourceSaver.save(pm, mat_path)
	if err != OK:
		push_error("save material failed " + str(err))
		quit(1)
		return
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var rad: float = 14.0
	for y in range(32):
		for x in range(32):
			var d: float = Vector2(float(x) - 15.5, float(y) - 15.5).length()
			if d < rad:
				var a: float = (1.0 - d / rad) * 0.92
				img.set_pixel(x, y, Color(1, 1, 1, a))
	var blob: Texture2D = ImageTexture.create_from_image(img)
	var blob_path: String = "res://resources/vfx/rank2_trail_particle_blob.tres"
	var save_blob: int = ResourceSaver.save(blob, blob_path)
	if save_blob != OK:
		push_error("save blob failed " + str(save_blob))
		quit(1)
		return
	var gp: GPUParticles2D = GPUParticles2D.new()
	gp.name = "Rank2ProjectileTrail"
	gp.position = Vector2(-18, 0)
	gp.z_index = -2
	gp.z_as_relative = true
	gp.amount = 52
	gp.lifetime = 0.52
	gp.explosiveness = 0.0
	gp.randomness = 0.42
	gp.local_coords = true
	gp.visibility_rect = Rect2(-96, -96, 192, 192)
	gp.emitting = true
	gp.texture = blob
	gp.process_material = pm
	var packed: PackedScene = PackedScene.new()
	var err2: Error = packed.pack(gp)
	if err2 != OK:
		push_error("pack failed " + str(err2))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/vfx/"))
	var sc_path: String = "res://scenes/vfx/Rank2ProjectileTrail.tscn"
	var err3: int = ResourceSaver.save(packed, sc_path)
	if err3 != OK:
		push_error("save scene failed " + str(err3))
		quit(1)
		return
	print("OK: ", mat_path, " ", blob_path, " ", sc_path)
	quit(0)
