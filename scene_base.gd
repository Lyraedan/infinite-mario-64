extends Node3D

@onready var sm_64_mario := $RandomMario as LibSM64Mario
@onready var sm_64_static_surface_handler: Node = $SM64StaticSurfaceHandler
@onready var sm_64_surface_objects_handler: Node = $SM64SurfaceObjectsHandler
@onready var mesh_instance_3d = $MeshInstance3D
@onready var start_displ = $StartDispl
@onready var world_environment := $WorldEnvironment as WorldEnvironment
@onready var directional_light := $DirectionalLight3D as DirectionalLight3D


func _process(delta):

	start_displ.position = sm_64_mario.position
	SOGlobal.block_material.set_shader_parameter("outer_time", float(Time.get_ticks_msec()) * 0.001)

	if !sm_64_mario.ready_to_play:
		start_displ.visible = true
	else:
		start_displ.visible = false
	start_displ.rotation.y += delta * PI * 0.5

var level_root_position_table : Array[Vector3] = []

func _generate_random_level(useSeed) -> void:

	SOGlobal.level_bounds = AABB()

	level_root_position_table.clear()
	var root_random = RandomNumberGenerator.new()
	var root_random_iterational = RandomNumberGenerator.new()
	var baseblock_random = RandomNumberGenerator.new()
	var top_random = RandomNumberGenerator.new()
	var pepper_random = RandomNumberGenerator.new()
	var mirror_random = RandomNumberGenerator.new()
	var environment_random = RandomNumberGenerator.new()
	var coin_random = RandomNumberGenerator.new()
	var movement_random = RandomNumberGenerator.new()
	var pillar_random = RandomNumberGenerator.new()
	var slope_random = RandomNumberGenerator.new()
	var cork_random = RandomNumberGenerator.new()

	var apple_seed = RandomNumberGenerator.new()
	apple_seed.seed = hash(useSeed)

	root_random.seed = apple_seed.randi()
	root_random_iterational.seed = apple_seed.randi()
	baseblock_random.seed = apple_seed.randi()
	top_random.seed = apple_seed.randi()
	pepper_random.seed = apple_seed.randi()
	mirror_random.seed = apple_seed.randi()
	environment_random.seed = apple_seed.randi()
	coin_random.seed = apple_seed.randi()
	movement_random.seed = apple_seed.randi()
	pillar_random.seed = apple_seed.randi()
	slope_random.seed = apple_seed.randi()
	cork_random.seed = apple_seed.randi()

	var block_colors := Gradient.new()
	var use_theme_gradient: bool = SOGlobal.current_theme and SOGlobal.current_theme.block_color_gradient != null
	var is_sm64_theme: bool = SOGlobal.current_theme and SOGlobal.current_theme.theme_id != LevelTheme.ThemeID.DEFAULT
	if use_theme_gradient and is_sm64_theme:
		block_colors.add_point(0, Color.WHITE)
		block_colors.add_point(0.999, Color.WHITE)
	elif use_theme_gradient:
		block_colors = SOGlobal.current_theme.block_color_gradient
	else:
		var color_count : int = environment_random.randi_range(3, 12)
		var avg_dist : float = 1.0 / color_count
		for i in range(color_count - 1):
			var hue : float = environment_random.randf_range(0, 1)
			var saturation : float = environment_random.randf_range(0.3, 1)
			var value : float = environment_random.randf_range(0.3, 1)
			var color_offset : float = avg_dist * 0.5 * environment_random.randf_range(-1, 1)
			var final_point_pos : float = float(i + 1) * avg_dist + color_offset
			block_colors.add_point(final_point_pos, Color.from_hsv(hue, saturation, value))
		var hue : float = environment_random.randf_range(0, 1)
		var saturation : float = environment_random.randf_range(0.3, 1)
		var value : float = environment_random.randf_range(0.3, 1)
		block_colors.add_point(0, Color.from_hsv(hue, saturation, value))
		block_colors.add_point(0.999, Color.from_hsv(hue, saturation, value))

	var new_gradient_texture : GradientTexture2D = GradientTexture2D.new()
	new_gradient_texture.width = 256
	new_gradient_texture.height = 1
	new_gradient_texture.fill_from = Vector2(-0.001, 0)
	new_gradient_texture.fill_to = Vector2(1.001, 0)
	new_gradient_texture.gradient = block_colors

	SOGlobal.block_material.set_shader_parameter("texture_gradient", new_gradient_texture)
	_pending_corks.clear()

	var strategy_theme = SOGlobal.current_theme
	if strategy_theme and strategy_theme.generation_strategy != LevelTheme.GenerationStrategy.DEFAULT_RANDOM_WALK:
		_generate_strategy_blocks(strategy_theme.generation_strategy,
			root_random, root_random_iterational, baseblock_random, top_random,
			pepper_random, mirror_random, environment_random, movement_random,
			pillar_random, slope_random, cork_random, apple_seed)
		await _generate_pools_and_coins(apple_seed, coin_random, cork_random)
		if _pending_corks.size() > 0 and apple_seed.randf() > 0.8:
			_place_cork_star(cork_random)
		return

	var level_gen_source : Vector3 = Vector3.ZERO
	var level_gen_source_velocity : float = root_random.randf_range(2.0, 6.0)
	var level_gen_source_angle : float = root_random.randf_range(0, PI * 2)
	SOGlobal.start_angle = snappedf(rad_to_deg(level_gen_source_angle), 45) + 180
	var level_gen_source_angle_velocity : float = root_random.randf_range(PI * -0.2, PI * 0.2)
	var vertical_vel : float = root_random.randf_range(0, 1)
	var max_block_width = root_random.randf_range(8, 24)
	var max_block_length = root_random.randf_range(8, 24)
	var max_block_height = root_random.randf_range(8, 20)
	var block_theme := SOGlobal.current_theme
	if block_theme:
		var bw_min: float = block_theme.block_width_min if block_theme.block_width_min >= 0 else 4
		var bw_max: float = block_theme.block_width_max if block_theme.block_width_max >= 0 else 24
		var bl_min: float = block_theme.block_length_min if block_theme.block_length_min >= 0 else 4
		var bl_max: float = block_theme.block_length_max if block_theme.block_length_max >= 0 else 24
		var bh_max: float = block_theme.block_height_max if block_theme.block_height_max >= 0 else 20
		max_block_width = root_random.randf_range(bw_min, bw_max)
		max_block_length = root_random.randf_range(bl_min, bl_max)
		max_block_height = root_random.randf_range(5.0, max(bh_max, 5.0))
	var block_height_bias = pow(root_random.randf_range(2, 3.5), 1.4)
	var min_vert_vel_change = root_random.randf_range(-0.2, 0.1)
	var max_vert_vel_change = root_random.randf_range(0.1, 0.4)
	var min_vert_vel_reduction = root_random.randf_range(0.75, 0.88)
	var max_vert_vel_reduction = root_random.randf_range(0.88, 0.95)
	var min_pepper_blocks = root_random.randi_range(0, 3)
	var max_pepper_blocks = root_random.randi_range(4, 12)
	var min_surface_blocks_per_4x4 = 0
	var max_surface_blocks_per_4x4 = root_random.randi_range(1, 2)
	var min_surface_block_chance = root_random.randf_range(0.4, 0.8)
	var max_surface_block_chance = root_random.randf_range(0.8, 1)
	var min_velocity_change = root_random.randf_range(-1, 0)
	var max_velocity_change = root_random.randf_range(1, 3)
	var min_angle_velocity_change = root_random.randf_range(-0.2, 0)
	var max_angle_velocity_change = root_random.randf_range(0, 0.2)
	var min_velocity_change_reduction = root_random.randf_range(0.80, 0.88)
	var max_velocity_change_reduction = root_random.randf_range(0.88, 0.96)
	var min_angle_velocity_change_reduction = root_random.randf_range(0.65, 0.72)
	var max_angle_velocity_change_reduction = root_random.randf_range(0.72, 0.85)

	var theme := SOGlobal.current_theme
	var iter_min_val: int = 25
	var iter_max_val: int = 65
	if theme and theme.iter_min >= 0:
		iter_min_val = theme.iter_min
	if theme and theme.iter_max >= 0:
		iter_max_val = theme.iter_max
	var iter : int = root_random.randi_range(iter_min_val, iter_max_val)

	var pillar_chance = root_random.randf_range(0.025, 0.05)
	if theme and theme.pillar_chance >= 0:
		pillar_chance = theme.pillar_chance

	var north_slope_chance = root_random.randf_range(0.0, 0.6)
	var east_slope_chance = root_random.randf_range(0.0, 0.6)
	var south_slope_chance = root_random.randf_range(0.0, 0.6)
	var west_slope_chance = root_random.randf_range(0.0, 0.6)
	if theme:
		if theme.slope_chance_north >= 0: north_slope_chance = theme.slope_chance_north
		if theme.slope_chance_east >= 0: east_slope_chance = theme.slope_chance_east
		if theme.slope_chance_south >= 0: south_slope_chance = theme.slope_chance_south
		if theme.slope_chance_west >= 0: west_slope_chance = theme.slope_chance_west
	var max_slope_val: int = 6
	if theme and theme.max_slope >= 0:
		max_slope_val = theme.max_slope
	var max_north_slope = root_random.randi_range(1, max(max_slope_val, 1))
	var max_east_slope = root_random.randi_range(1, max(max_slope_val, 1))
	var max_south_slope = root_random.randi_range(1, max(max_slope_val, 1))
	var max_west_slope = root_random.randi_range(1, max(max_slope_val, 1))
	var should_generate_cork_star : bool = root_random.randf() > 0.8
	for i in range(iter):
		level_root_position_table.append(level_gen_source)
		level_gen_source_velocity += root_random_iterational.randf_range(min_velocity_change, max_velocity_change)
		level_gen_source_angle_velocity += root_random_iterational.randf_range(min_angle_velocity_change, max_angle_velocity_change)
		vertical_vel += root_random_iterational.randf_range(min_vert_vel_change, max_vert_vel_change)
		#vertical_vel = max(root_random_iterational.randf_range(-5, -1), vertical_vel)
		level_gen_source_velocity = max(level_gen_source_velocity, root_random_iterational.randf_range(2, 4))
		vertical_vel *= root_random_iterational.randf_range(min_vert_vel_reduction, max_vert_vel_reduction)
		level_gen_source_velocity *= root_random_iterational.randf_range(min_velocity_change_reduction, max_velocity_change_reduction)
		level_gen_source_angle_velocity *= root_random_iterational.randf_range(min_angle_velocity_change_reduction, max_angle_velocity_change_reduction)
		level_gen_source_angle += level_gen_source_angle_velocity
		var ang_deg = rad_to_deg(level_gen_source_angle)
		ang_deg = snapped(ang_deg, 45)

		level_gen_source_velocity = minf(level_gen_source_velocity, 12.5)

		var src_no_y : Vector3 = (level_gen_source * Vector3(1, 0, 1))
		if src_no_y.length() > 100:
			level_gen_source_angle = root_random_iterational.randf_range(0, PI * 2)
		var block_pos : Vector3 = level_gen_source + Vector3(baseblock_random.randf_range(-12, 12), 0, baseblock_random.randf_range(-12, 12))
		if i == 0:
			block_pos = level_gen_source
		block_pos = snapped(block_pos, Vector3(1.0, 1.0, 1.0))
		var block_height = baseblock_random.randf_range(1.0 / max_block_height, 1.0)
		block_height = pow(block_height, block_height_bias) * max_block_height + 1
		var block_size : Vector3 = Vector3(baseblock_random.randf_range(4, max_block_width), block_height, baseblock_random.randf_range(4, max_block_length))
		block_size = snapped(block_size, Vector3(1.0, 1.0, 1.0))

		var top_area : float = block_size.x * block_size.z

		var new_block : LevelBlock
		if absf(block_size.x - block_size.z) < 2 and baseblock_random.randf() > 0.5:
			block_size.z = block_size.x
			if fmod(block_size.x, 2) == 1:
				block_pos.x += 0.5
			if fmod(block_size.y, 2) == 1:
				block_pos.y -= 0.5
			if fmod(block_size.z, 2) == 1:
				block_pos.z += 0.5
			new_block = SOGlobal.generate_cylinder(block_pos, block_size.y, block_size.x * 0.5, block_size.x * 0.5)
			top_area = pow(PI * block_size.x * 0.5, 2)
		else:
			if fmod(block_size.x, 2) == 1:
				block_pos.x += 0.5
			if fmod(block_size.y, 2) == 1:
				block_pos.y -= 0.5
			if fmod(block_size.z, 2) == 1:
				block_pos.z += 0.5
			var cur_n_slope : float = 0
			var cur_e_slope : float = 0
			var cur_s_slope : float = 0
			var cur_w_slope : float = 0
			if slope_random.randf() < north_slope_chance:
				cur_n_slope = slope_random.randi_range(0, max_north_slope)
			if slope_random.randf() < east_slope_chance:
				cur_e_slope = slope_random.randi_range(0, max_east_slope)
			if slope_random.randf() < south_slope_chance:
				cur_s_slope = slope_random.randi_range(0, max_south_slope)
			if slope_random.randf() < west_slope_chance:
				cur_w_slope = slope_random.randi_range(0, max_west_slope)
			new_block = SOGlobal.generate_block_from_pos_and_size(block_pos, block_size, cur_n_slope, cur_e_slope, cur_s_slope, cur_w_slope) as LevelBlock
			#new_block.basis = new_block.basis.rotated(Vector3.UP, deg_to_rad(ang_deg))
			#new_block._update_transform()

		# types of moving blocks to consider:
		# constantly rotating
		# periods of rotation and pause
		# rotate back and forth
		# linear back and forth horizontally
		# linear back and forth vertically

		if pillar_random.randf() < pillar_chance:
			var pillar_side_offset := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ang_deg + 90)) * pillar_random.randi_range(10, 18)
			var pillar_height := pillar_random.randi_range(12, 32)
			var pillar_radius := pillar_random.randi_range(2, 6)
			var pillar_pos := block_pos + pillar_side_offset + Vector3(0, pillar_height * 0.2, 0)
			var new_cylinder : LevelBlock = SOGlobal.generate_cylinder(pillar_pos, pillar_height, pillar_radius, pillar_radius)
			var num_sticks : int = ceil(pillar_height * pillar_random.randf_range(0.1, 0.2))
			for stick_iter in range(num_sticks):
				var random_angle_offset : float = pillar_random.randf_range(-PI, PI)
				var pillar_stick_height : float = float(stick_iter * pillar_height) / num_sticks
				var pillar_stick_extrusion : float = pillar_radius * 2 + pillar_random.randi_range(4, 12)
				var pillar_stick_width : float = pillar_random.randi_range(2, pillar_radius)
				var pillar_stick_tallness : float = pillar_random.randi_range(1, pillar_stick_width)
				var pillar_stick_size : Vector3 = Vector3(pillar_stick_width, pillar_stick_tallness, pillar_stick_extrusion)
				var pillar_stick_offset_for_material : Vector3 = Vector3.ZERO
				if fmod(pillar_stick_size.x, 2) == 1:
					pillar_stick_offset_for_material.x += 0.5
				if fmod(pillar_stick_size.y, 2) == 1:
					pillar_stick_offset_for_material.y -= 0.5
				if fmod(pillar_stick_size.z, 2) == 1:
					pillar_stick_offset_for_material.z += 0.5
				var cur_n_slope : float = 0
				var cur_e_slope : float = 0
				var cur_s_slope : float = 0
				var cur_w_slope : float = 0
				if slope_random.randf() < north_slope_chance:
					cur_n_slope = slope_random.randi_range(0, max_north_slope)
				if slope_random.randf() < east_slope_chance:
					cur_e_slope = slope_random.randi_range(0, max_east_slope)
				if slope_random.randf() < south_slope_chance:
					cur_s_slope = slope_random.randi_range(0, max_south_slope)
				if slope_random.randf() < west_slope_chance:
					cur_w_slope = slope_random.randi_range(0, max_west_slope)
				var pillar_stick_instance := SOGlobal.generate_block_from_pos_and_size(pillar_stick_offset_for_material, pillar_stick_size, cur_n_slope, cur_e_slope, cur_s_slope, cur_w_slope)  as LevelBlock
				pillar_stick_instance.position = pillar_pos + Vector3(0, -pillar_height * 0.4, 0) + Vector3(0, pillar_stick_height, 0)
				pillar_stick_instance.start_position = pillar_stick_instance.position
				pillar_stick_instance.basis = Basis.IDENTITY.rotated(Vector3.UP, random_angle_offset)
				pillar_stick_instance.start_rotation = pillar_stick_instance.basis

		var is_moving : bool = false
		var longest_axis : Vector3 = Vector3.UP
		var longest_axis_length : float = block_size.y
		var significantly_longest_axis : bool = false
		if block_size.y - block_size.x > 3 and block_size.y - block_size.z > 3 and absf(block_size.x - block_size.z) < 3:
			significantly_longest_axis = true

		if block_size.z > block_size.x and block_size.z > block_size.y:
			longest_axis = Vector3.FORWARD
			longest_axis_length = block_size.z
			if block_size.z - block_size.x > 3 and block_size.z - block_size.y > 3 and absf(block_size.x - block_size.y) < 3:
				significantly_longest_axis = true

		if block_size.x > block_size.z and block_size.x > block_size.y:
			longest_axis = Vector3.RIGHT
			longest_axis_length = block_size.x
			if block_size.x - block_size.y > 3 and block_size.x - block_size.z > 3 and absf(block_size.y - block_size.z) < 3:
				significantly_longest_axis = true

		if significantly_longest_axis and movement_random.randf() > 0.5 and level_gen_source_velocity > 7 and i > 3:
			is_moving = true
			var cw_or_ccw : int = movement_random.randi_range(0, 1) * 2 - 1
			var rotate_speed : float = 90
			new_block.continuous_rotation = longest_axis * rotate_speed
			new_block.move_time = movement_random.randf_range(1, 4)
			var should_pause : int = movement_random.randi_range(0, 1)
			new_block.pause_time = movement_random.randf_range(2, 4) * should_pause
			new_block._change_block_move_mode(LevelBlock.move_type.ROTATE_REPEAT)

		if top_area >= 24 and i != iter - 1:
			if movement_random.randf() > 0.5 and block_size.x == block_size.z and !is_moving and level_gen_source_velocity > 7 and i > 3:
				is_moving = true
				var cw_or_ccw : int = movement_random.randi_range(0, 1) * 2 - 1
				new_block.continuous_rotation = Vector3(0, (360 * cw_or_ccw) / movement_random.randf_range(8, 32), 0)
				new_block.pause_time = 0
				var vertical_offset : float = movement_random.randi_range(0, 1) * 2 - 1
				new_block.position += Vector3(0, vertical_offset * 0.5, 0)
				new_block.start_position += Vector3(0, vertical_offset * 0.5, 0)
				new_block._change_block_move_mode(LevelBlock.move_type.ROTATE_REPEAT)
			var num_surface_blocks_to_gen : int = floor(top_random.randi_range(min_surface_blocks_per_4x4, max_surface_blocks_per_4x4) * (top_area / 16))
			for b in range(num_surface_blocks_to_gen):
				if top_random.randf_range(0, 1) < top_random.randf_range(min_surface_block_chance, max_surface_block_chance):
					continue
				var top_block_size = Vector3(top_random.randf_range(1, 4), top_random.randf_range(1, 4), top_random.randf_range(1, 4))
				top_block_size = snapped(top_block_size, Vector3(1.0, 1.0, 1.0))
				var x_offset_range : float = (block_size.x - top_block_size.x) * 0.5
				var z_offset_range : float = (block_size.z - top_block_size.z) * 0.5
				var total_offset = Vector3(top_random.randf_range(-x_offset_range, x_offset_range), block_size.y * 0.5 + top_block_size.y * 0.5, top_random.randf_range(-z_offset_range, z_offset_range))
				total_offset = snapped(total_offset, Vector3(1, 1, 1))
				if fmod(top_block_size.x + block_size.x, 2) == 1:
					total_offset.x += 0.5
				if fmod(top_block_size.y + block_size.y, 2) == 1:
					total_offset.y -= 0.5
				if fmod(top_block_size.z + block_size.z, 2) == 1:
					total_offset.z += 0.5
				var cur_n_slope : float = 0
				var cur_e_slope : float = 0
				var cur_s_slope : float = 0
				var cur_w_slope : float = 0
				if slope_random.randf() < north_slope_chance:
					cur_n_slope = slope_random.randi_range(0, max_north_slope)
				if slope_random.randf() < east_slope_chance:
					cur_e_slope = slope_random.randi_range(0, max_east_slope)
				if slope_random.randf() < south_slope_chance:
					cur_s_slope = slope_random.randi_range(0, max_south_slope)
				if slope_random.randf() < west_slope_chance:
					cur_w_slope = slope_random.randi_range(0, max_west_slope)
				var top_block := SOGlobal.generate_block_from_pos_and_size(block_pos + total_offset, top_block_size, cur_n_slope, cur_e_slope, cur_s_slope, cur_w_slope, new_block) as LevelBlock
				if is_moving:
					top_block._change_block_move_mode(LevelBlock.move_type.CHILD)

		var block_volume = block_size.x * block_size.y * block_size.z
		if block_volume >= 320:
			for b in range(pepper_random.randi_range(min_pepper_blocks, max_pepper_blocks)):
				var gen_dist = 0
				var x_or_z_pep = pepper_random.randi_range(0, 1)
				var neg_or_pos = pepper_random.randi_range(0, 1) * 2 - 1
				var rand_dir = Vector3(x_or_z_pep * neg_or_pos, 0, (1 - x_or_z_pep) * neg_or_pos)
				var pepper_block_size = Vector3(pepper_random.randf_range(1, 6), pepper_random.randf_range(1, block_size.y), pepper_random.randf_range(1, 6))
				pepper_block_size = snapped(pepper_block_size, Vector3(1.0, 1.0, 1.0))
				var horiz_offset = Vector3.ZERO
				if rand_dir.x != 0:
					gen_dist = block_size.x * 0.5 + pepper_block_size.x * 0.5
					var offset_range : float = (block_size.z - pepper_block_size.z) * 0.5
					horiz_offset = Vector3(0, 0, pepper_random.randf_range(-offset_range, offset_range))
				else:
					gen_dist = block_size.z * 0.5 + pepper_block_size.z * 0.5
					var offset_range : float = (block_size.x - pepper_block_size.x) * 0.5
					horiz_offset = Vector3(pepper_random.randf_range(-offset_range, offset_range), 0, 0)
				horiz_offset = snapped(horiz_offset, Vector3(1, 1, 1))
				var height_adjust : float = snappedf(pepper_random.randf_range(-block_size.y + pepper_block_size.y, block_size.y - pepper_block_size.y) * 0.5, 1)
				var final_pos = block_pos + gen_dist * rand_dir + Vector3(0, height_adjust, 0) + horiz_offset
				if fmod(pepper_block_size.x + block_size.x, 2) == 1 and x_or_z_pep == 0:
					final_pos.x += 0.5
				if fmod(pepper_block_size.y + block_size.y, 2) == 1:
					final_pos.y += 0.5
				if fmod(pepper_block_size.z + block_size.z, 2) == 1 and x_or_z_pep == 1:
					final_pos.z += 0.5
				var cur_n_slope : float = 0
				var cur_e_slope : float = 0
				var cur_s_slope : float = 0
				var cur_w_slope : float = 0
				if slope_random.randf() < north_slope_chance:
					cur_n_slope = slope_random.randi_range(0, max_north_slope)
				if slope_random.randf() < east_slope_chance:
					cur_e_slope = slope_random.randi_range(0, max_east_slope)
				if slope_random.randf() < south_slope_chance:
					cur_s_slope = slope_random.randi_range(0, max_south_slope)
				if slope_random.randf() < west_slope_chance:
					cur_w_slope = slope_random.randi_range(0, max_west_slope)
				var new_pepper_block := SOGlobal.generate_block_from_pos_and_size(final_pos, pepper_block_size, cur_n_slope, cur_e_slope, cur_s_slope, cur_w_slope, new_block) as LevelBlock
				if is_moving:
					new_pepper_block._change_block_move_mode(LevelBlock.move_type.CHILD)
		if block_height >= 7.9:
			var rand_dist = mirror_random.randi_range(4, 6)
			var x_or_z = mirror_random.randi_range(0, 1)
			var neg_or_pos = mirror_random.randi_range(0, 1) * 2 - 1
			var rand_dir = Vector3(x_or_z * neg_or_pos, 0, (1 - x_or_z) * neg_or_pos)
			if rand_dir.x != 0:
				rand_dist += block_size.x
			else:
				rand_dist += block_size.z
			var mirror_pos = block_pos + rand_dist * rand_dir
			SOGlobal.generate_block_from_pos_and_size(mirror_pos, block_size)
			if block_volume >= 320:
				for b in range(pepper_random.randi_range(min_pepper_blocks, max_pepper_blocks)):
					var gen_dist = 0
					var x_or_z_pep = pepper_random.randi_range(0, 1)
					var neg_or_pos_pep = pepper_random.randi_range(0, 1) * 2 - 1
					var rand_dir_pep = Vector3(x_or_z_pep * neg_or_pos_pep, 0, (1 - x_or_z_pep) * neg_or_pos_pep)
					var pepper_block_size = Vector3(pepper_random.randf_range(1, 6), pepper_random.randf_range(1, block_size.y), pepper_random.randf_range(1, 6))
					pepper_block_size = snapped(pepper_block_size, Vector3(2.0, 2.0, 2.0))
					var horiz_offset = Vector3.ZERO
					if rand_dir_pep.x != 0:
						gen_dist = block_size.x * 0.5 + pepper_block_size.x * 0.5
						var offset_range : float = (block_size.z - pepper_block_size.z) * 0.5
						horiz_offset = Vector3(0, 0, pepper_random.randf_range(-offset_range, offset_range))
					else:
						gen_dist = block_size.z * 0.5 + pepper_block_size.z * 0.5
						var offset_range : float = (block_size.x - pepper_block_size.x) * 0.5
						horiz_offset = Vector3(pepper_random.randf_range(-offset_range, offset_range), 0, 0)
					horiz_offset = snapped(horiz_offset, Vector3(1, 1, 1))
					var height_adjust : float = snappedf(pepper_random.randf_range(-block_size.y + pepper_block_size.y, block_size.y - pepper_block_size.y) * 0.5, 1)
					var final_pos = mirror_pos + gen_dist * rand_dir_pep + Vector3(0, height_adjust, 0) + horiz_offset
					if fmod(pepper_block_size.x + block_size.x, 2) == 1 and x_or_z_pep == 0:
						final_pos.x += 0.5
					if fmod(pepper_block_size.y + block_size.y, 2) == 1:
						final_pos.y += 0.5
					if fmod(pepper_block_size.z + block_size.z, 2) == 1 and x_or_z_pep == 1:
						final_pos.z += 0.5

					var cur_n_slope : float = 0
					var cur_e_slope : float = 0
					var cur_s_slope : float = 0
					var cur_w_slope : float = 0
					if slope_random.randf() < north_slope_chance:
						cur_n_slope = slope_random.randi_range(0, max_north_slope)
					if slope_random.randf() < east_slope_chance:
						cur_e_slope = slope_random.randi_range(0, max_east_slope)
					if slope_random.randf() < south_slope_chance:
						cur_s_slope = slope_random.randi_range(0, max_south_slope)
					if slope_random.randf() < west_slope_chance:
						cur_w_slope = slope_random.randi_range(0, max_west_slope)
					SOGlobal.generate_block_from_pos_and_size(final_pos, pepper_block_size, cur_n_slope, cur_e_slope, cur_s_slope, cur_w_slope)

		if i == iter - 1:
			var new_star_pos : Vector3 = block_pos + Vector3(0, block_size.y * 0.5, 0) + Vector3(0, 3.5, 0)
			var new_star := SOGlobal.generate_power_star("main", new_star_pos) as PowerStar
			new_star.main_star = true
			new_star._activate_star()

		level_gen_source += Vector3(0, vertical_vel, level_gen_source_velocity).rotated(Vector3(0, 1, 0), deg_to_rad(ang_deg))

	await _generate_pools_and_coins(apple_seed, coin_random, cork_random)
	if _pending_corks.size() > 0 and should_generate_cork_star:
		_place_cork_star(cork_random)

