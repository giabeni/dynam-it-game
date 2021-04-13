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
	Tiles.HALL_T: Vector3(7, 1, 10),
	Tiles.HALL_X: Vector3(10, 1, 10),
	Tiles.HALL_X: Vector3(10, 1, 10),
	Tiles.CORREDOR_CURTO: Vector3(5, 1, 5),
	Tiles.CORREDOR_MEDIO: Vector3(10, 1, 5),
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

onready var grid: GridMap = $Navigation/NavigationMeshInstance/GridMap
onready var nav_mesh: NavigationMeshInstance = $Navigation/NavigationMeshInstance
onready var arrow = $Navigation/NavigationMeshInstance/GridMap/Point

export(Vector3) var MAP_SIZE = Vector3(60, 0, 60)
export(float) var MIN_ROOMS_DISTANCE = 40

var GRID_SIZE = Vector3(10, 0, 10)
var painted_cells = {}

func _ready():
	randomize()
	# Adjust the size of grid to match the map size
	GRID_SIZE = MAP_SIZE / grid.cell_size
	print(GRID_SIZE)
	
	_generate_map()
	

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_select"):
		grid.clear()
		$Navigation/NavigationMeshInstance/GridMap3.clear()
		painted_cells = {}
		_generate_map()
	

func _generate_map():
	
	var angles = [0]
	
	var cur_points = [Vector3(0, 0, 0)]
	
	var total_area = 0
	
	# Fill first open door with all
	var first_point = Vector3(-1, 0, 0)
	var first_wall_orientation = _get_orientation(90, 90)
	grid.set_cell_item(first_point.x, first_point.y, first_point.z, Tiles.PLATAFORMA, first_wall_orientation)
	

	while total_area <= 5000 and cur_points.size() > 0:
		var next_angles: Array = []
		var next_points: Array = []
		
		for p in range(0, cur_points.size()):
			var cur_point = cur_points[p]
			var angle = angles[p]
			
			yield(get_tree().create_timer(0.025), "timeout")
			
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
					print(cur_point)
					grid.set_cell_item(cur_point.x, cur_point.y, cur_point.z, tile, orientation)
					
					could_add_tile = true
					total_area += SIZES[tile].x * SIZES[tile].z
					
					# Paint occupied cells
					_paint_cells(tile, cur_point, angle)
					
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
				
				
		angles = next_angles
		cur_points = next_points
	
	# If area is too smal (less than a half), tries again
	if total_area <= 5000/2:
		grid.clear()
		$Navigation/NavigationMeshInstance/GridMap3.clear()
		painted_cells = {}
		_generate_map()
		return
	
	# Fill remaining doors with walls
	for p in range(0, cur_points.size()):
		var cur_point = cur_points[p]
		var angle = angles[p]
		var wall_orientation = _get_orientation(angle - 90, 90)
		grid.set_cell_item(cur_point.x, cur_point.y, cur_point.z, Tiles.PLATAFORMA, wall_orientation)
		
	return true
	
			
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
	

func _paint_cells(tile, cur_point, angle):
	var size: Vector3 = SIZES[tile]
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
			$Navigation/NavigationMeshInstance/GridMap3.set_cell_item(point.x, point.y, point.z, 1)
			
		cell += dir
		

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


func _is_point_available_old(point):
	var cells = grid.get_used_cells()
	
	for cell in cells:
		var orientation = grid.get_cell_item_orientation(cell.x, cell.y, cell.z)
		var angle = rad2deg(_get_rotation_from_orientation(orientation).y)
		var tile = grid.get_cell_item(cell.x, cell.y, cell.z)
		var size: Vector3 = SIZES[tile]
		var offset = Vector3(size.x, 0, 0).rotated(Vector3.UP, deg2rad(angle))
		var limit = cell + offset
		var dir: Vector3 = offset.normalized()
		
		var cur_point = cell
		while (limit - cur_point).length() >= 0.01:
			var width_dir = dir.rotated(Vector3.UP, deg2rad(90))
			for w in range(-size.z/2, size.z/2):
				var p = cell + width_dir * ceil(w)
				if (p - point).length() < 1:
					print(false)
					return false
				
			cur_point += dir
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
