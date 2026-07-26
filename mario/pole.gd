extends Node3D
class_name ClimbalePole

var POLE_HEIGHT : float = 5.25
var GRAB_DIST : float = 2.25
var RELEASE_DIST : float = 3.5
var FAST_GRAB_SPEED_THRESHOLD : float = 10.0

var pole_handle

func _ready() -> void:
	add_to_group("climbable_poles")
	_setup_pole()

func _setup_pole() -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "PoleStaticBody"
	static_body.add_to_group("libsm64_surface_objects")
	static_body.collision_layer = 0
	static_body.collision_mask = 0

	pole_handle = LibSM64.pole_create(global_position, POLE_HEIGHT, 0.0, 0.0, 0.0)
	static_body.set_meta("pole_handle", pole_handle)

	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1, POLE_HEIGHT, 1)

	add_child(static_body)
	tree_exiting.connect(_on_tree_exiting)

	var surface_props_comp := LibSM64SurfacePropertiesComponent.new()
	var surface_props := LibSM64SurfaceProperties.new()
	surface_props.surface_type = LibSM64.SURFACE_INTANGIBLE
	surface_props_comp.surface_properties = surface_props
	static_body.add_child(surface_props_comp)

func _on_tree_exiting() -> void:
	LibSM64.pole_destroy(pole_handle)

func try_grab(mario: LibSM64Mario) -> bool:
	var mario_pos = mario.global_position # I was trying to use .position here but it'd always snap me to the bottom or top of the pole
	var pole_pos = global_position

	var h_dist = Vector2(
		mario_pos.x - pole_pos.x,
		mario_pos.z - pole_pos.z
	).length()

	var can_grab = (
		h_dist < GRAB_DIST
		and mario_pos.y > pole_pos.y - 1.0
		and mario_pos.y < pole_pos.y + 6.5
	)

	var airborne = (
		mario.action == LibSM64.ACT_JUMP
		or mario.action == LibSM64.ACT_DOUBLE_JUMP
		or mario.action == LibSM64.ACT_FREEFALL
		or mario.action == LibSM64.ACT_SIDE_FLIP
		or mario.action == LibSM64.ACT_LONG_JUMP
		or mario.action == LibSM64.ACT_WALL_KICK_AIR
	)

	if can_grab and (Input.is_action_just_pressed(&"mario_a") or airborne):
		var snap_pos = Vector3(pole_pos.x, mario_pos.y, pole_pos.z)
		var fastGrab : bool = mario.velocity.length() > FAST_GRAB_SPEED_THRESHOLD
		print(mario.velocity.length())
		
		LibSM64.set_mario_velocity(mario.id, Vector3.ZERO)
		LibSM64.set_mario_forward_velocity(mario.id, 0.0)
		LibSM64.set_mario_position(mario.id, snap_pos)
		LibSM64.set_mario_action(mario.id, LibSM64.ACT_HOLDING_POLE)
		LibSM64.mario_attach_to_pole(mario.id, pole_handle, fastGrab)
		return true

	return false
