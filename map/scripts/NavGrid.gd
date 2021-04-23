extends GridMap

class_name NavGrid

onready var astar = AStar.new()

var navigation: Navigation = null
var CELL_TO_POINTS = {}

enum Tiles {
	WALKABLE,
	NOT_WALKABLE,
}

func _ready():
	pass
	

func bake_points():
	# Get painted cells
	var cells = get_used_cells()
	
	# Adds all cells
	for cell in cells:
		if get_cell_item(cell.x, cell.y, cell.z) == Tiles.WALKABLE:
			var world_pos = map_to_world(cell.x, cell.y, cell.z)
			var id = astar.get_available_point_id()
			astar.add_point(id, world_pos)
			CELL_TO_POINTS[String(cell)] = id
		
	# Connect neighbours
	for cell in cells:
		if String(cell) in CELL_TO_POINTS:
			var cell_id = CELL_TO_POINTS[String(cell)]
			var neighbours = _get_used_neighbours(cell)
			for neighbour in neighbours:
				if get_cell_item(cell.x, cell.y, cell.z) == Tiles.WALKABLE and String(neighbour) in CELL_TO_POINTS:
					var neighbour_id = CELL_TO_POINTS[String(neighbour)]
					if not astar.are_points_connected(cell_id, neighbour_id):
		#				print("Connecting: ", cell_id, " to ", neighbour_id)
						astar.connect_points(cell_id, neighbour_id)


func _get_used_neighbours(map_cell: Vector3):
	var neighbours = []
	
	var test_cell = map_cell + Vector3.LEFT
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.RIGHT
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.FORWARD
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.BACK
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
	
	test_cell = map_cell + Vector3.LEFT + Vector3.FORWARD
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.RIGHT + Vector3.FORWARD
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.LEFT + Vector3.BACK
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
	test_cell = map_cell + Vector3.RIGHT + Vector3.BACK
	if get_cell_item(test_cell.x, test_cell.y, test_cell.z) == Tiles.WALKABLE:
		neighbours.append(test_cell)
		
		
	return neighbours
	

func get_simple_path(from: Vector3, to: Vector3, paint_cells = false):
	
	if is_instance_valid(navigation):
		return navigation.get_simple_path(from, to)
	
	var origin = astar.get_closest_point(from)
	var target = astar.get_closest_point(to)
		
	var path = astar.get_point_path(origin, target)
	
	if paint_cells:
		for point in path:
			var cell = world_to_map(point)
			set_cell_item(cell.x, cell.y, cell.z, 0)
			
	return path
	

func get_closest_point(to: Vector3):
	if is_instance_valid(navigation):
		return navigation.get_closest_point(to)
	else:
		return astar.get_point_position(astar.get_closest_point(to))
		

func disable_cells(cells: Array):
	for cell in cells:
		cell += Vector3(0.01, 0.01, 0.01) # Hack to avoid -0
		cell = cell.round()
		set_cell_item(cell.x, cell.y, cell.z, Tiles.NOT_WALKABLE)
		if String(cell) in CELL_TO_POINTS:
			var point_id = CELL_TO_POINTS[String(cell)]
			astar.set_point_disabled(point_id, true)
