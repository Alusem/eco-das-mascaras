extends Control

signal acusacao_confirmada(npc)
signal acusacao_cancelada()

@export var dialog_panel_path: NodePath
@export var dialog_label_path: NodePath
@export var dialog_name_label_path: NodePath
@export var dialog_name_plate_path: NodePath
@export var dialog_portrait_path: NodePath
@export var caderno_panel_path: NodePath
@export var caderno_label_path: NodePath
@export var acusar_button_path: NodePath
@export var confirm_panel_path: NodePath
@export var confirm_label_path: NodePath
@export var confirm_yes_button_path: NodePath
@export var confirm_no_button_path: NodePath
@export var result_panel_path: NodePath
@export var result_label_path: NodePath
@export var result_button_path: NodePath
@export var blackout_rect_path: NodePath
@export var blackout_label_path: NodePath
@export var clock_label_path: NodePath
@export var heartbeat_player_path: NodePath
@export var vignette_rect_path: NodePath

@onready var dialog_panel: Control = _get_node_or_null(dialog_panel_path)
@onready var dialog_label: RichTextLabel = _get_node_or_null(dialog_label_path)
@onready var dialog_name_label: Label = _get_node_or_null(dialog_name_label_path)
@onready var dialog_name_plate: Control = _get_node_or_null(dialog_name_plate_path)
@onready var dialog_portrait: TextureRect = _get_node_or_null(dialog_portrait_path)
@onready var caderno_panel: Control = _get_node_or_null(caderno_panel_path)
@onready var caderno_label: RichTextLabel = _get_node_or_null(caderno_label_path)
@onready var acusar_button: Button = _get_node_or_null(acusar_button_path)
@onready var confirm_panel: Control = _get_node_or_null(confirm_panel_path)
@onready var confirm_label: Label = _get_node_or_null(confirm_label_path)
@onready var confirm_yes_button: Button = _get_node_or_null(confirm_yes_button_path)
@onready var confirm_no_button: Button = _get_node_or_null(confirm_no_button_path)
@onready var result_panel: Control = _get_node_or_null(result_panel_path)
@onready var result_label: Label = _get_node_or_null(result_label_path)
@onready var result_button: Button = _get_node_or_null(result_button_path)
@onready var blackout_rect: ColorRect = _get_node_or_null(blackout_rect_path)
@onready var blackout_label: Label = _get_node_or_null(blackout_label_path)
@onready var clock_label: Label = _get_node_or_null(clock_label_path)
@onready var heartbeat_player: AudioStreamPlayer = _get_node_or_null(heartbeat_player_path)
@onready var vignette_rect: ColorRect = _get_node_or_null(vignette_rect_path)

var dialog_timer: Timer
var evidencias: Array[Dictionary] = []
var evidencias_set: Dictionary = {}
var contradicoes: Dictionary = {}
var evidencia_selecionada_idx := -1
var acusacao_ativa := false
var _confirmacao_aberta := false
var _resultado_aberto := false
var _npc_pendente: Node = null
var _clock_accum := 0.0
var _pulse_time := 0.0
var _caderno_cursor_idx := -1


