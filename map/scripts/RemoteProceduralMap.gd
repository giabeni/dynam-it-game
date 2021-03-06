#tool
extends Spatial

class_name RemoteProceduralMap

enum Tiles {
	ARO_1,
	PORTAL,
	CORREDOR_MEDIO,
	CORREDOR_CURTO,
	HALL_X,
	HALL_T,
	SUPORTE_LATERAL,
	RAMPA_GRANDE,
	HALL_GRANDE,
	SUPORTE_PEQUENO,
	SUPORTE_MEDIO,
	ARO_2,
	RAMPA_PEQUENA,
	RAMPA_LARGA,
	PLATAFORMA,
}

const MAP_TILES = [
	Tiles.ARO_1,
#	Tiles.ARO_2,
	Tiles.HALL_GRANDE,
	Tiles.HALL_T,
	Tiles.HALL_X,
	Tiles.CORREDOR_CURTO,
	Tiles.CORREDOR_MEDIO,
]

const ROOMS = [Tiles.HALL_GRANDE]

const ORIENTATIONS = {
	Tiles.ARO_1: [0, 90],
	Tiles.ARO_2: [0, 90],
	Tiles.HALL_GRANDE: [0, 90],
	Tiles.HALL_T: [0, 90, 180, -90],
	Tiles.HALL_X: [0],
	Tiles.CORREDOR_CURTO: [0, 90],
	Tiles.CORREDOR_MEDIO: [0, 90],
}

const SIZES = {
	Tiles.ARO_1: Vector3(1, 1, 4),
	Tiles.ARO_2: Vector3(2, 1, 4),
	Tiles.HALL_GRANDE: Vector3(20, 1, 20),
	Tiles.HALL_T: Vector3(8, 1, 10),
	Tiles.HALL_X: Vector3(10, 1, 10),
	Tiles.CORREDOR_CURTO: Vector3(5, 1, 5),
	Tiles.CORREDOR_MEDIO: Vector3(10, 1, 5),
	Tiles.PLATAFORMA: Vector3(-2, 1, 9)
}

const NAVIGATION_SIZES = {
	Tiles.ARO_1: [Vector3(1, 1, 4)],
	Tiles.ARO_2: [Vector3(2, 1, 4)],
	Tiles.HALL_GRANDE: [Vector3(4, 1, 3), Vector3(3, 1, 7), Vector3(6, 1, 10), Vector3(3, 1, 7), Vector3(1, 1, 5), Vector3(4, 1, 3)],
	Tiles.HALL_T: [Vector3(4, 1, 3), Vector3(4, 1, 10)],
	Tiles.HALL_X: [Vector3(4, 1, 3), Vector3(3, 1, 10), Vector3(3, 1, 3)],
	Tiles.CORREDOR_CURTO: [Vector3(5, 1, 3)],
	Tiles.CORREDOR_MEDIO: [Vector3(10, 1, 3)],
}

const DOORS = {
	Tiles.ARO_1: [Vector3(1, 0, 0)],
	Tiles.ARO_2: [Vector3(2, 0, 0)],
	Tiles.HALL_GRANDE: [Vector3(20, 0, 0)],
	Tiles.HALL_T: [Vector3(5, 0, -5), Vector3(5, 0, 5)],
	Tiles.HALL_X: [Vector3(10, 0, 0), Vector3(5, 0, -5), Vector3(5, 0, 5)],
	Tiles.CORREDOR_CURTO: [Vector3(5, 0, 0)],
	Tiles.CORREDOR_MEDIO: [Vector3(10, 0, 0)],
}

const OBSTACLES_POINTS = {
	Tiles.ARO_1: [],
	Tiles.HALL_GRANDE: [],
	Tiles.HALL_T: [],
	Tiles.HALL_X: [],
	Tiles.CORREDOR_CURTO: [],
	Tiles.CORREDOR_MEDIO: [],
}

