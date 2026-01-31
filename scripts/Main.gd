extends Node2D

@export var max_interacoes_fase_1 := 4
@export var usar_temporizador := false
@export var tempo_fase_1 := 60.0

var _interacoes_fase_1 := 0
var _fase2_iniciada := false
var _timer: Timer
var _evidencias_registradas: Dictionary = {}
var _ui_conectada := false


func _ready() -> void:
	_conectar_player()
	_setup_timer()
	call_deferred("_conectar_ui")


func _conectar_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("pista_coletada"):
		player.connect("pista_coletada", Callable(self, "_on_pista_coletada"))
	if player != null and player.has_signal("npc_interagido"):
		player.connect("npc_interagido", Callable(self, "_on_npc_interagido"))


func _conectar_ui() -> void:
	if _ui_conectada:
		return
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return
	if ui.has_signal("acusacao_confirmada"):
		ui.connect("acusacao_confirmada", Callable(self, "_on_acusacao_confirmada"))
	if ui.has_signal("acusacao_cancelada"):
		ui.connect("acusacao_cancelada", Callable(self, "_on_acusacao_cancelada"))
	_ui_conectada = true


func _setup_timer() -> void:
	if not usar_temporizador:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = tempo_fase_1
	_timer.timeout.connect(_on_tempo_fase_1_timeout)
	add_child(_timer)
	_timer.start()


func _on_pista_coletada(_texto: String) -> void:
	if _fase2_iniciada:
		return
	if _evidencias_registradas.has(_texto):
		return
	_evidencias_registradas[_texto] = true
	_interacoes_fase_1 += 1
	if _interacoes_fase_1 >= max_interacoes_fase_1:
		_iniciar_apagao()


func _on_tempo_fase_1_timeout() -> void:
	_iniciar_apagao()


func _iniciar_apagao() -> void:
	if _fase2_iniciada:
		return
	_fase2_iniciada = true
	if _timer != null:
		_timer.stop()

	var npcs: Array = get_tree().get_nodes_in_group("npcs")
	if npcs.is_empty():
		return

	var killer := _escolher_killer(npcs)
	var vitima := _escolher_vitima(npcs, killer)
	var mascara_vitima := ""

	if vitima != null:
		if vitima.has_method("get_mascara_atual"):
			mascara_vitima = vitima.get_mascara_atual()
		if vitima.has_method("definir_vitima"):
			vitima.definir_vitima()

	for npc in npcs:
		if npc.has_method("mudar_fase"):
			if npc == killer:
				npc.mudar_fase(mascara_vitima)
			else:
				npc.mudar_fase()

	_embaralhar_posicoes(npcs, vitima)
	_notificar_apagao()
	_ativar_fase2_ui()


func _escolher_killer(npcs: Array) -> Node:
	for npc in npcs:
		if npc.is_killer:
			return npc
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return npcs[rng.randi_range(0, npcs.size() - 1)]


func _escolher_vitima(npcs: Array, killer: Node) -> Node:
	if npcs.size() <= 1:
		return null
	var candidatos: Array = []
	for npc in npcs:
		if npc != killer:
			candidatos.append(npc)
	if candidatos.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidatos[rng.randi_range(0, candidatos.size() - 1)]


func _embaralhar_posicoes(npcs: Array, vitima: Node) -> void:
	var vivos: Array = []
	for npc in npcs:
		if npc != vitima:
			vivos.append(npc)
	if vivos.size() < 2:
		return
	var posicoes: Array[Vector2] = []
	for npc in vivos:
		posicoes.append(npc.global_position)
	posicoes.shuffle()
	for i in range(vivos.size()):
		vivos[i].global_position = posicoes[i]


func _notificar_apagao() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("exibir_dialogo"):
		ui.exibir_dialogo("As luzes se apagaram. Um grito ecoa no salao.", false)


func _ativar_fase2_ui() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_fase2"):
		ui.set_fase2(true)
	_conectar_ui()


func _on_npc_interagido(npc: Node) -> void:
	if not _fase2_iniciada:
		return
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return
	var acusacao_ativa: bool = ui.has_method("is_acusacao_ativa") and ui.is_acusacao_ativa()
	var evidencia := ""
	if ui.has_method("get_evidencia_selecionada"):
		evidencia = ui.get_evidencia_selecionada()
	if evidencia == "":
		if acusacao_ativa and ui.has_method("exibir_dialogo"):
			ui.exibir_dialogo("Selecione uma evidencia no caderno antes de acusar.", false)
		return
	if ui.has_method("abrir_confirmacao_acusar"):
		var nome := _obter_nome_npc(npc)
		ui.abrir_confirmacao_acusar(npc, nome)


func _obter_nome_npc(npc: Node) -> String:
	if npc == null:
		return "suspeito"
	if npc.has_method("get_display_name"):
		return npc.get_display_name()
	if npc.has_method("get_mascara_atual"):
		return npc.get_mascara_atual()
	return npc.name


func _on_acusacao_confirmada(npc: Node) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return
	var acertou: bool = npc != null and bool(npc.get("is_killer"))
	if ui.has_method("mostrar_resultado"):
		if acertou:
			ui.mostrar_resultado("Voce venceu! Desvendou o misterio.")
		else:
			ui.mostrar_resultado("Game Over. Voce foi expulso do baile.")
	if ui.has_method("finalizar_acusacao"):
		ui.finalizar_acusacao()


func _on_acusacao_cancelada() -> void:
	return
