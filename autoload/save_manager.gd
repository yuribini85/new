extends Node
## Grava e lê user://save.json. Carrega ao abrir, processa a fila offline e
## grava ao ir para segundo plano ou fechar. O relatório fica em
## `relatorio_offline` para a tela de boas-vindas mostrar.

const CAMINHO_PADRAO := "user://save.json"
## Com --dados=<outra pasta>, o save fica separado para não misturar com o real.
var caminho := CAMINHO_PADRAO

var relatorio_offline: Dictionary = {}


func _ready() -> void:
	var dados := get_node("/root/Dados")
	if dados.pasta != dados.DATA_DIR:
		caminho = "user://save_%s.json" % dados.pasta.trim_suffix("/").get_file()
	var jogador := get_node("/root/Jogador")
	if jogador.economia == null:
		return  # dados pendentes
	if FileAccess.file_exists(caminho):
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
	var f := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: não consegui gravar")
		return
	f.store_string(JSON.stringify(Save.serializar(jogador)))
	f.close()
	# Grava em temporário e renomeia: um corte no meio não corrompe o save.
	DirAccess.rename_absolute(caminho + ".tmp", caminho)


func carregar() -> String:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not parsed is Dictionary:
		return "save corrompido"
	return Save.desserializar(parsed, get_node("/root/Jogador"), get_node("/root/Dados"))
