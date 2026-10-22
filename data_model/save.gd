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
			"faixas": c.faixas,
			"apelido": c.apelido,
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
		"vitorias": jogador.vitorias,
		"campeonatos": jogador.campeonatos,
		"titulos": jogador.titulos,
		"treinos": jogador.treinos,
		"personagem": jogador.personagem,
		"segundo_piloto": jogador.segundo_piloto,
		"carro_companheiro": jogador.carro_companheiro,
		"escalacao": jogador.escalacao,
		"pilotos": jogador.pilotos,
		"nome_admin": jogador.nome_admin,
		"ultima_loja": jogador.ultima_loja,
		"flags": jogador.flags,
		"dialogos_vistos": jogador.dialogos_vistos,
		"ultima_reativa": jogador.ultima_reativa,
		"derrotas_seguidas": jogador.derrotas_seguidas,
		"arena": jogador.arena,
		"equipe": jogador.equipe,
		"identidade": jogador.identidade,
		"grid": jogador.grid,
		"historico": jogador.historico,
		"caixa": jogador.caixa,
		"recordes_volta": jogador.recordes_volta,
		"dias": jogador.dias,
		"fila": jogador.fila,
		"ultimo_processamento": jogador.ultimo_processamento,
		"aceleracao": jogador.aceleracao,
		"combustivel": jogador.combustivel,
		"meta_dia": jogador.meta_dia,
		"repeticoes": jogador.repeticoes,
		"ampliacoes_garagem": jogador.ampliacoes_garagem,
		"contador_sementes": jogador.contador_sementes,
	}


const CHAVES := [
	"versao", "saldo", "proximo_uid", "carros", "licencas", "graus_licenca",
	"vitorias", "dias", "fila", "ultimo_processamento", "contador_sementes",
]