onready var grid: GridMap = $Navigation/NavigationMeshInstance/GridMap
onready var nav: Navigation = $Navigation
onready var nav_mesh: NavigationMeshInstance = $Navigation/NavigationMeshInstance
onready var arrow: Spatial = $Point
onready var obstacles: Spatial = $Navigation/Obstacles
onready var gold_piles: Spatial = $Navigation/GoldPiles
onready var lights: Spatial = $Navigation/Lights
onready var items: Spatial = $Navigation/Items
onready var npcs: Spatial = $Navigation/NPCs
onready var screens: Control = $"../EndScreens"
onready var player = $"../Player"
onready var nav_grid: NavGrid = $PaintedGrid
onready var match_instance: Match = $".."
onready var player_id = get_tree().get_network_unique_id()
onready var my_username = Server.username
onready var other_players = $"../OtherPlayers"


export(Vector3) var MAP_SIZE = Vector3(60, 0, 60)
export(float) var MIN_AREA = 2000
export(float) var MAX_AREA = 3000
export(int, 0, 100) var NPCS_COUNT = 0
export(int, 0, 100) var GOLD_PILES_COUNT = 0
export(int, 0, 100) var ITEMS_COUNT = 0
export(int, 0, 100) var WALLS_COUNT = 0

export(Array, PackedScene) var WALL_OBSTACLES_SCENES = [
	preload("res://obstacles/scenes/WoodWall.tscn"),
	preload("res://obstacles/scenes/RockWall.tscn"),
	preload("res://obstacles/scenes/MineCar.tscn")
]

export(Array, PackedScene) var OBJECTS_SCENES = [
	preload("res://obstacles/scenes/Barrel.tscn"),
	preload("res://obstacles/scenes/Crate.tscn"),
	preload("res://obstacles/scenes/TNTBarrel.tscn"),
]
export(PackedScene) var NPC_SCENE = preload("res://npcs/scenes/NPC.tscn")
export(PackedScene) var LIGHT_SCENE = preload("res://tiles/scenes/LightBulb.tscn")
export(PackedScene) var GOLD_PILE_SCENE = preload("res://obstacles/scenes/GoldRocks.tscn")
export(PackedScene) var PLAYER_TEMPLATE = preload("res://player/scenes/PlayerTemplate.tscn")

var GRID_SIZE = Vector3(10, 0, 10)
var x_limits = [INF, -INF]
var z_limits = [INF, -INF]
var painted_cells = {}
var wall_cells = {}
var baked_nav_mesh = PoolVector3Array([])
var should_bake_nav_meshes = false
var loading_progress = 0
var spawning_points = []

# Multiplayer
var last_map_state = 0
var map_state_buffer = []
#var thread = Thread.new()
const INTERPOLATION_OFFSET = 100


signal finished_grid
signal finished_walls
signal finished_objects(type)
signal npcs_spawned
signal finished_map_generation

func _ready():
#	$PaintedGrid.hide()
	_set_npcs_paused(true)
#	randomize()
	
	# Adjust the size of grid to match the map size
	GRID_SIZE = MAP_SIZE / grid.cell_size
	player.controller.set_physics_process(false)
	self.connect("finished_grid", self, "on_grid_generation_finished")
	self.connect("finished_walls", self, "on_walls_placement_finished")
	self.connect("finished_objects", self, "on_objects_placement_finisished")
	
	screens.set_loading_screen(5, "Creating mine's corridors...")
	if grid.get_used_cells().size() <= 0:
		should_bake_nav_meshes = true
		print("Generating map...")
		_generate_map()

#	screens.set_loading_screen(loading_progress, "Spawning enemies...")
#	_spawn_npcs()
#	yield(self, "npcs_spawned")
#	get_parent().configure_npcs_signals()
#	print(">> Spawned NPCs")
	
	
func on_grid_generation_finished():
	# Adds points and connections to NavGrid 
#	nav_grid.navigation = nav
	nav_grid.bake_points()
	print(">> Generated tiles")
	screens.set_loading_screen(8, "Adding destructible walls...")
	_add_walls()


func on_walls_placement_finished():
	print(">> Added destructible walls")
	screens.set_loading_screen(10, "Adding lights...")	
	_add_lights()
	print(">> Added lights")
	loading_progress = 10
	if not should_bake_nav_meshes:
		_calculate_map_limits()
	
	screens.set_loading_screen(loading_progress, "Adding gold piles...")	
	_add_objects([GOLD_PILE_SCENE], GOLD_PILES_COUNT, "Adding gold piles...", 0.6, 0.75, 15, gold_piles, "GOLD_PILES")


