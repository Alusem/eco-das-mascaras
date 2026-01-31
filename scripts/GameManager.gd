extends Node2D

enum GameState { TALKING, INVESTIGATING, BLACKOUT, GAME_OVER }

@export var tempo_fase_inicial := 30.0
@export var tempo_investigacao := 45.0
@export var duracao_blackout := 1.0
@export var usar_limite_interacoes := false
@export var limite_interacoes := 4
@export var reviver_npcs_no_blackout := false
@export var destacar_contradicoes := false
@export var intervalo_evento_min := 8.0
@export var intervalo_evento_max := 15.0

var estado_atual: GameState = GameState.TALKING
var Notebook: Array[String] = []

var _notebook_set: Dictionary = {}
var _state_timer: Timer
var _evento_timer: Timer
var _interacoes_fase1 := 0
var _posicoes_iniciais: Dictionary = {}
var _ui_conectada := false
var _mascara_para_local: Dictionary = {}
var _locais_disponiveis: Array[String] = []
var _mascara_para_personalidade: Dictionary = {}
var _locais_para_pos: Dictionary = {}
var _ultima_mascara_assassino := ""
var _ultima_mascara_vitima := ""
var _ultimo_assassino_nome := ""
var _ciclo_atual := 1
var _ultima_personalidade_assassino := ""
var _falhas_por_personalidade: Dictionary = {
	"Raposa": PackedStringArray(["curiosidade", "pecas", "deliciosas sombras"]),
	"Lobo": PackedStringArray(["grr", "cheiro", "ruido"]),
	"Cervo": PackedStringArray(["peço perdão", "melodia", "etiqueta"]),
	"Coelho": PackedStringArray(["v-voce viu", "e-eu", "muito rapido"]),
	"Coruja": PackedStringArray(["a coruja nota", "eu vejo", "silencio"]),
	"Javali": PackedStringArray(["fome", "comida", "calor"])
}
var _ambient_events: PackedStringArray = PackedStringArray(
	[
		"Um copo se estilhaça em algum canto.",
		"Alguem ri alto e logo se cala.",
		"A musica falha por um instante e volta mais baixa.",
		"Passos apressados ecoam perto da Sacada.",
		"Um sussurro atravessa o salao e desaparece."
	]
)


func _ready() -> void:
	add_to_group("game_manager")
	_coletar_npcs()
	_conectar_player()
	_setup_timer()
	_atualizar_ui_fase2(false)
	_iniciar_talking()
	_play_audio_phase_1()
	call_deferred("_conectar_ui")


func _setup_timer() -> void:
	_state_timer = Timer.new()
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timeout)
	add_child(_state_timer)
	_evento_timer = Timer.new()
	_evento_timer.one_shot = true
	_evento_timer.timeout.connect(_on_evento_timeout)
	add_child(_evento_timer)


func _coletar_npcs() -> void:
	_posicoes_iniciais.clear()
	for npc in get_tree().get_nodes_in_group("npcs"):
		_posicoes_iniciais[npc] = npc.global_position
		if npc.has_method("resetar_para_ciclo"):
			npc.resetar_para_ciclo()
	_registrar_locais_pos()
	_registrar_locais_mascara()


func _conectar_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("pista_coletada"):
		player.connect("pista_coletada", Callable(self, "_on_pista_coletada"))
	if player.has_signal("npc_interagido"):
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


func _atualizar_ui_fase2(ativa: bool) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_fase2"):
		ui.set_fase2(ativa)


func _iniciar_talking() -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	estado_atual = GameState.TALKING
	_interacoes_fase1 = 0
	_ciclo_atual = 1
	_registrar_locais_mascara()
	_parar_evento_timer()
	_start_timer(tempo_fase_inicial)
	_play_audio_phase_1()


func _start_timer(tempo: float) -> void:
	if _state_timer == null:
		return
	if estado_atual == GameState.GAME_OVER:
		return
	if tempo <= 0.0:
		_on_state_timeout()
		return
	_state_timer.stop()
	_state_timer.wait_time = tempo
	_state_timer.start()