func _generate_pools_and_coins(apple_seed_rng: RandomNumberGenerator, coin_rng: RandomNumberGenerator, cork_rng: RandomNumberGenerator) -> void:
	var theme := SOGlobal.current_theme
	var pool_random = RandomNumberGenerator.new()
	pool_random.seed = apple_seed_rng.randi()
	var use_lava_pools: bool = theme and theme.theme_id == LevelTheme.ThemeID.LAVA_FIRE_SEA
	var pool_tex: Texture2D = SOGlobal.lava_texture if use_lava_pools else SOGlobal.water_texture
	var num_pools: int = pool_random.randi_range(2, 4)
	for p in range(num_pools):
		var idx: int = pool_random.randi_range(0, level_root_position_table.size() - 1)
		var pool_center: Vector3 = level_root_position_table[idx]
		var pool_size: int = pool_random.randi_range(2, 3)
		for dx in range(pool_size):
			for dz in range(pool_size):
				var pool_pos: Vector3 = snapped(pool_center + Vector3(dx, 0, dz), Vector3.ONE)
				var pool_block := SOGlobal.generate_block_from_pos_and_size(pool_pos, Vector3(1, 1, 1))
				pool_block.set_instance_shader_parameter("texture_albedo", pool_tex)
				pool_block.set_instance_shader_parameter("side_texture_albedo", pool_tex)
				pool_block.set_instance_shader_parameter("slope_texture_albedo", pool_tex)
				for child in pool_block.get_children():
					if child is LibSM64SurfacePropertiesComponent:
						child.surface_properties.surface_type = 0
						break

	await get_tree().create_timer(0.02).timeout
	var coin_density_mult: float = 1.0
	if theme and theme.coin_density_mult >= 0:
		coin_density_mult = theme.coin_density_mult
	var coin_spawn_chance_filter: float = 1.0
	if coin_density_mult < 1.0:
		coin_spawn_chance_filter = coin_density_mult
	var num_coins_spawned = 0
	var coin_cast : RayCast3D = RayCast3D.new()
	coin_cast.set_collision_mask_value(1, true)
	SOGlobal.add_child(coin_cast)
	for mesh:LevelBlock in SOGlobal.level_meshes:
		if mesh.coin_surface == LevelBlock.coin_spawn_type.BOX:
			if coin_density_mult < 1.0 and coin_rng.randf() > coin_density_mult:
				continue
			var cur_box_size : Vector3 = mesh.block_size
			var cur_box_halfsize : Vector3 = cur_box_size * 0.5
			var cur_box_pos : Vector3 = mesh.position
			var coin_height : float = cur_box_pos.y + cur_box_halfsize.y + 0.75
			for bx in cur_box_size.x:
				for bz in cur_box_size.z:
					if cork_rng.randf() > 0.9994:
						var corner_1 : Vector3 = Vector3(cur_box_pos.x - cur_box_halfsize.x + 0.5, coin_height, cur_box_pos.z - cur_box_halfsize.z + 0.5)
						var possible_contents : Array = [["coin", "coin", "coin"], ["coin", "coin", "coin", "coin", "coin"], ["coin", "coin", "coin", "coin", "coin", "coin", "coin", "coin", "coin", "coin"]]
						var new_cork : CorkBox = SOGlobal.generate_cork_box_with_contents(corner_1 + Vector3(bx, 0, bz) + Vector3(0, 3, 0), possible_contents[cork_rng.randi_range(0, possible_contents.size() - 1)])
						if not _pending_corks.has(new_cork):
							_pending_corks.append(new_cork)

			for bx in cur_box_size.x:
				for bz in cur_box_size.z:
					if coin_rng.randf_range(0, 1) > 0.99975:
						var num_coins : int = coin_rng.randi_range(3, 6)
						var corner_1 : Vector3 = Vector3(cur_box_pos.x - cur_box_halfsize.x + 0.5, coin_height, cur_box_pos.z - cur_box_halfsize.z + 0.5)
						for nc in num_coins:
							SOGlobal.generate_yellow_coin_at_pos(corner_1 + Vector3(bx, nc, bz), false)
			if coin_rng.randf_range(0, 1) > 0.9 and cur_box_size.x > 3 and cur_box_size.z > 3:
				var corner_1 : Vector3 = Vector3(cur_box_pos.x - cur_box_halfsize.x + 0.5, coin_height, cur_box_pos.z - cur_box_halfsize.z + 0.5)
				var corner_2 : Vector3 = Vector3(cur_box_pos.x + cur_box_halfsize.x - 0.5, coin_height, cur_box_pos.z - cur_box_halfsize.z + 0.5)
				var corner_3 : Vector3 = Vector3(cur_box_pos.x - cur_box_halfsize.x + 0.5, coin_height, cur_box_pos.z + cur_box_halfsize.z - 0.5)
				var corner_4 : Vector3 = Vector3(cur_box_pos.x + cur_box_halfsize.x - 0.5, coin_height, cur_box_pos.z + cur_box_halfsize.z - 0.5)
				if coin_rng.randf_range(0, 1) > 0.8:
					SOGlobal.generate_yellow_coin_at_pos(corner_1)
					SOGlobal.generate_yellow_coin_at_pos(corner_1 + Vector3(1, 0, 0))
					SOGlobal.generate_yellow_coin_at_pos(corner_1 + Vector3(0, 0, 1))
					if cur_box_size.x > 5 and cur_box_size.z > 5 and coin_rng.randf_range(0, 1) > 0.75:
						SOGlobal.generate_yellow_coin_at_pos(corner_1 + Vector3(2, 0, 0))
						SOGlobal.generate_yellow_coin_at_pos(corner_1 + Vector3(0, 0, 2))
				if coin_rng.randf_range(0, 1) > 0.8:
					SOGlobal.generate_yellow_coin_at_pos(corner_2)
					SOGlobal.generate_yellow_coin_at_pos(corner_2 + Vector3(-1, 0, 0))
					SOGlobal.generate_yellow_coin_at_pos(corner_2 + Vector3(0, 0, 1))
					if cur_box_size.x > 5 and cur_box_size.z > 5 and coin_rng.randf_range(0, 1) > 0.75:
						SOGlobal.generate_yellow_coin_at_pos(corner_2 + Vector3(-2, 0, 0))
						SOGlobal.generate_yellow_coin_at_pos(corner_2 + Vector3(0, 0, 2))
				if coin_rng.randf_range(0, 1) > 0.8:
					SOGlobal.generate_yellow_coin_at_pos(corner_3)
					SOGlobal.generate_yellow_coin_at_pos(corner_3 + Vector3(1, 0, 0))
					SOGlobal.generate_yellow_coin_at_pos(corner_3 + Vector3(0, 0, -1))
					if cur_box_size.x > 5 and cur_box_size.z > 5 and coin_rng.randf_range(0, 1) > 0.75:
						SOGlobal.generate_yellow_coin_at_pos(corner_3 + Vector3(2, 0, 0))
						SOGlobal.generate_yellow_coin_at_pos(corner_3 + Vector3(0, 0, -2))
				if coin_rng.randf_range(0, 1) > 0.8:
					SOGlobal.generate_yellow_coin_at_pos(corner_4)
					SOGlobal.generate_yellow_coin_at_pos(corner_4 + Vector3(-1, 0, 0))
					SOGlobal.generate_yellow_coin_at_pos(corner_4 + Vector3(0, 0, -1))
					if cur_box_size.x > 5 and cur_box_size.z > 5 and coin_rng.randf_range(0, 1) > 0.75:
						SOGlobal.generate_yellow_coin_at_pos(corner_4 + Vector3(-2, 0, 0))
						SOGlobal.generate_yellow_coin_at_pos(corner_4 + Vector3(0, 0, -2))
			if coin_rng.randf_range(0, 1) > 0.85 and cur_box_size.x > 4 and cur_box_size.z > 4:
				var random_horiz_offset = Vector3(coin_rng.randf_range(-cur_box_halfsize.x + 2.5, cur_box_halfsize.x - 2.5), 0, coin_rng.randf_range(-cur_box_halfsize.z + 2.5, cur_box_halfsize.z - 2.5))
				random_horiz_offset = round(random_horiz_offset)
				var ring_origin = Vector3(cur_box_pos.x, 0, cur_box_pos.z) + Vector3(0, coin_height, 0) + random_horiz_offset
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(45)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(90)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(135)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(180)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(-45)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(-90)))
				SOGlobal.generate_yellow_coin_at_pos(ring_origin + Vector3(0, 0, 2).rotated(Vector3.UP, deg_to_rad(-135)))
			if coin_rng.randf_range(0, 1) > 0.85 and cur_box_size.x > 4 and cur_box_size.z > 4:
				var random_horiz_offset = Vector3(coin_rng.randf_range(-cur_box_halfsize.x + 2.5, cur_box_halfsize.x - 2.5), 0, coin_rng.randf_range(-cur_box_halfsize.z + 2.5, cur_box_halfsize.z - 2.5))
				random_horiz_offset = round(random_horiz_offset)
				var line_origin = Vector3(cur_box_pos.x, 0, cur_box_pos.z) + Vector3(0, coin_height, 0) + random_horiz_offset
				var coin_line_angle = coin_rng.randi_range(0, 7) * 45
				var line_dir = Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(coin_line_angle))
				SOGlobal.generate_yellow_coin_at_pos(line_origin + line_dir * 2)
				SOGlobal.generate_yellow_coin_at_pos(line_origin + line_dir * 1)
				SOGlobal.generate_yellow_coin_at_pos(line_origin)
				SOGlobal.generate_yellow_coin_at_pos(line_origin + line_dir * -1)
				SOGlobal.generate_yellow_coin_at_pos(line_origin + line_dir * -2)

		else:
			continue

