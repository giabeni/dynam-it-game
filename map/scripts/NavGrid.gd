extends GridMap

class_name NavGrid

onready var astar = AStar.new()

var navigation: Navigation = null
var CELL_TO_POINTS = {}

enum Tiles {
	WALKABLE,
	NOT_WALKABLE,
	PATH,
	OBSTACLE,
}


var path_cells = []
var path_tiles = []

var debug_navigation = false

func _ready():
	if debug_navigation:
		show()
	

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
	
	var should_disable_origin = false
	var should_disable_target = false
	
	
	if astar.is_point_disabled(origin):
		print(">>>> Origin cell is disabled")
		astar.set_point_disabled(origin, false)
		should_disable_origin = true
	if astar.is_point_disabled(target):
		print(">>>> Target cell is disabled")
		astar.set_point_disabled(target, false)
		should_disable_target = true
		
	var path = astar.get_point_path(origin, target)
	
	if paint_cells and debug_navigation:
		for c in range(path_cells.size()):
			var cell = path_cells[c]
			set_cell_item(cell.x, cell.y, cell.z, path_tiles[c])
		path_cells = []
		path_tiles = []
		
		# DEBUG REACHABLE CELLS
#		var connections = astar.get_point_connections(origin)
#		var i = 0
#		while i < connections.size():
#			var point = connections[i]
#			for con in astar.get_point_connections(point):
#				if not con in connections:
#					connections.append(con)
#				if con == target:
#					print("TARGET IS REACHABLE!")
#					break
#
#			point = astar.get_point_position(point)
#			var cell = world_to_map(point)			
#			var original_tile = get_cell_item(cell.x, cell.y, cell.z)
#			path_tiles.append(original_tile)
#			path_cells.append(cell)
#			set_cell_item(cell.x, cell.y, cell.z, Tiles.PATH)
#			i += 1
		if debug_navigation:
			for point in path:
				var cell = world_to_map(point)
				var original_tile = get_cell_item(cell.x, cell.y, cell.z)
				path_tiles.append(original_tile)
				path_cells.append(cell)
				set_cell_item(cell.x, cell.y, cell.z, Tiles.PATH)
			
			
	if should_disable_origin:
		astar.set_point_disabled(origin, true)
	if should_disable_target:
		astar.set_point_disabled(target, true)
		
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
#			astar.set_point_disabled(point_id, true)


func enable_cells(cells: Array):
	for cell in cells:
		cell += Vector3(0.01, 0.01, 0.01) # Hack to avoid -0
		cell = cell.round()
		set_cell_item(cell.x, cell.y, cell.z, Tiles.WALKABLE)
		if String(cell) in CELL_TO_POINTS:
			var point_id = CELL_TO_POINTS[String(cell)]
			astar.set_point_disabled(point_id, false)
			

func disable_cells_inside_AABB(origin: Vector3, aabb: AABB):
	var origin_point = astar.get_closest_point(origin)
	var origin_cell = self.world_to_map(origin)
	set_cell_item(origin_cell.x, origin_cell.y, origin_cell.z, Tiles.OBSTACLE)
	var cells_to_disable = [origin_cell]
	var edge = self._get_used_neighbours(origin_cell)
	var visited = {}
	var grown_aabb = aabb.grow(0)

	while (edge.size() > 0):
		var cell: Vector3 = edge.pop_front()
		visited[String(cell)] = true
		if grown_aabb.has_point(map_to_world(cell.x, cell.y, cell.z)):
			cells_to_disable.append(cell)
			set_cell_item(cell.x, cell.y, cell.z, Tiles.OBSTACLE)
			var neighbours = _get_used_neighbours(cell)
			for n in neighbours:
				# If the neighbour isn't already in the edge and has never been visited before, it can be added to the edge
				if edge.find(n) == -1 and (not visited.has(String(n)) or not visited[String(n)]):
					edge.append(n)


func get_cells_inside_AABB(map_cell: Vector3, aabb: AABB, grow = 0):
	set_cell_item(map_cell.x, map_cell.y, map_cell.z, Tiles.OBSTACLE)
	var cells_inside_ABBB = [map_cell]
	var edge = self._get_used_neighbours(map_cell)
	var visited = {}
	var grown_aabb = aabb.grow(grow)

	while (edge.size() > 0):
		var cell: Vector3 = edge.pop_front()
		visited[String(cell)] = true
		if grown_aabb.has_point(map_to_world(cell.x, cell.y, cell.z)):
			cells_inside_ABBB.append(cell)
			var neighbours = _get_used_neighbours(cell)
			for n in neighbours:
				# If the neighbour isn't already in the edge and has never been visited before, it can be added to the edge
				if edge.find(n) == -1 and (not visited.has(String(n)) or not visited[String(n)]):
					edge.append(n)
	return cells_inside_ABBB


func get_random_available_position_for_obstacle(aabb: AABB):
	var used_cells = get_used_cells()
	var cell_to_return: Vector3
	var found_cell = false
	
	while not found_cell:
		var random_cell = used_cells[randi() % used_cells.size()]
		if get_cell_item(random_cell.x, random_cell.y, random_cell.z) != Tiles.WALKABLE:
			found_cell = false
			continue
		
		var aabb_cells = get_cells_inside_AABB(random_cell, aabb)
		for cell in aabb_cells:
			if get_cell_item(cell.x, cell.y, cell.z) == Tiles.OBSTACLE:
				found_cell = false
				continue
		
		found_cell = true
		cell_to_return = random_cell
	
	return map_to_world(cell_to_return.x, cell_to_return.y, cell_to_return.z)
		
		
	