func on_objects_placement_finisished(type: String):
	if type == "GOLD_PILES":
		print(">> Added gold piles")
		screens.set_loading_screen(loading_progress, "Spawning destrutible items...")		
		_add_objects(OBJECTS_SCENES, ITEMS_COUNT, "Adding destructible objects...")
	elif type == "ITEMS":
		print(">> Added items")
		
		
		_set_players_positions()
		screens.set_loading_screen(99, "Finishing...")

		screens.set_loading_screen(100, "LET'S GO!")
		
		# Emits signal that finished map generation to enable server remote calls for room
		emit_signal("finished_map_generation")


func _set_players_positions():
	# Randomize spawning points
	spawning_points.shuffle()
	
	for username in match_instance.room.spots:
		var spot = match_instance.room.spots[username]
		var spot_origin = get_spawning_point(spot)
		if username == my_username:
			# Sets players positions
			player.global_transform.origin = spot_origin
		else:
			# Spawn other enemies
			spawn_remote_player(username, spot)


func start_match():
	print("REMOTE: >> Starting match!")
	get_parent().start_match()
	_set_npcs_paused(false)
	player.enable()


func _generate_map():
	grid.clear()
	$PaintedGrid.clear()
#	NavigationMeshGenerator.clear(nav_mesh.navmesh)
	painted_cells = {}
#	thread.start(self, "_generate_grid_map")
	_generate_grid_map()

	
func _calculate_map_limits():
	for cur_point in grid.get_used_cells():
		# Updates the limits of map
		x_limits[0] = min(x_limits[0], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).x)
		x_limits[1] = max(x_limits[1], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).x)
		z_limits[0] = min(z_limits[0], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).z)
		z_limits[1] = max(z_limits[1], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).z)

	
func _add_walls():
	var walls_count = 0
	var used_cells = grid.get_used_cells()
	used_cells.shuffle()
	for cell in used_cells:
		if grid.get_cell_item(cell.x, cell.y, cell.z) in [Tiles.ARO_1, Tiles.ARO_2, Tiles.PLATAFORMA]:
			continue
		var cur_point = grid.map_to_world(cell.x, cell.y, cell.z)
		if walls_count < WALLS_COUNT:
			var wall_scene: PackedScene = WALL_OBSTACLES_SCENES[randi() % WALL_OBSTACLES_SCENES.size()]
			var wall: Destructible = wall_scene.instance()
			obstacles.add_child(wall)
			wall_cells[String(cell)] = true
			var orientation = grid.get_cell_item_orientation(cell.x, cell.y, cell.z)
			var angle = _get_rotation_from_orientation(orientation)
			var cross_dir = Vector3(1, 0, 0).rotated(Vector3.UP, angle.y + deg2rad(90))
			var cells = [cell - 2 * cross_dir, cell - cross_dir, cell, cell + cross_dir, cell + 2 * cross_dir]
			$PaintedGrid.disable_cells(cells)
			wall.nav_grid_cells = cells
			wall.connect("on_destroyed", self, "_on_object_destroyed")
			wall.global_transform.origin = cur_point
			wall.rotation_degrees.y = rad2deg(angle.y) + 90
			walls_count += 1
		else:
			break
	
	emit_signal("finished_walls")
	
	
func _on_object_destroyed(nav_grid_cells):
	$PaintedGrid.enable_cells(nav_grid_cells)


func _add_lights():
	var used_cells = grid.get_used_cells()
	for cell in used_cells:
		var tile = grid.get_cell_item(cell.x, cell.y, cell.z)
		if tile in [Tiles.ARO_1, Tiles.ARO_2, Tiles.PLATAFORMA, Tiles.CORREDOR_CURTO, Tiles.CORREDOR_MEDIO]:
			continue
		var cur_point = _get_cell_middle(tile, cell)
		if tile in [Tiles.HALL_GRANDE]:
			cur_point.y += 0.75
		var light: Spatial = LIGHT_SCENE.instance()
		lights.add_child(light)
		light.global_transform.origin = cur_point