func _place_cork_star(cork_rng: RandomNumberGenerator) -> void:
	if _pending_corks.size() > 0:
		var which_cork : int = cork_rng.randi_range(0, _pending_corks.size() - 1)
		_pending_corks[which_cork].contained_items = ["star"]


func _generate_strategy_blocks(strategy: int,
	root_rng: RandomNumberGenerator, root_iter_rng: RandomNumberGenerator,
	base_rng: RandomNumberGenerator, top_rng: RandomNumberGenerator,
	pepper_rng: RandomNumberGenerator, mirror_rng: RandomNumberGenerator,
	env_rng: RandomNumberGenerator, move_rng: RandomNumberGenerator,
	pillar_rng: RandomNumberGenerator, slope_rng: RandomNumberGenerator,
	cork_rng: RandomNumberGenerator, apple_rng: RandomNumberGenerator) -> void:

	match strategy:
		LevelTheme.GenerationStrategy.BOBOMB_BATTLEFIELD:
			_generate_bobomb_battlefield(root_rng, base_rng, slope_rng)
		LevelTheme.GenerationStrategy.THWOMP_FORTRESS:
			_generate_thwomp_fortress(root_rng, base_rng, move_rng)
		LevelTheme.GenerationStrategy.SNOW_LAND:
			_generate_snow_land(root_rng, base_rng, slope_rng)
		LevelTheme.GenerationStrategy.LAVA_FIRE_SEA:
			_generate_lava_fire_sea(root_rng, base_rng, move_rng)


