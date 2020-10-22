extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var deck = []
var deck_size = 52

var currPlayers = 0
var players = []

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	for n in range(52):
		deck.append(n+1)
	get_node("../Game/DeckList").text = String(deck)
	players.resize(4)
	get_node("../Game").hide()
	get_node("../Game/DealerButtons").hide()
	get_node("../Game/DealerButtons/Deal 1 P1").hide()
	get_node("../Game/DealerButtons/Deal 1 P2").hide()
	get_node("../Game/DealerButtons/Deal 1 P3").hide()
	get_node("../Game/DealerButtons/Deal 1 P4").hide()
	pass # Replace with function body.

func _process(delta):
	var s = ""
	for i in player_info:
		s += String(player_info[i]) + "\n"
	get_node("../Game/Players").text = s
	if my_info.host:
		get_node("../Game/NumPlayers").text = String(currPlayers)

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		get_tree().network_peer = null
		print ("set network peer to null")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func connect_player(host):
	my_info.name = get_node("../LobbyMenu/Name").text
	var peer = NetworkedMultiplayerENet.new()
	if host:
		#peer.set_bind_ip("192.168.1.72")
		peer.create_server(6666, 10)
	else:
		peer.create_client(get_node("../LobbyMenu/IP text").text, 6666)
	get_tree().network_peer = peer
	my_info.peer_id = get_tree().get_network_unique_id()
	my_info.host = host
	player_info[my_info.peer_id] = my_info
	if my_info.host:
		add_first_available(my_info)
		update_game_state()
	get_node("../LobbyMenu").hide()
	get_node("../Game").show()
	if my_info.host:
		get_node("../Game/DealerButtons").show()

func _on_Host_pressed():
	connect_player(true)

func _on_Join_pressed():
	connect_player(false)

# Player info, associate ID to data
var player_info = {}
# Info we send to other players
var my_info = { name = "Johnson Magenta", hand = [], host = false }

func broadcast_update_clients():
	update_game_state()
	for i in range(players.size()):
		if players[i] && !players[i].host:
			rpc_id(players[i].peer_id, 'game_state', {players = players, deck_size = deck.size()})

func _player_connected(id):
	# Called on both clients and server when a peer connects. Send my info to it.
	print("player_connected, sending info" + my_info.name)
	print("player_connected, with id " + String(id))
	rpc_id(id, "register_player", my_info)

func _player_disconnected(id):
	print("_player_disconnected, with id " + String(id))
	player_info.erase(id) # Erase player from info.
	if my_info.host:
		remove_player_by_id(id)

func remove_player_by_id(id):
	for i in range(players.size()):
		if players[i] && players[i].peer_id == id:
			players[i] = null
			currPlayers-=1
			get_node("../Game/DealerButtons/Deal 1 P" + String(i+1)).hide()
			broadcast_update_clients()
			break

func _connected_ok():
	print("connected_ok")  # Only called on clients, not server. Will go unused; not useful here.

func _server_disconnected():
	print("_server_disconnected") # Server kicked us; show error and abort.

func _connected_fail():
	print("_connected_fail") # Could not even connect to server; abort.

remote func register_player(info):
	print ("got info" + String(info))
	# Get the id of the RPC sender.
	var id = get_tree().get_rpc_sender_id()
	# Store the info
	player_info[id] = info
	if my_info.host:
		if currPlayers < 4:
			print("yes, <4")
			add_first_available(info)
			broadcast_update_clients()

func add_first_available(info):
	for i in range(players.size()):
		print("i", i, "player", players[i])
		if players[i] == null:
			players[i] = info
			currPlayers += 1
			if my_info.host:
				get_node("../Game/DealerButtons/Deal 1 P" + String(i+1)).show()
			return i

remote func game_state(game_info):
	print("hi" + String(game_info.players))
	players = game_info.players
	deck_size = game_info.deck_size
	update_game_state()

func get_player_node(i):
	return get_node("../Game/P" + String(i))

func update_game_state():
	if my_info.host:
		get_node("../Game/DeckList").text = String(deck)
	else:
		get_node("../Game/DeckList").text = String(deck_size)
	for i in range(players.size()):
		var player_name = get_player_node(i+1).get_node("Name")
		var player_hand = get_player_node(i+1).get_node("Hand")
		if players[i] == null:
			player_name.text = "P" + String(i+1)
			player_hand.text = "[]"
		else:
			player_name.text = players[i].name
			if players[i].host:
				player_name.text += " (dealer)"
			player_hand.text = String(players[i].hand)

func _on_Shuffel_Deck_pressed():
	if !my_info.host: return
	deck.shuffle()
	broadcast_update_clients()

func _on_Deal_pressed():
	if !my_info.host: return
	for i in player_ids():
		deal_one_card(i)
	broadcast_update_clients()

func _on_Reset_pressed():
	if !my_info.host: return
	for p in players:
		if p:
			p.hand.clear()
	deck.clear()
	for n in range(52):
		deck.append(n+1)
	broadcast_update_clients()

func player_ids():
	var ids = []
	for i in range(players.size()):
		if players[i]:
			ids.append(i)
	return ids

func deal_one_card(player_id):
	if deck.size() == 0: return
	if !players[player_id]: return
	players[player_id].hand.append(deck.pop_front())


func _on_Deal_1_P1_pressed():
	deal_one_card(0)
	broadcast_update_clients()

func _on_Deal_1_P2_pressed():
	deal_one_card(1)
	broadcast_update_clients()

func _on_Deal_1_P3_pressed():
	deal_one_card(2)
	broadcast_update_clients()

func _on_Deal_1_P4_pressed():
	deal_one_card(3)
	broadcast_update_clients()
