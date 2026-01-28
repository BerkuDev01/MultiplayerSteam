extends Node

# Autoload para gestionar conexiones LAN usando ENetMultiplayerPeer

signal lan_server_created(port)
signal lan_client_connected()
signal lan_connection_failed()
signal lan_player_connected(peer_id)
signal lan_player_disconnected(peer_id)

const DEFAULT_PORT = 7777
const MAX_PLAYERS = 2

var peer: ENetMultiplayerPeer = null
var is_server: bool = false
var connected_peers: Dictionary = {} # {peer_id: {name: "", color: Color}}
var local_player_data: Dictionary = {"name": "Player", "color": Color.BLUE}

func _ready():
	# Conectar señales del multiplayer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Crear servidor LAN
func create_server(port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS - 1)
	
	if error != OK:
		print("Error al crear servidor LAN: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	
	print("Servidor LAN creado en puerto: ", port)
	print("Tu ID de peer: ", multiplayer.get_unique_id())
	
	# Añadir al servidor como jugador
	var server_id = multiplayer.get_unique_id()
	connected_peers[server_id] = local_player_data.duplicate()
	
	lan_server_created.emit(port)
	return true

# Conectar a servidor LAN
func join_server(ip: String, port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)
	
	if error != OK:
		print("Error al conectar a servidor LAN: ", error)
		lan_connection_failed.emit()
		return false
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	
	print("Intentando conectar a: ", ip, ":", port)
	return true

# Desconectar del servidor/lobby
func disconnect_from_lobby():
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	is_server = false
	connected_peers.clear()
	print("Desconectado del lobby LAN")

# Establecer datos del jugador local
func set_local_player_data(player_name: String, color: Color):
	local_player_data = {
		"name": player_name,
		"color": color
	}
	
	# Si ya estamos conectados, actualizar en red
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		var my_id = multiplayer.get_unique_id()
		connected_peers[my_id] = local_player_data.duplicate()
		
		# Enviar actualización a todos
		rpc("_update_player_data", my_id, player_name, color)

# Obtener datos de un jugador por peer_id
func get_player_data(peer_id: int) -> Dictionary:
	if connected_peers.has(peer_id):
		return connected_peers[peer_id]
	return {"name": "Player", "color": Color.WHITE}

# Obtener lista de todos los peers conectados
func get_connected_peers() -> Array:
	return connected_peers.keys()

# RPC para sincronizar datos de jugadores
@rpc("any_peer", "call_local", "reliable")
func _update_player_data(peer_id: int, player_name: String, color: Color):
	connected_peers[peer_id] = {
		"name": player_name,
		"color": color
	}
	print("Datos de jugador actualizados: ", player_name, " (ID: ", peer_id, ")")

# RPC para que el cliente envíe sus datos al servidor cuando se conecta
@rpc("any_peer", "reliable")
func _send_player_data_to_server(player_name: String, color: Color):
	var sender_id = multiplayer.get_remote_sender_id()
	connected_peers[sender_id] = {
		"name": player_name,
		"color": color
	}
	print("Cliente enviado datos: ", player_name, " (ID: ", sender_id, ")")
	print("Connected peers en servidor: ", connected_peers)
	
	# Servidor envía todos los datos de jugadores al nuevo cliente
	if is_server:
		await get_tree().create_timer(0.1).timeout
		print("Servidor enviando todos los datos al cliente ", sender_id)
		rpc_id(sender_id, "_receive_all_players_data", connected_peers)
		
		# También notificar a otros clientes
		lan_player_connected.emit(sender_id)

# RPC para que el servidor envíe todos los datos al cliente
@rpc("authority", "call_local", "reliable")
func _receive_all_players_data(all_players: Dictionary):
	connected_peers = all_players.duplicate(true)
	print("Recibidos datos de todos los jugadores: ", all_players)
	print("Connected peers actualizado: ", connected_peers)
	
	# Emitir señal para que la UI se actualice
	await get_tree().create_timer(0.1).timeout
	lan_player_connected.emit(multiplayer.get_unique_id())

# Callbacks de Multiplayer

func _on_peer_connected(id: int):
	print("Peer conectado: ", id)
	
	if is_server:
		# El servidor registra al nuevo peer temporalmente
		print("Servidor: Registrando nuevo peer temporalmente")
		lan_player_connected.emit(id)
	else:
		# El cliente envía sus datos al servidor inmediatamente
		print("Cliente: Enviando datos al servidor")
		await get_tree().create_timer(0.1).timeout  # Pequeño delay para asegurar conexión
		rpc_id(1, "_send_player_data_to_server", local_player_data["name"], local_player_data["color"])

func _on_peer_disconnected(id: int):
	print("Peer desconectado: ", id)
	if connected_peers.has(id):
		connected_peers.erase(id)
	lan_player_disconnected.emit(id)

func _on_connected_to_server():
	print("Conectado al servidor LAN exitosamente!")
	var my_id = multiplayer.get_unique_id()
	connected_peers[my_id] = local_player_data.duplicate()
	lan_client_connected.emit()
	
	# Enviar datos al servidor con un pequeño delay
	await get_tree().create_timer(0.2).timeout
	print("Enviando datos del jugador al servidor...")
	rpc_id(1, "_send_player_data_to_server", local_player_data["name"], local_player_data["color"])

func _on_connection_failed():
	print("Fallo al conectar al servidor LAN")
	lan_connection_failed.emit()

func _on_server_disconnected():
	print("Servidor LAN desconectado")
	disconnect_from_lobby()