func _start_evento_timer() -> void:
	if _evento_timer == null:
		return
	if intervalo_evento_min <= 0.0 or intervalo_evento_max <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tempo := rng.randf_range(intervalo_evento_min, intervalo_evento_max)
	_evento_timer.stop()
	_evento_timer.wait_time = tempo
	_evento_timer.start()


func _parar_evento_timer() -> void:
	if _evento_timer != null:
		_evento_timer.stop()


func _on_evento_timeout() -> void:
	if estado_atual != GameState.INVESTIGATING:
		return
	if _ambient_events.size() == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var texto := _ambient_events[rng.randi_range(0, _ambient_events.size() - 1)]
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("exibir_mensagem_sistema"):
		ui.exibir_mensagem_sistema(texto)
	_start_evento_timer()


func _on_state_timeout() -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	match estado_atual:
		GameState.TALKING:
			_iniciar_investigacao()
		GameState.INVESTIGATING:
			call_deferred("_iniciar_blackout")


func _iniciar_investigacao() -> void:
	if estado_atual == GameState.BLACKOUT or estado_atual == GameState.GAME_OVER:
		return
	estado_atual = GameState.BLACKOUT
	_parar_evento_timer()
	_play_audio_blackout()
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("mostrar_blackout"):
		ui.mostrar_blackout(duracao_blackout)
	if duracao_blackout <= 0.0:
		_finalizar_investigacao_pos_blackout()
		return
	get_tree().create_timer(duracao_blackout).timeout.connect(_finalizar_investigacao_pos_blackout)


func _finalizar_investigacao_pos_blackout() -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	_atribuir_locais_npcs()
	_executar_assassinato()
	_ciclo_atual += 1
	if _verificar_derrota_sozinho():
		return
	estado_atual = GameState.INVESTIGATING
	_atualizar_ui_fase2(true)
	_start_timer(tempo_investigacao)
	_notificar_apagao()
	_start_evento_timer()
	_play_audio_phase_2()


func _iniciar_blackout() -> void:
	if estado_atual == GameState.BLACKOUT or estado_atual == GameState.GAME_OVER:
		return
	estado_atual = GameState.BLACKOUT
	_parar_evento_timer()
	_play_audio_blackout()
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("mostrar_blackout"):
		await ui.mostrar_blackout(duracao_blackout)
	_resetar_posicoes()
	if reviver_npcs_no_blackout:
		_reviver_npcs()
	_atribuir_locais_npcs()
	_executar_assassinato()
	_ciclo_atual += 1
	if _verificar_derrota_sozinho():
		return
	estado_atual = GameState.INVESTIGATING
	_atualizar_ui_fase2(true)
	_start_timer(tempo_investigacao)
	_start_evento_timer()
	_play_audio_phase_2()


func _notificar_apagao() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("exibir_mensagem_sistema"):
		ui.exibir_mensagem_sistema("As luzes se apagaram. Um grito ecoa no salao.")


func _reviver_npcs() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("resetar_para_ciclo"):
			npc.resetar_para_ciclo()


func _resetar_posicoes() -> void:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc in _posicoes_iniciais:
			npc.global_position = _posicoes_iniciais[npc]


func _get_npcs_vivos() -> Array:
	var vivos: Array = []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("definir_vitima") and npc.is_vitima:
			continue
		vivos.append(npc)
	return vivos


