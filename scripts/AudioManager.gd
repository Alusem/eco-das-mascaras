extends Node

@export var phase_music: AudioStream = preload("res://resources/Musica.mp3")
@export var blackout_sfx: AudioStream
@export var base_volume_db := -8.0
@export var phase2_pitch := 0.95
@export var phase2_cutoff_hz := 1200.0
@export var phase2_cutoff_start_hz := 8000.0

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _phase2_active := false
var _intensity_tween: Tween


func _ready() -> void:
	_ensure_buses()
	_create_players()
	_carregar_grito_padrao()
	play_phase_1()


func _carregar_grito_padrao() -> void:
	if blackout_sfx != null:
		return
	var path := "res://resources/Grito.mp3"
	if ResourceLoader.exists(path):
		blackout_sfx = load(path)


func _ensure_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("DistortedMusic")
	_lowpass = _ensure_lowpass("DistortedMusic")
	_ensure_voice_buses()


func _ensure_bus(name: String) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, name)


func _ensure_lowpass(bus_name: String) -> AudioEffectLowPassFilter:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return null
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var effect := AudioServer.get_bus_effect(idx, i)
		if effect is AudioEffectLowPassFilter:
			return effect
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = phase2_cutoff_start_hz
	AudioServer.add_bus_effect(idx, lowpass, 0)
	return lowpass


func _ensure_voice_buses() -> void:
	var voices := [
		"Voice_Raposa",
		"Voice_Lobo",
		"Voice_Cervo",
		"Voice_Coelho",
		"Voice_Coruja",
		"Voice_Javali"
	]
	for name in voices:
		_ensure_bus(name)


func _create_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = base_volume_db
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)


func play_phase_1() -> void:
	_phase2_active = false
	_music_player.bus = "Music"
	_music_player.pitch_scale = 1.0
	_music_player.volume_db = base_volume_db
	if _lowpass != null:
		_lowpass.cutoff_hz = phase2_cutoff_start_hz
	if _music_player.stream == null:
		_music_player.stream = phase_music
	if not _music_player.playing:
		_music_player.play()


func transition_to_horror() -> void:
	if _music_player.stream == null:
		_music_player.stream = phase_music
	if not _music_player.playing:
		_music_player.play()
	_phase2_active = true
	_music_player.bus = "DistortedMusic"
	_music_player.pitch_scale = phase2_pitch
	if _lowpass != null:
		_lowpass.cutoff_hz = phase2_cutoff_start_hz
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", base_volume_db - 2.0, 1.0)
	if _lowpass != null:
		tween.tween_property(_lowpass, "cutoff_hz", phase2_cutoff_hz, 2.0)


func play_phase_2() -> void:
	transition_to_horror()


func on_blackout() -> void:
	if blackout_sfx != null:
		_sfx_player.stream = blackout_sfx
		_sfx_player.play()
	# Corte abrupto breve na musica
	if _music_player != null and _music_player.playing:
		var prev := _music_player.volume_db
		_music_player.volume_db = -80.0
		await get_tree().create_timer(0.2).timeout
		_music_player.volume_db = prev


func _on_music_finished() -> void:
	if _music_player == null:
		return
	# Garante loop mesmo para streams sem loop habilitado
	_music_player.play()


func set_horror_intensity(intensity: float) -> void:
	if not _phase2_active:
		return
	var t: float = clamp(float(intensity), 0.0, 1.0)
	if _intensity_tween != null and _intensity_tween.is_running():
		_intensity_tween.kill()
	_intensity_tween = create_tween()
	_intensity_tween.tween_property(_music_player, "volume_db", lerp(base_volume_db - 2.0, base_volume_db + 2.0, t), 0.2)
	_intensity_tween.tween_property(_music_player, "pitch_scale", lerp(phase2_pitch, phase2_pitch + 0.1, t), 0.2)
	if _lowpass != null:
		_intensity_tween.tween_property(_lowpass, "cutoff_hz", lerp(phase2_cutoff_hz, 700.0, t), 0.2)


func get_voice_bus(personality: String) -> String:
	return "Voice_%s" % personality.capitalize()