func _add_objects(scenes: Array, quantity: int, text: String, min_scale = 1, max_scale = 1, max_rotation = 0, parent = items, type = "ITEMS"):
	var count = 0
	while count < quantity:
		var x = rand_range(x_limits[0], x_limits[1])
		var z = rand_range(z_limits[0], z_limits[1])
		var y = 0
		var nav_point = nav_grid.get_closest_point(Vector3(x, y, z))
		if nav_point.y <= 3:
			var scene = scenes[randi() % scenes.size()]
			var object: Destructible = scene.instance()
			parent.add_child(object)
			
			object.global_transform.origin = nav_point
			object.scale.x = rand_range(min_scale, max_scale)
			object.scale.y = rand_range(min_scale, max_scale)
			object.scale.z = rand_range(min_scale, max_scale)
			object.rotation_degrees.x = rand_range(-max_rotation, max_rotation)
			object.rotation_degrees.y = rand_range(0, 360)
			object.rotation_degrees.z = rand_range(-max_rotation, max_rotation)
			
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			
			# Checks if gold pile is not overlapping area
			if object.is_overlapping_body():
				object.call_deferred("queue_free")
				continue
				
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			
			if object.is_blocking_npc():
				object.call_deferred("queue_free")
				continue				
			else:
				object.remove_inner_area()
				count += 1
				loading_progress += 74 / (ITEMS_COUNT + GOLD_PILES_COUNT)
				screens.set_loading_screen(loading_progress, "["+ str(count) +"/" + str(quantity) + "] " + text)

	emit_signal("finished_objects", type)
	
	
func _generate_grid_map():
	
	var angles = [0]
	
	var cur_points = [Vector3(0, 0, 0)]
		
	var total_area = 0
	
	# Fill first open door with all
	var first_point = Vector3(-1, 0, 0)
	var first_wall_orientation = _get_orientation(90, 90)
	grid.set_cell_item(first_point.x, first_point.y, first_point.z, Tiles.PLATAFORMA, first_wall_orientation)
	

	while total_area <= MAX_AREA and cur_points.size() > 0:
		var next_angles: Array = []
		var next_points: Array = []
		
		for p in range(0, cur_points.size()):
			var cur_point = cur_points[p]
			var angle = angles[p]
			
#			yield(get_tree().create_timer(0.25), "timeout")
			
			# Getting random tiles
			var tiles = _get_random_tiles()
			
			# Getting the correct orientation due to the angle
			var orientation = _get_orientation(angle)
			
			# Controls wether was possible to add a tile
			var could_add_tile = false

			for tile in tiles:
				# Checks if point is already occupied
				if _is_point_available(tile, cur_point, angle):

					# Adding tile to grid
					cur_point = cur_point.round()
					grid.set_cell_item(cur_point.x, cur_point.y, cur_point.z, tile, orientation)
					could_add_tile = true
					
					# Updates area of the map
					total_area += SIZES[tile].x * SIZES[tile].z
					
					# Adds tile as a spawning point
					if not tile in [Tiles.PLATAFORMA, Tiles.ARO_1, Tiles.ARO_2, Tiles.CORREDOR_CURTO, Tiles.CORREDOR_MEDIO]:
						if not String(cur_point) in wall_cells:
							spawning_points.append(_get_cell_middle(tile, cur_point))
					
					# Paint occupied cells
					_paint_cells(tile, cur_point, angle)
					_paint_navigation_cells(tile, cur_point, angle)

					# Updates the limits of map
					x_limits[0] = min(x_limits[0], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).x)
					x_limits[1] = max(x_limits[1], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).x)
					z_limits[0] = min(z_limits[0], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).z)
					z_limits[1] = max(z_limits[1], grid.map_to_world(cur_point.x, cur_point.y, cur_point.z).z)
					
					# Getting possible next directions
					var doors = DOORS[tile]
					
					# Updates the next points to spawn the nexts tiles
					for next_offset in doors:
						var next_point = cur_point + next_offset.rotated(Vector3.UP, deg2rad(angle))
						
						next_points.append(next_point)
					
						# Updates the current direction (angle) of the walking cursor
						if next_offset.z == 0:
							next_angles.append(angle)
						elif next_offset.z > 0:
							next_angles.append(angle - 90)
						elif next_offset.z < 0:
							next_angles.append(angle + 90)

					arrow.translation = grid.map_to_world(cur_point.x, cur_point.y, cur_point.z)
					arrow.rotation_degrees.y = angle
					break
			
			if not could_add_tile:
				# Add wall if there's no way out
				var wall_orientation = _get_orientation(angle - 90, 90)
				grid.set_cell_item(cur_point.x, cur_point.y, cur_point.z, Tiles.PLATAFORMA, wall_orientation)
				_paint_cells(Tiles.PLATAFORMA, cur_point, angle)
				
				
		angles = next_angles
		cur_points = next_points
	
	# If area is too smal (less than a half), tries again
	if total_area <= MIN_AREA:
		_generate_map()
		return
	
	# Fill remaining doors with walls
	for p in range(0, cur_points.size()):
		var cur_point = cur_points[p]
		var world_pos = grid.map_to_world(cur_point.x, cur_point.y, cur_point.z)
		$Camera.global_transform.origin.x = world_pos.x
		$Camera.global_transform.origin.z = world_pos.z
		
		var angle = angles[p]
		var wall_orientation = _get_orientation(angle - 90, 90)
		grid.set_cell_item(cur_point.x, cur_point.y, cur_point.z, Tiles.PLATAFORMA, wall_orientation)
		_paint_cells(Tiles.PLATAFORMA, cur_point, angle)


	emit_signal("finished_grid")
	return true
	

