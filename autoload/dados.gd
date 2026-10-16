extends Node
## Carrega o balanceamento de res://data/*.json uma vez, em memória, e confere
## o formato. É o único ponto de leitura desses arquivos.
## CLAUDE.md: nenhum número é inventado — o que falta aparece em pendencias().

const DATA_DIR := "res://data/"
const CarroScript := preload("res://data_model/carro.gd")
const PistaScript := preload("res://data_model/pista.gd")
const ElegibilidadeScript := preload("res://data_model/elegibilidade.gd")
const LicencasScript := preload("res://data_model/licencas.gd")
const SimulacaoScript := preload("res://sim/simulacao.gd")

## Tolerância para o traçado fechar (técnica, não é balanceamento).
const FECHAMENTO_MAX_M := 1.0

## arquivo -> campos obrigatórios de cada item da lista.
const ESQUEMAS := {
	"fabricantes": ["id", "nome", "escola"],
	"carros": [
		"id", "nome", "fabricante", "arquetipo_ref", "categoria", "tracao",
		"potencia", "peso", "aderencia", "freio", "preco", "ano",
	],
	"pecas": ["id", "nome", "categoria", "efeitos", "preco"],
	"pneus": ["id", "nome", "aderencia", "preco"],
	"pistas": ["id", "funcao", "trechos"],
	"pilotos_ia": ["id", "ritmo", "consistencia", "agressividade"],
	"eventos": ["id", "nome", "pista", "voltas", "condicao", "restricoes", "adversarios", "premios"],
	"licencas": ["id", "nome", "testes"],
	"contratos": ["id", "licenca", "nome", "carro", "provas", "condicoes"],
	"equipes": ["id", "nome", "pilotos"],
	"personagens": ["id", "nome"],
	"dialogos": ["id", "trigger", "falas"],
}

## arquivo -> chaves obrigatórias do objeto.
const OBJETOS := {
	"simulacao": SimulacaoScript.PARAMS,
	"economia": ["saldo_inicial", "fracao_revenda", "pneu_de_fabrica"],
	"carreira": ["piloto_jogador", "teto_offline_s"],
	"historia": ["dono"],
}

var _listas: Dictionary = {}  # arquivo -> {id -> item}
var _objetos: Dictionary = {}  # arquivo -> objeto
var _pendencias: Array = []
var _erros: Array = []


## Pasta efetivamente carregada. `--dados=<pasta>` depois de `--` na linha de
## comando troca a pasta (ex.: res://tests/fixtures/ para ver as telas antes
## do balanceamento existir). Nunca usar em build.
var pasta := DATA_DIR


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dados="):
			pasta = arg.trim_prefix("--dados=")
			push_warning("Dados: usando %s em vez de %s" % [pasta, DATA_DIR])
	carregar(pasta)
	for e in _erros:
		push_error("Dados: " + e)
	for p in _pendencias:
		push_warning("Dados pendente: " + p)


func carregar(dir: String) -> void:
	pasta = dir  # os arquivos lidos sob demanda (curvas, frota, monetização) vêm da mesma pasta
	_listas.clear()
	_pendencias.clear()
	_erros.clear()
	_objetos.erase("curvas")  # lido sob demanda (curvas())
	_objetos.erase("monetizacao")  # idem (monetizacao())
	_objetos.erase("carros_removidos")  # idem (substituto())
	_objetos.erase("workshops")  # idem (workshops())
	_objetos.erase("garagem")  # idem (garagem())
	_objetos.erase("equipe")  # idem (equipe())
	_objetos.erase("patrocinadores")  # idem (patrocinadores())
	_objetos.erase("grid_desafios")  # idem (grid_desafios())
	for arquivo in ESQUEMAS:
		_listas[arquivo] = {}
		var lista = _ler_json(dir + arquivo + ".json")
		if arquivo == "pecas" and lista is Dictionary:
			lista = _expandir_pecas(lista)
		if not lista is Array:
			_erros.append("%s.json deve ser uma lista" % arquivo)
			continue
		if lista.is_empty():
			_pendencias.append("%s.json vazio" % arquivo)
		for item in lista:
			_validar_item(arquivo, item)
			_listas[arquivo][str(item.get("id"))] = item
	_gerar_blindagem(dir)
	for arquivo in OBJETOS:
		_objetos[arquivo] = {}
		var obj = _ler_json(dir + arquivo + ".json")
		if not obj is Dictionary:
			_erros.append("%s.json deve ser um objeto" % arquivo)
			continue
		_objetos[arquivo] = obj
		for chave in OBJETOS[arquivo]:
			if not obj.has(chave):
				_erros.append("%s.json sem chave %s" % [arquivo, chave])
			elif obj[chave] == null:
				_pendencias.append("%s.json: %s" % [arquivo, chave])
	_validar_referencias()