func _snap_block_pos(pos: Vector3, size: Vector3) -> Vector3:
	var snapped_pos: Vector3 = snapped(pos, Vector3.ONE)
	if fmod(size.x, 2) == 1:
		snapped_pos.x += 0.5
	if fmod(size.y, 2) == 1:
		snapped_pos.y -= 0.5
	if fmod(size.z, 2) == 1:
		snapped_pos.z += 0.5
	return snapped_pos


func _generate_bobomb_battlefield(rng: RandomNumberGenerator, block_rng: RandomNumberGenerator, slope_rng: RandomNumberGenerator) -> void:
	var r := rng
	var br := block_rng

	var field_size := Vector3(br.randf_range(20, 28), 1, br.randf_range(20, 28))
	field_size = snapped(field_size, Vector3.ONE)
	field_size.y = max(field_size.y, 1)
	var field_pos := _snap_block_pos(Vector3(-field_size.x * 0.5, 0, -field_size.z * 0.5), field_size)
	_spawn_box(field_pos, field_size)
	level_root_position_table.append(field_pos + field_size * 0.5)

	var hill_height := r.randf_range(6, 10)
	var hill_size := Vector3(br.randf_range(12, 16), hill_height, br.randf_range(12, 16))
	_spawn_pyramid(Vector3(0, 0, 0), hill_size)
	level_root_position_table.append(Vector3(0, hill_height * 0.5, 0))

	var arch_dir := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized()
	_spawn_arch(Vector3(-hill_size.x * 0.5 - 2, 0, -2), Vector3(6, 6, 3), 0.3)
	level_root_position_table.append(Vector3(-hill_size.x * 0.5 + 1, 3, -0.5))

	_spawn_staircase(Vector3(0, 0, hill_size.z * 0.5 + 1), Vector3(6, hill_height * 0.5, 3), r.randi_range(4, 6), Vector3.BACK)
	level_root_position_table.append(Vector3(0, hill_height * 0.25, hill_size.z * 0.5 + 2.5))

	var num_platforms := r.randi_range(8, 12)
	for p in range(num_platforms):
		var angle := r.randf_range(0, PI * 2)
		var dist := br.randf_range(14, 30)
		var plat_size := Vector3(br.randf_range(4, 10), br.randf_range(1, 3), br.randf_range(4, 10))
		plat_size = snapped(plat_size, Vector3.ONE)
		plat_size.y = max(plat_size.y, 1)
		var plat_center := Vector3(cos(angle) * dist, r.randf_range(2, 10), sin(angle) * dist)
		var shape_choice := p % 4
		if shape_choice == 0:
			_spawn_octagonal_prism(plat_center - plat_size * 0.5, plat_size)
		elif shape_choice == 1:
			_spawn_cross_platform(plat_center - plat_size * 0.5, plat_size, 0.3)
		elif shape_choice == 2:
			_spawn_cylinder(plat_center - plat_size * 0.5, plat_size)
		else:
			_spawn_box(plat_center - plat_size * 0.5, plat_size)
		level_root_position_table.append(plat_center)

	var bridge_dir := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized()
	var bridge_start := bridge_dir * 14
	for b in range(4):
		var b_pos := _snap_block_pos(bridge_start + bridge_dir * b * 3.0 - Vector3(0.5, 0, 1.5), Vector3(1, 1, 3))
		b_pos.y = 1
		if b == 0 or b == 3:
			_spawn_box(b_pos, Vector3(1, 1, 3))
		else:
			_spawn_wedge(b_pos, Vector3(1, 1, 3), bridge_dir)
		level_root_position_table.append(b_pos + Vector3(0.5, 0.5, 1.5))

	var star_pos := Vector3(0, hill_height + 3.5, 0)
	var new_star := SOGlobal.generate_power_star("main", star_pos) as PowerStar
	new_star.main_star = true
	new_star._activate_star()


func _generate_thwomp_fortress(rng: RandomNumberGenerator, block_rng: RandomNumberGenerator, move_rng: RandomNumberGenerator) -> void:
	var r := rng
	var br := block_rng

	var base_size := Vector3(br.randf_range(18, 24), 2, br.randf_range(14, 18))
	base_size = snapped(base_size, Vector3.ONE)
	base_size.y = 2
	var base_pos := _snap_block_pos(-base_size * 0.5, base_size)
	_spawn_box(base_pos, base_size)
	level_root_position_table.append(base_pos + base_size * 0.5)

	for corner in range(4):
		var ca := corner * PI * 0.5 + PI * 0.25
		var cd := base_size.length() * 0.35
		var cpos := Vector3(cos(ca) * cd, 1.0, sin(ca) * cd)
		_spawn_cylinder(cpos - Vector3(1, 0, 1), Vector3(2, 4, 2), 8)
		level_root_position_table.append(cpos)

	var tier_count := r.randi_range(6, 9)
	var tier_size := base_size - Vector3(2, 0, 2)
	var last_center := Vector3.ZERO
	for t in range(tier_count):
		var t_width := br.randf_range(max(tier_size.x - t * 1.5, 4), max(tier_size.x - t * 1.0, 4))
		var t_depth := br.randf_range(max(tier_size.z - t * 1.5, 4), max(tier_size.z - t * 1.0, 4))
		var t_height := br.randf_range(2, 4)
		var t_size := Vector3(snapped(t_width, 1), snapped(t_height, 1), snapped(t_depth, 1))
		t_size.y = max(t_size.y, 2)
		var offset_x := br.randf_range(-3, 3)
		var offset_z := br.randf_range(-3, 3)
		var t_center := last_center + Vector3(offset_x, t_height * 0.5, offset_z)
		if abs(t_center.x) + t_size.x * 0.5 > base_size.x * 0.5:
			t_center.x = sign(t_center.x) * (base_size.x * 0.5 - t_size.x * 0.5)
		if abs(t_center.z) + t_size.z * 0.5 > base_size.z * 0.5:
			t_center.z = sign(t_center.z) * (base_size.z * 0.5 - t_size.z * 0.5)
		t_center.y = last_center.y + t_height * 0.5 + 2.0 if t == 0 else last_center.y + t_height * 0.5
		if t == 0:
			t_center.y = t_height * 0.5 + 2
		var t_pos := _snap_block_pos(t_center - t_size * 0.5, t_size)
		if t == tier_count - 1:
			_spawn_crenellated_block(t_pos, t_size, br.randi_range(2, 4))
		elif t % 2 == 1:
			_spawn_octagonal_prism(t_pos, t_size)
		else:
			_spawn_box(t_pos, t_size)
		level_root_position_table.append(t_center)
		last_center = t_center

		if t > 0 and t % 2 == 0:
			if t < tier_count - 1:
				var stair_dir := Vector3(br.randf_range(-1, 1), 0, br.randf_range(-1, 1)).normalized()
				_spawn_staircase(t_center - Vector3(1, 0, 1) + stair_dir * t_size.x * 0.5, Vector3(4, t_height * 0.8, 3), r.randi_range(3, 5), -stair_dir)
				level_root_position_table.append(t_center + stair_dir * 2)
			var gap_dir := Vector3(br.randf_range(-1, 1), 0, br.randf_range(-1, 1)).normalized()
			var bridge_len := br.randi_range(2, 4)
			for b in range(bridge_len):
				var bridge_center := t_center + gap_dir * (b + 1) * 2.5
				var bridge_size := Vector3(2, 1, 2)
				var bridge_pos := _snap_block_pos(bridge_center - bridge_size * 0.5, bridge_size)
				var bridge_block := _spawn_box(bridge_pos, bridge_size)
				level_root_position_table.append(bridge_center)
				if move_rng.randf() > 0.5:
					bridge_block.continuous_rotation = Vector3(0, 360.0 / move_rng.randf_range(8, 20), 0)
					bridge_block._change_block_move_mode(LevelBlock.move_type.ROTATE_REPEAT)

	var star_pos := last_center + Vector3(0, 4.5, 0)
	var new_star := SOGlobal.generate_power_star("main", star_pos) as PowerStar
	new_star.main_star = true
	new_star._activate_star()