func _ready() -> void:
	add_to_group("game_ui")
	if dialog_panel == null:
		push_warning("GameUI: dialog_panel_path nao aponta para um Control valido.")
	if dialog_label == null:
		push_warning("GameUI: dialog_label_path nao aponta para um RichTextLabel valido.")
	if dialog_name_label == null:
		push_warning("GameUI: dialog_name_label_path nao aponta para um Label valido.")
	if dialog_name_plate == null:
		push_warning("GameUI: dialog_name_plate_path nao aponta para um Control valido.")
	if dialog_portrait == null:
		push_warning("GameUI: dialog_portrait_path nao aponta para um TextureRect valido.")
	if dialog_panel != null:
		dialog_panel.visible = false
	if caderno_panel == null:
		push_warning("GameUI: caderno_panel_path nao aponta para um Control valido.")
	if caderno_label == null:
		push_warning("GameUI: caderno_label_path nao aponta para um RichTextLabel valido.")
	if caderno_panel != null:
		caderno_panel.visible = false
	if caderno_label != null:
		caderno_label.bbcode_enabled = true
		caderno_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_atualizar_caderno()
	if acusar_button == null:
		push_warning("GameUI: acusar_button_path nao aponta para um Button valido.")
	if acusar_button != null:
		acusar_button.visible = false
		acusar_button.pressed.connect(_on_acusar_pressed)
	if confirm_panel == null:
		push_warning("GameUI: confirm_panel_path nao aponta para um Control valido.")
	if confirm_label == null:
		push_warning("GameUI: confirm_label_path nao aponta para um Label valido.")
	if confirm_yes_button == null or confirm_no_button == null:
		push_warning("GameUI: confirm buttons nao apontam para um Button valido.")
	if confirm_panel != null:
		confirm_panel.visible = false
	if confirm_label != null:
		confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if confirm_yes_button != null:
		confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)
	if confirm_no_button != null:
		confirm_no_button.pressed.connect(_on_confirm_no_pressed)
	if result_panel == null:
		push_warning("GameUI: result_panel_path nao aponta para um Control valido.")
	if result_label == null:
		push_warning("GameUI: result_label_path nao aponta para um Label valido.")
	if result_button == null:
		push_warning("GameUI: result_button_path nao aponta para um Button valido.")
	if result_panel != null:
		result_panel.visible = false
	if result_label != null:
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if result_button != null:
		result_button.pressed.connect(_on_result_restart_pressed)
	if blackout_rect == null:
		push_warning("GameUI: blackout_rect_path nao aponta para um ColorRect valido.")
	if blackout_rect != null:
		blackout_rect.visible = false
		blackout_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blackout_label == null:
		push_warning("GameUI: blackout_label_path nao aponta para um Label valido.")
	if blackout_label != null:
		blackout_label.visible = false
		blackout_label.text = ""
	if clock_label == null:
		push_warning("GameUI: clock_label_path nao aponta para um Label valido.")
	if heartbeat_player == null:
		push_warning("GameUI: heartbeat_player_path nao aponta para um AudioStreamPlayer valido.")
	if vignette_rect == null:
		push_warning("GameUI: vignette_rect_path nao aponta para um ColorRect valido.")
	if vignette_rect != null:
		vignette_rect.visible = true

	dialog_timer = Timer.new()
	dialog_timer.one_shot = true
	dialog_timer.wait_time = 3.0
	dialog_timer.timeout.connect(_on_dialog_timer_timeout)
	add_child(dialog_timer)

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("pista_coletada"):
		player.connect("pista_coletada", Callable(self, "exibir_dialogo"))


func _input(_event: InputEvent) -> void:
	if is_modal_open():
		return
	if caderno_panel != null and caderno_panel.visible:
		if Input.is_action_just_pressed("ui_cancel"):
			caderno_panel.visible = false
			return
		if Input.is_action_just_pressed("ui_up"):
			_move_caderno_cursor(-1)
			return
		if Input.is_action_just_pressed("ui_down"):
			_move_caderno_cursor(1)
			return
		if Input.is_action_just_pressed("interact"):
			_toggle_select_caderno()
			return
	if dialog_panel != null and dialog_panel.visible and Input.is_action_just_pressed("interact"):
		_ocultar_dialogo()
	if caderno_panel != null and Input.is_action_just_pressed("ui_cancel"):
		caderno_panel.visible = not caderno_panel.visible
		if caderno_panel.visible:
			_ensure_caderno_cursor()


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum < 0.2:
		_update_pulso(delta)
		return
	_clock_accum = 0.0
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		_update_pulso(delta)
		return
	if gm.has_method("get_tempo_restante") and gm.has_method("get_estado_nome"):
		var restante: float = max(0.0, float(gm.get_tempo_restante()))
		var minutos: int = int(restante) / 60
		var segundos: int = int(restante) % 60
		var estado_nome: String = String(gm.get_estado_nome())
		var rodada := 1
		if gm.has_method("get_ciclo_atual"):
			rodada = int(gm.get_ciclo_atual())
		if clock_label != null:
			clock_label.text = "Rodada %d - %s %02d:%02d" % [rodada, estado_nome, minutos, segundos]
	_update_pulso(delta)


func exibir_dialogo(dado, registrar: bool = true) -> void:
	if is_modal_open():
		return
	var texto := _extrair_texto(dado)
	_set_dialog_speaker(_extrair_nome(dado), _extrair_portrait(dado))
	_registrar_no_journal(texto)
	if dialog_label != null:
		dialog_label.text = texto
	if dialog_panel != null:
		dialog_panel.visible = true
	if dialog_timer != null:
		dialog_timer.start()
	if registrar:
		_registrar_pista(dado)


func exibir_mensagem_sistema(texto: String) -> void:
	if is_modal_open():
		return
	_set_dialog_speaker("", null)
	if dialog_label != null:
		dialog_label.text = texto
	if dialog_panel != null:
		dialog_panel.visible = true
	if dialog_timer != null:
		dialog_timer.start()


func _on_dialog_timer_timeout() -> void:
	_ocultar_dialogo()


func _ocultar_dialogo() -> void:
	if dialog_panel != null:
		dialog_panel.visible = false
	if dialog_timer != null:
		dialog_timer.stop()


