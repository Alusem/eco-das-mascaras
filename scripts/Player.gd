extends CharacterBody2D

signal pista_coletada(dados_pista)
signal npc_interagido(npc)

enum GamePhase { FASE_1, FASE_2 }

@export var speed := 200.0
@export var interact_range := 72.0
@export var sprite_color: Color = Color(1, 1, 1)
@export var footstep_volume_db := -12.0
@export var footstep_pitch := 1.15
var game_phase: GamePhase = GamePhase.FASE_1

@onready var interaction_area: Area2D = $InteractionArea
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _footstep: AudioStreamPlayer = get_node_or_null("FootstepPlayer")


func _ready() -> void:
	add_to_group("player")
	if _sprite != null:
		_sprite.modulate = sprite_color
	if _footstep != null:
		_footstep.volume_db = footstep_volume_db
		_footstep.pitch_scale = footstep_pitch


func _physics_process(_delta: float) -> void:
	var input_vector := _get_input_vector()
	velocity = input_vector * speed
	move_and_slide()
	_update_footsteps(input_vector)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _get_input_vector() -> Vector2:
	var raw := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if abs(raw.x) > abs(raw.y):
		return Vector2(sign(raw.x), 0)
	if abs(raw.y) > 0.0:
		return Vector2(0, sign(raw.y))
	return Vector2.ZERO


func _try_interact() -> void:
	if interaction_area == null:
		return

	var ui := get_tree().get_first_node_in_group("game_ui")
	var suprimir_dialogo := false
	if ui != null and ui.has_method("should_suppress_dialog_on_interact"):
		suprimir_dialogo = ui.should_suppress_dialog_on_interact()
	var target := _pick_interactable_target()
	if target == null:
		return
	if suprimir_dialogo:
		if target.is_in_group("npcs"):
			emit_signal("npc_interagido", target)
		return
	var mensagem: Variant = target.interact()
	var texto := _extrair_texto(mensagem)
	emit_signal("npc_interagido", target)
	if texto != "":
		emit_signal("pista_coletada", mensagem)
		print(texto)


func _pick_interactable_target() -> Node:
	var nearest: Node = null
	var nearest_dist := interact_range
	var player_pos := global_position
	var candidates: Array = []
	candidates.append_array(interaction_area.get_overlapping_bodies())
	candidates.append_array(interaction_area.get_overlapping_areas())
	if candidates.is_empty():
		candidates.append_array(get_tree().get_nodes_in_group("npcs"))
		candidates.append_array(get_tree().get_nodes_in_group("clues"))
	for node in candidates:
		if node == null or node == self:
			continue
		if node is CanvasItem and not node.visible:
			continue
		if node is Area2D and not node.monitoring:
			continue
		if not node.has_method("interact"):
			continue
		if not (node is Node2D):
			continue
		var dist := player_pos.distance_to(node.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = node
	return nearest


func _extrair_texto(dado: Variant) -> String:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("texto"):
		return String(dado["texto"])
	return String(dado)


func _update_footsteps(input_vector: Vector2) -> void:
	if _footstep == null:
		return
	if input_vector == Vector2.ZERO:
		if _footstep.playing:
			_footstep.stop()
		return
	if not _footstep.playing:
		_footstep.play()