## data/pecas.json vem agrupado por carro (tools/importar_gt2.py →
## pecas_compactas: um terço do tamanho); aqui volta à lista de sempre: id =
## <carro>_<s>, nome pela tabela `nomes`, categoria omitida = o s sem o último
## _trecho, carros permitidos = só o carro.
static func _expandir_pecas(obj: Dictionary) -> Array:
	var nomes: Dictionary = obj.get("nomes", {})
	var lista := []
	var carros: Dictionary = obj.get("carros", {})
	for carro in carros:
		for q: Dictionary in carros[carro]:
			var sufixo := String(q["s"])
			var p := {"id": "%s_%s" % [carro, sufixo], "nome": q.get("nome", nomes.get(sufixo, sufixo)),
					"categoria": q.get("categoria", sufixo.rsplit("_", true, 1)[0]), "carros_permitidos": [carro]}
			for k in q:
				if k != "s" and k != "nome" and k != "categoria":
					p[k] = q[k]
			lista.append(p)
	return lista


## Blindagem (Blindagem): peças derivadas da redução de peso de cada carro,
## pela regra de data/arena.json → blindagem. Sem a regra, nenhuma.
func _gerar_blindagem(dir: String) -> void:
	var caminho := dir + "arena.json"
	if not FileAccess.file_exists(caminho):
		return
	var a = _ler_json(caminho)
	if not a is Dictionary or not a.get("blindagem") is Dictionary:
		return
	for p in Blindagem.gerar(_listas["pecas"].values(), _listas["carros"].values(), a["blindagem"]):
		_listas["pecas"][p["id"]] = p


func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		_erros.append("arquivo ausente: " + caminho)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if parsed == null:
		_erros.append("%s não é JSON válido" % caminho)
	return parsed


func _validar_item(arquivo: String, item: Variant) -> void:
	if not item is Dictionary:
		_erros.append("%s.json: item não é objeto" % arquivo)
		return
	for campo in ESQUEMAS[arquivo]:
		if not item.has(campo):
			_erros.append("%s.json: '%s' sem campo %s" % [arquivo, item.get("id"), campo])
		elif item[campo] == null:
			_pendencias.append("%s.json: '%s'.%s" % [arquivo, item.get("id"), campo])
	if arquivo == "pistas" and item.has("trechos"):
		var erros_pista := PistaScript.validar(item)
		for e in erros_pista:
			_erros.append("pistas.json: '%s' %s" % [item.get("id"), e])
		if erros_pista.is_empty():
			var p = PistaScript.new(item)
			if p.erro_fechamento() > FECHAMENTO_MAX_M or p.erro_rumo() > 0.01:
				_erros.append("pistas.json: '%s' não fecha (%.2f m, %.1f°) — use tools/editor_pista.tscn" % [
					item.get("id"), p.erro_fechamento(), rad_to_deg(p.erro_rumo())])


