class_name Save
extends RefCounted
## Converte o estado do jogador em JSON e de volta. Carros guardam só ids;
## os números voltam de data/ no load, então rebalancear não quebra saves.

const VERSAO := 1


static func serializar(jogador: Node) -> Dictionary:
	var carros := []
	for c in jogador.garagem.lista():
		carros.append({
			"id": c.id,
			"uid": c.uid,
			"pecas": c.pecas.values().map(func(p): return p["id"]),
			"pecas_possuidas": c.pecas_possuidas,
			"pneus": c.pneus.map(func(p): return p["id"]),
			"cor": c.cor,
			"ajuste_cambio": c.ajuste_cambio,
			"configuracoes": c.configuracoes,
		})
	return {
		"versao": VERSAO,
		"saldo": jogador.economia.saldo,
		"proximo_uid": jogador.garagem.proximo_uid,
		"carros": carros,
		"licencas": jogador.licencas,
		"graus_licenca": jogador.graus_licenca,
		"montagens": jogador.montagens,
		"desejos": jogador.desejos,
		"usados_vendidos": jogador.usados_vendidos,
		"vitorias": jogador.vitorias,
		"campeonatos": jogador.campeonatos,
		"titulos": jogador.titulos,
		"treinos": jogador.treinos,
		"personagem": jogador.personagem,
		"segundo_piloto": jogador.segundo_piloto,
		"carro_companheiro": jogador.carro_companheiro,
		"flags": jogador.flags,
		"dialogos_vistos": jogador.dialogos_vistos,
		"historico": jogador.historico,
		"dias": jogador.dias,
		"fila": jogador.fila,
		"ultimo_processamento": jogador.ultimo_processamento,
		"contador_sementes": jogador.contador_sementes,
	}


const CHAVES := [
	"versao", "saldo", "proximo_uid", "carros", "licencas", "graus_licenca", "usados_vendidos",
	"vitorias", "dias", "fila", "ultimo_processamento", "contador_sementes",
]


## Confere o save inteiro contra data/ sem mexer em nada. "" se está bom.
static func validar(s: Variant, dados: Node) -> String:
	if not s is Dictionary:
		return "save ilegível"
	for chave in CHAVES:
		if not s.has(chave):
			return "save sem o campo %s" % chave
	if typeof(s["versao"]) != TYPE_FLOAT or int(s["versao"]) != VERSAO:
		return "versão de save %s não suportada (esperada %d)" % [s["versao"], VERSAO]
	if not s["carros"] is Array or not s["fila"] is Dictionary:
		return "save com estrutura inválida"
	var uids := []
	for cs in s["carros"]:
		if not cs is Dictionary or not cs.has_all(["id", "uid", "pecas", "pecas_possuidas", "pneus"]):
			return "carro do save com estrutura inválida"
		if not dados.existe("carros", cs["id"]):
			return "carro %s não existe mais em data/" % cs["id"]
		for peca_id in cs["pecas"]:
			if not dados.existe("pecas", peca_id):
				return "peça %s não existe mais em data/" % peca_id
		for pneu_id in cs["pneus"]:
			if not dados.existe("pneus", pneu_id):
				return "pneu %s não existe mais em data/" % pneu_id
		uids.append(int(cs["uid"]))
	var f: Dictionary = s["fila"]
	if not f.is_empty():
		if not f.has_all(["evento_id", "uid", "restantes", "inicio", "semente"]):
			return "fila do save com estrutura inválida"
		if not dados.existe("eventos", f["evento_id"]) or not int(f["uid"]) in uids:
			return "fila do save aponta para evento ou carro inexistente"
		if f.get("config") is Dictionary:
			for peca_id in f["config"].get("pecas", []):
				if not dados.existe("pecas", peca_id):
					return "peça %s não existe mais em data/" % peca_id
			for pneu_id in f["config"].get("pneus", []):
				if not dados.existe("pneus", pneu_id):
					return "pneu %s não existe mais em data/" % pneu_id
	return ""