func _spawn_npcs():
	var npcs_count = NPCS_COUNT + 1
	
	if npcs_count <= 0:
		yield(get_tree(), "idle_frame")
		emit_signal("npcs_spawned")
		return

	var interval = 2
	
	var i = -1
	var used_cells = grid.get_used_cells()
	used_cells.shuffle()
	for cell in used_cells:
		var tile = grid.get_cell_item(cell.x, cell.y, cell.z) 
		if tile in [Tiles.PLATAFORMA, Tiles.ARO_1, Tiles.ARO_2, Tiles.CORREDOR_CURTO, Tiles.CORREDOR_MEDIO]:
			continue
		i += 1
		if not String(cell) in wall_cells:
			var middle_point = _get_cell_middle(tile, cell)
			var npc = NPC_SCENE.instance()
			npc.NAV_GRID_PATH = $PaintedGrid.get_path()
			npc.paused = true
			npc.obstacles = obstacles
			npc.gold_piles = gold_piles
			npc.player = player
			npcs.add_child(npc)
			npc.global_transform.origin = middle_point + Vector3.UP * 0.5
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			yield(get_tree(), "physics_frame")
			
			# Checks if wall is not overlapping npc
			if npc.is_overlapping_body():
				print("NPC INSIDE WALL! RETRYING...")
				npc.call_deferred("queue_free")
			else:
				npc.remove_inner_area()
				npcs_count -= 1
				loading_progress += 15 / NPCS_COUNT
				screens.set_loading_screen(loading_progress, "["+ str(NPCS_COUNT - npcs_count) +"/" + str(NPCS_COUNT) + "] Spawning enemies...")

			if npcs_count <= 0:
				break
	yield(get_tree(), "idle_frame")	
	emit_signal("npcs_spawned")
			
		
func _set_npcs_paused(paused: bool):
	for npc in npcs.get_children():
		npc.set_paused(paused)
	

func get_spawning_point(spot):
	return spawning_points[spot]
	

func spawn_remote_player(username, room_spot):
	var spawning_point = get_spawning_point(room_spot)
	var remote_player = PLAYER_TEMPLATE.instance()
	remote_player.name = str(username)
	other_players.add_child(remote_player, true)
	remote_player.global_transform.origin = spawning_point
	return remote_player
	

func spawn_previous_player(username, origin):
	if Server.username == username:
		return
	if other_players.has_node(str(username)):
		return
	var remote_player = PLAYER_TEMPLATE.instance()
	remote_player.name = str(username)
	other_players.add_child(remote_player, true)
	remote_player.global_transform.origin = origin
	return remote_player

func despawn_remote_player(username):
	yield(get_tree().create_timer(0.2), "timeout")
	if other_players.has_node(str(username)):
		other_players.get_node(str(username)).queue_free()


func _get_random_tiles():
	var tiles = []
	tiles.append_array(MAP_TILES)
	tiles.shuffle()
	return tiles


func _get_random_door(tile_index: int):
	var doors: Array = DOORS[tile_index]
	var d = randi() % doors.size()
	var random_door: Vector3 = doors[d]
	return random_door