func _generate_snow_land(rng: RandomNumberGenerator, block_rng: RandomNumberGenerator, slope_rng: RandomNumberGenerator) -> void:
	var r := rng
	var br := block_rng
	var sr := slope_rng

	var steps := r.randi_range(25, 40)
	var pos := Vector3.ZERO
	var angle := r.randf_range(0, PI * 2)
	var base_height := 2.0

	var base_size := Vector3(br.randf_range(20, 26), 1, br.randf_range(20, 26))
	base_size = snapped(base_size, Vector3.ONE)
	base_size.y = 1
	var base_pos := _snap_block_pos(-base_size * 0.5, base_size)
	_spawn_box(base_pos, base_size)
	level_root_position_table.append(Vector3.ZERO)

	var arch_placed := false
	var prev_dir := Vector3.ZERO
	for i in range(steps):
		angle += r.randf_range(-0.5, 0.5)
		var dist := 3.0 + r.randf_range(0, 2)
		var step_dir := Vector3(cos(angle), 0, sin(angle))
		pos += step_dir * dist
		var step_height := base_height + (float(i) / steps) * r.randf_range(12, 18)
		pos.y = step_height
		var blk_w := br.randf_range(4, 10)
		var blk_d := br.randf_range(4, 10)
		var blk_h := br.randf_range(1.5, 4)
		var blk_size: Vector3 = snapped(Vector3(blk_w, blk_h, blk_d), Vector3.ONE)
		blk_size.y = max(blk_size.y, 1)
		var blk_pos := _snap_block_pos(pos - blk_size * 0.5, blk_size)
		var shape_idx := i % 5
		if shape_idx == 0 and i > 0:
			_spawn_wedge(blk_pos, blk_size, -step_dir)
		elif shape_idx == 2 and i > 0:
			_spawn_wedge(blk_pos, blk_size, step_dir)
		elif shape_idx == 4 and i > 3:
			_spawn_cylinder(blk_pos, blk_size, 8)
		else:
			_spawn_box(blk_pos, blk_size)
		level_root_position_table.append(pos)
		prev_dir = step_dir

		if i > 5 and i % 8 == 0 and not arch_placed:
			var cross_dir := Vector3(step_dir.z, 0, -step_dir.x)
			_spawn_arch(pos + cross_dir * 2 - Vector3(0, 1, 0), Vector3(5, 5, 3), 0.3)
			level_root_position_table.append(pos + cross_dir * 2)
			arch_placed = true

	var peak_size := Vector3(6, 4, 6)
	var peak_pos := _snap_block_pos(pos - peak_size * 0.5, peak_size)
	_spawn_pyramid(peak_pos, peak_size)
	level_root_position_table.append(pos + Vector3(0, 2, 0))

	_spawn_staircase(pos - Vector3(3, 0, 3), Vector3(6, 3, 6), randi_range(4, 6), -prev_dir)
	level_root_position_table.append(pos - prev_dir * 2)

	var star_pos := pos + Vector3(0, 7.0, 0)
	var new_star := SOGlobal.generate_power_star("main", star_pos) as PowerStar
	new_star.main_star = true
	new_star._activate_star()


func _generate_lava_fire_sea(rng: RandomNumberGenerator, block_rng: RandomNumberGenerator, move_rng: RandomNumberGenerator) -> void:
	var r := rng
	var br := block_rng

	var num_clusters := r.randi_range(5, 8)
	var cluster_positions: Array[Vector3] = []
	for c in range(num_clusters):
		var angle := r.randf_range(0, PI * 2)
		var dist := br.randf_range(6, 30)
		var cluster_center := Vector3(cos(angle) * dist, 1.5, sin(angle) * dist)
		cluster_positions.append(cluster_center)

		var blocks_in_cluster := r.randi_range(2, 4)
		for b in range(blocks_in_cluster):
			var offset := Vector3(br.randf_range(-3, 3), 0, br.randf_range(-3, 3))
			var b_size := Vector3(br.randf_range(3, 8), br.randf_range(1, 2), br.randf_range(3, 8))
			b_size = snapped(b_size, Vector3.ONE)
			b_size.y = max(b_size.y, 1)
			var b_center := cluster_center + offset
			b_center.y = 1.0
			var b_pos := _snap_block_pos(b_center - b_size * 0.5, b_size)
			var block: LevelBlock
			var shape_idx = (c * 4 + b) % 4
			if b == 0 and b_size.x > 5 and b_size.z > 5:
				if shape_idx < 2:
					block = _spawn_octagonal_prism(b_pos, b_size)
				else:
					block = _spawn_cylinder(b_pos, b_size, 10)
			elif b == 1 and blocks_in_cluster > 2:
				if shape_idx == 1:
					block = _spawn_cross_platform(b_pos, b_size, 0.3)
				else:
					block = _spawn_box(b_pos, b_size)
			else:
				block = _spawn_box(b_pos, b_size)
			level_root_position_table.append(b_center)
			if move_rng.randf() > 0.6 and b == blocks_in_cluster - 1:
				block.continuous_rotation = Vector3(0, 360.0 / move_rng.randf_range(6, 16), 0)
				block._change_block_move_mode(LevelBlock.move_type.ROTATE_REPEAT)

		if c > 0 and c % 2 == 0:
			var prev_center := cluster_positions[c - 1]
			var bridge_dir_vec := (cluster_center - prev_center).normalized()
			var bridge_len := int(cluster_center.distance_to(prev_center) / 2.5)
			for b in range(bridge_len):
				var bridge_center := prev_center + bridge_dir_vec * (b + 1) * 2.5
				bridge_center.y = 1.0
				var bridge_size := Vector3(2, 1, 2)
				var bridge_pos := _snap_block_pos(bridge_center - bridge_size * 0.5, bridge_size)
				if b == 0 or b == bridge_len - 1:
					_spawn_octagonal_prism(bridge_pos, bridge_size)
				elif b == bridge_len / 2:
					var cross_dir := Vector3(-bridge_dir_vec.z, 0, bridge_dir_vec.x)
					_spawn_arch(bridge_center - bridge_size * 0.5 - cross_dir * 1.5, Vector3(5, 3, 3), 0.25)
					level_root_position_table.append(bridge_center + cross_dir * 1.5)
				else:
					_spawn_box(bridge_pos, bridge_size)
				level_root_position_table.append(bridge_center)

	if r.randf() > 0.5:
		var pillar_count := r.randi_range(3, 5)
		for p in range(pillar_count):
			var pa := r.randf_range(0, PI * 2)
			var pd := r.randf_range(10, 22)
			var ppos := Vector3(cos(pa) * pd, 1.0, sin(pa) * pd)
			var psize := Vector3(2, r.randf_range(3, 6), 2)
			_spawn_cylinder(ppos - psize * 0.5, psize, 8)
			level_root_position_table.append(ppos)

	var volcano_size := Vector3(r.randf_range(6, 10), r.randf_range(4, 6), r.randf_range(6, 10))
	volcano_size = snapped(volcano_size, Vector3.ONE)
	volcano_size.y = max(volcano_size.y, 3)
	var volcano_center := Vector3(br.randf_range(-8, 8), 1.0, br.randf_range(-8, 8))
	var inner_r := 1.0
	var outer_r := volcano_size.x * 0.5
	var ring_height := volcano_size.y
	_spawn_ring_segment(volcano_center, inner_r, outer_r, ring_height)
	level_root_position_table.append(volcano_center + Vector3(0, ring_height * 0.5, 0))

	_spawn_staircase(volcano_center + Vector3(-outer_r * 0.5, 0, -outer_r - 2), Vector3(outer_r, ring_height * 0.4, 3), randi_range(3, 5), Vector3.FORWARD)
	level_root_position_table.append(volcano_center + Vector3(0, 0, -outer_r - 1))

	var volcano_platform := volcano_center + Vector3(0, ring_height, 0)
	var plat_size := Vector3(4, 1, 4)
	_spawn_cross_platform(volcano_platform - Vector3(2, 0, 2), plat_size, 0.3)
	level_root_position_table.append(volcano_platform)

	var star_pos := volcano_platform + Vector3(0, 4.0, 0)
	var new_star := SOGlobal.generate_power_star("main", star_pos) as PowerStar
	new_star.main_star = true
	new_star._activate_star()


# ---- Custom Mesh System ----

