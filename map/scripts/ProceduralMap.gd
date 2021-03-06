#tool
extends Spatial

class_name ProceduralMap

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
onready var arcs: Spatial = $Navigation/Arcs
onready var ceilings: Spatial = $Navigation/Ceiling
onready var screens: Control = $"../EndScreens"
onready var nav_grid: NavGrid = $PaintedGrid


export(Vector3) var MAP_SIZE = Vector3(60, 0, 60)
export(float) var MIN_AREA = 6500
export(float) var MAX_AREA = 7500
export(int, 0, 100) var NPCS_COUNT = 10
export(int, 0, 100) var GOLD_PILES_COUNT = 40
export(int, 0, 100) var ITEMS_COUNT = 35
export(int, 0, 100) var WALLS_COUNT = 30
export(float, 0, 1) var CEILINGS_PROB = 1
export(float, 0, 1) var ARCS_PROB = 1

export(PackedScene) var GOLD_PILE_SCENE = preload("res://obstacles/scenes/GoldRocks.tscn")

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


export(Array, PackedScene) var ARC_SCENES = []
export(Array, PackedScene) var CEILING_SCENES = []

export(PackedScene) var NPC_SCENE = preload("res://npcs/scenes/NPC.tscn")
export(PackedScene) var LIGHT_SCENE = preload("res://tiles/scenes/LightBulb.tscn")
export(NodePath) var PLAYER1_PATH = "../Player"
export(NodePath) var PLAYER2_PATH = ""

var GRID_SIZE = Vector3(10, 0, 10)
var x_limits = [INF, -INF]
var z_limits = [INF, -INF]
var painted_cells = {}
var wall_cells = {}
var baked_nav_mesh = PoolVector3Array([])
var should_bake_nav_meshes = false
var loading_progress = 0
var total_loading = 0
var spawning_points = []
var player1
var player2

signal finished_grid
signal finished_walls
signal finished_objects
signal npcs_spawned

func _ready():
	self.owner = get_parent()
	if not PLAYER1_PATH == "":
		player1 = get_node(PLAYER1_PATH)
	if not PLAYER2_PATH == "":
		player2 = get_node(PLAYER2_PATH)
		
	
#	$Camera.current = true
#	player1.camera.current = false
	_set_npcs_paused(true)
	
	# Adjust the size of grid to match the map size
	GRID_SIZE = MAP_SIZE / grid.cell_size
	player1.controller.set_physics_process(false)
	if is_instance_valid(player2):
		player2.controller.set_physics_process(false)
	
	# Calculate total loading
	loading_progress = 0
	calculate_total_loading()
	
	screens.set_loading_screen(loading_progress, "Creating mine's corridors...")
	if grid.get_used_cells().size() <= 0:
		should_bake_nav_meshes = true
		print("Generating map...")
		_generate_map()
		yield(self, "finished_grid")
		
	
	# Adds points and connections to NavGrid 
#	nav_grid.navigation = nav
	nav_grid.bake_points()
		
	print(">> Generated tiles")
	
	loading_progress += 10
	screens.set_loading_screen(loading_progress, "Adding destructible walls...")
	_add_walls()
	print(">> Added destructible walls")
	
	loading_progress += WALLS_COUNT
	screens.set_loading_screen(loading_progress, "Adding lights...")	
	_add_lights()
	print(">> Added lights")
	
	loading_progress += 10
	screens.set_loading_screen(loading_progress, "Spawning enemies...")
	_spawn_npcs()
	yield(self, "npcs_spawned")
	get_parent().configure_npcs_signals()
	print(">> Spawned NPCs")

	if not should_bake_nav_meshes:
		_calculate_map_limits()
	
	screens.set_loading_screen(loading_progress, "Adding gold piles...")	
	_add_objects([GOLD_PILE_SCENE], GOLD_PILES_COUNT, "Adding gold piles...", 0.6, 0.75, 15, gold_piles)
#	yield(self, "finished_objects")
	print(">> Added gold piles")
	
	screens.set_loading_screen(loading_progress, "Spawning destructible items...")		
	_add_objects(OBJECTS_SCENES, ITEMS_COUNT, "Adding destructible objects...")
#	yield(self, "finished_objects")
	print(">> Added items")
	
#	if should_bake_nav_meshes and Engine.editor_hint:
#		NavigationMeshGenerator.bake(nav_mesh.navmesh, nav)
		
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	loading_progress += 5
	screens.set_loading_screen(loading_progress, "Finishing...")
	yield(get_tree(), "idle_frame")

	loading_progress += 5
	screens.set_loading_screen(loading_progress, "LET'S GO!")
	print("Starting match!")
#	$PaintedGrid.show()	
#	$PaintedGrid.hide()	
	get_parent().start_match()
#	yield(get_tree().create_timer(15), "timeout")

	_set_npcs_paused(false)
	
	player1.enable()
	if is_instance_valid(player2):
		player2.enable()


func calculate_total_loading():
	total_loading += 10 # Generate gridmaps
	total_loading += 10 # Generate lights
	total_loading += 10 # Finishing
	total_loading += WALLS_COUNT
	total_loading += ITEMS_COUNT
	total_loading += GOLD_PILES_COUNT
	total_loading += NPCS_COUNT

func _generate_map():
	grid.clear()
	$PaintedGrid.clear()
#	NavigationMeshGenerator.clear(nav_mesh.navmesh)
	painted_cells = {}
	yield(get_tree(), "idle_frame")
	_generate_grid_map()
	yield(get_tree(), "idle_frame")

	
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
			wall.owner = self.owner
			wall_cells[String(cell)] = true
			var orientation = grid.get_cell_item_orientation(cell.x, cell.y, cell.z)
			var angle = _get_rotation_from_orientation(orientation)
			var cross_dir = Vector3(1, 0, 0).rotated(Vector3.UP, angle.y + deg2rad(90))
			var cells = [cell - 2 * cross_dir, cell - cross_dir, cell, cell + cross_dir, cell + 2 * cross_dir]
			nav_grid.disable_cells_inside_AABB(cur_point, wall.mesh_instance.get_transformed_aabb())