func _registrar_pista(dado: Variant) -> void:
	var evidencia := _normalizar_evidencia(dado)
	var texto := String(evidencia.get("texto", "")).strip_edges()
	if texto == "":
		return
	if evidencias_set.has(texto):
		return
	evidencias_set[texto] = true
	evidencias.append(evidencia)
	_atualizar_caderno()


func registrar_pista(dado: Variant) -> void:
	_registrar_pista(dado)
	_ensure_caderno_cursor()


func registrar_contradicao(texto: String) -> void:
	if texto == "":
		return
	contradicoes[texto] = true
	_registrar_pista(texto)


func _extrair_texto(dado: Variant) -> String:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("texto"):
		return String(dado["texto"])
	return String(dado)


func _extrair_nome(dado: Variant) -> String:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("speaker_name"):
		return String(dado["speaker_name"])
	return ""


func _extrair_portrait(dado: Variant) -> Texture2D:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("portrait"):
		var tex: Variant = dado["portrait"]
		if tex is Texture2D:
			return tex
	return null


func _set_dialog_speaker(nome: String, portrait: Texture2D) -> void:
	if dialog_name_label != null:
		dialog_name_label.text = nome
	if dialog_name_plate != null:
		dialog_name_plate.visible = nome != ""
	if dialog_portrait != null:
		dialog_portrait.texture = portrait
		dialog_portrait.visible = portrait != null


func _normalizar_evidencia(dado: Variant) -> Dictionary:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("texto"):
		return {
			"texto": String(dado.get("texto", "")),
			"mask_hint": String(dado.get("mask_hint", "")),
			"local_hint": String(dado.get("local_hint", "")),
			"tipo": String(dado.get("tipo", ""))
		}
	return {
		"texto": String(dado),
		"mask_hint": "",
		"local_hint": "",
		"tipo": ""
	}


func _registrar_no_journal(texto: String) -> void:
	var journal := get_node_or_null("/root/JournalManager")
	if journal != null and journal.has_method("adicionar_registro"):
		journal.adicionar_registro(texto)


func _atualizar_caderno() -> void:
	if caderno_label == null:
		return
	var linhas: Array[String] = []
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("get_estado_nome") and gm.has_method("get_ciclo_atual"):
		var estado_nome := String(gm.get_estado_nome())
		var ciclo := int(gm.get_ciclo_atual())
		linhas.append("Rodada: %d - %s" % [ciclo, estado_nome])
		linhas.append("-------------------------")
	for i in range(evidencias.size()):
		var prefixo := ""
		var is_cursor := (i == _caderno_cursor_idx)
		var is_selected := (i == evidencia_selecionada_idx)
		if is_selected:
			prefixo = ">> "
		elif is_cursor:
			prefixo = "> "
		var texto_item := String(evidencias[i].get("texto", ""))
		if contradicoes.has(texto_item):
			prefixo = "%s[color=red](!)[/color] " % prefixo
		linhas.append("%s[url=%d]%s[/url]" % [prefixo, i, texto_item])
	caderno_label.text = "Caderno de Anotacoes:\n" + "\n".join(linhas)


func _ensure_caderno_cursor() -> void:
	if evidencias.is_empty():
		_caderno_cursor_idx = -1
	elif _caderno_cursor_idx < 0 or _caderno_cursor_idx >= evidencias.size():
		_caderno_cursor_idx = clamp(evidencia_selecionada_idx, 0, evidencias.size() - 1)
		if _caderno_cursor_idx < 0:
			_caderno_cursor_idx = 0


func _move_caderno_cursor(delta: int) -> void:
	if evidencias.is_empty():
		_caderno_cursor_idx = -1
		_atualizar_caderno()
		return
	_ensure_caderno_cursor()
	_caderno_cursor_idx = clamp(_caderno_cursor_idx + delta, 0, evidencias.size() - 1)
	_atualizar_caderno()


func _toggle_select_caderno() -> void:
	if evidencias.is_empty():
		return
	_ensure_caderno_cursor()
	if _caderno_cursor_idx == evidencia_selecionada_idx:
		evidencia_selecionada_idx = -1
	else:
		evidencia_selecionada_idx = _caderno_cursor_idx
	_atualizar_caderno()


func _on_caderno_meta_clicked(meta: Variant) -> void:
	var idx := -1
	match typeof(meta):
		TYPE_INT, TYPE_FLOAT:
			idx = int(meta)
		TYPE_STRING, TYPE_STRING_NAME:
			var idx_str := String(meta)
			if idx_str.is_valid_int():
				idx = int(idx_str)
	if idx < 0 or idx >= evidencias.size():
		return
	if evidencia_selecionada_idx == idx:
		evidencia_selecionada_idx = -1
	else:
		evidencia_selecionada_idx = idx
	_atualizar_caderno()


