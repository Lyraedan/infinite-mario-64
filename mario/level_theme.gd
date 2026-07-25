class_name LevelTheme extends Resource

enum ThemeID {
	DEFAULT,
	BOBOMB_BATTLEFIELD,
	THWOMP_FORTRESS,
	SNOW_LAND,
	LAVA_FIRE_SEA,
	BOO_MANSION,
	DIRE_DIRE_DOCKS,
	INSIDE_CASTLE,
	OUTSIDE_CASTLE,
	OUTSIDE_CASTLE_BACK
}

const THEME_COUNT: int = 5

@export var theme_id: ThemeID = ThemeID.DEFAULT
@export var theme_name: String = "Default"
@export var display_name: String = "Infinite Mario 64"

@export var block_albedo_texture: Texture2D
@export var block_slope_texture: Texture2D

@export var block_color_gradient: Gradient
@export var sky_color_gradient: Gradient
@export var sky_color_ramp: Gradient
@export var sky_noise_seed_offset: int = 0

@export var fog_density: float = -1.0
@export var fog_color: Color = Color(1, 1, 1)

@export var ambient_color: Color = Color(0.52, 0.52, 0.52)
@export var light_color: Color = Color(1, 1, 1)
@export var light_euler: Vector3 = Vector3(-30, 45, 0)

@export var death_plane_color: Color = Color(1.0, 0.2, 0.2)
@export var background_music_path: String

@export var coin_tint: Color = Color(1, 0.8, 0.29)
@export var star_color: Color = Color(1.0, 0.75, 0.25)

@export var default_surface_type: int = 0

@export var iter_min: int = -1
@export var iter_max: int = -1
@export var block_width_min: float = -1
@export var block_width_max: float = -1
@export var block_height_max: float = -1
@export var block_length_min: float = -1
@export var block_length_max: float = -1
@export var pillar_chance: float = -1
@export var slope_chance_north: float = -1
@export var slope_chance_east: float = -1
@export var slope_chance_south: float = -1
@export var slope_chance_west: float = -1
@export var max_slope: int = -1
@export var mirror_chance_mult: float = 1.0
@export var moving_block_chance_mult: float = 1.0
@export var coin_density_mult: float = 1.0