## Ids citados em um arquivo precisam existir no arquivo de destino.
func _validar_referencias() -> void:
	for c in _listas["carros"].values():
		if c.get("fabricante") != null and not _listas["fabricantes"].has(str(c["fabricante"])):
			_erros.append("carros.json: '%s' cita fabricante inexistente %s" % [c["id"], c["fabricante"]])
		if c.get("tracao") != null and not c["tracao"] in CarroScript.TRACOES:
			_erros.append("carros.json: '%s' tração inválida %s" % [c["id"], c["tracao"]])
		for janela in c.get("usados", []):
			if not janela is Array or janela.size() != 3 or janela[0] > janela[1] or janela[2] <= 0:
				_erros.append("carros.json: '%s' usados deve ser [[dia_inicio, dia_fim, preco], ...]" % c["id"])
	for p in _listas["pecas"].values():
		for e in p.get("efeitos", []):
			if not e.get("atributo") in CarroScript.ATRIBUTOS or not e.get("op") in CarroScript.OPS:
				_erros.append("pecas.json: '%s' efeito inválido %s" % [p["id"], e])
	_exigir("economia.json: pneu_de_fabrica", "pneus", _objetos.get("economia", {}).get("pneu_de_fabrica"))
	_exigir("carreira.json: piloto_jogador", "pilotos_ia", _objetos.get("carreira", {}).get("piloto_jogador"))
	for ev in _listas["eventos"].values():
		var onde := "eventos.json: '%s'" % ev["id"]
		_exigir(onde + " pista", "pistas", ev.get("pista"))
		_exigir(onde + " carro_premio", "carros", ev.get("carro_premio"))
		if ev.get("condicao") != null and not ev["condicao"] in ["seco", "chuva"]:
			_erros.append(onde + " condição inválida %s" % ev["condicao"])
		_validar_restricoes(onde, ev.get("restricoes", {}))
		for carro_id in ev.get("restricoes", {}).get("carros", []):
			_exigir(onde + " restrição carros", "carros", carro_id)
		for adv in ev.get("adversarios", []):
			_exigir(onde + " adversário carro", "carros", adv.get("carro"))
			_exigir(onde + " adversário piloto", "pilotos_ia", adv.get("piloto"))
			for peca_id in adv.get("pecas", []):
				_exigir(onde + " adversário peça", "pecas", peca_id)
			for pneu_id in adv.get("pneus", []):
				_exigir(onde + " adversário pneu", "pneus", pneu_id)

	for lic in _listas["licencas"].values():
		var onde := "licencas.json: '%s'" % lic["id"]
		_exigir(onde + " requisito", "licencas", lic.get("requisito"))
		_validar_restricoes(onde, {})
		for t in lic.get("testes", []):
			_exigir(onde + " teste pista", "pistas", t.get("pista"))
			_validar_restricoes(onde, t.get("restricoes", {}))
			for campo in ["id", "voltas", "condicao", "tempos"]:
				if not t.has(campo):
					_erros.append("%s teste sem %s" % [onde, campo])
			var tempos = t.get("tempos", {})
			for g in LicencasScript.GRAUS:
				if tempos is Dictionary and not tempos.has(g):
					_erros.append("%s teste '%s' sem tempo de %s" % [onde, t.get("id"), g])
				elif tempos is Dictionary and tempos[g] == null:
					_pendencias.append("%s teste '%s' tempo de %s" % [onde, t.get("id"), g])


	_validar_equipes()
	for c in _listas["dialogos"].values():
		var onde := "dialogos.json: '%s'" % c["id"]
		_exigir(onde + " próxima", "dialogos", c.get("proxima"))
		for f in c["falas"]:
			if f.has("quem"):
				_exigir(onde + " fala", "personagens", f["quem"])
			elif not f.has("acao"):
				_erros.append(onde + " fala sem quem nem ação")

	for ct in _listas["contratos"].values():
		var onde := "contratos.json: '%s'" % ct["id"]
		_exigir(onde + " licença", "licencas", ct.get("licenca"))
		_exigir(onde + " carro", "carros", ct.get("carro"))
		for pid in ct.get("pecas_escola", []):
			_exigir(onde + " peça da escola", "pecas", pid)
		for prova in ct.get("provas", []):
			_exigir(onde + " pista", "pistas", prova.get("pista"))
			if not prova.has("voltas") or prova.get("rivais", []).is_empty():
				_erros.append(onde + " prova sem voltas ou sem rivais")
			for rv in prova.get("rivais", []):
				_exigir(onde + " rival", "carros", rv.get("carro"))
				for pid in rv.get("pecas", []):
					_exigir(onde + " peça do rival", "pecas", pid)
		var cond = ct.get("condicoes", {})
		if cond is Dictionary and not cond.has("bronze"):
			_erros.append(onde + " sem condições de bronze")