#			$PaintedGrid.disable_cells(cells)
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
		light.owner = self.owner
		light.global_transform.origin = cur_point


func _add_objects(scenes: Array, quantity: int, text: String, min_scale = 1, max_scale = 1, max_rotation = 0, parent = items):
	var count = 0
	while count < quantity:
		
		var scene = scenes[randi() % scenes.size()]
		var object: Destructible = scene.instance()
		
		parent.add_child(object)
		object.owner = self.owner
		
		object.scale.x = rand_range(min_scale, max_scale)
		object.scale.y = rand_range(min_scale, max_scale)
		object.scale.z = rand_range(min_scale, max_scale)
		object.rotation_degrees.x = rand_range(-max_rotation, max_rotation)
		object.rotation_degrees.y = rand_range(0, 360)
		object.rotation_degrees.z = rand_range(-max_rotation, max_rotation)
		
		var nav_point = nav_grid.get_random_available_position_for_obstacle(object.mesh_instance.get_transformed_aabb())
		
		object.global_transform.origin = nav_point
		if object.is_blocking_npc():
			object.call_deferred("queue_free")
			continue
		else:
			object.remove_inner_area()
			count += 1
			loading_progress += 1
			screens.set_loading_screen(loading_progress, "["+ str(count) +"/" + str(quantity) + "] " + text)
			
			### Updates paint grid with AABB overlaps
			if is_instance_valid(object.mesh_instance):
				var aabb = object.mesh_instance.get_transformed_aabb()
				nav_grid.disable_cells_inside_AABB(object.global_transform.origin, aabb)
					
					
	emit_signal("finished_objects")
	

func _add_objects_by_physics(scenes: Array, quantity: int, text: String, min_scale = 1, max_scale = 1, max_rotation = 0, parent = items):
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
			object.owner = self.owner
			
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
				screens.set_loading_screen(loading_progress, "["+ str(count) +"/" + str(quantity) + "] " + text)
				
				### Updates paint grid with AABB overlaps
				if is_instance_valid(object.mesh_instance):
					var aabb = object.mesh_instance.get_transformed_aabb()
					nav_grid.disable_cells_inside_AABB(object.global_transform.origin, aabb)
					
					
	emit_signal("finished_objects")



func _generate_grid_map():
	
	var angles = [0]
	
	var cur_points = [Vector3(0, 0, 0)]
		
	var total_area = 0
	
	# Fill first open door with wall
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
					total_area += SIZES[tile].x * SIZES[tile].z
					
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
					
					# Adds specific walls according to tile
					if tile in [Tiles.CORREDOR_MEDIO, Tiles.CORREDOR_CURTO] and randf() < ARCS_PROB:
						# Adds a arc
						var arc_scene: PackedScene = ARC_SCENES[randi() % ARC_SCENES.size()]
						var arc: Destructible = arc_scene.instance()
						arc.rotation_degrees.y = -90 + angle
						arcs.add_child(arc)
						arc.owner = self.owner
						var world_position = grid.map_to_world(cur_point.x, cur_point.y, cur_point.z)
						arc.global_transform.origin = world_position
						if arc.name.find("RockArcCeiling") >= 0:
							arc.global_transform.origin.y += 6.5
					
					elif tile in [Tiles.HALL_GRANDE, Tiles.HALL_T, Tiles.HALL_X] and randf() < CEILINGS_PROB:
						# Adds a ceiliing if tile is Hall 50% of the times
						var ceiling_scene: PackedScene = CEILING_SCENES[randi() % CEILING_SCENES.size()]
						var ceiling: Destructible = ceiling_scene.instance()
						ceiling.rotation_degrees.y = -90 + angle
						ceilings.add_child(ceiling)
						ceiling.owner = self.owner
						var world_position = grid.map_to_world(cur_point.x, cur_point.y, cur_point.z)
						ceiling.global_transform.origin = world_position
						ceiling.global_transform.origin.y += 6.5
					
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
		for n in arcs.get_children():
			arcs.remove_child(n)
			n.queue_free()

		for n in ceilings.get_children():
			ceilings.remove_child(n)
			n.queue_free()
			
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
	
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	emit_signal("finished_grid")
	return true
	

func _spawn_npcs():
	var npcs_count = NPCS_COUNT
	
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
			npc.player = player1
			npcs.add_child(npc)
			npc.owner = self.owner
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
				spawning_points.append(npc.global_transform.origin)
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
		player1.camera.current = false
	elif Input.is_action_just_pressed("ui_focus_next") and $Camera.current:
		$Camera.current = false
		player1.camera.current = true
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


func _on_NPCSpawnTimer_timeout(force = false):
	print(">> Spawning new NPC")
	if (get_parent().SPAWN_NPCS_TIMER_ACTIVE and get_parent().npcs_count - get_parent().npcs_dead < 6) or force:
		var npc = NPC_SCENE.instance()
		npc.NAV_GRID_PATH = $PaintedGrid.get_path()
		npc.paused = false
		npc.obstacles = obstacles
		npc.gold_piles = gold_piles
		npc.player = player1
		npcs.add_child(npc)
		npc.owner = self.owner
		var initial_spawn_points_size = spawning_points.size() if spawning_points.size() else 1
		npc.global_transform.origin = spawning_points[randi() % initial_spawn_points_size]
		npc.remove_inner_area()
		get_parent().increment_npc_count()
		get_parent().set_npc_signals(npc)
