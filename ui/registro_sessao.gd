class_name RegistroSessao
extends RefCounted
## Registro local do playtest (docs/playtest_percurso.md, teste de ritmo):
## início e fim de cada sessão, fase, saldo, tempo em cada tela (Corrida =
## acompanhando a corrida), filas programadas, pulos e ausência entre sessões.
## Só grava com o modo de teste ligado (Preferencias.modo_teste). Fica no
## aparelho, em user://registro_playtest.json; nada sai dele.

const CAMINHO := "user://registro_playtest.json"
const NOMES_TELA := ["Garagem", "Mercado", "Oficina", "Competições", "Corrida", "Carreira"]

static var _sessoes: Array = []
static var _carregado := false
static var _aberta := false
static var _tela := -1
static var _tela_desde := 0.0


static func ativo() -> bool:
	return Preferencias.modo_teste != ""


static func sessoes() -> Array:
	_carregar()
	return _sessoes


static func inicio(jogador: Node) -> void:
	if not ativo() or _aberta:
		return
	_carregar()
	var agora := Time.get_unix_time_from_system()
	var anterior: Dictionary = _sessoes.back() if not _sessoes.is_empty() else {}
	_sessoes.append({
		"modo": Preferencias.modo_teste, "inicio": agora, "fim": agora,
		"ausencia_antes_s": agora - float(anterior["fim"]) if not anterior.is_empty() else -1.0,
		"fase_inicio": fase(jogador), "fase_fim": fase(jogador),
		"saldo_inicio": jogador.economia.saldo, "saldo_fim": jogador.economia.saldo,
		"telas": {}, "filas": [], "pulos": 0,
	})
	_aberta = true
	_tela_desde = agora
	_salvar()


static func tela(aba: int) -> void:
	if not _aberta:
		return
	_contar_tela()
	_tela = aba


static func fila(f: Dictionary, duracao_s: float, desafio: bool) -> void:
	if not _aberta:
		return
	_sessoes.back()["filas"].append({"t": Time.get_unix_time_from_system(), "evento": f.get("evento_id", ""),
			"repeticoes": int(f.get("restantes", 1)), "duracao_s": duracao_s, "desafio": desafio})
	_salvar()


static func pulo() -> void:
	if _aberta:
		_sessoes.back()["pulos"] += 1
		_salvar()


## Uma amostra de quadros por segundo por segundo; separa a tela de Corrida.
static func quadros(fps: float, na_corrida: bool) -> void:
	if not _aberta:
		return
	var s: Dictionary = _sessoes.back()
	var chave := "fps_corrida" if na_corrida else "fps_menus"
	var lista: Array = s.get_or_add(chave, [])
	lista.append(int(fps))
	if lista.size() > 600:
		lista.pop_front()


static func fim(jogador: Node) -> void:
	if not _aberta:
		return
	_contar_tela()
	var s: Dictionary = _sessoes.back()
	s["fim"] = Time.get_unix_time_from_system()
	s["fase_fim"] = fase(jogador)
	s["saldo_fim"] = jogador.economia.saldo
	_aberta = false
	_salvar()


static func limpar() -> void:
	_sessoes = []
	_aberta = false
	_salvar()


static func fase(jogador: Node) -> String:
	if "SPORT" in jogador.licencas:
		return "SPORT"
	if "CLUB" in jogador.licencas:
		return "CLUB"
	return "sem licença"


static func _contar_tela() -> void:
	var agora := Time.get_unix_time_from_system()
	if _tela >= 0 and _tela < NOMES_TELA.size():
		var telas: Dictionary = _sessoes.back()["telas"]
		var nome: String = NOMES_TELA[_tela]
		telas[nome] = float(telas.get(nome, 0.0)) + (agora - _tela_desde)
	_tela_desde = agora


static func _carregar() -> void:
	if _carregado:
		return
	_carregado = true
	if FileAccess.file_exists(CAMINHO):
		var lido = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
		if lido is Array:
			_sessoes = lido


static func _salvar() -> void:
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_sessoes, "\t"))