func _get_orientation(angle_y, angle_x = 0):
	var quat = Quat(Vector3.UP, deg2rad(angle_y))
	var basis = Basis(Vector3.LEFT, deg2rad(angle_x)).rotated(Vector3.UP, deg2rad(angle_y))
	return basis.get_orthogonal_index()


func _get_random_orientation(tile_index: int):
	var a = int(round(rand_range(0, ORIENTATIONS[Tiles.HALL_GRANDE].size() - 1)))
	var angle = ORIENTATIONS[Tiles.HALL_GRANDE][a]
	return _get_orientation(angle)
	

func _paint_cells(tile, cur_point, angle, sizes = SIZES, painted_tile = 1):
	var size: Vector3 = sizes[tile]
	var offset = Vector3(size.x, 0, 0).rotated(Vector3.UP, deg2rad(angle))
	var limit = cur_point + offset
	
	var dir: Vector3 = offset.normalized()
	var cell: Vector3 = cur_point
	
	while (limit.round() - cell.round()).length() >= 0.01:
		var width_dir = dir.rotated(Vector3.UP, deg2rad(90))
		for w in range(floor(-size.z/2), ceil(size.z/2)):
			var point: Vector3 = cell + width_dir * w
			point = point.round()
			painted_cells[String(point)] = true
			$PaintedGrid.set_cell_item(point.x, point.y, point.z, painted_tile)
			
		cell += dir
		

func _paint_navigation_cells(tile, cur_point, angle):
	for size in NAVIGATION_SIZES[tile]:
		var offset = Vector3(size.x, 0, 0).rotated(Vector3.UP, deg2rad(angle))
		var limit = cur_point + offset
		
		var dir: Vector3 = offset.normalized()
		var cell: Vector3 = cur_point
		
		while (limit.round() - cell.round()).length() >= 0.01:
			var width_dir = dir.rotated(Vector3.UP, deg2rad(90))
			for w in range(floor(-size.z/2), ceil(size.z/2)):
				var point: Vector3 = cell + width_dir * w
				point = point.round()
				$PaintedGrid.set_cell_item(point.x, point.y, point.z, 0)
				
			cell += dir

		cur_point = limit


func _get_cell_middle(tile: int, cell: Vector3):
	var orientation = grid.get_cell_item_orientation(cell.x, cell.y, cell.z)
	var angle = _get_rotation_from_orientation(orientation).y
	var size: Vector3 = SIZES[tile]
	var offset = Vector3(size.x, 0, 0).rotated(Vector3.UP, angle)
	var middle = cell + offset/2
	return grid.map_to_world(middle.x, middle.y, middle.z)


func _is_point_available(tile, cur_point, angle):
	var size: Vector3 = SIZES[tile]
	var offset = Vector3(size.x, 0, 0).rotated(Vector3.UP, deg2rad(angle))
	var limit = cur_point + offset
	
	var dir: Vector3 = offset.normalized()
	var cell: Vector3 = cur_point
	
	while (limit - cell).length() >= 0.01:
		var width_dir = dir.rotated(Vector3.UP, deg2rad(90))
		for w in range(floor(-size.z/2), ceil(size.z/2)):
			var point = cell + width_dir * w
			point = point.round()
			if String(point) in painted_cells and painted_cells[String(point)]:
				return false
			
		cell += dir
		
	return true


func _get_rotation_from_orientation(orientation):
	var orthogonal_angles = [
		Vector3(0, 0, 0),
		Vector3(0, 0, PI/2),
		Vector3(0, 0, PI),
		Vector3(0, 0, -PI/2),
		Vector3(PI/2, 0, 0),
		Vector3(PI, -PI/2, -PI/2),
		Vector3(-PI/2, PI, 0),
		Vector3(0, -PI/2, -PI/2),
		Vector3(-PI, 0, 0),
		Vector3(PI, 0, -PI/2),
		Vector3(0, PI, 0),
		Vector3(0, PI, -PI/2),
		Vector3(-PI/2, 0, 0),
		Vector3(0, -PI/2, PI/2),
		Vector3(PI/2, 0, PI),
		Vector3(0, PI/2, -PI/2),
		Vector3(0, PI/2, 0),
		Vector3(-PI/2, PI/2, 0),
		Vector3(PI, PI/2, 0),
		Vector3(PI/2, PI/2, 0),
		Vector3(PI, -PI/2, 0),
		Vector3(-PI/2, -PI/2, 0),
		Vector3(0, -PI/2, 0),
		Vector3(PI/2, -PI/2, 0)
	]
	
	return orthogonal_angles[orientation]
	

