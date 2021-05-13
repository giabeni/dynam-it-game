extends Node

class_name Rooms

const ROOM_CONTAINER_SCENE = preload("res://server/scenes/RoomContainer.tscn")

var current_room: RoomContainer = null

remote func update_rooms(rooms_json: String):
	print("REMOTE: Updating rooms...", rooms_json)
	var room_infos = parse_json(rooms_json)
	for room_id in room_infos:
		var room: RoomContainer
		var room_info = room_infos[room_id]
		if has_node(str(room_id)):
			room = get_node(str(room_id))
		else:
			room = ROOM_CONTAINER_SCENE.instance()
			room.name = str(room_info["room_id"])
			room.set_info(room_info)
			add_child(room, true)


remote func join_room(room_info_json, room_spot):
	print("REMOTE: Setting current room: ", room_info_json)
	var room_info = parse_json(room_info_json)
	if not has_node(str(room_info.room_id)):
		var room = ROOM_CONTAINER_SCENE.instance()
		room.name = str(room_info["room_id"])
		room.set_info(room_info)
		add_child(room, true)
	
	current_room = get_node(str(room_info.room_id))
	current_room.set_spot(Server.username, room_spot)

