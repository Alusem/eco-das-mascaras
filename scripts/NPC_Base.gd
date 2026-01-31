extends StaticBody2D

enum GamePhase { FASE_1, FASE_2 }

@export var npc_id := 0
@export var id_mascara := 0
@export var original_personality := ""
@export var speaker_name := ""
@export var portrait: Texture2D
@export var mascara_inicial := ""
@export var local_fase_1 := ""
@export var original_location := ""
@export var current_location := ""
@export var dialogo_inicial := ""
@export var falas_fase1: PackedStringArray = PackedStringArray()
@export var is_killer := false
@export var alibi_falso := ""
@export var alibi_inocente := ""
@export var falas_fase2_inocente: PackedStringArray = PackedStringArray()
@export var falas_fase2_killer: PackedStringArray = PackedStringArray()
@export var is_vitima := false
@export var sprite_color: Color = Color(1, 1, 1)
@export var idle_move_range := 12.0
@export var idle_move_speed := 20.0
@export var idle_pause_time := 0.8

var mascara_atual := ""
var fase_atual: GamePhase = GamePhase.FASE_1
@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
var _home_pos := Vector2.ZERO
var _idle_dir := 1.0
var _idle_pause_timer := 0.0
var _idle_state := 0


func _ready() -> void:
	add_to_group("npcs")
	if id_mascara == 0:
		id_mascara = npc_id
	if original_personality == "":
		original_personality = _derivar_personalidade(mascara_inicial)
	if speaker_name == "":
		speaker_name = original_personality
	if portrait == null:
		var default_path := "res://icon.svg"
		if ResourceLoader.exists(default_path):
			portrait = load(default_path)
	if original_location == "":
		original_location = local_fase_1
	if current_location == "":
		current_location = original_location
	mascara_atual = mascara_inicial
	if _sprite != null:
		_sprite.modulate = sprite_color
	if is_vitima:
		definir_vitima()
	set_home_pos()


func _process(delta: float) -> void:
	if is_vitima:
		return
	if idle_move_range <= 0.0 or idle_move_speed <= 0.0:
		return
	if _idle_state == 1:
		_idle_pause_timer -= delta
		if _idle_pause_timer <= 0.0:
			_idle_state = 0
			_idle_dir *= -1.0
		return
	var target := _home_pos + Vector2(idle_move_range * _idle_dir, 0.0)
	global_position = global_position.move_toward(target, idle_move_speed * delta)
	if global_position.distance_to(target) <= 0.5:
		_idle_state = 1
		_idle_pause_timer = idle_pause_time


func interact() -> Variant:
	if is_vitima:
		return ""
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("on_npc_interacted"):
		return gm.on_npc_interacted(self)
	return get_dialogo_inicial()


func mudar_fase(mascara_da_vitima: String = "") -> void:
	fase_atual = GamePhase.FASE_2
	if is_killer and mascara_da_vitima != "":
		mascara_atual = mascara_da_vitima


func definir_vitima() -> void:
	is_vitima = true
	if _sprite != null:
		_sprite.visible = false
	if _collision_shape != null:
		_collision_shape.disabled = true


func get_mascara_atual() -> String:
	return mascara_atual


func get_display_name() -> String:
	if mascara_atual != "":
		return mascara_atual
	return name


func get_speaker_name() -> String:
	if speaker_name != "":
		return speaker_name
	if original_personality != "":
		return original_personality
	if mascara_atual != "":
		return mascara_atual
	return name


func get_portrait() -> Texture2D:
	return portrait


func resetar_para_ciclo() -> void:
	is_vitima = false
	is_killer = false
	fase_atual = GamePhase.FASE_1
	mascara_atual = mascara_inicial
	current_location = original_location
	if _sprite != null:
		_sprite.visible = true
	if _collision_shape != null:
		_collision_shape.disabled = false
	set_home_pos()


func set_killer(ativo: bool) -> void:
	is_killer = ativo


func aplicar_mascara(nova_mascara: String) -> void:
	if nova_mascara != "":
		mascara_atual = nova_mascara


func set_current_location(novo_local: String) -> void:
	if novo_local != "":
		current_location = novo_local


func set_home_pos() -> void:
	_home_pos = global_position


func _derivar_personalidade(mascara: String) -> String:
	if mascara.begins_with("MASCARA DE "):
		return mascara.replace("MASCARA DE ", "").capitalize()
	return mascara.capitalize()


func get_dialogo_inicial() -> String:
	if falas_fase1.size() > 0:
		return _fala_aleatoria(falas_fase1)
	if dialogo_inicial != "":
		return dialogo_inicial
	return "Eu sou %s, estava no %s" % [mascara_atual, local_fase_1]


func get_dialogo_investigacao() -> String:
	if is_killer:
		if falas_fase2_killer.size() > 0:
			return _fala_aleatoria(falas_fase2_killer)
		if alibi_falso != "":
			return alibi_falso
	if falas_fase2_inocente.size() > 0:
		return _fala_aleatoria(falas_fase2_inocente)
	if alibi_inocente != "":
		return alibi_inocente
	return "Eu sou %s, estava no %s" % [mascara_atual, local_fase_1]


func _fala_aleatoria(lista: PackedStringArray) -> String:
	if lista.size() == 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return lista[rng.randi_range(0, lista.size() - 1)]


func get_fala_panico(is_killer_flag: bool) -> String:
	if is_killer_flag:
		return _fala_aleatoria(falas_fase2_killer)
	return _fala_aleatoria(falas_fase2_inocente)