func _executar_assassinato() -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	var vivos := _get_npcs_vivos()
	if vivos.size() < 2:
		return
	_ultima_mascara_assassino = ""
	_ultima_mascara_vitima = ""
	_ultimo_assassino_nome = ""
	_ultima_personalidade_assassino = ""
	for npc in vivos:
		if npc.has_method("set_killer"):
			npc.set_killer(false)
	var killer := _escolher_aleatorio(vivos)
	if killer != null and killer.has_method("set_killer"):
		killer.set_killer(true)
	var vitima := _escolher_vitima(vivos, killer)
	var mascara_vitima := ""
	if killer != null and killer.has_method("get_mascara_atual"):
		_ultima_mascara_assassino = killer.get_mascara_atual()
	if killer != null:
		_ultima_personalidade_assassino = String(killer.get("original_personality"))
	_ultimo_assassino_nome = _obter_nome_npc(killer)
	if vitima != null and vitima.has_method("get_mascara_atual"):
		mascara_vitima = vitima.get_mascara_atual()
		_ultima_mascara_vitima = mascara_vitima
	if vitima != null and vitima.has_method("definir_vitima"):
		vitima.definir_vitima()
	if killer != null and killer.has_method("aplicar_mascara"):
		killer.aplicar_mascara(mascara_vitima)


func _escolher_aleatorio(lista: Array) -> Node:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return lista[rng.randi_range(0, lista.size() - 1)]


func _escolher_vitima(vivos: Array, killer: Node) -> Node:
	var candidatos: Array = []
	for npc in vivos:
		if npc != killer:
			candidatos.append(npc)
	if candidatos.is_empty():
		return null
	return _escolher_aleatorio(candidatos)


func on_npc_interacted(npc: Node) -> Variant:
	if npc == null:
		return ""
	if estado_atual == GameState.GAME_OVER:
		return ""
	if npc.is_vitima:
		return ""
	match estado_atual:
		GameState.TALKING:
			return _montar_fala_fase1(npc)
		GameState.INVESTIGATING:
			return _montar_fala_investigacao(npc)
	return ""


func _on_pista_coletada(dado: Variant) -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	var texto := _extrair_texto(dado)
	if texto == "":
		return
	if _notebook_set.has(texto):
		return
	_notebook_set[texto] = true
	Notebook.append(texto)
	if usar_limite_interacoes and estado_atual == GameState.TALKING:
		_interacoes_fase1 += 1
		if _interacoes_fase1 >= limite_interacoes:
			_iniciar_investigacao()


func _extrair_texto(dado: Variant) -> String:
	if typeof(dado) == TYPE_DICTIONARY and dado.has("texto"):
		return String(dado["texto"])
	return String(dado)


func _on_npc_interagido(npc: Node) -> void:
	if estado_atual == GameState.GAME_OVER:
		return
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return
	if not ui.has_method("is_acusacao_ativa") or not ui.is_acusacao_ativa():
		return
	if npc == null or not npc.is_in_group("npcs"):
		return
	if ui.has_method("abrir_confirmacao_acusar"):
		ui.abrir_confirmacao_acusar(npc, _obter_nome_npc(npc))


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
	if estado_atual == GameState.GAME_OVER:
		return
	var acertou: bool = npc != null and bool(npc.get("is_killer"))
	if ui.has_method("mostrar_resultado"):
		var resumo := _montar_resumo_final()
		if acertou:
			ui.mostrar_resultado("Voce venceu! Desvendou o misterio.%s" % resumo)
		else:
			ui.mostrar_resultado("Game Over. Voce foi expulso do baile.%s" % resumo)
	if ui.has_method("finalizar_acusacao"):
		ui.finalizar_acusacao()


func _on_acusacao_cancelada() -> void:
	return


func _registrar_locais_mascara() -> void:
	_mascara_para_local.clear()
	_locais_disponiveis.clear()
	_mascara_para_personalidade.clear()
	for npc in get_tree().get_nodes_in_group("npcs"):
		var mascara := String(npc.get("mascara_inicial"))
		var local := String(npc.get("original_location"))
		if local == "":
			local = String(npc.get("local_fase_1"))
		var personalidade := String(npc.get("original_personality"))
		if personalidade == "":
			personalidade = _personality_from_mask(mascara)
		if mascara != "" and local != "":
			_mascara_para_local[mascara] = local
			if not _locais_disponiveis.has(local):
				_locais_disponiveis.append(local)
		if mascara != "" and personalidade != "":
			_mascara_para_personalidade[mascara] = personalidade