func _on_acusar_pressed() -> void:
	if acusacao_ativa:
		cancelar_acusacao(true)
		return
	acusacao_ativa = true
	if caderno_panel != null:
		caderno_panel.visible = true
	_atualizar_botao_acusar()
	exibir_dialogo("Escolha um suspeito e confirme a acusacao.", false)


func set_fase2(ativa: bool) -> void:
	if acusar_button != null:
		acusar_button.visible = ativa
		acusar_button.disabled = not ativa
	_atualizar_botao_acusar()


func is_acusacao_ativa() -> bool:
	return acusacao_ativa


func get_evidencia_selecionada() -> String:
	if evidencia_selecionada_idx < 0 or evidencia_selecionada_idx >= evidencias.size():
		return ""
	return String(evidencias[evidencia_selecionada_idx].get("texto", ""))


func finalizar_acusacao() -> void:
	acusacao_ativa = false
	if acusar_button != null:
		acusar_button.disabled = true
	if caderno_panel != null:
		caderno_panel.visible = false
	evidencia_selecionada_idx = -1
	_atualizar_caderno()
	_fechar_confirmacao()
	_atualizar_botao_acusar()


func cancelar_acusacao(limpar_evidencia: bool = true) -> void:
	acusacao_ativa = false
	if caderno_panel != null:
		caderno_panel.visible = false
	if limpar_evidencia:
		evidencia_selecionada_idx = -1
		_atualizar_caderno()
	_fechar_confirmacao()
	_atualizar_botao_acusar()


func _atualizar_botao_acusar() -> void:
	if acusar_button == null:
		return
	if acusacao_ativa:
		acusar_button.text = "Cancelar Acusacao"
	else:
		acusar_button.text = "Acusar Mentira"


func should_suppress_dialog_on_interact() -> bool:
	if is_modal_open():
		return true
	if acusacao_ativa:
		return true
	return false


func is_modal_open() -> bool:
	return _confirmacao_aberta or _resultado_aberto


func abrir_confirmacao_acusar(npc: Node, nome: String) -> void:
	if confirm_panel == null or confirm_label == null:
		return
	_confirmacao_aberta = true
	_npc_pendente = npc
	if dialog_panel != null:
		dialog_panel.visible = false
	confirm_label.text = "Acusar %s?" % nome
	confirm_panel.visible = true


func _on_confirm_yes_pressed() -> void:
	if _npc_pendente != null:
		emit_signal("acusacao_confirmada", _npc_pendente)
	_fechar_confirmacao()


func _on_confirm_no_pressed() -> void:
	emit_signal("acusacao_cancelada")
	_fechar_confirmacao()


func _fechar_confirmacao() -> void:
	_confirmacao_aberta = false
	_npc_pendente = null
	if confirm_panel != null:
		confirm_panel.visible = false


func mostrar_resultado(texto: String) -> void:
	if result_panel == null or result_label == null:
		return
	_resultado_aberto = true
	if dialog_panel != null:
		dialog_panel.visible = false
	if caderno_panel != null:
		caderno_panel.visible = false
	if confirm_panel != null:
		confirm_panel.visible = false
	result_label.text = texto
	result_panel.visible = true


func _on_result_restart_pressed() -> void:
	get_tree().reload_current_scene()


func mostrar_blackout(duracao: float) -> void:
	if blackout_rect == null:
		return
	blackout_rect.visible = true
	if blackout_label != null:
		blackout_label.text = "Um grito corta a musica..."
		blackout_label.visible = true
	await get_tree().create_timer(duracao).timeout
	blackout_rect.visible = false
	if blackout_label != null:
		blackout_label.visible = false


func _update_pulso(delta: float) -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	var ratio := 1.0
	if gm != null and gm.has_method("get_investigacao_ratio"):
		ratio = float(gm.get_investigacao_ratio())
	var intensity := 0.0
	if ratio <= 0.5:
		intensity = clamp((0.5 - ratio) / 0.5, 0.0, 1.0)
	if has_node("/root/AudioManager"):
		var audio := get_node("/root/AudioManager")
		if audio.has_method("set_horror_intensity"):
			audio.set_horror_intensity(intensity)
	_pulse_time += delta * (1.5 + intensity * 4.0)
	var pulse := 0.5 + 0.5 * sin(_pulse_time)
	if vignette_rect != null and vignette_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = vignette_rect.material
		mat.set_shader_parameter("strength", intensity)
		mat.set_shader_parameter("pulse", pulse)
	if heartbeat_player != null and heartbeat_player.stream != null:
		if intensity <= 0.01:
			if heartbeat_player.playing:
				heartbeat_player.stop()
		else:
			if not heartbeat_player.playing:
				heartbeat_player.play()
			heartbeat_player.volume_db = lerp(-24.0, -3.0, intensity)
			heartbeat_player.pitch_scale = lerp(1.0, 1.6, intensity)


func _get_node_or_null(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)
