extends Control

# Referencias a nodos de UI
@onready var player_name_input = $MarginContainer/VBoxContainer/NameContainer/NameInput
@onready var color_picker = $MarginContainer/VBoxContainer/ColorContainer/ColorPicker

# Botones de tipo de lobby
@onready var lobby_type_label = $MarginContainer/VBoxContainer/LobbyTypeContainer/Label
@onready var steam_lobby_btn = $MarginContainer/VBoxContainer/LobbyTypeContainer/SteamLobbyButton
@onready var lan_lobby_btn = $MarginContainer/VBoxContainer/LobbyTypeContainer/LANLobbyButton

# Contenedor LAN
@onready var lan_container = $MarginContainer/VBoxContainer/LANContainer
@onready var ip_input = $MarginContainer/VBoxContainer/LANContainer/IPContainer/IPInput
@onready var port_input = $MarginContainer/VBoxContainer/LANContainer/PortContainer/PortInput

# Botones principales
@onready var create_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/CreateLobbyButton
@onready var join_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/JoinLobbyButton
@onready var leave_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/LeaveLobbyButton
@onready var start_game_btn = $MarginContainer/VBoxContainer/ButtonsContainer/StartGameButton
@onready var players_list = $MarginContainer/VBoxContainer/PlayersContainer/PlayersList
@onready var lobby_info_label = $MarginContainer/VBoxContainer/LobbyInfo

var player_name: String = "Player"
var player_color: Color = Color.BLUE
var selected_lobby_type = SteamManager.LobbyType.STEAM
var update_timer: float = 0.0

func _process(delta):
	# Actualizar lista de jugadores periódicamente cuando estamos en lobby LAN
	if selected_lobby_type == SteamManager.LobbyType.LAN and LANManager.peer != null:
		update_timer += delta
		if update_timer >= 1.0:  # Actualizar cada segundo
			update_timer = 0.0
			_update_players_list()

func _ready():
	# Configurar valores iniciales
	player_name_input.text = SteamManager.steam_username
	color_picker.color = Color.BLUE
	ip_input.text = "127.0.0.1"
	port_input.text = "7777"
	
	# Ocultar contenedor LAN por defecto
	lan_container.visible = false
	
	# Conectar señales de botones
	steam_lobby_btn.pressed.connect(_on_steam_lobby_selected)
	lan_lobby_btn.pressed.connect(_on_lan_lobby_selected)
	create_lobby_btn.pressed.connect(_on_create_lobby_pressed)
	join_lobby_btn.pressed.connect(_on_join_lobby_pressed)
	leave_lobby_btn.pressed.connect(_on_leave_lobby_pressed)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	
	player_name_input.text_changed.connect(_on_name_changed)
	color_picker.color_changed.connect(_on_color_changed)
	
	# Conectar señales de SteamManager
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)
	SteamManager.player_joined.connect(_on_player_joined)
	SteamManager.player_left.connect(_on_player_left)
	SteamManager.lobby_data_updated.connect(_on_lobby_data_updated)
	
	# Conectar señales de LANManager
	LANManager.lan_server_created.connect(_on_lan_server_created)
	LANManager.lan_client_connected.connect(_on_lan_client_connected)
	LANManager.lan_connection_failed.connect(_on_lan_connection_failed)
	LANManager.lan_player_connected.connect(_on_lan_player_connected)
	LANManager.lan_player_disconnected.connect(_on_lan_player_disconnected)
	
	# Estado inicial
	_update_ui_state(false)

func _on_name_changed(new_name: String):
	player_name = new_name if new_name != "" else "Player"
	if selected_lobby_type == SteamManager.LobbyType.STEAM and SteamManager.lobby_id != 0:
		SteamManager.set_player_data(player_name, player_color)
	elif selected_lobby_type == SteamManager.LobbyType.LAN and LANManager.peer != null:
		LANManager.set_local_player_data(player_name, player_color)

func _on_color_changed(new_color: Color):
	player_color = new_color
	if selected_lobby_type == SteamManager.LobbyType.STEAM and SteamManager.lobby_id != 0:
		SteamManager.set_player_data(player_name, player_color)
	elif selected_lobby_type == SteamManager.LobbyType.LAN and LANManager.peer != null:
		LANManager.set_local_player_data(player_name, player_color)