func _spawn_custom_block(
	position: Vector3,
	block_size: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	surface_type: int = -1,
	move_type_val: LevelBlock.move_type = LevelBlock.move_type.NONE,
	continuous_rot: Vector3 = Vector3.ZERO,
	collision_size: Vector3 = Vector3.ZERO
) -> LevelBlock:

	var new_block := LevelBlock.new()
	new_block.block_size = block_size
	new_block.position = position
	SOGlobal.level_bounds = SOGlobal.level_bounds.expand(position)

	var arr_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_block.mesh = arr_mesh
	new_block.material_override = SOGlobal.block_material

	SOGlobal.add_child(new_block)

	var st := LibSM64.SURFACE_DEFAULT
	if SOGlobal.current_theme:
		st = SOGlobal.current_theme.default_surface_type
	var surface_properties := LibSM64SurfacePropertiesComponent.new()
	surface_properties.surface_properties = LibSM64SurfaceProperties.new()
	surface_properties.surface_properties.surface_type = surface_type if surface_type >= 0 else st
	new_block.add_child(surface_properties)

	new_block.set_instance_shader_parameter("fade_in", (float(Time.get_ticks_msec()) / 1000) + float(SOGlobal.level_meshes.size()) * 0.01 + 0.2)
	new_block.set_instance_shader_parameter("spawn_dir", Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
	new_block.set_instance_shader_parameter("spawn_pos", new_block.position)
	new_block.set_instance_shader_parameter("fade_in_distance", randf_range(2, 10))
	new_block.set_instance_shader_parameter("fade_in_duration", randf_range(0.3, 0.8))

	var new_collider := StaticBody3D.new()
	var new_collider_shape := CollisionShape3D.new()
	var new_box_shape: Shape3D
	if collision_size != Vector3.ZERO:
		new_box_shape = BoxShape3D.new()
		new_box_shape.size = collision_size
	else:
		new_box_shape = arr_mesh.create_convex_shape(true, false)
	new_collider_shape.shape = new_box_shape
	new_collider.set_collision_layer_value(1, true)
	new_collider.set_collision_mask_value(1, true)
	new_block.add_child(new_collider)
	new_collider.add_child(new_collider_shape)

	if move_type_val != LevelBlock.move_type.NONE:
		if continuous_rot != Vector3.ZERO:
			new_block.continuous_rotation = continuous_rot
		new_block._change_block_move_mode(move_type_val)

	SOGlobal.level_meshes.append(new_block)
	return new_block


func _scale_verts(verts: PackedVector3Array, size: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		out[i] = verts[i] * size
	return out


func _face_normals(verts: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in range(0, verts.size(), 3):
		var a := verts[i]
		var b := verts[i + 1]
		var c := verts[i + 2]
		var n := (b - a).cross(c - a).normalized()
		out[i] = n
		out[i + 1] = n
		out[i + 2] = n
	return out


func _face_uvs(vertices: PackedVector3Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	for i in range(0, vertices.size(), 3):
		var min_pos := vertices[i]
		var max_pos := vertices[i]
		for j in range(3):
			for axis in range(3):
				min_pos[axis] = min(min_pos[axis], vertices[i + j][axis])
				max_pos[axis] = max(max_pos[axis], vertices[i + j][axis])
		var face_size := max_pos - min_pos
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		var n := (b - a).cross(c - a).normalized()
		var abs_n := Vector3(abs(n.x), abs(n.y), abs(n.z))
		for j in range(3):
			var v := vertices[i + j] - min_pos
			var u: float
			var vt: float
			if abs_n.y >= abs_n.x and abs_n.y >= abs_n.z:
				u = v.x / max(face_size.x, 0.001)
				vt = v.z / max(face_size.z, 0.001)
			elif abs_n.x >= abs_n.z:
				u = v.z / max(face_size.z, 0.001)
				vt = v.y / max(face_size.y, 0.001)
			else:
				u = v.x / max(face_size.x, 0.001)
				vt = v.y / max(face_size.y, 0.001)
			uvs[i + j] = Vector2(u, vt)
	return uvs


# ---- Shape Generators ----

func _spawn_box(position: Vector3, size: Vector3) -> LevelBlock:
	return SOGlobal.generate_block_from_pos_and_size(
		_snap_block_pos(position, size), size
	)


func _spawn_wedge(position: Vector3, size: Vector3, direction: Vector3 = Vector3.FORWARD) -> LevelBlock:
	var verts := PackedVector3Array()
	var use_z := abs(direction.z) >= abs(direction.x)
	var pos_dir := (direction.z >= 0) if use_z else (direction.x >= 0)

	if use_z:
		var f0 := Vector3(-0.5, -0.5, -0.5)
		var f1 := Vector3(0.5, -0.5, -0.5)
		var f2 := Vector3(0.5, 0.5, -0.5)
		var f3 := Vector3(-0.5, 0.5, -0.5)
		var b0 := Vector3(-0.5, -0.5, 0.5)
		var b1 := Vector3(0.5, -0.5, 0.5)
		if pos_dir:
			verts.push_back(f0); verts.push_back(f1); verts.push_back(f2)
			verts.push_back(f0); verts.push_back(f2); verts.push_back(f3)
			verts.push_back(f3); verts.push_back(f2); verts.push_back(b1)
			verts.push_back(f3); verts.push_back(b1); verts.push_back(b0)
			verts.push_back(f0); verts.push_back(f3); verts.push_back(b0)
			verts.push_back(f1); verts.push_back(b1); verts.push_back(f2)
			verts.push_back(f0); verts.push_back(b1); verts.push_back(f1)
			verts.push_back(f0); verts.push_back(b0); verts.push_back(b1)
		else:
			verts.push_back(b0); verts.push_back(b1); verts.push_back(f2)
			verts.push_back(b0); verts.push_back(f2); verts.push_back(f3)
			verts.push_back(b0); verts.push_back(f3); verts.push_back(f0)
			verts.push_back(b1); verts.push_back(f1); verts.push_back(f2)
			verts.push_back(f3); verts.push_back(f2); verts.push_back(f1)
			verts.push_back(f3); verts.push_back(f1); verts.push_back(f0)
			verts.push_back(b0); verts.push_back(b1); verts.push_back(f1)
			verts.push_back(b0); verts.push_back(f1); verts.push_back(f0)
	else:
		var f0 := Vector3(-0.5, -0.5, -0.5)
		var f1 := Vector3(-0.5, -0.5, 0.5)
		var f2 := Vector3(-0.5, 0.5, 0.5)
		var f3 := Vector3(-0.5, 0.5, -0.5)
		var b0 := Vector3(0.5, -0.5, -0.5)
		var b1 := Vector3(0.5, -0.5, 0.5)
		if pos_dir:
			verts.push_back(f0); verts.push_back(f1); verts.push_back(f2)
			verts.push_back(f0); verts.push_back(f2); verts.push_back(f3)
			verts.push_back(f3); verts.push_back(f2); verts.push_back(b1)
			verts.push_back(f3); verts.push_back(b1); verts.push_back(b0)
			verts.push_back(f0); verts.push_back(f3); verts.push_back(b0)
			verts.push_back(f1); verts.push_back(b1); verts.push_back(f2)
			verts.push_back(f0); verts.push_back(b1); verts.push_back(f1)
			verts.push_back(f0); verts.push_back(b0); verts.push_back(b1)
		else:
			verts.push_back(b0); verts.push_back(b1); verts.push_back(f2)
			verts.push_back(b0); verts.push_back(f2); verts.push_back(f3)
			verts.push_back(b0); verts.push_back(f3); verts.push_back(f0)
			verts.push_back(b1); verts.push_back(f1); verts.push_back(f2)
			verts.push_back(f3); verts.push_back(f2); verts.push_back(f1)
			verts.push_back(f3); verts.push_back(f1); verts.push_back(f0)
			verts.push_back(b0); verts.push_back(b1); verts.push_back(f1)
			verts.push_back(b0); verts.push_back(f1); verts.push_back(f0)

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs)


func _spawn_pyramid(position: Vector3, size: Vector3) -> LevelBlock:
	var hw := 0.5; var hh := 0.5; var hd := 0.5
	var verts := PackedVector3Array()
	var tip := Vector3(0, hh, 0)
	var b0 := Vector3(-hw, -hh, -hd)
	var b1 := Vector3(hw, -hh, -hd)
	var b2 := Vector3(hw, -hh, hd)
	var b3 := Vector3(-hw, -hh, hd)

	verts.push_back(b0); verts.push_back(b1); verts.push_back(tip)  # front
	verts.push_back(b1); verts.push_back(b2); verts.push_back(tip)  # right
	verts.push_back(b2); verts.push_back(b3); verts.push_back(tip)  # back
	verts.push_back(b3); verts.push_back(b0); verts.push_back(tip)  # left
	verts.push_back(b0); verts.push_back(b2); verts.push_back(b1)  # bottom tri 1
	verts.push_back(b0); verts.push_back(b3); verts.push_back(b2)  # bottom tri 2

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs)


func _spawn_octagonal_prism(position: Vector3, size: Vector3) -> LevelBlock:
	var hw := 0.5; var hd := 0.5
	var hh := 0.5
	var verts := PackedVector3Array()
	var sides := 8
	var verts_bottom: Array[Vector3] = []
	var verts_top: Array[Vector3] = []
	for i in sides:
		var a := float(i) / sides * PI * 2
		var x := cos(a) * hw
		var z := sin(a) * hd
		verts_bottom.append(Vector3(x, -hh, z))
		verts_top.append(Vector3(x, hh, z))

	for i in sides:
		var ni := (i + 1) % sides
		verts.push_back(verts_bottom[i]); verts.push_back(verts_bottom[ni]); verts.push_back(verts_top[i])
		verts.push_back(verts_top[i]); verts.push_back(verts_bottom[ni]); verts.push_back(verts_top[ni])
		verts.push_back(verts_bottom[i]); verts.push_back(verts_top[i]); verts.push_back(verts_top[ni])

	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[2]); verts.push_back(verts_bottom[1])
	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[3]); verts.push_back(verts_bottom[2])
	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[4]); verts.push_back(verts_bottom[3])
	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[5]); verts.push_back(verts_bottom[4])
	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[6]); verts.push_back(verts_bottom[5])
	verts.push_back(verts_bottom[0]); verts.push_back(verts_bottom[7]); verts.push_back(verts_bottom[6])

	verts.push_back(verts_top[0]); verts.push_back(verts_top[1]); verts.push_back(verts_top[2])
	verts.push_back(verts_top[0]); verts.push_back(verts_top[2]); verts.push_back(verts_top[3])
	verts.push_back(verts_top[0]); verts.push_back(verts_top[3]); verts.push_back(verts_top[4])
	verts.push_back(verts_top[0]); verts.push_back(verts_top[4]); verts.push_back(verts_top[5])
	verts.push_back(verts_top[0]); verts.push_back(verts_top[5]); verts.push_back(verts_top[6])
	verts.push_back(verts_top[0]); verts.push_back(verts_top[6]); verts.push_back(verts_top[7])

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs)


func _spawn_cross_platform(position: Vector3, size: Vector3, arm_width: float = 0.3) -> LevelBlock:
	var hw := 0.5; var hd := 0.5; var hh := 0.5
	var aw := arm_width * 0.5
	var verts := PackedVector3Array()

	# Center block
	var c0 := Vector3(-aw, -hh, -aw)
	var c1 := Vector3(aw, -hh, -aw)
	var c2 := Vector3(aw, -hh, aw)
	var c3 := Vector3(-aw, -hh, aw)
	var c4 := Vector3(-aw, hh, -aw)
	var c5 := Vector3(aw, hh, -aw)
	var c6 := Vector3(aw, hh, aw)
	var c7 := Vector3(-aw, hh, aw)
	# 6 faces of center cube
	var add_face := func(a, b, c, d):
		verts.push_back(a); verts.push_back(b); verts.push_back(c)
		verts.push_back(a); verts.push_back(c); verts.push_back(d)
	add_face.call(c0, c1, c5, c4)  # front
	add_face.call(c1, c2, c6, c5)  # right
	add_face.call(c3, c2, c6, c7)  # back
	add_face.call(c0, c3, c7, c4)  # left
	add_face.call(c4, c5, c6, c7)  # top
	add_face.call(c0, c1, c2, c3)  # bottom

	# X arm
	var x0 := Vector3(-hw, -hh, -aw)
	var x1 := Vector3(hw, -hh, -aw)
	var x2 := Vector3(hw, -hh, aw)
	var x3 := Vector3(-hw, -hh, aw)
	var x4 := Vector3(-hw, hh, -aw)
	var x5 := Vector3(hw, hh, -aw)
	var x6 := Vector3(hw, hh, aw)
	var x7 := Vector3(-hw, hh, aw)
	add_face.call(x0, x1, x5, x4)
	add_face.call(x1, x2, x6, x5)
	add_face.call(x3, x2, x6, x7)
	add_face.call(x0, x3, x7, x4)
	add_face.call(x4, x5, x6, x7)
	add_face.call(x0, x1, x2, x3)
	# Remove overlapping center faces by... not bothering, they'll z-fight but be hidden

	# Z arm
	var z0 := Vector3(-aw, -hh, -hd)
	var z1 := Vector3(aw, -hh, -hd)
	var z2 := Vector3(aw, -hh, hd)
	var z3 := Vector3(-aw, -hh, hd)
	var z4 := Vector3(-aw, hh, -hd)
	var z5 := Vector3(aw, hh, -hd)
	var z6 := Vector3(aw, hh, hd)
	var z7 := Vector3(-aw, hh, hd)
	add_face.call(z0, z1, z5, z4)
	add_face.call(z1, z2, z6, z5)
	add_face.call(z3, z2, z6, z7)
	add_face.call(z0, z3, z7, z4)
	add_face.call(z4, z5, z6, z7)
	add_face.call(z0, z1, z2, z3)

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs)