## Recria o estado em `jogador` (que já deve ter passado por novo_jogo()).
## Retorna "" ou o motivo de não conseguir carregar; com erro, nada é alterado.
static func desserializar(s: Variant, jogador: Node, dados: Node) -> String:
	var erro := validar(s, dados)
	if erro != "":
		return erro
	jogador.economia.saldo = int(s["saldo"])
	for cs in s["carros"]:
		var c := Carro.new(dados.carro(cs["id"]))
		c.pecas_possuidas = cs["pecas_possuidas"]
		c.cor = String(cs.get("cor", ""))  # opcional: saves antigos sem pintura
		c.ajuste_cambio = String(cs.get("ajuste_cambio", ""))
		# Opcional: configurações salvas; peça que saiu de data/ some da configuração.
		if cs.get("configuracoes") is Array:
			for cfg in cs["configuracoes"]:
				if cfg is Dictionary:
					c.configuracoes.append({"nome": String(cfg.get("nome", "")),
							"pecas": Array(cfg.get("pecas", [])).filter(func(x): return dados.existe("pecas", x)),
							"ajuste_cambio": String(cfg.get("ajuste_cambio", ""))})
		for peca_id in cs["pecas"]:
			c.instalar(dados.peca(peca_id))
		for pneu_id in cs["pneus"]:
			c.adicionar_pneu(dados.pneu(pneu_id))
		c.uid = int(cs["uid"])
		jogador.garagem.carros[c.uid] = c
	jogador.garagem.proximo_uid = int(s["proximo_uid"])
	# Saves anteriores à decisão 33 têm os ids do GT2 (B, A, IC...): migram.
	jogador.licencas = []
	for x in s["licencas"]:
		jogador.licencas.append(String(x) if dados.existe("licencas", x) else Licencas.id_novo(String(x)))
	jogador.graus_licenca = {}
	var testes := {}
	for lic in dados.lista("licencas"):
		for t in lic["testes"]:
			testes[t["id"]] = true
	for k in s["graus_licenca"]:
		var novo := Licencas.teste_novo(String(k))
		jogador.graus_licenca[novo if not testes.has(k) and testes.has(novo) else String(k)] = s["graus_licenca"][k]
	# Opcional: montagens dos contratos (saves anteriores aos contratos não têm).
	jogador.montagens = {}
	if s.get("montagens") is Dictionary:
		for k in s["montagens"]:
			var m = s["montagens"][k]
			if m is Dictionary and dados.existe("contratos", k):
				jogador.montagens[k] = {"pecas": Array(m.get("pecas", [])).filter(func(x): return dados.existe("pecas", x)),
						"ajuste_cambio": String(m.get("ajuste_cambio", ""))}
	jogador.usados_vendidos = s["usados_vendidos"]
	# Opcional: lista de desejos (modelos que saíram de data/ somem).
	jogador.desejos = Array(s.get("desejos", [])).filter(func(x): return dados.existe("carros", x)) \
			if s.get("desejos") is Array else []
	jogador.vitorias = {}
	for k in s["vitorias"]:
		jogador.vitorias[k] = int(s["vitorias"][k])
	# Opcional: saves anteriores ao histórico carregam sem ele.
	jogador.historico = {}
	if s.get("historico") is Dictionary:
		for k in s["historico"]:
			var h: Dictionary = s["historico"][k]
			jogador.historico[k] = {
				"corridas": int(h.get("corridas", 0)), "melhor_pos": int(h.get("melhor_pos", 0)),
				"melhor_tempo": float(h.get("melhor_tempo", 0.0)), "ultima_pos": int(h.get("ultima_pos", 0)),
				"ultimo_tempo": float(h.get("ultimo_tempo", 0.0)),
			}
	# Opcional: saves anteriores aos campeonatos (decisão 35) carregam sem eles.
	jogador.campeonatos = {}
	if s.get("campeonatos") is Dictionary:
		for k in s["campeonatos"]:
			var c = s["campeonatos"][k]
			if c is Dictionary and c.get("pontos") is Dictionary:
				var pts := {}
				for q in c["pontos"]:
					pts[q] = int(c["pontos"][q])
				jogador.campeonatos[Campeonatos.RENOMEADAS.get(k, k)] = {"etapa": int(c.get("etapa", 0)), "pontos": pts}
	jogador.personagem = String(s.get("personagem", ""))
	jogador.segundo_piloto = String(s.get("segundo_piloto", ""))
	jogador.carro_companheiro = int(s.get("carro_companheiro", -1))
	jogador.flags = s["flags"].duplicate() if s.get("flags") is Dictionary else {}
	jogador.dialogos_vistos = s["dialogos_vistos"].duplicate() if s.get("dialogos_vistos") is Dictionary else {}
	jogador.treinos = {}
	if s.get("treinos") is Dictionary:
		for k in s["treinos"]:
			jogador.treinos[Licencas.id_novo(k)] = float(s["treinos"][k])
	jogador.titulos = {}
	if s.get("titulos") is Dictionary:
		for k in s["titulos"]:
			jogador.titulos[Campeonatos.RENOMEADAS.get(k, k)] = int(s["titulos"][k])
	jogador.dias = int(s["dias"])
	jogador.fila = s["fila"]
	if not jogador.fila.is_empty():
		jogador.fila["uid"] = int(jogador.fila["uid"])
		jogador.fila["restantes"] = int(jogador.fila["restantes"])
		jogador.fila["semente"] = int(jogador.fila["semente"])
		if jogador.fila.get("companheiro") is Dictionary:
			jogador.fila["companheiro"]["uid"] = int(jogador.fila["companheiro"]["uid"])
		if jogador.fila.get("posicoes") is Array:
			jogador.fila["posicoes"] = jogador.fila["posicoes"].map(func(x): return int(x))
	jogador.ultimo_processamento = float(s["ultimo_processamento"])
	jogador.contador_sementes = int(s["contador_sementes"])
	return ""
