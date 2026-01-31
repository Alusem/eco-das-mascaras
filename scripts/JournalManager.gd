extends Node

var registros: Array[String] = []


func adicionar_registro(texto: String) -> void:
	var registro := texto.strip_edges()
	if registro == "":
		return
	if registros.has(registro):
		return
	registros.append(registro)
	print("[Journal] ", registro)