func _registrar_locais_pos() -> void:
	_locais_para_pos.clear()
	var locais_node := get_node_or_null("Locais")
	if locais_node == null:
		return
	for child in locais_node.get_children():
		if child is Node2D:
			var chave := String(child.name)
			if chave == "Pista":
				chave = "Pista de danca"
			_locais_para_pos[chave] = child.global_position


func _atribuir_locais_npcs() -> void:
	if _locais_disponiveis.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for npc in get_tree().get_nodes_in_group("npcs"):
		var local := _locais_disponiveis[rng.randi_range(0, _locais_disponiveis.size() - 1)]
		if npc != null and npc.has_method("set_current_location"):
			npc.set_current_location(local)
		if _locais_para_pos.has(local):
			npc.global_position = _locais_para_pos[local]
		if npc != null and npc.has_method("set_home_pos"):
			npc.set_home_pos()


func _montar_fala_investigacao(npc: Node) -> Dictionary:
	var mascara := _get_mascara_atual(npc)
	var local_correto := _get_local_original_por_mascara(mascara)
	if local_correto == "":
		local_correto = _get_local_original_por_npc(npc)
	var local_declarado := local_correto
	var is_killer_flag := bool(npc.get("is_killer"))
	if is_killer_flag:
		local_declarado = _escolher_local_falso(local_correto)
	var personalidade_atual := _get_personalidade_por_mascara(mascara)
	var base := _fala_panico(personalidade_atual)
	var speaker := _get_speaker_name(npc)
	var portrait := _get_portrait(npc)
	var frase := "Eu estava no %s." % local_declarado
	if is_killer_flag:
		var falha := _falha_palavra(_ultima_personalidade_assassino)
		if falha != "":
			frase = "Eu estava no %s... %s." % [local_declarado, falha]
	if destacar_contradicoes and is_killer_flag:
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui != null and ui.has_method("registrar_contradicao"):
			ui.registrar_contradicao(frase)
	if base != "":
		frase = "%s %s" % [base, frase]
	return {
		"texto": frase,
		"mask_hint": mascara,
		"local_hint": local_declarado,
		"tipo": "fala",
		"speaker_name": speaker,
		"portrait": portrait
	}


func _montar_fala_fase1(npc: Node) -> Dictionary:
	var mascara := _get_mascara_atual(npc)
	var local := _get_local_original_por_npc(npc)
	if local == "":
		local = _get_local_original_por_mascara(mascara)
	var personalidade := String(npc.get("original_personality"))
	if personalidade == "":
		personalidade = _get_personalidade_por_mascara(mascara)
	var speaker := _get_speaker_name(npc)
	var portrait := _get_portrait(npc)
	var frase := _fala_fase1(personalidade, local)
	return {
		"texto": frase,
		"mask_hint": mascara,
		"local_hint": local,
		"tipo": "fala",
		"speaker_name": speaker,
		"portrait": portrait
	}