func _input(event):
	if Input.is_action_just_pressed("ui_up"):
		$Camera.size += 20
	elif Input.is_action_just_pressed("ui_down"):
		$Camera.size -= 20
	elif Input.is_action_just_pressed("ui_focus_next") and not $Camera.current:
		$Camera.current = true
		player.camera.current = false
	elif Input.is_action_just_pressed("ui_focus_next") and $Camera.current:
		$Camera.current = false
		player.camera.current = true
	elif Input.is_action_just_pressed("ui_page_up"):
		_generate_map()
		
	elif event is InputEventMouseMotion and $Camera.current:
		$Camera.global_translate(0.3 * Vector3(event.relative.x, 0, event.relative.y))
		
	elif event is InputEventMouseButton:
		match event.button_index:
			BUTTON_WHEEL_UP:
				$Camera.size -= 5
			BUTTON_WHEEL_DOWN:
				$Camera.size += 5


func _physics_process(delta):
	var render_time = OS.get_system_time_msecs() - INTERPOLATION_OFFSET
#	var render_time = Server.client_clock - INTERPOLATION_OFFSET
	if map_state_buffer.size() > 1:
		# Map State Buffer = [most_recent_state, next_future_state, most_future_state]
		while map_state_buffer.size() > 2 and render_time > map_state_buffer[2].T:
			map_state_buffer.remove(0) # Makes the next_future_state the most_recent_state if enough time has passed
		
		var most_recent_state = map_state_buffer[1]
		if map_state_buffer.size() > 2: # There is a future state
			var next_future_state = map_state_buffer[2]
			var interpolation_factor = float(render_time - most_recent_state["T"]) / float(next_future_state["T"] - most_recent_state["T"])
			for key in next_future_state.keys():
				if str(key) == "T":
					continue
				if key == Server.username:
					continue
				var username = key
				if not most_recent_state.has(username):
					continue
				if other_players.has_node(str(username)):
					# Interpolation
					var new_origin = lerp(most_recent_state[username]["O"], next_future_state[username]["O"], interpolation_factor)
					var new_rotation = Vector3()
					new_rotation.x = lerp_angle(most_recent_state[username]["R"].x, next_future_state[username]["R"].x, interpolation_factor)
					new_rotation.y = lerp_angle(most_recent_state[username]["R"].y, next_future_state[username]["R"].y, interpolation_factor)
					new_rotation.z = lerp_angle(most_recent_state[username]["R"].z, next_future_state[username]["R"].z, interpolation_factor)
					var new_vel_factor = lerp(most_recent_state[username]["V"], next_future_state[username]["V"], interpolation_factor)
					
					# Moving player
					other_players.get_node(str(username)).move_player(new_origin, new_vel_factor, new_rotation)
				else:
					print("REMOTE: >> Spawning player already present")
					spawn_previous_player(username, next_future_state[username]["O"])
			
		elif render_time > most_recent_state.T: # There's no future state
			var most_past_state = map_state_buffer[0]
			var extrapolation_factor = float(render_time - most_past_state["T"]) / float(most_recent_state["T"] - most_past_state["T"]) - 1.00
			for key in most_recent_state.keys():
				if str(key) == "T":
					continue
				if key == Server.username:
					continue
				var username = key
				if not most_past_state.has(username):
					continue
				if other_players.has_node(str(username)):
					# Extrapolation
					var origin_delta = (most_recent_state[username]["O"] - most_past_state[username]["O"])
					var new_origin = most_recent_state[username]["O"] + (origin_delta * extrapolation_factor)
					
					# Moving player
					other_players.get_node(str(username)).move_player(new_origin)
			
			

func update_map_state(map_state):
	if map_state["T"] > last_map_state:
		last_map_state = map_state["T"]
		map_state_buffer.append(map_state)
#		print(">>>> Received Room State, T = ", map_state["T"])
#		print(">>>> Buffer: ", map_state_buffer.size())