func _validar_equipes() -> void:
	var niveis: Array = _objetos.get("carreira", {}).get("niveis", [])
	for eq in _listas["equipes"].values():
		var onde := "equipes.json: '%s'" % eq["id"]
		if eq.has("nivel") and not eq["nivel"] in niveis:
			_erros.append("%s nível desconhecido %s" % [onde, eq["nivel"]])
		# A equipe do jogador não tem pilotos fixos (são os contratados).
		if (eq["pilotos"].is_empty() and not eq.get("jogador", false)) \
				or not eq["pilotos"].all(func(p): return p.has("id") and p.has("nome")):
			_erros.append(onde + " precisa de pilotos com id e nome")


func _validar_restricoes(onde: String, restricoes: Dictionary) -> void:
	for chave in restricoes:
		if not chave in ElegibilidadeScript.RESTRICOES:
			_erros.append(onde + " restrição desconhecida %s" % chave)


## Erro se `id` (quando preenchido) não existe em `arquivo`.
func _exigir(onde: String, arquivo: String, id: Variant) -> void:
	if id != null and not _listas[arquivo].has(str(id)):
		_erros.append("%s cita %s inexistente em %s.json" % [onde, id, arquivo])


## Valores que ainda precisam vir do estudo do GT2 ou de playtest.
func pendencias() -> Array:
	return _pendencias


## Problemas de formato. Devem ser corrigidos no JSON, não no código.
func erros() -> Array:
	return _erros


func lista(arquivo: String) -> Array:
	return _listas[arquivo].values()


func existe(arquivo: String, id: Variant) -> bool:
	return _listas.has(arquivo) and _listas[arquivo].has(str(id))


func item(arquivo: String, id: String) -> Dictionary:
	if not _listas[arquivo].has(id):
		push_error("Dados: '%s' não existe em %s.json" % [id, arquivo])
		return {}
	return _listas[arquivo][id]


func carro(id: String) -> Dictionary:
	return item("carros", id)


func peca(id: String) -> Dictionary:
	return item("pecas", id)


func pneu(id: String) -> Dictionary:
	return item("pneus", id)


func piloto(id: String) -> Dictionary:
	return item("pilotos_ia", id)


func pista(id: String) -> Pista:
	return PistaScript.new(item("pistas", id))


func simulacao() -> Dictionary:
	return _objetos["simulacao"]


func economia() -> Dictionary:
	return _objetos["economia"]


func carreira() -> Dictionary:
	return _objetos["carreira"]


func historia() -> Dictionary:
	return _objetos.get("historia", {})


## Nomes das curvas de cada pista, na ordem da volta (curvas.json, opcional:
## sem o arquivo ou sem a pista, a vista tática diz "Curva N").
func curvas(pista_id: String) -> Array:
	if not _objetos.has("curvas"):
		var c = _ler_json(pasta + "curvas.json") if FileAccess.file_exists(pasta + "curvas.json") else {}
		_objetos["curvas"] = c if c is Dictionary else {}
	return _objetos["curvas"].get(pista_id, [])