func _fala_fase1(personalidade: String, local: String) -> String:
	var templates: PackedStringArray = PackedStringArray()
	match personalidade:
		"Raposa":
			templates = PackedStringArray([
				"Oh, curiosidade... o brilho deste salao esconde sombras deliciosas.",
				"As pecas se movem com graca, curiosidade. Tudo parece um jogo.",
				"Curiosidade, as sombras dançam e sorriem para quem sabe olhar.",
				"Ha segredos aqui, curiosidade. Eu os provo como vinho.",
				"Cada gesto e uma pista, cada sorriso uma armadilha sutil."
			])
		"Lobo":
			templates = PackedStringArray([
				"Saia do meu caminho. O ruido daqui e irritante.",
				"Grr. O cheiro aqui e ruim e eu nao tenho paciencia.",
				"Direto ao ponto: estou de olho em tudo.",
				"Se esbarrou em mim, ja errou.",
				"Menos conversa. Mais distancia."
			])
		"Cervo":
			templates = PackedStringArray([
				"Peço perdão, mas a melodia me distraiu por um momento.",
				"Peço perdão pela minha postura, estou tentando manter a elegancia.",
				"Permita-me dizer, a etiqueta ainda tem valor aqui.",
				"Peço perdão se pareço tenso; a noite carrega um peso estranho.",
				"A melodia e gentil, mas algo a torna inquieta."
			])
		"Coelho":
			templates = PackedStringArray([
				"Você viu? Você viu? As luzes parecem piscar!",
				"E-eu só quero ficar quieto, tá? É tudo muito rápido.",
				"Foi rápido, foi rápido... eu nem sei onde olhar!",
				"Eu falo rápido, eu sei, mas é porque estou nervoso!",
				"Eu não gosto desse clima, sério."
			])
		"Coruja":
			templates = PackedStringArray([
				"A Coruja nota o silencio que antecede o caos.",
				"A Coruja observa. Tudo aqui e previsivel, ate deixar de ser.",
				"Eu vejo mais do que dizem.",
				"A Coruja observa os movimentos como quem lê um livro.",
				"Silencio. O salao respira antes do impacto."
			])
		"Javali":
			templates = PackedStringArray([
				"Que calor e que fome. E ainda por cima essa etiqueta chata.",
				"Cadê a comida? Festa boa tem mesa cheia.",
				"Não vim pra conversa fina. Vim pra comer e beber.",
				"Esse lugar ta quente demais, preciso de algo gelado.",
				"Se não tiver comida, eu vou embora."
			])
	var base := _fala_aleatoria_packed(templates)
	if base == "":
		return "..."
	return base


func _fala_panico(personalidade: String) -> String:
	var templates: PackedStringArray = PackedStringArray()
	match personalidade:
		"Raposa":
			templates = PackedStringArray([
				"Curiosidade, o medo tem uma coreografia própria.",
				"As sombras se fecharam como um segredo.",
				"Ah... o salao virou um palco para o pavor.",
				"O medo tem perfume e ele passou por mim."
			])
		"Lobo":
			templates = PackedStringArray([
				"Grr... o ruido ficou pior.",
				"O cheiro mudou. Algo deu errado.",
				"Nao me empurra. Isso aqui ficou perigoso.",
				"Grr... esse silencio ta me irritando."
			])
		"Cervo":
			templates = PackedStringArray([
				"Peço perdão, isso foi profundamente perturbador.",
				"A melodia se quebrou e o salao silenciou.",
				"Peço perdão, estou tentando manter a compostura.",
				"Peço perdão, meu coracao ainda esta acelerado."
			])
		"Coelho":
			templates = PackedStringArray([
				"Você viu? Você viu? As luzes sumiram!",
				"Eu... eu fiquei apavorado, foi tudo rapido!",
				"Eu juro, juro que ouvi um grito!",
				"Eu... eu nao sei o que fazer!"
			])
		"Coruja":
			templates = PackedStringArray([
				"A Coruja nota o silencio pesado.",
				"A Coruja vê o medo nos passos.",
				"Eu observo e sinto o salao prender o ar.",
				"A Coruja percebe o tremor nas paredes."
			])
		"Javali":
			templates = PackedStringArray([
				"Que confusao! Isso acabou com a minha fome.",
				"Calor, barulho e agora isso? Que festa.",
				"Eu so queria comer em paz.",
				"Isso estragou minha bebida!"
			])
	return _fala_aleatoria_packed(templates)


func _get_mascara_atual(npc: Node) -> String:
	if npc != null and npc.has_method("get_mascara_atual"):
		return npc.get_mascara_atual()
	return String(npc.get("mascara_inicial"))


func _get_local_original_por_mascara(mascara: String) -> String:
	if _mascara_para_local.has(mascara):
		return _mascara_para_local[mascara]
	return ""


func _get_local_original_por_npc(npc: Node) -> String:
	var local := String(npc.get("original_location"))
	if local == "":
		local = String(npc.get("local_fase_1"))
	return local


