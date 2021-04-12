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

const ROOMS = [Tiles.HALL_GRANDE]

const ORIENTATIONS = {
	Tiles.HALL_GRANDE: [0, 90, 180, -90]
}

onready var grid: GridMap = $Navigation/NavigationMeshInstance/GridMap
onready var nav_mesh: NavigationMeshInstance = $Navigation/NavigationMeshInstance

export(Vector3) var MAP_SIZE = Vector3(120, 0, 120)
export(float) var MIN_ROOMS_DISTANCE = 30

var GRID_SIZE = Vector3(10, 0, 10)

func _ready():
	# Adjust the size of grid to match the map size
	GRID_SIZE = MAP_SIZE / grid.cell_size
	print(GRID_SIZE)
	
	_generate_map()
	

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_select"):
		grid.clear()
		_generate_map()
	

func _generate_map():
	# Fill the map with rooms
	for x in range(-GRID_SIZE.x, GRID_SIZE.x, MIN_ROOMS_DISTANCE):
		for z in range(-GRID_SIZE.z, GRID_SIZE.z, MIN_ROOMS_DISTANCE):
			var y = 0
			var orientation = get_random_orientation(Tiles.HALL_GRANDE)
			grid.set_cell_item(x, y, z, Tiles.HALL_GRANDE, orientation)
			
			
func get_random_orientation(tile_index: int):
	var a = int(round(rand_range(0, ORIENTATIONS[Tiles.HALL_GRANDE].size() - 1)))
	var angle = ORIENTATIONS[Tiles.HALL_GRANDE][a]
	var quat = Quat(Vector3.UP, deg2rad(angle))
	var cell_item_orientation = Basis(quat).get_orthogonal_index()
	return cell_item_orientation
