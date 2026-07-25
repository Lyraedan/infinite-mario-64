extends Node

var level_bounds : AABB = AABB()
var level_meshes : Array[LevelBlock] = []
var level_start_time : int = 0
var current_mario : LibSM64Mario
var current_level_manager
var current_seed : String
var current_theme : LevelTheme
var theme_override_index : int = -1
var block_material : ShaderMaterial
var sky_material := preload("res://mario/sky_material.tres") as ShaderMaterial
var global_sound := AudioStreamPlayer.new() as AudioStreamPlayer
var global_sound_stream := AudioStreamPolyphonic.new() as AudioStreamPolyphonic
var libsm64_sound := LibSM64AudioStreamPlayer.new()
var music_player := AudioStreamPlayer.new()

func update_music(theme: LevelTheme):
	if theme and not theme.background_music_path.is_empty():
		var stream = load(theme.background_music_path)
		if stream:
			music_player.stream = stream
			music_player.play()
	else:
		music_player.stop()

var start_angle := 0.0
var save_data := MarioSaveFile.new()
var total_coins : int = 0
var main_star_pos : Vector3 = Vector3.ZERO
var restart_desired : bool = false
var inner_deadzone : float = 0.05
var outer_deadzone : float = 0.95
var flip_x : bool = true
var compat_renderer : bool = ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility"

var theme_list: Array[LevelTheme] = []
var theme_textures_cache: Dictionary = {}
var water_texture: Texture2D
var lava_texture: Texture2D

const THEME_PATHS: Array[String] = [
	"res://mario/themes/default.tres",
	"res://mario/themes/bobomb_battlefield.tres",
	"res://mario/themes/thwomp_fortress.tres",
	"res://mario/themes/snow_land.tres",
	"res://mario/themes/lava_fire_sea.tres",
]

func play_sound(inSound, volume : float = 0, pitch : float = 1) -> void:
	var playback : AudioStreamPlaybackPolyphonic = global_sound.get_stream_playback()
	playback.play_stream(inSound, 0, volume, pitch)

func generate_power_star(in_star_id : String, in_pos : Vector3, in_target_pos : Vector3 = Vector3.ZERO) -> PowerStar:
	var new_star : PowerStar = preload("res://mario/power_star.tscn").instantiate()
	new_star.star_gotten = save_data.is_star_collected(current_seed, in_star_id)
	print(new_star.star_gotten)
	new_star.position = in_pos
	new_star.star_id = in_star_id
	add_child(new_star)
	if in_target_pos != Vector3.ZERO:
		new_star.play_star_spawn_animation(in_target_pos)
	return new_star

func generate_cork_box_with_contents(in_pos : Vector3, contents : Array) -> CorkBox:
	var new_box : CorkBox = preload("res://mario/cork_block.tscn").instantiate()
	new_box.position = in_pos
	new_box.contained_items = contents
	add_child(new_box)
	return new_box
	#new_box.add_to_droplist()
	#var new_box : C

func generate_yellow_coin_at_pos(inPos : Vector3, in_drop_to_ground : bool = true, in_physics : bool = false, in_velocity : Vector3 = Vector3.ZERO) -> Coin:
	var new_coin := preload("res://mario/coin.tscn").instantiate() as Coin
	new_coin.position = inPos
	new_coin.velocity = in_velocity
	new_coin.drop_to_ground = in_drop_to_ground
	SOGlobal.add_child(new_coin)
	if in_physics:
		new_coin._set_physics_enabled(true)
	return new_coin