func _on_steam_lobby_selected():
	selected_lobby_type = SteamManager.LobbyType.STEAM
	lan_container.visible = false
	join_lobby_btn.text = "Buscar Lobby"
	steam_lobby_btn.disabled = true
	lan_lobby_btn.disabled = false

func _on_lan_lobby_selected():
	selected_lobby_type = SteamManager.LobbyType.LAN
	SteamManager.current_lobby_type = SteamManager.LobbyType.LAN  # Importante!
	lan_container.visible = true
	join_lobby_btn.text = "Unirse a IP"
	steam_lobby_btn.disabled = false
	lan_lobby_btn.disabled = true

func _on_create_lobby_pressed():
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		print("Creando lobby Steam...")
		SteamManager.create_lobby(2, SteamManager.LobbyType.STEAM)
	else:
		print("=== DEBUG: Creando servidor LAN ===")
		print("LANManager existe: ", LANManager != null)
		var port = int(port_input.text)
		print("Puerto: ", port)
		
		# Asegurarse de que el nombre no esté vacío
		var final_name = player_name if player_name != "" else "Player"
		print("Nombre final: ", final_name)
		print("Color final: ", player_color)
		
		LANManager.set_local_player_data(final_name, player_color)
		SteamManager.current_lobby_type = SteamManager.LobbyType.LAN  # Importante!
		print("Datos del jugador establecidos: ", final_name, " - ", player_color)
		var result = LANManager.create_server(port)
		print("Resultado de create_server: ", result)
		if not result:
			lobby_info_label.text = "ERROR: No se pudo crear el servidor LAN"

func _on_join_lobby_pressed():
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		# Por ahora buscamos lobbies y nos unimos al primero
		print("Buscando lobbies Steam...")
		SteamManager.search_lobbies()
		await get_tree().create_timer(1.0).timeout
	else:
		# Unirse a servidor LAN
		print("Conectando a servidor LAN...")
		var ip = ip_input.text
		var port = int(port_input.text)
		
		# Asegurarse de que el nombre no esté vacío
		var final_name = player_name if player_name != "" else "Player"
		print("Nombre final: ", final_name)
		print("Color final: ", player_color)
		
		LANManager.set_local_player_data(final_name, player_color)
		SteamManager.current_lobby_type = SteamManager.LobbyType.LAN  # Importante!
		LANManager.join_server(ip, port)

func _on_leave_lobby_pressed():
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		SteamManager.leave_lobby()
	else:
		LANManager.disconnect_from_lobby()
	
	_update_ui_state(false)
	_update_players_list()

func _on_start_game_pressed():
	var can_start = false
	
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		can_start = SteamManager.is_host and SteamManager.lobby_members.size() == 2
	else:
		can_start = LANManager.is_server and LANManager.get_connected_peers().size() == 2
	
	if can_start:
		print("=== HOST INICIANDO PARTIDA ===")
		
		# El host envía señal a todos para cambiar de escena (solo LAN)
		if selected_lobby_type == SteamManager.LobbyType.LAN:
			# Enviar RPC a todos los clientes
			rpc("_change_to_game_scene")
		
		# El host también cambia de escena (esto va después del RPC)
		_change_to_game_scene()

# RPC para cambiar de escena
@rpc("any_peer", "call_local", "reliable")
func _change_to_game_scene():
	print("=== CAMBIANDO A ESCENA DE JUEGO ===")
	
	# Verificar que todavía estamos en el árbol de escena
	if not is_inside_tree():
		print("ERROR: El nodo ya no está en el árbol de escena")
		return
	
	# Cambiar a la escena del juego
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_lobby_created(lobby_id: int):
	print("UI: Lobby creado con ID: ", lobby_id)
	lobby_info_label.text = "Lobby ID: %d\nEsperando jugador..." % lobby_id
	_update_ui_state(true)
	
	# Establecer datos del jugador
	SteamManager.set_player_data(player_name, player_color)
	_update_players_list()

func _on_lobby_joined(lobby_id: int):
	print("UI: Unido al lobby: ", lobby_id)
	lobby_info_label.text = "Lobby ID: %d" % lobby_id
	_update_ui_state(true)
	
	# Establecer datos del jugador
	SteamManager.set_player_data(player_name, player_color)
	_update_players_list()

func _on_lobby_join_failed():
	lobby_info_label.text = "Error al unirse al lobby"

# Callbacks de LAN

