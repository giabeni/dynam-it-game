extends Control

onready var players_list = $CenterContainer/PlayerList

func update_players_list(spots):
	var bbcode = "[center][table=2][cell][u]          Username          [/u][/cell] [cell][u]Spot[/u][/cell][cell][/cell] [cell][/cell]"
	
	for username in spots:
		bbcode += "[cell]" + username + "[/cell] [cell]" + str(spots[username]) + "[/cell]"
		
	bbcode += "[/table][/center]"
	
	players_list.bbcode_text = bbcode
