extends Control

# Referencias a nodos de UI
@onready var player_name_input = $MarginContainer/VBoxContainer/NameContainer/NameInput
@onready var color_picker = $MarginContainer/VBoxContainer/ColorContainer/ColorPicker
@onready var create_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/CreateLobbyButton
@onready var join_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/JoinLobbyButton
@onready var leave_lobby_btn = $MarginContainer/VBoxContainer/ButtonsContainer/LeaveLobbyButton
@onready var start_game_btn = $MarginContainer/VBoxContainer/ButtonsContainer/StartGameButton
@onready var players_list = $MarginContainer/VBoxContainer/PlayersContainer/PlayersList
@onready var lobby_info_label = $MarginContainer/VBoxContainer/LobbyInfo

var player_name: String = "Player"
var player_color: Color = Color.BLUE

func _ready():
	# Configurar valores iniciales
	player_name_input.text = SteamManager.steam_username
	color_picker.color = Color.BLUE
	
	# Conectar señales de botones
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
	
	# Estado inicial
	_update_ui_state(false)

func _on_name_changed(new_name: String):
	player_name = new_name
	if SteamManager.lobby_id != 0:
		SteamManager.set_player_data(player_name, player_color)

func _on_color_changed(new_color: Color):
	player_color = new_color
	if SteamManager.lobby_id != 0:
		SteamManager.set_player_data(player_name, player_color)

func _on_create_lobby_pressed():
	print("Creando lobby...")
	SteamManager.create_lobby(2)

func _on_join_lobby_pressed():
	# Por ahora buscamos lobbies y nos unimos al primero
	# En una implementación real, mostrarías una lista de lobbies
	print("Buscando lobbies...")
	SteamManager.search_lobbies()
	
	# Esperar un momento para que lleguen los resultados
	await get_tree().create_timer(1.0).timeout
	
	# Aquí deberías mostrar una lista de lobbies disponibles
	# Por simplicidad, intentamos buscar lobbies manualmente
	# Esto es temporal - necesitarás implementar una UI para seleccionar lobby

func _on_leave_lobby_pressed():
	SteamManager.leave_lobby()
	_update_ui_state(false)
	_update_players_list()

func _on_start_game_pressed():
	if SteamManager.is_host and SteamManager.lobby_members.size() == 2:
		# Cambiar a la escena del juego
		get_tree().change_scene_to_file("res://game.tscn")

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
	start_game_btn.visible = in_lobby and SteamManager.is_host

func _update_players_list():
	players_list.clear()
	
	if SteamManager.lobby_id == 0:
		players_list.add_item("No estás en un lobby")
		return
	
	var members = SteamManager.get_lobby_members()
	
	for member_id in members:
		var data = SteamManager.get_player_data(member_id)
		var display_name = data.get("name", "Player")
		var color = data.get("color", Color.WHITE)
		
		var is_you = (member_id == SteamManager.steam_id)
		var is_host = (member_id == Steam.getLobbyOwner(SteamManager.lobby_id))
		
		var prefix = ""
		if is_host:
			prefix += "[HOST] "
		if is_you:
			prefix += "[TÚ] "
		
		var item_text = prefix + display_name
		var index = players_list.add_item(item_text)
		players_list.set_item_custom_fg_color(index, color)
	
	# Actualizar botón de iniciar
	if SteamManager.is_host:
		start_game_btn.disabled = (members.size() < 2)
		if members.size() < 2:
			start_game_btn.text = "Esperando jugador..."
		else:
			start_game_btn.text = "¡Iniciar Partida!"
