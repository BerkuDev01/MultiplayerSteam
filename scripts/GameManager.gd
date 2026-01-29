extends Node

# Gestiona la lógica del juego, spawns y puntuación

signal game_started()
signal player_scored(player_id: int, new_score: int)
signal game_ended(winner_id: int)

# Posiciones de spawn (las definimos aquí si no hay Marker2D)
var spawn_positions: Array[Vector2] = [
	Vector2(200, 300),   # Spawn 1 (izquierda)
	Vector2(900, 300)    # Spawn 2 (derecha)
]

# Prefab del jugador
var player_scene_path = "res://scenes/player.tscn"

# Datos del juego
var players: Dictionary = {}  # {peer_id: {node: Node2D, score: int, color: Color, name: String}}
var scores: Dictionary = {}  # {peer_id: score}
var max_score: int = 5
var is_game_active: bool = false

func _ready():
	print("=== GAMEMANAGER READY ===")
	
	# Esperar un momento para que todo esté listo
	await get_tree().create_timer(0.5).timeout
	
	# Determinar qué sistema de red estamos usando y spawnear jugadores
	if SteamManager.current_lobby_type == SteamManager.LobbyType.STEAM:
		print("Usando modo Steam")
		_setup_steam_game()
	else:
		print("Usando modo LAN")
		_setup_lan_game()
	
	is_game_active = true
	game_started.emit()

func _setup_steam_game():
	print("Configurando juego Steam...")
	var members = SteamManager.get_lobby_members()
	print("Miembros en Steam: ", members)
	
	for i in range(members.size()):
		var member_id = members[i]
		var player_data = SteamManager.get_player_data(member_id)
		
		var spawn_pos = spawn_positions[i] if i < spawn_positions.size() else Vector2(400 + i * 200, 300)
		print("Spawneando en posición: ", spawn_pos)
		_spawn_player(member_id, player_data["name"], player_data["color"], spawn_pos)

func _setup_lan_game():
	print("Configurando juego LAN...")
	var peers = LANManager.get_connected_peers()
	print("Peers en LAN: ", peers)
	
	for i in range(peers.size()):
		var peer_id = peers[i]
		var player_data = LANManager.get_player_data(peer_id)
		
		var spawn_pos = spawn_positions[i] if i < spawn_positions.size() else Vector2(400 + i * 200, 300)
		print("Spawneando en posición: ", spawn_pos)
		_spawn_player(peer_id, player_data["name"], player_data["color"], spawn_pos)

func _spawn_player(peer_id: int, player_name: String, color: Color, spawn_position: Vector2):
	print("=== SPAWNEANDO JUGADOR ===")
	print("  Peer ID: ", peer_id)
	print("  Nombre: ", player_name)
	print("  Color: ", color)
	print("  Posición: ", spawn_position)
	
	# Cargar escena del jugador
	var player_scene = load(player_scene_path)
	if player_scene == null:
		print("ERROR: No se pudo cargar la escena del jugador en: ", player_scene_path)
		return
	
	var player_instance = player_scene.instantiate()
	player_instance.name = "Player_" + str(peer_id)
	player_instance.position = spawn_position
	
	# Configurar jugador
	player_instance.peer_id = peer_id
	player_instance.player_name = player_name
	player_instance.player_color = color
	
	# Determinar si este jugador es local
	if SteamManager.current_lobby_type == SteamManager.LobbyType.STEAM:
		player_instance.is_local = (peer_id == SteamManager.steam_id)
	else:
		player_instance.is_local = (peer_id == multiplayer.get_unique_id())
	
	# Añadir al árbol de escena
	get_parent().add_child(player_instance)
	
	# Guardar referencia
	players[peer_id] = {
		"node": player_instance,
		"score": 0,
		"color": color,
		"name": player_name
	}
	scores[peer_id] = 0
	
	print("✓ Jugador spawneado correctamente: ", player_name, " | Es local: ", player_instance.is_local)

func add_score(peer_id: int):
	if not scores.has(peer_id):
		return
	
	scores[peer_id] += 1
	player_scored.emit(peer_id, scores[peer_id])
	
	print("Puntuación: ", players[peer_id]["name"], " = ", scores[peer_id])
	
	# Verificar si alguien ganó
	if scores[peer_id] >= max_score:
		_end_game(peer_id)

func _end_game(winner_id: int):
	is_game_active = false
	game_ended.emit(winner_id)
	print("¡Juego terminado! Ganador: ", players[winner_id]["name"])

func reset_positions():
	# Resetear posiciones después de un punto
	var peer_ids = players.keys()
	for i in range(peer_ids.size()):
		var peer_id = peer_ids[i]
		var spawn_pos = spawn_positions[i] if i < spawn_positions.size() else Vector2(400 + i * 200, 300)
		players[peer_id]["node"].position = spawn_pos
		players[peer_id]["node"].linear_velocity = Vector2.ZERO
		players[peer_id]["node"].angular_velocity = 0.0
