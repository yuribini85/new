extends Node
## Grava e lê user://save.json. Carrega ao abrir, processa a fila offline e
## grava ao ir para segundo plano ou fechar. O relatório fica em
## `relatorio_offline` para a tela de boas-vindas mostrar.

const CAMINHO := "user://save.json"

var relatorio_offline: Dictionary = {}


func _ready() -> void:
	var jogador := get_node("/root/Jogador")
	if jogador.economia == null:
		return  # dados pendentes
	if FileAccess.file_exists(CAMINHO):
		var erro := carregar()
		if erro != "":
			push_error("SaveManager: " + erro)
	if jogador.fila_ctrl != null:
		relatorio_offline = jogador.fila_ctrl.processar(Time.get_unix_time_from_system())
		salvar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		salvar()


func salvar() -> void:
	var jogador := get_node("/root/Jogador")
	if jogador.economia == null:
		return
	var f := FileAccess.open(CAMINHO + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: não consegui gravar")
		return
	f.store_string(JSON.stringify(Save.serializar(jogador)))
	f.close()
	# Grava em temporário e renomeia: um corte no meio não corrompe o save.
	DirAccess.rename_absolute(CAMINHO + ".tmp", CAMINHO)


func carregar() -> String:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not parsed is Dictionary:
		return "save corrompido"
	return Save.desserializar(parsed, get_node("/root/Jogador"), get_node("/root/Dados"))