## Carros que saíram da frota (decisão 40) viram o substituto, com as mesmas
## peças (categoria e estágio) quando o carro novo as tem. Num save que veio de
## JSON, antes de validar.
static func migrar_frota(s: Variant, dados: Node) -> void:
	if not s is Dictionary or not s.get("carros") is Array:
		return
	for cs in s["carros"]:
		if not cs is Dictionary or dados.existe("carros", cs.get("id", "")):
			continue
		var novo: String = dados.substituto(String(cs.get("id", "")))
		if novo == "":
			continue
		var velho := String(cs["id"])
		cs["id"] = novo
		# A mesma peça (categoria e estágio) no carro novo, quando ele tem.
		for chave in ["pecas", "pecas_possuidas"]:
			if cs.get(chave) is Array:
				var lista := []
				for p in cs[chave]:
					var q := String(p)
					if q.begins_with(velho + "_"):
						q = novo + q.trim_prefix(velho)
					if dados.existe("pecas", q) and not q in lista:
						lista.append(q)
				cs[chave] = lista
	if s.get("desejos") is Array:
		var d := []
		for x in s["desejos"]:
			var id: String = String(x) if dados.existe("carros", x) else dados.substituto(String(x))
			if id != "" and not id in d:
				d.append(id)
		s["desejos"] = d
	var f = s.get("fila")
	if f is Dictionary and f.get("config") is Dictionary:
		f["config"]["pecas"] = Array(f["config"].get("pecas", [])).filter(func(p): return dados.existe("pecas", p))


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
		# dados.evento: também as provas montadas (desafio do Grid, "grid_<equipe>").
		if dados.evento(String(f["evento_id"])).is_empty() or not int(f["uid"]) in uids:
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
	migrar_frota(s, dados)
	var erro := validar(s, dados)
	if erro != "":
		return erro
	jogador.economia.saldo = int(s["saldo"])
	for cs in s["carros"]:
		var c := Carro.new(dados.carro(cs["id"]))
		c.pecas_possuidas = cs["pecas_possuidas"]
		c.cor = String(cs.get("cor", ""))  # opcional: saves antigos sem pintura
		c.faixas = cs.get("faixas", {}) if cs.get("faixas") is Dictionary else {}
		c.apelido = String(cs.get("apelido", "")).left(Carro.APELIDO_MAX)  # opcional: saves antigos
		# Saves antigos: ajuste_cambio (agora sempre o equilibrado) e as
		# preparações salvas (configuracoes) ficam de fora.
		for peca_id in cs["pecas"]:
			c.instalar(dados.peca(peca_id))
		for pneu_id in cs["pneus"]:
			c.adicionar_pneu(dados.pneu(pneu_id))
		c.uid = int(cs["uid"])
		jogador.garagem.carros[c.uid] = c
	jogador.garagem.proximo_uid = int(s["proximo_uid"])
	# Saves anteriores à decisão 33 têm os ids antigos (B, A, IC...): migram.
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
	# Montagens dos contratos de licença (removidos, decisão 99): não carregam mais.
	jogador.montagens = {}
	# Usados (removidos, decisão 42): usados_vendidos de saves antigos fica de fora.
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
				"ultimo_tempo": float(h.get("ultimo_tempo", 0.0)), "derrotas": int(h.get("derrotas", 0)),
			}
	# Opcionais (decisão 130): saves anteriores às caixas e aos recordes de volta.
	jogador.caixa = Array(s.get("caixa", [])).map(func(x): return String(x)) if s.get("caixa") is Array else []
	jogador.recordes_volta = {}
	if s.get("recordes_volta") is Dictionary:
		for k in s["recordes_volta"]:
			jogador.recordes_volta[String(k)] = float(s["recordes_volta"][k])
	# Opcional: saves anteriores aos campeonatos (decisão 35) carregam sem eles.
	jogador.campeonatos = {}
	if s.get("campeonatos") is Dictionary:
		for k in s["campeonatos"]:
			var c = s["campeonatos"][k]
			if c is Dictionary and c.get("pontos") is Dictionary:
				var pts := {}
				for q in c["pontos"]:
					pts[q] = int(c["pontos"][q])
				jogador.campeonatos[Campeonatos.migrar_nome(dados, Campeonatos.RENOMEADAS.get(k, k))] = {
						"etapa": int(c.get("etapa", 0)), "pontos": pts}
	jogador.personagem = String(s.get("personagem", ""))
	jogador.segundo_piloto = String(s.get("segundo_piloto", ""))
	jogador.carro_companheiro = int(s.get("carro_companheiro", -1))
	jogador.escalacao = s["escalacao"].duplicate(true) if s.get("escalacao") is Dictionary else {}
	jogador.pilotos = s["pilotos"].duplicate(true) if s.get("pilotos") is Dictionary else {}
	jogador.nome_admin = String(s.get("nome_admin", ""))
	jogador.ultima_loja = String(s.get("ultima_loja", ""))
	jogador.flags = s["flags"].duplicate() if s.get("flags") is Dictionary else {}
	jogador.dialogos_vistos = s["dialogos_vistos"].duplicate() if s.get("dialogos_vistos") is Dictionary else {}
	jogador.ultima_reativa = int(s.get("ultima_reativa", -1000))
	jogador.derrotas_seguidas = int(s.get("derrotas_seguidas", 0))
	jogador.arena = s["arena"].duplicate(true) if s.get("arena") is Dictionary else {}
	jogador.equipe = s["equipe"].duplicate(true) if s.get("equipe") is Dictionary else {}
	jogador.identidade = s["identidade"].duplicate(true) if s.get("identidade") is Dictionary else {}
	jogador.grid = s["grid"].duplicate(true) if s.get("grid") is Dictionary else {}
	# Peças (moeda removida): credito_pecas de saves antigos fica de fora, sem conversão.
	jogador.treinos = {}
	if s.get("treinos") is Dictionary:
		for k in s["treinos"]:
			jogador.treinos[Licencas.id_novo(k)] = float(s["treinos"][k])
	jogador.titulos = {}
	if s.get("titulos") is Dictionary:
		for k in s["titulos"]:
			jogador.titulos[Campeonatos.migrar_nome(dados, Campeonatos.RENOMEADAS.get(k, k))] = int(s["titulos"][k])
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
	jogador.ampliacoes_garagem = int(s.get("ampliacoes_garagem", 0))  # opcional (decisão 43)
	# Opcional: saves anteriores à aceleração (decisão 39) carregam sem ela.
	jogador.aceleracao = {}
	var ac = s.get("aceleracao")
	if ac is Dictionary and ac.has_all(["ganho", "inicio", "fim", "fator"]):
		jogador.aceleracao = {"ganho": float(ac["ganho"]), "inicio": float(ac["inicio"]),
				"fim": float(ac["fim"]), "fator": float(ac["fator"])}
	# Opcionais: saves anteriores ao combustível carregam com o tanque cheio.
	jogador.combustivel = {}
	var cb = s.get("combustivel")
	if cb is Dictionary and cb.has_all(["qtd", "desde"]):
		jogador.combustivel = {"qtd": int(cb["qtd"]), "desde": float(cb["desde"])}
	# Opcional: saves anteriores à meta do dia começam o dia do zero.
	jogador.meta_dia = s.get("meta_dia", {}) if s.get("meta_dia") is Dictionary else {}
	jogador.repeticoes = {}
	var rp = s.get("repeticoes")
	if rp is Dictionary and rp.get("provas") is Dictionary:
		var provas := {}
		for k in rp["provas"]:
			provas[String(k)] = int(rp["provas"][k])
		jogador.repeticoes = {"periodo": int(rp.get("periodo", 0)), "provas": provas}
	jogador.contador_sementes = int(s["contador_sementes"])
	return ""
