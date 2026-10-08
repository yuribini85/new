extends Node
## Grava e lê user://save.json. Carrega ao abrir, processa a fila offline e
## grava ao ir para segundo plano ou fechar. O relatório fica em
## `relatorio_offline` para a tela de boas-vindas mostrar.
##
## Proteção: cada gravação guarda o save anterior em .bak. Se o save não
## carrega (corrompido, versão antiga, dado que sumiu de data/), tenta o .bak;
## se nenhum serve, os dois são renomeados para .erro-<hora> (nunca
## sobrescritos), o jogo começa do zero e `aviso` explica o que houve.

const CAMINHO_PADRAO := "user://save.json"
## Com --dados=<outra pasta>, o save fica separado para não misturar com o real.
var caminho := CAMINHO_PADRAO

var relatorio_offline: Dictionary = {}
## Mensagem para o jogador quando o save não pôde ser usado ("" se tudo bem).
var aviso := ""


func _ready() -> void:
	var dados := get_node("/root/Dados")
	if dados.pasta != dados.DATA_DIR:
		caminho = "user://save_%s.json" % dados.pasta.trim_suffix("/").get_file()
	var jogador := get_node("/root/Jogador")
	if jogador.economia == null:
		return  # dados pendentes
	var r := carregar_protegido(caminho, jogador, dados)
	aviso = r["aviso"]
	if not r["carregou"] and not dados.historia().is_empty():
		# Jogo novo: começa pelo prólogo do Adrian (decisão 32).
		var erro := Prologo.iniciar(dados, jogador)
		if erro != "":
			push_warning("SaveManager: " + erro)
	if r["aviso"] != "":
		push_warning("SaveManager: " + r["aviso"])
	if jogador.fila_ctrl != null and r["carregou"]:
		relatorio_offline = jogador.fila_ctrl.processar(Time.get_unix_time_from_system())
		salvar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		salvar()


func salvar() -> void:
	var jogador := get_node("/root/Jogador")
	if jogador.economia != null:
		gravar(caminho, Save.serializar(jogador))


## Grava em temporário e renomeia (um corte no meio não corrompe o save);
## o save anterior vira .bak.
static func gravar(arquivo: String, estado: Dictionary) -> bool:
	var f := FileAccess.open(arquivo + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: não consegui gravar " + arquivo)
		return false
	f.store_string(JSON.stringify(estado))
	f.close()
	if FileAccess.file_exists(arquivo):
		DirAccess.remove_absolute(arquivo + ".bak")
		DirAccess.rename_absolute(arquivo, arquivo + ".bak")
	return DirAccess.rename_absolute(arquivo + ".tmp", arquivo) == OK


## Retorna {"carregou": bool, "origem": "save"|"bak"|"", "aviso": String}.
## Sem arquivo nenhum: jogo novo, sem aviso.
static func carregar_protegido(arquivo: String, jogador: Node, dados: Node) -> Dictionary:
	var erros := []
	for origem in ["save", "bak"]:
		var p: String = arquivo if origem == "save" else arquivo + ".bak"
		if not FileAccess.file_exists(p):
			continue
		var json := JSON.new()
		var lido: Variant = json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null
		var erro := Save.desserializar(lido, jogador, dados)
		if erro == "":
			var aviso := ""
			if origem == "bak":
				aviso = "O save principal não abriu (%s). Recuperado o anterior." % erros[0]
				_guardar_com_erro(arquivo)
			return {"carregou": true, "origem": origem, "aviso": aviso}
		erros.append(erro)
	if erros.is_empty():
		return {"carregou": false, "origem": "", "aviso": ""}
	var copia := _guardar_com_erro(arquivo)
	_guardar_com_erro(arquivo + ".bak")
	return {"carregou": false, "origem": "",
		"aviso": "Não foi possível abrir o save (%s). Ele foi guardado em %s e um jogo novo começou." % [erros[0], copia]}


## Renomeia o arquivo para <nome>.erro-<hora>, para nunca ser sobrescrito.
static func _guardar_com_erro(p: String) -> String:
	if not FileAccess.file_exists(p):
		return ""
	var destino := "%s.erro-%d" % [p, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(p, destino)
	return destino
