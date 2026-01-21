extends Node

# Autoload singleton para gestionar Steam

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_join_failed()
signal player_joined(steam_id, player_name)
signal player_left(steam_id)
signal lobby_data_updated()

var steam_id: int = 0
var steam_username: String = ""
var lobby_id: int = 0
var lobby_members: Array = []
var is_host: bool = false

# Datos de jugadores en el lobby
var players_data: Dictionary = {} # {steam_id: {name: "", color: Color}}

func _ready():
	# Inicializar Steam
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Steam init: ", initialize_response)
	
	if initialize_response['status'] > 0:
		print("ERROR: No se pudo inicializar Steam")
		return
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	print("Steam ID: ", steam_id)
	print("Username: ", steam_username)
	
	# Conectar señales de Steam
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_data_update.connect(_on_lobby_data_update)

func _process(_delta):
	Steam.run_callbacks()

# Crear lobby
func create_lobby(max_players: int = 2):
	print("Creando lobby...")
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)

# Buscar lobbies disponibles
func search_lobbies():
	print("Buscando lobbies...")
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	
#
func open_steam_ui():
	print("Conectando Steam UI")
	Steam.activateGameOverlay()

# Unirse a un lobby
func join_lobby(target_lobby_id: int):
	print("Uniéndose al lobby: ", target_lobby_id)
	Steam.joinLobby(target_lobby_id)

# Abandonar lobby actual
func leave_lobby():
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
		lobby_members.clear()
		players_data.clear()
		is_host = false

# Establecer datos del jugador (nombre y color)
func set_player_data(player_name: String, color: Color):
	if lobby_id == 0:
		return
	
	var color_string = "%s,%s,%s" % [color.r, color.g, color.b]
	var data_string = "%s|%s" % [player_name, color_string]
	
	Steam.setLobbyMemberData(lobby_id, "player_data", data_string)
	
	# Actualizar localmente
	players_data[steam_id] = {
		"name": player_name,
		"color": color
	}

# Obtener datos de un jugador
func get_player_data(player_steam_id: int) -> Dictionary:
	if players_data.has(player_steam_id):
		return players_data[player_steam_id]
	return {"name": "Player", "color": Color.WHITE}

# Obtener todos los miembros del lobby
func get_lobby_members() -> Array:
	lobby_members.clear()
	var num_members = Steam.getNumLobbyMembers(lobby_id)
	
	for i in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(lobby_id, i)
		lobby_members.append(member_id)
		
		# Obtener datos del miembro
		var member_data = Steam.getLobbyMemberData(lobby_id, member_id, "player_data")
		if member_data != "":
			var parts = member_data.split("|")
			if parts.size() >= 2:
				var player_name = parts[0]
				var color_parts = parts[1].split(",")
				var color = Color(
					float(color_parts[0]),
					float(color_parts[1]),
					float(color_parts[2])
				)
				players_data[member_id] = {
					"name": player_name,
					"color": color
				}
	
	return lobby_members

# Callbacks de Steam

func _on_lobby_created(connect_result: int, created_lobby_id: int):
	if connect_result == 1:
		lobby_id = created_lobby_id
		is_host = true
		print("Lobby creado exitosamente: ", lobby_id)
		
		# Establecer nombre del lobby
		Steam.setLobbyData(lobby_id, "name", "Partida de " + steam_username)
		
		lobby_created.emit(lobby_id)
	else:
		print("ERROR: Fallo al crear lobby")

func _on_lobby_match_list(lobbies: Array):
	print("Lobbies encontrados: ", lobbies.size())
	for lobby in lobbies:
		print("  Lobby ID: ", lobby)

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response == 1:
		lobby_id = joined_lobby_id
		print("Unido al lobby: ", lobby_id)
		
		# Verificar si somos el host
		var owner_id = Steam.getLobbyOwner(lobby_id)
		is_host = (owner_id == steam_id)
		
		get_lobby_members()
		lobby_joined.emit(lobby_id)
	else:
		print("ERROR: Fallo al unirse al lobby. Código: ", response)
		lobby_join_failed.emit()

func _on_lobby_chat_update(changed_lobby_id: int, changed_id: int, making_change_id: int, chat_state: int):
	if changed_lobby_id != lobby_id:
		return
	
	var player_name = Steam.getFriendPersonaName(changed_id)
	
	match chat_state:
		Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
			print("Jugador entró: ", player_name)
			get_lobby_members()
			player_joined.emit(changed_id, player_name)
		
		Steam.CHAT_MEMBER_STATE_CHANGE_LEFT, Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
			print("Jugador salió: ", player_name)
			if players_data.has(changed_id):
				players_data.erase(changed_id)
			get_lobby_members()
			player_left.emit(changed_id)

func _on_lobby_data_update(success: int, updated_lobby_id: int, member_id: int):
	if updated_lobby_id == lobby_id:
		get_lobby_members()
		lobby_data_updated.emit()
