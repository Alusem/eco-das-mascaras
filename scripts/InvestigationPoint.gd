extends Area2D

@export var clue_path: NodePath
@export var reveal_text: String = "Algo chamou sua atencao."
@export var one_shot := true

@onready var _clue: Node = get_node_or_null(clue_path)


func _ready() -> void:
	input_pickable = true


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_revelar_pista()


func _revelar_pista() -> void:
	if _clue != null and _clue.has_method("reveal"):
		_clue.reveal()
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("exibir_mensagem_sistema"):
		ui.exibir_mensagem_sistema(reveal_text)
	if one_shot:
		queue_free()