func generate_block_from_pos_and_size(inPos : Vector3, inSize : Vector3, north_slope : float = 0, east_slope : float = 0, south_slope : float = 0, west_slope : float = 0, in_parent = SOGlobal, move_mode : LevelBlock.move_type = LevelBlock.move_type.NONE, chatter : bool = false) -> LevelBlock:
	var new_block := LevelBlock.new()
	new_block.block_size = inSize
	var new_mesh : BoxMesh = BoxMesh.new()
	new_block.position = inPos
	new_mesh.size = inSize
	SOGlobal.level_bounds = SOGlobal.level_bounds.expand(new_block.position)
	var mesh_faces : PackedVector3Array = new_mesh.get_faces()
	var mesh_normals : PackedVector3Array = []
	mesh_normals.resize(mesh_faces.size())
	for i in range(mesh_faces.size()):
		if mesh_faces[i].y < 0:
			if mesh_faces[i].x > 0:
				mesh_faces[i] += Vector3(east_slope, 0, 0)
			else:
				mesh_faces[i] -= Vector3(west_slope, 0, 0)
			if mesh_faces[i].z > 0:
				mesh_faces[i] += Vector3(0, 0, north_slope)
			else:
				mesh_faces[i] -= Vector3(0, 0, south_slope)
	for i in range(mesh_faces.size()):
		match i % 3:
			0:
				var dir_one : Vector3 = (mesh_faces[i + 1] - mesh_faces[i])
				var dir_two : Vector3 = (mesh_faces[i + 2] - mesh_faces[i])
				mesh_normals[i] = -dir_one.cross(dir_two).normalized()
			1:
				var dir_one : Vector3 = (mesh_faces[i - 1] - mesh_faces[i])
				var dir_two : Vector3 = (mesh_faces[i + 1] - mesh_faces[i])
				mesh_normals[i] = dir_one.cross(dir_two).normalized()
			2:
				var dir_one : Vector3 = (mesh_faces[i - 1] - mesh_faces[i])
				var dir_two : Vector3 = (mesh_faces[i - 2] - mesh_faces[i])
				mesh_normals[i] = dir_one.cross(dir_two).normalized()
		#DebugDraw3D.draw_arrow_line(mesh_faces[i] + new_block.position, mesh_faces[i] + mesh_normals[i] + new_block.position, Color(1, 0, 0), 0.25, true, 10)
	var arr_mesh : ArrayMesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_faces
	arrays[Mesh.ARRAY_NORMAL] = mesh_normals
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_block.mesh = arr_mesh
	new_block.material_override = block_material
	if in_parent != SOGlobal:
		new_block.movement_parent = in_parent
	new_block.current_move_type = move_mode
	add_child(new_block)
	var surface_properties := LibSM64SurfacePropertiesComponent.new()
	surface_properties.surface_properties = LibSM64SurfaceProperties.new()
	surface_properties.surface_properties.surface_type = current_theme.default_surface_type if current_theme else LibSM64.SURFACE_DEFAULT
	new_block.add_child(surface_properties)
	new_block.set_instance_shader_parameter("fade_in", (float(Time.get_ticks_msec()) / 1000) + float(level_meshes.size()) * 0.01 + 0.2)
	new_block.set_instance_shader_parameter("spawn_dir", Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
	new_block.set_instance_shader_parameter("spawn_pos", new_block.position)
	new_block.set_instance_shader_parameter("fade_in_distance", randf_range(2, 10))
	new_block.set_instance_shader_parameter("fade_in_duration", randf_range(0.3, 0.8))
	if chatter:
		new_block.set_instance_shader_parameter("fade_in_duration", 0.125)
		new_block.set_instance_shader_parameter("fade_in_distance", 0.0)
		new_block.set_instance_shader_parameter("fade_in", (float(Time.get_ticks_msec()) / 1000))
	var new_collider := StaticBody3D.new()
	var new_collider_shape := CollisionShape3D.new()
	var new_box_shape := arr_mesh.create_convex_shape(true, false)
	new_collider_shape.shape = new_box_shape
	new_collider.set_collision_layer_value(1, true)
	new_collider.set_collision_mask_value(1, true)

	new_block.add_child(new_collider)
	new_collider.add_child(new_collider_shape)

	level_meshes.append(new_block)
	return new_block


func generate_cylinder(inPos : Vector3, in_height : float, in_radius_bot : float, in_radius_top : float, in_parent = SOGlobal, move_mode : LevelBlock.move_type = LevelBlock.move_type.NONE, chatter : bool = false) -> LevelBlock:
	var new_block := LevelBlock.new()
	new_block.coin_surface = LevelBlock.coin_spawn_type.CIRCLE
	new_block.block_size = Vector3(in_radius_top, in_radius_bot, 0)
	var new_mesh : CylinderMesh = CylinderMesh.new()
	new_mesh.height = in_height
	new_mesh.bottom_radius = in_radius_bot
	new_mesh.top_radius = in_radius_top
	new_mesh.radial_segments = 16
	new_block.position = inPos
	SOGlobal.level_bounds = SOGlobal.level_bounds.expand(new_block.position)
	new_block.mesh = new_mesh
	new_block.material_override = block_material
	var surface_properties := LibSM64SurfacePropertiesComponent.new()
	surface_properties.surface_properties = LibSM64SurfaceProperties.new()
	surface_properties.surface_properties.surface_type = current_theme.default_surface_type if current_theme else LibSM64.SURFACE_DEFAULT
	new_block.current_move_type = move_mode
	if in_parent != SOGlobal:
		new_block.movement_parent = in_parent
	add_child(new_block)
	new_block.add_child(surface_properties)
	new_block.set_instance_shader_parameter("fade_in", (float(Time.get_ticks_msec()) / 1000) + float(level_meshes.size()) * 0.01 + 0.2)
	new_block.set_instance_shader_parameter("spawn_dir", Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
	new_block.set_instance_shader_parameter("spawn_pos", new_block.position)
	new_block.set_instance_shader_parameter("fade_in_distance", randf_range(2, 10))
	new_block.set_instance_shader_parameter("fade_in_duration", randf_range(0.3, 0.8))
	if chatter:
		new_block.set_instance_shader_parameter("fade_in_duration", 0.125)
		new_block.set_instance_shader_parameter("fade_in_distance", 0.0)
		new_block.set_instance_shader_parameter("fade_in", (float(Time.get_ticks_msec()) / 1000))
	var new_collider := StaticBody3D.new()
	var new_collider_shape := CollisionShape3D.new()
	var new_collision_shape := new_mesh.create_convex_shape(true, false)
	new_collider_shape.shape = new_collision_shape
	new_collider.set_collision_layer_value(1, true)
	new_collider.set_collision_mask_value(1, true)

	new_block.add_child(new_collider)
	new_collider.add_child(new_collider_shape)

	level_meshes.append(new_block)
	return new_block

func get_theme_for_seed(seed: String) -> LevelTheme:
	if theme_override_index >= 0 and theme_override_index < theme_list.size():
		return theme_list[theme_override_index]
	if theme_list.is_empty():
		load_themes()
	if theme_list.is_empty():
		return null
	var index: int = abs(hash(seed)) % theme_list.size()
	return theme_list[index]

func load_themes() -> void:
	theme_list.clear()
	for path in THEME_PATHS:
		var theme := load(path) as LevelTheme
		if theme:
			theme_list.append(theme)

func _load_runtime_texture(path: String) -> Texture2D:
	var tex: Texture2D = ResourceLoader.load(path)
	if tex:
		return tex
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var img := Image.new()
		if img.load_png_from_buffer(file.get_buffer(file.get_length())) == OK:
			return ImageTexture.create_from_image(img)
	return null

func _generate_theme_textures() -> void:
	theme_textures_cache.clear()

	const ST = "res://streamingassets/sm64_textures"

	const BG = "res://streamingassets/sm64_textures/backgrounds"

	var theme_data: Dictionary = {
		LevelTheme.ThemeID.DEFAULT: {
			"albedo": "res://mario/debug_floor.png",
			"side": "res://mario/debug_floor.png",
			"slope": "res://mario/debug_floor_slope.png",
			"background": "%s/tex_262_521_256x256.png" % BG,
		},
		LevelTheme.ThemeID.BOBOMB_BATTLEFIELD: {
			"albedo": "%s/course_01_bobomb_battlefield/tex_37_103_32x32.png" % ST,
			"side": "%s/course_01_bobomb_battlefield/tex_70_37_32x32.png" % ST,
			"slope": "%s/course_01_bobomb_battlefield/tex_37_3_32x32.png" % ST,
			"background": "%s/tex_3_3_256x256.png" % BG,
		},
		LevelTheme.ThemeID.THWOMP_FORTRESS: {
			"albedo": "%s/course_02_whomp_fortress/tex_36_36_32x32.png" % ST,
			"side": "%s/course_02_whomp_fortress/tex_206_38_32x32.png" % ST,
			"slope": "%s/course_02_whomp_fortress/tex_137_70_32x32.png" % ST,
			"background": "%s/tex_3_3_256x256.png" % BG,
		},
		LevelTheme.ThemeID.SNOW_LAND: {
			"albedo": "%s/course_04_cool_cool_mountain/tex_105_3_32x32.png" % ST,
			"side": "%s/course_04_cool_cool_mountain/tex_37_135_32x32.png" % ST,
			"slope": "%s/course_04_cool_cool_mountain/tex_104_71_32x32.png" % ST,
			"background": "%s/tex_780_3_256x256.png" % BG,
		},
		LevelTheme.ThemeID.LAVA_FIRE_SEA: {
			"albedo": "%s/course_07_lethal_lava_land/tex_139_37_32x32.png" % ST,
			"side": "%s/course_07_lethal_lava_land/tex_3_309_32x32.png" % ST,
			"slope": "%s/course_07_lethal_lava_land/tex_37_309_32x32.png" % ST,
			"background": "%s/tex_262_262_256x165.png" % BG,
		},
	}

	for theme_id in theme_data:
		var data: Dictionary = theme_data[theme_id]
		var albedo_tex: Texture2D = _load_runtime_texture(data["albedo"])
		var side_tex: Texture2D = _load_runtime_texture(data["side"])
		var slope_tex: Texture2D = _load_runtime_texture(data["slope"])
		var bg_tex: Texture2D = null
		if data.has("background"):
			bg_tex = _load_runtime_texture(data["background"])
		if not albedo_tex:
			albedo_tex = load("res://mario/debug_floor.png")
		if not side_tex:
			side_tex = load("res://mario/debug_floor.png")
		if not slope_tex:
			slope_tex = load("res://mario/debug_floor_slope.png")
		theme_textures_cache[theme_id] = { "albedo": albedo_tex, "side": side_tex, "slope": slope_tex, "background": bg_tex }

	water_texture = _load_runtime_texture("%s/peach_castle_courtyard/tex_71_105_32x32.png" % ST)
	if not water_texture:
		water_texture = load("res://mario/debug_floor.png")
	lava_texture = _load_runtime_texture("%s/course_07_lethal_lava_land/tex_173_3_32x32.png" % ST)
	if not lava_texture:
		lava_texture = load("res://mario/debug_floor.png")


# save block structure:
# seed : string
# coins : int
# star_data : Dictionary{StarSaveData} with the star ID as the key

# star save data structure:
# star_id : string
# time : float


func _ready():
	load_themes()
	_generate_theme_textures()
	if theme_list.size() > 0:
		current_theme = theme_list[0]
	add_child(global_sound)
	global_sound.stream = global_sound_stream
	global_sound.play()
	add_child(libsm64_sound)
	libsm64_sound.play()
	add_child(music_player)
	print("INITIAL BINDINGS!")
	for i in InputMap.get_actions().size():
		var action := InputMap.get_actions()[i]
		if action.begins_with("ui"):
			continue
		print(action)
		for k in InputMap.action_get_events(action).size():
			var event = InputMap.action_get_events(action)[k]
			print(event)
			print(event.device)
	save_data.load_game()

	if compat_renderer:
		block_material = load("res://mario/block_material_compat.tres")
	else:
		block_material = load("res://mario/block_material.tres")


var unfocused := false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SOGlobal.save_data.save_game()
		get_tree().quit()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		unfocused = true
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		unfocused = false