## Arena de destruição (decisões 49-50, arena.json, opcional). Sem o arquivo
## ou com chave faltando, {} (a arena não abre).
func arena() -> Dictionary:
	if not _objetos.has("arena"):
		var caminho := pasta + "arena.json"
		var a = _ler_json(caminho) if FileAccess.file_exists(caminho) else {}
		var ok: bool = a is Dictionary and Arena.PARAMS.all(func(k): return a.has(k))
		_objetos["arena"] = a if ok else {}
	return _objetos["arena"]


## Gestão da equipe do jogador (equipe.json, opcional): patrocínio, desmanche
## e sede. Sem o arquivo, {} (nada disso aparece).
func equipe() -> Dictionary:
	if not _objetos.has("equipe"):
		var caminho := pasta + "equipe.json"
		var e = _ler_json(caminho) if FileAccess.file_exists(caminho) else {}
		_objetos["equipe"] = e if e is Dictionary and e.has("patrocinio") else {}
	return _objetos["equipe"]


## Patrocinadores (patrocinadores.json, opcional): [{id, nome, ramo, licenca,
## condicao: {tipo, valor?}}]. Sem o arquivo, [].
func patrocinadores() -> Array:
	if not _objetos.has("patrocinadores"):
		var caminho := pasta + "patrocinadores.json"
		var l = _ler_json(caminho) if FileAccess.file_exists(caminho) else []
		_objetos["patrocinadores"] = {"lista": l if l is Array else []}
	return _objetos["patrocinadores"]["lista"]


## Vagas da garagem (decisão 43, garagem.json, opcional). Sem o arquivo, {}
## (garagem sem limite).
func garagem() -> Dictionary:
	if not _objetos.has("garagem"):
		var caminho := pasta + "garagem.json"
		var g = _ler_json(caminho) if FileAccess.file_exists(caminho) else {}
		_objetos["garagem"] = g if g is Dictionary else {}
	return _objetos["garagem"]


## Workshops das Lojas (decisão 42, workshops.json, opcional): [{id, nome,
## logo, fabricantes}]. Sem o arquivo, [] (a tela faz uma por fabricante).
func workshops() -> Array:
	if not _objetos.has("workshops"):
		var caminho := pasta + "workshops.json"
		var w = _ler_json(caminho) if FileAccess.file_exists(caminho) else []
		_objetos["workshops"] = w if w is Array else []
	return _objetos["workshops"]


## Carro que saiu da frota (decisão 40, carros_removidos.json, gerado pelo
## importador): o id que ficou no lugar dele; "" se o carro não saiu.
func substituto(id: String) -> String:
	if not _objetos.has("carros_removidos"):
		var caminho := pasta + "carros_removidos.json"
		var m = _ler_json(caminho) if FileAccess.file_exists(caminho) else {}
		_objetos["carros_removidos"] = m if m is Dictionary else {}
	return String(_objetos["carros_removidos"].get(id, ""))


## Monetização (decisão 39, monetizacao.json, opcional): {aceleracao: {fator,
## duracao_s, teto_s}}. Sem o arquivo, a aceleração não aparece.
func monetizacao() -> Dictionary:
	if not _objetos.has("monetizacao"):
		var m = _ler_json(pasta + "monetizacao.json") if FileAccess.file_exists(pasta + "monetizacao.json") else {}
		_objetos["monetizacao"] = m if m is Dictionary else {}
	return _objetos["monetizacao"]


func evento(id: String) -> Dictionary:
	# Desafio do The Grid (decisão 74): prova montada dos dados do Grid.
	if id.begins_with(GridDesafio.PREFIXO):
		return GridDesafio.evento(self, id.trim_prefix(GridDesafio.PREFIXO))
	return item("eventos", id)


## Desafios do The Grid (decisão 74, grid_desafios.json, opcional).
func grid_desafios() -> Dictionary:
	if not _objetos.has("grid_desafios"):
		var caminho := pasta + "grid_desafios.json"
		var g = _ler_json(caminho) if FileAccess.file_exists(caminho) else {}
		_objetos["grid_desafios"] = g if g is Dictionary else {}
	return _objetos["grid_desafios"]
