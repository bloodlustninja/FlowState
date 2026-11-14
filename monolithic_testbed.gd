extends Node3D

# ==============================================================================
# FLOWSTATE: MASTER ARCADE RACER (AUTO MODELLISTA / INITIAL D ANIME STYLE)
# Hero Comic White Muscle Car + Vibrant Daytime Cobalt Sky + Light Anime Tarmac +
# Stepped 2-Tone Cel Shading + Blazing Taillights + Inky Drop Shadows +
# True Physical Bounding Collisions + Zero-Clipping Traffic AI + Natural Steering
# ==============================================================================

# --- ROAD CONFIGURATION ---
const ROAD_WIDTH: float = 20.0                # 20m Wide 4-Lane Highway
const CHUNK_LENGTH: float = 120.0
const CHUNK_SEGMENTS: int = 40
const NUM_CHUNKS: int = 4
const LANE_OFFSETS: Array[float] = [-6.6, -2.2, 2.2, 6.6]

# --- VEHICLE HANDLING & PHYSICS ---
const CRUISE_SPEED: float = 46.0              # ~165 KM/H
const BOOST_SPEED: float = 58.0               # ~210 KM/H
const BRAKE_SPEED: float = 28.0               # ~100 KM/H
const MAX_LAT_SPEED: float = 22.0             # Responsive lane transitions
const LATERAL_LIMIT: float = 8.6              # Guardrail collision limit
const TIRE_RADIUS: float = 0.35

# --- EXACT VEHICLE BOUNDS (SCALED 0.72) ---
const HERO_HALF_W: float = 1.015              # Scaled half-width of White Muscle car
const HERO_HALF_L: float = 2.18               # Scaled half-length of White Muscle car

# --- ANIME PALETTE (AUTO MODELLISTA / INITIAL D DAYLIGHT HIGHWAY) ---
const COLOR_SKY_TOP: Color = Color(0.08, 0.36, 0.92)       # Radiant Anime Cobalt Blue
const COLOR_SKY_HORIZON: Color = Color(0.55, 0.82, 0.98)   # Crisp Anime Sky Cyan
const COLOR_GROUND_INK: Color = Color(0.18, 0.22, 0.30)    # Distant Terrain Slate
const COLOR_SUN: Color = Color(1.0, 0.98, 0.92)            # Brilliant White Sun
const COLOR_CLIFF_SUN: Color = Color(0.24, 0.44, 0.28)     # Rich Sunlit Anime Pine Green
const COLOR_CLIFF_SHADOW: Color = Color(0.12, 0.22, 0.16)  # Deep Mountain Shade
const COLOR_BARRIER: Color = Color(0.70, 0.74, 0.80)       # Matte Galvanized Track Barrier (prevents bloom flare)
const COLOR_BARRIER_CAP: Color = Color(0.92, 0.18, 0.15)   # Safety Red Rumble Cap
const COLOR_PLAYER_CAR: Color = Color(0.941, 0.937, 0.918)  # Warm paper white/cream #F0EFEA
const COLOR_ANIME_SHADOW: Color = Color(0.196, 0.208, 0.290) # Cool slate violet/indigo #32354A

# Game States
enum GameState { START, RACING, CRASHED }
var current_state: GameState = GameState.START

# Skid Decals Data & Object Pool
class SkidDecal:
	var node: MeshInstance3D
	var time_left: float = 0.0

const SKID_POOL_SIZE: int = 64
var skid_pool: Array[SkidDecal] = []
var skid_pool_idx: int = 0
var last_skid_drop_z: float = 999999.0
var skid_quad_mesh: QuadMesh
var skid_shared_mat: StandardMaterial3D

# Spark & Spray Object Pools
const DIFFUSER_SPARK_POOL_SIZE: int = 12
var diffuser_spark_pool: Array[MeshInstance3D] = []
var diffuser_spark_idx: int = 0

const GUARDRAIL_SPARK_POOL_SIZE: int = 8
var guardrail_spark_pool: Array[MeshInstance3D] = []
var guardrail_spark_idx: int = 0

const WATER_SPRAY_POOL_SIZE: int = 12
var water_spray_pool: Array[MeshInstance3D] = []
var water_spray_idx: int = 0

# Sky Radiance Update Throttling
var last_sky_update_progress: float = -999.0

# Nodes & Rig Components
var car_root: Node3D
var visual_rig: Node3D
var follow_cam: Camera3D
var player_shadow: MeshInstance3D
var smoke_left: CPUParticles3D
var smoke_right: CPUParticles3D
var trail_left: MeshInstance3D
var trail_right: MeshInstance3D
var trail_mesh_l: PlaneMesh
var trail_mesh_r: PlaneMesh
var spoiler_streak_l: MeshInstance3D
var spoiler_streak_r: MeshInstance3D
var exhaust_flame_l: MeshInstance3D
var exhaust_flame_r: MeshInstance3D
var exhaust_bumper_flash: OmniLight3D
var world_env_resource: Environment
var sun_light: DirectionalLight3D

# Visual & VFX Timers & State
var smoke_step_timer: float = 0.0
var backfire_timer: float = 0.0
var backfire_light_timer: float = 0.0
var prev_hud_gear: int = 1
var prev_speed_for_pop: float = 0.0
var current_cam_roll: float = 0.0
var chunk_spawn_count: int = 0
var active_tunnel_intervals: Array[Vector2] = []

static var gantry_sign_mat: StandardMaterial3D
static var smoke_puff_shader: Shader
static var smoke_puff_mat: ShaderMaterial
static var toon_flame_shader: Shader
static var toon_flame_mat: ShaderMaterial
static var tunnel_concrete_mat: StandardMaterial3D
static var tunnel_rib_mat: StandardMaterial3D
static var tunnel_fluor_mat: StandardMaterial3D
static var tunnel_pool_mat: StandardMaterial3D

# --- MANGA COMIC CUT-IN PANEL ---
var cutin_container: Control
var cutin_subviewport: SubViewport
var cutin_cam: Camera3D
var cutin_title_label: Label
var cutin_tween: Tween
var cutin_cooldown: float = 0.0
var cutin_active: bool = false

# --- GUARDRAIL SPARK WEDGES ---
static var spark_shader: Shader
static var spark_mat: ShaderMaterial
var is_scraping_guardrail: bool = false
var spark_spawn_timer: float = 0.0

# --- DYNAMIC ANIME WEATHER CYCLE ---
enum WeatherState { SUNNY, RAIN, SNOW }
var current_weather: WeatherState = WeatherState.SUNNY
var weather_timer: float = 38.0
var is_raining: bool = false
var is_snowing: bool = false
var hud_rain_overlay: ColorRect
var hud_snow_overlay: ColorRect
static var rain_shader: Shader
static var rain_mat: ShaderMaterial
static var snow_shader: Shader
static var snow_overlay_mat: ShaderMaterial
static var water_spray_shader: Shader
static var water_spray_mat: ShaderMaterial

# --- DIFFUSER GROUND SPARK BURSTS ---
static var diffuser_spark_mesh: ArrayMesh
static var diffuser_spark_mat_white: StandardMaterial3D
static var diffuser_spark_mat_amber: StandardMaterial3D
var diffuser_spark_timer: float = 0.0

# --- SPOILER WINGTIP VORTEX SHADER ---
static var wingtip_vortex_shader: Shader
static var wingtip_vortex_mat: ShaderMaterial

# --- MANGA TANKŌBON RESULTS COVER ---
var hud_tankobon_cover: Control
var hud_grade_badge: Label
var hud_comic_stats_label: Label
var hud_retry_btn: Button
var crash_orbit_active: bool = false
var crash_orbit_timer: float = 0.0
var crash_orbit_angle: float = 0.0
var tankobon_shown: bool = false

# --- HIGHWAY ENVIRONMENTAL MICRO-HAZARDS ---
class TrafficConeData:
	var node: Node3D
	var global_z: float
	var global_x: float
	var hit: bool = false

var active_traffic_cones: Array[TrafficConeData] = []

class FlyingCone:
	var node: Node3D
	var velocity: Vector3
	var ang_velocity: Vector3
	var time_left: float

var active_flying_cones: Array[FlyingCone] = []

class TollGateBarrier:
	var lane_x: float
	var boom_node: Node3D
	var sign_node: MeshInstance3D
	var is_open_lane: bool = false
	var broken: bool = false

class TollPlazaData:
	var global_z: float
	var open_lane_x: float
	var toll_node: Node3D
	var gates: Array[TollGateBarrier] = []
	var passed: bool = false

var active_toll_plazas: Array[TollPlazaData] = []

class ConstructionZoneData:
	var global_z_start: float
	var global_z_end: float
	var cordoned_x: float

var active_construction_zones: Array[ConstructionZoneData] = []

# --- RAIN PUDDLES & AQUAPLANING DATA ---
class PuddleData:
	var node: Node3D
	var global_z: float
	var global_x: float
	var splashed: bool = false

var active_puddles: Array[PuddleData] = []
static var puddle_mat: StandardMaterial3D

# --- SEASONAL WEATHER PARTICLES (TEXTURED LEAVES & 3-LAYER 3D SNOW) ---
var leaf_particles: CPUParticles3D
var snow_layer_near: CPUParticles3D
var snow_layer_mid: CPUParticles3D
var snow_layer_far: CPUParticles3D
static var leaf_mat: StandardMaterial3D
static var snow_mat: StandardMaterial3D
static var leaf_green_tex: Texture2D
static var leaf_autumn_tex: Texture2D
static var snowflake_tex: Texture2D
static var foliage_sheet_tex: Texture2D
var weather_transition_tween: Tween
var current_wet_refl: float = 0.0

# --- MID-RACE ANIME RADIO CHATTER HUD ---
var hud_radio_chatter: Control
var hud_radio_speaker_label: Label
var hud_radio_text_label: Label
var radio_chatter_tween: Tween

# --- HIGHWAY PATROL PURSUIT EVASION EVENT ---
var patrol_evasion_active: bool = false
var patrol_evasion_timer: float = 0.0
var patrol_evaded_cars: int = 0
var patrol_cooldown: float = 8.0

# --- TUNNEL ACOUSTICS & BACKFIRE DYNAMIC ILLUMINATION ---
var is_in_tunnel: bool = false
var tunnel_backfire_light: OmniLight3D
var tunnel_backfire_light_timer: float = 0.0

# --- SYNTHESIZED PROCEDURAL ARCADE AUDIO ---
var proc_audio_player: AudioStreamPlayer
var proc_audio_playback: AudioStreamGeneratorPlayback

# --- PRODUCTION ARCADE AUDIO SYSTEM ---
var rally_music_player: AudioStreamPlayer
var radio_chatter_player: AudioStreamPlayer
var rival_entry_player: AudioStreamPlayer
var engine_audio_player: AudioStreamPlayer
var gear_shift_player: AudioStreamPlayer
var drift_audio_player: AudioStreamPlayer
var crash_audio_player: AudioStreamPlayer

var stream_rally_music: AudioStream
var stream_radio_chatter: AudioStream
var stream_rival_entry: AudioStream
var stream_engine_loop: AudioStream
var stream_gear_upshift: AudioStream
var stream_tire_drift: AudioStream
var stream_car_crash: AudioStream

var radio_chatter_cooldown: float = 0.0
var _audio_unlocked: bool = false

# In-Car Future Funk Radio Track Timestamps (for continuous shuffle)
const RALLY_TRACKS: Array[Dictionary] = [
	{"title": "Tim Legend — Soda City Funk", "start": 0.0, "end": 83.0},
	{"title": "Bastetrak — Def Insanity", "start": 83.0, "end": 180.0},
	{"title": "Desired — Emotions", "start": 180.0, "end": 240.0},
	{"title": "DIGITAL WAVES — Fresh", "start": 240.0, "end": 317.0},
	{"title": "Pop Up! — Keepin' your love", "start": 317.0, "end": 378.0},
	{"title": "Macross 82-99 — 82.99 F.M", "start": 378.0, "end": 463.0},
	{"title": "コンシャスTHOUGHTS — Star Struck", "start": 463.0, "end": 509.0},
	{"title": "眠 / Lopu$ — I blame you (remix)", "start": 509.0, "end": 562.0},
	{"title": "眠, Aevv, Lopu$ — Love Letter", "start": 562.0, "end": 629.0},
	{"title": "Groovy Kaiju — Take Me Back to Shinjuku", "start": 629.0, "end": 672.0},
	{"title": "AnTgry — DANCE!", "start": 672.0, "end": 716.0},
	{"title": "Android52 — Eternal Groove", "start": 716.0, "end": 789.0},
	{"title": "ナイト Naito — Talk About Love", "start": 789.0, "end": 863.0},
	{"title": "Macross 82-99 — Dance!", "start": 863.0, "end": 908.0},
	{"title": "Castle Carousel — yachtpop", "start": 908.0, "end": 976.0},
	{"title": "Skule Toyama — Hot Chance", "start": 976.0, "end": 1028.0},
	{"title": "Yung Bae — Welcome to the Disco (feat. Macross 82-99)", "start": 1028.0, "end": 1081.0},
	{"title": "LORDSUN — 手さぐりのBREAK", "start": 1081.0, "end": 1164.0},
	{"title": "Yung Bae — I can tell", "start": 1164.0, "end": 1248.0},
	{"title": "Macross 82-99 — Tokyo Bounce (feat. Vantage)", "start": 1248.0, "end": 1298.0},
	{"title": "Castle Carousel — Internet Moms", "start": 1298.0, "end": 1358.0},
	{"title": "Dan Mason ダン・メイソン x Aritus — Kensaku Love", "start": 1358.0, "end": 1422.0},
	{"title": "Night Tempo — Two of us", "start": 1422.0, "end": 1486.0},
	{"title": "Downtown 溝", "start": 1486.0, "end": 1532.0}
]

var current_rally_track_idx: int = -1
var current_rally_track_end: float = 0.0
var playlist_volume: float = 0.425 # Reduced by 15% from 0.50
var rally_track_hud_box: Control
var rally_track_hud_label: Label
var rally_track_hud_tween: Tween

var prev_player_z_joint: float = 0.0
var camera_pitch_kick: float = 0.0
var hero_body_shader_mat: ShaderMaterial
var spoiler_mats: Array[ShaderMaterial] = []
var exhaust_tip_l: MeshInstance3D
var exhaust_tip_r: MeshInstance3D

# Dynamic Day/Night Cycle & Lighting State
var day_cycle_progress: float = 0.28 # Default soft sunset anime gradient (0.0 = Noon, 0.32 = Dusk, 0.60 = Night, 0.85 = Dawn)
var day_cycle_duration: float = 80.0
var night_factor: float = 0.0 # 0.0 (Day) to 1.0 (Full Night)
var tod_mode: int = 0 # 0 = AUTO, 1 = NOON, 2 = DUSK, 3 = NIGHT
var procedural_sky_mat: ProceduralSkyMaterial

# Vehicle Headlights & Highway Sodium Pools
var hero_headlight_l: SpotLight3D
var hero_headlight_r: SpotLight3D
var hero_headlight_cone_mesh: MeshInstance3D
var hero_headlight_cone_mat: StandardMaterial3D
static var headlight_cone_mat: ShaderMaterial
var hero_headlight_lens_mat: StandardMaterial3D
static var sodium_lamp_mat: StandardMaterial3D
static var sodium_pool_mat: StandardMaterial3D
var active_sodium_spots: Array[SpotLight3D] = []
var hud_tod_toggle_btn: Button
var bg_cloud_mat: StandardMaterial3D
static var skyline_mat: ShaderMaterial
static var tokyo_bay_water_mat: ShaderMaterial

static var constr_barrier_shader: Shader
static var constr_barrier_mat: ShaderMaterial
static var amber_strobe_shader: Shader
static var amber_strobe_mat: ShaderMaterial
static var traffic_cone_shader: Shader
static var traffic_cone_mat: ShaderMaterial
static var toll_sign_shader: Shader
static var toll_sign_open_mat: ShaderMaterial
static var toll_sign_closed_mat: ShaderMaterial
static var expansion_rubber_mat: StandardMaterial3D
static var expansion_steel_mat: StandardMaterial3D
static var cone_base_mat: StandardMaterial3D

# Road Chunks Pool & Materials
var road_chunks: Array[Node3D] = []
var next_chunk_z: float = 0.0
var road_curve_seed: float = 0.0
static var road_shader_mat: ShaderMaterial
static var cliff_sun_mat: StandardMaterial3D
static var cliff_dark_mat: StandardMaterial3D
static var cliff_mat: ShaderMaterial
static var mountain_peak_mat: ShaderMaterial
static var hillside_foliage_mat: Material
static var hillside_rock_mat: StandardMaterial3D
static var hillside_layer2_mat: StandardMaterial3D
static var hillside_layer3_mat: StandardMaterial3D
static var smoke_cel_mat: ShaderMaterial
static var smoke_outline_mat: ShaderMaterial
static var barrier_material: StandardMaterial3D
static var barrier_cap_material: StandardMaterial3D
static var comic_hero_shader: Shader
static var comic_ink_shader: Shader
static var comic_outline_mat: ShaderMaterial
static var contact_shadow_mat: ShaderMaterial
static var speedlines_mat: ShaderMaterial

# --- 4 JAPANESE MANGA BIOMES SYSTEM ---
const BIOMES: Dictionary = {
	"shuto_dusk": {
		"name": "SHUTO DUSK",
		"kanji": "首都高 DUSK",
		"badge": "SHUTO EXPRESSWAY // DUSK",
		"sky_top": Color("#0E2864"),
		"sky_horizon": Color("#E8827A"),
		"ground_horizon": Color("#242B3D"),
		"sun_color": Color("#FFF8EB"),
		"sun_energy": 1.25,
		"ambient_color": Color("#2A283D"),
		"ambient_energy": 0.28,
		"fog_color": Color("#242B3D"),
		"fog_density": 0.001,
		"weather": "sunny",
		"traffic_min_dist": 160.0,
		"traffic_max_dist": 230.0,
	},
	"neo_shinjuku": {
		"name": "NEO-SHINJUKU",
		"kanji": "新宿 ALLEY",
		"badge": "NEO-SHINJUKU // URBAN CANYON",
		"sky_top": Color("#080816"),
		"sky_horizon": Color("#4A1535"),
		"ground_horizon": Color("#0A0A14"),
		"sun_color": Color("#3A4A7A"),
		"sun_energy": 0.65,
		"ambient_color": Color("#181428"),
		"ambient_energy": 0.35,
		"fog_color": Color("#100C1C"),
		"fog_density": 0.0018,
		"weather": "rain",
		"traffic_min_dist": 200.0,
		"traffic_max_dist": 290.0,
	},
	"enoshima_coast": {
		"name": "ENOSHIMA COAST",
		"kanji": "江の島 COAST",
		"badge": "ENOSHIMA COAST // OCEAN HIGHWAY",
		"sky_top": Color("#1E5FA8"),
		"sky_horizon": Color("#FFAA44"),
		"ground_horizon": Color("#3D6075"),
		"sun_color": Color("#FFE5B4"),
		"sun_energy": 1.40,
		"ambient_color": Color("#4A5568"),
		"ambient_energy": 0.32,
		"fog_color": Color("#F4D58D"),
		"fog_density": 0.0007,
		"weather": "sunny",
		"traffic_min_dist": 280.0,
		"traffic_max_dist": 390.0,
	},
	"hakone_snow": {
		"name": "HAKONE SNOW",
		"kanji": "箱根 TOUGE",
		"badge": "HAKONE SNOW // ALPINE PASS",
		"sky_top": Color("#4A6B8A"),
		"sky_horizon": Color("#B8D2E6"),
		"ground_horizon": Color("#7A96B2"),
		"sun_color": Color("#E6F2FF"),
		"sun_energy": 1.10,
		"ambient_color": Color("#859CB5"),
		"ambient_energy": 0.30,
		"fog_color": Color("#A4BED5"),
		"fog_density": 0.0012,
		"weather": "snow",
		"traffic_min_dist": 450.0,
		"traffic_max_dist": 680.0,
	}
}

const STAGE_INTERVAL_METERS: float = 2500.0
var stage_tier: int = 1
var stage_start_z: float = 0.0
var current_biome_id: String = "shuto_dusk"
var discovered_biomes: Array[String] = ["shuto_dusk"]

var fork_left_biome: String = "hakone_snow"
var fork_right_biome: String = "enoshima_coast"
var fork_active: bool = false
var active_fork_mid_z: float = -999999.0
var active_fork_exit_z: float = -999999.0
var fork_transition_done: bool = false
const SAVE_DATA_PATH: String = "user://save_data.cfg"

# Start Screen & Vibe Pill UI
var hud_start_screen: Control
var hud_vibe_label: Label
var hud_stage_banner: Control
var hud_stage_label: Label
var hud_stage_sub: Label

# Biome Prop Materials
static var coastal_sand_mat: StandardMaterial3D
static var ocean_water_mat: StandardMaterial3D
static var ocean_foam_mat: StandardMaterial3D
static var palm_trunk_mat: StandardMaterial3D
static var palm_frond_mat: StandardMaterial3D
static var coastal_cliff_mat: StandardMaterial3D

static var snow_rock_mat: StandardMaterial3D
static var snow_foliage_mat: StandardMaterial3D
static var snowbank_mat: StandardMaterial3D

static var shinjuku_building_mat: StandardMaterial3D
static var shinjuku_window_mat: StandardMaterial3D
static var neon_pink_mat: StandardMaterial3D
static var neon_cyan_mat: StandardMaterial3D
static var neon_yellow_mat: StandardMaterial3D
static var vending_body_mat: StandardMaterial3D
static var vending_glass_mat: StandardMaterial3D
static var power_pole_mat: StandardMaterial3D
static var power_line_mat: StandardMaterial3D
static var attenuator_mat: StandardMaterial3D

# Player Motion State
var player_z: float = 0.0
var player_lane_x: float = 0.0
var player_lat_velocity: float = 0.0
var player_target_speed: float = CRUISE_SPEED
var player_speed: float = CRUISE_SPEED
var spinout_angle: float = 0.0
var body_turn_yaw: float = 0.0
var screen_shake: float = 0.0

# Input tracking
var is_touching: bool = false
var touch_start: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var steer_input: float = 0.0
var drift_active: bool = false
var prev_drift_active: bool = false
var boost_active: bool = false
var player_wheels: Array[Node3D] = []

# Traffic Pool
class TrafficVehicleData:
	var instance: AnimatableBody3D
	var mesh_root: Node3D
	var shadow_mesh: MeshInstance3D
	var model_type: String
	var current_z: float = -60.0
	var lane_offset: float = 0.0
	var speed: float = 24.0
	var grazed: bool = false
	var half_w: float = 1.015
	var half_l: float = 1.90
	var bob_seed: float = 0.0
	var wheels: Array[Node3D] = []
	var is_lane_switcher: bool = false
	var is_switching: bool = false
	var switch_start_x: float = 0.0
	var switch_target_x: float = 0.0
	var switch_progress: float = 0.0
	var is_disrupted: bool = false
	var disrupt_yaw: float = 0.0
	var disrupt_slide_speed: float = 0.0
	var disrupt_spin_rate: float = 0.0
	var is_roadblock: bool = false
	var is_police: bool = false
	var is_dekotora: bool = false
	var roadblock_crashing: bool = false
	var roadblock_has_impacted: bool = false
	var strobe_timer: float = 0.0
	var strobe_mat_r: Material
	var strobe_mat_b: Material
	var taillight_mat: Material
	var body_mat: ShaderMaterial
	var flinch_timer: float = 0.0
	var flinch_swerve_offset: float = 0.0
	var flinch_target_swerve: float = 0.0
	var graze_grace_timer: float = 0.0
	var graze_grace_active: bool = false

var traffic_pool: Array[TrafficVehicleData] = []
const TRAFFIC_POOL_SIZE: int = 12

# Nitro & Double-Tap System
const DOUBLE_TAP_WINDOW: float = 0.25
var last_tap_time: float = -999.0
var nitro_charge: float = 0.0          # 0.0 to 100.0
var drift_charge: float = 0.0          # 0.0 to 100.0
var nitro_active: bool = false
var nitro_timer: float = 0.0
var nitro_tier: int = 1                # 1 = 50-99% (+18%), 2 = 100% (+25%)
var nitro_speed_mult: float = 1.0

# Graze Boost & Exit Kick
var graze_speed_kick_timer: float = 0.0
var cam_fov_punch: float = 0.0
var cam_fov_punch_timer: float = 0.0

# HUD & Audio Elements for Boost / Graze
var hud_nitro_bar_bg: ColorRect
var hud_nitro_bar: ColorRect
var hud_nitro_ready_badge: Label
var graze_audio_player: AudioStreamPlayer
var scrape_audio_player: AudioStreamPlayer
var nitro_audio_player: AudioStreamPlayer
var nitro_flame_mat: ShaderMaterial

const TRAFFIC_CONFIGS: Dictionary = {
	"truck": { "path": "res://assets/vehicles/traffic/heavy_truck.fbx", "speed": 20.0, "half_w": 1.23, "half_l": 1.94, "color": Color(0.18, 0.52, 0.28) },
	"dekotora": { "path": "res://assets/vehicles/traffic/heavy_truck.fbx", "speed": 21.0, "half_w": 1.35, "half_l": 2.45, "color": Color(0.08, 0.08, 0.12) },
	"sedan": { "path": "res://assets/vehicles/traffic/sedan_civilian.fbx", "speed": 28.0, "half_w": 1.015, "half_l": 1.885, "color": Color(0.16, 0.44, 0.84) },
	"suv": { "path": "res://assets/vehicles/traffic/suv_civilian.fbx", "speed": 24.0, "half_w": 1.015, "half_l": 1.815, "color": Color(0.88, 0.62, 0.25) },
	"police": { "path": "res://assets/vehicles/traffic/police_interceptor.fbx", "speed": 34.0, "half_w": 0.95, "half_l": 2.06, "color": Color(0.10, 0.10, 0.14) },
	"muscle": { "path": "res://assets/vehicles/traffic/muscle.fbx", "speed": 30.0, "half_w": 1.015, "half_l": 2.18, "color": Color(0.62, 0.16, 0.42) }
}

const TRAFFIC_SPAWN_ORDER: Array[String] = [
	"truck", "sedan", "police", "suv", "muscle",
	"dekotora", "sedan", "police", "muscle", "sedan",
	"suv", "truck"
]

# Scoring, Combos & HUD
var score: int = 0
var displayed_score: float = 0.0
var combo_multiplier: int = 1
var combo_timer: float = 0.0
var near_miss_count: int = 0
var top_speed_achieved: float = 0.0

# Aggressive Pursuer / Rival Disruptor Car
var rival_root: AnimatableBody3D
var rival_mesh_root: Node3D
var rival_shadow: MeshInstance3D
var rival_wheels: Array[Node3D] = []
var rival_z: float = 9999.0
var rival_lane_x: float = 0.0
var rival_speed: float = 0.0
var rival_active: bool = false
var rival_state: int = 0  # 0: PASSING_PLAYER, 1: DISRUPTING_TRAFFIC, 2: POLICE_ROADBLOCK, 3: ESCAPING
var rival_timer: float = 0.0
var rival_spawn_cooldown: float = 5.0  # Spawns ~5s into race
var rival_disrupt_count: int = 0
var rival_grazed: bool = false
var rival_passed_player: bool = false
var rival_target_police: Array[TrafficVehicleData] = []
var rival_spawn_side: float = -7.2
const RIVAL_HALF_W: float = 0.98
const RIVAL_HALF_L: float = 2.05
var hud_rival_alert: Label
var hud_rev_bar: ColorRect
var hud_gear_label: Label
var hud_hazard_banner: Control
var hud_hazard_label: Label
var hazard_tween: Tween
var background_rig: Node3D
var horizon_manager: HorizonManager

var hud_speed_label: Label
var hud_combo_container: Control
var hud_combo_label: Label
var hud_combo_bar: ColorRect
var hud_drift_label: Label
var hud_score_label: Label
var hud_crash_flash: ColorRect
var hud_restart_banner: Control
var hud_summary_stats: Label
var hud_speedlines: ColorRect
var hud_graze_container: Control

func _get_stage_top_speed_kmh(tier: int) -> float:
	match tier:
		1: return 165.0
		2: return 185.0
		3: return 205.0
		4: return 225.0
		_: return minf(245.0, 225.0 + float(tier - 4) * 10.0)

func _get_stage_cruise_speed() -> float:
	return _get_stage_top_speed_kmh(stage_tier) / 3.6

func _get_stage_boost_speed() -> float:
	return (_get_stage_top_speed_kmh(stage_tier) + 35.0) / 3.6

func _get_stage_score_multiplier(tier: int) -> float:
	match tier:
		1: return 1.0
		2: return 1.25
		3: return 1.5
		4: return 2.0
		_: return 2.0 + float(tier - 4) * 0.5

func _load_save_data() -> void:
	var cfg := ConfigFile.new()
	var all_default_biomes: Array = ["shuto_dusk", "neo_shinjuku", "enoshima_coast", "hakone_snow"]
	if cfg.load(SAVE_DATA_PATH) == OK:
		var loaded_list = cfg.get_value("biomes", "discovered_biomes", all_default_biomes)
		if loaded_list is Array:
			discovered_biomes.clear()
			for b in loaded_list:
				var s := String(b)
				if s in BIOMES and not s in discovered_biomes:
					discovered_biomes.append(s)
		if discovered_biomes.is_empty():
			discovered_biomes = ["shuto_dusk", "neo_shinjuku", "enoshima_coast", "hakone_snow"]
		var last_b: String = cfg.get_value("biomes", "last_biome", "shuto_dusk")
		if last_b in discovered_biomes:
			current_biome_id = last_b
		else:
			current_biome_id = discovered_biomes[0]
	else:
		discovered_biomes = ["shuto_dusk", "neo_shinjuku", "enoshima_coast", "hakone_snow"]
		current_biome_id = "shuto_dusk"

func _save_save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("biomes", "discovered_biomes", discovered_biomes)
	cfg.set_value("biomes", "last_biome", current_biome_id)
	cfg.save(SAVE_DATA_PATH)

func _discover_biome(b_id: String) -> void:
	if not b_id in discovered_biomes:
		discovered_biomes.append(b_id)
		_save_save_data()
		_trigger_radio_chatter("TACHIBANA SPOTTER", "NEW BIOME UNLOCKED: " + BIOMES[b_id]["name"] + "!", Color("#FFD700"))

func _rebuild_start_chunks() -> void:
	for chunk in road_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	road_chunks.clear()
	next_chunk_z = 0.0
	chunk_spawn_count = 0
	_setup_road_system()

func _apply_biome_transition(new_biome_id: String) -> void:
	if not new_biome_id in BIOMES:
		return
	current_biome_id = new_biome_id
	var b_data: Dictionary = BIOMES[new_biome_id]

	# Sky & Atmosphere
	if is_instance_valid(procedural_sky_mat):
		procedural_sky_mat.sky_top_color = b_data["sky_top"]
		procedural_sky_mat.sky_horizon_color = b_data["sky_horizon"]
		procedural_sky_mat.ground_horizon_color = b_data["ground_horizon"]
	if is_instance_valid(world_env_resource):
		world_env_resource.ambient_light_color = b_data["ambient_color"]
		world_env_resource.ambient_light_energy = b_data["ambient_energy"]
		world_env_resource.fog_light_color = b_data["fog_color"]
		world_env_resource.fog_density = b_data["fog_density"]

	# Directional Sun
	if is_instance_valid(sun_light):
		sun_light.light_color = b_data["sun_color"]
		sun_light.light_energy = b_data["sun_energy"]

	# Horizon Mountain / Island Silhouette Manager
	if is_instance_valid(horizon_manager):
		horizon_manager.set_biome_style(new_biome_id)

	# Distant Tokyo Skyline (Show on Shuto Dusk and Neo-Shinjuku; hide in Hakone Snow and Enoshima Coast)
	if is_instance_valid(background_rig):
		background_rig.visible = (new_biome_id in ["shuto_dusk", "neo_shinjuku"])

	# Weather state
	match b_data["weather"]:
		"rain":
			set_weather_rain(true)
			if is_instance_valid(hud_rain_overlay):
				hud_rain_overlay.visible = true
				hud_rain_overlay.modulate.a = 1.0
		"snow":
			_set_weather_state(WeatherState.SNOW)
			if is_instance_valid(hud_rain_overlay):
				hud_rain_overlay.visible = false
				hud_rain_overlay.modulate.a = 0.0
		_:
			set_weather_rain(false)
			if is_instance_valid(hud_rain_overlay):
				hud_rain_overlay.visible = false
				hud_rain_overlay.modulate.a = 0.0

func _cycle_start_biome(dir: int) -> void:
	if discovered_biomes.is_empty():
		return
	var cur_idx := discovered_biomes.find(current_biome_id)
	if cur_idx == -1:
		cur_idx = 0
	cur_idx = (cur_idx + dir + discovered_biomes.size()) % discovered_biomes.size()
	current_biome_id = discovered_biomes[cur_idx]
	_apply_biome_transition(current_biome_id)
	if is_instance_valid(hud_vibe_label):
		hud_vibe_label.text = BIOMES[current_biome_id]["name"]
	if current_state == GameState.START:
		_rebuild_start_chunks()
	_save_save_data()

func _start_race() -> void:
	if current_state != GameState.START:
		return
	current_state = GameState.RACING
	if is_instance_valid(hud_start_screen):
		hud_start_screen.visible = false
	if is_instance_valid(engine_audio_player) and not engine_audio_player.playing:
		engine_audio_player.play()
	if is_instance_valid(rally_music_player) and not rally_music_player.playing:
		_play_random_rally_track()
	_trigger_radio_chatter("TACHIBANA SPOTTER", "Race started! Heading into " + BIOMES[current_biome_id]["name"] + "!", Color("#FFD700"))

func _trigger_stage_badge(tier: int, kmh: int) -> void:
	if not is_instance_valid(hud_stage_banner):
		return
	hud_stage_banner.visible = true
	hud_stage_banner.modulate.a = 1.0
	hud_stage_banner.scale = Vector2(1.25, 1.25)
	if is_instance_valid(hud_stage_label):
		hud_stage_label.text = "STAGE " + str(tier) + " // +20 KM/H"
	if is_instance_valid(hud_stage_sub):
		hud_stage_sub.text = "BASE TOP SPEED: " + str(kmh) + " KM/H (" + str(_get_stage_score_multiplier(tier)) + "x SCORE)"
	_play_proc_audio("high_rev")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(hud_stage_banner, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw_seq := create_tween()
	tw_seq.tween_interval(2.2)
	tw_seq.tween_property(hud_stage_banner, "modulate:a", 0.0, 0.5)
	tw_seq.tween_callback(func(): if is_instance_valid(hud_stage_banner): hud_stage_banner.visible = false)

func _ready() -> void:
	_load_save_data()
	_setup_procedural_audio()
	_setup_game_audio()
	_setup_materials()
	_setup_environment()
	_setup_background_layers()
	_apply_biome_transition(current_biome_id)
	_setup_road_system()
	_setup_skid_pool()
	_setup_spark_pools()
	_setup_player_car()
	_setup_weather_particles()
	_setup_traffic_pool()
	_setup_rival_car()
	_setup_camera()
	_setup_hud()
	current_state = GameState.START
	if is_instance_valid(hud_start_screen):
		hud_start_screen.visible = true
	purge_outlines(self)
	if OS.get_cmdline_args().has("--capture-biomes") or OS.get_cmdline_user_args().has("--capture-biomes"):
		_run_biome_captures()

func _run_biome_captures() -> void:
	var artifact_dir := "C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743"
	for f in range(25):
		await get_tree().process_frame

	var img_start := get_viewport().get_texture().get_image()
	if img_start:
		img_start.save_png(artifact_dir + "/capture_vibe_pill.png")
		print("CAPTURED: vibe pill")

	_start_race()

	var biomes_to_capture := ["shuto_dusk", "neo_shinjuku", "enoshima_coast", "hakone_snow"]
	for b_id in biomes_to_capture:
		current_biome_id = b_id
		last_sky_update_progress = -999.0
		_apply_biome_transition(b_id)
		_rebuild_start_chunks()
		player_speed = 46.0
		for f in range(35):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		if img:
			var out_file: String = artifact_dir + "/capture_" + b_id + ".png"
			img.save_png(out_file)
			print("CAPTURED: ", b_id)

	get_tree().quit()

func _setup_skid_pool() -> void:
	skid_quad_mesh = QuadMesh.new()
	skid_quad_mesh.size = Vector2(0.34, 1.35)
	skid_quad_mesh.orientation = PlaneMesh.FACE_Y

	skid_shared_mat = StandardMaterial3D.new()
	skid_shared_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skid_shared_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skid_shared_mat.albedo_color = Color(0.102, 0.110, 0.141, 0.75)
	skid_shared_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var skid_container := Node3D.new()
	skid_container.name = "SkidMarksPool"
	add_child(skid_container)

	skid_pool.clear()
	for i in range(SKID_POOL_SIZE):
		var sm_inst := MeshInstance3D.new()
		sm_inst.mesh = skid_quad_mesh
		sm_inst.material_override = skid_shared_mat
		sm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sm_inst.visible = false
		skid_container.add_child(sm_inst)

		var item := SkidDecal.new()
		item.node = sm_inst
		item.time_left = 0.0
		skid_pool.append(item)

func _setup_spark_pools() -> void:
	var spark_container := Node3D.new()
	spark_container.name = "SparksAndSprayPool"
	add_child(spark_container)

	# 1. Diffuser Sparks Pool
	diffuser_spark_pool.clear()
	for i in range(DIFFUSER_SPARK_POOL_SIZE):
		var spark := MeshInstance3D.new()
		spark.mesh = diffuser_spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.visible = false
		spark_container.add_child(spark)
		diffuser_spark_pool.append(spark)

	# 2. Guardrail Sparks Pool
	var gr_mesh := QuadMesh.new()
	gr_mesh.size = Vector2(0.32, 0.14)
	guardrail_spark_pool.clear()
	for i in range(GUARDRAIL_SPARK_POOL_SIZE):
		var spark := MeshInstance3D.new()
		spark.mesh = gr_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.visible = false
		spark_container.add_child(spark)
		guardrail_spark_pool.append(spark)

	# 3. Water Spray Pool
	var ws_mesh := QuadMesh.new()
	ws_mesh.size = Vector2(0.85, 1.4)
	water_spray_pool.clear()
	for i in range(WATER_SPRAY_POOL_SIZE):
		var spray := MeshInstance3D.new()
		spray.mesh = ws_mesh
		spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spray.visible = false
		spark_container.add_child(spray)
		water_spray_pool.append(spray)

# 1. PURGE INVERTED HULL PASS FROM ALL ENVIRONMENT PROPS & VEHICLES
func purge_outlines(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		# Remove next_pass from material_override
		if node.material_override and node.material_override.next_pass:
			node.material_override.next_pass = null
		# Remove next_pass from all surface materials
		if node.mesh:
			for i in range(node.mesh.get_surface_count()):
				var mat = node.get_surface_override_material(i)
				if mat and mat.next_pass:
					mat.next_pass = null
				var surf_mat = node.mesh.surface_get_material(i)
				if surf_mat and surf_mat.next_pass:
					surf_mat.next_pass = null
	for child in node.get_children():
		purge_outlines(child)

static func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is Texture2D:
			return res
	var global_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

# ==============================================================================
# 1. SHADERS & TOON MATERIALS (AUTO MODELLISTA ANIME CEL-SHADING)
# ==============================================================================
func _setup_materials() -> void:
	if not comic_hero_shader:
		comic_hero_shader = load("res://shaders/manga_brush_car.gdshader")

	if not contact_shadow_mat:
		var shadow_sh: Shader = load("res://contact_shadow.gdshader")
		contact_shadow_mat = ShaderMaterial.new()
		contact_shadow_mat.shader = shadow_sh
		contact_shadow_mat.set_shader_parameter("shadow_color", Color(0.04, 0.04, 0.08, 0.75)) # Hard contact shadow

	if not road_shader_mat:
		var road_sh: Shader = load("res://highway_road.gdshader")
		road_shader_mat = ShaderMaterial.new()
		road_shader_mat.shader = road_sh
		road_shader_mat.set_shader_parameter("asphalt_color", Color("#282D3B")) # Dark Graphic Tarmac
		road_shader_mat.set_shader_parameter("line_yellow", Color("#FFD000"))
		road_shader_mat.set_shader_parameter("line_white", Color("#FFFFFF"))
		road_shader_mat.set_shader_parameter("curb_red", Color("#D92027"))
		road_shader_mat.set_shader_parameter("curb_white", Color("#FFFFFF"))

	if not cliff_sun_mat:
		cliff_sun_mat = StandardMaterial3D.new()
		cliff_sun_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		cliff_sun_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		cliff_sun_mat.albedo_color = COLOR_CLIFF_SUN
		cliff_sun_mat.roughness = 0.90
		cliff_sun_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not cliff_dark_mat:
		cliff_dark_mat = StandardMaterial3D.new()
		cliff_dark_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		cliff_dark_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		cliff_dark_mat.albedo_color = COLOR_CLIFF_SHADOW
		cliff_dark_mat.roughness = 0.95
		cliff_dark_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not barrier_material:
		barrier_material = StandardMaterial3D.new()
		barrier_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		barrier_material.specular_mode = BaseMaterial3D.SPECULAR_TOON
		barrier_material.albedo_color = COLOR_BARRIER
		barrier_material.cull_mode = BaseMaterial3D.CULL_BACK
		barrier_material.metallic = 0.60
		barrier_material.roughness = 0.28

	if not barrier_cap_material:
		barrier_cap_material = StandardMaterial3D.new()
		barrier_cap_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		barrier_cap_material.specular_mode = BaseMaterial3D.SPECULAR_TOON
		barrier_cap_material.albedo_color = COLOR_BARRIER_CAP
		barrier_cap_material.cull_mode = BaseMaterial3D.CULL_BACK
		barrier_cap_material.roughness = 0.35

	if not speedlines_mat:
		var sl_sh: Shader = load("res://manga_speedlines.gdshader")
		speedlines_mat = ShaderMaterial.new()
		speedlines_mat.shader = sl_sh
		speedlines_mat.set_shader_parameter("intensity", 0.0)
		speedlines_mat.set_shader_parameter("line_color", Color(1.0, 1.0, 1.0, 0.75))

	if not smoke_puff_shader:
		smoke_puff_shader = load("res://shaders/anime_smoke_puff.gdshader")
	if not smoke_puff_mat:
		smoke_puff_mat = ShaderMaterial.new()
		smoke_puff_mat.shader = smoke_puff_shader

	if not toon_flame_shader:
		toon_flame_shader = load("res://shaders/stepped_toon_flame.gdshader")
	if not toon_flame_mat:
		toon_flame_mat = ShaderMaterial.new()
		toon_flame_mat.shader = toon_flame_shader
	if not nitro_flame_mat and toon_flame_shader:
		nitro_flame_mat = ShaderMaterial.new()
		nitro_flame_mat.shader = toon_flame_shader
		nitro_flame_mat.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
		nitro_flame_mat.set_shader_parameter("mid_color", Color("#00E5FF"))
		nitro_flame_mat.set_shader_parameter("rim_color", Color(0.0, 0.4, 1.0, 1.0))

	if not tunnel_concrete_mat:
		tunnel_concrete_mat = StandardMaterial3D.new()
		tunnel_concrete_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		tunnel_concrete_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		tunnel_concrete_mat.albedo_color = Color("#2A2D37")
		tunnel_concrete_mat.roughness = 0.88
		tunnel_concrete_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not tunnel_rib_mat:
		tunnel_rib_mat = StandardMaterial3D.new()
		tunnel_rib_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		tunnel_rib_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		tunnel_rib_mat.albedo_color = Color("#1A1C24")
		tunnel_rib_mat.roughness = 0.75
		tunnel_rib_mat.metallic = 0.25
		tunnel_rib_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not tunnel_fluor_mat:
		tunnel_fluor_mat = StandardMaterial3D.new()
		tunnel_fluor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tunnel_fluor_mat.albedo_color = Color("#E6F4FF")

	if not tunnel_pool_mat:
		tunnel_pool_mat = StandardMaterial3D.new()
		tunnel_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tunnel_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tunnel_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		tunnel_pool_mat.albedo_color = Color(0.902, 0.957, 1.0, 0.24)
		tunnel_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not spark_shader:
		spark_shader = load("res://shaders/guardrail_spark.gdshader")
	if not spark_mat:
		spark_mat = ShaderMaterial.new()
		spark_mat.shader = spark_shader

	if not wingtip_vortex_shader:
		wingtip_vortex_shader = load("res://shaders/wingtip_vortex.gdshader")
	if not wingtip_vortex_mat:
		wingtip_vortex_mat = ShaderMaterial.new()
		wingtip_vortex_mat.shader = wingtip_vortex_shader

	if not diffuser_spark_mesh:
		var st_sp := SurfaceTool.new()
		st_sp.begin(Mesh.PRIMITIVE_TRIANGLES)
		st_sp.add_vertex(Vector3(-0.045, 0.0, 0.0))
		st_sp.add_vertex(Vector3(0.045, 0.0, 0.0))
		st_sp.add_vertex(Vector3(0.0, 0.0, -0.24))
		st_sp.add_index(0); st_sp.add_index(1); st_sp.add_index(2)
		st_sp.add_index(0); st_sp.add_index(2); st_sp.add_index(1)
		diffuser_spark_mesh = st_sp.commit()

	if not diffuser_spark_mat_white:
		diffuser_spark_mat_white = StandardMaterial3D.new()
		diffuser_spark_mat_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		diffuser_spark_mat_white.albedo_color = Color("#FFFFFF")
		diffuser_spark_mat_white.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not diffuser_spark_mat_amber:
		diffuser_spark_mat_amber = StandardMaterial3D.new()
		diffuser_spark_mat_amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		diffuser_spark_mat_amber.albedo_color = Color("#FFAA00")
		diffuser_spark_mat_amber.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not rain_shader:
		rain_shader = load("res://shaders/manga_rain.gdshader")
	if not rain_mat:
		rain_mat = ShaderMaterial.new()
		rain_mat.shader = rain_shader

	if not snow_shader:
		snow_shader = load("res://shaders/manga_snow.gdshader")
	if not snow_overlay_mat:
		snow_overlay_mat = ShaderMaterial.new()
		snow_overlay_mat.shader = snow_shader

	if not water_spray_shader:
		water_spray_shader = load("res://shaders/anime_water_spray.gdshader")
	if not water_spray_mat:
		water_spray_mat = ShaderMaterial.new()
		water_spray_mat.shader = water_spray_shader

	if not constr_barrier_shader:
		constr_barrier_shader = load("res://shaders/construction_barrier.gdshader")
	if not constr_barrier_mat:
		constr_barrier_mat = ShaderMaterial.new()
		constr_barrier_mat.shader = constr_barrier_shader

	if not amber_strobe_shader:
		amber_strobe_shader = load("res://shaders/amber_strobe.gdshader")
	if not amber_strobe_mat:
		amber_strobe_mat = ShaderMaterial.new()
		amber_strobe_mat.shader = amber_strobe_shader

	if not traffic_cone_shader:
		traffic_cone_shader = load("res://shaders/traffic_cone.gdshader")
	if not traffic_cone_mat:
		traffic_cone_mat = ShaderMaterial.new()
		traffic_cone_mat.shader = traffic_cone_shader

	if not toll_sign_shader:
		toll_sign_shader = load("res://shaders/toll_gate_sign.gdshader")
	if not toll_sign_open_mat:
		toll_sign_open_mat = ShaderMaterial.new()
		toll_sign_open_mat.shader = toll_sign_shader
		toll_sign_open_mat.set_shader_parameter("is_open", true)
	if not toll_sign_closed_mat:
		toll_sign_closed_mat = ShaderMaterial.new()
		toll_sign_closed_mat.shader = toll_sign_shader
		toll_sign_closed_mat.set_shader_parameter("is_open", false)

	if not expansion_rubber_mat:
		expansion_rubber_mat = StandardMaterial3D.new()
		expansion_rubber_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		expansion_rubber_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		expansion_rubber_mat.albedo_color = Color("#0D0F14")
		expansion_rubber_mat.roughness = 0.92
		expansion_rubber_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not expansion_steel_mat:
		expansion_steel_mat = StandardMaterial3D.new()
		expansion_steel_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		expansion_steel_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		expansion_steel_mat.albedo_color = Color("#4D5262")
		expansion_steel_mat.metallic = 0.65
		expansion_steel_mat.roughness = 0.35
		expansion_steel_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not cone_base_mat:
		cone_base_mat = StandardMaterial3D.new()
		cone_base_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		cone_base_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		cone_base_mat.albedo_color = Color("#111216")
		cone_base_mat.roughness = 0.90
		cone_base_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not sodium_lamp_mat:
		sodium_lamp_mat = StandardMaterial3D.new()
		sodium_lamp_mat.albedo_color = Color("#3A3732")
		sodium_lamp_mat.emission_enabled = true
		sodium_lamp_mat.emission = Color("#FFA012")
		sodium_lamp_mat.emission_energy_multiplier = 0.0

	if not sodium_pool_mat:
		sodium_pool_mat = StandardMaterial3D.new()
		sodium_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sodium_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sodium_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sodium_pool_mat.albedo_color = Color(1.0, 0.627, 0.071, 0.0)
		sodium_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# --- 4 BIOMES MATERIALS INITIALIZATION ---
	if not coastal_sand_mat:
		coastal_sand_mat = StandardMaterial3D.new()
		coastal_sand_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		coastal_sand_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		coastal_sand_mat.albedo_color = Color("#F4D58D")
		coastal_sand_mat.roughness = 0.95

	if not ocean_water_mat:
		ocean_water_mat = StandardMaterial3D.new()
		ocean_water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ocean_water_mat.albedo_color = Color("#1E6FA8")

	if not ocean_foam_mat:
		ocean_foam_mat = StandardMaterial3D.new()
		ocean_foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ocean_foam_mat.albedo_color = Color("#FFFFFF")

	if not palm_trunk_mat:
		palm_trunk_mat = StandardMaterial3D.new()
		palm_trunk_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		palm_trunk_mat.albedo_color = Color("#8B5A2B")

	if not palm_frond_mat:
		palm_frond_mat = StandardMaterial3D.new()
		palm_frond_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		palm_frond_mat.albedo_color = Color("#2E8B57")
		palm_frond_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not coastal_cliff_mat:
		coastal_cliff_mat = StandardMaterial3D.new()
		coastal_cliff_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		coastal_cliff_mat.albedo_color = Color("#C49A5A")

	if not snow_rock_mat:
		snow_rock_mat = StandardMaterial3D.new()
		snow_rock_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		snow_rock_mat.albedo_color = Color("#DCE8F2")

	if not snow_foliage_mat:
		snow_foliage_mat = StandardMaterial3D.new()
		snow_foliage_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		snow_foliage_mat.albedo_color = Color("#EBF2F7")
		snow_foliage_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not snowbank_mat:
		snowbank_mat = StandardMaterial3D.new()
		snowbank_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		snowbank_mat.albedo_color = Color("#F0F6FA")

	if not shinjuku_building_mat:
		shinjuku_building_mat = StandardMaterial3D.new()
		shinjuku_building_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		shinjuku_building_mat.albedo_color = Color("#282A33")

	if not shinjuku_window_mat:
		shinjuku_window_mat = StandardMaterial3D.new()
		shinjuku_window_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shinjuku_window_mat.albedo_color = Color("#FFD27F")

	if not neon_pink_mat:
		neon_pink_mat = StandardMaterial3D.new()
		neon_pink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		neon_pink_mat.albedo_color = Color("#FF2A55")

	if not neon_cyan_mat:
		neon_cyan_mat = StandardMaterial3D.new()
		neon_cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		neon_cyan_mat.albedo_color = Color("#00E5FF")

	if not neon_yellow_mat:
		neon_yellow_mat = StandardMaterial3D.new()
		neon_yellow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		neon_yellow_mat.albedo_color = Color("#FFD000")

	if not vending_body_mat:
		vending_body_mat = StandardMaterial3D.new()
		vending_body_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		vending_body_mat.albedo_color = Color("#D92027")

	if not vending_glass_mat:
		vending_glass_mat = StandardMaterial3D.new()
		vending_glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vending_glass_mat.albedo_color = Color("#00E5FF")

	if not power_pole_mat:
		power_pole_mat = StandardMaterial3D.new()
		power_pole_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		power_pole_mat.albedo_color = Color("#4A4D54")

	if not power_line_mat:
		power_line_mat = StandardMaterial3D.new()
		power_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		power_line_mat.albedo_color = Color("#111115")

	if not attenuator_mat:
		attenuator_mat = StandardMaterial3D.new()
		attenuator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		attenuator_mat.albedo_color = Color("#FFD000")

	if not cliff_mat:
		var cliff_sh: Shader = load("res://shaders/anime_cliff.gdshader")
		cliff_mat = ShaderMaterial.new()
		cliff_mat.shader = cliff_sh

	if not mountain_peak_mat:
		var mp_sh: Shader = load("res://shaders/anime_mountain_peak.gdshader")
		mountain_peak_mat = ShaderMaterial.new()
		mountain_peak_mat.shader = mp_sh
		mountain_peak_mat.set_shader_parameter("horizon_fog_color", Color("#FF6B35"))

	if not skyline_mat:
		var sky_sh: Shader = load("res://shaders/tokyo_skyline.gdshader")
		skyline_mat = ShaderMaterial.new()
		skyline_mat.shader = sky_sh
		skyline_mat.set_shader_parameter("night_glow", 0.38)
		skyline_mat.set_shader_parameter("building_base_color", Color("#1E242E"))
		skyline_mat.set_shader_parameter("sun_tint", Color("#FFA347") * 0.90)
		skyline_mat.set_shader_parameter("horizon_haze_color", Color("#FF6B35"))

	if not tokyo_bay_water_mat:
		var water_sh: Shader = load("res://shaders/tokyo_bay_water.gdshader")
		tokyo_bay_water_mat = ShaderMaterial.new()
		tokyo_bay_water_mat.shader = water_sh
		tokyo_bay_water_mat.set_shader_parameter("horizon_fog_color", Color("#FF6B35"))
		tokyo_bay_water_mat.set_shader_parameter("night_factor", 0.38)
		tokyo_bay_water_mat.set_shader_parameter("sun_direction", Vector3(-0.5, -0.8, -0.3))
		tokyo_bay_water_mat.set_shader_parameter("sun_reflection_color", Color("#FFA347"))

	if not headlight_cone_mat:
		var hl_sh: Shader = load("res://shaders/headlight_cone.gdshader")
		headlight_cone_mat = ShaderMaterial.new()
		headlight_cone_mat.shader = hl_sh
		headlight_cone_mat.set_shader_parameter("beam_color", Color(1.0, 0.96, 0.84))
		headlight_cone_mat.set_shader_parameter("intensity", 0.0)

	if not foliage_sheet_tex:
		foliage_sheet_tex = _load_texture_safe("res://assets/textures/foliage_tree_sheet.png")

	if not hillside_foliage_mat:
		var fol_sh: Shader = load("res://shaders/anime_nature_3d.gdshader")
		var fol_mat := ShaderMaterial.new()
		fol_mat.shader = fol_sh
		fol_mat.set_shader_parameter("sun_direction", Vector3(-0.5, -0.8, -0.3))
		fol_mat.set_shader_parameter("sun_tint", Color(1.0, 0.95, 0.85, 1.0))
		fol_mat.set_shader_parameter("shadow_tint_color", Color(0.03, 0.07, 0.04, 1.0))
		fol_mat.set_shader_parameter("horizon_fog_color", Color(0.20, 0.24, 0.32, 1.0))
		fol_mat.set_shader_parameter("horizon_fog_color", Color(0.22, 0.26, 0.40, 1.0))
		fol_mat.set_shader_parameter("rim_power", 2.5)
		hillside_foliage_mat = fol_mat

	if not leaf_green_tex:
		leaf_green_tex = _load_texture_safe("res://assets/textures/leaf_green.png")
	if not leaf_autumn_tex:
		leaf_autumn_tex = _load_texture_safe("res://assets/textures/leaf_autumn.png")
	if not leaf_mat:
		leaf_mat = StandardMaterial3D.new()
		leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		leaf_mat.alpha_scissor_threshold = 0.25
		if leaf_green_tex:
			leaf_mat.albedo_texture = leaf_green_tex
		leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not snowflake_tex:
		snowflake_tex = _load_texture_safe("res://assets/textures/snowflake.png")
	if not snow_mat:
		snow_mat = StandardMaterial3D.new()
		snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		snow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if snowflake_tex:
			snow_mat.albedo_texture = snowflake_tex
		snow_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
		snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not hillside_rock_mat:
		hillside_rock_mat = StandardMaterial3D.new()
		hillside_rock_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		hillside_rock_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		hillside_rock_mat.vertex_color_use_as_albedo = true
		hillside_rock_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		hillside_rock_mat.roughness = 0.92
		hillside_rock_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not hillside_layer2_mat:
		hillside_layer2_mat = StandardMaterial3D.new()
		hillside_layer2_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hillside_layer2_mat.albedo_color = Color("#353B4F")
		hillside_layer2_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not hillside_layer3_mat:
		hillside_layer3_mat = StandardMaterial3D.new()
		hillside_layer3_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hillside_layer3_mat.albedo_color = Color("#6A729B")
		hillside_layer3_mat.disable_fog = false
		hillside_layer3_mat.cull_mode = BaseMaterial3D.CULL_BACK

	if not smoke_cel_mat:
		var fnl := FastNoiseLite.new()
		fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
		fnl.frequency = 0.04
		fnl.fractal_octaves = 2
		var img: Image = fnl.get_image(128, 128)
		var smoke_noise_tex := ImageTexture.create_from_image(img)

		var smoke_outline_sh: Shader = load("res://shaders/cel_smoke_outline.gdshader")
		smoke_outline_mat = ShaderMaterial.new()
		smoke_outline_mat.shader = smoke_outline_sh
		smoke_outline_mat.set_shader_parameter("outline_color", Color(0.05, 0.05, 0.08, 1.0))
		smoke_outline_mat.set_shader_parameter("outline_thickness", 0.032)
		smoke_outline_mat.set_shader_parameter("noise_tex", smoke_noise_tex)
		smoke_outline_mat.set_shader_parameter("alpha_scissor", 0.45)
		smoke_outline_mat.set_shader_parameter("vertex_displacement", 0.25)

		var smoke_sh: Shader = load("res://shaders/cel_smoke.gdshader")
		smoke_cel_mat = ShaderMaterial.new()
		smoke_cel_mat.shader = smoke_sh
		smoke_cel_mat.set_shader_parameter("light_color", Color(0.96, 0.95, 0.98, 1.0))
		smoke_cel_mat.set_shader_parameter("shadow_color", Color(0.55, 0.58, 0.68, 1.0))
		smoke_cel_mat.set_shader_parameter("noise_tex", smoke_noise_tex)
		smoke_cel_mat.set_shader_parameter("alpha_scissor", 0.45)
		smoke_cel_mat.set_shader_parameter("shadow_threshold", 0.1)
		smoke_cel_mat.next_pass = smoke_outline_mat

# Ultimate Spider-Man (2005) 3D Comic Inking & Procedural Cross-Hatching Material
func _get_comic_ink_mat(base_color: Color, is_emiss: bool = false, emiss_col: Color = Color.BLACK, emiss_energy: float = 0.0, shadow_thresh: float = 0.42, hatch_dens: float = 60.0) -> ShaderMaterial:
	if not comic_ink_shader:
		comic_ink_shader = load("res://shaders/comic_ink_car.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = comic_ink_shader
	mat.set_shader_parameter("base_paint_color", base_color)
	mat.set_shader_parameter("ink_shadow_color", Color("#0A0914"))
	mat.set_shader_parameter("shadow_threshold", shadow_thresh)
	mat.set_shader_parameter("hatch_density", hatch_dens)
	mat.set_shader_parameter("is_emissive", is_emiss)
	mat.set_shader_parameter("emissive_color", emiss_col)
	mat.set_shader_parameter("emissive_energy", emiss_energy)
	return mat

# Creates a distinct comic material using the Ultimate Spider-Man hatching pipeline
func _create_comic_mat(base_col: Color, is_emiss: bool = false, emiss_col: Color = Color.BLACK, emiss_energy: float = 0.0, _gloss: float = 0.85, _metal: float = 0.05, _livery: bool = false, _with_outline: bool = false) -> Material:
	return _get_comic_ink_mat(base_col, is_emiss, emiss_col, emiss_energy)

# ==============================================================================
# 2. VIBRANT ANIME DAYTIME SKY & SUN
# ==============================================================================
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 1.0

	# 1. ENVIRONMENT & SKY GRADIENT OVERHAUL (Auto Modellista Palette)
	# Sky Top Color: Saturated Deep Ultramarine (#08307B)
	# Sky Horizon Color: Warm Sunlit Cream (#F6E5B8)
	# Ground Horizon Color: Slate Navy (#242B3D)
	# Ambient Light Color: Warm Ivory (#FFF8E7) with energy = 0.55
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#0E2864")
	sky_mat.sky_horizon_color = Color("#E8827A") # Soft sunset anime gradient (pink to indigo)
	sky_mat.ground_horizon_color = Color("#242B3D")
	sky_mat.ground_bottom_color = Color("#181D2A")
	sky_mat.sun_angle_max = 10.0
	sky_mat.sun_curve = 0.50
	sky_mat.energy_multiplier = 1.0
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.use_debanding = true
	procedural_sky_mat = sky_mat

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky

	# 2. FAKE "RAY-TRACED" BOUNCE LIGHT (Hemispheric Ambient Fill)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2A283D") # Cool anime indigo sky fill
	env.ambient_light_energy = 0.28
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED # Prevents cheap specular washing out toon lines

	# 3. POST-PROCESSING & COLOR GRADING
	# Tonemap Mode: TONEMAPPER_FILMIC (increases contrast, deepens black ink levels)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	# 1. CALIBRATE BLOOM & GLOW (Additive blend, HDR threshold 1.6 prevents white paint flare)
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.6 # CRITICAL: prevents matte white car paint from blooming
	env.glow_bloom = 0.12        # Soft, controlled halos only on emissive lights
	env.glow_intensity = 0.75

	# Disable SSAO and Volumetric Fog to eliminate depth-buffer scanline tearing, froxel banding, and z-fighting on mobile GPUs
	env.ssao_enabled = false
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.001
	env.volumetric_fog_anisotropy = 0.0
	env.volumetric_fog_emission_energy = 0.0

	# Atmospheric Distance Fog (Deep Horizon Distance & Layered Scale)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#242B3D") # Muted anime horizon slate (eliminates blinding white glare)
	env.fog_light_energy = 0.50
	env.fog_sun_scatter = 0.0
	env.fog_density = 0.001
	env.fog_depth_begin = 600.0 # Roadway, cars, and trees stay 100% crisp and saturated
	env.fog_depth_end = 2800.0  # Smooth transition into distant mountains without white washout
	env.fog_sky_affect = 0.0   # CRITICAL: keeps sky overhead vibrant and never washed out!

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env_resource = env
	add_child(world_env)

	# 3. CRISP STABLE SHADOWS (Smooth Cascades, No Popping Or Snapping)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0) # Elevated stable sun angle
	sun.light_color = Color("#FFF8EB") # Warm comic sunlight
	sun.light_energy = 1.25
	sun.light_volumetric_fog_energy = 0.0 # Raw volumetric fog energy set to 0.0 per mandate (kills horizon glare strip)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun_light = sun
	add_child(sun)

# ==============================================================================
# 2B. HORIZON DEPTH: MULTI-LAYER PARALLAX MOUNTAINS, SKYLINES & ANIME CLOUDS
# ==============================================================================
func _setup_background_layers() -> void:
	# 1. Camera-Anchored Horizon Rig (Grand Mountain Massifs, Enoshima Island & Sun Disc)
	var hm_script = load("res://scripts/HorizonManager.gd")
	if hm_script:
		horizon_manager = hm_script.new()
		horizon_manager.name = "HorizonManager"
		horizon_manager.mountain_distance = 480.0
		if is_instance_valid(follow_cam):
			horizon_manager.player_camera = follow_cam
		add_child(horizon_manager)

	background_rig = Node3D.new()
	background_rig.name = "BackgroundRig"
	background_rig.top_level = true
	add_child(background_rig)

	# 2. Distant City Skyline Silhouettes (Full 3D Solid Tokyo Metropolis - Batched 1 Draw Call)
	var sky_st := SurfaceTool.new()
	sky_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# =========================================================================
	# SOLID TOKYO BAY RECLAIMED LANDMASS & HARBOR QUAY SEAWALL FOUNDATIONS
	# Eliminates any floating appearance: every building, pier and tower stands
	# solidly on concrete quays, seawalls and reclaimed island platforms
	# Top: Y = 2.0m to 4.0m (8.5m to 10.5m above bay water at Y = -6.5m)
	# Bottom: Y = -25.0m (seawalls plunge 18.5m below water into bay bedrock)
	# =========================================================================
	# 1. Primary Harumi & Odaiba Waterfront Quay Wharf Platform (Z: -530m to -760m, X: 65m to 520m)
	_add_skyline_box(sky_st, Vector3(65.0, -25.0, -760.0), Vector3(520.0, 2.0, -530.0), 2, 0.15)
	# Waterfront concrete coping seawall along forward quay edge facing the player
	_add_skyline_box(sky_st, Vector3(65.0, 1.8, -533.0), Vector3(520.0, 3.4, -528.0), 2, 0.05)

	# 2. Midtown Metropolis Island Mainland Platform (Z: -755m to -1350m, X: 55m to 550m)
	_add_skyline_box(sky_st, Vector3(55.0, -25.0, -1350.0), Vector3(550.0, 4.0, -755.0), 2, 0.20)
	# Stepped retaining terrace wall between waterfront wharf and midtown plateau
	_add_skyline_box(sky_st, Vector3(65.0, 1.8, -762.0), Vector3(530.0, 5.0, -755.0), 2, 0.10)

	# 3. Cargo Finger Piers & Mooring Jetties extending into Tokyo Bay
	var pier_configs := [
		Vector3(110.0, 2.0, -555.0),
		Vector3(160.0, 2.0, -565.0),
		Vector3(260.0, 2.0, -565.0),
		Vector3(340.0, 2.0, -560.0),
		Vector3(420.0, 2.0, -555.0)
	]
	for p_cfg in pier_configs:
		var pw: float = 32.0
		var pd: float = 40.0
		_add_skyline_box(sky_st, Vector3(p_cfg.x - pw * 0.5, -25.0, p_cfg.z - pd * 0.5), Vector3(p_cfg.x + pw * 0.5, p_cfg.y, p_cfg.z + pd * 0.5), 2, 0.3)
		# Pier edge safety bumper curbs
		_add_skyline_box(sky_st, Vector3(p_cfg.x - pw * 0.5, p_cfg.y, p_cfg.z + pd * 0.5 - 1.2), Vector3(p_cfg.x + pw * 0.5, p_cfg.y + 0.8, p_cfg.z + pd * 0.5), 2, 0.05)

	# Clean open Tokyo Bay waterfront vista (unobstructed Tokyo Tower corridor)

	# =========================================================================
	# TIER 1: WATERFRONT LOGISTICS & HARUMI DOCKS (Z: -630m to -730m, X: 90m to 460m)
	# Cleanly spaced waterfront warehouses, tanks & commercial slabs across Tokyo Bay
	# =========================================================================
	for c in range(12):
		var b_w: float = 26.0 + float((c * 17) % 16)
		var b_d: float = 22.0 + float((c * 13) % 12)
		var b_h: float = 45.0 + float((c * 23) % 35)
		var b_x: float = 90.0 + float(c) * 30.0
		if b_x >= 170.0 and b_x <= 250.0:
			b_x += 80.0 # Keep Tokyo Tower vista corridor completely open
		var b_y: float = 2.0
		var b_z: float = -630.0 - float((c * 3) % 4) * 25.0

		var x_min: float = b_x - b_w * 0.5
		var x_max: float = b_x + b_w * 0.5
		var z_min: float = b_z - b_d
		var z_max: float = b_z
		var y_top: float = b_y + b_h

		var t1_style: int = 0
		var t1_seed: float = fposmod(float(c * 23) * 0.087, 1.0)
		if c % 4 == 0:
			t1_style = 2 # Keihin Industrial Factory / Corrugated Warehouse
			_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), t1_style, t1_seed)
			_add_industrial_silo(sky_st, Vector3(b_x + b_w * 0.5 + 4.0, b_y, (z_min + z_max) * 0.5), 5.5, b_h * 0.75, 3.2, t1_seed)
		elif c % 4 == 1:
			t1_style = 4 # Shuto Expressway Cyber Neon Commercial Signboard
			_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), t1_style, t1_seed)
			var bb_w: float = b_w * 0.75
			_add_skyline_box(sky_st, Vector3(b_x - bb_w * 0.5, y_top + 2.0, z_max - 2.5), Vector3(b_x + bb_w * 0.5, y_top + 14.0, z_max - 0.5), 4, t1_seed)
		elif c % 4 == 2:
			t1_style = 5 # Chemical / LNG Storage Silo Cluster
			_add_industrial_silo(sky_st, Vector3(b_x, b_y, (z_min + z_max) * 0.5), b_w * 0.40, b_h * 0.85, 3.2, t1_seed)
			_add_industrial_chimney(sky_st, Vector3(b_x + b_w * 0.55, b_y, z_max), 3.2, 1.6, b_h * 1.15, t1_seed)
		else:
			t1_style = 0 # Corporate Ribbon Windows
			_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), t1_style, t1_seed)

	# =========================================================================
	# PRODUCTION-GRADE 3D LANDMARK 1: TOKYO TOWER (X: 210m, Z: -750m, Height: 340m)
	# Iconic landmark vista right across Tokyo Bay, framed beautifully in player camera
	# =========================================================================
	_add_3d_tokyo_tower(sky_st, Vector3(210.0, 4.0, -750.0), 340.0)

	# =========================================================================
	# TIER 2: MIDTOWN METROPOLIS CORE (Z: -780m to -1005m, X: 100m to 460m)
	# Stepped Ziggurats, Shinjuku Twin Towers with Skybridges, Rotundas, Pinnacles
	# =========================================================================
	for c in range(20):
		var arch_type: int = c % 6
		var b_w: float = 34.0 + float((c * 13) % 20)
		var b_d: float = 30.0 + float((c * 19) % 16)
		var b_h: float = 140.0 + float((c * 31) % 110)
		var b_x: float = 100.0 + float(c) * 18.0
		if b_x >= 180.0 and b_x <= 240.0:
			b_x += 65.0 # Keep Tokyo Tower corridor clear
		var b_y: float = 4.0
		var b_z: float = -780.0 - float((c * 5) % 6) * 45.0
		var t2_seed: float = fposmod(float(c * 31) * 0.091, 1.0)

		var x_min: float = b_x - b_w * 0.5
		var x_max: float = b_x + b_w * 0.5
		var z_min: float = b_z - b_d
		var z_max: float = b_z
		var y_top: float = b_y + b_h

		match arch_type:
			0: # ARCHETYPE 0: Multi-Tier Stepped Ziggurat Tower (Roppongi Hills Style)
				var tier1_h: float = b_h * 0.48
				var tier2_h: float = b_h * 0.80
				_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, b_y + tier1_h, z_max), 0, t2_seed)
				var t2_xmin: float = b_x - b_w * 0.38; var t2_xmax: float = b_x + b_w * 0.38
				var t2_zmin: float = (z_min + z_max) * 0.5 - b_d * 0.38; var t2_zmax: float = (z_min + z_max) * 0.5 + b_d * 0.38
				_add_skyline_box(sky_st, Vector3(t2_xmin, b_y + tier1_h, t2_zmin), Vector3(t2_xmax, b_y + tier2_h, t2_zmax), 0, t2_seed)
				var t3_xmin: float = b_x - b_w * 0.22; var t3_xmax: float = b_x + b_w * 0.22
				var t3_zmin: float = (z_min + z_max) * 0.5 - b_d * 0.22; var t3_zmax: float = (z_min + z_max) * 0.5 + b_d * 0.22
				_add_skyline_box(sky_st, Vector3(t3_xmin, b_y + tier2_h, t3_zmin), Vector3(t3_xmax, y_top, t3_zmax), 0, t2_seed)
				var sp_base := Vector3(b_x, y_top, (z_min + z_max) * 0.5)
				sky_st.set_color(Color(0.7, t2_seed, 0.0, 1.0))
				sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(sp_base + Vector3(-1.8, 0.0, 0.0))
				sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(sp_base + Vector3(1.8, 0.0, 0.0))
				sky_st.set_uv(Vector2(0.5, 1.0));  sky_st.add_vertex(sp_base + Vector3(0.0, 36.0, 0.0))

			1: # ARCHETYPE 1: Tokyo Shinjuku Twin Towers with Skybridge (Tokyo Gov Building Style)
				var podium_h: float = 55.0
				_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, b_y + podium_h, z_max), 1, t2_seed)
				var tw_w: float = b_w * 0.38
				_add_skyline_box(sky_st, Vector3(x_min, b_y + podium_h, z_min), Vector3(x_min + tw_w, y_top, z_max), 1, t2_seed)
				_add_skyline_box(sky_st, Vector3(x_max - tw_w, b_y + podium_h, z_min), Vector3(x_max, y_top, z_max), 1, t2_seed)
				var sb_y: float = b_y + b_h * 0.60
				_add_skyline_box(sky_st, Vector3(x_min + tw_w * 0.85, sb_y, (z_min + z_max) * 0.5 - 6.0), Vector3(x_max - tw_w * 0.85, sb_y + 18.0, (z_min + z_max) * 0.5 + 6.0), 1, t2_seed)

			2: # ARCHETYPE 2: Keihin Petrochemical Distillation Plant & Flare Stack
				_add_industrial_silo(sky_st, Vector3(b_x, b_y, (z_min + z_max) * 0.5), b_w * 0.38, b_h * 0.70, 4.5, t2_seed)
				_add_industrial_chimney(sky_st, Vector3(b_x + b_w * 0.5, b_y, z_max), 4.2, 2.2, b_h * 0.90, t2_seed)

			3: # ARCHETYPE 3: Octagonal / Curved Rotunda Highrise with Cantilevered Helipad
				_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), 3, t2_seed)
				var ch_w: float = b_w * 0.28
				_add_skyline_box(sky_st, Vector3(b_x - ch_w, b_y, z_max - 4.0), Vector3(b_x + ch_w, y_top, z_max + 6.0), 3, t2_seed)
				_add_skyline_box(sky_st, Vector3(b_x - ch_w, b_y, z_min - 6.0), Vector3(b_x + ch_w, y_top, z_min + 4.0), 3, t2_seed)
				var hp_w: float = b_w * 0.65; var hp_d: float = b_d * 0.65
				_add_skyline_box(sky_st, Vector3(b_x - hp_w * 0.5, y_top + 2.0, (z_min + z_max) * 0.5 - hp_d * 0.5), Vector3(b_x + hp_w * 0.5, y_top + 6.0, (z_min + z_max) * 0.5 + hp_d * 0.5), 0, t2_seed)

			4: # ARCHETYPE 4: Broad Commercial Slab with Cyber Neon Signs
				_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), 4, t2_seed)
				_add_skyline_box(sky_st, Vector3(x_min + 4.0, y_top, (z_min + z_max) * 0.5 - 7.0), Vector3(x_min + 18.0, y_top + 16.0, (z_min + z_max) * 0.5 + 7.0), 4, t2_seed)
				_add_skyline_box(sky_st, Vector3(x_max - 18.0, y_top, (z_min + z_max) * 0.5 - 7.0), Vector3(x_max - 4.0, y_top + 16.0, (z_min + z_max) * 0.5 + 7.0), 4, t2_seed)

			_: # ARCHETYPE 5: Supertall Needle Pinnacle with Telescopic Crown
				var core_w: float = b_w * 0.70; var core_d: float = b_d * 0.70
				_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top - 40.0, z_max), 1, t2_seed)
				_add_skyline_box(sky_st, Vector3(b_x - core_w * 0.5, y_top - 40.0, (z_min + z_max) * 0.5 - core_d * 0.5), Vector3(b_x + core_w * 0.5, y_top - 15.0, (z_min + z_max) * 0.5 + core_d * 0.5), 1, t2_seed)
				_add_skyline_box(sky_st, Vector3(b_x - core_w * 0.25, y_top - 15.0, (z_min + z_max) * 0.5 - core_d * 0.25), Vector3(b_x + core_w * 0.25, y_top, (z_min + z_max) * 0.5 + core_d * 0.25), 1, t2_seed)
				var pin_base := Vector3(b_x, y_top, (z_min + z_max) * 0.5)
				sky_st.set_color(Color(0.7, t2_seed, 0.0, 1.0))
				sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(pin_base + Vector3(-1.8, 0.0, 0.0))
				sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(pin_base + Vector3(1.8, 0.0, 0.0))
				sky_st.set_uv(Vector2(0.5, 1.0));  sky_st.add_vertex(pin_base + Vector3(0.0, 42.0, 0.0))

	# =========================================================================
	# TIER 3: DISTANT HORIZON MEGATOWERS (Z: -1050m to -1275m, X: 110m to 460m)
	# Towering 200m to 380m Megastructures dissolved into horizon haze
	# =========================================================================
	for c in range(16):
		var b_w: float = 40.0 + float((c * 19) % 22)
		var b_d: float = 34.0 + float((c * 23) % 18)
		var b_h: float = 200.0 + float((c * 37) % 130)
		var b_x: float = 110.0 + float(c) * 22.0
		if b_x >= 350.0 and b_x <= 410.0:
			b_x += 60.0 # Open corridor for Tokyo Skytree
		var b_y: float = 4.0
		var b_z: float = -1050.0 - float((c * 7) % 6) * 45.0
		var t3_seed: float = fposmod(float(c * 37) * 0.079, 1.0)
		var t3_style: int = 1 if (c % 2 == 0) else 0

		var x_min: float = b_x - b_w * 0.5
		var x_max: float = b_x + b_w * 0.5
		var z_min: float = b_z - b_d
		var z_max: float = b_z
		var y_top: float = b_y + b_h

		_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top, z_max), t3_style, t3_seed)

		var sp_base := Vector3(b_x, y_top, (z_min + z_max) * 0.5)
		sky_st.set_color(Color(0.7, t3_seed, 0.0, 1.0))
		sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(sp_base + Vector3(-2.2, 0.0, 0.0))
		sky_st.set_uv(Vector2(0.5, 0.98)); sky_st.add_vertex(sp_base + Vector3(2.2, 0.0, 0.0))
		sky_st.set_uv(Vector2(0.5, 1.0));  sky_st.add_vertex(sp_base + Vector3(0.0, 48.0, 0.0))

	# =========================================================================
	# PRODUCTION-GRADE 3D LANDMARK 2: TOKYO SKYTREE (X: 380m, Z: -1180m, Height: 480m)
	# Towering Tripod Lattice Shaft, Tembo Deck, Tembo Galleria & Spire
	# =========================================================================
	_add_3d_skytree(sky_st, Vector3(380.0, 4.0, -1180.0), 480.0)

	# =========================================================================
	# TIER 4: KEIHIN INDUSTRIAL REFINERY HARBOR & SMOKESTACKS (X: 320m to 510m, Z: -820m to -1000m)
	# Distant coastal factories, chemical silos and hazard-band smokestacks along right horizon
	# =========================================================================
	for c in range(12):
		var b_w: float = 38.0 + float((c * 17) % 20)
		var b_d: float = 32.0 + float((c * 13) % 16)
		var b_h: float = 90.0 + float((c * 19) % 65)
		var b_x: float = 320.0 + float(c) * 16.0
		var b_y: float = 4.0
		var b_z: float = -820.0 - float((c * 3) % 4) * 60.0
		var t4_seed: float = fposmod(float(c * 29) * 0.083, 1.0)

		var x_min: float = b_x - b_w * 0.5
		var x_max: float = b_x + b_w * 0.5
		var z_min: float = b_z - b_d
		var z_max: float = b_z
		var y_top: float = b_y + b_h

		if c % 3 == 0:
			# Hazard-striped industrial chimney & factory block
			_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top * 0.55, z_max), 2, t4_seed)
			_add_industrial_chimney(sky_st, Vector3(b_x + b_w * 0.45, b_y, z_max), 4.5, 2.2, b_h * 1.25, t4_seed)
		elif c % 3 == 1:
			# Chemical storage silo battery
			_add_industrial_silo(sky_st, Vector3(b_x, b_y, (z_min + z_max) * 0.5), b_w * 0.42, b_h * 0.70, 4.0, t4_seed)
			_add_industrial_chimney(sky_st, Vector3(b_x - b_w * 0.45, b_y, z_min), 4.0, 1.8, b_h * 1.10, t4_seed)
		else:
			# Port logistics warehouse
			_add_skyline_box(sky_st, Vector3(x_min, b_y, z_min), Vector3(x_max, y_top * 0.65, z_max), 2, t4_seed)

	# =========================================================================
	# TIER 5: SWEEPING DISTANT WEST BAY SILHOUETTES (X: 70m to 170m, Z: -950m to -1050m)
	# Panoramic metropolis towers peeking between distant saddles across Tokyo Bay
	# =========================================================================
	for c in range(5):
		var b_w: float = 34.0 + float(c * 8)
		var b_d: float = 28.0
		var b_h: float = 140.0 + float(c * 28)
		var b_x: float = 70.0 + float(c) * 20.0
		var b_y: float = 4.0
		var b_z: float = -950.0 - float(c * 25)
		var t5_seed: float = fposmod(float(c * 41) * 0.081, 1.0)
		_add_skyline_box(sky_st, Vector3(b_x - b_w * 0.5, b_y, b_z - b_d), Vector3(b_x + b_w * 0.5, b_y + b_h, b_z), 0, t5_seed)

	var sky_mesh := sky_st.commit()
	var sky_inst := MeshInstance3D.new()
	sky_inst.mesh = sky_mesh
	sky_inst.material_override = skyline_mat
	sky_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background_rig.add_child(sky_inst)

	# Tokyo Bay Water Horizon Plane (Eliminates dark void beneath distant skyline)
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(4000.0, 4000.0)
	water_mesh.orientation = PlaneMesh.FACE_Y
	var water_inst := MeshInstance3D.new()
	water_inst.name = "TokyoBayWater"
	water_inst.mesh = water_mesh
	water_inst.material_override = tokyo_bay_water_mat
	water_inst.position = Vector3(300.0, -6.5, -850.0)
	water_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background_rig.add_child(water_inst)

	# 3. Horizontal Layered Anime Cloud Strips along Horizon (Purged blinding white glare bar per mandate)
	bg_cloud_mat = StandardMaterial3D.new()
	bg_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_cloud_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bg_cloud_mat.albedo_color = Color(0, 0, 0, 0) # Clear: eliminates giant white glare bar across sunset/sky gradient
	bg_cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for cl in range(4):
		var cloud := MeshInstance3D.new()
		var cl_mesh := PlaneMesh.new()
		cl_mesh.size = Vector2(580.0, 12.0 + float(cl) * 4.0)
		cl_mesh.orientation = PlaneMesh.FACE_Z
		cloud.mesh = cl_mesh
		cloud.material_override = bg_cloud_mat
		cloud.position = Vector3(0.0, 52.0 + float(cl) * 16.0, -350.0 - float(cl) * 15.0)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background_rig.add_child(cloud)

# ==============================================================================
# 3. HIGH-PRECISION COMIC VEHICLE MATERIALS (DETERMINISTIC CLASSIFIER)
# ==============================================================================
func _apply_comic_materials_to_model(root: Node, model_type: String, primary_color: Color, td: TrafficVehicleData = null) -> void:
	var sun_fwd := -sun_light.global_transform.basis.z if is_instance_valid(sun_light) else Vector3(-0.5, -0.8, -0.3)
	var b_mat := MaterialFailsafe.apply_vehicle_materials(root, model_type, primary_color, sun_fwd, false, td)
	if td != null:
		td.body_mat = b_mat

# ==============================================================================
# 4. MATHEMATICAL ROAD SPLINE (NATURAL SMOOTH CURVES & TRUE TANGENTS)
# ==============================================================================
func _sample_road_x(world_z: float) -> float:
	return sin(world_z * 0.015 + road_curve_seed) * 14.0

func _sample_road_bank(world_z: float) -> float:
	return cos(world_z * 0.015 + road_curve_seed) * 0.08

func _sample_road_tangent(world_z: float) -> Vector3:
	var dx_dz: float = 0.015 * 14.0 * cos(world_z * 0.015 + road_curve_seed)
	return Vector3(-dx_dz, 0.0, -1.0).normalized()

func _sample_road_right(world_z: float) -> Vector3:
	var dx_dz: float = 0.015 * 14.0 * cos(world_z * 0.015 + road_curve_seed)
	return Vector3(1.0, 0.0, -dx_dz).normalized()

func _sample_hillside_height(gz: float, lat: float) -> float:
	var n_macro: float = sin(gz * 0.012) * 5.5 + cos(gz * 0.027) * 3.5
	var n_meso: float = sin(gz * 0.048) * 2.2 + cos(gz * 0.088) * 1.4
	var n_micro: float = sin(gz * 0.13) * 0.8 + cos(gz * 0.26) * 0.5

	var h0: float = 0.0
	var h1: float = 1.2 + n_micro * 0.2
	var h2: float = 1.8 + n_micro * 0.3
	var h3: float = 6.2 + n_micro * 0.4
	var h4: float = 7.0 + n_meso * 0.5
	var h5: float = 15.5 + n_meso * 0.8
	var h6: float = 16.8 + n_macro * 0.7
	var h7: float = 36.0 + n_macro * 1.8
	var h8: float = 48.0 + n_macro * 2.2
	var h9: float = -6.0

	if lat <= 0.0:
		return 0.0
	elif lat <= 1.0:
		return lerp(h0, h1, lat / 1.0)
	elif lat <= 7.5:
		return lerp(h1, h2, (lat - 1.0) / 6.5)
	elif lat <= 8.5:
		return lerp(h2, h3, (lat - 7.5) / 1.0)
	elif lat <= 20.0:
		return lerp(h3, h4, (lat - 8.5) / 11.5)
	elif lat <= 21.5:
		return lerp(h4, h5, (lat - 20.0) / 1.5)
	elif lat <= 38.0:
		return lerp(h5, h6, (lat - 21.5) / 16.5)
	elif lat <= 72.0:
		return lerp(h6, h7, (lat - 38.0) / 34.0)
	elif lat <= 125.0:
		return lerp(h7, h8, (lat - 72.0) / 53.0)
	elif lat <= 170.0:
		return lerp(h8, h9, (lat - 125.0) / 45.0)
	else:
		return h9

func _add_skyline_box(st: SurfaceTool, min_pt: Vector3, max_pt: Vector3, style_id: int = 0, seed_val: float = 0.5) -> void:
	var x_min := min_pt.x; var x_max := max_pt.x
	var y_min := min_pt.y; var y_max := max_pt.y
	var z_min := min_pt.z; var z_max := max_pt.z

	var w_x: float = absf(x_max - x_min)
	var h_y: float = absf(y_max - y_min)
	var d_z: float = absf(z_max - z_min)

	var col := Color(float(style_id) / 10.0, seed_val, 0.0, 1.0)

	# Front (+Z face)
	st.set_color(col); st.set_normal(Vector3(0, 0, 1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_max))
	st.set_uv(Vector2(w_x, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_max))
	st.set_uv(Vector2(w_x, h_y)); st.add_vertex(Vector3(x_max, y_max, z_max))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_max))
	st.set_uv(Vector2(w_x, h_y)); st.add_vertex(Vector3(x_max, y_max, z_max))
	st.set_uv(Vector2(0.0, h_y)); st.add_vertex(Vector3(x_min, y_max, z_max))

	# Left (-X, road/camera facing)
	st.set_color(col); st.set_normal(Vector3(-1, 0, 0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_min))
	st.set_uv(Vector2(d_z, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_max))
	st.set_uv(Vector2(d_z, h_y)); st.add_vertex(Vector3(x_min, y_max, z_max))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_min))
	st.set_uv(Vector2(d_z, h_y)); st.add_vertex(Vector3(x_min, y_max, z_max))
	st.set_uv(Vector2(0.0, h_y)); st.add_vertex(Vector3(x_min, y_max, z_min))

	# Right (+X face)
	st.set_color(col); st.set_normal(Vector3(1, 0, 0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_max))
	st.set_uv(Vector2(d_z, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_min))
	st.set_uv(Vector2(d_z, h_y)); st.add_vertex(Vector3(x_max, y_max, z_min))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_max))
	st.set_uv(Vector2(d_z, h_y)); st.add_vertex(Vector3(x_max, y_max, z_min))
	st.set_uv(Vector2(0.0, h_y)); st.add_vertex(Vector3(x_max, y_max, z_max))

	# Back (-Z face)
	st.set_color(col); st.set_normal(Vector3(0, 0, -1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_min))
	st.set_uv(Vector2(w_x, 0.0)); st.add_vertex(Vector3(x_min, y_min, z_min))
	st.set_uv(Vector2(w_x, h_y)); st.add_vertex(Vector3(x_min, y_max, z_min))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_min, z_min))
	st.set_uv(Vector2(w_x, h_y)); st.add_vertex(Vector3(x_min, y_max, z_min))
	st.set_uv(Vector2(0.0, h_y)); st.add_vertex(Vector3(x_max, y_max, z_min))

	# Roof (+Y face)
	st.set_color(col); st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_max, z_min))
	st.set_uv(Vector2(w_x, 0.0)); st.add_vertex(Vector3(x_max, y_max, z_min))
	st.set_uv(Vector2(w_x, d_z)); st.add_vertex(Vector3(x_max, y_max, z_max))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_max, z_min))
	st.set_uv(Vector2(w_x, d_z)); st.add_vertex(Vector3(x_max, y_max, z_max))
	st.set_uv(Vector2(0.0, d_z)); st.add_vertex(Vector3(x_min, y_max, z_max))

func _add_industrial_silo(st: SurfaceTool, center: Vector3, radius: float, height: float, cap_height: float, seed_val: float = 0.5) -> void:
	var sides := 8
	var col := Color(0.5, seed_val, 0.0, 1.0) # Style 5: Industrial Silo ("कारखाने")
	for s in range(sides):
		var a0: float = float(s) / float(sides) * TAU
		var a1: float = float(s + 1) / float(sides) * TAU
		var p0_bot := center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1_bot := center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var p0_top := p0_bot + Vector3(0.0, height, 0.0)
		var p1_top := p1_bot + Vector3(0.0, height, 0.0)

		var n := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5)).normalized()
		var u0: float = float(s) * (radius * TAU / float(sides))
		var u1: float = float(s + 1) * (radius * TAU / float(sides))

		st.set_color(col); st.set_normal(n)
		st.set_uv(Vector2(u0, 0.0));    st.add_vertex(p0_bot)
		st.set_uv(Vector2(u1, 0.0));    st.add_vertex(p1_bot)
		st.set_uv(Vector2(u1, height)); st.add_vertex(p1_top)

		st.set_color(col); st.set_normal(n)
		st.set_uv(Vector2(u0, 0.0));    st.add_vertex(p0_bot)
		st.set_uv(Vector2(u1, height)); st.add_vertex(p1_top)
		st.set_uv(Vector2(u0, height)); st.add_vertex(p0_top)

		# Dome/Conical cap
		var apex := center + Vector3(0.0, height + cap_height, 0.0)
		var n_cap := Vector3(cos((a0 + a1) * 0.5), 0.6, sin((a0 + a1) * 0.5)).normalized()
		st.set_color(col); st.set_normal(n_cap)
		st.set_uv(Vector2(u0, height)); st.add_vertex(p0_top)
		st.set_uv(Vector2(u1, height)); st.add_vertex(p1_top)
		st.set_uv(Vector2((u0 + u1) * 0.5, height + cap_height)); st.add_vertex(apex)

func _add_industrial_chimney(st: SurfaceTool, center: Vector3, r_base: float, r_top: float, height: float, seed_val: float = 0.5) -> void:
	var sides := 8
	var col := Color(0.6, seed_val, 0.0, 1.0) # Style 6: Hazard Band Smokestack ("कारखाने")
	for s in range(sides):
		var a0: float = float(s) / float(sides) * TAU
		var a1: float = float(s + 1) / float(sides) * TAU
		var p0_bot := center + Vector3(cos(a0) * r_base, 0.0, sin(a0) * r_base)
		var p1_bot := center + Vector3(cos(a1) * r_base, 0.0, sin(a1) * r_base)
		var p0_top := center + Vector3(cos(a0) * r_top, height, sin(a0) * r_top)
		var p1_top := center + Vector3(cos(a1) * r_top, height, sin(a1) * r_top)

		var n := Vector3(cos((a0 + a1) * 0.5), 0.1, sin((a0 + a1) * 0.5)).normalized()
		var u0: float = float(s) * 2.0
		var u1: float = float(s + 1) * 2.0

		st.set_color(col); st.set_normal(n)
		st.set_uv(Vector2(u0, 0.0));    st.add_vertex(p0_bot)
		st.set_uv(Vector2(u1, 0.0));    st.add_vertex(p1_bot)
		st.set_uv(Vector2(u1, height)); st.add_vertex(p1_top)

		st.set_color(col); st.set_normal(n)
		st.set_uv(Vector2(u0, 0.0));    st.add_vertex(p0_bot)
		st.set_uv(Vector2(u1, height)); st.add_vertex(p1_top)
		st.set_uv(Vector2(u0, height)); st.add_vertex(p0_top)

func _add_industrial_shed(st: SurfaceTool, center: Vector3, len_z: float, width_x: float, wall_h: float, roof_h: float, is_sawtooth: bool, seed_val: float = 0.5) -> void:
	var x_min := center.x - width_x * 0.5
	var x_max := center.x + width_x * 0.5
	var z_min := center.z - len_z * 0.5
	var z_max := center.z + len_z * 0.5
	var y_bot := center.y
	var y_wall := y_bot + wall_h

	# Main corrugated factory box
	_add_skyline_box(st, Vector3(x_min, y_bot, z_min), Vector3(x_max, y_wall, z_max), 2, seed_val)

	var col := Color(0.2, seed_val, 0.0, 1.0)
	if is_sawtooth:
		var num_teeth := 3
		var tooth_len := len_z / float(num_teeth)
		for t in range(num_teeth):
			var tz0 := z_min + float(t) * tooth_len
			var tz1 := tz0 + tooth_len
			var t_apex_z := tz0 + tooth_len * 0.35
			# Slanted back slope
			st.set_color(col); st.set_normal(Vector3(0, 0.8, 0.6).normalized())
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, tz1))
			st.set_uv(Vector2(width_x, 0.0)); st.add_vertex(Vector3(x_max, y_wall, tz1))
			st.set_uv(Vector2(width_x, roof_h)); st.add_vertex(Vector3(x_max, y_wall + roof_h, t_apex_z))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, tz1))
			st.set_uv(Vector2(width_x, roof_h)); st.add_vertex(Vector3(x_max, y_wall + roof_h, t_apex_z))
			st.set_uv(Vector2(0.0, roof_h)); st.add_vertex(Vector3(x_min, y_wall + roof_h, t_apex_z))
			# Vertical glass clerestory face
			st.set_color(col); st.set_normal(Vector3(0, 0, -1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, tz0))
			st.set_uv(Vector2(width_x, 0.0)); st.add_vertex(Vector3(x_max, y_wall, tz0))
			st.set_uv(Vector2(width_x, roof_h)); st.add_vertex(Vector3(x_max, y_wall + roof_h, t_apex_z))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, tz0))
			st.set_uv(Vector2(width_x, roof_h)); st.add_vertex(Vector3(x_max, y_wall + roof_h, t_apex_z))
			st.set_uv(Vector2(0.0, roof_h)); st.add_vertex(Vector3(x_min, y_wall + roof_h, t_apex_z))
	else:
		var ridge_x := (x_min + x_max) * 0.5
		# Left roof pitch
		st.set_color(col); st.set_normal(Vector3(-0.6, 0.8, 0).normalized())
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, z_min))
		st.set_uv(Vector2(0.0, len_z)); st.add_vertex(Vector3(x_min, y_wall, z_max))
		st.set_uv(Vector2(roof_h, len_z)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_max))
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_min, y_wall, z_min))
		st.set_uv(Vector2(roof_h, len_z)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_max))
		st.set_uv(Vector2(roof_h, 0.0)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_min))
		# Right roof pitch
		st.set_color(col); st.set_normal(Vector3(0.6, 0.8, 0).normalized())
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_wall, z_max))
		st.set_uv(Vector2(0.0, len_z)); st.add_vertex(Vector3(x_max, y_wall, z_min))
		st.set_uv(Vector2(roof_h, len_z)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_min))
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x_max, y_wall, z_max))
		st.set_uv(Vector2(roof_h, len_z)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_min))
		st.set_uv(Vector2(roof_h, 0.0)); st.add_vertex(Vector3(ridge_x, y_wall + roof_h, z_max))

func _add_neon_billboard(st: SurfaceTool, center: Vector3, w: float, h: float, seed_val: float = 0.5) -> void:
	var pole_w: float = 0.65
	_add_skyline_box(st, Vector3(center.x - pole_w * 0.5, center.y, center.z - pole_w * 0.5), Vector3(center.x + pole_w * 0.5, center.y + 7.5, center.z + pole_w * 0.5), 1, 0.1)
	var sign_y0 := center.y + 7.5
	var sign_y1 := sign_y0 + h
	_add_skyline_box(st, Vector3(center.x - 0.45, sign_y0, center.z - w * 0.5), Vector3(center.x + 0.45, sign_y1, center.z + w * 0.5), 4, seed_val)

func _add_3d_tokyo_tower(st: SurfaceTool, center: Vector3, total_h: float) -> void:
	var base_y: float = center.y
	var cx: float = center.x
	var cz: float = center.z

	var w_base: float = 38.0
	var d_base: float = 38.0
	var h_lower: float = 105.0
	var w_deck1: float = 28.0
	var h_deck1: float = 18.0
	var h_mid: float = 58.0
	var w_deck2: float = 15.0
	var h_deck2: float = 12.0

	var y_deck1_bot: float = base_y + h_lower
	var y_deck1_top: float = y_deck1_bot + h_deck1
	var y_deck2_bot: float = y_deck1_top + h_mid
	var y_deck2_top: float = y_deck2_bot + h_deck2
	var y_tip: float = base_y + total_h

	# 1. Four 3D Lattice Legs & Pyramidal Frustum
	var hw0 := w_base * 0.5
	var hd0 := d_base * 0.5
	var hw1 := 9.0
	var hd1 := 9.0

	# 4 Corner lattice column pillars
	var leg_w: float = 2.4
	var corners := [
		[Vector3(cx - hw0, base_y, cz - hd0), Vector3(cx - hw1, y_deck1_bot, cz - hd1)],
		[Vector3(cx + hw0, base_y, cz - hd0), Vector3(cx + hw1, y_deck1_bot, cz - hd1)],
		[Vector3(cx + hw0, base_y, cz + hd0), Vector3(cx + hw1, y_deck1_bot, cz + hd1)],
		[Vector3(cx - hw0, base_y, cz + hd0), Vector3(cx - hw1, y_deck1_bot, cz + hd1)]
	]
	for c in corners:
		var p0: Vector3 = c[0]
		var p1: Vector3 = c[1]
		_add_skyline_box(st, Vector3(p0.x - leg_w * 0.5, p0.y, p0.z - leg_w * 0.5), Vector3(p1.x + leg_w * 0.5, p1.y, p1.z + leg_w * 0.5), 7, 0.45)

	# 4 Slanted Lattice Truss Faces (South, North, East, West)
	var col_tt := Color(0.7, 0.5, 0.0, 1.0) # Style 7
	# South Face (+Z)
	st.set_color(col_tt); st.set_normal(Vector3(0.0, 0.15, 0.98).normalized())
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz + hd0))
	st.set_uv(Vector2(w_base, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz + hd0))
	st.set_uv(Vector2(hw1 * 2.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz + hd1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz + hd0))
	st.set_uv(Vector2(hw1 * 2.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz + hd1))
	st.set_uv(Vector2(0.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz + hd1))

	# North Face (-Z)
	st.set_color(col_tt); st.set_normal(Vector3(0.0, 0.15, -0.98).normalized())
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz - hd0))
	st.set_uv(Vector2(w_base, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz - hd0))
	st.set_uv(Vector2(hw1 * 2.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz - hd1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz - hd0))
	st.set_uv(Vector2(hw1 * 2.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz - hd1))
	st.set_uv(Vector2(0.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz - hd1))

	# West Face (-X)
	st.set_color(col_tt); st.set_normal(Vector3(-0.98, 0.15, 0.0).normalized())
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz - hd0))
	st.set_uv(Vector2(d_base, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz + hd0))
	st.set_uv(Vector2(hd1 * 2.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz + hd1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx - hw0, base_y, cz - hd0))
	st.set_uv(Vector2(hd1 * 2.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz + hd1))
	st.set_uv(Vector2(0.0, h_lower)); st.add_vertex(Vector3(cx - hw1, y_deck1_bot, cz - hd1))

	# East Face (+X)
	st.set_color(col_tt); st.set_normal(Vector3(0.98, 0.15, 0.0).normalized())
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz + hd0))
	st.set_uv(Vector2(d_base, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz - hd0))
	st.set_uv(Vector2(hd1 * 2.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz - hd1))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(cx + hw0, base_y, cz + hd0))
	st.set_uv(Vector2(hd1 * 2.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz - hd1))
	st.set_uv(Vector2(0.0, h_lower)); st.add_vertex(Vector3(cx + hw1, y_deck1_bot, cz + hd1))

	# 2. Main 3D Observation Deck (Two-story deck with glowing windows)
	_add_skyline_box(st, Vector3(cx - w_deck1 * 0.5, y_deck1_bot, cz - w_deck1 * 0.5), Vector3(cx + w_deck1 * 0.5, y_deck1_top, cz + w_deck1 * 0.5), 7, 0.65)
	# Cantilevered observation roof ledge
	_add_skyline_box(st, Vector3(cx - (w_deck1 + 3.0) * 0.5, y_deck1_top, cz - (w_deck1 + 3.0) * 0.5), Vector3(cx + (w_deck1 + 3.0) * 0.5, y_deck1_top + 2.5, cz + (w_deck1 + 3.0) * 0.5), 7, 0.1)

	# 3. Upper Lattice Shaft (Tapering from 13m to 5m)
	var hw2 := 6.5
	_add_skyline_box(st, Vector3(cx - hw2, y_deck1_top + 2.5, cz - hw2), Vector3(cx + hw2, y_deck2_bot, cz + hw2), 7, 0.75)

	# 4. Upper Observation Deck (Tembo Galleria)
	_add_skyline_box(st, Vector3(cx - w_deck2 * 0.5, y_deck2_bot, cz - w_deck2 * 0.5), Vector3(cx + w_deck2 * 0.5, y_deck2_top, cz + w_deck2 * 0.5), 7, 0.90)

	# 5. Spire Telecommunication Needle Mast & Strobing Red Beacon
	var sp_w := 2.2
	_add_skyline_box(st, Vector3(cx - sp_w * 0.5, y_deck2_top, cz - sp_w * 0.5), Vector3(cx + sp_w * 0.5, y_tip - 12.0, cz + sp_w * 0.5), 7, 0.2)
	# Antenna needle tip
	st.set_color(Color(0.7, 0.95, 0.0, 1.0))
	st.set_uv(Vector2(0.5, 0.95)); st.add_vertex(Vector3(cx - 0.9, y_tip - 12.0, cz))
	st.set_uv(Vector2(0.5, 0.95)); st.add_vertex(Vector3(cx + 0.9, y_tip - 12.0, cz))
	st.set_uv(Vector2(0.5, 1.0));  st.add_vertex(Vector3(cx, y_tip, cz))

func _add_rainbow_bridge(st: SurfaceTool, x_start: float, x_end: float, z_pos: float, deck_y: float) -> void:
	var deck_w: float = 14.0
	var truss_h: float = 6.0
	var z_min := z_pos - deck_w * 0.5
	var z_max := z_pos + deck_w * 0.5

	# 1. Main Double-Deck Truss Roadway Viaduct
	_add_skyline_box(st, Vector3(x_start, deck_y - truss_h, z_min), Vector3(x_end, deck_y, z_max), 8, 0.25)

	# Highway Approach Abutments (Solid Concrete Piers anchoring into water and land)
	_add_skyline_box(st, Vector3(x_start - 14.0, -25.0, z_min - 2.0), Vector3(x_start + 4.0, deck_y, z_max + 2.0), 2, 0.2)
	_add_skyline_box(st, Vector3(x_end - 4.0, -25.0, z_min - 2.0), Vector3(x_end + 14.0, deck_y, z_max + 2.0), 2, 0.2)

	# Roadway barrier curbs with sodium pearl lights
	_add_skyline_box(st, Vector3(x_start, deck_y, z_min), Vector3(x_end, deck_y + 1.2, z_min + 0.8), 8, 0.1)
	_add_skyline_box(st, Vector3(x_start, deck_y, z_max - 0.8), Vector3(x_end, deck_y + 1.2, z_max), 8, 0.1)

	# 2. Twin Suspension Towers (H-Frames spaced along span)
	var span_len: float = x_end - x_start
	var tower_xs := [x_start + span_len * 0.28, x_start + span_len * 0.72]
	var tower_top_y := deck_y + 112.0 # Total height ~112m above deck
	var pylon_w: float = 3.6
	var cable_z1 := z_pos - 6.2
	var cable_z2 := z_pos + 6.2

	for tx in tower_xs:
		# Front column (-Z) plunging into maritime caisson
		_add_skyline_box(st, Vector3(tx - pylon_w * 0.5, -25.0, cable_z1 - pylon_w * 0.5), Vector3(tx + pylon_w * 0.5, tower_top_y, cable_z1 + pylon_w * 0.5), 8, 0.5)
		# Back column (+Z) plunging into maritime caisson
		_add_skyline_box(st, Vector3(tx - pylon_w * 0.5, -25.0, cable_z2 - pylon_w * 0.5), Vector3(tx + pylon_w * 0.5, tower_top_y, cable_z2 + pylon_w * 0.5), 8, 0.5)
		# Massive Tokyo Bay Concrete Maritime Caisson Pier (Pylon foundation rising from bay bedrock)
		_add_skyline_box(st, Vector3(tx - 12.0, -25.0, z_pos - 12.0), Vector3(tx + 12.0, 3.5, z_pos + 12.0), 2, 0.25)
		_add_skyline_box(st, Vector3(tx - 13.0, 2.5, z_pos - 13.0), Vector3(tx + 13.0, 4.2, z_pos + 13.0), 2, 0.1)
		# Horizontal H-Frame Crossbeams
		_add_skyline_box(st, Vector3(tx - pylon_w * 0.4, deck_y - 8.0, cable_z1), Vector3(tx + pylon_w * 0.4, deck_y - 3.0, cable_z2), 8, 0.5)
		_add_skyline_box(st, Vector3(tx - pylon_w * 0.4, deck_y + 42.0, cable_z1), Vector3(tx + pylon_w * 0.4, deck_y + 47.0, cable_z2), 8, 0.5)
		_add_skyline_box(st, Vector3(tx - pylon_w * 0.4, tower_top_y - 8.0, cable_z1), Vector3(tx + pylon_w * 0.4, tower_top_y - 3.0, cable_z2), 8, 0.5)

	# 3. Sweeping Catenary Suspension Cables & Vertical Hangers
	var tx0: float = tower_xs[0]
	var tx1: float = tower_xs[1]
	var steps: int = 24
	var dx: float = (x_end - x_start) / float(steps)

	for cz in [cable_z1, cable_z2]:
		var prev_pt := Vector3(x_start, deck_y + 4.0, cz)
		for s in range(1, steps + 1):
			var x_cur: float = x_start + float(s) * dx
			var y_cur: float = deck_y
			if x_cur < tx0:
				var t: float = (x_cur - x_start) / (tx0 - x_start)
				y_cur = lerp(deck_y + 4.0, tower_top_y, t * t)
			elif x_cur <= tx1:
				var u: float = (x_cur - tx0) / (tx1 - tx0)
				# Parabolic dip sagging down towards deck
				y_cur = tower_top_y - 4.0 * u * (1.0 - u) * (tower_top_y - (deck_y + 12.0))
			else:
				var t: float = (x_cur - tx1) / (x_end - tx1)
				y_cur = lerp(tower_top_y, deck_y + 4.0, t * (2.0 - t))

			var cur_pt := Vector3(x_cur, y_cur, cz)
			# Cable segment
			_add_skyline_box(st, Vector3(minf(prev_pt.x, cur_pt.x), minf(prev_pt.y, cur_pt.y) - 0.4, cz - 0.4), Vector3(maxf(prev_pt.x, cur_pt.x), maxf(prev_pt.y, cur_pt.y) + 0.4, cz + 0.4), 8, 0.8)

			# Vertical suspender hanger wire dropping to deck
			if s % 2 == 0 and y_cur > deck_y + 2.0:
				_add_skyline_box(st, Vector3(x_cur - 0.25, deck_y, cz - 0.25), Vector3(x_cur + 0.25, y_cur, cz + 0.25), 8, 0.9)

			prev_pt = cur_pt

func _add_container_gantry_crane(st: SurfaceTool, pos: Vector3, scale_f: float, seed_val: float) -> void:
	var w: float = 14.0 * scale_f
	var d: float = 12.0 * scale_f
	var h: float = 38.0 * scale_f
	var leg_w: float = 1.6 * scale_f

	# 4 Corner A-Frame Legs (Style 6 - International Orange/White Hazard)
	_add_skyline_box(st, Vector3(pos.x - w * 0.5, pos.y, pos.z - d * 0.5), Vector3(pos.x - w * 0.5 + leg_w, pos.y + h, pos.z - d * 0.5 + leg_w), 6, seed_val)
	_add_skyline_box(st, Vector3(pos.x + w * 0.5 - leg_w, pos.y, pos.z - d * 0.5), Vector3(pos.x + w * 0.5, pos.y + h, pos.z - d * 0.5 + leg_w), 6, seed_val)
	_add_skyline_box(st, Vector3(pos.x - w * 0.5, pos.y, pos.z + d * 0.5 - leg_w), Vector3(pos.x - w * 0.5 + leg_w, pos.y + h, pos.z + d * 0.5), 6, seed_val)
	_add_skyline_box(st, Vector3(pos.x + w * 0.5 - leg_w, pos.y, pos.z + d * 0.5 - leg_w), Vector3(pos.x + w * 0.5, pos.y + h, pos.z + d * 0.5), 6, seed_val)

	# Overhead Crane Gantry Cantilever Boom Arm
	var boom_len: float = 32.0 * scale_f
	var boom_h: float = 4.2 * scale_f
	_add_skyline_box(st, Vector3(pos.x - w * 0.5 - 6.0 * scale_f, pos.y + h - boom_h, pos.z - d * 0.35), Vector3(pos.x - w * 0.5 + boom_len, pos.y + h, pos.z + d * 0.35), 6, seed_val)

	# Machinery Operator Cab & Counterweight
	_add_skyline_box(st, Vector3(pos.x - w * 0.5 - 8.0 * scale_f, pos.y + h - 2.0 * scale_f, pos.z - d * 0.45), Vector3(pos.x - w * 0.5 - 2.0 * scale_f, pos.y + h + 6.0 * scale_f, pos.z + d * 0.45), 2, seed_val)

func _add_3d_skytree(st: SurfaceTool, center: Vector3, total_h: float) -> void:
	var base_y: float = center.y
	var cx: float = center.x
	var cz: float = center.z

	var w_base: float = 48.0
	var h_lower: float = 135.0
	var w_deck1: float = 32.0
	var h_deck1: float = 18.0
	var h_mid: float = 62.0
	var w_deck2: float = 24.0
	var h_deck2: float = 14.0

	var y_d1_bot: float = base_y + h_lower
	var y_d1_top: float = y_d1_bot + h_deck1
	var y_d2_bot: float = y_d1_top + h_mid
	var y_d2_top: float = y_d2_bot + h_deck2
	var y_tip: float = base_y + total_h

	# Tripod lattice shaft tapering from 48m to 14m
	_add_industrial_silo(st, center, w_base * 0.35, h_lower, 0.0, 0.8)

	# Lower Observation Deck (Tembo Deck)
	_add_industrial_silo(st, Vector3(cx, y_d1_bot, cz), w_deck1 * 0.5, h_deck1, 2.0, 0.85)

	# Mid Shaft
	_add_industrial_silo(st, Vector3(cx, y_d1_top, cz), 7.5, h_mid, 0.0, 0.8)

	# Upper Observation Deck (Tembo Galleria)
	_add_industrial_silo(st, Vector3(cx, y_d2_bot, cz), w_deck2 * 0.5, h_deck2, 2.0, 0.90)

	# Needle Spire
	_add_skyline_box(st, Vector3(cx - 1.6, y_d2_top, cz - 1.6), Vector3(cx + 1.6, y_tip - 15.0, cz + 1.6), 7, 0.1)
	st.set_color(Color(0.7, 0.95, 0.0, 1.0))
	st.set_uv(Vector2(0.5, 0.95)); st.add_vertex(Vector3(cx - 1.0, y_tip - 15.0, cz))
	st.set_uv(Vector2(0.5, 0.95)); st.add_vertex(Vector3(cx + 1.0, y_tip - 15.0, cz))
	st.set_uv(Vector2(0.5, 1.0));  st.add_vertex(Vector3(cx, y_tip, cz))

# ==============================================================================
# PROCEDURAL 3D ANIME NATURE & GEOMETRY GENERATORS (ZERO 2D CARDS)
# Matching Anime Visual Standard: Puffy Trees, Conifers, Bamboo, Rocks, Terraces
# ==============================================================================
func _add_lowpoly_puff(st: SurfaceTool, center: Vector3, radius: Vector3, col: Color) -> void:
	var lats: int = 4
	var lons: int = 6
	for lat_i in range(lats):
		var phi0: float = -PI * 0.5 + PI * float(lat_i) / float(lats)
		var phi1: float = -PI * 0.5 + PI * float(lat_i + 1) / float(lats)
		var y0: float = sin(phi0) * radius.y
		var y1: float = sin(phi1) * radius.y
		var r0: float = cos(phi0)
		var r1: float = cos(phi1)

		for lon_i in range(lons):
			var theta0: float = TAU * float(lon_i) / float(lons)
			var theta1: float = TAU * float(lon_i + 1) / float(lons)

			var n00 := Vector3(cos(theta0) * r0, sin(phi0), sin(theta0) * r0).normalized()
			var n10 := Vector3(cos(theta1) * r0, sin(phi0), sin(theta1) * r0).normalized()
			var n11 := Vector3(cos(theta1) * r1, sin(phi1), sin(theta1) * r1).normalized()
			var n01 := Vector3(cos(theta0) * r1, sin(phi1), sin(theta0) * r1).normalized()

			var p00 := center + Vector3(n00.x * radius.x, y0, n00.z * radius.z)
			var p10 := center + Vector3(n10.x * radius.x, y0, n10.z * radius.z)
			var p11 := center + Vector3(n11.x * radius.x, y1, n11.z * radius.z)
			var p01 := center + Vector3(n01.x * radius.x, y1, n01.z * radius.z)

			st.set_color(col)
			if lat_i == 0:
				st.set_normal(n00); st.add_vertex(p00)
				st.set_normal(n01); st.add_vertex(p01)
				st.set_normal(n11); st.add_vertex(p11)
			elif lat_i == lats - 1:
				st.set_normal(n00); st.add_vertex(p00)
				st.set_normal(n01); st.add_vertex(p01)
				st.set_normal(n10); st.add_vertex(p10)
			else:
				st.set_normal(n00); st.add_vertex(p00)
				st.set_normal(n01); st.add_vertex(p01)
				st.set_normal(n11); st.add_vertex(p11)

				st.set_normal(n00); st.add_vertex(p00)
				st.set_normal(n11); st.add_vertex(p11)
				st.set_normal(n10); st.add_vertex(p10)

func _add_lowpoly_cone(st: SurfaceTool, base: Vector3, radius: float, height: float, col: Color, sides: int = 6) -> void:
	var apex := base + Vector3(0.0, height, 0.0)
	for s in range(sides):
		var a0: float = TAU * float(s) / float(sides)
		var a1: float = TAU * float(s + 1) / float(sides)
		var p0 := base + Vector3(cos(a0) * radius, -height * 0.12, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, -height * 0.12, sin(a1) * radius)

		var fn: Vector3 = (p1 - p0).cross(apex - p0).normalized()
		var radial_dir := Vector3(cos((a0 + a1) * 0.5), 0.2, sin((a0 + a1) * 0.5)).normalized()
		if fn.dot(radial_dir) < 0.0:
			fn = -fn

		st.set_color(col)
		st.set_normal(fn); st.add_vertex(p0)
		st.set_normal(fn); st.add_vertex(p1)
		st.set_normal(fn); st.add_vertex(apex)

func _add_lowpoly_cylinder(st: SurfaceTool, bot: Vector3, top: Vector3, r_bot: float, r_top: float, col: Color, sides: int = 5) -> void:
	for s in range(sides):
		var a0: float = TAU * float(s) / float(sides)
		var a1: float = TAU * float(s + 1) / float(sides)
		var p0_bot := bot + Vector3(cos(a0) * r_bot, 0.0, sin(a0) * r_bot)
		var p1_bot := bot + Vector3(cos(a1) * r_bot, 0.0, sin(a1) * r_bot)
		var p0_top := top + Vector3(cos(a0) * r_top, 0.0, sin(a0) * r_top)
		var p1_top := top + Vector3(cos(a1) * r_top, 0.0, sin(a1) * r_top)

		var fn: Vector3 = (p0_top - p0_bot).cross(p1_bot - p0_bot).normalized()
		var radial_dir := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		if fn.dot(radial_dir) < 0.0:
			fn = -fn

		st.set_color(col)
		st.set_normal(fn); st.add_vertex(p0_bot)
		st.set_normal(fn); st.add_vertex(p0_top)
		st.set_normal(fn); st.add_vertex(p1_top)

		st.set_normal(fn); st.add_vertex(p0_bot)
		st.set_normal(fn); st.add_vertex(p1_top)
		st.set_normal(fn); st.add_vertex(p1_bot)

func _add_3d_puffy_tree(st: SurfaceTool, ground_pos: Vector3, scale_f: float, _seed_val: float) -> void:
	var trunk_col := Color(0.12, 0.08, 0.05)
	var fol_crown := Color(0.09, 0.18, 0.10) # Natural cedar canopy crest
	var fol_main := Color(0.06, 0.13, 0.07)  # Deep Japanese mountain cedar viridian
	var fol_shade := Color(0.03, 0.07, 0.04) # Deep dense forest interior shadow

	# 1. Main Wooden Trunk & Branches
	var base_pt := ground_pos - Vector3(0.0, 0.4, 0.0)
	var mid_trunk := ground_pos + Vector3(0.0, 2.2 * scale_f, 0.0)
	_add_lowpoly_cylinder(st, base_pt, mid_trunk, 0.38 * scale_f, 0.25 * scale_f, trunk_col, 5)

	var br1_top := mid_trunk + Vector3(0.95 * scale_f, 1.3 * scale_f, 0.40 * scale_f)
	var br2_top := mid_trunk + Vector3(-0.85 * scale_f, 1.4 * scale_f, -0.45 * scale_f)
	_add_lowpoly_cylinder(st, mid_trunk, br1_top, 0.20 * scale_f, 0.12 * scale_f, trunk_col, 4)
	_add_lowpoly_cylinder(st, mid_trunk, br2_top, 0.18 * scale_f, 0.11 * scale_f, trunk_col, 4)

	# 2. Billowing Multi-Lobe Canopy Puffs
	_add_lowpoly_puff(st, mid_trunk + Vector3(0.0, 0.35 * scale_f, 0.0), Vector3(2.1, 1.2, 2.1) * scale_f, fol_shade)
	_add_lowpoly_puff(st, mid_trunk + Vector3(0.15 * scale_f, 1.3 * scale_f, 0.1 * scale_f), Vector3(1.85, 1.45, 1.85) * scale_f, fol_main)
	_add_lowpoly_puff(st, mid_trunk + Vector3(0.25 * scale_f, 2.4 * scale_f, -0.15 * scale_f), Vector3(1.55, 1.35, 1.55) * scale_f, fol_crown)
	_add_lowpoly_puff(st, br1_top + Vector3(0.40 * scale_f, 0.30 * scale_f, 0.20 * scale_f), Vector3(1.45, 1.25, 1.45) * scale_f, fol_crown)
	_add_lowpoly_puff(st, br2_top + Vector3(-0.40 * scale_f, 0.30 * scale_f, -0.20 * scale_f), Vector3(1.35, 1.15, 1.35) * scale_f, fol_main)
	_add_lowpoly_puff(st, mid_trunk + Vector3(-0.55 * scale_f, 0.65 * scale_f, 0.70 * scale_f), Vector3(1.40, 1.15, 1.40) * scale_f, fol_shade)
	_add_lowpoly_puff(st, mid_trunk + Vector3(0.50 * scale_f, 0.80 * scale_f, -0.65 * scale_f), Vector3(1.30, 1.10, 1.30) * scale_f, fol_shade)
	_add_lowpoly_puff(st, mid_trunk + Vector3(0.10 * scale_f, 3.2 * scale_f, 0.0), Vector3(1.20, 1.05, 1.20) * scale_f, fol_crown)

func _add_3d_pine_tree(st: SurfaceTool, ground_pos: Vector3, scale_f: float, _seed_val: float) -> void:
	var trunk_col := Color(0.18, 0.10, 0.06)
	var p_base := ground_pos - Vector3(0.0, 0.4, 0.0)
	var p_top := ground_pos + Vector3(0.0, 5.8 * scale_f, 0.0)
	_add_lowpoly_cylinder(st, p_base, p_top, 0.32 * scale_f, 0.08 * scale_f, trunk_col, 5)

	# 5 Stacked downward conical needle skirts (Deep anime mountain conifer viridian)
	_add_lowpoly_cone(st, ground_pos + Vector3(0.0, 1.2 * scale_f, 0.0), 2.10 * scale_f, 2.0 * scale_f, Color(0.03, 0.07, 0.04), 6)
	_add_lowpoly_cone(st, ground_pos + Vector3(0.0, 2.4 * scale_f, 0.0), 1.75 * scale_f, 1.9 * scale_f, Color(0.04, 0.09, 0.05), 6)
	_add_lowpoly_cone(st, ground_pos + Vector3(0.0, 3.5 * scale_f, 0.0), 1.40 * scale_f, 1.8 * scale_f, Color(0.05, 0.11, 0.06), 6)
	_add_lowpoly_cone(st, ground_pos + Vector3(0.0, 4.5 * scale_f, 0.0), 1.00 * scale_f, 1.8 * scale_f, Color(0.06, 0.13, 0.07), 6)
	_add_lowpoly_cone(st, ground_pos + Vector3(0.0, 5.4 * scale_f, 0.0), 0.65 * scale_f, 1.7 * scale_f, Color(0.08, 0.16, 0.09), 6)

func _add_3d_bamboo_cluster(st: SurfaceTool, ground_pos: Vector3, stalk_count: int, scale_f: float, seed_val: float) -> void:
	var stalk_col := Color(0.22, 0.34, 0.15)
	var leaf_col := Color(0.14, 0.30, 0.13)
	var node_col := Color(0.16, 0.26, 0.11)

	for s in range(stalk_count):
		var ang: float = TAU * float(s) / float(stalk_count) + seed_val * 2.0
		var dist: float = (0.35 + fposmod(seed_val * 4.3 + float(s) * 0.7, 0.95)) * scale_f
		var stalk_base := ground_pos + Vector3(cos(ang) * dist, -0.3, sin(ang) * dist)
		var hgt: float = (5.5 + fposmod(seed_val * 6.7 + float(s) * 1.3, 3.2)) * scale_f
		var num_segs: int = 5
		var seg_h: float = hgt / float(num_segs)

		var cur_bot := stalk_base
		for seg_i in range(num_segs):
			var cur_top := cur_bot + Vector3(0.0, seg_h, 0.0)
			_add_lowpoly_cylinder(st, cur_bot, cur_top, 0.08 * scale_f, 0.075 * scale_f, stalk_col, 4)
			_add_lowpoly_cylinder(st, cur_top - Vector3(0.0, 0.04 * scale_f, 0.0), cur_top + Vector3(0.0, 0.04 * scale_f, 0.0), 0.10 * scale_f, 0.10 * scale_f, node_col, 4)
			if seg_i >= num_segs - 2:
				var leaf_ang: float = ang + float(seg_i) * 1.8
				var leaf_dir := Vector3(cos(leaf_ang), 0.35, sin(leaf_ang)).normalized()
				var leaf_center := cur_top + leaf_dir * (0.65 * scale_f)
				_add_lowpoly_puff(st, leaf_center, Vector3(0.55, 0.25, 0.55) * scale_f, leaf_col)
			cur_bot = cur_top

func _add_3d_boulder(st: SurfaceTool, ground_pos: Vector3, scale_f: float, _seed_val: float) -> void:
	var rock_sun := Color(0.38, 0.36, 0.35)
	var rock_shade := Color(0.16, 0.17, 0.22)
	var rock_moss := Color(0.18, 0.32, 0.15) # Mossy top facet
	var b_base := ground_pos - Vector3(0.0, 0.25 * scale_f, 0.0)

	var apex := b_base + Vector3(0.10 * scale_f, 0.85 * scale_f, 0.05 * scale_f)
	var v0 := b_base + Vector3(-0.95 * scale_f, 0.15 * scale_f, -0.85 * scale_f)
	var v1 := b_base + Vector3(0.92 * scale_f, 0.20 * scale_f, -0.70 * scale_f)
	var v2 := b_base + Vector3(0.85 * scale_f, 0.12 * scale_f, 0.88 * scale_f)
	var v3 := b_base + Vector3(-0.80 * scale_f, 0.18 * scale_f, 0.75 * scale_f)

	var faces: Array = [
		{"v0": v0, "v1": v1, "v2": apex, "c": rock_moss},
		{"v0": v1, "v1": v2, "v2": apex, "c": rock_sun},
		{"v0": v2, "v1": v3, "v2": apex, "c": rock_shade},
		{"v0": v3, "v1": v0, "v2": apex, "c": rock_shade}
	]
	for f in faces:
		var va: Vector3 = f["v0"]
		var vb: Vector3 = f["v1"]
		var vc: Vector3 = f["v2"]
		var fn: Vector3 = (vb - va).cross(vc - va).normalized()
		var center_tri: Vector3 = (va + vb + vc) / 3.0
		if fn.dot((center_tri - b_base).normalized()) < 0.0:
			fn = -fn
		st.set_color(f["c"])
		st.set_normal(fn); st.add_vertex(va)
		st.set_normal(fn); st.add_vertex(vb)
		st.set_normal(fn); st.add_vertex(vc)

func _add_3d_bush(st: SurfaceTool, ground_pos: Vector3, scale_f: float, _seed_val: float) -> void:
	var bush_main := Color(0.06, 0.14, 0.07)
	var bush_lit := Color(0.08, 0.18, 0.09)
	var bush_shade := Color(0.03, 0.07, 0.04)
	var p0 := ground_pos + Vector3(0.0, 0.45 * scale_f, 0.0)
	var p1 := ground_pos + Vector3(0.38 * scale_f, 0.35 * scale_f, 0.22 * scale_f)
	var p2 := ground_pos + Vector3(-0.35 * scale_f, 0.38 * scale_f, -0.18 * scale_f)
	var p3 := ground_pos + Vector3(0.15 * scale_f, 0.60 * scale_f, -0.15 * scale_f)

	_add_lowpoly_puff(st, p0, Vector3(1.05, 0.65, 1.05) * scale_f, bush_shade)
	_add_lowpoly_puff(st, p1, Vector3(0.85, 0.55, 0.85) * scale_f, bush_main)
	_add_lowpoly_puff(st, p2, Vector3(0.80, 0.52, 0.80) * scale_f, bush_main)
	_add_lowpoly_puff(st, p3, Vector3(0.70, 0.48, 0.70) * scale_f, bush_lit)

func _build_anime_faceted_mountain(st: SurfaceTool, center: Vector3, width: float, height: float, depth_ext: float, seed_val: float) -> void:
	var col_sun := Color("#5A6068")     # Mid-tone granite highlight
	var col_crest := Color("#646C76")   # Granite crest
	var col_shade := Color("#222834")   # Deep slate cel shadow
	var col_cleft := Color("#121620")   # Dark crevice fracture
	var col_forest := Color("#1A3820")  # Deep shoulder forest turf

	var summit := center + Vector3(0.0, height, 0.0)
	var shoulder_left := center + Vector3(-width * 0.32, height * 0.65, -depth_ext * 0.12)
	var shoulder_right := center + Vector3(width * 0.28, height * 0.58, depth_ext * 0.10)

	var num_pts := 16
	var r_base_x := width * 0.90
	var r_base_z := depth_ext * 0.90
	var r_mid_x := width * 0.52
	var r_mid_z := depth_ext * 0.52

	var base_pts: Array[Vector3] = []
	var mid_pts: Array[Vector3] = []

	for p in range(num_pts):
		var ang: float = TAU * float(p) / float(num_pts)
		var noise_f: float = sin(ang * 3.0 + seed_val * 4.0) * 0.18 + cos(ang * 5.0) * 0.10
		var rx: float = r_base_x * (1.0 + noise_f)
		var rz: float = r_base_z * (1.0 - noise_f * 0.6)
		var y_b: float = center.y + sin(ang * 2.0) * 6.0
		base_pts.append(center + Vector3(cos(ang) * rx, y_b, sin(ang) * rz))

		var rmx: float = r_mid_x * (0.85 + noise_f * 0.4)
		var rmz: float = r_mid_z * (0.85 - noise_f * 0.4)
		var y_m: float = center.y + height * (0.42 + sin(ang * 3.0 + 1.2) * 0.08)
		mid_pts.append(center + Vector3(cos(ang) * rmx, y_m, sin(ang) * rmz))

	# 1. Base to Mid Skirt Facets
	for p in range(num_pts):
		var p_next: int = (p + 1) % num_pts
		var b0 := base_pts[p]
		var b1 := base_pts[p_next]
		var m0 := mid_pts[p]
		var m1 := mid_pts[p_next]

		var is_sunward := (cos(TAU * float(p) / float(num_pts)) > -0.2)
		var c_bot := col_forest if is_sunward else col_cleft
		var c_top := col_sun if is_sunward else col_shade

		st.set_color(c_bot)
		st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(m0)
		st.set_color(c_top)
		st.add_vertex(b1); st.add_vertex(m1); st.add_vertex(m0)

	# 2. Mid to Summit & Shoulders Facets
	for p in range(num_pts):
		var p_next: int = (p + 1) % num_pts
		var m0 := mid_pts[p]
		var m1 := mid_pts[p_next]

		var target_apex := summit
		if p >= 3 and p <= 6:
			target_apex = shoulder_right
		elif p >= 10 and p <= 13:
			target_apex = shoulder_left

		var is_sunward := (cos(TAU * float(p) / float(num_pts)) > -0.15)
		var c_face := col_crest if is_sunward else col_shade

		st.set_color(c_face)
		st.add_vertex(m0); st.add_vertex(m1); st.add_vertex(target_apex)

	# 3. Shoulder to Summit Connecting Facets
	st.set_color(col_crest)
	st.add_vertex(shoulder_right); st.add_vertex(summit); st.add_vertex(mid_pts[4])
	st.set_color(col_shade)
	st.add_vertex(shoulder_left); st.add_vertex(mid_pts[11]); st.add_vertex(summit)

func _build_chunk_roadside_architecture(_st: SurfaceTool, _start_z: float, _is_tunnel: bool) -> void:
	# Purged: Highway right flank is maintained as completely open elevated coastal vista
	pass

func _add_tree_trunk_anchor(_st: SurfaceTool, _ground_pos: Vector3, _radius: float, _height: float) -> void:
	pass

func _add_foliage_card(st: SurfaceTool, base_pos: Vector3, w: float, _h: float, _archetype: int, _ang_deg: float = 22.0) -> void:
	_add_3d_puffy_tree(st, base_pos, w * 0.25, 0.5)

func _add_lowpoly_pine_tree(st: SurfaceTool, base_pos: Vector3, scale_f: float) -> void:
	_add_3d_pine_tree(st, base_pos, scale_f, 0.5)

func _add_lowpoly_bush(st: SurfaceTool, base_pos: Vector3, scale_f: float) -> void:
	_add_3d_bush(st, base_pos, scale_f, 0.5)

func _add_lowpoly_rock(st: SurfaceTool, base_pos: Vector3, scale_f: float) -> void:
	_add_3d_boulder(st, base_pos, scale_f, 0.5)

# ==============================================================================
# 5. PROCEDURAL 20M HIGHWAY + STRATIFIED CANYON + ROADSIDE SPEED PROPS
# ==============================================================================
func _setup_road_system() -> void:
	for i in range(NUM_CHUNKS):
		var chunk = _create_road_chunk(next_chunk_z)
		add_child(chunk)
		road_chunks.append(chunk)
		next_chunk_z -= CHUNK_LENGTH

func _create_road_chunk(start_z: float) -> Node3D:
	chunk_spawn_count += 1
	var dist_from_stage: float = abs(start_z - stage_start_z)
	var is_fork_approach: bool = (dist_from_stage >= 2380.0 and dist_from_stage < 2500.0)
	var is_twin_tunnel: bool = (dist_from_stage >= 2500.0 and dist_from_stage < 2620.0)
	var is_tunnel: bool = is_twin_tunnel or (not is_fork_approach and (chunk_spawn_count % 14 == 3))

	var chunk_root := Node3D.new()
	chunk_root.position.z = start_z

	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hillside_st := SurfaceTool.new()
	hillside_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var foliage_st := SurfaceTool.new()
	foliage_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rock_st := SurfaceTool.new()
	rock_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var barrier_st := SurfaceTool.new()
	barrier_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var barrier_cap_st := SurfaceTool.new()
	barrier_cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Biome-specific surface tools for batched draw calls
	var sand_st := SurfaceTool.new()
	var water_st := SurfaceTool.new()
	var trunk_st := SurfaceTool.new()
	var snow_st := SurfaceTool.new()
	var win_st := SurfaceTool.new()
	var pole_st := SurfaceTool.new()
	var line_st := SurfaceTool.new()

	if current_biome_id == "enoshima_coast":
		sand_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		water_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	elif current_biome_id == "hakone_snow":
		snow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	elif current_biome_id == "neo_shinjuku":
		win_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		pole_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		line_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step_z: float = CHUNK_LENGTH / float(CHUNK_SEGMENTS)

	# Pick candidate biomes for fork if approaching
	if is_fork_approach:
		var candidates: Array[String] = []
		for b in BIOMES.keys():
			if b != current_biome_id:
				candidates.append(b)
		candidates.shuffle()
		if candidates.size() >= 2:
			fork_left_biome = candidates[0]
			fork_right_biome = candidates[1]

	for i in range(CHUNK_SEGMENTS + 1):
		var local_z: float = -float(i) * step_z
		var global_z: float = start_z + local_z

		var center_x: float = _sample_road_x(global_z)
		var bank_angle: float = _sample_road_bank(global_z)
		var right_vec: Vector3 = _sample_road_right(global_z)

		var half_w: float = ROAD_WIDTH * 0.5
		if is_fork_approach:
			var widen_t: float = float(i) / float(CHUNK_SEGMENTS)
			half_w = lerp(ROAD_WIDTH * 0.5, 14.5, widen_t)
		elif is_twin_tunnel:
			half_w = 14.5

		var center_pt := Vector3(center_x, 0.0, local_z)
		var left_pt := center_pt - (right_vec * half_w) + Vector3(0.0, sin(bank_angle) * half_w, 0.0)
		var right_pt := center_pt + (right_vec * half_w) - Vector3(0.0, sin(bank_angle) * half_w, 0.0)

		var normal := Vector3(0.0, 1.0, 0.0)
		var v_uv: float = float(i)

		# 1. Roadway Surface
		road_st.set_normal(normal)
		road_st.set_uv(Vector2(0.0, v_uv))
		road_st.add_vertex(left_pt)

		road_st.set_normal(normal)
		road_st.set_uv(Vector2(1.0, v_uv))
		road_st.add_vertex(right_pt)

		# 2. Roadside Formations per Biome
		if current_biome_id == "shuto_dusk" or is_fork_approach or is_twin_tunnel:
			var n_macro: float = sin(global_z * 0.012) * 5.5 + cos(global_z * 0.027) * 3.5
			var n_meso: float = sin(global_z * 0.048) * 2.2 + cos(global_z * 0.088) * 1.4
			var n_micro: float = sin(global_z * 0.13) * 0.8 + cos(global_z * 0.26) * 0.5

			var h1: float = 1.2 + n_micro * 0.2
			var h2: float = 1.8 + n_micro * 0.3
			var h3: float = 6.2 + n_micro * 0.4
			var h4: float = 7.0 + n_meso * 0.5
			var h5: float = 15.5 + n_meso * 0.8
			var h6: float = 16.8 + n_macro * 0.7
			var h7: float = 36.0 + n_macro * 1.8
			var h8: float = 48.0 + n_macro * 2.2

			var pt0 := left_pt
			var pt1 := left_pt - (right_vec * 0.35) + Vector3(0.0, h1, 0.0)
			var pt2 := left_pt - (right_vec * 7.5) + Vector3(0.0, h2, 0.0)
			var pt3 := left_pt - (right_vec * 7.9) + Vector3(0.0, h3, 0.0)
			var pt4 := left_pt - (right_vec * 19.5) + Vector3(0.0, h4, 0.0)
			var pt5 := left_pt - (right_vec * 20.2) + Vector3(0.0, h5, 0.0)
			var pt6 := left_pt - (right_vec * 36.0) + Vector3(0.0, h6, 0.0)
			var pt7 := left_pt - (right_vec * 72.0) + Vector3(0.0, h7, 0.0)
			var pt8 := left_pt - (right_vec * 135.0) + Vector3(0.0, h8, 0.0)

			var hs_u: float = float(i) / float(CHUNK_SEGMENTS)
			var bands: Array = [
				{"p0": pt0, "p1": pt1, "v0": 0.0,  "v1": 0.08},
				{"p0": pt1, "p1": pt2, "v0": 0.08, "v1": 0.22},
				{"p0": pt2, "p1": pt3, "v0": 0.22, "v1": 0.30},
				{"p0": pt3, "p1": pt4, "v0": 0.30, "v1": 0.44},
				{"p0": pt4, "p1": pt5, "v0": 0.44, "v1": 0.52},
				{"p0": pt5, "p1": pt6, "v0": 0.52, "v1": 0.62},
				{"p0": pt6, "p1": pt7, "v0": 0.62, "v1": 0.82},
				{"p0": pt7, "p1": pt8, "v0": 0.82, "v1": 1.0}
			]
			for b in bands:
				hillside_st.set_uv(Vector2(hs_u, b["v0"]))
				hillside_st.add_vertex(b["p0"])
				hillside_st.set_uv(Vector2(hs_u, b["v1"]))
				hillside_st.add_vertex(b["p1"])

		elif current_biome_id == "enoshima_coast":
			# LEFT: Coastal cliff rising up with rocky faces
			var cliff_top := left_pt - (right_vec * 34.0) + Vector3(0.0, 28.0, 0.0)
			hillside_st.add_vertex(left_pt)
			hillside_st.add_vertex(cliff_top)

			# RIGHT: Sandy beach shoulder sloping down into ocean water plane
			var sand_end := right_pt + (right_vec * 16.0) - Vector3(0.0, 1.4, 0.0)
			var ocean_end := right_pt + (right_vec * 240.0) - Vector3(0.0, 3.2, 0.0)
			sand_st.add_vertex(right_pt)
			sand_st.add_vertex(sand_end)
			water_st.add_vertex(sand_end)
			water_st.add_vertex(ocean_end)

		elif current_biome_id == "hakone_snow":
			var snow_l := left_pt - (right_vec * 2.8) + Vector3(0.0, 0.8, 0.0)
			var cliff_l := left_pt - (right_vec * 45.0) + Vector3(0.0, 38.0, 0.0)
			snow_st.add_vertex(left_pt); snow_st.add_vertex(snow_l)
			hillside_st.add_vertex(snow_l); hillside_st.add_vertex(cliff_l)

			var snow_r := right_pt + (right_vec * 2.8) + Vector3(0.0, 0.8, 0.0)
			var cliff_r := right_pt + (right_vec * 45.0) + Vector3(0.0, 38.0, 0.0)
			snow_st.add_vertex(right_pt); snow_st.add_vertex(snow_r)
			hillside_st.add_vertex(snow_r); hillside_st.add_vertex(cliff_r)

		elif current_biome_id == "neo_shinjuku":
			var sw_l := left_pt - (right_vec * 3.8) + Vector3(0.0, 0.22, 0.0)
			var sw_r := right_pt + (right_vec * 3.8) + Vector3(0.0, 0.22, 0.0)
			hillside_st.add_vertex(left_pt); hillside_st.add_vertex(sw_l)
			hillside_st.add_vertex(right_pt); hillside_st.add_vertex(sw_r)

		# 3. Guardrails (Right side)
		var bar_inner_top := right_pt + Vector3(0.0, 1.2, 0.0)
		var bar_outer_top := right_pt + (right_vec * 0.55) + Vector3(0.0, 1.2, 0.0)
		var bar_outer_bottom := right_pt + (right_vec * 0.55) - Vector3(0.0, 8.0, 0.0)

		barrier_st.set_normal(-right_vec); barrier_st.set_uv(Vector2(0.0, v_uv)); barrier_st.add_vertex(right_pt)
		barrier_st.set_normal(-right_vec); barrier_st.set_uv(Vector2(1.0, v_uv)); barrier_st.add_vertex(bar_inner_top)
		barrier_cap_st.set_normal(Vector3.UP); barrier_cap_st.set_uv(Vector2(0.0, v_uv)); barrier_cap_st.add_vertex(bar_inner_top)
		barrier_cap_st.set_normal(Vector3.UP); barrier_cap_st.set_uv(Vector2(1.0, v_uv)); barrier_cap_st.add_vertex(bar_outer_top)
		barrier_st.set_normal(right_vec); barrier_st.set_uv(Vector2(0.0, v_uv)); barrier_st.add_vertex(bar_outer_top)
		barrier_st.set_normal(right_vec); barrier_st.set_uv(Vector2(1.0, v_uv)); barrier_st.add_vertex(bar_outer_bottom)

	for i in range(CHUNK_SEGMENTS):
		var i2: int = i * 2
		road_st.add_index(i2)
		road_st.add_index(i2 + 1)
		road_st.add_index(i2 + 2)
		road_st.add_index(i2 + 1)
		road_st.add_index(i2 + 3)
		road_st.add_index(i2 + 2)

		if current_biome_id == "shuto_dusk" or is_fork_approach or is_twin_tunnel:
			for b in range(8):
				var idx_curr_bot: int = (i * 8 + b) * 2
				var idx_curr_top: int = idx_curr_bot + 1
				var idx_next_bot: int = ((i + 1) * 8 + b) * 2
				var idx_next_top: int = idx_next_bot + 1
				hillside_st.add_index(idx_curr_bot)
				hillside_st.add_index(idx_next_bot)
				hillside_st.add_index(idx_curr_top)
				hillside_st.add_index(idx_curr_top)
				hillside_st.add_index(idx_next_bot)
				hillside_st.add_index(idx_next_top)
		elif current_biome_id == "enoshima_coast":
			sand_st.add_index(i2); sand_st.add_index(i2 + 2); sand_st.add_index(i2 + 1)
			sand_st.add_index(i2 + 1); sand_st.add_index(i2 + 2); sand_st.add_index(i2 + 3)
			water_st.add_index(i2); water_st.add_index(i2 + 2); water_st.add_index(i2 + 1)
			water_st.add_index(i2 + 1); water_st.add_index(i2 + 2); water_st.add_index(i2 + 3)
			hillside_st.add_index(i2); hillside_st.add_index(i2 + 1); hillside_st.add_index(i2 + 2)
			hillside_st.add_index(i2 + 1); hillside_st.add_index(i2 + 3); hillside_st.add_index(i2 + 2)
		elif current_biome_id == "hakone_snow":
			var si: int = i * 4
			snow_st.add_index(si); snow_st.add_index(si + 1); snow_st.add_index(si + 4)
			snow_st.add_index(si + 1); snow_st.add_index(si + 5); snow_st.add_index(si + 4)
			snow_st.add_index(si + 2); snow_st.add_index(si + 3); snow_st.add_index(si + 6)
			snow_st.add_index(si + 3); snow_st.add_index(si + 7); snow_st.add_index(si + 6)
			hillside_st.add_index(si); hillside_st.add_index(si + 1); hillside_st.add_index(si + 4)
			hillside_st.add_index(si + 1); hillside_st.add_index(si + 5); hillside_st.add_index(si + 4)
			hillside_st.add_index(si + 2); hillside_st.add_index(si + 3); hillside_st.add_index(si + 6)
			hillside_st.add_index(si + 3); hillside_st.add_index(si + 7); hillside_st.add_index(si + 6)
		elif current_biome_id == "neo_shinjuku":
			var ni: int = i * 4
			hillside_st.add_index(ni); hillside_st.add_index(ni + 1); hillside_st.add_index(ni + 4)
			hillside_st.add_index(ni + 1); hillside_st.add_index(ni + 5); hillside_st.add_index(ni + 4)
			hillside_st.add_index(ni + 2); hillside_st.add_index(ni + 3); hillside_st.add_index(ni + 6)
			hillside_st.add_index(ni + 3); hillside_st.add_index(ni + 7); hillside_st.add_index(ni + 6)

		# Prop generation per segment
		var seg_local_z: float = -float(i) * step_z
		var seg_gz: float = start_z + seg_local_z
		var seg_seed: float = sin(seg_gz * 73.15 + float(i) * 31.45) * 43758.5453
		var seg_rnd: float = fposmod(seg_seed, 1.0)
		var seg_cx: float = _sample_road_x(seg_gz)
		var seg_ba: float = _sample_road_bank(seg_gz)
		var seg_rv: Vector3 = _sample_road_right(seg_gz)
		var seg_hw: float = ROAD_WIDTH * 0.5
		var seg_left := Vector3(seg_cx, 0.0, seg_local_z) - (seg_rv * seg_hw) + Vector3(0.0, sin(seg_ba) * seg_hw, 0.0)
		var seg_right := Vector3(seg_cx, 0.0, seg_local_z) + (seg_rv * seg_hw) - Vector3(0.0, sin(seg_ba) * seg_hw, 0.0)

		if current_biome_id == "shuto_dusk" and not is_fork_approach and not is_twin_tunnel:
			if i % 2 == 0:
				var b_lat: float = 2.0 + seg_rnd * 3.5
				var b_ground_y: float = _sample_hillside_height(seg_gz, b_lat)
				var b_pos := seg_left - (seg_rv * b_lat) + Vector3(0.0, b_ground_y, 0.0)
				_add_3d_bush(foliage_st, b_pos, 1.15 + seg_rnd * 0.45, seg_rnd)
				if seg_rnd < 0.70:
					var tr_lat: float = 3.6 + fposmod(seg_rnd * 6.7, 2.8)
					var tr_ground_y: float = _sample_hillside_height(seg_gz, tr_lat)
					var tr_pos := seg_left - (seg_rv * tr_lat) + Vector3(0.0, tr_ground_y, 0.0)
					_add_3d_puffy_tree(foliage_st, tr_pos, 0.95 + fposmod(seg_rnd * 4.3, 0.45), seg_rnd)
				else:
					var pn_lat: float = 4.2 + fposmod(seg_rnd * 5.5, 2.4)
					var pn_ground_y: float = _sample_hillside_height(seg_gz, pn_lat)
					var pn_pos := seg_left - (seg_rv * pn_lat) + Vector3(0.0, pn_ground_y, 0.0)
					_add_3d_pine_tree(foliage_st, pn_pos, 0.90 + fposmod(seg_rnd * 3.8, 0.35), seg_rnd)
			if i % 3 == 0:
				var tr2_lat: float = 10.2 + fposmod(seg_rnd * 4.1, 7.8)
				var tr2_ground_y: float = _sample_hillside_height(seg_gz, tr2_lat)
				var tr2_pos := seg_left - (seg_rv * tr2_lat) + Vector3(0.0, tr2_ground_y, 0.0)
				_add_3d_puffy_tree(foliage_st, tr2_pos, 1.25, seg_rnd)

		elif current_biome_id == "enoshima_coast" and not is_fork_approach and not is_twin_tunnel:
			# Coastal palm trees along left cliff verge & right sandy beach
			if i % 3 == 0:
				var cliff_palm := seg_left - (seg_rv * (3.5 + seg_rnd * 4.0)) + Vector3(0.0, 1.2, 0.0)
				_add_3d_palm_tree(trunk_st, foliage_st, cliff_palm, 0.95 + seg_rnd * 0.35, seg_rnd)
			elif i % 5 == 2:
				var beach_palm := seg_right + (seg_rv * (5.0 + seg_rnd * 3.5)) - Vector3(0.0, 0.8, 0.0)
				_add_3d_palm_tree(trunk_st, foliage_st, beach_palm, 0.85 + seg_rnd * 0.25, seg_rnd)

		elif current_biome_id == "hakone_snow" and not is_fork_approach and not is_twin_tunnel:
			# Snow-capped alpine pines along left and right
			if i % 2 == 0:
				var sp_l := seg_left - (seg_rv * (4.2 + seg_rnd * 6.0)) + Vector3(0.0, 1.2, 0.0)
				_add_3d_snow_pine(foliage_st, snow_st, sp_l, 0.95 + seg_rnd * 0.45, seg_rnd)
			if i % 3 == 1:
				var sp_r := seg_right + (seg_rv * (4.5 + seg_rnd * 6.0)) + Vector3(0.0, 1.2, 0.0)
				_add_3d_snow_pine(foliage_st, snow_st, sp_r, 0.95 + seg_rnd * 0.45, seg_rnd)

		elif current_biome_id == "neo_shinjuku" and not is_fork_approach and not is_twin_tunnel:
			# Stacked Japanese buildings on both sides
			if i % 5 == 0:
				var bld_pos_l := seg_left - (seg_rv * 16.0)
				var bld_size_l := Vector3(12.0, 18.0 + seg_rnd * 16.0, 14.0)
				_add_shinjuku_building(hillside_st, win_st, bld_pos_l - bld_size_l * 0.5, bld_pos_l + bld_size_l * 0.5, seg_rnd)

				var bld_pos_r := seg_right + (seg_rv * 16.0)
				var bld_size_r := Vector3(12.0, 18.0 + fposmod(seg_rnd * 3.7, 1.0) * 16.0, 14.0)
				_add_shinjuku_building(hillside_st, win_st, bld_pos_r - bld_size_r * 0.5, bld_pos_r + bld_size_r * 0.5, seg_rnd)

				# Vending machines on sidewalks
				_add_3d_vending_machine(foliage_st, win_st, seg_left - (seg_rv * 2.2), 0.0, seg_rnd)
				_add_3d_vending_machine(foliage_st, win_st, seg_right + (seg_rv * 2.2), PI, seg_rnd)

				# Vertical neon blade signs projecting from buildings (Ref Image 2)
				var neon_texts: Array[String] = ["東岸大寿司", "#0E5FF", "新宿 24H", "湾岸 LINE", "RAMEN 麺"]
				var text_l: String = neon_texts[(i + int(seg_rnd * 10.0)) % neon_texts.size()]
				var text_r: String = neon_texts[(i + 2 + int(seg_rnd * 10.0)) % neon_texts.size()]
				var neon_pos_l := seg_left - (seg_rv * 9.8) + Vector3(0.0, 6.8, 0.0)
				var neon_pos_r := seg_right + (seg_rv * 9.8) + Vector3(0.0, 6.8, 0.0)
				var seg_tan: Vector3 = _sample_road_tangent(seg_gz)
				_add_3d_neon_sign(chunk_root, neon_pos_l, seg_tan, text_l, i)
				_add_3d_neon_sign(chunk_root, neon_pos_r, seg_tan, text_r, i + 1)

				# Utility poles with power lines
				var next_pole_pos := seg_left - (seg_rv * 2.8) - Vector3(0.0, 0.0, step_z * 5.0)
				_add_3d_power_pole(pole_st, line_st, seg_left - (seg_rv * 2.8), next_pole_pos)

		var bi: int = i * 4
		barrier_st.add_index(bi); barrier_st.add_index(bi + 1); barrier_st.add_index(bi + 4)
		barrier_st.add_index(bi + 1); barrier_st.add_index(bi + 5); barrier_st.add_index(bi + 4)
		barrier_cap_st.add_index(i2); barrier_cap_st.add_index(i2 + 1); barrier_cap_st.add_index(i2 + 2)
		barrier_cap_st.add_index(i2 + 1); barrier_cap_st.add_index(i2 + 3); barrier_cap_st.add_index(i2 + 2)
		barrier_st.add_index(bi + 2); barrier_st.add_index(bi + 3); barrier_st.add_index(bi + 6)
		barrier_st.add_index(bi + 3); barrier_st.add_index(bi + 7); barrier_st.add_index(bi + 6)

	var road_inst := MeshInstance3D.new()
	road_inst.mesh = road_st.commit()
	road_inst.material_override = road_shader_mat
	chunk_root.add_child(road_inst)

	hillside_st.generate_normals()
	var hillside_mesh := hillside_st.commit()
	if is_instance_valid(hillside_mesh) and hillside_mesh.get_surface_count() > 0:
		var hillside_inst := MeshInstance3D.new()
		hillside_inst.name = "HillsideLayer2"
		hillside_inst.mesh = hillside_mesh
		if current_biome_id == "enoshima_coast":
			hillside_inst.material_override = coastal_cliff_mat
		elif current_biome_id == "hakone_snow":
			hillside_inst.material_override = snow_rock_mat
		elif current_biome_id == "neo_shinjuku":
			hillside_inst.material_override = shinjuku_building_mat
		else:
			hillside_inst.material_override = cliff_mat if is_instance_valid(cliff_mat) else hillside_layer2_mat
		hillside_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_root.add_child(hillside_inst)

	# Biome meshes
	if current_biome_id == "enoshima_coast":
		var sand_mesh := sand_st.commit()
		if is_instance_valid(sand_mesh) and sand_mesh.get_surface_count() > 0:
			var s_inst := MeshInstance3D.new()
			s_inst.mesh = sand_mesh
			s_inst.material_override = coastal_sand_mat
			s_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(s_inst)
		var w_mesh := water_st.commit()
		if is_instance_valid(w_mesh) and w_mesh.get_surface_count() > 0:
			var w_inst := MeshInstance3D.new()
			w_inst.mesh = w_mesh
			w_inst.material_override = ocean_water_mat
			w_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(w_inst)
		var tr_mesh := trunk_st.commit()
		if is_instance_valid(tr_mesh) and tr_mesh.get_surface_count() > 0:
			var tr_inst := MeshInstance3D.new()
			tr_inst.mesh = tr_mesh
			tr_inst.material_override = palm_trunk_mat
			tr_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(tr_inst)
	elif current_biome_id == "hakone_snow":
		var snow_mesh := snow_st.commit()
		if is_instance_valid(snow_mesh) and snow_mesh.get_surface_count() > 0:
			var sn_inst := MeshInstance3D.new()
			sn_inst.mesh = snow_mesh
			sn_inst.material_override = snowbank_mat
			sn_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(sn_inst)
	elif current_biome_id == "neo_shinjuku":
		var win_mesh := win_st.commit()
		if is_instance_valid(win_mesh) and win_mesh.get_surface_count() > 0:
			var wn_inst := MeshInstance3D.new()
			wn_inst.mesh = win_mesh
			wn_inst.material_override = shinjuku_window_mat
			wn_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(wn_inst)
		var p_mesh := pole_st.commit()
		if is_instance_valid(p_mesh) and p_mesh.get_surface_count() > 0:
			var p_inst := MeshInstance3D.new()
			p_inst.mesh = p_mesh
			p_inst.material_override = power_pole_mat
			p_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(p_inst)
		var l_mesh := line_st.commit()
		if is_instance_valid(l_mesh) and l_mesh.get_surface_count() > 0:
			var l_inst := MeshInstance3D.new()
			l_inst.mesh = l_mesh
			l_inst.material_override = power_line_mat
			l_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk_root.add_child(l_inst)

	var fol_mesh := foliage_st.commit()
	if is_instance_valid(fol_mesh) and fol_mesh.get_surface_count() > 0:
		var fol_inst := MeshInstance3D.new()
		fol_inst.name = "HillsideLayer1Foliage"
		fol_inst.mesh = fol_mesh
		if current_biome_id == "enoshima_coast":
			fol_inst.material_override = palm_frond_mat
		elif current_biome_id == "hakone_snow":
			fol_inst.material_override = snow_foliage_mat
		elif current_biome_id == "neo_shinjuku":
			fol_inst.material_override = vending_body_mat
		else:
			fol_inst.material_override = hillside_foliage_mat
		fol_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_root.add_child(fol_inst)

	var rock_mesh := rock_st.commit()
	if rock_mesh.get_surface_count() > 0:
		var rock_inst := MeshInstance3D.new()
		rock_inst.name = "HillsideLayer1Rocks"
		rock_inst.mesh = rock_mesh
		rock_inst.material_override = hillside_rock_mat
		rock_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk_root.add_child(rock_inst)

	var barrier_inst := MeshInstance3D.new()
	barrier_inst.mesh = barrier_st.commit()
	barrier_inst.material_override = barrier_material
	barrier_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_root.add_child(barrier_inst)

	var barrier_cap_inst := MeshInstance3D.new()
	barrier_cap_inst.mesh = barrier_cap_st.commit()
	barrier_cap_inst.material_override = barrier_cap_material
	barrier_cap_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_root.add_child(barrier_cap_inst)

	for joint_step in [0.0, 40.0, 80.0]:
		var j_rel_z: float = -joint_step
		var j_gz: float = start_z + j_rel_z
		var j_cx: float = _sample_road_x(j_gz)
		var j_tan: Vector3 = _sample_road_tangent(j_gz)
		var j_bank: float = _sample_road_bank(j_gz)

		var joint_node := Node3D.new()
		joint_node.position = Vector3(j_cx, 0.025, j_rel_z)
		joint_node.transform.basis = Basis.looking_at(j_tan, Vector3.UP)
		joint_node.rotate_object_local(Vector3(0, 0, 1), j_bank)

		var r_mesh := BoxMesh.new()
		r_mesh.size = Vector3(21.4, 0.02, 0.38)
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = r_mesh
		r_inst.material_override = expansion_rubber_mat
		joint_node.add_child(r_inst)

		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(21.4, 0.025, 0.08)
		for t_side in [-0.20, 0.20]:
			var t_inst := MeshInstance3D.new()
			t_inst.mesh = t_mesh
			t_inst.position = Vector3(0.0, 0.005, t_side)
			t_inst.material_override = expansion_steel_mat
			joint_node.add_child(t_inst)

		chunk_root.add_child(joint_node)

	_spawn_chunk_speed_props(chunk_root, start_z, is_tunnel)

	if is_twin_tunnel:
		_build_twin_tunnels(chunk_root, start_z)
		active_tunnel_intervals.append(Vector2(start_z - 10.0, start_z - 110.0))
		active_fork_mid_z = start_z - 60.0
		active_fork_exit_z = start_z - 110.0
		fork_active = true
		fork_transition_done = false
	elif is_fork_approach:
		_build_fork_gantry(chunk_root, start_z, BIOMES[fork_left_biome]["name"], BIOMES[fork_right_biome]["name"])
	elif is_tunnel:
		_build_tunnel_module(chunk_root, start_z)
		active_tunnel_intervals.append(Vector2(start_z - 30.0, start_z - 90.0))
	else:
		if chunk_spawn_count % 8 == 5:
			_build_toll_plaza(chunk_root, start_z)
		elif chunk_spawn_count % 5 == 2:
			_build_construction_squeeze(chunk_root, start_z)

	if is_raining:
		_spawn_chunk_puddles(chunk_root, start_z)

	purge_outlines(chunk_root)
	return chunk_root

func _spawn_chunk_speed_props(chunk: Node3D, start_z: float, is_tunnel: bool = false) -> void:
	for prop_step in [20.0, 50.0, 80.0, 110.0]:
		if is_tunnel and prop_step >= 30.0 and prop_step <= 90.0:
			continue
		var prop_z: float = -prop_step
		var global_z: float = start_z + prop_z
		var center_x: float = _sample_road_x(global_z)
		var right_vec: Vector3 = _sample_road_right(global_z)
		var tan_vec: Vector3 = _sample_road_tangent(global_z)

		var pole := Node3D.new()
		pole.position = Vector3(center_x, 0.0, prop_z) + (right_vec * 10.3)
		pole.transform.basis = Basis.looking_at(tan_vec, Vector3.UP)

		# 1. Base Foundation & Mounting Flange Pad
		var base_pad := MeshInstance3D.new()
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(0.52, 0.16, 0.52)
		base_pad.mesh = pad_mesh
		base_pad.position = Vector3(0.0, 0.08, 0.0)
		base_pad.material_override = barrier_material
		pole.add_child(base_pad)

		# 2. Tapered Octagonal Steel Mast (CylinderMesh)
		var mast := MeshInstance3D.new()
		var mast_cyl := CylinderMesh.new()
		mast_cyl.top_radius = 0.09
		mast_cyl.bottom_radius = 0.15
		mast_cyl.height = 5.8
		mast_cyl.radial_segments = 8
		mast.mesh = mast_cyl
		mast.position = Vector3(0.0, 2.98, 0.0)
		mast.material_override = barrier_material
		pole.add_child(mast)

		# 3. Arched Gooseneck Cantilever Arm (Smooth curved highway reach)
		var arm1 := MeshInstance3D.new()
		var a1_mesh := CylinderMesh.new()
		a1_mesh.top_radius = 0.075
		a1_mesh.bottom_radius = 0.085
		a1_mesh.height = 1.35
		a1_mesh.radial_segments = 6
		arm1.mesh = a1_mesh
		arm1.position = Vector3(-0.45, 6.05, 0.0)
		arm1.rotation_degrees = Vector3(0.0, 0.0, -42.0)
		arm1.material_override = barrier_material
		pole.add_child(arm1)

		var arm2 := MeshInstance3D.new()
		var a2_mesh := CylinderMesh.new()
		a2_mesh.top_radius = 0.065
		a2_mesh.bottom_radius = 0.075
		a2_mesh.height = 1.65
		a2_mesh.radial_segments = 6
		arm2.mesh = a2_mesh
		arm2.position = Vector3(-1.45, 6.48, 0.0)
		arm2.rotation_degrees = Vector3(0.0, 0.0, -82.0)
		arm2.material_override = barrier_material
		pole.add_child(arm2)

		# 4. Aerodynamic Cobra-Head Luminaire Housing
		var lamp_body := MeshInstance3D.new()
		var lb_mesh := BoxMesh.new()
		lb_mesh.size = Vector3(0.82, 0.16, 0.38)
		lamp_body.mesh = lb_mesh
		lamp_body.position = Vector3(-2.35, 6.42, 0.0)
		lamp_body.rotation_degrees = Vector3(0.0, 0.0, 8.0) # Angled slightly downward toward road
		lamp_body.material_override = barrier_material
		pole.add_child(lamp_body)

		# 5. Downward Recessed Sodium Lens
		var lamp := MeshInstance3D.new()
		var l_box := BoxMesh.new()
		l_box.size = Vector3(0.62, 0.06, 0.30)
		lamp.mesh = l_box
		lamp.position = Vector3(-2.38, 6.33, 0.0)
		lamp.rotation_degrees = Vector3(0.0, 0.0, 8.0)
		lamp.material_override = sodium_lamp_mat
		pole.add_child(lamp)

		# Wide elliptical sodium ground light pool across road lane
		var pool := MeshInstance3D.new()
		var p_mesh := PlaneMesh.new()
		p_mesh.size = Vector2(10.5, 8.5)
		p_mesh.orientation = PlaneMesh.FACE_Y
		pool.mesh = p_mesh
		pool.material_override = sodium_pool_mat
		pool.position = Vector3(-3.8, 0.03, 0.0)
		pole.add_child(pool)

		chunk.add_child(pole)

		# Orange reflector post along the outer concrete barrier
		var reflector := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.08, 0.25, 0.08)
		reflector.mesh = r_box
		var r_mat := StandardMaterial3D.new()
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.albedo_color = Color("#FF9500")
		r_mat.emission_enabled = true
		r_mat.emission = Color("#FF9500")
		r_mat.emission_energy_multiplier = 2.5
		reflector.material_override = r_mat
		reflector.position = Vector3(center_x, 1.35, prop_z) + (right_vec * 9.8)
		chunk.add_child(reflector)

	# Japanese Expressway Overhead Gantry Signs on alternating chunks
	if not is_tunnel and int(abs(start_z) / 120.0) % 2 == 1:
		var gantry_z: float = -60.0
		var gz: float = start_z + gantry_z
		var g_center_x: float = _sample_road_x(gz)
		var _g_right: Vector3 = _sample_road_right(gz)
		var g_tan: Vector3 = _sample_road_tangent(gz)

		var gantry := Node3D.new()
		gantry.position = Vector3(g_center_x, 0.0, gantry_z)
		gantry.transform.basis = Basis.looking_at(g_tan, Vector3.UP)

		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.35, 7.5, 0.35)
		for side in [-1.0, 1.0]:
			var col := MeshInstance3D.new()
			col.mesh = p_mesh
			col.position = Vector3(side * 10.2, 3.75, 0.0)
			col.material_override = barrier_material
			gantry.add_child(col)

		var beam := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(20.8, 0.45, 0.45)
		beam.mesh = b_mesh
		beam.position = Vector3(0.0, 7.3, 0.0)
		beam.material_override = barrier_material
		gantry.add_child(beam)

		var sign_mat := _get_expressway_sign_material()

		var sign_board := MeshInstance3D.new()
		var sb_mesh := BoxMesh.new()
		sb_mesh.size = Vector3(8.2, 2.4, 0.15)
		sign_board.mesh = sb_mesh
		sign_board.material_override = sign_mat
		sign_board.position = Vector3(1.2, 6.2, 0.0)
		gantry.add_child(sign_board)

		var sign_frame := MeshInstance3D.new()
		var sf_mesh := BoxMesh.new()
		sf_mesh.size = Vector3(8.35, 2.55, 0.08)
		sign_frame.mesh = sf_mesh
		var sf_mat := StandardMaterial3D.new()
		sf_mat.albedo_color = Color("#98A0B2")
		sign_frame.material_override = sf_mat
		sign_frame.position = Vector3(1.2, 6.2, -0.04)
		gantry.add_child(sign_frame)

		# Downward warm-yellow SpotLight3D pooling light over asphalt under each gantry
		var gantry_spot := SpotLight3D.new()
		gantry_spot.light_color = Color("#FFF4D0")
		gantry_spot.light_energy = 3.6
		gantry_spot.spot_range = 12.0
		gantry_spot.spot_angle = 45.0
		gantry_spot.spot_attenuation = 1.0
		gantry_spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # Downward facing
		gantry_spot.position = Vector3(0.0, 7.2, 0.0)
		gantry_spot.shadow_enabled = false
		gantry.add_child(gantry_spot)

		# Warm yellow asphalt light pool beneath gantry
		var gantry_pool := MeshInstance3D.new()
		var gp_mesh := PlaneMesh.new()
		gp_mesh.size = Vector2(14.0, 7.5)
		gp_mesh.orientation = PlaneMesh.FACE_Y
		gantry_pool.mesh = gp_mesh
		var gp_mat := StandardMaterial3D.new()
		gp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gp_mat.albedo_color = Color(1.0, 0.95, 0.80, 0.18)
		gp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		gantry_pool.material_override = gp_mat
		gantry_pool.position = Vector3(0.0, 0.03, 0.0)
		gantry.add_child(gantry_pool)

		chunk.add_child(gantry)

# ==============================================================================
# 5. PROCEDURAL COVERED TUNNEL & OVERPASS MODULE (60M ENCLOSED INDUSTRIAL TUBE)
# ==============================================================================
func _build_tunnel_module(chunk: Node3D, start_z: float) -> void:
	var tunnel_steps: Array[float] = [30.0, 36.0, 42.0, 48.0, 54.0, 60.0, 66.0, 72.0, 78.0, 84.0, 90.0]

	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.9, 7.5, 1.2)

	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(22.4, 0.8, 1.2)

	var gusset_mesh := BoxMesh.new()
	gusset_mesh.size = Vector3(1.4, 1.4, 1.1)

	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(21.4, 0.45, 6.2)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.5, 7.4, 6.2)

	var fluor_mesh := BoxMesh.new()
	fluor_mesh.size = Vector3(0.65, 0.18, 4.2)

	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(12.0, 4.5)
	pool_mesh.orientation = PlaneMesh.FACE_Y

	for idx in range(tunnel_steps.size()):
		var step: float = tunnel_steps[idx]
		var local_z: float = -step
		var global_z: float = start_z + local_z
		var center_x: float = _sample_road_x(global_z)
		var tan_vec: Vector3 = _sample_road_tangent(global_z)
		var basis_look := Basis.looking_at(tan_vec, Vector3.UP)

		var rib_node := Node3D.new()
		rib_node.position = Vector3(center_x, 0.0, local_z)
		rib_node.transform.basis = basis_look

		# 1. Left & Right Heavy Support Pillars
		for side in [-1.0, 1.0]:
			var pillar := MeshInstance3D.new()
			pillar.mesh = pillar_mesh
			pillar.material_override = tunnel_concrete_mat
			pillar.position = Vector3(side * 10.6, 3.75, 0.0)
			pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rib_node.add_child(pillar)

			# Arched corner gusset
			var gusset := MeshInstance3D.new()
			gusset.mesh = gusset_mesh
			gusset.material_override = tunnel_rib_mat
			gusset.position = Vector3(side * 9.6, 6.4, 0.0)
			gusset.rotation_degrees = Vector3(0.0, 0.0, 45.0 * side)
			gusset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rib_node.add_child(gusset)

		# 2. Industrial Arched Overhead Rib
		var rib := MeshInstance3D.new()
		rib.mesh = beam_mesh
		rib.material_override = tunnel_rib_mat
		rib.position = Vector3(0.0, 7.2, 0.0)
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rib_node.add_child(rib)

		# 3. Enclosed Concrete Roof & Outer Walls between ribs
		if idx < tunnel_steps.size() - 1:
			var slab := MeshInstance3D.new()
			slab.mesh = slab_mesh
			slab.material_override = tunnel_concrete_mat
			slab.position = Vector3(0.0, 7.5, -3.0)
			slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rib_node.add_child(slab)

			for side in [-1.0, 1.0]:
				var wall := MeshInstance3D.new()
				wall.mesh = wall_mesh
				wall.material_override = tunnel_concrete_mat
				wall.position = Vector3(side * 10.9, 3.7, -3.0)
				wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				rib_node.add_child(wall)

		# 4. Overhead Fluorescent Fixtures with downward SpotLight3D pools (spaced every 12m)
		if idx % 2 == 1:
			var fixture := MeshInstance3D.new()
			fixture.mesh = fluor_mesh
			fixture.material_override = tunnel_fluor_mat
			fixture.position = Vector3(0.0, 7.05, 0.0)
			rib_node.add_child(fixture)

			var spot := SpotLight3D.new()
			spot.light_color = Color("#E6F4FF")
			spot.light_energy = 3.8
			spot.spot_range = 14.0
			spot.spot_angle = 50.0
			spot.spot_attenuation = 1.0
			spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			spot.position = Vector3(0.0, 6.95, 0.0)
			spot.shadow_enabled = false
			rib_node.add_child(spot)

			var pool := MeshInstance3D.new()
			pool.mesh = pool_mesh
			pool.material_override = tunnel_pool_mat
			pool.position = Vector3(0.0, 0.035, 0.0)
			rib_node.add_child(pool)

		chunk.add_child(rib_node)

func _create_traffic_cone_mesh() -> Node3D:
	var root := Node3D.new()
	
	# Base plate (black rubber)
	var base := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.50, 0.04, 0.50)
	base.mesh = b_mesh
	base.material_override = cone_base_mat
	base.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(base)

	# Tapered cone body
	var cone := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.035
	c_mesh.bottom_radius = 0.22
	c_mesh.height = 0.65
	c_mesh.radial_segments = 12
	cone.mesh = c_mesh
	cone.material_override = traffic_cone_mat
	cone.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(cone)

	return root

func _build_construction_squeeze(chunk: Node3D, start_z: float) -> void:
	var squeeze_side: float = -1.0 if (chunk_spawn_count % 2 == 0) else 1.0
	var cordoned_x: float = squeeze_side * 6.6
	var divider_x: float = squeeze_side * 4.4
	var shoulder_x: float = squeeze_side * 9.2

	var cz := ConstructionZoneData.new()
	cz.global_z_start = start_z - 20.0
	cz.global_z_end = start_z - 100.0
	cz.cordoned_x = cordoned_x
	active_construction_zones.append(cz)

	# 1. Taper entrance with rubber traffic cones (from -20m to -45m)
	for i in range(7):
		var t: float = float(i) / 6.0
		var c_rel_z: float = -20.0 - (t * 25.0)
		var c_gz: float = start_z + c_rel_z
		var c_cx: float = _sample_road_x(c_gz)
		var c_tan: Vector3 = _sample_road_tangent(c_gz)
		var c_right: Vector3 = _sample_road_right(c_gz)
		var c_bank: float = _sample_road_bank(c_gz)
		var cone_offset_x: float = lerp(shoulder_x, divider_x, t)
		var cone_y: float = -sin(c_bank) * cone_offset_x + 0.02

		var cone_node := _create_traffic_cone_mesh()
		cone_node.position = Vector3(c_cx, cone_y, c_rel_z) + (c_right * cone_offset_x)
		cone_node.transform.basis = Basis.looking_at(c_tan, Vector3.UP)
		cone_node.rotate_object_local(Vector3(0, 0, 1), c_bank)
		chunk.add_child(cone_node)

		var cd := TrafficConeData.new()
		cd.node = cone_node
		cd.global_z = c_gz
		cd.global_x = cone_offset_x
		active_traffic_cones.append(cd)

	# 2. Cordoned Lane Striped Plastic Barricades with Flashing Amber Strobes (from -45m to -95m)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.15, 0.95, 3.8)

	var strobe_mesh := BoxMesh.new()
	strobe_mesh.size = Vector3(0.22, 0.22, 0.22)

	for b_step in [46.0, 52.0, 58.0, 64.0, 70.0, 76.0, 82.0, 88.0, 94.0]:
		var b_rel_z: float = -b_step
		var b_gz: float = start_z + b_rel_z
		var b_cx: float = _sample_road_x(b_gz)
		var b_tan: Vector3 = _sample_road_tangent(b_gz)
		var b_right: Vector3 = _sample_road_right(b_gz)
		var b_bank: float = _sample_road_bank(b_gz)
		var b_y: float = -sin(b_bank) * divider_x + 0.48

		var barrier := MeshInstance3D.new()
		barrier.mesh = bar_mesh
		barrier.material_override = constr_barrier_mat
		barrier.position = Vector3(b_cx, b_y, b_rel_z) + (b_right * divider_x)
		barrier.transform.basis = Basis.looking_at(b_tan, Vector3.UP)
		barrier.rotate_object_local(Vector3(0, 0, 1), b_bank)
		chunk.add_child(barrier)

		var strobe := MeshInstance3D.new()
		strobe.mesh = strobe_mesh
		strobe.material_override = amber_strobe_mat
		strobe.position = Vector3(0.0, 0.58, 0.0)
		barrier.add_child(strobe)

	# 3. Scattered rubber cones inside the work zone
	for sc_idx in range(5):
		var sc_rel_z: float = -48.0 - (float(sc_idx) * 10.0) + randf_range(-2.0, 2.0)
		var sc_gz: float = start_z + sc_rel_z
		var sc_cx: float = _sample_road_x(sc_gz)
		var sc_tan: Vector3 = _sample_road_tangent(sc_gz)
		var sc_right: Vector3 = _sample_road_right(sc_gz)
		var sc_bank: float = _sample_road_bank(sc_gz)
		var sc_offset_x: float = cordoned_x + randf_range(-0.8, 0.8)
		var sc_y: float = -sin(sc_bank) * sc_offset_x + 0.02

		var cone_node := _create_traffic_cone_mesh()
		cone_node.position = Vector3(sc_cx, sc_y, sc_rel_z) + (sc_right * sc_offset_x)
		cone_node.transform.basis = Basis.looking_at(sc_tan, Vector3.UP)
		cone_node.rotate_object_local(Vector3(0, 0, 1), sc_bank)
		chunk.add_child(cone_node)

		var cd := TrafficConeData.new()
		cd.node = cone_node
		cd.global_z = sc_gz
		cd.global_x = sc_offset_x
		active_traffic_cones.append(cd)

func _build_toll_plaza(chunk: Node3D, start_z: float) -> void:
	var plaza_z: float = -60.0
	var p_gz: float = start_z + plaza_z
	var p_cx: float = _sample_road_x(p_gz)
	var p_tan: Vector3 = _sample_road_tangent(p_gz)
	var p_bank: float = _sample_road_bank(p_gz)

	var toll_node := Node3D.new()
	toll_node.position = Vector3(p_cx, 0.0, plaza_z)
	toll_node.transform.basis = Basis.looking_at(p_tan, Vector3.UP)
	toll_node.rotate_object_local(Vector3(0, 0, 1), p_bank)
	chunk.add_child(toll_node)

	var open_idx := randi() % 4
	var open_x: float = LANE_OFFSETS[open_idx]

	var tp := TollPlazaData.new()
	tp.global_z = p_gz
	tp.open_lane_x = open_x
	active_toll_plazas.append(tp)

	# 5 Concrete booth island cabins: at x = -8.8, -4.4, 0.0, 4.4, 8.8
	var booth_mesh := BoxMesh.new()
	booth_mesh.size = Vector3(0.85, 3.2, 5.5)

	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.95, 0.8, 1.2)

	for bx in [-8.8, -4.4, 0.0, 4.4, 8.8]:
		var booth := MeshInstance3D.new()
		booth.mesh = booth_mesh
		booth.material_override = tunnel_concrete_mat
		booth.position = Vector3(bx, 1.6, 0.0)
		toll_node.add_child(booth)

		var nose := MeshInstance3D.new()
		nose.mesh = nose_mesh
		nose.material_override = constr_barrier_mat
		nose.position = Vector3(bx, 0.4, 3.2)
		toll_node.add_child(nose)

	# Overhead Toll Roof Canopy
	var canopy := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(21.5, 0.85, 6.5)
	canopy.mesh = c_mesh
	canopy.material_override = tunnel_rib_mat
	canopy.position = Vector3(0.0, 4.8, 0.0)
	toll_node.add_child(canopy)

	var fascia := Label3D.new()
	fascia.text = "首都高 TOLL PLAZA // 料金所"
	fascia.font_size = 38
	fascia.modulate = Color("#FFDF00")
	fascia.outline_modulate = Color("#080808")
	fascia.outline_size = 8
	fascia.position = Vector3(0.0, 5.8, 3.3)
	toll_node.add_child(fascia)

	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(2.2, 1.3, 0.25)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(3.2, 0.16, 0.16)

	for i in range(4):
		var lx: float = LANE_OFFSETS[i]
		var is_open: bool = (i == open_idx)

		var gate_sign := MeshInstance3D.new()
		gate_sign.mesh = sign_mesh
		gate_sign.material_override = toll_sign_open_mat if is_open else toll_sign_closed_mat
		gate_sign.position = Vector3(lx, 4.2, 3.3)
		toll_node.add_child(gate_sign)

		var boom := MeshInstance3D.new()
		boom.mesh = arm_mesh
		boom.material_override = constr_barrier_mat
		boom.position = Vector3(lx, 0.95, 2.2)
		toll_node.add_child(boom)

		var gate_entry := TollGateBarrier.new()
		gate_entry.lane_x = lx
		gate_entry.boom_node = boom
		gate_entry.sign_node = gate_sign
		gate_entry.is_open_lane = is_open
		gate_entry.broken = false
		tp.gates.append(gate_entry)

# ==============================================================================
# OUTRUN HIGHWAY FORKS & 4-BIOME 3D PROP BUILDERS
# ==============================================================================
func _build_fork_gantry(chunk: Node3D, start_z: float, left_name: String, right_name: String) -> void:
	var g_rel_z: float = -45.0
	var g_gz: float = start_z + g_rel_z
	var g_cx: float = _sample_road_x(g_gz)
	var g_tan: Vector3 = _sample_road_tangent(g_gz)

	var gantry_root := Node3D.new()
	gantry_root.name = "ForkGantry"
	gantry_root.position = Vector3(g_cx, 0.0, g_rel_z)
	gantry_root.transform.basis = Basis.looking_at(g_tan, Vector3.UP)

	# 1. Industrial Steel Posts on Left & Right Highway Edges
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.9, 9.2, 0.9)
	for side in [-15.2, 15.2]:
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = barrier_material
		post.position = Vector3(side, 4.6, 0.0)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gantry_root.add_child(post)

	# 2. Heavy Double Lattice Cross-Truss
	var truss_mesh := BoxMesh.new()
	truss_mesh.size = Vector3(31.5, 1.2, 1.4)
	for ty in [7.2, 8.8]:
		var truss := MeshInstance3D.new()
		truss.mesh = truss_mesh
		truss.material_override = barrier_material
		truss.position = Vector3(0.0, ty, 0.0)
		truss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gantry_root.add_child(truss)

	# 3. Dual Unshaded Neon Destination Billboards
	# Left Billboard: [ ⬸ LEFT // HAKONE SNOW ]
	var left_sign_bg := MeshInstance3D.new()
	var bg_mesh_l := BoxMesh.new()
	bg_mesh_l.size = Vector3(10.5, 2.8, 0.25)
	left_sign_bg.mesh = bg_mesh_l
	left_sign_bg.position = Vector3(-7.2, 8.0, 0.8)
	left_sign_bg.material_override = expansion_rubber_mat
	left_sign_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry_root.add_child(left_sign_bg)

	var left_lbl := Label3D.new()
	left_lbl.text = "⬸ LEFT LANE //\n" + left_name
	left_lbl.font_size = 46
	left_lbl.modulate = Color("#00E5FF")
	left_lbl.outline_modulate = Color("#002838")
	left_lbl.outline_size = 12
	left_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_lbl.position = Vector3(-7.2, 8.0, 0.95)
	left_lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	left_lbl.no_depth_test = false
	left_lbl.render_priority = 2
	gantry_root.add_child(left_lbl)

	# Right Billboard: [ ENOSHIMA COAST // RIGHT ⤑ ]
	var right_sign_bg := MeshInstance3D.new()
	var bg_mesh_r := BoxMesh.new()
	bg_mesh_r.size = Vector3(10.5, 2.8, 0.25)
	right_sign_bg.mesh = bg_mesh_r
	right_sign_bg.position = Vector3(7.2, 8.0, 0.8)
	right_sign_bg.material_override = expansion_rubber_mat
	right_sign_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry_root.add_child(right_sign_bg)

	var right_lbl := Label3D.new()
	right_lbl.text = right_name + "\n// RIGHT LANE ⤑"
	right_lbl.font_size = 46
	right_lbl.modulate = Color("#FF2A55")
	right_lbl.outline_modulate = Color("#440018")
	right_lbl.outline_size = 12
	right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_lbl.position = Vector3(7.2, 8.0, 0.95)
	right_lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	right_lbl.no_depth_test = false
	right_lbl.render_priority = 2
	gantry_root.add_child(right_lbl)

	# 4. Overhead Spotlight Illuminating Signs
	var g_spot := SpotLight3D.new()
	g_spot.light_color = Color("#FFFFFF")
	g_spot.light_energy = 4.0
	g_spot.spot_range = 18.0
	g_spot.spot_angle = 65.0
	g_spot.position = Vector3(0.0, 9.5, 2.5)
	g_spot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	g_spot.shadow_enabled = false
	gantry_root.add_child(g_spot)

	chunk.add_child(gantry_root)

func _build_twin_tunnels(chunk: Node3D, start_z: float) -> void:
	var tunnel_steps: Array[float] = [15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0, 85.0, 95.0, 105.0]

	var outer_pillar_mesh := BoxMesh.new()
	outer_pillar_mesh.size = Vector3(0.9, 7.5, 1.4)

	var center_divider_mesh := BoxMesh.new()
	center_divider_mesh.size = Vector3(1.4, 7.5, 10.0)

	var rib_mesh := BoxMesh.new()
	rib_mesh.size = Vector3(13.5, 0.8, 1.2)

	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(13.2, 0.45, 10.0)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.6, 7.4, 10.0)

	var fluor_mesh := BoxMesh.new()
	fluor_mesh.size = Vector3(0.65, 0.18, 5.0)

	for idx in range(tunnel_steps.size()):
		var step: float = tunnel_steps[idx]
		var local_z: float = -step
		var global_z: float = start_z + local_z
		var center_x: float = _sample_road_x(global_z)
		var tan_vec: Vector3 = _sample_road_tangent(global_z)
		var basis_look := Basis.looking_at(tan_vec, Vector3.UP)

		var frame := Node3D.new()
		frame.position = Vector3(center_x, 0.0, local_z)
		frame.transform.basis = basis_look

		# Left Outer Wall & Pillar
		var left_pillar := MeshInstance3D.new()
		left_pillar.mesh = outer_pillar_mesh
		left_pillar.material_override = tunnel_concrete_mat
		left_pillar.position = Vector3(-13.8, 3.75, 0.0)
		left_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(left_pillar)

		# Right Outer Wall & Pillar
		var right_pillar := MeshInstance3D.new()
		right_pillar.mesh = outer_pillar_mesh
		right_pillar.material_override = tunnel_concrete_mat
		right_pillar.position = Vector3(13.8, 3.75, 0.0)
		right_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(right_pillar)

		# Center Pier / Dividing Concrete Wall (separates left and right barrels)
		var center_wall := MeshInstance3D.new()
		center_wall.mesh = center_divider_mesh
		center_wall.material_override = tunnel_concrete_mat
		center_wall.position = Vector3(0.0, 3.75, -5.0)
		center_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(center_wall)

		# Left Tunnel Overhead Rib
		var rib_l := MeshInstance3D.new()
		rib_l.mesh = rib_mesh
		rib_l.material_override = tunnel_rib_mat
		rib_l.position = Vector3(-6.8, 7.2, 0.0)
		rib_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(rib_l)

		# Right Tunnel Overhead Rib
		var rib_r := MeshInstance3D.new()
		rib_r.mesh = rib_mesh
		rib_r.material_override = tunnel_rib_mat
		rib_r.position = Vector3(6.8, 7.2, 0.0)
		rib_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frame.add_child(rib_r)

		# Slabs and Outer Walls
		if idx < tunnel_steps.size() - 1:
			var slab_l := MeshInstance3D.new()
			slab_l.mesh = slab_mesh
			slab_l.material_override = tunnel_concrete_mat
			slab_l.position = Vector3(-6.8, 7.5, -5.0)
			slab_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			frame.add_child(slab_l)

			var slab_r := MeshInstance3D.new()
			slab_r.mesh = slab_mesh
			slab_r.material_override = tunnel_concrete_mat
			slab_r.position = Vector3(6.8, 7.5, -5.0)
			slab_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			frame.add_child(slab_r)

			var wall_l := MeshInstance3D.new()
			wall_l.mesh = wall_mesh
			wall_l.material_override = tunnel_concrete_mat
			wall_l.position = Vector3(-13.8, 3.7, -5.0)
			wall_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			frame.add_child(wall_l)

			var wall_r := MeshInstance3D.new()
			wall_r.mesh = wall_mesh
			wall_r.material_override = tunnel_concrete_mat
			wall_r.position = Vector3(13.8, 3.7, -5.0)
			wall_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			frame.add_child(wall_r)

		# Overhead Fluorescent strip lights in both barrels
		for b_x in [-6.8, 6.8]:
			var fl := MeshInstance3D.new()
			fl.mesh = fluor_mesh
			fl.material_override = tunnel_fluor_mat
			fl.position = Vector3(b_x, 7.05, 0.0)
			frame.add_child(fl)

			var spot := SpotLight3D.new()
			spot.light_color = Color("#E6F4FF")
			spot.light_energy = 3.6
			spot.spot_range = 14.0
			spot.spot_angle = 50.0
			spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			spot.position = Vector3(b_x, 6.95, 0.0)
			spot.shadow_enabled = false
			frame.add_child(spot)

		chunk.add_child(frame)

func _add_3d_palm_tree(trunk_st: SurfaceTool, frond_st: SurfaceTool, ground_pos: Vector3, scale_f: float, seed_val: float) -> void:
	var h_seg: int = 4
	var total_h: float = 7.0 * scale_f
	var lean_dir: Vector3 = Vector3(cos(seed_val * 6.28), 0.0, sin(seed_val * 6.28)).normalized() * (1.2 * scale_f)

	for s in range(h_seg):
		var t0: float = float(s) / float(h_seg)
		var t1: float = float(s + 1) / float(h_seg)
		var p0: Vector3 = ground_pos + Vector3(0.0, t0 * total_h, 0.0) + (lean_dir * t0 * t0)
		var p1: Vector3 = ground_pos + Vector3(0.0, t1 * total_h, 0.0) + (lean_dir * t1 * t1)
		var r0: float = lerp(0.38, 0.18, t0) * scale_f
		var r1: float = lerp(0.38, 0.18, t1) * scale_f

		trunk_st.add_vertex(p0 + Vector3(-r0, 0.0, 0.0))
		trunk_st.add_vertex(p0 + Vector3(r0, 0.0, 0.0))
		trunk_st.add_vertex(p1 + Vector3(r1, 0.0, 0.0))

		trunk_st.add_vertex(p0 + Vector3(-r0, 0.0, 0.0))
		trunk_st.add_vertex(p1 + Vector3(r1, 0.0, 0.0))
		trunk_st.add_vertex(p1 + Vector3(-r1, 0.0, 0.0))

	# Palm Fronds Crown radiating outwards
	var apex: Vector3 = ground_pos + Vector3(0.0, total_h, 0.0) + lean_dir
	var num_fronds: int = 7
	for f in range(num_fronds):
		var f_angle: float = float(f) * (TAU / float(num_fronds)) + (seed_val * 2.0)
		var f_dir := Vector3(cos(f_angle), 0.0, sin(f_angle)).normalized()
		var f_len: float = (3.2 + fposmod(seed_val * float(f + 1) * 3.1, 1.4)) * scale_f
		var f_mid: Vector3 = apex + (f_dir * f_len * 0.55) + Vector3(0.0, 0.6 * scale_f, 0.0)
		var f_tip: Vector3 = apex + (f_dir * f_len) - Vector3(0.0, 0.8 * scale_f, 0.0)
		var f_w: float = 0.55 * scale_f

		var f_side := f_dir.cross(Vector3.UP).normalized() * f_w
		frond_st.add_vertex(apex)
		frond_st.add_vertex(f_mid + f_side)
		frond_st.add_vertex(f_mid - f_side)

		frond_st.add_vertex(f_mid + f_side)
		frond_st.add_vertex(f_tip)
		frond_st.add_vertex(f_mid - f_side)

func _add_3d_snow_pine(foliage_st: SurfaceTool, snow_st: SurfaceTool, ground_pos: Vector3, scale_f: float, seed_val: float) -> void:
	var total_h: float = 8.5 * scale_f
	var tiers: int = 4
	for t in range(tiers):
		var t_ratio: float = float(t) / float(tiers)
		var y_base: float = ground_pos.y + (t_ratio * total_h * 0.75) + (1.2 * scale_f)
		var y_top: float = y_base + (2.4 * scale_f)
		var r_base: float = (2.8 - t_ratio * 1.8) * scale_f

		for side in [-1.0, 1.0]:
			foliage_st.add_vertex(Vector3(ground_pos.x - r_base, y_base, ground_pos.z))
			foliage_st.add_vertex(Vector3(ground_pos.x + r_base, y_base, ground_pos.z))
			foliage_st.add_vertex(Vector3(ground_pos.x, y_top, ground_pos.z))

			foliage_st.add_vertex(Vector3(ground_pos.x, y_base, ground_pos.z - r_base))
			foliage_st.add_vertex(Vector3(ground_pos.x, y_base, ground_pos.z + r_base))
			foliage_st.add_vertex(Vector3(ground_pos.x, y_top, ground_pos.z))

		var y_snow_base: float = y_base + (0.45 * scale_f)
		var y_snow_top: float = y_top + (0.15 * scale_f)
		var r_snow: float = r_base * 0.85
		snow_st.add_vertex(Vector3(ground_pos.x - r_snow, y_snow_base, ground_pos.z))
		snow_st.add_vertex(Vector3(ground_pos.x + r_snow, y_snow_base, ground_pos.z))
		snow_st.add_vertex(Vector3(ground_pos.x, y_snow_top, ground_pos.z))

		snow_st.add_vertex(Vector3(ground_pos.x, y_snow_base, ground_pos.z - r_snow))
		snow_st.add_vertex(Vector3(ground_pos.x, y_snow_base, ground_pos.z + r_snow))
		snow_st.add_vertex(Vector3(ground_pos.x, y_snow_top, ground_pos.z))

func _add_shinjuku_building(bld_st: SurfaceTool, win_st: SurfaceTool, b_min: Vector3, b_max: Vector3, seed_val: float) -> void:
	var p000 := Vector3(b_min.x, b_min.y, b_min.z)
	var p100 := Vector3(b_max.x, b_min.y, b_min.z)
	var p110 := Vector3(b_max.x, b_max.y, b_min.z)
	var p010 := Vector3(b_min.x, b_max.y, b_min.z)
	var p001 := Vector3(b_min.x, b_min.y, b_max.z)
	var p101 := Vector3(b_max.x, b_min.y, b_max.z)
	var p111 := Vector3(b_max.x, b_max.y, b_max.z)
	var p011 := Vector3(b_min.x, b_max.y, b_max.z)

	# Front face
	bld_st.add_vertex(p000); bld_st.add_vertex(p100); bld_st.add_vertex(p110)
	bld_st.add_vertex(p000); bld_st.add_vertex(p110); bld_st.add_vertex(p010)
	# Street side face (facing the road)
	if b_min.x > 0.0:
		bld_st.add_vertex(p000); bld_st.add_vertex(p010); bld_st.add_vertex(p011)
		bld_st.add_vertex(p000); bld_st.add_vertex(p011); bld_st.add_vertex(p001)
	else:
		bld_st.add_vertex(p100); bld_st.add_vertex(p101); bld_st.add_vertex(p111)
		bld_st.add_vertex(p100); bld_st.add_vertex(p111); bld_st.add_vertex(p110)
	# Roof
	bld_st.add_vertex(p010); bld_st.add_vertex(p110); bld_st.add_vertex(p111)
	bld_st.add_vertex(p010); bld_st.add_vertex(p111); bld_st.add_vertex(p011)

	# Windows on the facade facing street
	var face_x: float = b_min.x if b_min.x > 0.0 else b_max.x
	var face_offset: float = -0.1 if b_min.x > 0.0 else 0.1
	var z_len: float = abs(b_max.z - b_min.z)
	var h_len: float = abs(b_max.y - b_min.y)
	var num_floors: int = int(h_len / 4.2)
	for fl in range(1, num_floors):
		var y_win: float = b_min.y + float(fl) * 4.2
		for wz in [0.25, 0.55, 0.85]:
			var z_win: float = b_min.z + (z_len * wz)
			var w_w: float = 1.6
			var w_h: float = 1.4
			var wp0 := Vector3(face_x + face_offset, y_win, z_win - w_w * 0.5)
			var wp1 := Vector3(face_x + face_offset, y_win, z_win + w_w * 0.5)
			var wp2 := Vector3(face_x + face_offset, y_win + w_h, z_win + w_w * 0.5)
			var wp3 := Vector3(face_x + face_offset, y_win + w_h, z_win - w_w * 0.5)
			win_st.add_vertex(wp0); win_st.add_vertex(wp1); win_st.add_vertex(wp2)
			win_st.add_vertex(wp0); win_st.add_vertex(wp2); win_st.add_vertex(wp3)

func _add_3d_vending_machine(v_body_st: SurfaceTool, v_glass_st: SurfaceTool, pos: Vector3, rot_y: float, seed_val: float) -> void:
	var w: float = 1.2
	var h: float = 2.0
	var d: float = 0.85
	var p00 := pos + Vector3(-w * 0.5, 0.0, -d * 0.5)
	var p10 := pos + Vector3(w * 0.5, 0.0, -d * 0.5)
	var p11 := pos + Vector3(w * 0.5, h, -d * 0.5)
	var p01 := pos + Vector3(-w * 0.5, h, -d * 0.5)

	v_body_st.add_vertex(p00); v_body_st.add_vertex(p10); v_body_st.add_vertex(p11)
	v_body_st.add_vertex(p00); v_body_st.add_vertex(p11); v_body_st.add_vertex(p01)

	var gw0 := pos + Vector3(-w * 0.42, 0.85, -d * 0.5 - 0.05)
	var gw1 := pos + Vector3(w * 0.42, 0.85, -d * 0.5 - 0.05)
	var gw2 := pos + Vector3(w * 0.42, h - 0.15, -d * 0.5 - 0.05)
	var gw3 := pos + Vector3(-w * 0.42, h - 0.15, -d * 0.5 - 0.05)
	v_glass_st.add_vertex(gw0); v_glass_st.add_vertex(gw1); v_glass_st.add_vertex(gw2)
	v_glass_st.add_vertex(gw0); v_glass_st.add_vertex(gw2); v_glass_st.add_vertex(gw3)

func _add_3d_power_pole(pole_st: SurfaceTool, line_st: SurfaceTool, pos: Vector3, next_pos: Vector3) -> void:
	var h: float = 8.5
	var r: float = 0.18

	pole_st.add_vertex(pos + Vector3(-r, 0.0, 0.0))
	pole_st.add_vertex(pos + Vector3(r, 0.0, 0.0))
	pole_st.add_vertex(pos + Vector3(r, h, 0.0))

	pole_st.add_vertex(pos + Vector3(-r, 0.0, 0.0))
	pole_st.add_vertex(pos + Vector3(r, h, 0.0))
	pole_st.add_vertex(pos + Vector3(-r, h, 0.0))

	var cw: float = 1.4
	for cy in [7.0, 8.0]:
		pole_st.add_vertex(pos + Vector3(-cw, cy - 0.08, 0.0))
		pole_st.add_vertex(pos + Vector3(cw, cy - 0.08, 0.0))
		pole_st.add_vertex(pos + Vector3(cw, cy + 0.08, 0.0))

		pole_st.add_vertex(pos + Vector3(-cw, cy - 0.08, 0.0))
		pole_st.add_vertex(pos + Vector3(cw, cy + 0.08, 0.0))
		pole_st.add_vertex(pos + Vector3(-cw, cy + 0.08, 0.0))

	if next_pos != Vector3.ZERO:
		var pA := pos + Vector3(0.0, 7.8, 0.0)
		var pB := next_pos + Vector3(0.0, 7.8, 0.0)
		var pMid := (pA + pB) * 0.5 - Vector3(0.0, 0.6, 0.0)

		line_st.add_vertex(pA + Vector3(0.0, -0.04, 0.0))
		line_st.add_vertex(pA + Vector3(0.0, 0.04, 0.0))
		line_st.add_vertex(pMid + Vector3(0.0, 0.04, 0.0))

		line_st.add_vertex(pA + Vector3(0.0, -0.04, 0.0))
		line_st.add_vertex(pMid + Vector3(0.0, 0.04, 0.0))
		line_st.add_vertex(pMid + Vector3(0.0, -0.04, 0.0))

		line_st.add_vertex(pMid + Vector3(0.0, -0.04, 0.0))
		line_st.add_vertex(pMid + Vector3(0.0, 0.04, 0.0))
		line_st.add_vertex(pB + Vector3(0.0, 0.04, 0.0))

		line_st.add_vertex(pMid + Vector3(0.0, -0.04, 0.0))
		line_st.add_vertex(pB + Vector3(0.0, 0.04, 0.0))
		line_st.add_vertex(pB + Vector3(0.0, -0.04, 0.0))

func _add_3d_neon_sign(chunk: Node3D, pos: Vector3, tan_vec: Vector3, text: String, color_idx: int) -> void:
	var sign_node := Node3D.new()
	sign_node.position = pos
	sign_node.transform.basis = Basis.looking_at(tan_vec, Vector3.UP)

	# Blade sign frame
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.25, 4.4, 1.4)
	var box_inst := MeshInstance3D.new()
	box_inst.mesh = box_mesh
	var sign_mat: StandardMaterial3D
	match color_idx % 3:
		0: sign_mat = neon_pink_mat
		1: sign_mat = neon_cyan_mat
		_: sign_mat = neon_yellow_mat
	box_inst.material_override = sign_mat
	box_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign_node.add_child(box_inst)

	# Twin neon labels on both faces
	for sign_dir in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font_size = 42
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color.BLACK
		lbl.outline_size = 10
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector3(sign_dir * 0.14, 0.0, 0.0)
		lbl.rotation_degrees = Vector3(0.0, 90.0 * sign_dir, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lbl.no_depth_test = false
		lbl.render_priority = 2
		sign_node.add_child(lbl)

	chunk.add_child(sign_node)

func _spawn_shattered_gate_booms(pos: Vector3, tan_dir: Vector3, right_dir: Vector3) -> void:
	var half_arm_mesh := BoxMesh.new()
	half_arm_mesh.size = Vector3(1.6, 0.16, 0.16)

	for side in [-1.0, 1.0]:
		var half := MeshInstance3D.new()
		half.mesh = half_arm_mesh
		half.material_override = constr_barrier_mat
		half.position = pos + (right_dir * (side * 0.75)) + Vector3(0.0, 0.15, 0.0)
		add_child(half)

		var debris := FlyingCone.new()
		debris.node = half
		var kick_speed: float = player_speed * 0.65 + randf_range(8.0, 16.0)
		debris.velocity = (tan_dir * kick_speed) + (right_dir * (side * randf_range(6.0, 12.0))) + Vector3(0.0, randf_range(8.0, 14.0), 0.0)
		debris.ang_velocity = Vector3(randf_range(16.0, 32.0), randf_range(12.0, 24.0), randf_range(14.0, 28.0))
		debris.time_left = 1.6
		active_flying_cones.append(debris)

	# Radial burst of geometric comic spark wedges
	for k in range(8):
		var spark := MeshInstance3D.new()
		var sm := PrismMesh.new()
		sm.size = Vector3(0.18, 0.38, 0.05)
		spark.mesh = sm
		spark.material_override = spark_mat
		var sp_pos := pos + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.4), randf_range(-0.3, 0.3))
		spark.position = sp_pos
		add_child(spark)

		var tw := spark.create_tween()
		var sp_dir := (Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.2), randf_range(-1.0, 0.2))).normalized()
		var target := sp_pos + (sp_dir * randf_range(2.5, 5.0))
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "scale", Vector3(0.1, 0.1, 0.1), 0.22)
		tw.chain().tween_callback(spark.queue_free)

func _spawn_floating_smash_badge(world_pos: Vector3, pts: int) -> void:
	if not is_instance_valid(hud_graze_container) or not is_instance_valid(follow_cam):
		return
	var screen_pos: Vector2 = follow_cam.unproject_position(world_pos)
	var badge := Label.new()
	badge.text = "💥 SMASH! +" + str(pts)
	badge.position = screen_pos + Vector2(randf_range(-30, 30), randf_range(-40, -10))
	badge.add_theme_font_size_override("font_size", 42)
	badge.add_theme_color_override("font_color", Color("#FF3B30"))
	badge.add_theme_color_override("font_shadow_color", Color("#FFE600"))
	badge.add_theme_constant_override("shadow_offset_x", 3)
	badge.add_theme_constant_override("shadow_offset_y", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_graze_container.add_child(badge)

	var tw := badge.create_tween()
	tw.set_parallel(true)
	tw.tween_property(badge, "position:y", badge.position.y - 75.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.35, 1.35), 0.15).from(Vector2(0.5, 0.5))
	tw.chain().tween_property(badge, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(badge.queue_free)

func _spawn_flying_cone(pos: Vector3) -> void:
	var fc := _create_traffic_cone_mesh()
	fc.position = pos + Vector3(0.0, 0.2, 0.0)
	add_child(fc)

	var flying := FlyingCone.new()
	flying.node = fc
	flying.velocity = Vector3(randf_range(-5.0, 5.0), randf_range(8.0, 13.0), -player_speed * 0.45 - randf_range(6.0, 12.0))
	flying.ang_velocity = Vector3(randf_range(12.0, 22.0), randf_range(16.0, 28.0), randf_range(8.0, 18.0))
	flying.time_left = 1.3
	active_flying_cones.append(flying)

func _spawn_tire_slap_puffs() -> void:
	if not is_instance_valid(car_root):
		return
	var car_trans := car_root.global_transform
	var right_dir := car_trans.basis.x.normalized()
	var fwd_dir := car_trans.basis.z.normalized()

	for side in [-0.76, 0.76]:
		for z_offset in [-1.4, 1.3]:
			var puff := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.35, 0.35)
			puff.mesh = qm
			puff.material_override = smoke_puff_mat
			puff.position = car_trans.origin + (right_dir * side) + (fwd_dir * z_offset) + Vector3(0.0, 0.12, 0.0)
			puff.scale = Vector3(0.2, 0.2, 0.2)
			add_child(puff)

			var tw := puff.create_tween()
			tw.set_parallel(true)
			tw.tween_property(puff, "scale", Vector3(0.55, 0.55, 0.55), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.chain().tween_callback(puff.queue_free)

# ==============================================================================
# PROCEDURAL ARCADE AUDIO SYNTHESIZER (ZERO-ASSET SELF-CONTAINED SOUNDS)
# ==============================================================================
func _setup_procedural_audio() -> void:
	# Retired procedural synthesizer in favor of authentic sample suite (avoids WebAudio generator heap faults)
	return

func _play_proc_audio(sound_type: String) -> void:
	if not is_instance_valid(proc_audio_playback):
		return
	if sound_type == "radio_static":
		return
	var frames_to_push := int(0.12 * 22050.0)
	if sound_type == "chirp":
		frames_to_push = int(0.09 * 22050.0)
	elif sound_type == "radio_static":
		frames_to_push = int(0.28 * 22050.0)
	elif sound_type == "pop":
		frames_to_push = int(0.08 * 22050.0)
	elif sound_type == "siren":
		frames_to_push = int(0.32 * 22050.0)
	elif sound_type == "splash":
		frames_to_push = int(0.18 * 22050.0)

	var avail: int = proc_audio_playback.get_frames_available()
	var to_write: int = mini(avail, frames_to_push)
	if to_write <= 0:
		return

	var phase: float = 0.0
	for i in range(to_write):
		var t: float = float(i) / 22050.0
		var sample: float = 0.0
		if sound_type == "chirp":
			var freq: float = lerp(1600.0, 2600.0, float(i) / float(to_write))
			phase += freq / 22050.0 * TAU
			var env: float = (1.0 - (float(i) / float(to_write)))
			sample = sin(phase) * 0.35 * env
		elif sound_type == "radio_static":
			var noise_val := (randf() * 2.0 - 1.0)
			if t < 0.02:
				var squelch_pop := sin(t * 1100.0 * TAU) * 0.40
				sample = squelch_pop + noise_val * 0.45
			elif t > 0.23:
				var tail_env: float = clamp((0.28 - t) / 0.05, 0.0, 1.0)
				sample = (noise_val * 0.40 + sin(t * 1400.0 * TAU) * 0.30) * tail_env
			else:
				var radio_hum := sin(t * 120.0 * TAU) * 0.08
				var crackle := noise_val * (0.42 + 0.16 * sin(t * 350.0 * TAU))
				sample = (crackle + radio_hum) * 0.65
		elif sound_type == "pop":
			var env: float = exp(-t * 45.0)
			var noise: float = (randf() * 2.0 - 1.0) * 0.55
			var thump: float = sin(t * 75.0 * TAU) * 0.45
			sample = (noise + thump) * env * 0.70
		elif sound_type == "siren":
			var is_high: bool = (int(t * 10.0) % 2 == 0)
			var freq: float = 880.0 if is_high else 650.0
			phase += freq / 22050.0 * TAU
			sample = sin(phase) * 0.38
		elif sound_type == "splash":
			var env: float = sin(float(i) / float(to_write) * PI)
			sample = (randf() * 2.0 - 1.0) * 0.45 * env

		proc_audio_playback.push_frame(Vector2(sample, sample))

# ==============================================================================
# PRODUCTION ARCADE AUDIO ENGINE & MIXING
# ==============================================================================
func _setup_game_audio() -> void:
	# 1. Preload audio stream resources safely with type verification
	if OS.has_feature("web"):
		if ResourceLoader.exists("res://assets/audio/web_future_funk.mp3"):
			stream_rally_music = load("res://assets/audio/web_future_funk.mp3")
	else:
		if ResourceLoader.exists("res://assets/audio/future_funk.mp3"):
			stream_rally_music = load("res://assets/audio/future_funk.mp3")
	if ResourceLoader.exists("res://assets/audio/chatter.mp3"):
		stream_radio_chatter = load("res://assets/audio/chatter.mp3")
	if ResourceLoader.exists("res://assets/audio/rivalentry.mp3"):
		stream_rival_entry = load("res://assets/audio/rivalentry.mp3")
	if ResourceLoader.exists("res://assets/audio/engine_loop.mp3"):
		stream_engine_loop = load("res://assets/audio/engine_loop.mp3")
	if ResourceLoader.exists("res://assets/audio/gear_upshift.wav"):
		stream_gear_upshift = load("res://assets/audio/gear_upshift.wav")
	if ResourceLoader.exists("res://assets/audio/tire_drift.mp3"):
		stream_tire_drift = load("res://assets/audio/tire_drift.mp3")
	if ResourceLoader.exists("res://assets/audio/car_crash.wav"):
		stream_car_crash = load("res://assets/audio/car_crash.wav")

	# Ensure stream loop properties are enabled on looping resources
	if stream_rally_music and stream_rally_music is AudioStreamMP3:
		(stream_rally_music as AudioStreamMP3).loop = true

	if stream_engine_loop and stream_engine_loop is AudioStreamMP3:
		(stream_engine_loop as AudioStreamMP3).loop = true

	if stream_tire_drift and stream_tire_drift is AudioStreamMP3:
		(stream_tire_drift as AudioStreamMP3).loop = true

	# 2. Continuous In-Car Shuffled Rally Radio (Set to 50% Linear Volume ~ -6.02 dB)
	rally_music_player = AudioStreamPlayer.new()
	rally_music_player.name = "RallyMusicPlayer"
	rally_music_player.stream = stream_rally_music
	rally_music_player.volume_db = linear_to_db(playlist_volume)
	add_child(rally_music_player)
	rally_music_player.finished.connect(_play_random_rally_track)

	# 3. Radio Comms Chatter SFX Player
	radio_chatter_player = AudioStreamPlayer.new()
	radio_chatter_player.name = "RadioChatterPlayer"
	radio_chatter_player.stream = stream_radio_chatter
	radio_chatter_player.volume_db = linear_to_db(0.92)
	add_child(radio_chatter_player)

	# 4. Rival Entry SFX Player
	rival_entry_player = AudioStreamPlayer.new()
	rival_entry_player.name = "RivalEntryPlayer"
	rival_entry_player.stream = stream_rival_entry
	rival_entry_player.volume_db = linear_to_db(0.95)
	add_child(rival_entry_player)

	# 5. Authentic Recorded Sports Car Engine Player
	engine_audio_player = AudioStreamPlayer.new()
	engine_audio_player.name = "EngineAudioPlayer"
	engine_audio_player.stream = stream_engine_loop
	engine_audio_player.volume_db = 0.0
	engine_audio_player.pitch_scale = 1.0
	add_child(engine_audio_player)
	engine_audio_player.finished.connect(func():
		if is_instance_valid(engine_audio_player):
			engine_audio_player.play()
	)
	# 6. Dog-Box Sequential Gear Upshift SFX Player
	gear_shift_player = AudioStreamPlayer.new()
	gear_shift_player.name = "GearShiftPlayer"
	gear_shift_player.stream = stream_gear_upshift
	gear_shift_player.volume_db = linear_to_db(0.85)
	add_child(gear_shift_player)

	# 7. High-Tension Asphalt Tire Drift Screech Player (+30% Volume)
	drift_audio_player = AudioStreamPlayer.new()
	drift_audio_player.name = "DriftAudioPlayer"
	drift_audio_player.stream = stream_tire_drift
	drift_audio_player.volume_db = -80.0
	add_child(drift_audio_player)
	drift_audio_player.finished.connect(func():
		if is_instance_valid(drift_audio_player):
			drift_audio_player.play()
	)

	# 8. High-Impact Metal & Glass Car Crash SFX Player
	crash_audio_player = AudioStreamPlayer.new()
	crash_audio_player.name = "CrashAudioPlayer"
	crash_audio_player.stream = stream_car_crash
	crash_audio_player.volume_db = linear_to_db(1.35)
	add_child(crash_audio_player)

	# 8b. Escalating Graze Chime SFX Player
	graze_audio_player = AudioStreamPlayer.new()
	graze_audio_player.name = "GrazeAudioPlayer"
	graze_audio_player.stream = stream_gear_upshift
	graze_audio_player.volume_db = 1.0
	add_child(graze_audio_player)

	# 8c. Glancing Metallic Scrape SFX Player
	scrape_audio_player = AudioStreamPlayer.new()
	scrape_audio_player.name = "ScrapeAudioPlayer"
	scrape_audio_player.stream = stream_car_crash
	scrape_audio_player.volume_db = -6.0
	add_child(scrape_audio_player)

	# 8d. Nitro Surge / Overdrive Activation SFX Player
	nitro_audio_player = AudioStreamPlayer.new()
	nitro_audio_player.name = "NitroAudioPlayer"
	nitro_audio_player.stream = stream_rival_entry
	nitro_audio_player.volume_db = 2.0
	add_child(nitro_audio_player)

	# 9. Initialize audio playback safely based on platform.
	# On Web (HTML5/Wasm), browsers strictly require user interaction before running audio contexts.
	if OS.has_feature("web"):
		AudioServer.set_bus_mute(0, true)
	else:
		_audio_unlocked = true
		if is_instance_valid(engine_audio_player):
			engine_audio_player.play()
		_play_random_rally_track()

func _play_random_rally_track() -> void:
	if not is_instance_valid(rally_music_player) or not stream_rally_music:
		return
	if OS.has_feature("web"):
		current_rally_track_idx = 0
		var track: Dictionary = RALLY_TRACKS[0]
		current_rally_track_end = float(track["end"])
		rally_music_player.volume_db = linear_to_db(playlist_volume)
		rally_music_player.play(0.0)
		_show_music_track_popup(str(track["title"]))
		return

	var available_indices: Array[int] = []
	for i in range(RALLY_TRACKS.size()):
		if i != current_rally_track_idx:
			available_indices.append(i)
	if available_indices.is_empty():
		current_rally_track_idx = 0
	else:
		current_rally_track_idx = available_indices.pick_random()

	var track: Dictionary = RALLY_TRACKS[current_rally_track_idx]
	current_rally_track_end = float(track["end"])
	rally_music_player.volume_db = linear_to_db(playlist_volume)
	rally_music_player.play(float(track["start"]))
	_show_music_track_popup(str(track["title"]))

func _show_music_track_popup(title: String) -> void:
	if not is_instance_valid(rally_track_hud_box) or not is_instance_valid(rally_track_hud_label):
		return
	if is_instance_valid(rally_track_hud_tween) and rally_track_hud_tween.is_valid():
		rally_track_hud_tween.kill()

	rally_track_hud_label.text = "📻 [SHUFFLE] " + title
	rally_track_hud_box.modulate = Color(1, 1, 1, 1)
	rally_track_hud_box.visible = true

	rally_track_hud_tween = create_tween()
	rally_track_hud_tween.tween_interval(4.5)
	rally_track_hud_tween.tween_property(rally_track_hud_box, "modulate:a", 0.0, 0.5)
	rally_track_hud_tween.tween_callback(func():
		if is_instance_valid(rally_track_hud_box):
			rally_track_hud_box.visible = false
	)

func _process_audio_mixing(delta: float) -> void:
	# 1. Rally Playlist Continuous Background Shuffle Guard (Reduced by 15%)
	if is_instance_valid(rally_music_player):
		rally_music_player.volume_db = linear_to_db(playlist_volume)
		if not rally_music_player.playing and stream_rally_music:
			_play_random_rally_track()
		elif current_rally_track_end > 0.0:
			var cur_pos: float = rally_music_player.get_playback_position()
			if cur_pos >= current_rally_track_end:
				_play_random_rally_track()

	# 2. Authentic Sports Car Engine Volume & Speed Feedback
	if is_instance_valid(engine_audio_player):
		if not engine_audio_player.playing and stream_engine_loop:
			engine_audio_player.play()
		if current_state == GameState.CRASHED:
			engine_audio_player.volume_db = lerp(engine_audio_player.volume_db, -80.0, clamp(5.0 * delta, 0.0, 1.0))
		else:
			var speed_kmh: float = player_speed * 3.6
			# Subtle organic pitch climb (preserving raw recorded tone without synthetic warping)
			var base_pitch: float = lerp(0.95, 1.12, clamp(speed_kmh / 200.0, 0.0, 1.0))
			if boost_active:
				base_pitch *= 1.08

			engine_audio_player.pitch_scale = lerp(engine_audio_player.pitch_scale, base_pitch, clamp(8.0 * delta, 0.0, 1.0))
			var target_vol: float = lerp(-1.0, 2.0, clamp(speed_kmh / 180.0, 0.0, 1.0))
			engine_audio_player.volume_db = lerp(engine_audio_player.volume_db, target_vol, clamp(8.0 * delta, 0.0, 1.0))

	# 3. Authentic High-Tension Asphalt Tire Drift Screech (+30% Volume)
	if is_instance_valid(drift_audio_player):
		if drift_active and current_state == GameState.RACING:
			if not drift_audio_player.playing and stream_tire_drift:
				drift_audio_player.play()
			# Raised by 30% to linear 1.25 (+1.94 dB)
			var target_drift_vol: float = linear_to_db(1.25)
			var lat_ratio: float = clamp(abs(player_lat_velocity) / 6.0, 0.90, 1.20)
			drift_audio_player.volume_db = lerp(drift_audio_player.volume_db, target_drift_vol, clamp(18.0 * delta, 0.0, 1.0))
			drift_audio_player.pitch_scale = lerp(drift_audio_player.pitch_scale, 1.0 * lat_ratio, clamp(12.0 * delta, 0.0, 1.0))
		else:
			drift_audio_player.volume_db = lerp(drift_audio_player.volume_db, -80.0, clamp(18.0 * delta, 0.0, 1.0))
			if drift_audio_player.volume_db <= -70.0 and drift_audio_player.playing:
				drift_audio_player.stop()

# ==============================================================================
# SEASONAL WEATHER PARTICLES (TEXTURED LEAVES & 3-LAYER 3D SNOW)
# ==============================================================================
func _setup_weather_particles() -> void:
	leaf_particles = CPUParticles3D.new()
	leaf_particles.name = "LeafWeatherParticles"
	leaf_particles.amount = 45
	leaf_particles.lifetime = 2.2
	leaf_particles.preprocess = 0.5
	leaf_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaf_particles.emission_box_extents = Vector3(16.0, 3.5, 24.0)
	leaf_particles.direction = Vector3(-0.6, -0.3, 1.0).normalized()
	leaf_particles.spread = 28.0
	leaf_particles.initial_velocity_min = 12.0
	leaf_particles.initial_velocity_max = 24.0
	leaf_particles.angular_velocity_min = -180.0
	leaf_particles.angular_velocity_max = 180.0
	leaf_particles.scale_amount_min = 0.8
	leaf_particles.scale_amount_max = 1.4

	var leaf_qm := QuadMesh.new()
	leaf_qm.size = Vector2(0.30, 0.34)
	if leaf_mat:
		leaf_qm.material = leaf_mat
	leaf_particles.mesh = leaf_qm
	leaf_particles.color = Color(1.0, 1.0, 1.0, 0.95)
	add_child(leaf_particles)

	# 1. 3D Snow Layer 1: Near (Kept 20m+ ahead of camera lens to avoid hitting screen)
	snow_layer_near = CPUParticles3D.new()
	snow_layer_near.name = "SnowLayerNear"
	snow_layer_near.amount = 75
	snow_layer_near.lifetime = 1.8
	snow_layer_near.preprocess = 0.5
	snow_layer_near.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_layer_near.emission_box_extents = Vector3(14.0, 3.5, 12.0)
	snow_layer_near.direction = Vector3(-0.35, -2.2, 1.4).normalized()
	snow_layer_near.spread = 25.0
	snow_layer_near.initial_velocity_min = 8.0
	snow_layer_near.initial_velocity_max = 16.0
	snow_layer_near.angular_velocity_min = -90.0
	snow_layer_near.angular_velocity_max = 90.0
	snow_layer_near.scale_amount_min = 0.7
	snow_layer_near.scale_amount_max = 1.2

	var snow_qm_near := QuadMesh.new()
	snow_qm_near.size = Vector2(0.20, 0.20)
	if snow_mat:
		snow_qm_near.material = snow_mat
	snow_layer_near.mesh = snow_qm_near
	snow_layer_near.color = Color(1.0, 1.0, 1.0, 0.90)
	snow_layer_near.emitting = false
	add_child(snow_layer_near)

	# 2. 3D Snow Layer 2: Mid-Ground (Deep atmosphere over road and barriers)
	snow_layer_mid = CPUParticles3D.new()
	snow_layer_mid.name = "SnowLayerMid"
	snow_layer_mid.amount = 160
	snow_layer_mid.lifetime = 2.4
	snow_layer_mid.preprocess = 0.5
	snow_layer_mid.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_layer_mid.emission_box_extents = Vector3(36.0, 7.0, 30.0)
	snow_layer_mid.direction = Vector3(-0.30, -2.0, 1.8).normalized()
	snow_layer_mid.spread = 30.0
	snow_layer_mid.initial_velocity_min = 10.0
	snow_layer_mid.initial_velocity_max = 20.0
	snow_layer_mid.angular_velocity_min = -70.0
	snow_layer_mid.angular_velocity_max = 70.0
	snow_layer_mid.scale_amount_min = 0.8
	snow_layer_mid.scale_amount_max = 1.3

	var snow_qm_mid := QuadMesh.new()
	snow_qm_mid.size = Vector2(0.30, 0.30)
	if snow_mat:
		snow_qm_mid.material = snow_mat
	snow_layer_mid.mesh = snow_qm_mid
	snow_layer_mid.color = Color(0.95, 0.98, 1.0, 0.80)
	snow_layer_mid.emitting = false
	add_child(snow_layer_mid)

	# 3. 3D Snow Layer 3: Distant Blizzard Veil (Sweeps against horizon skyline and peaks)
	snow_layer_far = CPUParticles3D.new()
	snow_layer_far.name = "SnowLayerFar"
	snow_layer_far.amount = 240
	snow_layer_far.lifetime = 3.2
	snow_layer_far.preprocess = 0.5
	snow_layer_far.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_layer_far.emission_box_extents = Vector3(90.0, 15.0, 65.0)
	snow_layer_far.direction = Vector3(-0.25, -1.8, 2.2).normalized()
	snow_layer_far.spread = 35.0
	snow_layer_far.initial_velocity_min = 12.0
	snow_layer_far.initial_velocity_max = 24.0
	snow_layer_far.angular_velocity_min = -50.0
	snow_layer_far.angular_velocity_max = 50.0
	snow_layer_far.scale_amount_min = 0.9
	snow_layer_far.scale_amount_max = 1.5

	var snow_qm_far := QuadMesh.new()
	snow_qm_far.size = Vector2(0.44, 0.44)
	if snow_mat:
		snow_qm_far.material = snow_mat
	snow_layer_far.mesh = snow_qm_far
	snow_layer_far.color = Color(0.90, 0.95, 1.0, 0.60)
	snow_layer_far.emitting = false
	add_child(snow_layer_far)

# ==============================================================================
# MID-RACE ANIME RADIO CHATTER POPUP
# ==============================================================================
func _trigger_radio_chatter(speaker: String, text: String, color: Color = Color("#FFD000"), force: bool = false) -> void:
	if not is_instance_valid(hud_radio_chatter):
		return
	if not force and radio_chatter_cooldown > 0.0:
		return
	radio_chatter_cooldown = 28.0 # Generous 28-second breather between chatter events
	if is_instance_valid(radio_chatter_tween) and radio_chatter_tween.is_valid():
		radio_chatter_tween.kill()

	if is_instance_valid(hud_radio_speaker_label):
		hud_radio_speaker_label.text = "[" + speaker + "]"
		hud_radio_speaker_label.add_theme_color_override("font_color", color)
	if is_instance_valid(hud_radio_text_label):
		hud_radio_text_label.text = text

	hud_radio_chatter.modulate = Color(1, 1, 1, 1)
	hud_radio_chatter.visible = true

	if is_instance_valid(radio_chatter_player) and stream_radio_chatter:
		radio_chatter_player.pitch_scale = randf_range(0.98, 1.02)
		radio_chatter_player.play()

	radio_chatter_tween = create_tween()
	radio_chatter_tween.tween_interval(3.8)
	radio_chatter_tween.tween_property(hud_radio_chatter, "modulate:a", 0.0, 0.4)
	radio_chatter_tween.tween_callback(func():
		if is_instance_valid(hud_radio_chatter):
			hud_radio_chatter.visible = false
	)

# ==============================================================================
# RAIN PUDDLE GENERATOR (GLOSSY REFLECTIVE DISCS)
# ==============================================================================
func _spawn_chunk_puddles(chunk: Node3D, start_z: float) -> void:
	if not puddle_mat:
		puddle_mat = StandardMaterial3D.new()
		puddle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puddle_mat.albedo_color = Color(0.12, 0.18, 0.28, 0.85)
		puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var puddle_lanes := [-5.5, -2.5, 2.5, 5.5]
	for _i in range(3):
		var p_z: float = start_z - randf_range(20.0, 100.0)
		var p_x: float = puddle_lanes.pick_random() + randf_range(-0.35, 0.35)

		var pud := PuddleData.new()
		pud.global_z = p_z
		pud.global_x = p_x

		var p_mesh := QuadMesh.new()
		p_mesh.size = Vector2(2.6, 4.2)
		p_mesh.orientation = PlaneMesh.FACE_Y

		var p_inst := MeshInstance3D.new()
		p_inst.mesh = p_mesh
		p_inst.material_override = puddle_mat
		p_inst.position = Vector3(p_x, 0.03, p_z - start_z)
		chunk.add_child(p_inst)
		pud.node = p_inst
		active_puddles.append(pud)

# ==============================================================================
# JAPANESE DEKOTORA ART TRUCK DECORATION
# ==============================================================================
func _decorate_dekotora_truck(v_root: Node3D, td: TrafficVehicleData) -> void:
	td.is_dekotora = true
	var deco_root := Node3D.new()
	deco_root.name = "DekotoraDeco"
	v_root.add_child(deco_root)

	var bumper_box := BoxMesh.new()
	bumper_box.size = Vector3(2.6, 0.5, 0.7)
	var chrome_mat := StandardMaterial3D.new()
	chrome_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chrome_mat.albedo_color = Color("#E4E8EE")
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = bumper_box
	b_inst.material_override = chrome_mat
	b_inst.position = Vector3(0.0, 0.35, -2.35)
	deco_root.add_child(b_inst)

	for lx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var led_box := BoxMesh.new()
		led_box.size = Vector3(0.18, 0.12, 0.08)
		var led_mat := StandardMaterial3D.new()
		led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led_mat.albedo_color = Color("#FFB703")
		var led_inst := MeshInstance3D.new()
		led_inst.mesh = led_box
		led_inst.material_override = led_mat
		led_inst.position = Vector3(lx, 0.35, -2.71)
		deco_root.add_child(led_inst)

	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(2.4, 0.15, 0.9)
	var v_inst := MeshInstance3D.new()
	v_inst.mesh = visor_box
	v_inst.material_override = chrome_mat
	v_inst.position = Vector3(0.0, 2.45, -1.25)
	v_inst.rotation_degrees.x = -12.0
	deco_root.add_child(v_inst)

	for vx in [-0.9, -0.6, -0.3, 0.0, 0.3, 0.6, 0.9]:
		var v_led := BoxMesh.new()
		v_led.size = Vector3(0.14, 0.10, 0.06)
		var vl_mat := StandardMaterial3D.new()
		vl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vl_mat.albedo_color = Color("#00FF88") if (int(abs(vx * 10.0)) % 2 == 0) else Color("#FFB703")
		var vl_inst := MeshInstance3D.new()
		vl_inst.mesh = v_led
		vl_inst.material_override = vl_mat
		vl_inst.position = Vector3(vx, 2.50, -1.68)
		deco_root.add_child(vl_inst)

	var art_l := Label3D.new()
	art_l.text = "⚡ 天下御意見無用 ⚡\n[DAIKOKU MARU]"
	art_l.font_size = 38
	art_l.modulate = Color("#FFE500")
	art_l.outline_modulate = Color("#D90429")
	art_l.outline_size = 14
	art_l.position = Vector3(-1.32, 1.45, 0.45)
	art_l.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	deco_root.add_child(art_l)

	var art_r := Label3D.new()
	art_r.text = "⚡ 爆走一番星 ⚡\n[HIGHWAY EXPRESS]"
	art_r.font_size = 38
	art_r.modulate = Color("#FFE500")
	art_r.outline_modulate = Color("#D90429")
	art_r.outline_size = 14
	art_r.position = Vector3(1.32, 1.45, 0.45)
	art_r.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	deco_root.add_child(art_r)

	for sx in [-1.15, 1.15]:
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.08
		pipe_mesh.bottom_radius = 0.08
		pipe_mesh.height = 2.4
		var pipe_inst := MeshInstance3D.new()
		pipe_inst.mesh = pipe_mesh
		pipe_inst.material_override = chrome_mat
		pipe_inst.position = Vector3(sx, 1.6, -0.65)
		deco_root.add_child(pipe_inst)

# ==============================================================================
# 6. PLAYER VEHICLE RIG (HERO WHITE MUSCLE CAR + CONTACT SHADOW + TIRE SMOKE)
# ==============================================================================
func _setup_player_car() -> void:
	car_root = Node3D.new()
	car_root.name = "PlayerCar"
	add_child(car_root)

	visual_rig = Node3D.new()
	visual_rig.name = "VisualRig"
	car_root.add_child(visual_rig)

	# Ground contact drop shadow decal (Firmly grounds the car to the road)
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(2.1, 4.5)
	shadow_mesh.orientation = PlaneMesh.FACE_Y
	player_shadow = MeshInstance3D.new()
	player_shadow.name = "ContactShadow"
	player_shadow.mesh = shadow_mesh
	player_shadow.material_override = contact_shadow_mat
	player_shadow.position.y = 0.03
	player_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car_root.add_child(player_shadow)

	# Cel-Shaded Comic Drift Smoke Emitters
	smoke_left = _create_tire_smoke_emitter(Vector3(-0.72, 0.12, 1.25))
	smoke_right = _create_tire_smoke_emitter(Vector3(0.72, 0.12, 1.25))
	car_root.add_child(smoke_left)
	car_root.add_child(smoke_right)

	# Dynamic Warm Point Light for Tunnel Backfires
	tunnel_backfire_light = OmniLight3D.new()
	tunnel_backfire_light.name = "TunnelBackfireLight"
	tunnel_backfire_light.light_color = Color("#FF9922")
	tunnel_backfire_light.light_energy = 0.0
	tunnel_backfire_light.omni_range = 14.0
	tunnel_backfire_light.omni_attenuation = 1.2
	tunnel_backfire_light.position = Vector3(0.0, 0.4, 2.2)
	car_root.add_child(tunnel_backfire_light)

	# Hero White Muscle Car
	var car_path: String = "res://assets/vehicles/traffic/muscle.fbx"
	if ResourceLoader.exists(car_path):
		var racer_scn: PackedScene = load(car_path)
		if racer_scn:
			var model_inst := racer_scn.instantiate() as Node3D
			model_inst.name = "PlayerMesh"
			model_inst.scale = Vector3(0.72, 0.72, 0.72)
			model_inst.rotation_degrees = Vector3(0, 180, 0) # Rear faces camera (+Z), front points down road (-Z)
			visual_rig.add_child(model_inst)

			# 1. Base Body Material: Solid-State Comic Ink Shader
			var ink_mat := ShaderMaterial.new()
			ink_mat.shader = preload("res://shaders/comic_ink_car.gdshader")
			ink_mat.set_shader_parameter("paper_white", Color("#EAE6DF"))
			ink_mat.set_shader_parameter("slate_grey", Color("#6E7485"))
			ink_mat.set_shader_parameter("stripe_blue", Color("#0057E0"))
			ink_mat.set_shader_parameter("navy_diffuser", Color("#1F3861"))
			ink_mat.set_shader_parameter("ink_black", Color("#0A0914"))
			ink_mat.set_shader_parameter("shadow_tint", Color("#1E202B"))
			ink_mat.set_shader_parameter("shadow_cut", 0.32)
			ink_mat.set_shader_parameter("is_two_tone", true)
			ink_mat.set_shader_parameter("has_stripes", true)
			if is_instance_valid(sun_light):
				ink_mat.set_shader_parameter("sun_direction", -sun_light.global_transform.basis.z)
			hero_body_shader_mat = ink_mat

			# 2. Taillights: Pure saturated crimson #FF0828, Unshaded per mandate
			var taillight_mat := StandardMaterial3D.new()
			taillight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			taillight_mat.albedo_color = Color("#FF0828")
			taillight_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			# 3. Tinted Comic Glass
			var window_mat: Material = _get_comic_ink_mat(Color(0.08, 0.10, 0.14))

			# 4. Wheels
			var wheel_tire_mat: Material = _get_comic_ink_mat(Color(0.12, 0.12, 0.14))
			var wheel_rim_mat: Material = _get_comic_ink_mat(Color(0.85, 0.85, 0.88))

			_apply_decal_car_materials(model_inst, ink_mat, taillight_mat, window_mat, wheel_tire_mat, wheel_rim_mat)

			# Apply MaterialFailsafe to protect taillights & glass, while applying comic ink to body
			var sun_fwd := -sun_light.global_transform.basis.z if is_instance_valid(sun_light) else Vector3(-0.5, -0.8, -0.3)
			hero_body_shader_mat = MaterialFailsafe.apply_vehicle_materials(model_inst, "muscle", Color("#EAE6DF"), sun_fwd, true)

			# 3D Auto Modellista GT Racing Wing (Trunk Elevated GT Spoiler)
			var gt_wing := _create_gt_racing_wing()
			visual_rig.add_child(gt_wing)

			# 5. Project Manga Streaks & Livery via Decal (Bypasses Missing UVs)
			var livery_tex: ImageTexture = generate_decal_livery_texture()

			var decal := Decal.new()
			decal.name = "MangaLiveryDecal"
			decal.size = Vector3(2.4, 2.2, 4.6)
			decal.position = Vector3(0.0, 0.7, 0.0)
			decal.cull_mask = 2
			decal.texture_albedo = livery_tex
			decal.visible = false # Procedural solid-state shader renders crisp inky stripes across hood, roof, trunk & spoiler
			visual_rig.add_child(decal)

			player_wheels.clear()
			_collect_wheels(model_inst, player_wheels)

			# 3. TAILLIGHT SPEED TRAILS: Ethereal, additive transparent glowing ribbons behind rear taillights
			var trail_sh: Shader = load("res://shaders/taillight_trail.gdshader")
			var trail_mat := ShaderMaterial.new()
			trail_mat.shader = trail_sh
			trail_mat.set_shader_parameter("trail_color", Color(1.0, 0.02, 0.13, 0.85))

			trail_mesh_l = PlaneMesh.new()
			trail_mesh_l.size = Vector2(0.28, 0.001)
			trail_mesh_l.orientation = PlaneMesh.FACE_Y
			trail_left = MeshInstance3D.new()
			trail_left.name = "SpeedTrailL"
			trail_left.mesh = trail_mesh_l
			trail_left.material_override = trail_mat
			trail_left.position = Vector3(-0.52, 0.58, 1.55)
			trail_left.rotation_degrees = Vector3(18.5, 0.0, 0.0)
			trail_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trail_left.visible = false
			visual_rig.add_child(trail_left)

			trail_mesh_r = PlaneMesh.new()
			trail_mesh_r.size = Vector2(0.28, 0.001)
			trail_mesh_r.orientation = PlaneMesh.FACE_Y
			trail_right = MeshInstance3D.new()
			trail_right.name = "SpeedTrailR"
			trail_right.mesh = trail_mesh_r
			trail_right.material_override = trail_mat
			trail_right.position = Vector3(0.52, 0.58, 1.55)
			trail_right.rotation_degrees = Vector3(18.5, 0.0, 0.0)
			trail_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trail_right.visible = false
			visual_rig.add_child(trail_right)

			# 4. SPOILER WINGTIP VORTICES (Aerodynamic Vapor Needles)
			# Unshaded Manga White (#FFFFFF, alpha = 0.85) with 1px solid black ink edge (#080808)
			if not wingtip_vortex_shader:
				wingtip_vortex_shader = load("res://shaders/wingtip_vortex.gdshader")
			if not wingtip_vortex_mat:
				wingtip_vortex_mat = ShaderMaterial.new()
				wingtip_vortex_mat.shader = wingtip_vortex_shader

			# Geometry: Sharp needle ribbons (width at wing: 0.04m, tapering to 0.0m at tail tip; length = 3.2m trailing strictly along heading)
			var streak_mesh: ArrayMesh = _create_needle_ribbon_mesh(3.2, 0.04)

			spoiler_streak_l = MeshInstance3D.new()
			spoiler_streak_l.name = "SpoilerStreakL"
			spoiler_streak_l.mesh = streak_mesh
			spoiler_streak_l.material_override = wingtip_vortex_mat
			spoiler_streak_l.position = Vector3(-0.84, 1.05, 1.82)
			spoiler_streak_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spoiler_streak_l.visible = false
			visual_rig.add_child(spoiler_streak_l)

			spoiler_streak_r = MeshInstance3D.new()
			spoiler_streak_r.name = "SpoilerStreakR"
			spoiler_streak_r.mesh = streak_mesh
			spoiler_streak_r.material_override = wingtip_vortex_mat
			spoiler_streak_r.position = Vector3(0.84, 1.05, 1.82)
			spoiler_streak_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spoiler_streak_r.visible = false
			visual_rig.add_child(spoiler_streak_r)

	# 5. Twin Conical Flame Meshes for Exhaust Backfires & Gear-Shift Pops
	if not toon_flame_shader:
		toon_flame_shader = load("res://shaders/stepped_toon_flame.gdshader")
	if not toon_flame_mat:
		toon_flame_mat = ShaderMaterial.new()
		toon_flame_mat.shader = toon_flame_shader
	if not nitro_flame_mat and toon_flame_shader:
		nitro_flame_mat = ShaderMaterial.new()
		nitro_flame_mat.shader = toon_flame_shader
		nitro_flame_mat.set_shader_parameter("core_color", Color(1.0, 1.0, 1.0, 1.0))
		nitro_flame_mat.set_shader_parameter("mid_color", Color("#00E5FF"))
		nitro_flame_mat.set_shader_parameter("rim_color", Color(0.0, 0.4, 1.0, 1.0))

	var flame_cyl := CylinderMesh.new()
	flame_cyl.top_radius = 0.0     # Pointed cone tip
	flame_cyl.bottom_radius = 0.09 # Exhaust pipe base
	flame_cyl.height = 0.55
	flame_cyl.radial_segments = 12

	exhaust_flame_l = MeshInstance3D.new()
	exhaust_flame_l.mesh = flame_cyl
	exhaust_flame_l.material_override = toon_flame_mat
	exhaust_flame_l.position = Vector3(-0.42, 0.28, 2.05)
	exhaust_flame_l.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	exhaust_flame_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	exhaust_flame_l.visible = false
	car_root.add_child(exhaust_flame_l)

	exhaust_flame_r = MeshInstance3D.new()
	exhaust_flame_r.mesh = flame_cyl
	exhaust_flame_r.material_override = toon_flame_mat
	exhaust_flame_r.position = Vector3(0.42, 0.28, 2.05)
	exhaust_flame_r.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	exhaust_flame_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	exhaust_flame_r.visible = false
	car_root.add_child(exhaust_flame_r)

	exhaust_bumper_flash = OmniLight3D.new()
	exhaust_bumper_flash.light_color = Color("#FF9500")
	exhaust_bumper_flash.light_energy = 5.0
	exhaust_bumper_flash.omni_range = 3.5
	exhaust_bumper_flash.position = Vector3(0.0, 0.35, 2.15)
	exhaust_bumper_flash.visible = false
	car_root.add_child(exhaust_bumper_flash)

	# 6. Twin Detailed Exhaust Tip Mounts (Visible Jiggle during Idle, Rigid under Boost)
	var tip_cyl := CylinderMesh.new()
	tip_cyl.top_radius = 0.088
	tip_cyl.bottom_radius = 0.088
	tip_cyl.height = 0.22
	tip_cyl.radial_segments = 14

	var tip_mat := StandardMaterial3D.new()
	tip_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	tip_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	tip_mat.albedo_color = Color("#22242C") # Dark Burnished Steel
	tip_mat.metallic = 0.70
	tip_mat.roughness = 0.30

	exhaust_tip_l = MeshInstance3D.new()
	exhaust_tip_l.name = "ExhaustTipL"
	exhaust_tip_l.mesh = tip_cyl
	exhaust_tip_l.material_override = tip_mat
	exhaust_tip_l.position = Vector3(-0.42, 0.28, 1.95)
	exhaust_tip_l.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	visual_rig.add_child(exhaust_tip_l)

	exhaust_tip_r = MeshInstance3D.new()
	exhaust_tip_r.name = "ExhaustTipR"
	exhaust_tip_r.mesh = tip_cyl
	exhaust_tip_r.material_override = tip_mat
	exhaust_tip_r.position = Vector3(0.42, 0.28, 1.95)
	exhaust_tip_r.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	visual_rig.add_child(exhaust_tip_r)

	# 7. Authentic Xenon Forward Headlight SpotLight3D Beam
	hero_headlight_l = SpotLight3D.new()
	hero_headlight_l.name = "HeadlightSpotL"
	hero_headlight_l.light_color = Color("#FFF6E0")
	hero_headlight_l.light_energy = 0.0
	hero_headlight_l.spot_range = 42.0
	hero_headlight_l.spot_angle = 36.0
	hero_headlight_l.spot_attenuation = 1.2
	hero_headlight_l.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	hero_headlight_l.position = Vector3(0.0, 0.52, -1.90)
	hero_headlight_l.shadow_enabled = false
	hero_headlight_l.visible = false
	visual_rig.add_child(hero_headlight_l)

	_reset_race()

func generate_decal_livery_texture() -> ImageTexture:
	var width := 512
	var height := 512
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0)) # Transparent background

	# 1. Two bold Royal Blue racing stripes down the center (#0047AB) - hood and roof only, stops before rear taillights
	var stripe_w: int = 36
	var half_gap: int = 11
	var center: int = int(width * 0.5)
	for y in range(0, 360): # Stops at 360 (does not spill over rear taillight fascia)
		# Left stripe
		for x in range(center - half_gap - stripe_w, center - half_gap):
			img.set_pixel(x, y, Color("#0047AB"))
		# Right stripe
		for x in range(center + half_gap, center + half_gap + stripe_w):
			img.set_pixel(x, y, Color("#0047AB"))

	return ImageTexture.create_from_image(img)

func _create_gt_racing_wing() -> Node3D:
	var wing_root := Node3D.new()
	wing_root.name = "GTRacingWing"

	var spoiler_sh: Shader = load("res://shaders/comic_spoiler.gdshader")

	var white_mat := ShaderMaterial.new()
	white_mat.shader = spoiler_sh
	white_mat.set_shader_parameter("base_color", Color("#EAE6DF"))
	white_mat.set_shader_parameter("ink_shadow", Color(0.08, 0.08, 0.14, 1.0))
	white_mat.set_shader_parameter("shadow_cut", 0.38)
	white_mat.set_shader_parameter("hatch_base_spacing", 3.6)

	var blue_mat := ShaderMaterial.new()
	blue_mat.shader = spoiler_sh
	blue_mat.set_shader_parameter("base_color", Color("#0057E0"))
	blue_mat.set_shader_parameter("ink_shadow", Color(0.03, 0.06, 0.18, 1.0))
	blue_mat.set_shader_parameter("shadow_cut", 0.38)
	blue_mat.set_shader_parameter("hatch_base_spacing", 3.6)

	var ink_mat := ShaderMaterial.new()
	ink_mat.shader = spoiler_sh
	ink_mat.set_shader_parameter("base_color", Color("#0A0914"))
	ink_mat.set_shader_parameter("ink_shadow", Color(0.02, 0.02, 0.04, 1.0))

	var strut_mat := ShaderMaterial.new()
	strut_mat.shader = spoiler_sh
	strut_mat.set_shader_parameter("base_color", Color("#D4DAE6"))
	strut_mat.set_shader_parameter("ink_shadow", Color(0.08, 0.08, 0.14, 1.0))
	strut_mat.set_shader_parameter("shadow_cut", 0.38)

	spoiler_mats.clear()
	spoiler_mats.append(white_mat)
	spoiler_mats.append(blue_mat)
	spoiler_mats.append(ink_mat)
	spoiler_mats.append(strut_mat)

	var wing_y := 1.15
	var wing_z := 1.86
	var wing_rot := Vector3(8.0, 0.0, 0.0) # Downward rear slope exposes top surface & blue stripes to chase camera

	# 1. Main Wing Blade Sections (Matching dual Cobalt Blue racing stripes)
	# Center White Gap (X: -0.055 to +0.055)
	var blade_mid := MeshInstance3D.new()
	var bm_mid := BoxMesh.new()
	bm_mid.size = Vector3(0.11, 0.032, 0.28)
	blade_mid.mesh = bm_mid
	blade_mid.material_override = white_mat
	blade_mid.position = Vector3(0.0, wing_y, wing_z)
	blade_mid.rotation_degrees = wing_rot
	blade_mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wing_root.add_child(blade_mid)

	# Dual Cobalt Blue Stripes (Left: -0.22 to -0.055, Right: +0.055 to +0.22)
	for is_r in [false, true]:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.165, 0.033, 0.28)
		stripe.mesh = sm
		stripe.material_override = blue_mat
		stripe.position = Vector3(0.1375 if is_r else -0.1375, wing_y, wing_z)
		stripe.rotation_degrees = wing_rot
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing_root.add_child(stripe)

	# Outer White Wing Blade Sections (Left: -0.76 to -0.22, Right: +0.22 to +0.76)
	for is_r in [false, true]:
		var outer_blade := MeshInstance3D.new()
		var obm := BoxMesh.new()
		obm.size = Vector3(0.54, 0.032, 0.28)
		outer_blade.mesh = obm
		outer_blade.material_override = white_mat
		outer_blade.position = Vector3(0.49 if is_r else -0.49, wing_y, wing_z)
		outer_blade.rotation_degrees = wing_rot
		outer_blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing_root.add_child(outer_blade)

	# Pinstripe Ink Borders between stripes & outer blade
	for x_pos in [-0.22, -0.055, 0.055, 0.22]:
		var pin := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.008, 0.035, 0.282)
		pin.mesh = pm
		pin.material_override = ink_mat
		pin.position = Vector3(x_pos, wing_y, wing_z)
		pin.rotation_degrees = wing_rot
		pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing_root.add_child(pin)

	# 2. Dual Endplates (Auto Modellista styled winglets angled slightly outward)
	for is_r in [false, true]:
		var endplate := MeshInstance3D.new()
		endplate.name = "EndplateR" if is_r else "EndplateL"
		var epm := BoxMesh.new()
		epm.size = Vector3(0.024, 0.26, 0.34)
		endplate.mesh = epm
		endplate.material_override = ink_mat
		endplate.position = Vector3(0.78 if is_r else -0.78, wing_y + 0.02, wing_z)
		endplate.rotation_degrees = Vector3(8.0, 0.0, 10.0 if is_r else -10.0) # Angled outward
		endplate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing_root.add_child(endplate)

	# 3. Dual Stanchion Struts (Angled alloy silver brackets connecting trunk deck to wing)
	for is_r in [false, true]:
		var strut := MeshInstance3D.new()
		strut.name = "StrutR" if is_r else "StrutL"
		var sm := BoxMesh.new()
		sm.size = Vector3(0.028, 0.50, 0.045)
		strut.mesh = sm
		strut.material_override = strut_mat
		# Angled backwards from trunk (Z=1.62, Y=0.70) to wing blade (Z=1.86, Y=1.15)
		strut.position = Vector3(0.36 if is_r else -0.36, 0.92, 1.74)
		strut.rotation_degrees = Vector3(-26.0, 0.0, 0.0)
		strut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wing_root.add_child(strut)

	return wing_root

func _create_needle_ribbon_mesh(length: float = 3.2, base_w: float = 0.04) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = base_w * 0.5
	# Dual-plane intersecting cross needle (sharp 3.2m needle visible from all camera angles)
	# Horizontal blade
	st.set_color(Color(1.0, 1.0, 1.0, 0.85))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-hw, 0.0, 0.0))
	st.set_color(Color(1.0, 1.0, 1.0, 0.85))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(hw, 0.0, 0.0))
	st.set_color(Color(1.0, 1.0, 1.0, 0.0)) # Needle tip vanishes into air
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, 0.0, length))

	# Vertical blade
	st.set_color(Color(1.0, 1.0, 1.0, 0.85))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(0.0, -hw, 0.0))
	st.set_color(Color(1.0, 1.0, 1.0, 0.85))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(0.0, hw, 0.0))
	st.set_color(Color(1.0, 1.0, 1.0, 0.0))
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(Vector3(0.0, 0.0, length))

	for t in range(2):
		var base_idx: int = t * 3
		st.add_index(base_idx)
		st.add_index(base_idx + 1)
		st.add_index(base_idx + 2)
		st.add_index(base_idx)
		st.add_index(base_idx + 2)
		st.add_index(base_idx + 1)
	return st.commit()

func _get_expressway_sign_material() -> StandardMaterial3D:
	if gantry_sign_mat:
		return gantry_sign_mat

	var width := 512
	var height := 160
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)

	var green := Color("#006A3B") # Saturated Shuto Green
	var white := Color("#FFFFFF") # Crisp Manga White

	img.fill(green)

	# 1. Crisp Manga White Border (4px thick, inset 6px)
	_draw_img_rect(img, 6, 6, width - 12, 4, white)
	_draw_img_rect(img, 6, height - 10, width - 12, 4, white)
	_draw_img_rect(img, 6, 6, 4, height - 12, white)
	_draw_img_rect(img, width - 10, 6, 4, height - 12, white)

	# 2. Route Badge Shield Box on Left: [ C1 ]
	_draw_img_rect(img, 24, 22, 68, 48, white)
	_draw_img_rect(img, 27, 25, 62, 42, green)
	# Draw 'C'
	_draw_img_rect(img, 36, 32, 5, 28, white)
	_draw_img_rect(img, 36, 32, 18, 5, white)
	_draw_img_rect(img, 36, 55, 18, 5, white)
	# Draw '1'
	_draw_img_rect(img, 64, 32, 5, 28, white)
	_draw_img_rect(img, 58, 32, 8, 4, white)
	_draw_img_rect(img, 58, 56, 17, 4, white)

	# 3. Straight Ahead Expressway Arrow [ ↑ ]
	_draw_img_rect(img, 55, 86, 6, 48, white)
	for d in range(14):
		_draw_img_rect(img, 58 - d, 86 + d, d * 2, 2, white)

	# 4. Top Line Destination Block Lettering: "SHUTO EXP 首都高"
	var tx := 115
	var ty := 26
	# S
	_draw_img_rect(img, tx, ty, 15, 4, white)
	_draw_img_rect(img, tx, ty, 4, 12, white)
	_draw_img_rect(img, tx, ty + 10, 15, 4, white)
	_draw_img_rect(img, tx + 11, ty + 10, 4, 12, white)
	_draw_img_rect(img, tx, ty + 18, 15, 4, white)
	# H
	_draw_img_rect(img, tx + 20, ty, 4, 22, white)
	_draw_img_rect(img, tx + 20, ty + 9, 13, 4, white)
	_draw_img_rect(img, tx + 29, ty, 4, 22, white)
	# U
	_draw_img_rect(img, tx + 38, ty, 4, 22, white)
	_draw_img_rect(img, tx + 38, ty + 18, 13, 4, white)
	_draw_img_rect(img, tx + 47, ty, 4, 22, white)
	# T
	_draw_img_rect(img, tx + 55, ty, 15, 4, white)
	_draw_img_rect(img, tx + 61, ty, 4, 22, white)
	# O
	_draw_img_rect(img, tx + 74, ty, 4, 22, white)
	_draw_img_rect(img, tx + 74, ty, 14, 4, white)
	_draw_img_rect(img, tx + 84, ty, 4, 22, white)
	_draw_img_rect(img, tx + 74, ty + 18, 14, 4, white)

	# "EXP"
	var ex := tx + 102
	_draw_img_rect(img, ex, ty, 4, 22, white)
	_draw_img_rect(img, ex, ty, 13, 4, white)
	_draw_img_rect(img, ex, ty + 9, 10, 4, white)
	_draw_img_rect(img, ex, ty + 18, 13, 4, white)
	_draw_img_rect(img, ex + 18, ty, 4, 22, white)
	_draw_img_rect(img, ex + 18, ty, 13, 4, white)
	_draw_img_rect(img, ex + 18, ty + 10, 13, 4, white)
	_draw_img_rect(img, ex + 27, ty, 4, 12, white)

	# Japanese Kanji Graphic Blocks ("首都高")
	var kx := tx + 155
	for k in range(3):
		var kbx := kx + k * 28
		_draw_img_rect(img, kbx, ty, 20, 3, white)
		_draw_img_rect(img, kbx + 2, ty + 6, 16, 3, white)
		_draw_img_rect(img, kbx, ty + 12, 20, 3, white)
		_draw_img_rect(img, kbx + 4, ty + 3, 3, 16, white)
		_draw_img_rect(img, kbx + 13, ty + 3, 3, 16, white)
		_draw_img_rect(img, kbx + 1, ty + 19, 18, 3, white)

	# 5. Bottom Line: "HANEDA / YOKOHAMA 2.5km ↗"
	var by := 76
	var bx := 115
	for bar in range(6):
		var bbx: int = bx + bar * 42
		_draw_img_rect(img, bbx, by, 32, 4, white)
		_draw_img_rect(img, bbx, by + 12, 32, 3, white)
		_draw_img_rect(img, bbx, by + 24, 32, 4, white)
		_draw_img_rect(img, bbx + 3, by + 4, 4, 20, white)
		_draw_img_rect(img, bbx + 25, by + 4, 4, 20, white)

	# Distance tag: "2.5 km"
	var dx := 390
	_draw_img_rect(img, dx, by + 4, 18, 4, white)
	_draw_img_rect(img, dx + 14, by + 4, 4, 10, white)
	_draw_img_rect(img, dx, by + 12, 18, 4, white)
	_draw_img_rect(img, dx, by + 14, 4, 10, white)
	_draw_img_rect(img, dx, by + 22, 18, 4, white)

	# Right Exit Arrow [ ↗ ]
	var ax := 455
	var ay := 105
	for d in range(24):
		_draw_img_rect(img, ax - 12 + d, ay + 12 - d, 4, 4, white)
	for h in range(14):
		_draw_img_rect(img, ax + 12 - h, ay - 12, 3, 4, white)
		_draw_img_rect(img, ax + 10, ay - 12 + h, 4, 3, white)

	var tex := ImageTexture.create_from_image(img)
	gantry_sign_mat = StandardMaterial3D.new()
	gantry_sign_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	gantry_sign_mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	gantry_sign_mat.albedo_texture = tex
	gantry_sign_mat.roughness = 0.40
	return gantry_sign_mat

func _draw_img_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	var x_max: int = mini(rx + rw, img.get_width())
	var y_max: int = mini(ry + rh, img.get_height())
	for x in range(maxi(0, rx), x_max):
		for y in range(maxi(0, ry), y_max):
			img.set_pixel(x, y, col)

func _apply_decal_car_materials(node: Node, body_mat: Material, tail_mat: Material, win_mat: Material, tire_mat: Material, rim_mat: Material) -> void:
	for child in node.get_children():
		if child.name in ["TaillightMesh", "WindowMesh"]:
			continue

		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.material_override = null

			if "wheel" in mi.name.to_lower():
				mi.set_layer_mask_value(1, true)
				mi.set_layer_mask_value(2, false) # Exclude wheels from Decal
				mi.set_layer_mask_value(3, false)
				if mi.mesh and mi.mesh.get_surface_count() >= 2:
					mi.set_surface_override_material(0, tire_mat)
					mi.set_surface_override_material(1, rim_mat)
				else:
					mi.set_surface_override_material(0, tire_mat)
			else:
				# 3. PRESERVE TAILLIGHTS & WINDOWS (Stop Decal Bleed):
				# - Body shell MeshInstance3D visual layers: Layer 2 ONLY (bit 2)
				# - Red taillights & windows: Layer 1 ONLY (bit 1)
				# - Decal node: cull_mask = 2 (projects onto body shell ONLY)
				mi.set_layer_mask_value(1, false)
				mi.set_layer_mask_value(2, true)  # Layer 2 ONLY
				mi.set_layer_mask_value(3, false)

				if mi.mesh:
					var sc: int = mi.mesh.get_surface_count()
					for i in range(sc):
						mi.set_surface_override_material(i, body_mat)
					if sc > 4:
						# Surface 4: Cobalt Blue modeled racing stripes
						var sm: Material = _get_comic_ink_mat(Color("#0047AB"))
						mi.set_surface_override_material(4, sm)

					# Isolate Red Tail Lights and Windows onto Visual Layer 1 (cull_mask bit 1)
					if mi.mesh is ArrayMesh:
						var orig_mesh: ArrayMesh = mi.mesh as ArrayMesh
						# Extract surface 6 (Red Taillights) -> Visual Layer 1 ONLY
						if sc > 6:
							var tail_arr = orig_mesh.surface_get_arrays(6)
							if tail_arr.size() > 0 and tail_arr[ArrayMesh.ARRAY_VERTEX] != null:
								var tail_inst := MeshInstance3D.new()
								tail_inst.name = "TaillightMesh"
								var tail_mesh := ArrayMesh.new()
								tail_mesh.add_surface_from_arrays(orig_mesh.surface_get_primitive_type(6), tail_arr)
								tail_inst.mesh = tail_mesh
								if tail_mat is StandardMaterial3D:
									(tail_mat as StandardMaterial3D).depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
								tail_inst.material_override = tail_mat
								tail_inst.set_layer_mask_value(1, true)   # Visual Layer 1 ONLY
								tail_inst.set_layer_mask_value(2, false)  # STRICTLY EXCLUDED from Decal Layer 2
								tail_inst.set_layer_mask_value(3, false)
								tail_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
								mi.add_child(tail_inst)

								# Clear surface 6 on the body shell so decal cannot paint on it
								var clear_mat := StandardMaterial3D.new()
								clear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
								clear_mat.albedo_color = Color(0, 0, 0, 0)
								mi.set_surface_override_material(6, clear_mat)

						# Extract surface 2 (Tinted Comic Glass) -> Visual Layer 1 ONLY
						if sc > 2:
							var win_arr = orig_mesh.surface_get_arrays(2)
							if win_arr.size() > 0 and win_arr[ArrayMesh.ARRAY_VERTEX] != null:
								var win_inst := MeshInstance3D.new()
								win_inst.name = "WindowMesh"
								var win_mesh := ArrayMesh.new()
								win_mesh.add_surface_from_arrays(orig_mesh.surface_get_primitive_type(2), win_arr)
								win_inst.mesh = win_mesh
								win_inst.material_override = win_mat
								win_inst.set_layer_mask_value(1, true)   # Visual Layer 1 ONLY
								win_inst.set_layer_mask_value(2, false)  # STRICTLY EXCLUDED from Decal Layer 2
								win_inst.set_layer_mask_value(3, false)
								win_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
								mi.add_child(win_inst)

								# Clear surface 2 on the body shell so decal cannot paint on it
								var clear_mat_w := StandardMaterial3D.new()
								clear_mat_w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
								clear_mat_w.albedo_color = Color(0, 0, 0, 0)
								mi.set_surface_override_material(2, clear_mat_w)
					else:
						if sc > 6:
							mi.set_surface_override_material(6, tail_mat)
						if sc > 2:
							mi.set_surface_override_material(2, win_mat)
		if child.get_child_count() > 0:
			_apply_decal_car_materials(child, body_mat, tail_mat, win_mat, tire_mat, rim_mat)

func _collect_wheels(node: Node, wheel_array: Array[Node3D]) -> void:
	for child in node.get_children():
		if "wheel" in child.name.to_lower() and child is Node3D:
			wheel_array.append(child as Node3D)
		if child.get_child_count() > 0:
			_collect_wheels(child, wheel_array)

func _create_tire_smoke_emitter(offset: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = offset
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.material = smoke_cel_mat
	p.mesh = sm
	p.amount = 22
	p.lifetime = 0.65
	p.explosiveness = 0.06
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.18
	p.direction = Vector3(0.0, 0.55, 1.0)
	p.spread = 32.0
	p.gravity = Vector3(0.0, 1.8, 0.0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.8
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.6
	p.emitting = false
	p.visible = true
	return p

func _reset_race() -> void:
	for sd in skid_pool:
		sd.time_left = 0.0
		if is_instance_valid(sd.node):
			sd.node.visible = false
	last_skid_drop_z = 999999.0
	active_tunnel_intervals.clear()
	chunk_spawn_count = 0
	current_cam_roll = 0.0
	smoke_step_timer = 0.0
	backfire_timer = 0.0
	backfire_light_timer = 0.0
	prev_hud_gear = 1
	prev_speed_for_pop = CRUISE_SPEED
	if is_instance_valid(engine_audio_player):
		engine_audio_player.volume_db = -3.0
		engine_audio_player.pitch_scale = 0.85
		if not engine_audio_player.playing:
			engine_audio_player.play()
	if is_instance_valid(drift_audio_player):
		drift_audio_player.volume_db = -80.0
	if is_instance_valid(rally_music_player) and not rally_music_player.playing:
		rally_music_player.play()
	Engine.time_scale = 1.0
	crash_orbit_active = false
	tankobon_shown = false
	is_scraping_guardrail = false
	if is_instance_valid(smoke_left): smoke_left.emitting = false
	if is_instance_valid(smoke_right): smoke_right.emitting = false
	spark_spawn_timer = 0.0
	diffuser_spark_timer = 0.0
	for fc in active_flying_cones:
		if is_instance_valid(fc.node):
			fc.node.queue_free()
	active_flying_cones.clear()
	active_traffic_cones.clear()
	active_toll_plazas.clear()
	active_construction_zones.clear()
	for pud in active_puddles:
		if is_instance_valid(pud.node):
			pud.node.queue_free()
	active_puddles.clear()
	patrol_evasion_active = false
	patrol_evasion_timer = 0.0
	patrol_evaded_cars = 0
	patrol_cooldown = 8.0
	active_sodium_spots.clear()
	prev_player_z_joint = 0.0
	camera_pitch_kick = 0.0
	if is_instance_valid(hero_body_shader_mat):
		hero_body_shader_mat.set_shader_parameter("sodium_intensity", 0.0)
	if is_instance_valid(hud_tankobon_cover):
		hud_tankobon_cover.visible = false
	if is_instance_valid(cutin_container):
		cutin_container.visible = false

	for chunk in road_chunks:
		chunk.queue_free()
	road_chunks.clear()

	next_chunk_z = 0.0
	_setup_road_system()

	player_z = 0.0
	player_lane_x = 0.0
	player_lat_velocity = 0.0
	player_speed = CRUISE_SPEED
	player_target_speed = CRUISE_SPEED
	top_speed_achieved = CRUISE_SPEED
	spinout_angle = 0.0
	body_turn_yaw = 0.0
	current_state = GameState.RACING
	score = 0
	displayed_score = 0.0
	combo_multiplier = 1
	combo_timer = 0.0
	near_miss_count = 0

	var z_cursor: float = -75.0
	for i in range(traffic_pool.size()):
		var td: TrafficVehicleData = traffic_pool[i]
		td.current_z = z_cursor
		td.lane_offset = LANE_OFFSETS[i % LANE_OFFSETS.size()]
		td.grazed = false
		td.is_lane_switcher = (i % 4 == 1) # 25% designated lane switchers
		td.is_switching = false
		td.switch_progress = 0.0
		td.is_disrupted = false
		td.is_roadblock = false
		td.is_police = false
		td.roadblock_crashing = false
		td.roadblock_has_impacted = false
		td.disrupt_yaw = 0.0
		td.disrupt_slide_speed = 0.0
		td.disrupt_spin_rate = 0.0
		td.flinch_timer = 0.0
		td.flinch_swerve_offset = 0.0
		td.flinch_target_swerve = 0.0
		if is_instance_valid(td.taillight_mat):
			if td.taillight_mat is ShaderMaterial:
				td.taillight_mat.set_shader_parameter("emissive_energy", 0.5)
			elif td.taillight_mat is StandardMaterial3D:
				(td.taillight_mat as StandardMaterial3D).emission_energy_multiplier = 0.5
		td.speed = TRAFFIC_CONFIGS[td.model_type]["speed"]
		if is_instance_valid(td.mesh_root):
			td.mesh_root.rotation.z = 0.0
		_snap_traffic_to_road(td)
		z_cursor -= randf_range(45.0, 65.0)

	if is_instance_valid(hud_restart_banner):
		hud_restart_banner.visible = false
	if is_instance_valid(hud_crash_flash):
		hud_crash_flash.color.a = 0.0
	if is_instance_valid(hud_combo_container):
		hud_combo_container.visible = false
	if is_instance_valid(hud_combo_label):
		hud_combo_label.text = ""
	if is_instance_valid(hud_combo_bar):
		hud_combo_bar.visible = false

	rival_active = false
	rival_spawn_cooldown = 4.0
	rival_state = 0
	rival_timer = 0.0
	rival_grazed = false
	rival_passed_player = false
	rival_target_police.clear()
	if is_instance_valid(rival_root):
		rival_root.visible = false
	if is_instance_valid(hud_rival_alert):
		hud_rival_alert.visible = false
	if is_instance_valid(hud_hazard_banner):
		hud_hazard_banner.visible = false
	if is_instance_valid(hazard_tween) and hazard_tween.is_valid():
		hazard_tween.kill()
	if is_instance_valid(trail_left):
		trail_left.visible = false
		trail_right.visible = false
	if is_instance_valid(spoiler_streak_l):
		spoiler_streak_l.visible = false
		spoiler_streak_r.visible = false

	_update_car_transform()

	if is_instance_valid(follow_cam):
		var car_basis: Basis = car_root.global_transform.basis
		follow_cam.global_position = car_root.global_position + (car_basis.z * 4.6) + Vector3(0.0, 1.88, 0.0)
		var look_target: Vector3 = car_root.global_position - (car_basis.z * 24.0) + Vector3(0.0, 1.25, 0.0)
		follow_cam.look_at(look_target, Vector3.UP)
		follow_cam.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(10.0))

func _update_car_transform() -> void:
	var center_x: float = _sample_road_x(player_z)
	var right_vec: Vector3 = _sample_road_right(player_z)
	var tan_vec: Vector3 = _sample_road_tangent(player_z)
	var bank_rad: float = _sample_road_bank(player_z)

	var road_y: float = -sin(bank_rad) * player_lane_x + 0.02
	var world_pos := Vector3(center_x, road_y, player_z) + (right_vec * player_lane_x)
	var forward_basis := Basis.looking_at(tan_vec, Vector3.UP)
	var spin_basis := Basis(Vector3.UP, spinout_angle)
	var bank_basis := Basis(Vector3.FORWARD, bank_rad)
	var final_basis := (forward_basis * spin_basis * bank_basis).orthonormalized()

	if is_instance_valid(car_root):
		if car_root.is_inside_tree():
			car_root.global_transform = Transform3D(final_basis, world_pos)
		else:
			car_root.transform = Transform3D(final_basis, world_pos)

# ==============================================================================
# 7. TRAFFIC POOL (WITH CONTACT SHADOWS & PRECISE HALF-EXTENTS)
# ==============================================================================
func _setup_traffic_pool() -> void:
	var base_z: float = -60.0

	for i in range(TRAFFIC_POOL_SIZE):
		var v_type: String = TRAFFIC_SPAWN_ORDER[i % TRAFFIC_SPAWN_ORDER.size()]
		var cfg: Dictionary = TRAFFIC_CONFIGS[v_type]
		var td := TrafficVehicleData.new()
		td.model_type = v_type
		td.current_z = base_z - float(i) * 45.0
		td.lane_offset = LANE_OFFSETS[i % LANE_OFFSETS.size()]
		td.speed = cfg["speed"]
		td.half_w = cfg["half_w"]
		td.half_l = cfg["half_l"]
		td.bob_seed = randf() * 100.0
		td.is_lane_switcher = (i % 4 == 1)

		var v_root := AnimatableBody3D.new()
		v_root.name = "Traffic_" + str(i) + "_" + v_type
		v_root.sync_to_physics = false
		add_child(v_root)
		td.instance = v_root

		var col_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(td.half_w * 2.0, 1.4, td.half_l * 2.0)
		col_shape.shape = box_shape
		col_shape.position.y = 0.70
		v_root.add_child(col_shape)

		var s_mesh := QuadMesh.new()
		s_mesh.size = Vector2(td.half_w * 2.3, td.half_l * 2.1)
		s_mesh.orientation = PlaneMesh.FACE_Y
		var s_inst := MeshInstance3D.new()
		s_inst.name = "Shadow"
		s_inst.mesh = s_mesh
		s_inst.material_override = contact_shadow_mat
		s_inst.position.y = 0.02
		v_root.add_child(s_inst)
		td.shadow_mesh = s_inst

		if ResourceLoader.exists(cfg["path"]):
			var scn: PackedScene = load(cfg["path"])
			if scn:
				var m_inst := scn.instantiate() as Node3D
				m_inst.scale = Vector3(0.72, 0.72, 0.72)
				m_inst.rotation_degrees = Vector3(0, 180, 0)
				v_root.add_child(m_inst)
				td.mesh_root = m_inst
				var car_color: Color = MaterialFailsafe.TRAFFIC_PALETTE[i % MaterialFailsafe.TRAFFIC_PALETTE.size()]
				_apply_comic_materials_to_model(m_inst, v_type, car_color, td)
				td.wheels.clear()
				_collect_wheels(m_inst, td.wheels)
				if v_type == "dekotora":
					_decorate_dekotora_truck(v_root, td)

		traffic_pool.append(td)
		_snap_traffic_to_road(td)

func _snap_traffic_to_road(td: TrafficVehicleData) -> void:
	var z_val: float = td.current_z
	var center_x: float = _sample_road_x(z_val)
	var right_vec: Vector3 = _sample_road_right(z_val)
	var tan_vec: Vector3 = _sample_road_tangent(z_val)
	var bank_rad: float = _sample_road_bank(z_val)

	var effective_offset: float = td.lane_offset + td.flinch_swerve_offset
	var road_y: float = -sin(bank_rad) * effective_offset + 0.02
	var world_pos := Vector3(center_x, road_y, z_val) + (right_vec * effective_offset)
	var forward_basis := Basis.looking_at(tan_vec, Vector3.UP)
	var spin_basis := Basis(Vector3.UP, td.disrupt_yaw)
	var bank_basis := Basis(Vector3.FORWARD, bank_rad)
	var final_basis := (forward_basis * spin_basis * bank_basis).orthonormalized()

	if is_instance_valid(td.instance):
		if td.instance.is_inside_tree():
			td.instance.global_transform = Transform3D(final_basis, world_pos)
		else:
			td.instance.transform = Transform3D(final_basis, world_pos)

# ==============================================================================
# 7.5. AGGRESSIVE PURSUER / RIVAL CAR (BLACKED-OUT SPORTS COUPE)
# ==============================================================================
func _setup_rival_car() -> void:
	rival_root = AnimatableBody3D.new()
	rival_root.name = "RivalPursuer"
	rival_root.sync_to_physics = false
	rival_root.visible = false
	add_child(rival_root)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(RIVAL_HALF_W * 2.0, 1.4, RIVAL_HALF_L * 2.0)
	col_shape.shape = box_shape
	col_shape.position.y = 0.70
	rival_root.add_child(col_shape)

	var s_mesh := QuadMesh.new()
	s_mesh.size = Vector2(RIVAL_HALF_W * 2.3, RIVAL_HALF_L * 2.1)
	s_mesh.orientation = PlaneMesh.FACE_Y
	rival_shadow = MeshInstance3D.new()
	rival_shadow.name = "Shadow"
	rival_shadow.mesh = s_mesh
	rival_shadow.material_override = contact_shadow_mat
	rival_shadow.position.y = 0.02
	rival_root.add_child(rival_shadow)

	if ResourceLoader.exists("res://assets/vehicles/player/player_racer.fbx"):
		var scn: PackedScene = load("res://assets/vehicles/player/player_racer.fbx")
		if scn:
			var m_inst := scn.instantiate() as Node3D
			m_inst.scale = Vector3(0.72, 0.72, 0.72)
			m_inst.rotation_degrees = Vector3(0, 180, 0)
			rival_root.add_child(m_inst)
			rival_mesh_root = m_inst
			_apply_comic_materials_to_model(m_inst, "rival", Color(0.08, 0.08, 0.10))
			rival_wheels.clear()
			_collect_wheels(m_inst, rival_wheels)

func _process_rival_ai(delta: float) -> void:
	if current_state == GameState.CRASHED:
		return

	# Handle cooldown & spawning
	if not rival_active:
		rival_spawn_cooldown -= delta
		if rival_spawn_cooldown <= 0.0:
			_spawn_rival()
		return

	rival_timer += delta

	# 1. Advance along spline
	rival_z -= rival_speed * delta

	# Wheel spin
	var r_spin: float = (rival_speed / TIRE_RADIUS) * delta
	for w in rival_wheels:
		w.rotate_x(r_spin)

	# 2. State Machine
	match rival_state:
		0: # PASSING_PLAYER: Accelerates hard along outer flank past player into forward distance
			rival_speed = lerp(rival_speed, player_speed + 32.0, 6.0 * delta)
			rival_lane_x = move_toward(rival_lane_x, rival_spawn_side, 5.0 * delta)

			if rival_z < player_z and not rival_passed_player:
				rival_passed_player = true
				_trigger_radio_chatter("RIVAL // MIDNIGHT", "Out of my lane, rookie! You can't match this boost!", Color("#FF2A55"))
				screen_shake = max(screen_shake, 0.16)

			# Must reach AT LEAST 50m ahead of player before starting disruptions!
			# This gives the player plenty of distance and 1.5-2.5s of advance reaction time!
			if rival_z < player_z - 50.0:
				rival_state = 1 # DISRUPTING_TRAFFIC
				rival_disrupt_count = 0
				screen_shake = 0.20

		1: # DISRUPTING_TRAFFIC: Cruising 50-65m ahead of player and causing chaos in plain sight
			var target_lead_z: float = player_z - 54.0
			var speed_bias: float = (target_lead_z - rival_z) * 1.5
			rival_speed = lerp(rival_speed, player_speed + clamp(speed_bias, -2.0, 18.0), 4.0 * delta)

			# NATURAL ENCOUNTER CHECK:
			# Check if there are TWO police cars naturally cruising ahead on the highway
			var police_ahead: Array[TrafficVehicleData] = []
			for td in traffic_pool:
				if td.model_type in ["police", "police_interceptor"] and not td.is_roadblock and not td.roadblock_crashing:
					var dist_p: float = rival_z - td.current_z # Positive if ahead of rival
					if dist_p > 12.0 and dist_p < 95.0:
						police_ahead.append(td)

			if police_ahead.size() >= 2:
				# Sort by X so p1 is left and p2 is right
				police_ahead.sort_custom(func(a, b): return a.lane_offset < b.lane_offset)
				rival_target_police = [police_ahead[0], police_ahead[1]]
				rival_state = 2 # POLICE_ROADBLOCK_APPROACH
				rival_target_police[0].is_police = true
				rival_target_police[1].is_police = true
				_trigger_hazard_banner("🚨 POLICE PATROL INTERCEPTING AHEAD! 🚨")
			else:
				# No two police cars ahead naturally -> hunt regular civilian traffic
				var target_car: TrafficVehicleData = null
				for td in traffic_pool:
					if not td.is_disrupted and not td.is_roadblock and not td.roadblock_crashing and td.model_type != "police":
						var dist_ahead: float = rival_z - td.current_z
						if dist_ahead > 4.0 and dist_ahead < 35.0:
							target_car = td
							break

				if target_car:
					rival_lane_x = move_toward(rival_lane_x, target_car.lane_offset, 14.0 * delta)
					var dz_hit: float = abs(target_car.current_z - rival_z)
					var dx_hit: float = abs(target_car.lane_offset - rival_lane_x)
					if dz_hit < 2.8 and dx_hit < 1.4:
						# SIDESWIPE IMPACT! Civilian car spins out smoothly!
						target_car.is_disrupted = true
						var push_dir: float = sign(target_car.lane_offset - rival_lane_x)
						if push_dir == 0.0:
							push_dir = 1.0 if target_car.lane_offset < 0.0 else -1.0
						target_car.disrupt_slide_speed = push_dir * 11.0
						target_car.disrupt_spin_rate = push_dir * 6.5
						target_car.speed *= 0.65
						screen_shake = 0.25
						_spawn_floating_graze_badge(target_car.instance.global_position, 500)
						rival_disrupt_count += 1
						rival_lane_x -= push_dir * 2.4
				else:
					var weave_x: float = sin(Time.get_ticks_msec() * 0.0025) * 4.4
					rival_lane_x = lerp(rival_lane_x, weave_x, 3.0 * delta)

				# After disrupting civilian traffic or time limit, rival escapes into the horizon
				if rival_disrupt_count >= 2 or rival_timer > 9.0:
					rival_state = 3 # ESCAPING

		2: # POLICE_ROADBLOCK_APPROACH: Approaching natural police roadblock formation
			rival_speed = lerp(rival_speed, 56.0, 4.0 * delta)
			if rival_target_police.size() >= 2:
				var p1: TrafficVehicleData = rival_target_police[0]
				var p2: TrafficVehicleData = rival_target_police[1]
				var mid_x: float = (p1.lane_offset + p2.lane_offset) * 0.5
				var police_z: float = min(p1.current_z, p2.current_z)
				var gap_z: float = rival_z - police_z

				# Aim down center corridor toward the cruisers
				rival_lane_x = move_toward(rival_lane_x, mid_x, 10.0 * delta)

				# When rival gets within 32m, police begin closing the trap
				if gap_z > 6.0 and gap_z < 32.0:
					p1.roadblock_crashing = true
					p2.roadblock_crashing = true

				# At 6m before impact, rival swerves violently to outer shoulder!
				elif gap_z <= 6.0:
					var evade_shoulder: float = -7.2 if mid_x >= 0.0 else 7.2
					rival_lane_x = move_toward(rival_lane_x, evade_shoulder, 24.0 * delta)

					# Check if police cruisers collide with each other in center
					var p_dx: float = abs(p1.lane_offset - p2.lane_offset)
					if p_dx < 1.8 and not p1.roadblock_has_impacted:
						p1.roadblock_has_impacted = true
						p2.roadblock_has_impacted = true
						p1.is_roadblock = true
						p2.is_roadblock = true
						p1.disrupt_slide_speed = -2.4
						p2.disrupt_slide_speed = 2.4
						p1.disrupt_spin_rate = 3.8
						p2.disrupt_spin_rate = -3.8
						screen_shake = 0.65
						_trigger_hazard_banner("🚨💥 POLICE PILEUP ROADBLOCK! 💥🚨")

					# Once past the roadblock, rival speeds off into distance
					if rival_z < police_z - 8.0:
						rival_state = 3 # ESCAPING
			else:
				rival_state = 3 # ESCAPING

		3: # ESCAPING: Rival roars off into the far horizon fog
			rival_speed = lerp(rival_speed, 68.0, 3.0 * delta)
			if rival_z < player_z - 110.0:
				_despawn_rival()
				return

	# Direct Collision / Graze between Player and Rival (if player catches up)
	var dz_hero: float = abs(rival_z - player_z)
	var dx_hero: float = abs(rival_lane_x - player_lane_x)
	var fatal_w: float = (HERO_HALF_W - 0.12) + RIVAL_HALF_W
	var side_rub_w: float = HERO_HALF_W + RIVAL_HALF_W
	var crash_l: float = HERO_HALF_L + RIVAL_HALF_L

	# Dynamic Manga Comic Cut-In when Rival passes within 6m
	if dz_hero < 6.0 and rival_active and not cutin_active and cutin_cooldown <= 0.0:
		_trigger_manga_cutin("⚡ RIVAL INTERCEPTOR!")

	if dz_hero < crash_l and dx_hero < side_rub_w:
		if dx_hero >= fatal_w:
			var side_r: float = sign(player_lane_x - rival_lane_x)
			if side_r == 0.0: side_r = 1.0
			player_lat_velocity = side_r * 4.0
			player_lane_x += side_r * 0.08
			screen_shake = max(screen_shake, 0.18)
			_emit_guardrail_sparks(side_r, delta)
			_play_scrape_sound()
		else:
			_trigger_crash(null, "WRECKED BY RIVAL!")
			return
	elif not rival_grazed and dz_hero < (crash_l + 0.60) and dx_hero < (side_rub_w + 0.60):
		rival_grazed = true
		near_miss_count += 1
		combo_multiplier = mini(combo_multiplier + 1, 4)
		combo_timer = 2.5
		var pts: int = 500 * combo_multiplier
		score += pts
		hud_combo_label.text = "RIVAL GRAZE! x" + str(combo_multiplier)
		hud_combo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_trigger_graze_microfreeze()
		_spawn_floating_graze_badge(rival_root.global_position, pts)

		# High-reward graze payoffs
		var graze_boost_r: float = 50.0 if drift_active else 30.0
		nitro_charge = min(100.0, nitro_charge + graze_boost_r)
		drift_charge = min(100.0, drift_charge + graze_boost_r)
		graze_speed_kick_timer = 0.4
		player_speed += player_speed * 0.04
		cam_fov_punch = 2.0
		cam_fov_punch_timer = 0.15
		_play_graze_chime()
		var g_text: String = "DRIFT GRAZE! +50%" if drift_active else "GRAZE! +30% BOOST"
		_spawn_floating_comic_text(rival_root.global_position + Vector3(0.0, 2.0, 0.0), g_text, Color("#FFF01F"), Color("#000000"), 36)

	_snap_rival_to_road()

func _spawn_rival() -> void:
	rival_active = true
	rival_state = 0 # PASSING_PLAYER
	# Appear from far left (-7.2) or far right (+7.2) outer flank
	rival_spawn_side = -7.2 if randf() < 0.5 else 7.2
	rival_lane_x = rival_spawn_side
	rival_z = player_z + 10.0 # Enters from side periphery behind player
	rival_speed = player_speed + 12.0 # Fast initial surge
	rival_timer = 0.0
	rival_disrupt_count = 0
	rival_grazed = false
	rival_passed_player = false
	rival_target_police.clear()
	if is_instance_valid(rival_root):
		rival_root.visible = true
	if is_instance_valid(rival_mesh_root):
		rival_mesh_root.rotation = Vector3(0, deg_to_rad(180), 0)
	_snap_rival_to_road()

	if is_instance_valid(rival_entry_player) and stream_rival_entry:
		rival_entry_player.pitch_scale = randf_range(0.98, 1.02)
		rival_entry_player.play()

	_trigger_hazard_banner("⚠️ RIVAL DISRUPTOR ZOOMING IN FROM FLANK! ⚠️")

func _trigger_hazard_banner(alert_text: String) -> void:
	if not is_instance_valid(hud_hazard_banner) or not is_instance_valid(hud_hazard_label):
		return
	if is_instance_valid(hazard_tween) and hazard_tween.is_valid():
		hazard_tween.kill()
	hud_hazard_label.text = alert_text
	hud_hazard_banner.visible = true
	hud_hazard_banner.scale = Vector2(1.10, 1.10)
	hud_hazard_banner.modulate = Color(1.35, 1.35, 1.15, 1.0)
	hazard_tween = create_tween()
	hazard_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hazard_tween.tween_property(hud_hazard_banner, "scale", Vector2(1.0, 1.0), 0.25)
	hazard_tween.parallel().tween_property(hud_hazard_banner, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.20)
	hazard_tween.tween_interval(3.5)
	hazard_tween.tween_callback(func(): hud_hazard_banner.visible = false)

func _despawn_rival() -> void:
	rival_active = false
	rival_spawn_cooldown = randf_range(25.0, 38.0)
	rival_target_police.clear()
	if is_instance_valid(rival_root):
		rival_root.visible = false

func _snap_rival_to_road() -> void:
	if not is_instance_valid(rival_root):
		return
	var center_x: float = _sample_road_x(rival_z)
	var right_vec: Vector3 = _sample_road_right(rival_z)
	var tan_vec: Vector3 = _sample_road_tangent(rival_z)
	var bank_rad: float = _sample_road_bank(rival_z)

	var road_y: float = -sin(bank_rad) * rival_lane_x + 0.02
	var world_pos := Vector3(center_x, road_y, rival_z) + (right_vec * rival_lane_x)
	var forward_basis := Basis.looking_at(tan_vec, Vector3.UP)
	var bank_basis := Basis(Vector3.FORWARD, bank_rad)
	var final_basis := (forward_basis * bank_basis).orthonormalized()

	if is_instance_valid(rival_root):
		if rival_root.is_inside_tree():
			rival_root.global_transform = Transform3D(final_basis, world_pos)
		else:
			rival_root.transform = Transform3D(final_basis, world_pos)

# ==============================================================================
# 8. LOW AGGRESSIVE ANIME CAMERA (AUTO MODELLISTA PERSPECTIVE)
# ==============================================================================
func _setup_camera() -> void:
	follow_cam = Camera3D.new()
	follow_cam.fov = 68.0
	follow_cam.near = 0.8
	follow_cam.far = 3800.0
	follow_cam.current = true
	add_child(follow_cam)
	if is_instance_valid(horizon_manager):
		horizon_manager.player_camera = follow_cam

func _update_camera(delta: float) -> void:
	if current_state == GameState.CRASHED and crash_orbit_active:
		var orbit_rad: float = deg_to_rad(crash_orbit_angle)
		var orbit_dist: float = 4.8
		var orbit_offset := Vector3(sin(orbit_rad) * orbit_dist, 1.75, cos(orbit_rad) * orbit_dist)
		follow_cam.global_position = car_root.global_position + orbit_offset
		follow_cam.look_at(car_root.global_position + Vector3(0.0, 0.75, 0.0), Vector3.UP)
		if is_instance_valid(background_rig):
			background_rig.global_position.z = follow_cam.global_position.z
			background_rig.global_position.x = _sample_road_x(follow_cam.global_position.z)
		return

	var car_basis: Basis = car_root.global_transform.basis

	# Dynamic Staging: Smoothly lerp camera distance from 4.2m at 80 km/h to 5.3m at 200 km/h
	var speed_kmh: float = player_speed * 3.6
	var speed_t: float = clamp((speed_kmh - 80.0) / (200.0 - 80.0), 0.0, 1.0)
	var cam_dist: float = lerp(4.2, 5.3, speed_t)

	# Pitch/Height Adjustment: Elevated camera Y-position so traffic ahead is clearly visible over the roof
	var cam_height: float = 1.88 - (speed_t * 0.18)
	var cam_pos: Vector3 = car_root.global_position + (car_basis.z * cam_dist) + Vector3(0.0, cam_height, 0.0)

	# Dynamic lateral shift on drift
	if drift_active:
		cam_pos += car_basis.x * (steer_input * 0.40)

	if screen_shake > 0.0:
		screen_shake = lerp(screen_shake, 0.0, 10.0 * delta)
		if screen_shake < 0.005:
			screen_shake = 0.0
		var shake_mag: float = screen_shake * 0.05
		cam_pos += Vector3(randf_range(-shake_mag, shake_mag), randf_range(-shake_mag, shake_mag), 0.0)

	# High-frequency camera micro-vibration during guardrail scraping
	if is_scraping_guardrail:
		cam_pos += Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0.0)

	follow_cam.global_position = follow_cam.global_position.lerp(cam_pos, 16.0 * delta)

	# Synchronous Background Rig anchoring (Zero frame phase jitter with camera; tracks road curvature without lateral steering twitch)
	if is_instance_valid(background_rig):
		background_rig.global_position.z = follow_cam.global_position.z
		background_rig.global_position.x = _sample_road_x(follow_cam.global_position.z)
		background_rig.global_position.y = 0.0

	var look_target: Vector3 = car_root.global_position - (car_basis.z * 24.0) + Vector3(0.0, 1.25, 0.0)
	follow_cam.look_at(look_target, Vector3.UP)
	follow_cam.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(10.0))

	# Expansion Joint camera pitch kick (micro-kick downward springs back to horizon)
	camera_pitch_kick = lerp(camera_pitch_kick, 0.0, 24.0 * delta)
	if abs(camera_pitch_kick) > 0.0005:
		follow_cam.rotate_object_local(Vector3(1, 0, 0), camera_pitch_kick)

	# Roll Offset: Smoothly lerp camera roll (local Z-rotation) by -4.0 degrees into the direction of a drift
	var target_roll: float = 0.0
	if drift_active:
		var drift_dir: float = sign(player_lat_velocity) if abs(player_lat_velocity) > 0.2 else sign(steer_input)
		if drift_dir == 0.0: drift_dir = 1.0
		target_roll = -drift_dir * deg_to_rad(4.0)
	current_cam_roll = lerp(current_cam_roll, target_roll, 8.0 * delta)
	if abs(current_cam_roll) > 0.0005:
		follow_cam.rotate_object_local(Vector3(0, 0, 1), current_cam_roll)

	# Dynamic FOV: Smoothly lerp Camera3D FOV between 68° (cruise) and 74° (drift active) using delta * 8.0
	var target_fov: float = 68.0
	if drift_active:
		target_fov = 74.0
	elif boost_active:
		target_fov = 76.0

	# Punch camera FOV on graze kicks and nitro surges
	if cam_fov_punch_timer > 0.0:
		cam_fov_punch_timer -= delta
		if cam_fov_punch_timer <= 0.0:
			cam_fov_punch = 0.0
	target_fov += cam_fov_punch

	follow_cam.fov = lerp(follow_cam.fov, target_fov, 8.0 * delta)

# ==============================================================================
# 9. COMIC HUD & MANGA SPEEDLINES
# ==============================================================================
func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(control)

	hud_crash_flash = ColorRect.new()
	hud_crash_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_crash_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	hud_crash_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(hud_crash_flash)

	# Screen-space Comic Rain Overlay (Anime Monsoon)
	hud_rain_overlay = ColorRect.new()
	hud_rain_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_rain_overlay.material = rain_mat
	hud_rain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_rain_overlay.visible = false
	control.add_child(hud_rain_overlay)

	# Screen-space Comic Snow Overlay (Anime Snowstorm)
	hud_snow_overlay = ColorRect.new()
	hud_snow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_snow_overlay.material = snow_overlay_mat
	hud_snow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_snow_overlay.visible = false
	control.add_child(hud_snow_overlay)

	# Screen-Edge Comic Speed Needles (Strictly Outer 15% Edges, Center 70% Clear)
	hud_speedlines = ColorRect.new()
	hud_speedlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_speedlines.color = Color(0.0, 0.0, 0.0, 0.0)
	hud_speedlines.material = speedlines_mat
	hud_speedlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_speedlines.visible = false
	control.add_child(hud_speedlines)

	# Day/Night Time-Of-Day HUD Button
	hud_tod_toggle_btn = Button.new()
	hud_tod_toggle_btn.text = "☀️ AUTO"
	hud_tod_toggle_btn.position = Vector2(870, 48)
	hud_tod_toggle_btn.size = Vector2(170, 42)
	hud_tod_toggle_btn.add_theme_font_size_override("font_size", 16)
	hud_tod_toggle_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	hud_tod_toggle_btn.pressed.connect(_on_tod_btn_pressed)
	control.add_child(hud_tod_toggle_btn)

	# Dynamic Manga Comic Cut-In Panel
	cutin_container = Control.new()
	cutin_container.size = Vector2(360, 210)
	cutin_container.position = Vector2(1120, 260)
	cutin_container.rotation_degrees = -3.5
	cutin_container.visible = false
	control.add_child(cutin_container)

	var cutin_shadow := ColorRect.new()
	cutin_shadow.size = Vector2(360, 210)
	cutin_shadow.position = Vector2(8, 8)
	cutin_shadow.color = Color(0.03, 0.03, 0.05, 0.90)
	cutin_container.add_child(cutin_shadow)

	var cutin_svc := SubViewportContainer.new()
	cutin_svc.size = Vector2(360, 210)
	cutin_svc.stretch = true
	cutin_container.add_child(cutin_svc)

	cutin_subviewport = SubViewport.new()
	cutin_subviewport.size = Vector2i(360, 210)
	cutin_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cutin_subviewport.own_world_3d = false
	cutin_subviewport.world_3d = get_world_3d()
	cutin_svc.add_child(cutin_subviewport)

	cutin_cam = Camera3D.new()
	cutin_cam.fov = 76.0
	cutin_cam.near = 0.05
	cutin_cam.far = 200.0
	cutin_subviewport.add_child(cutin_cam)

	var cutin_border := ReferenceRect.new()
	cutin_border.size = Vector2(360, 210)
	cutin_border.border_color = Color("#080808")
	cutin_border.border_width = 3.5
	cutin_border.editor_only = false
	cutin_container.add_child(cutin_border)

	var cutin_strip := ColorRect.new()
	cutin_strip.size = Vector2(360, 28)
	cutin_strip.color = Color(0.05, 0.06, 0.09, 0.95)
	cutin_container.add_child(cutin_strip)

	cutin_title_label = Label.new()
	cutin_title_label.size = Vector2(360, 28)
	cutin_title_label.text = "⚡ CLOSE PASS // 超接近"
	cutin_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cutin_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cutin_title_label.add_theme_font_size_override("font_size", 14)
	cutin_title_label.add_theme_color_override("font_color", Color("#FFD000"))
	cutin_title_label.add_theme_color_override("font_outline_color", Color("#080808"))
	cutin_title_label.add_theme_constant_override("outline_size", 3)
	cutin_container.add_child(cutin_title_label)

	# 4. INTEGRATED ARCADE SPEEDOMETER CLUSTER
	var speedo_cluster := Control.new()
	speedo_cluster.position = Vector2(28, 42)
	speedo_cluster.rotation_degrees = -4.0
	control.add_child(speedo_cluster)

	# Dark bracket backplate with cyan comic accent border
	var cluster_bg := ColorRect.new()
	cluster_bg.size = Vector2(340, 178)
	cluster_bg.color = Color(0.05, 0.06, 0.10, 0.88)
	speedo_cluster.add_child(cluster_bg)

	var cluster_border := ReferenceRect.new()
	cluster_border.size = Vector2(340, 178)
	cluster_border.border_color = Color("#00E5FF")
	cluster_border.border_width = 2.5
	cluster_border.editor_only = false
	speedo_cluster.add_child(cluster_border)

	var cluster_tag := Label.new()
	cluster_tag.text = "TACHOMETER // WANGAN SPEC"
	cluster_tag.position = Vector2(16, 8)
	cluster_tag.add_theme_font_size_override("font_size", 13)
	cluster_tag.add_theme_color_override("font_color", Color("#00E5FF"))
	speedo_cluster.add_child(cluster_tag)

	# Speed Display: Bold comic numerals with bright yellow fill (#FFD000)
	hud_speed_label = Label.new()
	hud_speed_label.text = "165"
	hud_speed_label.position = Vector2(14, 24)
	hud_speed_label.add_theme_font_size_override("font_size", 54)
	hud_speed_label.add_theme_color_override("font_color", Color("#FFD000"))
	hud_speed_label.add_theme_color_override("font_outline_color", Color("#000000"))
	hud_speed_label.add_theme_constant_override("outline_size", 6)
	hud_speed_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	hud_speed_label.add_theme_constant_override("shadow_offset_x", 4)
	hud_speed_label.add_theme_constant_override("shadow_offset_y", 4)
	speedo_cluster.add_child(hud_speed_label)

	var unit_label := Label.new()
	unit_label.text = "KM/H"
	unit_label.position = Vector2(130, 48)
	unit_label.add_theme_font_size_override("font_size", 22)
	unit_label.add_theme_color_override("font_color", Color("#FFD000"))
	unit_label.add_theme_color_override("font_outline_color", Color("#000000"))
	unit_label.add_theme_constant_override("outline_size", 4)
	speedo_cluster.add_child(unit_label)

	hud_gear_label = Label.new()
	hud_gear_label.text = "GEAR 5"
	hud_gear_label.position = Vector2(245, 48)
	hud_gear_label.add_theme_font_size_override("font_size", 18)
	hud_gear_label.add_theme_color_override("font_color", Color("#00E5FF"))
	speedo_cluster.add_child(hud_gear_label)

	# Rev / Speed Arc Bar (Fills from cyan -> amber -> redline flash at 200 km/h)
	var rev_bg := ColorRect.new()
	rev_bg.position = Vector2(16, 92)
	rev_bg.size = Vector2(308, 12)
	rev_bg.color = Color(0.12, 0.14, 0.18, 0.95)
	speedo_cluster.add_child(rev_bg)

	hud_rev_bar = ColorRect.new()
	hud_rev_bar.position = Vector2(16, 92)
	hud_rev_bar.size = Vector2(220, 12)
	hud_rev_bar.color = Color("#00E5FF")
	speedo_cluster.add_child(hud_rev_bar)

	# Score Counter: Positioned inside the cluster right below the rev bar
	hud_score_label = Label.new()
	hud_score_label.text = "SCORE: 0"
	hud_score_label.position = Vector2(16, 110)
	hud_score_label.add_theme_font_size_override("font_size", 18)
	hud_score_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	hud_score_label.add_theme_color_override("font_outline_color", Color("#000000"))
	hud_score_label.add_theme_constant_override("outline_size", 4)
	speedo_cluster.add_child(hud_score_label)

	# Nitro / Boost Gauge Bar
	hud_nitro_bar_bg = ColorRect.new()
	hud_nitro_bar_bg.position = Vector2(16, 136)
	hud_nitro_bar_bg.size = Vector2(308, 8)
	hud_nitro_bar_bg.color = Color(0.10, 0.12, 0.16, 0.95)
	speedo_cluster.add_child(hud_nitro_bar_bg)

	hud_nitro_bar = ColorRect.new()
	hud_nitro_bar.position = Vector2(16, 136)
	hud_nitro_bar.size = Vector2(0, 8)
	hud_nitro_bar.color = Color("#00E5FF")
	speedo_cluster.add_child(hud_nitro_bar)

	# Visual "DOUBLE TAP!" Ready Prompt Badge
	hud_nitro_ready_badge = Label.new()
	hud_nitro_ready_badge.text = "⚡ DOUBLE TAP BOOST! ⚡"
	hud_nitro_ready_badge.position = Vector2(16, 148)
	hud_nitro_ready_badge.size = Vector2(308, 22)
	hud_nitro_ready_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_nitro_ready_badge.add_theme_font_size_override("font_size", 14)
	hud_nitro_ready_badge.add_theme_color_override("font_color", Color("#FFD000"))
	hud_nitro_ready_badge.add_theme_color_override("font_outline_color", Color("#000000"))
	hud_nitro_ready_badge.add_theme_constant_override("outline_size", 4)
	hud_nitro_ready_badge.visible = false
	speedo_cluster.add_child(hud_nitro_ready_badge)

	# Combo Badge: Angled comic banner with small bounce tween on each graze trigger
	hud_combo_container = Control.new()
	hud_combo_container.position = Vector2(32, 232)
	hud_combo_container.rotation_degrees = -7.0
	hud_combo_container.pivot_offset = Vector2(115, 24)
	hud_combo_container.visible = false
	control.add_child(hud_combo_container)

	var combo_bg := ColorRect.new()
	combo_bg.size = Vector2(250, 46)
	combo_bg.color = Color(0.06, 0.06, 0.10, 0.88)
	hud_combo_container.add_child(combo_bg)

	var combo_accent := ColorRect.new()
	combo_accent.size = Vector2(8, 46)
	combo_accent.color = Color("#FFD000")
	hud_combo_container.add_child(combo_accent)

	hud_combo_label = Label.new()
	hud_combo_label.text = "GRAZE!"
	hud_combo_label.position = Vector2(16, 4)
	hud_combo_label.add_theme_font_size_override("font_size", 28)
	hud_combo_label.add_theme_color_override("font_color", Color("#FFD000"))
	hud_combo_label.add_theme_color_override("font_outline_color", Color("#000000"))
	hud_combo_label.add_theme_constant_override("outline_size", 6)
	hud_combo_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	hud_combo_label.add_theme_constant_override("shadow_offset_x", 3)
	hud_combo_label.add_theme_constant_override("shadow_offset_y", 3)
	hud_combo_container.add_child(hud_combo_label)

	hud_combo_bar = ColorRect.new()
	hud_combo_bar.position = Vector2(0, 46)
	hud_combo_bar.size = Vector2(250, 6)
	hud_combo_bar.color = Color("#FFD000")
	hud_combo_container.add_child(hud_combo_bar)

	hud_drift_label = Label.new()
	hud_drift_label.text = "DRIFT!"
	hud_drift_label.visible = false
	hud_drift_label.position = Vector2(60, 280)
	hud_drift_label.add_theme_font_size_override("font_size", 38)
	hud_drift_label.add_theme_color_override("font_color", Color("#FF5964"))
	hud_drift_label.add_theme_color_override("font_shadow_color", Color("#1B1224"))
	control.add_child(hud_drift_label)

	# Animated Hazard Warning Banner across upper screen (full-width arcade presentation)
	hud_hazard_banner = Control.new()
	var banner_w: float = 1080.0
	var banner_h: float = 48.0
	hud_hazard_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_hazard_banner.offset_left = 0.0
	hud_hazard_banner.offset_right = 0.0
	hud_hazard_banner.offset_top = 205.0
	hud_hazard_banner.offset_bottom = 253.0
	hud_hazard_banner.size = Vector2(banner_w, banner_h)
	hud_hazard_banner.pivot_offset = Vector2(banner_w * 0.5, banner_h * 0.5)
	hud_hazard_banner.visible = false
	control.add_child(hud_hazard_banner)

	# Top Hazard Stripe Tape
	var top_hazard := ColorRect.new()
	top_hazard.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_hazard.offset_left = 0.0
	top_hazard.offset_right = 0.0
	top_hazard.offset_top = 0.0
	top_hazard.offset_bottom = 6.0
	var hz_mat := ShaderMaterial.new()
	hz_mat.shader = load("res://shaders/hazard_stripe.gdshader")
	top_hazard.material = hz_mat
	hud_hazard_banner.add_child(top_hazard)

	# Center Dark Obsidian Banner Plate
	var plate := ColorRect.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.offset_left = 0.0
	plate.offset_right = 0.0
	plate.offset_top = 6.0
	plate.offset_bottom = -6.0
	plate.color = Color(0.06, 0.07, 0.10, 0.94)
	hud_hazard_banner.add_child(plate)

	# Bottom Hazard Stripe Tape
	var bot_hazard := ColorRect.new()
	bot_hazard.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_hazard.offset_left = 0.0
	bot_hazard.offset_right = 0.0
	bot_hazard.offset_top = -6.0
	bot_hazard.offset_bottom = 0.0
	bot_hazard.material = hz_mat
	hud_hazard_banner.add_child(bot_hazard)

	hud_hazard_label = Label.new()
	hud_hazard_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_hazard_label.offset_left = 0.0
	hud_hazard_label.offset_right = 0.0
	hud_hazard_label.offset_top = 6.0
	hud_hazard_label.offset_bottom = -6.0
	hud_hazard_label.text = "⚠️ POLICE PATROL INTERCEPTING AHEAD! ⚠️"
	hud_hazard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hazard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_hazard_label.add_theme_font_size_override("font_size", 22)
	hud_hazard_label.add_theme_color_override("font_color", Color("#FFDF00"))
	hud_hazard_label.add_theme_color_override("font_outline_color", Color("#000000"))
	hud_hazard_label.add_theme_constant_override("outline_size", 4)
	hud_hazard_label.add_theme_color_override("font_shadow_color", Color("#FF1E27"))
	hud_hazard_label.add_theme_constant_override("shadow_offset_x", 2)
	hud_hazard_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_hazard_banner.add_child(hud_hazard_label)

	hud_rival_alert = hud_hazard_label

	# 90s Anime In-Car Radio Transceiver Box (Enlarged High-Visibility Comms HUD)
	hud_radio_chatter = Control.new()
	hud_radio_chatter.size = Vector2(780, 120)
	hud_radio_chatter.position = Vector2(250, 36)
	hud_radio_chatter.visible = false
	control.add_child(hud_radio_chatter)

	var radio_bg := ColorRect.new()
	radio_bg.size = Vector2(780, 120)
	radio_bg.color = Color(0.03, 0.05, 0.09, 0.94)
	hud_radio_chatter.add_child(radio_bg)

	var radio_border := ReferenceRect.new()
	radio_border.size = Vector2(780, 120)
	radio_border.border_color = Color("#00E5FF")
	radio_border.border_width = 3.0
	radio_border.editor_only = false
	hud_radio_chatter.add_child(radio_border)

	var freq_tag := Label.new()
	freq_tag.text = "[RX] ● IN-CAR TRANSCEIVER // 144.80 MHz [CH-03 WANGAN]"
	freq_tag.position = Vector2(16, 8)
	freq_tag.add_theme_font_size_override("font_size", 13)
	freq_tag.add_theme_color_override("font_color", Color("#00FF88"))
	hud_radio_chatter.add_child(freq_tag)

	hud_radio_speaker_label = Label.new()
	hud_radio_speaker_label.position = Vector2(16, 28)
	hud_radio_speaker_label.size = Vector2(748, 30)
	hud_radio_speaker_label.text = "[TACHIBANA SPOTTER]"
	hud_radio_speaker_label.add_theme_font_size_override("font_size", 24)
	hud_radio_speaker_label.add_theme_color_override("font_color", Color("#FFD000"))
	hud_radio_speaker_label.add_theme_color_override("font_outline_color", Color("#050810"))
	hud_radio_speaker_label.add_theme_constant_override("outline_size", 6)
	hud_radio_chatter.add_child(hud_radio_speaker_label)

	hud_radio_text_label = Label.new()
	hud_radio_text_label.position = Vector2(16, 60)
	hud_radio_text_label.size = Vector2(748, 52)
	hud_radio_text_label.text = "Maintain drift angle on the outer apex!"
	hud_radio_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_radio_text_label.add_theme_font_size_override("font_size", 22)
	hud_radio_text_label.add_theme_color_override("font_color", Color("#FFFFFF"))
	hud_radio_text_label.add_theme_color_override("font_outline_color", Color("#050810"))
	hud_radio_text_label.add_theme_constant_override("outline_size", 4)
	hud_radio_chatter.add_child(hud_radio_text_label)

	# In-Car Stereo Now Playing Pill
	rally_track_hud_box = Control.new()
	rally_track_hud_box.size = Vector2(780, 36)
	rally_track_hud_box.position = Vector2(250, 162)
	rally_track_hud_box.visible = false
	control.add_child(rally_track_hud_box)

	var track_bg := ColorRect.new()
	track_bg.size = Vector2(780, 36)
	track_bg.color = Color(0.04, 0.06, 0.10, 0.88)
	rally_track_hud_box.add_child(track_bg)

	var track_border := ReferenceRect.new()
	track_border.size = Vector2(780, 36)
	track_border.border_color = Color("#FFB300")
	track_border.border_width = 2.0
	track_border.editor_only = false
	rally_track_hud_box.add_child(track_border)

	rally_track_hud_label = Label.new()
	rally_track_hud_label.position = Vector2(16, 6)
	rally_track_hud_label.size = Vector2(748, 24)
	rally_track_hud_label.text = "📻 [SHUFFLE] RALLY RADIO"
	rally_track_hud_label.add_theme_font_size_override("font_size", 16)
	rally_track_hud_label.add_theme_color_override("font_color", Color("#FFD000"))
	rally_track_hud_label.add_theme_color_override("font_outline_color", Color("#050810"))
	rally_track_hud_label.add_theme_constant_override("outline_size", 4)
	rally_track_hud_box.add_child(rally_track_hud_label)

	hud_graze_container = Control.new()
	hud_graze_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_graze_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(hud_graze_container)

	hud_restart_banner = Control.new()
	hud_restart_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_restart_banner.visible = false
	control.add_child(hud_restart_banner)

	var banner_bg := ColorRect.new()
	banner_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_bg.color = Color(0.08, 0.05, 0.12, 0.60)
	hud_restart_banner.add_child(banner_bg)

	var crash_lbl := Label.new()
	crash_lbl.text = "CRASHED!"
	crash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crash_lbl.position = Vector2(0, 680)
	crash_lbl.size = Vector2(1080, 100)
	crash_lbl.add_theme_font_size_override("font_size", 76)
	crash_lbl.add_theme_color_override("font_color", Color("#FF3B30"))
	crash_lbl.add_theme_color_override("font_shadow_color", Color("#1B1224"))
	crash_lbl.add_theme_constant_override("shadow_offset_x", 6)
	crash_lbl.add_theme_constant_override("shadow_offset_y", 6)
	hud_restart_banner.add_child(crash_lbl)

	hud_summary_stats = Label.new()
	hud_summary_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_summary_stats.position = Vector2(0, 800)
	hud_summary_stats.size = Vector2(1080, 160)
	hud_summary_stats.add_theme_font_size_override("font_size", 34)
	hud_summary_stats.add_theme_color_override("font_color", Color("#F4D03F"))
	hud_summary_stats.add_theme_color_override("font_shadow_color", Color("#1B1224"))
	hud_summary_stats.add_theme_constant_override("shadow_offset_x", 3)
	hud_summary_stats.add_theme_constant_override("shadow_offset_y", 3)
	hud_restart_banner.add_child(hud_summary_stats)

	var tap_lbl := Label.new()
	tap_lbl.text = "TAP ANYWHERE TO RESTART"
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_lbl.position = Vector2(0, 980)
	tap_lbl.size = Vector2(1080, 60)
	tap_lbl.add_theme_font_size_override("font_size", 36)
	tap_lbl.add_theme_color_override("font_color", Color("#FFF8E7"))
	tap_lbl.add_theme_color_override("font_shadow_color", Color("#1B1224"))
	tap_lbl.add_theme_constant_override("shadow_offset_x", 3)
	tap_lbl.add_theme_constant_override("shadow_offset_y", 3)
	hud_restart_banner.add_child(tap_lbl)

	# Manga Tankōbon Cover Results Screen (Game Over)
	hud_tankobon_cover = Control.new()
	hud_tankobon_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_tankobon_cover.visible = false
	control.add_child(hud_tankobon_cover)

	var tank_backdrop := ColorRect.new()
	tank_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	tank_backdrop.color = Color(0.04, 0.04, 0.07, 0.85)
	hud_tankobon_cover.add_child(tank_backdrop)

	var book := Control.new()
	book.position = Vector2(90, 210)
	book.size = Vector2(900, 1460)
	hud_tankobon_cover.add_child(book)

	var book_shadow := ColorRect.new()
	book_shadow.size = Vector2(900, 1460)
	book_shadow.position = Vector2(14, 16)
	book_shadow.color = Color(0.0, 0.0, 0.0, 0.95)
	book.add_child(book_shadow)

	var book_bg := ColorRect.new()
	book_bg.size = Vector2(900, 1460)
	book_bg.color = Color("#F4F1EA")
	book.add_child(book_bg)

	var book_border := ReferenceRect.new()
	book_border.size = Vector2(900, 1460)
	book_border.border_color = Color("#080808")
	book_border.border_width = 7.0
	book_border.editor_only = false
	book.add_child(book_border)

	var inner_rule := ReferenceRect.new()
	inner_rule.position = Vector2(10, 10)
	inner_rule.size = Vector2(880, 1440)
	inner_rule.border_color = Color("#080808")
	inner_rule.border_width = 2.0
	inner_rule.editor_only = false
	book.add_child(inner_rule)

	var pub_bar := ColorRect.new()
	pub_bar.position = Vector2(14, 14)
	pub_bar.size = Vector2(872, 54)
	pub_bar.color = Color("#0C0E14")
	book.add_child(pub_bar)

	var pub_lbl := Label.new()
	pub_lbl.text = "週刊少年 WANGAN COMICS"
	pub_lbl.position = Vector2(24, 22)
	pub_lbl.add_theme_font_size_override("font_size", 24)
	pub_lbl.add_theme_color_override("font_color", Color("#FFDF00"))
	pub_lbl.add_theme_color_override("font_outline_color", Color("#080808"))
	pub_lbl.add_theme_constant_override("outline_size", 4)
	book.add_child(pub_lbl)

	var issue_lbl := Label.new()
	issue_lbl.text = "SHONEN FLOW NO.24 // ¥480"
	issue_lbl.position = Vector2(580, 24)
	issue_lbl.add_theme_font_size_override("font_size", 18)
	issue_lbl.add_theme_color_override("font_color", Color("#00E5FF"))
	book.add_child(issue_lbl)

	var title_kanji := Label.new()
	title_kanji.text = "湾岸 FLOW STATE"
	title_kanji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_kanji.position = Vector2(0, 96)
	title_kanji.size = Vector2(900, 90)
	title_kanji.add_theme_font_size_override("font_size", 68)
	title_kanji.add_theme_color_override("font_color", Color("#FF1E27"))
	title_kanji.add_theme_color_override("font_outline_color", Color("#080808"))
	title_kanji.add_theme_constant_override("outline_size", 8)
	title_kanji.add_theme_color_override("font_shadow_color", Color("#080808"))
	title_kanji.add_theme_constant_override("shadow_offset_x", 6)
	title_kanji.add_theme_constant_override("shadow_offset_y", 6)
	book.add_child(title_kanji)

	var title_sub := Label.new()
	title_sub.text = "— VOL. 01 : HIGHWAY ACCIDENT INVESTIGATION —"
	title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sub.position = Vector2(0, 190)
	title_sub.size = Vector2(900, 32)
	title_sub.add_theme_font_size_override("font_size", 20)
	title_sub.add_theme_color_override("font_color", Color("#1A1C24"))
	book.add_child(title_sub)

	var illu_box := ColorRect.new()
	illu_box.position = Vector2(40, 240)
	illu_box.size = Vector2(820, 560)
	illu_box.color = Color("#11131A")
	book.add_child(illu_box)

	var illu_border := ReferenceRect.new()
	illu_border.position = Vector2(40, 240)
	illu_border.size = Vector2(820, 560)
	illu_border.border_color = Color("#080808")
	illu_border.border_width = 4.0
	illu_border.editor_only = false
	book.add_child(illu_border)

	var illu_tag := Label.new()
	illu_tag.text = "CRITICAL CHASSIS FAILURE // 追突・大破"
	illu_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	illu_tag.position = Vector2(40, 260)
	illu_tag.size = Vector2(820, 40)
	illu_tag.add_theme_font_size_override("font_size", 26)
	illu_tag.add_theme_color_override("font_color", Color("#FF5964"))
	illu_tag.add_theme_color_override("font_outline_color", Color("#080808"))
	illu_tag.add_theme_constant_override("outline_size", 5)
	book.add_child(illu_tag)

	var stamp_container := Control.new()
	stamp_container.position = Vector2(450, 530)
	stamp_container.size = Vector2(240, 240)
	stamp_container.pivot_offset = Vector2(120, 120)
	stamp_container.rotation_degrees = -14.0
	book.add_child(stamp_container)

	var stamp_outer_ring := ReferenceRect.new()
	stamp_outer_ring.size = Vector2(240, 240)
	stamp_outer_ring.border_color = Color("#FF1E27")
	stamp_outer_ring.border_width = 6.0
	stamp_outer_ring.editor_only = false
	stamp_container.add_child(stamp_outer_ring)

	var stamp_tag := Label.new()
	stamp_tag.text = "OFFICIAL EVALUATION"
	stamp_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_tag.position = Vector2(0, 18)
	stamp_tag.size = Vector2(240, 24)
	stamp_tag.add_theme_font_size_override("font_size", 13)
	stamp_tag.add_theme_color_override("font_color", Color("#FF1E27"))
	stamp_container.add_child(stamp_tag)

	hud_grade_badge = Label.new()
	hud_grade_badge.text = "RETIRED"
	hud_grade_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_grade_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_grade_badge.position = Vector2(0, 44)
	hud_grade_badge.size = Vector2(240, 140)
	hud_grade_badge.pivot_offset = Vector2(120, 70)
	hud_grade_badge.add_theme_font_size_override("font_size", 74)
	hud_grade_badge.add_theme_color_override("font_color", Color("#FF1E27"))
	hud_grade_badge.add_theme_color_override("font_outline_color", Color("#080808"))
	hud_grade_badge.add_theme_constant_override("outline_size", 8)
	stamp_container.add_child(hud_grade_badge)

	var stats_box := ColorRect.new()
	stats_box.position = Vector2(40, 830)
	stats_box.size = Vector2(820, 390)
	stats_box.color = Color("#0C0E14")
	book.add_child(stats_box)

	var stats_border := ReferenceRect.new()
	stats_border.position = Vector2(40, 830)
	stats_border.size = Vector2(820, 390)
	stats_border.border_color = Color("#080808")
	stats_border.border_width = 4.0
	stats_border.editor_only = false
	book.add_child(stats_border)

	hud_comic_stats_label = Label.new()
	hud_comic_stats_label.position = Vector2(65, 855)
	hud_comic_stats_label.size = Vector2(770, 340)
	hud_comic_stats_label.add_theme_font_size_override("font_size", 28)
	hud_comic_stats_label.add_theme_color_override("font_color", Color("#F4D03F"))
	hud_comic_stats_label.add_theme_color_override("font_outline_color", Color("#080808"))
	hud_comic_stats_label.add_theme_constant_override("outline_size", 4)
	hud_comic_stats_label.add_theme_constant_override("line_spacing", 12)
	hud_comic_stats_label.text = "RUN LOG:\n  TOTAL SCORE: 0 PTS\n  TOP SPEED: 0 KM/H\n  NEAR MISSES: 0 GRAZES\n  FINAL COMBO: x1 CHAIN"
	book.add_child(hud_comic_stats_label)

	var barcode_box := ColorRect.new()
	barcode_box.position = Vector2(40, 1250)
	barcode_box.size = Vector2(300, 160)
	barcode_box.color = Color("#FFFFFF")
	book.add_child(barcode_box)

	var barcode_border := ReferenceRect.new()
	barcode_border.position = Vector2(40, 1250)
	barcode_border.size = Vector2(300, 160)
	barcode_border.border_color = Color("#080808")
	barcode_border.border_width = 2.0
	barcode_border.editor_only = false
	book.add_child(barcode_border)

	var bar_widths: Array[int] = [3, 1, 2, 4, 1, 3, 2, 1, 4, 2, 3, 1, 2, 4, 1, 3, 2, 1, 3, 2, 4, 1]
	var cur_bx: float = 20.0
	for bw in bar_widths:
		var bar := ColorRect.new()
		bar.position = Vector2(cur_bx, 15.0)
		bar.size = Vector2(bw * 2.2, 85.0)
		bar.color = Color("#080808")
		barcode_box.add_child(bar)
		cur_bx += bw * 2.2 + 5.0

	var isbn_lbl := Label.new()
	isbn_lbl.text = "4 901234 567890\nISBN 978-4-08-872856-8"
	isbn_lbl.position = Vector2(10, 108)
	isbn_lbl.size = Vector2(280, 48)
	isbn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	isbn_lbl.add_theme_font_size_override("font_size", 14)
	isbn_lbl.add_theme_color_override("font_color", Color("#080808"))
	barcode_box.add_child(isbn_lbl)

	hud_retry_btn = Button.new()
	hud_retry_btn.text = "RE-RUN // 再挑戦"
	hud_retry_btn.position = Vector2(400, 1270)
	hud_retry_btn.size = Vector2(460, 120)
	hud_retry_btn.add_theme_font_size_override("font_size", 34)
	hud_retry_btn.add_theme_color_override("font_color", Color("#080808"))
	hud_retry_btn.add_theme_color_override("font_hover_color", Color("#FF1E27"))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#FFDF00")
	btn_style.border_width_left = 5
	btn_style.border_width_top = 5
	btn_style.border_width_right = 5
	btn_style.border_width_bottom = 5
	btn_style.border_color = Color("#080808")
	btn_style.shadow_size = 8
	btn_style.shadow_offset = Vector2(6, 6)
	hud_retry_btn.add_theme_stylebox_override("normal", btn_style)
	hud_retry_btn.pressed.connect(func(): _reset_race())
	book.add_child(hud_retry_btn)

	# START SCREEN HUD OVERLAY WITH VIBE PILL
	hud_start_screen = Control.new()
	hud_start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_start_screen.visible = (current_state == GameState.START)
	control.add_child(hud_start_screen)

	var start_bg_btn := Button.new()
	start_bg_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_bg_btn.flat = true
	start_bg_btn.focus_mode = Control.FOCUS_NONE
	start_bg_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	start_bg_btn.pressed.connect(func(): _start_race())
	hud_start_screen.add_child(start_bg_btn)

	var title_lbl := Label.new()
	title_lbl.text = "FLOWSTATE // 湾岸"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.position = Vector2(0, 260)
	title_lbl.size = Vector2(1080, 110)
	title_lbl.add_theme_font_size_override("font_size", 68)
	title_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	title_lbl.add_theme_color_override("font_shadow_color", Color("#080811"))
	title_lbl.add_theme_constant_override("shadow_offset_x", 4)
	title_lbl.add_theme_constant_override("shadow_offset_y", 6)
	hud_start_screen.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "— OUTRUN HIGHWAY ARCADE —"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.position = Vector2(0, 370)
	sub_lbl.size = Vector2(1080, 50)
	sub_lbl.add_theme_font_size_override("font_size", 26)
	sub_lbl.add_theme_color_override("font_color", Color("#FFD000"))
	sub_lbl.add_theme_color_override("font_shadow_color", Color("#080811"))
	sub_lbl.add_theme_constant_override("shadow_offset_y", 3)
	hud_start_screen.add_child(sub_lbl)

	# Vibe Pill Container (Beside/Above "TAP TO DRIVE")
	var pill_box := Control.new()
	pill_box.position = Vector2(240, 1380)
	pill_box.size = Vector2(600, 76)
	pill_box.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_start_screen.add_child(pill_box)

	var pill_bg := ColorRect.new()
	pill_bg.size = Vector2(600, 76)
	pill_bg.color = Color(0.06, 0.07, 0.12, 0.92)
	pill_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_box.add_child(pill_bg)

	var pill_border := ReferenceRect.new()
	pill_border.size = Vector2(600, 76)
	pill_border.border_color = Color("#00E5FF")
	pill_border.border_width = 3.0
	pill_border.editor_only = false
	pill_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_box.add_child(pill_border)

	var btn_prev := Button.new()
	btn_prev.text = "◀"
	btn_prev.position = Vector2(8, 8)
	btn_prev.size = Vector2(60, 60)
	btn_prev.focus_mode = Control.FOCUS_NONE
	btn_prev.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_prev.add_theme_font_size_override("font_size", 32)
	btn_prev.pressed.connect(func(): _cycle_start_biome(-1))
	pill_box.add_child(btn_prev)

	hud_vibe_label = Label.new()
	hud_vibe_label.text = BIOMES[current_biome_id]["name"]
	hud_vibe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_vibe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_vibe_label.position = Vector2(75, 0)
	hud_vibe_label.size = Vector2(450, 76)
	hud_vibe_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_vibe_label.add_theme_font_size_override("font_size", 30)
	hud_vibe_label.add_theme_color_override("font_color", Color("#00E5FF"))
	hud_vibe_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	hud_vibe_label.add_theme_constant_override("shadow_offset_y", 3)
	pill_box.add_child(hud_vibe_label)

	var btn_next := Button.new()
	btn_next.text = "▶"
	btn_next.position = Vector2(532, 8)
	btn_next.size = Vector2(60, 60)
	btn_next.focus_mode = Control.FOCUS_NONE
	btn_next.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_next.add_theme_font_size_override("font_size", 32)
	btn_next.pressed.connect(func(): _cycle_start_biome(1))
	pill_box.add_child(btn_next)

	var start_tap_lbl := Label.new()
	start_tap_lbl.text = "TAP TO DRIVE"
	start_tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_tap_lbl.position = Vector2(0, 1490)
	start_tap_lbl.size = Vector2(1080, 80)
	start_tap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_tap_lbl.add_theme_font_size_override("font_size", 42)
	start_tap_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	start_tap_lbl.add_theme_color_override("font_shadow_color", Color("#000000"))
	start_tap_lbl.add_theme_constant_override("shadow_offset_y", 4)
	hud_start_screen.add_child(start_tap_lbl)

	var tw_tap := create_tween().set_loops()
	tw_tap.tween_property(start_tap_lbl, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	tw_tap.tween_property(start_tap_lbl, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	# Manga Stage Tier Upgrade Banner
	hud_stage_banner = Control.new()
	hud_stage_banner.set_anchors_preset(Control.PRESET_CENTER)
	hud_stage_banner.position = Vector2(190, 480)
	hud_stage_banner.size = Vector2(700, 160)
	hud_stage_banner.visible = false
	control.add_child(hud_stage_banner)

	var stg_bg := ColorRect.new()
	stg_bg.size = Vector2(700, 160)
	stg_bg.color = Color(0.05, 0.07, 0.12, 0.94)
	hud_stage_banner.add_child(stg_bg)

	var stg_border := ReferenceRect.new()
	stg_border.size = Vector2(700, 160)
	stg_border.border_color = Color("#FFDF00")
	stg_border.border_width = 4.0
	stg_border.editor_only = false
	hud_stage_banner.add_child(stg_border)

	hud_stage_label = Label.new()
	hud_stage_label.text = "STAGE 2 // +20 KM/H"
	hud_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_stage_label.position = Vector2(0, 20)
	hud_stage_label.size = Vector2(700, 60)
	hud_stage_label.add_theme_font_size_override("font_size", 42)
	hud_stage_label.add_theme_color_override("font_color", Color("#FFDF00"))
	hud_stage_label.add_theme_color_override("font_shadow_color", Color("#000000"))
	hud_stage_label.add_theme_constant_override("shadow_offset_y", 3)
	hud_stage_banner.add_child(hud_stage_label)

	hud_stage_sub = Label.new()
	hud_stage_sub.text = "BASE TOP SPEED: 185 KM/H (1.25x SCORE)"
	hud_stage_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_stage_sub.position = Vector2(0, 92)
	hud_stage_sub.size = Vector2(700, 45)
	hud_stage_sub.add_theme_font_size_override("font_size", 24)
	hud_stage_sub.add_theme_color_override("font_color", Color("#FFFFFF"))
	hud_stage_banner.add_child(hud_stage_sub)

# ==============================================================================
# 10. TOUCH DISPATCHER (DEADZONE & PROPORTIONAL STEERING)
# ==============================================================================
func _input(event: InputEvent) -> void:
	if not _audio_unlocked and event.is_pressed():
		_audio_unlocked = true
		AudioServer.set_bus_mute(0, false)
		if is_instance_valid(engine_audio_player) and not engine_audio_player.playing:
			engine_audio_player.play()
		if is_instance_valid(rally_music_player) and not rally_music_player.playing:
			_play_random_rally_track()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			set_weather_rain(not is_raining)
		elif event.keycode == KEY_B:
			for b in BIOMES.keys():
				if not b in discovered_biomes:
					discovered_biomes.append(b)
			_cycle_start_biome(1)

	if current_state == GameState.START:
		return

	if current_state == GameState.CRASHED:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			if tankobon_shown:
				_reset_race()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var now_sec: float = Time.get_ticks_msec() * 0.001
			if (now_sec - last_tap_time) <= DOUBLE_TAP_WINDOW and (now_sec - last_tap_time) > 0.04:
				last_tap_time = -999.0
				if nitro_charge >= 50.0 and current_state == GameState.RACING:
					_try_activate_double_tap_nitro()
			else:
				last_tap_time = now_sec
			is_touching = true
			touch_start = event.position
			touch_current = event.position
		else:
			is_touching = false
			steer_input = 0.0
			drift_active = false
			boost_active = false
	elif event is InputEventScreenDrag and is_touching:
		touch_current = event.position
		var delta_drag: Vector2 = touch_current - touch_start

		if abs(delta_drag.x) > 220.0:
			touch_start.x = touch_current.x - (sign(delta_drag.x) * 220.0)
			delta_drag.x = touch_current.x - touch_start.x

		var deadzone: float = 12.0
		var raw_x: float = delta_drag.x
		if abs(raw_x) < deadzone:
			steer_input = 0.0
		else:
			var norm: float = clamp((raw_x - (sign(raw_x) * deadzone)) / 180.0, -1.0, 1.0)
			steer_input = sign(norm) * pow(abs(norm), 1.25)

		boost_active = delta_drag.y < -50.0
		drift_active = delta_drag.y > 45.0
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var now_sec: float = Time.get_ticks_msec() * 0.001
				if (now_sec - last_tap_time) <= DOUBLE_TAP_WINDOW and (now_sec - last_tap_time) > 0.04:
					last_tap_time = -999.0
					if nitro_charge >= 50.0 and current_state == GameState.RACING:
						_try_activate_double_tap_nitro()
				else:
					last_tap_time = now_sec
				is_touching = true
				touch_start = event.position
				touch_current = event.position
			else:
				is_touching = false
				steer_input = 0.0
				drift_active = false
				boost_active = false
	elif event is InputEventMouseMotion and is_touching:
		touch_current = event.position
		var delta_drag: Vector2 = touch_current - touch_start
		var deadzone: float = 12.0
		var raw_x: float = delta_drag.x
		if abs(raw_x) < deadzone:
			steer_input = 0.0
		else:
			var norm: float = clamp((raw_x - (sign(raw_x) * deadzone)) / 180.0, -1.0, 1.0)
			steer_input = sign(norm) * pow(abs(norm), 1.25)
		boost_active = delta_drag.y < -50.0
		drift_active = delta_drag.y > 45.0

# ==============================================================================
# 11. MAIN LOOP & AUTHENTIC ARCADE DRIVING PHYSICS
# ==============================================================================
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if radio_chatter_cooldown > 0.0:
		radio_chatter_cooldown -= delta
	_process_audio_mixing(delta)
	if current_state == GameState.START:
		_process_suspension_and_vibration(delta)
		_update_camera(delta)
		_update_hud(delta)
		return
	if current_state == GameState.CRASHED:
		_process_crashed_state(delta)
		_update_camera(delta)
		_update_hud(delta)
		return

	_process_player_motion(delta)
	_process_suspension_and_vibration(delta)

	# Dynamic spinning wheels
	var player_spin: float = (player_speed / TIRE_RADIUS) * delta
	for w in player_wheels:
		w.rotate_x(player_spin)

	for td in traffic_pool:
		var tr_spin: float = (td.speed / TIRE_RADIUS) * delta
		for w in td.wheels:
			w.rotate_x(tr_spin)

	_process_traffic_and_collisions(delta)

	# Check Fork Midpoint & Exit Checkpoints
	if fork_active:
		if not fork_transition_done and player_z <= active_fork_mid_z:
			var chosen_biome: String = fork_left_biome if player_lane_x < 0.0 else fork_right_biome
			_apply_biome_transition(chosen_biome)
			fork_transition_done = true
		elif fork_transition_done and player_z <= active_fork_exit_z:
			fork_active = false
			stage_tier += 1
			stage_start_z = player_z
			_discover_biome(current_biome_id)
			cam_fov_punch = 3.5
			cam_fov_punch_timer = 0.35
			_trigger_stage_badge(stage_tier, int(round(_get_stage_top_speed_kmh(stage_tier))))
			_trigger_radio_chatter("TACHIBANA SPOTTER", "Tunnel exit clear! Entering " + BIOMES[current_biome_id]["name"] + "!", Color("#00FF88"))

	_process_rival_ai(delta)
	_process_road_recycler()
	_process_highway_hazards(delta)
	_process_skid_marks(delta)
	_process_weather_cycle(delta)

	# Drift charging (+30.0/sec while holding drift)
	if drift_active and current_state == GameState.RACING:
		nitro_charge = min(100.0, nitro_charge + 30.0 * delta)
		drift_charge = min(100.0, drift_charge + 30.0 * delta)

	# Exhaust backfire & nitro flames
	if nitro_active:
		_show_nitro_flames(true)
	else:
		if backfire_timer > 0.0:
			backfire_timer -= delta
			if backfire_timer <= 0.0:
				if is_instance_valid(exhaust_flame_l): exhaust_flame_l.visible = false
				if is_instance_valid(exhaust_flame_r): exhaust_flame_r.visible = false
	if backfire_light_timer > 0.0:
		backfire_light_timer -= delta
		if backfire_light_timer <= 0.0:
			if is_instance_valid(exhaust_bumper_flash): exhaust_bumper_flash.visible = false

	# Dynamic Day/Night Cycle, Sky Interpolation & Headlight/Sodium Management
	_process_day_night_cycle(delta)

	# Diffuser ground spark bursts: at speeds > 180 km/h, trigger intermittent 3-frame micro-bursts scraping from beneath rear diffuser
	var player_kmh_sparks: float = player_speed * 3.6
	if player_kmh_sparks > 180.0 and current_state == GameState.RACING:
		diffuser_spark_timer -= delta
		if diffuser_spark_timer <= 0.0:
			diffuser_spark_timer = randf_range(0.08, 0.18)
			_spawn_diffuser_ground_sparks()
	else:
		diffuser_spark_timer = 0.0

	# Dynamic Manga Comic Cut-In trigger on 4x combo
	if combo_multiplier >= 4 and not cutin_active and cutin_cooldown <= 0.0:
		_trigger_manga_cutin("🔥 COMBO FEVER 4X!")

	# Update secondary cut-in camera position
	if is_instance_valid(cutin_container) and cutin_container.visible and is_instance_valid(cutin_cam) and is_instance_valid(car_root):
		var car_trans := car_root.global_transform
		var fender_pos := car_trans * Vector3(-1.18, 0.45, -1.2)
		var look_target := car_trans * Vector3(-0.35, 0.60, 1.1)
		cutin_cam.global_position = fender_pos
		cutin_cam.look_at(look_target, car_trans.basis.y)

	if cutin_cooldown > 0.0:
		cutin_cooldown -= delta

	_update_camera(delta)
	_update_hud(delta)

func _on_tod_btn_pressed() -> void:
	tod_mode = (tod_mode + 1) % 4
	match tod_mode:
		0:
			if is_instance_valid(hud_tod_toggle_btn): hud_tod_toggle_btn.text = "☀️ AUTO"
		1:
			if is_instance_valid(hud_tod_toggle_btn): hud_tod_toggle_btn.text = "☀️ NOON"
		2:
			if is_instance_valid(hud_tod_toggle_btn): hud_tod_toggle_btn.text = "🌅 DUSK"
		3:
			if is_instance_valid(hud_tod_toggle_btn): hud_tod_toggle_btn.text = "🌙 NIGHT"

func _process_day_night_cycle(delta: float) -> void:
	if tod_mode == 0:
		day_cycle_progress = fposmod(day_cycle_progress + (delta / day_cycle_duration), 1.0)
	elif tod_mode == 1:
		day_cycle_progress = lerp(day_cycle_progress, 0.0, 8.0 * delta)
	elif tod_mode == 2:
		day_cycle_progress = lerp(day_cycle_progress, 0.32, 8.0 * delta)
	elif tod_mode == 3:
		day_cycle_progress = lerp(day_cycle_progress, 0.60, 8.0 * delta)

	# 4 Distinct Phases: Noon (0.0) -> Dusk (0.32) -> Midnight (0.60) -> Dawn (0.85) -> Noon (1.0)
	var times := [0.0, 0.32, 0.60, 0.85, 1.0]
	var idx: int = 0
	while idx < 3 and day_cycle_progress > times[idx + 1]:
		idx += 1
	var t_span: float = times[idx + 1] - times[idx]
	var u: float = clamp((day_cycle_progress - times[idx]) / t_span, 0.0, 1.0)
	var s: float = u * u * (3.0 - 2.0 * u) # Smoothstep

	# Keyframe Color & Scalar Tables
	var sky_tops := [Color("#08307B"), Color("#1F153E"), Color("#05070E"), Color("#102B5E"), Color("#08307B")]
	var sky_hors := [Color("#9CC5E8"), Color("#FF6B35"), Color("#0E1528"), Color("#FFB885"), Color("#9CC5E8")]
	var gnd_hors := [Color("#242B3D"), Color("#1B1626"), Color("#080B12"), Color("#1E1F2A"), Color("#242B3D")]
	var gnd_bots := [Color("#181D2A"), Color("#0F0C16"), Color("#030407"), Color("#12131C"), Color("#181D2A")]

	var sun_cols := [Color("#FFF8EB"), Color("#FFA347"), Color("#6B8AFF"), Color("#FFE6C2"), Color("#FFF8EB")]
	var sun_pits := [-55.0, -24.0, -42.0, -26.0, -55.0]
	var sun_yaws := [32.0, 48.0, 25.0, -42.0, 32.0]
	var sun_nrgs := [1.25, 1.10, 0.20, 0.95, 1.25]

	var amb_cols := [Color("#526880"), Color("#887082"), Color("#1A2238"), Color("#8A6478"), Color("#526880")]
	var amb_nrgs := [0.55, 0.60, 0.28, 0.48, 0.55]

	var fog_cols := [Color("#88AED2"), Color("#E27448"), Color("#10182C"), Color("#DB8E80"), Color("#88AED2")]
	var fog_nrgs := [0.70, 0.85, 0.35, 0.70, 0.70]

	var night_facs := [0.0, 0.38, 1.0, 0.10, 0.0]

	var cur_sky_top: Color = sky_tops[idx].lerp(sky_tops[idx + 1], s)
	var cur_sky_hor: Color = sky_hors[idx].lerp(sky_hors[idx + 1], s)
	var cur_gnd_hor: Color = gnd_hors[idx].lerp(gnd_hors[idx + 1], s)
	var cur_gnd_bot: Color = gnd_bots[idx].lerp(gnd_bots[idx + 1], s)

	var cur_sun_col: Color = sun_cols[idx].lerp(sun_cols[idx + 1], s)
	var cur_sun_pit: float = lerp(sun_pits[idx], sun_pits[idx + 1], s)
	var cur_sun_yaw: float = lerp(sun_yaws[idx], sun_yaws[idx + 1], s)
	var cur_sun_nrg: float = lerp(sun_nrgs[idx], sun_nrgs[idx + 1], s)

	var cur_amb_col: Color = amb_cols[idx].lerp(amb_cols[idx + 1], s)
	var cur_amb_nrg: float = lerp(amb_nrgs[idx], amb_nrgs[idx + 1], s)

	var cur_fog_col: Color = fog_cols[idx].lerp(fog_cols[idx + 1], s)
	var cur_fog_nrg: float = lerp(fog_nrgs[idx], fog_nrgs[idx + 1], s)

	night_factor = lerp(night_facs[idx], night_facs[idx + 1], s)

	# Modulate sun and ambient light occlusion when inside procedural tunnel
	var in_tunnel: bool = false
	for tint in active_tunnel_intervals:
		if player_z <= tint.x and player_z >= tint.y:
			in_tunnel = true
			break
	is_in_tunnel = in_tunnel

	if current_biome_id in BIOMES and current_biome_id != "shuto_dusk":
		var b_data: Dictionary = BIOMES[current_biome_id]
		cur_sky_top = b_data["sky_top"]
		cur_sky_hor = b_data["sky_horizon"]
		cur_gnd_hor = b_data["ground_horizon"]
		cur_sun_col = b_data["sun_color"]
		cur_sun_nrg = b_data["sun_energy"]
		cur_amb_col = b_data["ambient_color"]
		cur_amb_nrg = b_data["ambient_energy"]
		cur_fog_col = b_data["fog_color"]
		if current_biome_id == "neo_shinjuku":
			night_factor = 1.0
		else:
			night_factor = 0.15

	if in_tunnel:
		cur_sun_nrg *= 0.10
		cur_amb_nrg *= 0.35

	# Update Sun DirectionalLight3D
	var car_tints := [
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.08, 0.88, 0.78, 1.0),
		Color(0.55, 0.60, 0.76, 1.0),
		Color(0.92, 0.82, 0.88, 1.0),
		Color(1.0, 1.0, 1.0, 1.0)
	]
	var cur_car_tint: Color = car_tints[idx].lerp(car_tints[idx + 1], s)

	if is_instance_valid(sun_light):
		sun_light.rotation_degrees = Vector3(cur_sun_pit, cur_sun_yaw, 0.0)
		sun_light.light_color = cur_sun_col
		sun_light.light_energy = lerp(sun_light.light_energy, cur_sun_nrg, 8.0 * delta)
		sun_light.light_volumetric_fog_energy = 0.0
		var sun_fwd_dir := -sun_light.global_transform.basis.z
		if is_instance_valid(hero_body_shader_mat):
			hero_body_shader_mat.set_shader_parameter("sun_direction", sun_fwd_dir)
			hero_body_shader_mat.set_shader_parameter("day_night_tint", cur_car_tint)
		for sm in spoiler_mats:
			if is_instance_valid(sm):
				sm.set_shader_parameter("sun_direction", sun_fwd_dir)
				sm.set_shader_parameter("day_night_tint", cur_car_tint)
		for td in traffic_pool:
			if is_instance_valid(td.body_mat):
				td.body_mat.set_shader_parameter("sun_direction", sun_fwd_dir)
				td.body_mat.set_shader_parameter("day_night_tint", cur_car_tint)

	# Update Environment & Atmospheric Fog
	if is_instance_valid(world_env_resource):
		world_env_resource.volumetric_fog_enabled = false
		world_env_resource.volumetric_fog_density = 0.001
		world_env_resource.volumetric_fog_emission_energy = 0.0
		world_env_resource.background_energy_multiplier = 1.0
		world_env_resource.ambient_light_color = cur_amb_col
		world_env_resource.ambient_light_energy = lerp(world_env_resource.ambient_light_energy, cur_amb_nrg, 8.0 * delta)
		world_env_resource.fog_light_color = cur_fog_col
		world_env_resource.fog_light_energy = cur_fog_nrg
		world_env_resource.volumetric_fog_albedo = Color(0, 0, 0, 0)
		world_env_resource.volumetric_fog_emission = Color(0, 0, 0, 0)

	# Update Sky Gradient (throttled to avoid GPU radiance map cubemap re-baking every 16ms)
	if is_instance_valid(procedural_sky_mat) and abs(day_cycle_progress - last_sky_update_progress) >= 0.005:
		last_sky_update_progress = day_cycle_progress
		procedural_sky_mat.sky_top_color = cur_sky_top
		procedural_sky_mat.sky_horizon_color = cur_sky_hor
		procedural_sky_mat.ground_horizon_color = cur_gnd_hor
		procedural_sky_mat.ground_bottom_color = cur_gnd_bot
		procedural_sky_mat.sun_angle_max = 10.0
		procedural_sky_mat.sun_curve = 0.50
		procedural_sky_mat.energy_multiplier = 1.0
		procedural_sky_mat.sky_energy_multiplier = 1.0

	# Update Vehicle Headlights & Projected Ground Beam
	var h_active: bool = (night_factor > 0.05)
	if is_instance_valid(hero_headlight_l):
		hero_headlight_l.visible = h_active
		hero_headlight_l.light_energy = 5.2 * night_factor
	if is_instance_valid(hero_headlight_r):
		hero_headlight_r.visible = false

	# Update Global Highway Sodium Lamp Posts & Road Surface Pools
	if is_instance_valid(sodium_lamp_mat):
		sodium_lamp_mat.emission_energy_multiplier = 4.8 * night_factor
	if is_instance_valid(sodium_pool_mat):
		sodium_pool_mat.albedo_color.a = 0.65 * night_factor

	# Update Distant Horizon Clouds (Eliminates white band at all times of day)
	if is_instance_valid(bg_cloud_mat):
		bg_cloud_mat.albedo_color = Color(0, 0, 0, 0)

	var env_sun_dir := -sun_light.global_transform.basis.z if is_instance_valid(sun_light) else Vector3(-0.5, -0.8, -0.3)

	# Update Batched Tokyo Skyline Lights, Dynamic Sun Facade & Atmosphere
	if is_instance_valid(skyline_mat):
		skyline_mat.set_shader_parameter("night_glow", night_factor)
		skyline_mat.set_shader_parameter("sun_direction", env_sun_dir)
		skyline_mat.set_shader_parameter("sun_tint", cur_sun_col * 0.90)
		skyline_mat.set_shader_parameter("horizon_haze_color", cur_sky_hor)
		var bldg_cols := [
			Color("#181E26"), # Noon: cool modern dark steel-slate silhouette
			Color("#221B24"), # Sunset: deep warm twilight silhouette (matching reference)
			Color("#0C1016"), # Night: deep midnight blue highrise
			Color("#141820"), # Dawn: morning light highrise
			Color("#181E26")  # Noon
		]
		var cur_bldg_col: Color = bldg_cols[idx].lerp(bldg_cols[idx + 1], s)
		skyline_mat.set_shader_parameter("building_base_color", cur_bldg_col)

	if is_instance_valid(tokyo_bay_water_mat):
		tokyo_bay_water_mat.set_shader_parameter("horizon_fog_color", cur_sky_hor)
		tokyo_bay_water_mat.set_shader_parameter("night_factor", night_factor)
		tokyo_bay_water_mat.set_shader_parameter("sun_direction", env_sun_dir)
		tokyo_bay_water_mat.set_shader_parameter("sun_reflection_color", cur_sun_col * 0.80)

	# Production-grade Anime Lighting Palettes for Foliage & Mountains
	var fol_base_cols := [
		Color(0.06, 0.14, 0.07, 1.0), # Noon: deep rich Japanese viridian
		Color(0.08, 0.08, 0.07, 1.0), # Sunset: dark warm cedar silhouette (reference image)
		Color(0.03, 0.06, 0.05, 1.0), # Night: moonlit dark pine
		Color(0.05, 0.11, 0.06, 1.0), # Dawn
		Color(0.06, 0.14, 0.07, 1.0)  # Noon
	]
	var fol_crown_cols := [
		Color(0.10, 0.22, 0.12, 1.0), # Noon: subtle sunward cedar crown
		Color(0.14, 0.12, 0.09, 1.0), # Sunset: warm dark silhouette canopy
		Color(0.05, 0.09, 0.07, 1.0), # Night
		Color(0.09, 0.18, 0.10, 1.0), # Dawn
		Color(0.10, 0.22, 0.12, 1.0)  # Noon
	]
	var fol_shadow_cols := [
		Color(0.03, 0.07, 0.04, 1.0), # Noon: deep dense viridian shadow floor
		Color(0.03, 0.03, 0.03, 1.0), # Sunset: deep dark silhouette shadow
		Color(0.015, 0.03, 0.02, 1.0), # Night
		Color(0.025, 0.05, 0.03, 1.0), # Dawn
		Color(0.03, 0.07, 0.04, 1.0)  # Noon
	]
	var grass_tops := [
		Color("#142412"), # Noon: deep rich agricultural turf
		Color("#1A1812"), # Sunset: dark silhouette turf
		Color("#08100A"), # Night
		Color("#121E10"), # Dawn
		Color("#142412")
	]
	var wall_cols := [
		Color("#383E48"), # Noon: weathered civil engineering concrete
		Color("#3D343E"), # Sunset: warm concrete
		Color("#181A20"), # Night
		Color("#32353E"), # Dawn
		Color("#383E48")
	]

	var cur_fol_base: Color = fol_base_cols[idx].lerp(fol_base_cols[idx + 1], s)
	var cur_fol_crown: Color = fol_crown_cols[idx].lerp(fol_crown_cols[idx + 1], s)
	var cur_fol_shadow: Color = fol_shadow_cols[idx].lerp(fol_shadow_cols[idx + 1], s)
	var cur_grass_top: Color = grass_tops[idx].lerp(grass_tops[idx + 1], s)
	var cur_wall_col: Color = wall_cols[idx].lerp(wall_cols[idx + 1], s)

	var rck_cols := [Color("#4A5260"), Color("#524854"), Color("#20242E"), Color("#484250"), Color("#4A5260")]
	var l2_cols  := [Color("#353C4A"), Color("#403644"), Color("#181C26"), Color("#323640"), Color("#353C4A")]
	var l3_cols  := [Color("#252C38"), Color("#302634"), Color("#10141C"), Color("#242830"), Color("#252C38")]

	var cur_rck_col: Color = rck_cols[idx].lerp(rck_cols[idx + 1], s)
	var cur_l2_col: Color = l2_cols[idx].lerp(l2_cols[idx + 1], s)
	var cur_l3_col: Color = l3_cols[idx].lerp(l3_cols[idx + 1], s)

	if is_instance_valid(hillside_foliage_mat):
		if hillside_foliage_mat is ShaderMaterial:
			hillside_foliage_mat.set_shader_parameter("sun_direction", env_sun_dir)
			hillside_foliage_mat.set_shader_parameter("sun_tint", cur_sun_col)
			hillside_foliage_mat.set_shader_parameter("foliage_base_color", cur_fol_base)
			hillside_foliage_mat.set_shader_parameter("foliage_crown_color", cur_fol_crown)
			hillside_foliage_mat.set_shader_parameter("foliage_shadow_color", cur_fol_shadow)
		elif "albedo_color" in hillside_foliage_mat:
			hillside_foliage_mat.albedo_color = cur_fol_base
	if is_instance_valid(hillside_rock_mat):
		hillside_rock_mat.albedo_color = cur_rck_col
	if is_instance_valid(cliff_mat):
		cliff_mat.set_shader_parameter("sun_direction", env_sun_dir)
		cliff_mat.set_shader_parameter("sun_tint", cur_sun_col)
		cliff_mat.set_shader_parameter("grass_top_color", cur_grass_top)
		cliff_mat.set_shader_parameter("grass_dark_color", cur_grass_top.darkened(0.20))
		cliff_mat.set_shader_parameter("stone_wall_color", cur_wall_col)
		cliff_mat.set_shader_parameter("stone_shadow_color", cur_wall_col.darkened(0.25))
		cliff_mat.set_shader_parameter("rock_sun_color", cur_l2_col.lightened(0.25))
		cliff_mat.set_shader_parameter("rock_shadow_color", cur_l2_col.darkened(0.20))
		cliff_mat.set_shader_parameter("forest_ridge_color", cur_fol_crown.darkened(0.25))
		cliff_mat.set_shader_parameter("horizon_fog_color", cur_sky_hor)
	if is_instance_valid(mountain_peak_mat):
		mountain_peak_mat.set_shader_parameter("sun_direction", env_sun_dir)
		mountain_peak_mat.set_shader_parameter("sun_tint", cur_sun_col)
		mountain_peak_mat.set_shader_parameter("horizon_fog_color", cur_sky_hor)
	if is_instance_valid(hillside_layer2_mat):
		hillside_layer2_mat.albedo_color = cur_l2_col
	if is_instance_valid(hillside_layer3_mat):
		hillside_layer3_mat.albedo_color = cur_l3_col

	# Update Camera-Anchored Horizon Mountains Palette (Sunset: #7A7CA8, Night: #2D3552)
	if is_instance_valid(horizon_manager):
		var horizon_palette := [Color("#6A729B"), Color("#7A7CA8"), Color("#2D3552"), Color("#4A5578"), Color("#6A729B")]
		var cur_hm_col: Color = horizon_palette[idx].lerp(horizon_palette[idx + 1], s)
		horizon_manager.set_horizon_palette(cur_hm_col)

func _process_player_motion(delta: float) -> void:
	# Drift Exit Slingshot Boost
	if prev_drift_active and not drift_active:
		var slingshot_bonus: float = 14.0 + (drift_charge * 0.08)
		player_speed += slingshot_bonus
		drift_charge = 0.0
		screen_shake = 0.22
		score += 600
	prev_drift_active = drift_active

	# Target forward speed scaled per stage tier
	var stage_cruise: float = _get_stage_cruise_speed()
	var stage_boost: float = _get_stage_boost_speed()
	if boost_active:
		player_target_speed = stage_boost
	elif drift_active:
		player_target_speed = stage_cruise * 0.92
	else:
		player_target_speed = stage_cruise

	# Graze forward velocity burst (+10% over 0.4s)
	if graze_speed_kick_timer > 0.0:
		graze_speed_kick_timer -= delta
		player_target_speed *= 1.10

	# Two-tier nitro surge forward velocity
	if nitro_active:
		nitro_timer -= delta
		if nitro_timer <= 0.0:
			nitro_active = false
			nitro_speed_mult = 1.0
			_show_nitro_flames(false)
		else:
			player_target_speed = max(player_target_speed, stage_boost) * nitro_speed_mult
			player_speed = lerp(player_speed, player_target_speed, 8.0 * delta)

	if not nitro_active:
		player_speed = lerp(player_speed, player_target_speed, 5.0 * delta)
	player_z -= player_speed * delta

	# Lateral velocity with momentum
	var max_lat: float = MAX_LAT_SPEED * (1.30 if drift_active else 1.0)
	var target_lat_vel: float = steer_input * max_lat
	player_lat_velocity = lerp(player_lat_velocity, target_lat_vel, (9.0 if drift_active else 14.0) * delta)
	player_lane_x += player_lat_velocity * delta

	# Road boundaries & Guardrail Contact Spark Wedges
	var scraping_side: float = 0.0
	if player_lane_x > LATERAL_LIMIT:
		player_lane_x = LATERAL_LIMIT
		player_lat_velocity = -4.0
		screen_shake = 0.15
		scraping_side = 1.0
	elif player_lane_x < -LATERAL_LIMIT:
		player_lane_x = -LATERAL_LIMIT
		player_lat_velocity = 4.0
		screen_shake = 0.15
		scraping_side = -1.0
	elif player_lane_x >= (LATERAL_LIMIT - 0.08):
		scraping_side = 1.0
	elif player_lane_x <= -(LATERAL_LIMIT - 0.08):
		scraping_side = -1.0

	if scraping_side != 0.0:
		is_scraping_guardrail = true
		spark_spawn_timer += delta
		if spark_spawn_timer >= 0.035:
			spark_spawn_timer = 0.0
			_emit_guardrail_sparks(scraping_side, delta)
	else:
		is_scraping_guardrail = false
		spark_spawn_timer = 0.0

	_update_car_transform()

func _process_suspension_and_vibration(delta: float) -> void:
	if not is_instance_valid(visual_rig):
		return

	var bank_rad: float = _sample_road_bank(player_z)

	# Authentic Arcade Driving Alignment: Car cruises naturally straight down road spline
	# Powerslide drift angle ONLY engages when player swipes down!
	var target_yaw: float = 0.0
	if drift_active:
		var drift_dir: float = sign(player_lat_velocity) if abs(player_lat_velocity) > 0.5 else sign(steer_input)
		target_yaw = -drift_dir * deg_to_rad(30.0)
		if is_instance_valid(smoke_left):
			smoke_left.emitting = true
			smoke_left.visible = true
		if is_instance_valid(smoke_right):
			smoke_right.emitting = true
			smoke_right.visible = true
	else:
		target_yaw = -steer_input * deg_to_rad(3.0) # Subtle natural steering lean only
		if is_instance_valid(smoke_left):
			smoke_left.emitting = false
		if is_instance_valid(smoke_right):
			smoke_right.emitting = false

	body_turn_yaw = lerp_angle(body_turn_yaw, target_yaw, (9.0 if drift_active else 18.0) * delta)
	visual_rig.rotation.y = body_turn_yaw

	# Dynamic Centrifugal Roll
	var target_roll: float = -player_lat_velocity * 0.014 + bank_rad * 0.30
	if drift_active:
		target_roll *= 1.3

	# Dynamic Pitch
	var target_pitch: float = 0.0
	if boost_active:
		target_pitch = deg_to_rad(2.5) # Squat
	elif drift_active:
		target_pitch = deg_to_rad(1.0)

	# Engine Micro-Rumble
	var engine_rumble: float = sin(Time.get_ticks_msec() * 0.028) * 0.005

	visual_rig.rotation.z = lerp_angle(visual_rig.rotation.z, target_roll, 12.0 * delta)
	visual_rig.rotation.x = lerp_angle(visual_rig.rotation.x, target_pitch, 10.0 * delta)
	visual_rig.rotation.y = body_turn_yaw
	visual_rig.position.y = engine_rumble

	# 2. Exhaust Pipe Vibration: Visibly jiggle on mounts during idle/cruise and lock rigid under full throttle
	var is_full_throttle: bool = boost_active or ((player_target_speed - player_speed) > 3.5)
	var tip_jiggle_x: float = 0.0
	var tip_jiggle_y: float = 0.0
	if not is_full_throttle and current_state == GameState.RACING:
		var t_jiggle: float = float(Time.get_ticks_msec())
		tip_jiggle_y = sin(t_jiggle * 0.048) * 0.018 + sin(t_jiggle * 0.082) * 0.008
		tip_jiggle_x = cos(t_jiggle * 0.036) * 0.012

	if is_instance_valid(exhaust_tip_l):
		exhaust_tip_l.position = Vector3(-0.42 + tip_jiggle_x, 0.28 + tip_jiggle_y, 1.95)
	if is_instance_valid(exhaust_tip_r):
		exhaust_tip_r.position = Vector3(0.42 - tip_jiggle_x, 0.28 + tip_jiggle_y, 1.95)

	# 3. TAILLIGHT SPEED TRAILS: Length stretches from 0.0m at 100 km/h to 1.8m at 200 km/h
	if is_instance_valid(trail_left) and is_instance_valid(trail_right):
		var kmh_val: float = player_speed * 3.6
		var trail_t: float = clamp((kmh_val - 100.0) / 100.0, 0.0, 1.0)
		var current_trail_len: float = trail_t * 1.8
		if current_trail_len > 0.02 and current_state == GameState.RACING:
			trail_left.visible = true
			trail_right.visible = true
			trail_mesh_l.size = Vector2(0.28, current_trail_len)
			trail_mesh_r.size = Vector2(0.28, current_trail_len)
			trail_left.position = Vector3(-0.52, 0.58, 1.55 + (current_trail_len * 0.5))
			trail_right.position = Vector3(0.52, 0.58, 1.55 + (current_trail_len * 0.5))
		else:
			trail_left.visible = false
			trail_right.visible = false

	# 4. SPOILER WINGTIP VORTICES (Aerodynamic Vapor Needles)
	# Trigger: Active ONLY when vehicle velocity > 165 km/h, trailing 3.2m needle with fast 18 FPS turbulence jitter
	if is_instance_valid(spoiler_streak_l) and is_instance_valid(spoiler_streak_r):
		var kmh_val: float = player_speed * 3.6
		if kmh_val > 165.0 and current_state == GameState.RACING:
			spoiler_streak_l.visible = true
			spoiler_streak_r.visible = true
			var streak_t: float = clamp((kmh_val - 165.0) / 45.0, 0.45, 1.0)

			# Fast keyframe jitter updated on an 18 FPS timer to simulate stepped anime wind turbulence
			var step_18fps: int = int(floor(Time.get_ticks_msec() * 0.018))
			var jx: float = (fposmod(sin(float(step_18fps) * 12.9898) * 43758.5453, 1.0) - 0.5) * 0.022
			var jy: float = (fposmod(sin(float(step_18fps + 47) * 78.233) * 43758.5453, 1.0) - 0.5) * 0.025
			var j_rot: float = (fposmod(sin(float(step_18fps + 109) * 39.425) * 43758.5453, 1.0) - 0.5) * 0.075

			spoiler_streak_l.position = Vector3(-0.84 + jx, 1.05 + jy, 1.82)
			spoiler_streak_r.position = Vector3(0.84 - jx, 1.05 - jy, 1.82)
			spoiler_streak_l.scale = Vector3(1.0 + j_rot * 0.4, 1.0 - j_rot * 0.4, streak_t)
			spoiler_streak_r.scale = Vector3(1.0 - j_rot * 0.4, 1.0 + j_rot * 0.4, streak_t)
			spoiler_streak_l.rotation = Vector3(jy * 0.4, jx * 0.4, j_rot)
			spoiler_streak_r.rotation = Vector3(-jy * 0.4, -jx * 0.4, -j_rot)
		else:
			spoiler_streak_l.visible = false
			spoiler_streak_r.visible = false

func _process_crashed_state(delta: float) -> void:
	if is_instance_valid(trail_left):
		trail_left.visible = false
		trail_right.visible = false
	if is_instance_valid(spoiler_streak_l):
		spoiler_streak_l.visible = false
		spoiler_streak_r.visible = false
	player_speed = lerp(player_speed, 0.0, 3.5 * delta)
	player_z -= player_speed * delta
	spinout_angle += 720.0 * delta

	var spinning := player_speed > 2.0
	if is_instance_valid(smoke_left):
		smoke_left.emitting = spinning
		smoke_left.visible = spinning
	if is_instance_valid(smoke_right):
		smoke_right.emitting = spinning
		smoke_right.visible = spinning

	if is_instance_valid(visual_rig):
		visual_rig.rotation.x = deg_to_rad(-12.0)

	_update_car_transform()

	if crash_orbit_active:
		var real_delta: float = delta / max(Engine.time_scale, 0.01)
		crash_orbit_timer -= real_delta
		crash_orbit_angle += 220.0 * real_delta
		if crash_orbit_timer <= 0.0:
			crash_orbit_active = false
			Engine.time_scale = 1.0
			_show_tankobon_cover_screen()

func _trigger_crash(traffic_data: TrafficVehicleData, _reason: String = "CRASHED!") -> void:
	current_state = GameState.CRASHED
	screen_shake = 0.70
	hud_crash_flash.color = Color(1.0, 0.1, 0.1, 0.75)

	if is_instance_valid(crash_audio_player) and stream_car_crash:
		crash_audio_player.pitch_scale = randf_range(0.96, 1.04)
		crash_audio_player.play()
	if is_instance_valid(hud_rival_alert):
		hud_rival_alert.visible = false
	if is_instance_valid(hud_hazard_banner):
		hud_hazard_banner.visible = false
	if is_instance_valid(hazard_tween) and hazard_tween.is_valid():
		hazard_tween.kill()
	if is_instance_valid(cutin_container):
		cutin_container.visible = false
	if is_instance_valid(trail_left):
		trail_left.visible = false
		trail_right.visible = false
	if is_instance_valid(spoiler_streak_l):
		spoiler_streak_l.visible = false
		spoiler_streak_r.visible = false

	# Slow-mo camera orbit initiation (0.35s slow-mo duration at Engine.time_scale = 0.15)
	crash_orbit_active = true
	crash_orbit_timer = 0.35
	crash_orbit_angle = 0.0
	tankobon_shown = false
	Engine.time_scale = 0.15

	if traffic_data:
		traffic_data.current_z -= 25.0

func _show_tankobon_cover_screen() -> void:
	tankobon_shown = true
	if is_instance_valid(hud_restart_banner):
		hud_restart_banner.visible = false
	if is_instance_valid(hud_tankobon_cover):
		hud_tankobon_cover.visible = true

	var final_score_int: int = int(displayed_score)
	var top_kmh: int = int(round(top_speed_achieved * 3.6))
	var grade: String = "RETIRED"
	var grade_color: Color = Color("#FF1E27")

	if final_score_int >= 12000 or near_miss_count >= 15:
		grade = "S"
		grade_color = Color("#FFD700")
	elif final_score_int >= 6000 or near_miss_count >= 8:
		grade = "A"
		grade_color = Color("#FF5964")
	elif final_score_int >= 2000:
		grade = "B"
		grade_color = Color("#00E5FF")

	if is_instance_valid(hud_grade_badge):
		hud_grade_badge.text = grade
		hud_grade_badge.add_theme_color_override("font_color", grade_color)
		hud_grade_badge.scale = Vector2(3.2, 3.2)
		var stamp_tw := hud_grade_badge.create_tween()
		stamp_tw.tween_property(hud_grade_badge, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_instance_valid(hud_comic_stats_label):
		hud_comic_stats_label.text = "RUN LOG:\n  TOTAL SCORE: %d PTS\n  TOP SPEED: %d KM/H\n  NEAR MISSES: %d GRAZES\n  FINAL COMBO: x%d CHAIN" % [
			final_score_int, top_kmh, near_miss_count, combo_multiplier
		]

# ==============================================================================
# 12. TRAFFIC AI (NO CLIPPING, HORIZON SPAWN, ACCURATE HITBOXES)
# ==============================================================================
func _get_adjacent_lane(current_lane: float) -> float:
	var idx: int = 0
	var min_diff: float = 999.0
	for i in range(LANE_OFFSETS.size()):
		var diff: float = abs(LANE_OFFSETS[i] - current_lane)
		if diff < min_diff:
			min_diff = diff
			idx = i
	if idx <= 0:
		return LANE_OFFSETS[1]
	elif idx >= LANE_OFFSETS.size() - 1:
		return LANE_OFFSETS[LANE_OFFSETS.size() - 2]
	else:
		return LANE_OFFSETS[idx + (1 if randf() > 0.5 else -1)]

func _spawn_floating_graze_badge(world_pos: Vector3, pts: int) -> void:
	if not is_instance_valid(hud_graze_container) or not is_instance_valid(follow_cam):
		return
	var screen_pos: Vector2 = follow_cam.unproject_position(world_pos)
	var badge := Label.new()
	badge.text = "GRAZE! +" + str(pts)
	badge.position = screen_pos + Vector2(randf_range(-30, 30), randf_range(-40, -10))
	badge.add_theme_font_size_override("font_size", 38)
	badge.add_theme_color_override("font_color", Color("#FFF01F"))
	badge.add_theme_color_override("font_shadow_color", Color("#D62828"))
	badge.add_theme_constant_override("shadow_offset_x", 3)
	badge.add_theme_constant_override("shadow_offset_y", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_graze_container.add_child(badge)

	var tw := badge.create_tween()
	tw.set_parallel(true)
	tw.tween_property(badge, "position:y", badge.position.y - 70.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.25, 1.25), 0.15).from(Vector2(0.5, 0.5))
	tw.chain().tween_property(badge, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(badge.queue_free)

func _play_graze_chime() -> void:
	if is_instance_valid(graze_audio_player) and stream_gear_upshift:
		graze_audio_player.pitch_scale = clamp(1.25 + float(combo_multiplier) * 0.22, 1.25, 2.8)
		graze_audio_player.play()

func _play_scrape_sound() -> void:
	if is_instance_valid(scrape_audio_player) and stream_car_crash:
		if not scrape_audio_player.playing:
			scrape_audio_player.pitch_scale = randf_range(1.6, 2.2)
			scrape_audio_player.play()

func _play_nitro_sound() -> void:
	if is_instance_valid(nitro_audio_player) and stream_rival_entry:
		nitro_audio_player.pitch_scale = 1.35 if nitro_tier == 2 else 1.15
		nitro_audio_player.play()

func _show_nitro_flames(show: bool) -> void:
	if not is_instance_valid(exhaust_flame_l) or not is_instance_valid(exhaust_flame_r):
		return
	if show:
		exhaust_flame_l.material_override = nitro_flame_mat if nitro_flame_mat else toon_flame_mat
		exhaust_flame_r.material_override = nitro_flame_mat if nitro_flame_mat else toon_flame_mat
		exhaust_flame_l.visible = true
		exhaust_flame_r.visible = true
		var flame_scale: Vector3 = (Vector3(2.2, 2.2, 2.2) if nitro_tier == 2 else Vector3(1.6, 1.6, 1.6)) * randf_range(0.9, 1.2)
		exhaust_flame_l.scale = flame_scale
		exhaust_flame_r.scale = flame_scale
		if is_instance_valid(exhaust_bumper_flash):
			exhaust_bumper_flash.light_color = Color("#00E5FF")
			exhaust_bumper_flash.light_energy = 6.0
			exhaust_bumper_flash.visible = true
	else:
		exhaust_flame_l.material_override = toon_flame_mat
		exhaust_flame_r.material_override = toon_flame_mat
		exhaust_flame_l.visible = false
		exhaust_flame_r.visible = false
		if is_instance_valid(exhaust_bumper_flash):
			exhaust_bumper_flash.light_color = Color("#FF9500")
			exhaust_bumper_flash.visible = false

func _trigger_overdrive_shockwave() -> void:
	# 1. Force traffic within 18m ahead to swerve into outer lanes
	for td in traffic_pool:
		var dist_ahead: float = player_z - td.current_z
		if dist_ahead > 0.0 and dist_ahead < 18.0 and not td.is_roadblock:
			var outer_lane: float = -3.8 if td.lane_offset < 0.0 else 3.8
			td.is_switching = true
			td.switch_start_x = td.lane_offset
			td.switch_target_x = outer_lane
			td.switch_progress = 0.0
			_trigger_traffic_flinch(td)

	# 2. Outward expanding comic ink shockwave ring
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.2
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("#00E5FF")
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring_mesh
	ring_node.material_override = ring_mat
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_instance_valid(car_root):
		ring_node.global_transform = Transform3D(Basis(), car_root.global_position + Vector3(0.0, 0.1, 0.0))
	add_child(ring_node)

	var tw := ring_node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring_node, "scale", Vector3(14.0, 1.0, 14.0), 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.40)
	tw.chain().tween_callback(ring_node.queue_free)

func _spawn_floating_comic_text(world_pos: Vector3, text: String, color: Color = Color("#FFF01F"), shadow_color: Color = Color("#000000"), font_size: int = 38) -> void:
	if not is_instance_valid(hud_graze_container) or not is_instance_valid(follow_cam):
		return
	var screen_pos: Vector2 = follow_cam.unproject_position(world_pos)
	var badge := Label.new()
	badge.text = text
	badge.position = screen_pos + Vector2(randf_range(-25, 25), randf_range(-35, -15))
	badge.add_theme_font_size_override("font_size", font_size)
	badge.add_theme_color_override("font_color", color)
	badge.add_theme_color_override("font_outline_color", Color("#000000"))
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_color_override("font_shadow_color", shadow_color)
	badge.add_theme_constant_override("shadow_offset_x", 3)
	badge.add_theme_constant_override("shadow_offset_y", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_graze_container.add_child(badge)

	var tw := badge.create_tween()
	tw.set_parallel(true)
	tw.tween_property(badge, "position:y", badge.position.y - 75.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.2, 1.2), 0.15).from(Vector2(0.6, 0.6))
	tw.chain().tween_property(badge, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(badge.queue_free)

func _trigger_traffic_scrape(td: TrafficVehicleData, effective_x: float) -> void:
	var side: float = sign(player_lane_x - effective_x)
	if side == 0.0: side = 1.0
	player_lat_velocity = side * 3.5
	player_lane_x += side * 0.06
	screen_shake = max(screen_shake, 0.14)
	_emit_guardrail_sparks(side, 0.016)
	_play_scrape_sound()

func _try_activate_double_tap_nitro() -> void:
	if nitro_charge < 50.0:
		return
	nitro_active = true
	if nitro_charge >= 99.5:
		# Tier 2: 100% full charge Overdrive
		nitro_tier = 2
		nitro_timer = 2.2
		nitro_speed_mult = 1.25
		cam_fov_punch = 5.0
		cam_fov_punch_timer = 0.45
		screen_shake = max(screen_shake, 0.35)
		_trigger_overdrive_shockwave()
		if is_instance_valid(car_root):
			_spawn_floating_comic_text(car_root.global_position + Vector3(0.0, 2.0, 0.0), "MAX OVERDRIVE!!", Color("#00E5FF"), Color("#000000"), 46)
	else:
		# Tier 1: 50% to 99% charge Nitro Surge
		nitro_tier = 1
		nitro_timer = 1.4
		nitro_speed_mult = 1.18
		cam_fov_punch = 3.5
		cam_fov_punch_timer = 0.35
		screen_shake = max(screen_shake, 0.22)
		if is_instance_valid(car_root):
			_spawn_floating_comic_text(car_root.global_position + Vector3(0.0, 2.0, 0.0), "NITRO SURGE!", Color("#00E5FF"), Color("#000000"), 42)

	nitro_charge = 0.0
	_play_nitro_sound()
	_show_nitro_flames(true)

func _apply_graze_rewards(td: TrafficVehicleData) -> void:
	td.grazed = true
	td.graze_grace_active = true
	td.graze_grace_timer = 0.35
	near_miss_count += 1
	combo_multiplier = mini(combo_multiplier + 1, 4)
	combo_timer = 2.5
	_trigger_graze_microfreeze()
	_trigger_traffic_flinch(td)

	# High-Reward Graze Payoffs:
	var boost_inj: float = 50.0 if drift_active else 30.0
	nitro_charge = min(100.0, nitro_charge + boost_inj)
	drift_charge = min(100.0, drift_charge + boost_inj)
	graze_speed_kick_timer = 0.4
	player_speed += player_speed * 0.04
	cam_fov_punch = 2.0
	cam_fov_punch_timer = 0.15
	_play_graze_chime()

	var g_msg: String = "DRIFT GRAZE! +50%" if drift_active else "GRAZE! +30% BOOST"
	_spawn_floating_comic_text(td.instance.global_position + Vector3(0.0, 1.8, 0.0), g_msg, Color("#FFF01F"), Color("#000000"), 36)

func _process_traffic_and_collisions(delta: float) -> void:
	var t_ms: float = Time.get_ticks_msec() * 0.001

	for td in traffic_pool:
		# Collision immunity grace timer
		if td.graze_grace_active:
			td.graze_grace_timer -= delta
			if td.graze_grace_timer <= 0.0:
				td.graze_grace_active = false

		# Adaptive Following: Check distance to vehicle directly ahead in same lane
		var closest_ahead_gap: float = 999.0
		var ahead_speed: float = td.speed
		for other in traffic_pool:
			if other != td and abs(other.lane_offset - td.lane_offset) < 1.0:
				var dist_ahead: float = td.current_z - other.current_z # Positive if other is ahead
				if dist_ahead > 0.0 and dist_ahead < closest_ahead_gap:
					closest_ahead_gap = dist_ahead
					ahead_speed = other.speed

		var active_speed: float = td.speed
		if closest_ahead_gap < 14.0:
			active_speed = min(td.speed, ahead_speed * 0.85)
		elif closest_ahead_gap < 28.0:
			active_speed = min(td.speed, ahead_speed)

		# Disrupted civilian dynamics (spinout slide across lanes)
		if td.is_disrupted and not td.is_roadblock and not td.roadblock_crashing:
			td.lane_offset += td.disrupt_slide_speed * delta
			if abs(td.lane_offset) > LATERAL_LIMIT:
				td.lane_offset = clamp(td.lane_offset, -LATERAL_LIMIT, LATERAL_LIMIT)
				td.disrupt_slide_speed *= -0.5
				td.disrupt_spin_rate *= -0.6
			td.disrupt_yaw += td.disrupt_spin_rate * delta
			td.disrupt_spin_rate = lerp(td.disrupt_spin_rate, 0.0, 3.2 * delta)
			td.disrupt_slide_speed = lerp(td.disrupt_slide_speed, 0.0, 2.5 * delta)
			td.speed = lerp(td.speed, 8.0, 2.0 * delta)
			active_speed = td.speed

		# Police roadblock cohesive crash sequence
		if td.roadblock_crashing:
			if not td.roadblock_has_impacted:
				# Pre-impact: Both cruisers steer smoothly together to close the gap
				var target_side: float = -0.75 if td.lane_offset < 0.0 else 0.75
				td.lane_offset = move_toward(td.lane_offset, target_side, 9.5 * delta)
				var converge_yaw: float = deg_to_rad(30.0 * (-1.0 if target_side > 0.0 else 1.0))
				td.disrupt_yaw = lerp_angle(td.disrupt_yaw, converge_yaw, 8.0 * delta)
			else:
				# Post-impact: Metal collision, rebound bounce, crumple spin, and screeching deceleration
				td.lane_offset += td.disrupt_slide_speed * delta
				td.disrupt_yaw += td.disrupt_spin_rate * delta
				td.disrupt_spin_rate = lerp(td.disrupt_spin_rate, 0.0, 3.5 * delta)
				td.disrupt_slide_speed = lerp(td.disrupt_slide_speed, 0.0, 3.5 * delta)
				td.speed = lerp(td.speed, 0.0, 3.0 * delta)
				if td.speed < 1.0:
					td.speed = 0.0
				active_speed = td.speed

		# Police roadblock stops completely as barrier once settled
		if td.is_roadblock and td.speed <= 0.1:
			active_speed = 0.0

		# Police light strobe animation
		if td.is_police or td.model_type in ["police", "police_interceptor"]:
			td.strobe_timer += delta * 14.0
			var strobe_phase: bool = int(td.strobe_timer) % 2 == 0
			if is_instance_valid(td.strobe_mat_r):
				if td.strobe_mat_r is ShaderMaterial:
					td.strobe_mat_r.set_shader_parameter("base_paint_color", Color(1.0, 0.05, 0.05) if strobe_phase else Color(0.15, 0.01, 0.01))
				elif td.strobe_mat_r is StandardMaterial3D:
					td.strobe_mat_r.albedo_color = Color(1.0, 0.05, 0.05) if strobe_phase else Color(0.15, 0.01, 0.01)
			if is_instance_valid(td.strobe_mat_b):
				if td.strobe_mat_b is ShaderMaterial:
					td.strobe_mat_b.set_shader_parameter("base_paint_color", Color(0.05, 0.35, 1.0) if not strobe_phase else Color(0.01, 0.05, 0.15))
				elif td.strobe_mat_b is StandardMaterial3D:
					td.strobe_mat_b.albedo_color = Color(0.05, 0.35, 1.0) if not strobe_phase else Color(0.01, 0.05, 0.15)

		td.current_z -= active_speed * delta

		# Late Lane Switchers: Merge to adjacent lane 35-55m ahead of player
		if td.is_lane_switcher and not td.is_switching and not td.is_disrupted and not td.is_roadblock:
			var p_gap: float = player_z - td.current_z
			if p_gap >= 35.0 and p_gap <= 55.0:
				td.is_switching = true
				td.switch_start_x = td.lane_offset
				td.switch_target_x = _get_adjacent_lane(td.lane_offset)
				td.switch_progress = 0.0

		if td.is_switching:
			td.switch_progress += delta / 1.2
			var t: float = clamp(td.switch_progress, 0.0, 1.0)
			var smooth_t: float = smoothstep(0.0, 1.0, t)
			td.lane_offset = lerp(td.switch_start_x, td.switch_target_x, smooth_t)
			var merge_dir: float = sign(td.switch_target_x - td.switch_start_x)
			var tilt_angle: float = deg_to_rad(4.0) * merge_dir * sin(smooth_t * PI)
			if is_instance_valid(td.mesh_root):
				td.mesh_root.rotation.z = -tilt_angle
			if td.switch_progress >= 1.0:
				td.is_switching = false
				if is_instance_valid(td.mesh_root):
					td.mesh_root.rotation.z = 0.0

		# Mathematical Anti-Penetration Guarantee: Never allow vehicles to overlap
		if closest_ahead_gap < 6.0 and not td.is_roadblock:
			td.current_z += (6.0 - closest_ahead_gap)

		# Highway vibration
		if is_instance_valid(td.mesh_root):
			td.mesh_root.position.y = sin(t_ms * 20.0 + td.bob_seed) * 0.005

		# Civilian flinch lateral swerve & taillight restore
		if td.flinch_timer > 0.0:
			td.flinch_timer -= delta
			td.flinch_swerve_offset = lerp(td.flinch_swerve_offset, td.flinch_target_swerve, 12.0 * delta)
			if td.flinch_timer <= 0.0:
				td.flinch_target_swerve = 0.0
				if is_instance_valid(td.taillight_mat):
					if td.taillight_mat is ShaderMaterial:
						td.taillight_mat.set_shader_parameter("emissive_energy", 0.5)
					elif td.taillight_mat is StandardMaterial3D:
						(td.taillight_mat as StandardMaterial3D).emission_energy_multiplier = 0.5
		else:
			td.flinch_swerve_offset = lerp(td.flinch_swerve_offset, 0.0, 6.0 * delta)

		# Recycle vehicles that fall > 35m behind player with Biome-Scaled Density
		if td.current_z > player_z + 35.0:
			var b_cfg: Dictionary = BIOMES.get(current_biome_id, BIOMES["shuto_dusk"])
			var min_dist: float = b_cfg.get("traffic_min_dist", 180.0)
			var max_dist: float = b_cfg.get("traffic_max_dist", 260.0)
			var target_spawn_z: float = player_z - randf_range(min_dist, max_dist)
			if fork_active and target_spawn_z <= active_fork_mid_z + 40.0 and target_spawn_z >= active_fork_exit_z - 40.0:
				target_spawn_z -= 140.0
			td.lane_offset = _find_clear_lane(target_spawn_z)
			td.current_z = target_spawn_z
			td.grazed = false
			td.graze_grace_active = false
			td.graze_grace_timer = 0.0
			td.is_lane_switcher = (randf() < 0.25)
			td.is_switching = false
			td.switch_progress = 0.0
			td.is_disrupted = false
			td.is_roadblock = false
			td.is_police = false
			td.roadblock_crashing = false
			td.roadblock_has_impacted = false
			td.disrupt_yaw = 0.0
			td.disrupt_slide_speed = 0.0
			td.disrupt_spin_rate = 0.0
			td.flinch_timer = 0.0
			td.flinch_swerve_offset = 0.0
			td.flinch_target_swerve = 0.0
			if is_instance_valid(td.taillight_mat):
				if td.taillight_mat is ShaderMaterial:
					td.taillight_mat.set_shader_parameter("emissive_energy", 0.5)
				elif td.taillight_mat is StandardMaterial3D:
					(td.taillight_mat as StandardMaterial3D).emission_energy_multiplier = 0.5
			td.speed = TRAFFIC_CONFIGS[td.model_type]["speed"]
			if is_instance_valid(td.mesh_root):
				td.mesh_root.rotation.z = 0.0

		_snap_traffic_to_road(td)

		# TRUE PHYSICAL COLLISION & LATERAL INSET
		var dz: float = abs(td.current_z - player_z)
		var effective_x: float = td.lane_offset + td.flinch_swerve_offset
		var dx: float = abs(effective_x - player_lane_x)

		# Inset the lateral (X-axis) width of the player's fatal crash hitbox by 0.12m on left and right edges
		var fatal_crash_limit_x: float = (HERO_HALF_W - 0.12) + td.half_w
		var side_rub_limit_x: float = HERO_HALF_W + td.half_w
		var crash_limit_z: float = HERO_HALF_L + td.half_l

		# Instant Physical Impact -> Scrape or Crash!
		if dz < crash_limit_z and dx < side_rub_limit_x:
			if td.is_roadblock and not td.graze_grace_active:
				_trigger_crash(td, "CRASHED INTO ROADBLOCK!")
				return
			elif td.graze_grace_active or dx >= fatal_crash_limit_x:
				# Non-fatal glancing scrape / graze ghost exit clip!
				_trigger_traffic_scrape(td, effective_x)
			else:
				# Direct rear-end impact -> Fatal CRASH!
				_trigger_crash(td, "CRASHED!")
				return

		# Roadblock & Graze Scoring
		elif not td.grazed and dz < (crash_limit_z + 0.90) and dx < (side_rub_limit_x + 0.90):
			if td.is_roadblock:
				var pts: int = 2500 * combo_multiplier
				score += pts
				hud_combo_label.text = "⚡ ROADBLOCK ESCAPE! +" + str(pts) + " ⚡"
				hud_combo_label.modulate = Color(1.0, 0.85, 0.1, 1.0)
				_spawn_floating_graze_badge(td.instance.global_position, pts)
				_apply_graze_rewards(td)
			elif td.is_disrupted:
				var pts: int = 800 * combo_multiplier
				score += pts
				hud_combo_label.text = ("🔥 FEVER! x" + str(combo_multiplier) if combo_multiplier >= 4 else "x" + str(combo_multiplier) + " CHAIN!")
				hud_combo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_spawn_floating_graze_badge(td.instance.global_position, pts)
				_apply_graze_rewards(td)
			elif dz < (crash_limit_z + 0.60) and dx < (side_rub_limit_x + 0.60):
				var pts: int = 250 * combo_multiplier
				score += pts
				hud_combo_label.text = ("🔥 FEVER! x" + str(combo_multiplier) if combo_multiplier >= 4 else ("x" + str(combo_multiplier) + " CHAIN!" if combo_multiplier > 1 else "GRAZE!"))
				hud_combo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_spawn_floating_graze_badge(td.instance.global_position, pts)
				_apply_graze_rewards(td)
				if patrol_evasion_active:
					patrol_evaded_cars += 1
					if patrol_evaded_cars >= 3:
						patrol_evasion_active = false
						score += 1000
						combo_multiplier += 1
						combo_timer = 3.5
						_spawn_floating_smash_badge(car_root.global_position + Vector3(0.0, 2.2, 0.0), 1000)
						_trigger_hazard_banner("✨ PURSUIT EVADED! +1,000 PTS ✨")
						_trigger_radio_chatter("TACHIBANA SPOTTER", "Pursuit evaded! Clean escape through traffic!", Color("#00FF88"))

func _trigger_graze_microfreeze() -> void:
	Engine.time_scale = 0.08
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.035)
	tw.tween_callback(func(): Engine.time_scale = 1.0)
	_bounce_combo_badge()

func _bounce_combo_badge() -> void:
	if not is_instance_valid(hud_combo_container):
		return
	hud_combo_container.visible = true
	hud_combo_container.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(hud_combo_container, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process_skid_marks(delta: float) -> void:
	# 1. Update active pooled skid marks
	for sd in skid_pool:
		if sd.time_left > 0.0:
			sd.time_left -= delta
			if sd.time_left <= 0.0:
				if is_instance_valid(sd.node):
					sd.node.visible = false
			else:
				var alpha_factor: float = clamp(sd.time_left / 3.0, 0.0, 1.0)
				if is_instance_valid(sd.node):
					sd.node.transparency = (1.0 - alpha_factor) * 0.75

	# 2. Drop new discrete skid points only when drift_active == true
	if drift_active and current_state == GameState.RACING:
		if abs(player_z - last_skid_drop_z) >= 0.90:
			last_skid_drop_z = player_z
			_spawn_skid_pair()

func _spawn_skid_pair() -> void:
	if not is_instance_valid(car_root) or skid_pool.is_empty():
		return
	var car_trans := car_root.global_transform
	var right_dir := car_trans.basis.x.normalized()
	var center_pos := car_trans.origin + (car_trans.basis.z * 1.25)
	center_pos.y = 0.022

	for side in [-0.76, 0.76]:
		var sd := skid_pool[skid_pool_idx]
		skid_pool_idx = (skid_pool_idx + 1) % SKID_POOL_SIZE

		sd.node.global_transform = Transform3D(car_trans.basis, center_pos + (right_dir * side))
		sd.node.transparency = 0.0
		sd.node.visible = true
		sd.time_left = 3.0

# ==============================================================================
# 12. STEPPED ANIME TIRE SMOKE & EXHAUST BACKFIRES & TRAFFIC FLINCH
# ==============================================================================
func _spawn_stepped_smoke_puffs() -> void:
	if not is_instance_valid(car_root) or not is_raining or water_spray_pool.is_empty():
		return
	var car_trans := car_root.global_transform
	var right_dir := car_trans.basis.x.normalized()
	var center_pos := car_trans.origin + (car_trans.basis.z * 1.25)

	if not water_spray_shader:
		water_spray_shader = load("res://shaders/anime_water_spray.gdshader")
	if not water_spray_mat:
		water_spray_mat = ShaderMaterial.new()
		water_spray_mat.shader = water_spray_shader

	for side in [-0.76, 0.76]:
		var spray := water_spray_pool[water_spray_idx]
		water_spray_idx = (water_spray_idx + 1) % WATER_SPRAY_POOL_SIZE

		spray.material_override = water_spray_mat
		spray.scale = Vector3(0.3, 0.3, 0.3)
		var spawn_pos: Vector3 = center_pos + (right_dir * side) + Vector3(randf_range(-0.06, 0.06), 0.35, randf_range(-0.05, 0.05))
		spray.position = spawn_pos
		spray.visible = true

		var tw := spray.create_tween()
		var target_pos := spawn_pos + (car_trans.basis.z * randf_range(2.4, 3.8)) + Vector3.UP * randf_range(0.35, 0.7)
		tw.set_parallel(true)
		tw.tween_property(spray, "position", target_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spray, "scale", Vector3(1.2, 1.6, 1.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			if is_instance_valid(spray):
				spray.visible = false
		)

func _emit_guardrail_sparks(side: float, _delta: float) -> void:
	if not is_instance_valid(car_root) or guardrail_spark_pool.is_empty():
		return
	if not spark_shader:
		spark_shader = load("res://shaders/guardrail_spark.gdshader")
	if not spark_mat:
		spark_mat = ShaderMaterial.new()
		spark_mat.shader = spark_shader

	var car_trans := car_root.global_transform
	var car_basis := car_trans.basis
	var contact_pos: Vector3 = car_trans.origin + (car_basis.x * (HERO_HALF_W * side)) + Vector3(0.0, 0.42 + randf_range(-0.08, 0.08), randf_range(-0.5, 0.8))

	for _i in range(2):
		var spark := guardrail_spark_pool[guardrail_spark_idx]
		guardrail_spark_idx = (guardrail_spark_idx + 1) % GUARDRAIL_SPARK_POOL_SIZE

		spark.material_override = spark_mat
		spark.position = contact_pos
		spark.scale = Vector3(1.0, 1.0, 1.0)
		spark.visible = true

		var spray_dir: Vector3 = (car_basis.z * randf_range(14.0, 26.0) + (car_basis.x * (-side * randf_range(2.0, 5.0))) + Vector3.UP * randf_range(1.0, 4.0))
		var target_pos: Vector3 = contact_pos + (spray_dir * 0.14)

		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target_pos, 0.14)
		tw.tween_property(spark, "scale", Vector3(0.1, 0.1, 0.1), 0.14)
		tw.chain().tween_callback(func():
			if is_instance_valid(spark):
				spark.visible = false
		)

func _spawn_exhaust_shockwave() -> void:
	# Purged: Exhaust shockwaves/donuts disabled per mandate
	return

func _spawn_diffuser_ground_sparks() -> void:
	if not is_instance_valid(car_root) or diffuser_spark_pool.is_empty():
		return
	var car_trans: Transform3D = car_root.global_transform
	var car_basis: Basis = car_trans.basis
	var spark_count: int = randi_range(2, 3)
	for _i in range(spark_count):
		var spark := diffuser_spark_pool[diffuser_spark_idx]
		diffuser_spark_idx = (diffuser_spark_idx + 1) % DIFFUSER_SPARK_POOL_SIZE

		spark.material_override = diffuser_spark_mat_white if randf() > 0.55 else diffuser_spark_mat_amber

		# Position scraped beneath the rear diffuser at tarmac level (y = 0.035)
		var spawn_pos: Vector3 = car_trans.origin + (car_basis.z * 1.95) + (car_basis.x * randf_range(-0.45, 0.45)) + Vector3(0.0, 0.035, 0.0)
		spark.position = spawn_pos
		spark.rotation = car_trans.basis.get_euler() + Vector3(0.0, randf_range(-0.35, 0.35), 0.0)
		spark.scale = Vector3(1.0, 1.0, 1.0)
		spark.visible = true

		# 3-frame micro-burst (0.05 seconds at 60 FPS)
		var spray_vec: Vector3 = (car_basis.z * randf_range(1.6, 2.8)) + (car_basis.x * randf_range(-0.35, 0.35))
		var target_pos: Vector3 = spawn_pos + spray_vec

		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target_pos, 0.05)
		tw.tween_property(spark, "scale", Vector3(0.15, 0.15, 0.15), 0.05)
		tw.chain().tween_callback(func():
			if is_instance_valid(spark):
				spark.visible = false
		)

func _trigger_manga_cutin(title_text: String) -> void:
	if cutin_active or cutin_cooldown > 0.0 or current_state == GameState.CRASHED:
		return
	cutin_active = true
	cutin_cooldown = 4.0
	if is_instance_valid(cutin_subviewport):
		cutin_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if is_instance_valid(cutin_title_label):
		cutin_title_label.text = title_text
	if is_instance_valid(cutin_container):
		cutin_container.visible = true
		cutin_container.position.x = 1120.0
		if is_instance_valid(cutin_tween) and cutin_tween.is_valid():
			cutin_tween.kill()
		cutin_tween = create_tween()
		cutin_tween.tween_property(cutin_container, "position:x", 700.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cutin_tween.tween_interval(0.75)
		cutin_tween.tween_property(cutin_container, "position:x", 1120.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		cutin_tween.tween_callback(func():
			if is_instance_valid(cutin_container):
				cutin_container.visible = false
			if is_instance_valid(cutin_subviewport):
				cutin_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			cutin_active = false
		)

func _process_weather_cycle(delta: float) -> void:
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = randf_range(35.0, 60.0)
		var next_w: int = (int(current_weather) + randi_range(1, 2)) % 3
		_set_weather_state(next_w as WeatherState)

func _set_weather_state(state: WeatherState) -> void:
	current_weather = state
	is_raining = (state == WeatherState.RAIN)
	is_snowing = (state == WeatherState.SNOW)

	if is_instance_valid(weather_transition_tween) and weather_transition_tween.is_valid():
		weather_transition_tween.kill()
	weather_transition_tween = create_tween()
	weather_transition_tween.set_parallel(true)

	# 1. Smoothly fade Rain 2D Overlay
	if is_instance_valid(hud_rain_overlay):
		hud_rain_overlay.visible = true
		var target_rain_a: float = 1.0 if is_raining else 0.0
		weather_transition_tween.tween_property(hud_rain_overlay, "modulate:a", target_rain_a, 2.5)

	# 2. Disable 2D Screen Snow Overlay (User requested true 3D particles, no screen overlay)
	if is_instance_valid(hud_snow_overlay):
		hud_snow_overlay.visible = false
		hud_snow_overlay.modulate.a = 0.0

	# 3. Smooth Road Wetness Reflection
	var target_wet: float = 0.85 if is_raining else (0.40 if is_snowing else 0.0)
	weather_transition_tween.tween_method(func(val: float):
		current_wet_refl = val
		if is_instance_valid(road_shader_mat):
			road_shader_mat.set_shader_parameter("is_wet", val > 0.05)
			road_shader_mat.set_shader_parameter("wet_reflectivity", val)
	, current_wet_refl, target_wet, 2.8)

	# 4. Foliage Leaf Particles (Green in Sunny, Japanese Scarlet Autumn in Rain)
	if is_instance_valid(leaf_particles):
		if state == WeatherState.SUNNY:
			if leaf_mat and leaf_green_tex:
				leaf_mat.albedo_texture = leaf_green_tex
			leaf_particles.emitting = true
			leaf_particles.amount = 45
			weather_transition_tween.tween_property(leaf_particles, "color:a", 1.0, 2.0)
			_trigger_radio_chatter("TACHIBANA SPOTTER", "Sun breaking through! Peak highway grip!", Color("#FFD000"))
		elif state == WeatherState.RAIN:
			if leaf_mat and leaf_autumn_tex:
				leaf_mat.albedo_texture = leaf_autumn_tex
			leaf_particles.emitting = true
			leaf_particles.amount = 75
			weather_transition_tween.tween_property(leaf_particles, "color:a", 1.0, 2.0)
			_trigger_radio_chatter("TACHIBANA SPOTTER", "Autumn storm on the bay! Watch for standing water puddles!", Color("#00E5FF"))
		elif state == WeatherState.SNOW:
			weather_transition_tween.tween_property(leaf_particles, "color:a", 0.0, 1.8)
			_trigger_radio_chatter("TACHIBANA SPOTTER", "Blizzard active! Snow flurries swirling across lanes!", Color("#C8E8FF"))

	# 5. 3-Layer True 3D World Space Snow Particles
	for snow_layer in [snow_layer_near, snow_layer_mid, snow_layer_far]:
		if is_instance_valid(snow_layer):
			if is_snowing:
				snow_layer.emitting = true
				var target_a: float = 0.90 if snow_layer == snow_layer_near else (0.80 if snow_layer == snow_layer_mid else 0.60)
				weather_transition_tween.tween_property(snow_layer, "color:a", target_a, 2.8)
			else:
				var t_fade := weather_transition_tween.tween_property(snow_layer, "color:a", 0.0, 2.0)
				if is_instance_valid(t_fade):
					t_fade.finished.connect(func(): if not is_snowing and is_instance_valid(snow_layer): snow_layer.emitting = false)

func set_weather_rain(enable: bool) -> void:
	_set_weather_state(WeatherState.RAIN if enable else WeatherState.SUNNY)

func _trigger_exhaust_backfire() -> void:
	backfire_timer = 0.075
	backfire_light_timer = 0.02
	if is_instance_valid(exhaust_flame_l):
		exhaust_flame_l.visible = true
		exhaust_flame_l.scale = (Vector3(1.6, 1.6, 1.6) if is_in_tunnel else Vector3(1.0, 1.0, 1.0)) * randf_range(0.85, 1.25)
	if is_instance_valid(exhaust_flame_r):
		exhaust_flame_r.visible = true
		exhaust_flame_r.scale = (Vector3(1.6, 1.6, 1.6) if is_in_tunnel else Vector3(1.0, 1.0, 1.0)) * randf_range(0.85, 1.25)
	if is_instance_valid(exhaust_bumper_flash):
		exhaust_bumper_flash.visible = true

	if is_in_tunnel:
		if is_instance_valid(tunnel_backfire_light):
			tunnel_backfire_light.light_energy = 4.5
			tunnel_backfire_light_timer = 0.06
		_play_proc_audio("pop")
		if is_instance_valid(car_root):
			var pop_badge := Label3D.new()
			pop_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			pop_badge.text = "💥 BANG!"
			pop_badge.font_size = 50
			pop_badge.modulate = Color("#FFE500")
			pop_badge.outline_modulate = Color("#D90429")
			pop_badge.outline_size = 12
			pop_badge.position = car_root.global_position + Vector3(randf_range(-0.4, 0.4), 0.5, 2.0)
			add_child(pop_badge)
			var tw := pop_badge.create_tween()
			tw.set_parallel(true)
			tw.tween_property(pop_badge, "position:y", pop_badge.position.y + 0.5, 0.28)
			tw.tween_property(pop_badge, "modulate:a", 0.0, 0.15).set_delay(0.13)
			tw.chain().tween_callback(pop_badge.queue_free)

func _trigger_traffic_flinch(td: TrafficVehicleData) -> void:
	if not td or td.is_roadblock or td.roadblock_crashing:
		return
	td.flinch_timer = 0.55
	# Instantly flash civilian vehicle brake lights to emission = 3.5 for 0.55 seconds
	if is_instance_valid(td.taillight_mat):
		if td.taillight_mat is ShaderMaterial:
			td.taillight_mat.set_shader_parameter("is_emissive", true)
			td.taillight_mat.set_shader_parameter("emissive_color", Color(1.0, 0.05, 0.05))
			td.taillight_mat.set_shader_parameter("emissive_energy", 3.5)
		elif td.taillight_mat is StandardMaterial3D:
			(td.taillight_mat as StandardMaterial3D).emission_enabled = true
			(td.taillight_mat as StandardMaterial3D).emission = Color(1.0, 0.05, 0.05)
			(td.taillight_mat as StandardMaterial3D).emission_energy_multiplier = 3.5

	# Lerp a momentary 0.3m lateral swerve toward their lane shoulder
	var shoulder_dir: float = 1.0 if td.lane_offset >= 0.0 else -1.0
	td.flinch_target_swerve = shoulder_dir * 0.3

	# Spawn a 2D billboarded comic exclamation mark ("!") badge above their roof for 0.4 seconds
	if is_instance_valid(td.instance):
		var badge := Label3D.new()
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.text = "!"
		badge.font_size = 72
		badge.modulate = Color("#FFE500")
		badge.outline_modulate = Color("#080808")
		badge.outline_size = 18
		badge.position = Vector3(0.0, td.half_l * 0.35 + 1.45, 0.0)
		td.instance.add_child(badge)
		var tw := badge.create_tween()
		tw.set_parallel(true)
		tw.tween_property(badge, "position:y", badge.position.y + 0.45, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(badge, "modulate:a", 0.0, 0.15).set_delay(0.25)
		tw.chain().tween_callback(badge.queue_free)

func _find_clear_lane(target_z: float) -> float:
	var best_lane: float = LANE_OFFSETS[0]
	var best_min_dist: float = -1.0
	for lane in LANE_OFFSETS:
		var min_dist_in_lane: float = 999.0
		for other in traffic_pool:
			if abs(other.lane_offset - lane) < 1.0:
				var d: float = abs(other.current_z - target_z)
				if d < min_dist_in_lane:
					min_dist_in_lane = d
		if min_dist_in_lane > best_min_dist:
			best_min_dist = min_dist_in_lane
			best_lane = lane
	return best_lane

func _process_road_recycler() -> void:
	if road_chunks.is_empty():
		return
	var oldest_chunk = road_chunks[0]
	if player_z < oldest_chunk.position.z - (CHUNK_LENGTH * 1.5):
		road_chunks.remove_at(0)
		oldest_chunk.queue_free()

		var new_chunk = _create_road_chunk(next_chunk_z)
		add_child(new_chunk)
		road_chunks.append(new_chunk)
		next_chunk_z -= CHUNK_LENGTH

		# Clean up distant tunnel intervals that fell behind the player
		var t_idx := 0
		while t_idx < active_tunnel_intervals.size():
			if active_tunnel_intervals[t_idx].y > player_z + 40.0:
				active_tunnel_intervals.remove_at(t_idx)
			else:
				t_idx += 1

func _process_highway_hazards(delta: float) -> void:
	# 1. EXPANSION JOINT THUMPS (Every 40 meters)
	var cur_joint_idx: int = int(floor(-player_z / 40.0))
	var prev_joint_idx: int = int(floor(-prev_player_z_joint / 40.0))
	if cur_joint_idx > prev_joint_idx and current_state == GameState.RACING:
		camera_pitch_kick = 0.024
		_spawn_tire_slap_puffs()
		screen_shake = max(screen_shake, 0.04)
	prev_player_z_joint = player_z

	# 2. TRAFFIC CONE COLLISIONS (Clipping sends flat 3D cone spinning without stopping momentum)
	for i in range(active_traffic_cones.size() - 1, -1, -1):
		var cone: TrafficConeData = active_traffic_cones[i]
		if cone.global_z > player_z + 30.0:
			if is_instance_valid(cone.node):
				cone.node.queue_free()
			active_traffic_cones.remove_at(i)
			continue

		if not cone.hit and current_state == GameState.RACING:
			var dz: float = abs(cone.global_z - player_z)
			var dx: float = abs(cone.global_x - player_lane_x)
			if dz < 1.45 and dx < 0.95:
				cone.hit = true
				if is_instance_valid(cone.node):
					cone.node.visible = false
				var c_cx: float = _sample_road_x(cone.global_z)
				var c_right: Vector3 = _sample_road_right(cone.global_z)
				var c_bank: float = _sample_road_bank(cone.global_z)
				var c_y: float = -sin(c_bank) * cone.global_x + 0.05
				var spawn_pos: Vector3 = Vector3(c_cx, c_y, cone.global_z) + (c_right * cone.global_x)
				_spawn_flying_cone(spawn_pos)
				score += 150
				screen_shake = max(screen_shake, 0.08)
				_spawn_floating_graze_badge(spawn_pos, 150)

	# 3. FLYING CONES SIMULATION LOOP
	for i in range(active_flying_cones.size() - 1, -1, -1):
		var fc: FlyingCone = active_flying_cones[i]
		fc.time_left -= delta
		if fc.time_left <= 0.0 or not is_instance_valid(fc.node):
			if is_instance_valid(fc.node):
				fc.node.queue_free()
			active_flying_cones.remove_at(i)
			continue
		fc.velocity.y -= 26.0 * delta
		fc.node.position += fc.velocity * delta
		fc.node.rotate_x(fc.ang_velocity.x * delta)
		fc.node.rotate_y(fc.ang_velocity.y * delta)
		fc.node.rotate_z(fc.ang_velocity.z * delta)

	# 4. ROAD CONSTRUCTION SQUEEZE BOUNDARIES
	for i in range(active_construction_zones.size() - 1, -1, -1):
		var cz: ConstructionZoneData = active_construction_zones[i]
		if cz.global_z_end > player_z + 40.0:
			active_construction_zones.remove_at(i)
			continue
		if current_state == GameState.RACING and player_z <= cz.global_z_start and player_z >= cz.global_z_end:
			if cz.cordoned_x < 0.0:
				if player_lane_x < -3.6:
					player_lane_x = -3.6
					player_lat_velocity = 5.5
					screen_shake = max(screen_shake, 0.20)
					_emit_guardrail_sparks(-1.0, delta)
			else:
				if player_lane_x > 3.6:
					player_lane_x = 3.6
					player_lat_velocity = -5.5
					screen_shake = max(screen_shake, 0.20)
					_emit_guardrail_sparks(1.0, delta)

	# 5. BREAKABLE TOLL GATES & BOOTH DEFLECTION (All Gates Breakable, Zero Momentum Loss)
	for i in range(active_toll_plazas.size() - 1, -1, -1):
		var tp: TollPlazaData = active_toll_plazas[i]
		if tp.global_z > player_z + 40.0:
			active_toll_plazas.remove_at(i)
			continue
		if current_state == GameState.RACING:
			# Concrete booth divider island cushion deflection (No crash, sparks & lateral bounce)
			if player_z <= (tp.global_z + 4.0) and player_z >= (tp.global_z - 4.0):
				for bx in [-8.8, -4.4, 0.0, 4.4, 8.8]:
					var b_dist: float = player_lane_x - bx
					if abs(b_dist) < 0.78:
						var push_sign: float = -1.0 if b_dist < 0.0 else 1.0
						player_lane_x = bx + (push_sign * 0.78)
						player_lat_velocity = push_sign * 4.8
						screen_shake = max(screen_shake, 0.16)
						_emit_guardrail_sparks(push_sign, delta)
						break

			# Gate barrier crossing - all 4 gates breakable with zero momentum loss!
			if player_z <= (tp.global_z + 2.5) and player_z >= (tp.global_z - 2.8):
				for gate in tp.gates:
					if not gate.broken:
						if abs(player_lane_x - gate.lane_x) <= 1.65:
							gate.broken = true
							if is_instance_valid(gate.boom_node):
								gate.boom_node.visible = false
							var c_cx: float = _sample_road_x(tp.global_z)
							var c_right: Vector3 = _sample_road_right(tp.global_z)
							var c_tan: Vector3 = _sample_road_tangent(tp.global_z)
							var g_pos: Vector3 = Vector3(c_cx, 0.95, tp.global_z) + (c_right * gate.lane_x)
							_spawn_shattered_gate_booms(g_pos, c_tan, c_right)

							if gate.is_open_lane:
								score += 1000
								combo_multiplier += 1
								combo_timer = 3.0
								_spawn_floating_graze_badge(car_root.global_position, 1000)
								screen_shake = max(screen_shake, 0.08)
							else:
								score += 500
								combo_multiplier += 1
								combo_timer = 2.5
								_spawn_floating_smash_badge(car_root.global_position, 500)
								screen_shake = max(screen_shake, 0.15)
							tp.passed = true
							break

	# 6. RHYTHMIC OVERHEAD SODIUM POOL WASH (Stepped Toon Highlights on Hood, Roof & Spoiler)
	if is_instance_valid(hero_body_shader_mat):
		var sodium_val: float = 0.0
		if current_state == GameState.RACING:
			var pole_phase: float = fposmod(-player_z - 20.0 + 15.0, 30.0) - 15.0
			var dist_to_pole: float = abs(pole_phase)
			if dist_to_pole < 4.2:
				var raw_t: float = 1.0 - (dist_to_pole / 4.2)
				if raw_t > 0.65:
					sodium_val = 1.0
				elif raw_t > 0.30:
					sodium_val = 0.55
				else:
					sodium_val = 0.20
		hero_body_shader_mat.set_shader_parameter("sodium_intensity", sodium_val * night_factor)

	# 7. HIGHWAY PATROL EVASION EVENT
	if patrol_cooldown > 0.0:
		patrol_cooldown -= delta
	elif not patrol_evasion_active and current_state == GameState.RACING and player_speed > 42.0:
		for td in traffic_pool:
			if (td.is_police or td.model_type in ["police", "police_interceptor"]) and not td.is_roadblock:
				var gap: float = abs(td.current_z - player_z)
				if gap < 48.0:
					patrol_evasion_active = true
					patrol_evasion_timer = 9.0
					patrol_evaded_cars = 0
					patrol_cooldown = 40.0
					_play_proc_audio("siren")
					_trigger_hazard_banner("🚨 PATROL RADAR DETECTED! ESCAPE PURSUIT (WEAVE 3 CARS) 🚨")
					_trigger_radio_chatter("HIGHWAY DISPATCH", "Patrol Unit 1: Intercepting black sports car exceeding 200 km/h!", Color("#FF3344"))
					break

	if patrol_evasion_active and current_state == GameState.RACING:
		patrol_evasion_timer -= delta
		if patrol_evasion_timer <= 0.0:
			patrol_evasion_active = false
			_trigger_radio_chatter("TACHIBANA SPOTTER", "Radar lost your line! You're in the clear!", Color("#00E5FF"))

	# 8. RAIN PUDDLES & AQUAPLANING
	if is_raining and current_state == GameState.RACING and player_speed > 35.0:
		for i in range(active_puddles.size() - 1, -1, -1):
			var pud: PuddleData = active_puddles[i]
			if pud.global_z > player_z + 40.0:
				if is_instance_valid(pud.node):
					pud.node.queue_free()
				active_puddles.remove_at(i)
				continue
			if not pud.splashed:
				var p_dz: float = abs(pud.global_z - player_z)
				var p_dx: float = abs(pud.global_x - player_lane_x)
				if p_dz < 1.8 and p_dx < 1.4:
					pud.splashed = true
					score += 150
					_play_proc_audio("splash")
					_spawn_floating_graze_badge(car_root.global_position + Vector3(0.0, 1.8, 0.0), 150)
					screen_shake = max(screen_shake, 0.08)

					var car_trans := car_root.global_transform
					var right_dir := car_trans.basis.x.normalized()
					var center_pos := car_trans.origin + (car_trans.basis.z * 1.3)
					for side in [-0.95, 0.95]:
						var spray := MeshInstance3D.new()
						var qm := QuadMesh.new()
						qm.size = Vector2(1.4, 2.2)
						spray.mesh = qm
						spray.material_override = water_spray_mat
						spray.scale = Vector3(0.5, 0.5, 0.5)
						var s_pos: Vector3 = center_pos + (right_dir * side)
						spray.position = s_pos
						add_child(spray)

						var tw := spray.create_tween()
						var target_pos: Vector3 = s_pos + (car_trans.basis.z * 3.5) + (right_dir * side * 1.8) + Vector3.UP * 1.2
						tw.set_parallel(true)
						tw.tween_property(spray, "position", target_pos, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						tw.tween_property(spray, "scale", Vector3(2.2, 2.8, 1.2), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
						tw.chain().tween_callback(spray.queue_free)

					if is_instance_valid(pud.node):
						var p_tw := pud.node.create_tween()
						p_tw.tween_property(pud.node, "scale", Vector3(0.2, 0.2, 0.2), 0.3)

	# 10. WEATHER PARTICLE POSITION TRACKING & DYNAMIC DIRECTIONAL RAIN WIND
	if is_instance_valid(car_root):
		var car_pos := car_root.global_position
		if is_instance_valid(leaf_particles):
			leaf_particles.global_position = car_pos + Vector3(0.0, 2.5, -14.0)
		if is_instance_valid(snow_layer_near):
			snow_layer_near.global_position = car_pos + Vector3(0.0, 3.5, -28.0)
		if is_instance_valid(snow_layer_mid):
			snow_layer_mid.global_position = car_pos + Vector3(0.0, 8.0, -75.0)
		if is_instance_valid(snow_layer_far):
			snow_layer_far.global_position = car_pos + Vector3(0.0, 18.0, -170.0)

		# Dynamic Directional Wind for Rain Shader
		if is_raining and is_instance_valid(rain_mat):
			var base_wind: float = sin(float(Time.get_ticks_msec()) * 0.0004) * 0.45
			var steer_wind: float = -steer_input * 0.35
			var dynamic_angle: float = clamp(0.55 + base_wind + steer_wind, -1.2, 1.2)
			rain_mat.set_shader_parameter("rain_angle", dynamic_angle)

	# 11. TUNNEL BACKFIRE LIGHT DECAY
	if tunnel_backfire_light_timer > 0.0:
		tunnel_backfire_light_timer -= delta
		if tunnel_backfire_light_timer <= 0.0 and is_instance_valid(tunnel_backfire_light):
			tunnel_backfire_light.light_energy = 0.0

func _update_hud(delta: float) -> void:
	top_speed_achieved = max(top_speed_achieved, player_speed)
	displayed_score = lerp(displayed_score, float(score), 12.0 * delta)

	var speed_kmh: int = int(round(player_speed * 3.6))
	hud_speed_label.text = str(max(0, speed_kmh))
	hud_score_label.text = "SCORE: " + str(int(displayed_score))

	# Update Nitro / Boost Gauge and Double-Tap Prompt
	if is_instance_valid(hud_nitro_bar):
		hud_nitro_bar.size.x = (nitro_charge / 100.0) * 308.0
		if nitro_charge >= 50.0:
			var pulse: float = sin(Time.get_ticks_msec() * 0.014) * 0.5 + 0.5
			var pulse_col: Color = Color("#00E5FF").lerp(Color("#FFD000"), pulse)
			hud_nitro_bar.color = pulse_col
			if is_instance_valid(hud_nitro_ready_badge):
				hud_nitro_ready_badge.visible = true
				hud_nitro_ready_badge.text = "⚡ MAX OVERDRIVE READY! ⚡" if nitro_charge >= 99.5 else "⚡ DOUBLE TAP BOOST! ⚡"
				hud_nitro_ready_badge.add_theme_color_override("font_color", pulse_col)
		else:
			hud_nitro_bar.color = Color("#00B4D8")
			if is_instance_valid(hud_nitro_ready_badge):
				hud_nitro_ready_badge.visible = false

	# Update Arcade Speedometer Rev Bar & Gear Indicator
	if is_instance_valid(hud_rev_bar):
		var rev_ratio: float = clamp(float(speed_kmh) / 200.0, 0.0, 1.0)
		hud_rev_bar.size.x = rev_ratio * 308.0
		if rev_ratio < 0.65:
			hud_rev_bar.color = Color("#00E5FF") # Cyan
		elif rev_ratio < 0.88:
			hud_rev_bar.color = Color("#FFB300") # Amber
		else:
			hud_rev_bar.color = Color("#FF1E27") # Redline Flash
	if is_instance_valid(hud_gear_label):
		var gear: int = 1
		if speed_kmh > 175: gear = 6
		elif speed_kmh > 140: gear = 5
		elif speed_kmh > 105: gear = 4
		elif speed_kmh > 70: gear = 3
		elif speed_kmh > 35: gear = 2
		hud_gear_label.text = "GEAR " + str(gear)

		# Trigger: On upshift or sudden throttle release at speeds > 130 km/h
		if gear > prev_hud_gear:
			_trigger_exhaust_backfire()
			if is_instance_valid(gear_shift_player) and stream_gear_upshift:
				gear_shift_player.pitch_scale = randf_range(0.96, 1.04)
				gear_shift_player.play()
		elif speed_kmh > 130 and (prev_speed_for_pop - player_speed) > 1.8:
			_trigger_exhaust_backfire()
		prev_hud_gear = gear
		prev_speed_for_pop = player_speed

	hud_drift_label.visible = drift_active and (current_state == GameState.RACING)

	# Dynamic Screen-Edge Comic Speed Needles (activated when vehicle speed > 175 km/h, strictly outer 15% edges)
	if is_instance_valid(speedlines_mat):
		if speed_kmh > 175 and current_state == GameState.RACING:
			var sl_intensity: float = clamp((float(speed_kmh) - 175.0) / 25.0, 0.45, 1.0)
			speedlines_mat.set_shader_parameter("intensity", sl_intensity)
			if is_instance_valid(hud_speedlines): hud_speedlines.visible = true
		else:
			speedlines_mat.set_shader_parameter("intensity", 0.0)
			if is_instance_valid(hud_speedlines): hud_speedlines.visible = false

	# Fade Red Damage Flash
	if hud_crash_flash.color.a > 0.0:
		hud_crash_flash.color.a = max(0.0, hud_crash_flash.color.a - (delta * 1.2))

	# Update Combo Banner & Bar
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_multiplier = 1
			if is_instance_valid(hud_combo_container):
				hud_combo_container.visible = false
		else:
			if is_instance_valid(hud_combo_container):
				hud_combo_container.visible = true
				if is_instance_valid(hud_combo_bar):
					hud_combo_bar.size.x = 250.0 * (combo_timer / 2.5)
				if combo_timer < 0.6:
					hud_combo_container.modulate.a = combo_timer / 0.6
				else:
					hud_combo_container.modulate.a = 1.0
	else:
		if is_instance_valid(hud_combo_container):
			hud_combo_container.visible = false
