extends Area2D

@export var descricao_pista: String = ""
@export var mask_hint: String = ""
@export var local_hint: String = ""
@export var sprite_path: NodePath
@export var starts_hidden := true

@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)
var _coletado := false


func _ready() -> void:
	add_to_group("clues")
	if starts_hidden:
		visible = false
		monitoring = false
		monitorable = false


func interact() -> Variant:
	if not _coletado:
		_coletado = true
		if _sprite != null:
			_sprite.modulate = Color(0.6, 0.6, 0.6, 1)
	return get_evidence_data()


func reveal() -> void:
	visible = true
	monitoring = true
	monitorable = true


func get_evidence_data() -> Dictionary:
	return {
		"texto": descricao_pista,
		"mask_hint": mask_hint,
		"local_hint": local_hint,
		"tipo": "pista"
	}