func _spawn_crenellated_block(position: Vector3, size: Vector3, teeth: int = 3) -> LevelBlock:
	var hw := 0.5; var hd := 0.5; var hh := 0.5
	var verts := PackedVector3Array()

	var add_face := func(a, b, c, d):
		verts.push_back(a); verts.push_back(b); verts.push_back(c)
		verts.push_back(a); verts.push_back(c); verts.push_back(d)

	# Base block
	var b0 := Vector3(-hw, -hh, -hd)
	var b1 := Vector3(hw, -hh, -hd)
	var b2 := Vector3(hw, -hh, hd)
	var b3 := Vector3(-hw, -hh, hd)
	var b4 := Vector3(-hw, -hh * 0.5, -hd)
	var b5 := Vector3(hw, -hh * 0.5, -hd)
	var b6 := Vector3(hw, -hh * 0.5, hd)
	var b7 := Vector3(-hw, -hh * 0.5, hd)
	add_face.call(b0, b1, b5, b4)
	add_face.call(b1, b2, b6, b5)
	add_face.call(b3, b2, b6, b7)
	add_face.call(b0, b3, b7, b4)
	add_face.call(b4, b5, b6, b7)
	add_face.call(b0, b1, b2, b3)

	# Teeth along Z axis
	var tooth_width: float = (hw * 2) / max(teeth * 2, 1)
	for t in range(teeth):
		var tx := -hw + t * tooth_width * 2
		var t0 := Vector3(tx, -hh * 0.5, -hd)
		var t1 := Vector3(tx + tooth_width, -hh * 0.5, -hd)
		var t2 := Vector3(tx + tooth_width, -hh * 0.5, hd)
		var t3 := Vector3(tx, -hh * 0.5, hd)
		var t4 := Vector3(tx, hh, -hd)
		var t5 := Vector3(tx + tooth_width, hh, -hd)
		var t6 := Vector3(tx + tooth_width, hh, hd)
		var t7 := Vector3(tx, hh, hd)
		add_face.call(t0, t1, t5, t4)
		add_face.call(t1, t2, t6, t5)
		add_face.call(t3, t2, t6, t7)
		add_face.call(t0, t3, t7, t4)
		add_face.call(t4, t5, t6, t7)
		add_face.call(t0, t1, t2, t3)

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs)


func _spawn_ring_segment(position: Vector3, inner_radius: float, outer_radius: float, height: float, segments: int = 8) -> LevelBlock:
	var verts := PackedVector3Array()
	for i in segments:
		var a1 := float(i) / segments * PI * 2
		var a2 := float(i + 1) / segments * PI * 2
		var ix1 := cos(a1) * inner_radius; var iz1 := sin(a1) * inner_radius
		var ox1 := cos(a1) * outer_radius; var oz1 := sin(a1) * outer_radius
		var ix2 := cos(a2) * inner_radius; var iz2 := sin(a2) * inner_radius
		var ox2 := cos(a2) * outer_radius; var oz2 := sin(a2) * outer_radius
		var ih := height * 0.5; var il := -height * 0.5

		# Outer face
		verts.push_back(Vector3(ox1, il, oz1)); verts.push_back(Vector3(ox2, il, oz2)); verts.push_back(Vector3(ox1, ih, oz1))
		verts.push_back(Vector3(ox1, ih, oz1)); verts.push_back(Vector3(ox2, il, oz2)); verts.push_back(Vector3(ox2, ih, oz2))
		# Inner face
		verts.push_back(Vector3(ix2, il, iz2)); verts.push_back(Vector3(ix1, il, iz1)); verts.push_back(Vector3(ix2, ih, iz2))
		verts.push_back(Vector3(ix2, ih, iz2)); verts.push_back(Vector3(ix1, il, iz1)); verts.push_back(Vector3(ix1, ih, iz1))
		# Top
		verts.push_back(Vector3(ix1, ih, iz1)); verts.push_back(Vector3(ox1, ih, oz1)); verts.push_back(Vector3(ix2, ih, iz2))
		verts.push_back(Vector3(ix2, ih, iz2)); verts.push_back(Vector3(ox1, ih, oz1)); verts.push_back(Vector3(ox2, ih, oz2))
		# Bottom
		verts.push_back(Vector3(ix2, il, iz2)); verts.push_back(Vector3(ox1, il, oz1)); verts.push_back(Vector3(ix1, il, iz1))
		verts.push_back(Vector3(ix2, il, iz2)); verts.push_back(Vector3(ox2, il, oz2)); verts.push_back(Vector3(ox1, il, oz1))

	var size := Vector3(outer_radius * 2, height, outer_radius * 2)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(verts)
	return _spawn_custom_block(position, size, verts, normals, uvs, -1, LevelBlock.move_type.NONE, Vector3.ZERO, size)


func _spawn_arch(position: Vector3, size: Vector3, thickness: float = 0.3) -> LevelBlock:
	var hw := 0.5; var hh := 0.5; var hd := 0.5
	var verts := PackedVector3Array()
	var tw := thickness * 0.5
	var segs := 12
	var inner_radius := hw - tw
	var outer_radius := hw

	for i in range(segs):
		var a1 := (float(i) / segs) * PI
		var a2 := (float(i + 1) / segs) * PI
		var ix1 := cos(a1) * inner_radius; var iz1 := sin(a1) * inner_radius
		var ix2 := cos(a2) * inner_radius; var iz2 := sin(a2) * inner_radius
		var ox1 := cos(a1) * outer_radius; var oz1 := sin(a1) * outer_radius
		var ox2 := cos(a2) * outer_radius; var oz2 := sin(a2) * outer_radius

		# Front face (z=-hd)
		verts.push_back(Vector3(ix1, iz1, -hd)); verts.push_back(Vector3(ox1, oz1, -hd)); verts.push_back(Vector3(ix2, iz2, -hd))
		verts.push_back(Vector3(ix2, iz2, -hd)); verts.push_back(Vector3(ox1, oz1, -hd)); verts.push_back(Vector3(ox2, oz2, -hd))
		# Back face (z=hd)
		verts.push_back(Vector3(ox1, oz1, hd)); verts.push_back(Vector3(ix1, iz1, hd)); verts.push_back(Vector3(ox2, oz2, hd))
		verts.push_back(Vector3(ox2, oz2, hd)); verts.push_back(Vector3(ix1, iz1, hd)); verts.push_back(Vector3(ix2, iz2, hd))
		# Outer surface
		verts.push_back(Vector3(ox1, oz1, -hd)); verts.push_back(Vector3(ox2, oz2, -hd)); verts.push_back(Vector3(ox1, oz1, hd))
		verts.push_back(Vector3(ox1, oz1, hd)); verts.push_back(Vector3(ox2, oz2, -hd)); verts.push_back(Vector3(ox2, oz2, hd))
		# Inner surface
		verts.push_back(Vector3(ix2, iz2, -hd)); verts.push_back(Vector3(ix1, iz1, -hd)); verts.push_back(Vector3(ix2, iz2, hd))
		verts.push_back(Vector3(ix2, iz2, hd)); verts.push_back(Vector3(ix1, iz1, -hd)); verts.push_back(Vector3(ix1, iz1, hd))
		# Bottom
		verts.push_back(Vector3(ix1, 0, -hd)); verts.push_back(Vector3(ox1, 0, -hd)); verts.push_back(Vector3(ix2, 0, -hd))
		verts.push_back(Vector3(ix2, 0, -hd)); verts.push_back(Vector3(ox1, 0, -hd)); verts.push_back(Vector3(ox2, 0, -hd))
		verts.push_back(Vector3(ox1, 0, hd)); verts.push_back(Vector3(ix1, 0, hd)); verts.push_back(Vector3(ox2, 0, hd))
		verts.push_back(Vector3(ox2, 0, hd)); verts.push_back(Vector3(ix1, 0, hd)); verts.push_back(Vector3(ix2, 0, hd))

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs, -1, LevelBlock.move_type.NONE, Vector3.ZERO, size)


func _spawn_staircase(position: Vector3, size: Vector3, steps: int = 4, direction: Vector3 = Vector3.FORWARD) -> LevelBlock:
	var verts := PackedVector3Array()
	var use_z := abs(direction.z) >= abs(direction.x)
	var pos_dir := (direction.z >= 0) if use_z else (direction.x >= 0)

	for s in range(steps):
		var t := float(s) / steps
		var t1 := float(s + 1) / steps
		if use_z:
			var z0 := -0.5 + t * (pos_dir if pos_dir else -1.0)
			var z1 := -0.5 + t1 * (pos_dir if pos_dir else -1.0)
			var y0 := -0.5
			var y1 := -0.5 + (t1 / steps) * (steps - 1)
			var yb := -0.5 + (t / steps) * (steps - 1)
			# Riser
			verts.push_back(Vector3(-0.5, yb, z0)); verts.push_back(Vector3(0.5, yb, z0)); verts.push_back(Vector3(-0.5, y1, z0))
			verts.push_back(Vector3(-0.5, y1, z0)); verts.push_back(Vector3(0.5, yb, z0)); verts.push_back(Vector3(0.5, y1, z0))
			# Tread
			verts.push_back(Vector3(-0.5, y1, z0)); verts.push_back(Vector3(0.5, y1, z0)); verts.push_back(Vector3(-0.5, y1, z1))
			verts.push_back(Vector3(-0.5, y1, z1)); verts.push_back(Vector3(0.5, y1, z0)); verts.push_back(Vector3(0.5, y1, z1))
		else:
			var x0 := -0.5 + t * (pos_dir if pos_dir else -1.0)
			var x1 := -0.5 + t1 * (pos_dir if pos_dir else -1.0)
			var y0 := -0.5
			var y1 := -0.5 + (t1 / steps) * (steps - 1)
			var yb := -0.5 + (t / steps) * (steps - 1)
			verts.push_back(Vector3(x0, yb, -0.5)); verts.push_back(Vector3(x0, yb, 0.5)); verts.push_back(Vector3(x0, y1, -0.5))
			verts.push_back(Vector3(x0, y1, -0.5)); verts.push_back(Vector3(x0, yb, 0.5)); verts.push_back(Vector3(x0, y1, 0.5))
			verts.push_back(Vector3(x0, y1, -0.5)); verts.push_back(Vector3(x0, y1, 0.5)); verts.push_back(Vector3(x1, y1, -0.5))
			verts.push_back(Vector3(x1, y1, -0.5)); verts.push_back(Vector3(x0, y1, 0.5)); verts.push_back(Vector3(x1, y1, 0.5))

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs, -1, LevelBlock.move_type.NONE, Vector3.ZERO, size)