func _on_lan_server_created(port: int):
	print("UI: Servidor LAN creado en puerto: ", port)
	lobby_info_label.text = "Servidor LAN - Puerto: %d\nTu IP Local: %s\nEsperando jugador..." % [port, _get_local_ip()]
	_update_ui_state(true)
	await get_tree().create_timer(0.1).timeout  # Pequeño delay antes de actualizar lista
	_update_players_list()

func _on_lan_client_connected():
	print("UI: Conectado al servidor LAN")
	lobby_info_label.text = "Conectado al servidor LAN"
	_update_ui_state(true)
	await get_tree().create_timer(0.3).timeout  # Esperar a que se sincronicen los datos
	_update_players_list()

func _on_lan_connection_failed():
	lobby_info_label.text = "Error al conectar al servidor LAN"

func _on_lan_player_connected(peer_id: int):
	print("UI: Jugador LAN conectado: ", peer_id)
	await get_tree().create_timer(0.3).timeout  # Esperar a que lleguen los datos
	_update_players_list()

func _on_lan_player_disconnected(peer_id: int):
	print("UI: Jugador LAN desconectado: ", peer_id)
	_update_players_list()

# Función auxiliar para obtener IP local
func _get_local_ip() -> String:
	var ip_list = IP.get_local_addresses()
	for ip in ip_list:
		# Filtrar IPs que no sean localhost ni IPv6
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

func _on_player_joined(steam_id: int, player_name_joined: String):
	print("UI: Jugador unido: ", player_name_joined)
	_update_players_list()

func _on_player_left(steam_id: int):
	print("UI: Jugador salió")
	_update_players_list()

func _on_lobby_data_updated():
	_update_players_list()

func _update_ui_state(in_lobby: bool):
	create_lobby_btn.visible = not in_lobby
	join_lobby_btn.visible = not in_lobby
	leave_lobby_btn.visible = in_lobby
	
	# Botones de tipo de lobby solo visibles cuando no estás en lobby
	steam_lobby_btn.visible = not in_lobby
	lan_lobby_btn.visible = not in_lobby
	lobby_type_label.visible = not in_lobby
	
	# Contenedor LAN solo visible si está seleccionado y no estás en lobby
	if not in_lobby:
		lan_container.visible = (selected_lobby_type == SteamManager.LobbyType.LAN)
	
	# Botón de start
	var is_host_any = false
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		is_host_any = SteamManager.is_host
	else:
		is_host_any = LANManager.is_server
	
	start_game_btn.visible = in_lobby and is_host_any

func _update_players_list():
	players_list.clear()
	
	var in_lobby = false
	var members = []
	var host_id = 0
	
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		in_lobby = (SteamManager.lobby_id != 0)
		if in_lobby:
			members = SteamManager.get_lobby_members()
			host_id = Steam.getLobbyOwner(SteamManager.lobby_id)
	else:
		in_lobby = (LANManager.peer != null and LANManager.peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED)
		if in_lobby:
			members = LANManager.get_connected_peers()
			if LANManager.is_server:
				host_id = multiplayer.get_unique_id()
			else:
				host_id = 1  # El servidor siempre es peer 1
	
	if not in_lobby:
		players_list.add_item("No estás en un lobby")
		return
	
	for member_id in members:
		var data: Dictionary
		var is_you = false
		
		if selected_lobby_type == SteamManager.LobbyType.STEAM:
			data = SteamManager.get_player_data(member_id)
			is_you = (member_id == SteamManager.steam_id)
		else:
			data = LANManager.get_player_data(member_id)
			is_you = (member_id == multiplayer.get_unique_id())
		
		var display_name = data.get("name", "Player")
		var color = data.get("color", Color.WHITE)
		
		var is_host = (member_id == host_id)
		
		var prefix = ""
		if is_host:
			prefix += "[HOST] "
		if is_you:
			prefix += "[TÚ] "
		
		var item_text = prefix + display_name
		var index = players_list.add_item(item_text)
		players_list.set_item_custom_fg_color(index, color)
	
	# Actualizar botón de iniciar
	var is_host_any = false
	if selected_lobby_type == SteamManager.LobbyType.STEAM:
		is_host_any = SteamManager.is_host
	else:
		is_host_any = LANManager.is_server
	
	if is_host_any:
		start_game_btn.disabled = (members.size() < 2)
		if members.size() < 2:
			start_game_btn.text = "Esperando jugador..."
		else:
			start_game_btn.text = "¡Iniciar Partida!"