func _get_personalidade_por_mascara(mascara: String) -> String:
	if _mascara_para_personalidade.has(mascara):
		return _mascara_para_personalidade[mascara]
	return _personality_from_mask(mascara)


func _get_speaker_name(npc: Node) -> String:
	if npc != null and npc.has_method("get_speaker_name"):
		return npc.get_speaker_name()
	return ""


func _get_portrait(npc: Node) -> Texture2D:
	if npc != null and npc.has_method("get_portrait"):
		return npc.get_portrait()
	return null


func _personality_from_mask(mascara: String) -> String:
	if mascara.begins_with("MASCARA DE "):
		return mascara.replace("MASCARA DE ", "").capitalize()
	return mascara.capitalize()


func _fala_aleatoria_packed(falas: PackedStringArray) -> String:
	if falas.size() == 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return falas[rng.randi_range(0, falas.size() - 1)]


func _falha_palavra(personalidade_original: String) -> String:
	if not _falhas_por_personalidade.has(personalidade_original):
		return ""
	var lista: PackedStringArray = _falhas_por_personalidade[personalidade_original]
	return _fala_aleatoria_packed(lista)


func get_tempo_restante() -> float:
	if _state_timer == null:
		return 0.0
	if not _state_timer.is_stopped():
		return _state_timer.time_left
	return 0.0


func get_estado_nome() -> String:
	match estado_atual:
		GameState.TALKING:
			return "Conversa"
		GameState.INVESTIGATING:
			return "Investigacao"
		GameState.BLACKOUT:
			return "Apagao"
		GameState.GAME_OVER:
			return "Fim"
	return ""


func get_ciclo_atual() -> int:
	return _ciclo_atual


func get_investigacao_ratio() -> float:
	if estado_atual != GameState.INVESTIGATING:
		return 1.0
	if tempo_investigacao <= 0.0:
		return 0.0
	if _state_timer == null:
		return 0.0
	return clamp(_state_timer.time_left / tempo_investigacao, 0.0, 1.0)


func _escolher_local_falso(local_correto: String) -> String:
	if _locais_disponiveis.size() == 0:
		return local_correto
	var opcoes: Array[String] = []
	for local in _locais_disponiveis:
		if local != local_correto:
			opcoes.append(local)
	if opcoes.is_empty():
		return local_correto
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return opcoes[rng.randi_range(0, opcoes.size() - 1)]


func _verificar_derrota_sozinho() -> bool:
	var vivos := _get_npcs_vivos()
	if vivos.size() == 1:
		var npc: Node = vivos[0]
		if npc != null and bool(npc.get("is_killer")):
			_encerrar_jogo("Game Over. O assassino ficou sozinho com voce.")
			return true
	return false


func _encerrar_jogo(texto: String) -> void:
	estado_atual = GameState.GAME_OVER
	if _state_timer != null:
		_state_timer.stop()
	_parar_evento_timer()
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("mostrar_resultado"):
		ui.mostrar_resultado("%s%s" % [texto, _montar_resumo_final()])
	if ui != null and ui.has_method("finalizar_acusacao"):
		ui.finalizar_acusacao()
	_ciclo_atual = max(1, _ciclo_atual)


func _play_audio_phase_1() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_phase_1()


func _play_audio_phase_2() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_phase_2()


func _play_audio_blackout() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").on_blackout()


func _montar_resumo_final() -> String:
	var linhas: Array[String] = []
	if _ultimo_assassino_nome != "":
		linhas.append("Assassino: %s." % _ultimo_assassino_nome)
	if _ultima_mascara_vitima != "":
		linhas.append("Mascara da vitima: %s." % _ultima_mascara_vitima)
	if _ultima_mascara_assassino != "":
		linhas.append("Mascara original: %s." % _ultima_mascara_assassino)
	if linhas.is_empty():
		return ""
	return "\n" + "\n".join(linhas)
