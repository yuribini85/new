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
		})
	return {
		"versao": VERSAO,
		"saldo": jogador.economia.saldo,
		"proximo_uid": jogador.garagem.proximo_uid,
		"carros": carros,
		"licencas": jogador.licencas,
		"graus_licenca": jogador.graus_licenca,
		"usados_vendidos": jogador.usados_vendidos,
		"vitorias": jogador.vitorias,
		"dias": jogador.dias,
		"fila": jogador.fila,
		"ultimo_processamento": jogador.ultimo_processamento,
		"contador_sementes": jogador.contador_sementes,
	}


## Recria o estado em `jogador` (que já deve ter passado por novo_jogo()).
## Retorna "" ou o motivo de não conseguir carregar.
static func desserializar(s: Dictionary, jogador: Node, dados: Node) -> String:
	if int(s.get("versao", 0)) != VERSAO:
		return "versão de save %s não suportada" % s.get("versao")
	jogador.economia.saldo = int(s["saldo"])
	for cs in s["carros"]:
		var c := Carro.new(dados.carro(cs["id"]))
		c.pecas_possuidas = cs["pecas_possuidas"]
		for peca_id in cs["pecas"]:
			c.instalar(dados.peca(peca_id))
		for pneu_id in cs["pneus"]:
			c.adicionar_pneu(dados.pneu(pneu_id))
		c.uid = int(cs["uid"])
		jogador.garagem.carros[c.uid] = c
	jogador.garagem.proximo_uid = int(s["proximo_uid"])
	jogador.licencas = s["licencas"]
	jogador.graus_licenca = s["graus_licenca"]
	jogador.usados_vendidos = s["usados_vendidos"]
	jogador.vitorias = {}
	for k in s["vitorias"]:
		jogador.vitorias[k] = int(s["vitorias"][k])
	jogador.dias = int(s["dias"])
	jogador.fila = s["fila"]
	if not jogador.fila.is_empty():
		jogador.fila["uid"] = int(jogador.fila["uid"])
		jogador.fila["restantes"] = int(jogador.fila["restantes"])
		jogador.fila["semente"] = int(jogador.fila["semente"])
	jogador.ultimo_processamento = float(s["ultimo_processamento"])
	jogador.contador_sementes = int(s["contador_sementes"])
	return ""