func _spawn_cylinder(position: Vector3, size: Vector3, sides: int = 16) -> LevelBlock:
	var verts := PackedVector3Array()
	var hw := 0.5; var hd := 0.5; var hh := 0.5
	var verts_bottom: Array[Vector3] = []
	var verts_top: Array[Vector3] = []
	for i in sides:
		var a := float(i) / sides * PI * 2
		var x := cos(a) * hw
		var z := sin(a) * hd
		verts_bottom.append(Vector3(x, -hh, z))
		verts_top.append(Vector3(x, hh, z))

	for i in sides:
		var ni := (i + 1) % sides
		verts.push_back(verts_bottom[i]); verts.push_back(verts_bottom[ni]); verts.push_back(verts_top[i])
		verts.push_back(verts_top[i]); verts.push_back(verts_bottom[ni]); verts.push_back(verts_top[ni])

	# Bottom cap (fan from center-bottom)
	for i in range(1, sides - 1):
		verts.push_back(Vector3(0, -hh, 0)); verts.push_back(verts_bottom[i + 1]); verts.push_back(verts_bottom[i])
	# Top cap (fan from center-top)
	for i in range(1, sides - 1):
		verts.push_back(Vector3(0, hh, 0)); verts.push_back(verts_top[i]); verts.push_back(verts_top[i + 1])

	var scaled_verts := _scale_verts(verts, size)
	var uvs := _face_uvs(verts)
	var normals := _face_normals(scaled_verts)
	var pos := _snap_block_pos(position, size)
	return _spawn_custom_block(pos, size, scaled_verts, normals, uvs, -1, LevelBlock.move_type.NONE, Vector3.ZERO, size)


func _add_simple_collision(block: LevelBlock, size: Vector3) -> void:
	var collider := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	collider.set_collision_layer_value(1, true)
	collider.set_collision_mask_value(1, true)
	block.add_child(collider)
	collider.add_child(shape)


# ---- Helper: place block and get center ----
func _place_block(spawn_func: Callable, args: Array) -> LevelBlock:
	return spawn_func.call(args)


var _is_libsm64_init := false
var _pending_corks: Array[CorkBox] = []

func _create_mario_world(useSeed = str(randi())) -> void:

	SOGlobal.current_seed = useSeed

	var parsed_seed: String = useSeed
	SOGlobal.theme_override_index = -1
	if ":" in useSeed:
		var parts: PackedStringArray = useSeed.split(":", true, 2)
		parsed_seed = parts[0]
		if parts.size() > 1:
			var theme_name_override: String = parts[1].strip_edges()
			for i in SOGlobal.theme_list.size():
				if theme_name_override.to_lower() == SOGlobal.theme_list[i].theme_name.to_lower():
					SOGlobal.theme_override_index = i
					break

	SOGlobal.current_theme = SOGlobal.get_theme_for_seed(parsed_seed)
	useSeed = parsed_seed

	LibSM64.scale_factor = 110.0

	SOGlobal.total_coins = 0

	if _is_libsm64_init:
		for mesh in SOGlobal.level_meshes:
			if mesh and is_instance_valid(mesh):
				mesh.free()
		for node in SOGlobal.get_children():
			if node is BlockNametag:
				node.queue_free()
			if node is PowerStar:
				node.queue_free()
			if node is Coin:
				node.queue_free()
			if node is CorkBox:
				node.queue_free()
		SOGlobal.level_meshes.clear()
		LibSM64Global.terminate()

	_is_libsm64_init = LibSM64Global.init()

	var theme := SOGlobal.current_theme
	if theme:
		var texs = SOGlobal.theme_textures_cache.get(theme.theme_id)
		if texs:
			SOGlobal.block_material.set_shader_parameter("texture_albedo", texs["albedo"])
			SOGlobal.block_material.set_shader_parameter("side_texture_albedo", texs["side"])
			SOGlobal.block_material.set_shader_parameter("slope_texture_albedo", texs["slope"])
			SOGlobal.block_material.set_shader_parameter("apply_hue_shift", theme.theme_id == LevelTheme.ThemeID.DEFAULT)

	_generate_random_level(useSeed)

	await get_tree().create_timer(0.2).timeout

	SOGlobal.save_data.try_submit_save_block(useSeed)

	sm_64_static_surface_handler.load_static_surfaces()
	sm_64_surface_objects_handler.load_all_surface_objects()

	sm_64_mario.create()
	SOGlobal.level_start_time = Time.get_ticks_msec()
	sm_64_mario.preview_cam_yaw = 45
	sm_64_mario.preview_cam_pitch = -20
	sm_64_mario.preview_cam_zoom = 1
	sm_64_mario.preview_cam_pan_pitch = 0
	sm_64_mario.preview_cam_pan_yaw = 0
	sm_64_mario.ready_to_play = false

	if theme:
		var death_mat: ShaderMaterial = mesh_instance_3d.get_active_material(0) as ShaderMaterial
		if death_mat:
			death_mat.set_shader_parameter("death_color", theme.death_plane_color)
		world_environment.environment.fog_density = max(theme.fog_density, 0.0) if theme.fog_density >= 0 else world_environment.environment.fog_density
		world_environment.environment.fog_light_color = theme.fog_color
		world_environment.environment.ambient_light_color = theme.ambient_color
		directional_light.light_color = theme.light_color
		directional_light.rotation_degrees = theme.light_euler

	if ProjectSettings.get_setting("display/window/size/transparent") == true:
		world_environment.environment.sky.sky_material = null
		return

	var sky_random = RandomNumberGenerator.new()
	sky_random.seed = hash(useSeed)

	var sky_colors := Gradient.new()
	var use_sky_gradient: bool = theme and theme.sky_color_gradient != null
	if use_sky_gradient:
		sky_colors = theme.sky_color_gradient
	else:
		var color_count : int = sky_random.randi_range(3, 12)
		var avg_dist : float = 1.0 / color_count
		for i in range(color_count - 1):
			var hue : float = sky_random.randf_range(0, 1)
			var saturation : float = sky_random.randf_range(0.16, 0.75)
			var value : float = sky_random.randf_range(0.15, 0.6)
			var color_offset : float = avg_dist * 0.5 * sky_random.randf_range(-1, 1)
			var final_point_pos : float = float(i + 1) * avg_dist + color_offset
			sky_colors.add_point(final_point_pos, Color.from_hsv(hue, saturation, value))
		var hue : float = sky_random.randf_range(0, 1)
		var saturation : float = sky_random.randf_range(0.3, 1)
		var value : float = sky_random.randf_range(0.3, 1)
		sky_colors.add_point(0, Color.from_hsv(hue, saturation, value))
		sky_colors.add_point(0.999, Color.from_hsv(hue, saturation, value))

	var sky_ramp := Gradient.new()
	var use_sky_ramp: bool = theme and theme.sky_color_ramp != null
	if use_sky_ramp:
		sky_ramp = theme.sky_color_ramp
	else:
		var color_count : int = sky_random.randi_range(3, 12)
		var avg_dist : float = 1.0 / color_count
		for i in range(color_count - 1):
			var hue : float = sky_random.randf_range(0, 1)
			var saturation : float = sky_random.randf_range(0.2, 0.75)
			var value : float = sky_random.randf_range(0.2, 0.6)
			var color_offset : float = avg_dist * 0.5 * sky_random.randf_range(-1, 1)
			var final_point_pos : float = lerp(float(i + 1) * avg_dist + color_offset, 0.75, 0.5)
			sky_ramp.add_point(final_point_pos, Color.from_hsv(hue, saturation, value))
		var hue : float = sky_random.randf_range(0, 1)
		var saturation : float = sky_random.randf_range(0.6, 1)
		var value : float = sky_random.randf_range(0.01, 0.05)
		sky_ramp.add_point(0, Color.from_hsv(hue, saturation, value))
		sky_ramp.add_point(0.999, Color.from_hsv(hue, saturation, value))

	var sky_gradient_texture : GradientTexture2D = GradientTexture2D.new()
	sky_gradient_texture.width = 256
	sky_gradient_texture.height = 1
	sky_gradient_texture.fill_from = Vector2(-0.001, 0)
	sky_gradient_texture.fill_to = Vector2(1.001, 0)
	sky_gradient_texture.gradient = sky_colors

	var sky_ramp_texture : GradientTexture2D = GradientTexture2D.new()
	sky_ramp_texture.width = 256
	sky_ramp_texture.height = 1
	sky_ramp_texture.fill_from = Vector2(-0.001, 0)
	sky_ramp_texture.fill_to = Vector2(1.001, 0)
	sky_ramp_texture.gradient = sky_ramp

	if false:
		var debug_gradient : TextureRect = TextureRect.new()
		debug_gradient.size = Vector2(256, 256)
		debug_gradient.custom_minimum_size = Vector2(256, 256)
		debug_gradient.texture = sky_ramp_texture
		SOGlobal.add_child(debug_gradient)

	var bg_tex: Texture2D = null
	if theme:
		var texs = SOGlobal.theme_textures_cache.get(theme.theme_id)
		if texs and texs.get("background") != null:
			bg_tex = texs["background"]

	if bg_tex:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = bg_tex
		world_environment.environment.sky.sky_material = pano
	else:
		world_environment.environment.sky.sky_material = SOGlobal.sky_material
		SOGlobal.sky_material.set_shader_parameter("sky_color_ramp", sky_ramp_texture)
		var sky_noise_texture := NoiseTexture2D.new()
		sky_noise_texture.seamless = true
		if use_sky_gradient:
			sky_noise_texture.color_ramp = sky_colors
		var sky_noise := FastNoiseLite.new()
		sky_noise.seed = sky_random.randi()
		if theme:
			sky_noise.seed += theme.sky_noise_seed_offset
		sky_noise.noise_type = sky_random.randi_range(0, 5)
		sky_noise.fractal_type = sky_random.randi_range(0, 3)
		sky_noise.cellular_return_type = sky_random.randi_range(0, 6)
		sky_noise.cellular_distance_function = sky_random.randi_range(0, 3)
		sky_noise.domain_warp_enabled = bool(sky_random.randi_range(0, 1))
		sky_noise.domain_warp_fractal_type = sky_random.randi_range(0, 2)
		sky_noise.cellular_jitter = sky_random.randf_range(0.0, 3.0)
		sky_noise.domain_warp_amplitude = sky_random.randf_range(0, 60)
		sky_noise.domain_warp_fractal_gain = sky_random.randf_range(0.0, 2.0)
		sky_noise.domain_warp_fractal_lacunarity = sky_random.randf_range(0.0, 15.0)
		sky_noise.domain_warp_fractal_octaves = sky_random.randi_range(0, 5)
		sky_noise.domain_warp_frequency = sky_random.randf_range(0.0, 0.5)
		sky_noise.fractal_gain = sky_random.randf_range(0.0, 2.0)
		sky_noise.fractal_lacunarity = sky_random.randf_range(0.0, 4.0)
		sky_noise.fractal_octaves = sky_random.randi_range(0, 5)
		sky_noise.fractal_ping_pong_strength = sky_random.randf_range(0.0, 4.0)
		sky_noise.fractal_weighted_strength = sky_random.randf_range(0.0, 2.0)
		sky_noise.frequency = sky_random.randf_range(0.001, 0.05)
		sky_noise_texture.width = 256
		sky_noise_texture.height = 256
		sky_noise_texture.noise = sky_noise
		await sky_noise_texture.changed
		SOGlobal.sky_material.set_shader_parameter("sky_texture", sky_noise_texture)
	if !theme or theme.fog_density < 0:
		world_environment.environment.fog_density = sky_random.randf_range(0.0005, 0.01)
	if SOGlobal.compat_renderer:
		world_environment.environment.fog_light_energy *= 0.25

func _ready() -> void:
	_create_mario_world()
	SOGlobal.current_level_manager = self


func _on_tree_exiting() -> void:
#	pass
	# Clean up the `libsm64` world when the scene is freed.
	sm_64_mario.delete()
	LibSM64Global.terminate()


#func _process(delta):
	#pass
	#mesh_instance_3d.rotation = mesh_instance_3d.rotation + Vector3(0, 0.1 * delta, 0)
