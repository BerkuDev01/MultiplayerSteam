extends Node

# Gestiona la lógica del juego, spawns y puntuación

signal game_started()
signal player_scored(player_id: int, new_score: int)
signal game_ended(winner_id: int)

# Referencias a spawns
@onready var spawn1 = $"../Spawns/Spawn1"
@onready var spawn2 = $"../Spawns/Spawn2"
@onready var multiplayer_spawner = $MultiplayerSpawner

# Prefab del jugador
const PLAYER_SCENE = preload("res://scenes/player.tscn")

# Datos del juego
var players: Dictionary = {}
var scores: Dictionary = {}
var max_score: int = 5
var is_game_active: bool = false

func _ready():
	print("=== GAMEMANAGER READY ===")
	
	# Verificar spawns
	if spawn1 == null:
		print("ERROR: No se encontró Spawn1")
		return
	if spawn2 == null:
		print("ERROR: No se encontró Spawn2")
		return
	
	print("Spawn1: ", spawn1.global_position)
	print("Spawn2: ", spawn2.global_position)
	
	# Verificar si estamos en red
	print("Multiplayer autoridad: ", multiplayer.get_unique_id())
	print("¿Es servidor?: ", multiplayer.is_server())
	
	# Esperar a que la red esté lista
	await get_tree().create_timer(0.5).timeout
	
	# Solo el servidor/host spawnea jugadores
	if multiplayer.is_server():
		print("SOY SERVIDOR - Spawneando jugadores...")
		_spawn_all_players()
	else:
		print("SOY CLIENTE - Esperando spawns del servidor...")
	
	is_game_active = true
	game_started.emit()

func _spawn_all_players():
	print("=== SPAWNEANDO TODOS LOS JUGADORES ===")
	
	var players_to_spawn = []
	
	# Obtener lista de jugadores según el modo
	if SteamManager.current_lobby_type == SteamManager.LobbyType.STEAM:
		print("Obteniendo miembros de Steam...")
		var members = SteamManager.get_lobby_members()
		print("Miembros Steam: ", members)
		
		for member_id in members:
			var data = SteamManager.get_player_data(member_id)
			print("  - Miembro: ", member_id, " -> ", data)
			players_to_spawn.append({
				"id": member_id,
				"name": data["name"],
				"color": data["color"]
			})
	else:
		print("Obteniendo peers de LAN...")
		var peers = LANManager.get_connected_peers()
		print("Peers LAN: ", peers)
		
		for peer_id in peers:
			var data = LANManager.get_player_data(peer_id)
			print("  - Peer: ", peer_id, " -> ", data)
			players_to_spawn.append({
				"id": peer_id,
				"name": data["name"],
				"color": data["color"]
			})
	
	print("Total jugadores a spawnear: ", players_to_spawn.size())
	
	# Spawnear cada jugador
	for i in range(players_to_spawn.size()):
		var player_info = players_to_spawn[i]
		var spawn_pos = spawn1.global_position if i == 0 else spawn2.global_position
		
		print("Spawneando jugador ", i, ": ", player_info["name"], " en ", spawn_pos)
		_spawn_player(player_info["id"], player_info["name"], player_info["color"], spawn_pos)

func _spawn_player(peer_id: int, player_name: String, color: Color, spawn_position: Vector2):
	print("  > Creando instancia de jugador...")
	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_" + str(peer_id)
	player.global_position = spawn_position
	
	print("  > Configurando propiedades...")
	# Configurar antes de añadir al árbol
	player.peer_id = peer_id
	player.player_name = player_name
	player.player_color = color
	
	# Determinar si es local
	if SteamManager.current_lobby_type == SteamManager.LobbyType.STEAM:
		player.is_local = (peer_id == SteamManager.steam_id)
	else:
		player.is_local = (peer_id == multiplayer.get_unique_id())
	
	print("  > Añadiendo al árbol...")
	# Añadir al nodo Game (padre del GameManager)
	get_parent().add_child(player)
	
	print("  > Guardando referencia...")
	players[peer_id] = {
		"node": player,
		"score": 0,
		"color": color,
		"name": player_name
	}
	scores[peer_id] = 0
	
	print("  ✓ Jugador spawneado: ", player_name, " | Local: ", player.is_local)

func add_score(peer_id: int):
	if not scores.has(peer_id):
		return
	
	scores[peer_id] += 1
	player_scored.emit(peer_id, scores[peer_id])
	
	print("Puntuación: ", players[peer_id]["name"], " = ", scores[peer_id])
	
	if scores[peer_id] >= max_score:
		_end_game(peer_id)

func _end_game(winner_id: int):
	is_game_active = false
	game_ended.emit(winner_id)
	print("¡Juego terminado! Ganador: ", players[winner_id]["name"])

func reset_positions():
	var peer_ids = players.keys()
	for i in range(peer_ids.size()):
		var peer_id = peer_ids[i]
		var spawn_pos = spawn1.global_position if i == 0 else spawn2.global_position
		players[peer_id]["node"].global_position = spawn_pos
		players[peer_id]["node"].linear_velocity = Vector2.ZERO
		players[peer_id]["node"].angular_velocity = 0.0
