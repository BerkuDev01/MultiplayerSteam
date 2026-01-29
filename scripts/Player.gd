extends RigidBody2D

# Información del jugador
var peer_id: int = 0
var player_name: String = "Player"
var player_color: Color = Color.WHITE
var is_local: bool = false

# Referencias a nodos
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var name_label = $NameLabel

# Movimiento tipo tanque
var move_speed: float = 300.0
var rotation_speed: float = 3.0

func _ready():
	# Configurar color del jugador
	sprite.modulate = player_color
	name_label.text = player_name
	
	print("Player _ready: ", player_name, " | Local: ", is_local, " | Peer ID: ", peer_id)
	
	# Configurar física
	if not is_local:
		# Los jugadores remotos no se controlan localmente
		# Su movimiento será sincronizado por red
		pass

func _physics_process(delta):
	if not is_local:
		return
	
	# Control tipo tanque solo para el jugador local
	var input_vector = Vector2.ZERO
	
	# Rotación
	if Input.is_action_pressed("ui_left"):
		apply_torque_impulse(-rotation_speed * 1000 * delta)
	if Input.is_action_pressed("ui_right"):
		apply_torque_impulse(rotation_speed * 1000 * delta)
	
	# Movimiento adelante/atrás
	if Input.is_action_pressed("ui_up"):
		input_vector.y = -1
	if Input.is_action_pressed("ui_down"):
		input_vector.y = 1
	
	# Aplicar fuerza en la dirección de rotación
	if input_vector != Vector2.ZERO:
		var direction = transform.y * input_vector.y
		apply_central_force(direction * move_speed)
