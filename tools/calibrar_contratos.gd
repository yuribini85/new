extends SceneTree
## Gera data/contratos.json: escolhe carros, rivais e pistas dos contratos da
## licença B e calibra as condições com a própria simulação (bancada de
## Contratos: cada carro sozinho, piloto do jogador, semente fixa do contrato).
## O desenho de cada contrato (o que ele pede) é o da decisão 4; os carros e os
## números saem dos dados por estes critérios (provisórios, a confirmar em
## playtest; ver data/README.md):
##
## Comum: voltas e limite de potência do carro da escola vêm dos testes da
## licença (licencas.json; sem testes, os da anterior). A escola oferece todas as peças do catálogo que
## servem no carro. Busca de montagem: gulosa (a peça que mais ajuda por vez)
## e depois enxuta (tira o que não faz falta) — o jogador pode achar melhor.
##
## "O pequeno contra o gigante": rival com ao menos RAZAO_GIGANTE vezes a
##   potência do carro da escola, que vence o carro de fábrica. Precisa ter
##   solução sem peças de potência (ouro). Escolhe o par de maior razão.
##   bronze: vencer · prata: folga de metade da maior folga encontrada · ouro: vencer sem peças de potência.
## "O último giro": rival que vence o carro de fábrica e só é batido com
##   ao menos 2 peças, ao menor custo C achado (peça de mais ganho por giro
##   primeiro), com C até o saldo inicial. Escolhe o maior C.
##   bronze: vencer gastando até FOLGA_CUSTO_BRONZE × C · prata: até FOLGA_CUSTO_PRATA × C · ouro: até C.
## "Dois circuitos, um carro": duas pistas, um rival diferente em cada, que
##   vence o carro de fábrica ali (do par mais fácil ao mais difícil). A melhor
##   montagem para uma pista sozinha precisa perder na outra, e uma montagem só
##   precisa vencer nas duas com folga de ao menos FOLGA_MINIMA_DUPLA.
##   bronze: vencer as duas · prata: folga de metade da folga da solução · ouro: com as peças da solução enxuta.
## Licenças acima da primeira (--licenca=SPORT, NATIONAL, INTERNATIONAL, PRO ou ELITE): os mesmos três contratos, com
## carros e pistas dos eventos que a licença libera (carro da escola: um rival
## desses eventos dentro do limite da licença; rivais: os desses eventos e os
## da licença seguinte; pistas: as desses eventos). O teto de "O último
## giro" é a soma dos prêmios de 1º lugar dos eventos da licença anterior
## (na primeira, o saldo inicial). Os ids levam o prefixo da licença ("pro_..."; os da antiga IC mantêm "ic_", que os saves já usam).
## Só os contratos da licença pedida são trocados em contratos.json.
## A primeira licença (Club) usa a mesma regra, com o saldo inicial como teto
## de custo; --busca-completa volta à busca antiga entre todos os carros e
## pistas (com a frota inteira passa de três horas).
## Uso: godot --headless --path . --script res://tools/calibrar_contratos.gd [-- --licenca=CLUB] [--so-custo]
## --so-custo: refaz só "O último giro" (o único que depende de preços), com os
## carros já usados pelos contratos atuais da licença; os outros ficam como estão.
## Para quando os preços mudam sem mudar o resto (ex.: a conversão da moeda).
## --manter-par (com --so-custo): mantém o carro, o rival e a pista do contrato
## atual e só refaz a montagem mais barata. Na licença Club a busca completa
## (todos os carros × pistas) passa de duas horas; com os preços mudando todos na
## mesma proporção, o par escolhido não muda (conferido nas outras licenças).

const CAMINHO := "res://data/contratos.json"
const RAZAO_GIGANTE := 1.3
const FOLGA_CUSTO_BRONZE := 1.5
const FOLGA_CUSTO_PRATA := 1.2
## Passo do arredondamento dos tetos de custo: 5 G (~100 Cr do GT2, o passo antigo).
const PASSO_CUSTO := 5
## Folga mínima da solução de "Dois circuitos" (s): a prata precisa ter sentido.
const FOLGA_MINIMA_DUPLA := 0.2
## Prata de "Dois circuitos" por folga fixa (s), perceptível ao jogador: só entram
## pares de rivais cuja solução alcança essa folga. PENDENTE do playtest de
## clareza (a partir de que diferença o jogador percebe a vantagem); enquanto
## for < 0, a prata é metade da folga da solução, como antes.
const FOLGA_PRATA_DUPLA_S := -1.0
## Orçamento de busca de "Dois circuitos": montagens conjuntas tentadas por carro e
## par de pistas, do par de rivais mais fácil ao mais difícil (com 618 carros, todos os pares não
## terminam). Limite da ferramenta, não do jogo.
const PARES_MAX := 12
## Orçamento total de montagens conjuntas de "Dois circuitos" (licenças altas têm
## dezenas de carros × pares de pistas: sem teto a busca passa de duas horas).
## Limite da ferramenta, não do jogo.
const DUPLOS_MAX := 300
var _duplos := 0

var _feito := false
var _dados: Node
var _piloto: Dictionary
var _voltas := 1
var _cache := {}
var _pecas_carro := {}  # id do carro -> peças que servem nele
var _licenca := "CLUB"
var _saldo_ref := 0


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_calibrar()
		quit()
	return false


func _calibrar() -> void:
	_dados = root.get_node("Dados")
	_piloto = _dados.piloto(_dados.carreira()["piloto_jogador"])
	var so_custo := false
	var manter_par := false
	var busca_completa := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--licenca="):
			_licenca = a.trim_prefix("--licenca=")
		elif a == "--so-custo":
			so_custo = true
		elif a == "--manter-par":
			manter_par = true
		elif a == "--busca-completa":
			busca_completa = true
	var lic: Dictionary = _dados.item("licencas", _licenca)
	# Sem testes do GT2 (ELITE): voltas e limite dos testes da licença anterior,
	# a mesma regra do tempo de treino (Licencas.treino_s).
	var testes: Array = lic.get("testes", [])
	var ids: Array = _dados.lista("licencas").map(func(l): return l["id"])
	var k := ids.find(_licenca)
	while testes.is_empty() and k > 0:
		k -= 1
		testes = _dados.item("licencas", ids[k]).get("testes", [])
	_voltas = int(testes[0]["voltas"])
	var limite := INF
	for t in testes:
		limite = minf(limite, float(t.get("restricoes", {}).get("potencia_max", INF)))
	var pistas: Array = _dados.lista("pistas").map(func(p): return p["id"])
	var escola: Array = _dados.lista("carros").filter(func(c): return float(c["potencia"]) <= limite)
	var todos: Array = _dados.lista("carros").duplicate()
	_saldo_ref = int(_dados.economia()["saldo_inicial"])
	if _licenca != _dados.lista("licencas")[0]["id"] or not busca_completa:
		var ordem: Array = _dados.lista("licencas").map(func(l): return l["id"])
		var seguinte: String = ordem[ordem.find(_licenca) + 1] if ordem.find(_licenca) + 1 < ordem.size() else ""
		var deste := _eventos_da(_licenca)
		var rivais_aqui := _rivais(deste)
		escola = rivais_aqui.filter(func(c): return float(c["potencia"]) <= limite)
		todos = _rivais(deste + _eventos_da(seguinte))
		pistas = []
		for e in deste:
			if not e["pista"] in pistas:
				pistas.append(e["pista"])
		var requisito: String = "" if lic.get("requisito") == null else String(lic["requisito"])
		if requisito != "":
			_saldo_ref = 0
			for e in _eventos_da(requisito):
				if not e["premios"].is_empty():
					_saldo_ref += int(e["premios"][0])
		print("%s: %d carros da escola, %d rivais, %d pistas, teto de custo %d G" % [_licenca, escola.size(),
				todos.size(), pistas.size(), _saldo_ref])
	escola.sort_custom(func(a, b): return a["id"] < b["id"])
	todos.sort_custom(func(a, b): return a["id"] < b["id"])
	var usados := []
	var contratos := []
	if so_custo:
		_so_custo(escola, todos, pistas, manter_par)
		return
	print("procurando: o pequeno contra o gigante (%d s)" % [Time.get_ticks_msec() / 1000])
	var c1 := _pequeno_contra_gigante(escola, todos, pistas)
	if not c1.is_empty():
		contratos.append(c1)
		usados.append(c1["carro"])
	print("procurando: o último giro (%d s)" % [Time.get_ticks_msec() / 1000])
	var c2 := _ultimo_credito(escola.filter(func(c): return not c["id"] in usados), todos, pistas)
	if not c2.is_empty():
		contratos.append(c2)
		usados.append(c2["carro"])
	print("procurando: dois circuitos (%d s)" % [Time.get_ticks_msec() / 1000])
	var c3 := _dois_circuitos(escola.filter(func(c): return not c["id"] in usados), todos, pistas)
	if not c3.is_empty():
		contratos.append(c3)
	for c in contratos:
		c["licenca"] = _licenca
		if _licenca != _dados.lista("licencas")[0]["id"]:
			c["id"] = _licenca.to_lower() + "_" + c["id"]
		print("%s: %s · %s" % [c["id"], c["carro"], JSON.stringify(c["condicoes"])])
		for p in c["provas"]:
			print("   %s contra %s" % [p["pista"], ", ".join(p["rivais"].map(func(r): return r["carro"]))])
		print("   referência: %s" % JSON.stringify(c["_referencia"]))
		c.erase("_referencia")
	# Troca só os desta licença; os outros ficam como estão, na ordem das licenças.
	var antigos: Array = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO)) if FileAccess.file_exists(CAMINHO) else []
	var ordem_lic: Array = _dados.lista("licencas").map(func(l): return l["id"])
	var todos_contratos: Array = antigos.filter(func(c): return c["licenca"] != _licenca) + contratos
	todos_contratos.sort_custom(func(a, b): return ordem_lic.find(a["licenca"]) < ordem_lic.find(b["licenca"]))
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(todos_contratos, "\t") + "\n")
	f.close()


## --so-custo: recalcula "O último giro" desta licença e troca só ele no arquivo.
## Os carros já usados são os dos contratos que vêm antes dele (a ordem da busca).
func _so_custo(escola: Array, todos: Array, pistas: Array, manter_par := false) -> void:
	var antigos: Array = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	var i := -1
	var usados := []
	for k in antigos.size():
		if antigos[k]["licenca"] != _licenca:
			continue
		if String(antigos[k]["id"]).ends_with("ultimo_credito"):  # o prefixo varia (ic_ dos saves antigos)
			i = k
			break
		usados.append(antigos[k]["carro"])
	if i < 0:
		print("%s: sem \"O último giro\"; nada a fazer" % _licenca)
		return
	if manter_par:
		var prova: Dictionary = antigos[i]["provas"][0]
		escola = [_dados.carro(antigos[i]["carro"])]
		todos = [_dados.carro(prova["rivais"][0]["carro"])]
		pistas = [prova["pista"]]
	var c := _ultimo_credito(escola.filter(func(x): return not x["id"] in usados), todos, pistas)
	if c.is_empty():
		push_error("%s: \"O último giro\" sem solução com os preços novos" % _licenca)
		return
	c["licenca"] = _licenca
	c["id"] = antigos[i]["id"]
	print("%s: %s · %s (antes: %s · %s)" % [c["id"], c["carro"], JSON.stringify(c["condicoes"]), antigos[i]["carro"],
			JSON.stringify(antigos[i]["condicoes"])])
	if c["carro"] != antigos[i]["carro"]:
		print("   ATENÇÃO: o carro mudou; os contratos seguintes da licença usavam o antigo como já usado")
	c.erase("_referencia")
	# Relê antes de gravar: outras licenças podem rodar em paralelo.
	antigos = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	for k in antigos.size():
		if antigos[k]["id"] == c["id"]:
			antigos[k] = c
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	f.store_string(JSON.stringify(antigos, "\t") + "\n")
	f.close()


func _eventos_da(lic: String) -> Array:
	if lic == "":
		return []
	return _dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca", "") == lic)


## Carros rivais dos eventos, sem repetir.
func _rivais(eventos: Array) -> Array:
	var ids := {}
	for e in eventos:
		for a in e["adversarios"]:
			ids[a["carro"]] = true
	return ids.keys().map(func(id): return _dados.carro(id))


func _pequeno_contra_gigante(escola: Array, todos: Array, pistas: Array) -> Dictionary:
	var melhor := {}
	var melhor_razao := 0.0
	for pista in pistas:
		for c in escola:
			var fabrica := _tempo(_montar(c, []), pista)
			var sem_pot := {}
			var tudo := {}
			for g in todos:
				var razao := float(g["potencia"]) / float(c["potencia"])
				if razao < RAZAO_GIGANTE or razao <= melhor_razao:
					continue
				var rival := _tempo(_montar(g, []), pista)
				if fabrica <= rival:
					continue
				if tudo.is_empty():  # montagens só quando há candidato (são as buscas caras)
					sem_pot = _guloso(c, pista, Contratos.CATEGORIAS_POTENCIA)
					tudo = _guloso(c, pista, [])
				if sem_pot["tempo"] >= rival or tudo["tempo"] >= rival:
					continue
				melhor_razao = razao
				melhor = {
					"id": "pequeno_gigante", "licenca": _licenca, "nome": "O pequeno contra o gigante",
					"descricao": "O %s tem %d cv; o rival, %d. Monte o carro da escola para chegar na frente." % [
							c["nome"], c["potencia"], g["potencia"]],
					"carro": c["id"],
					"provas": [{"pista": pista, "voltas": _voltas, "condicao": "seco", "rivais": [{"carro": g["id"]}]}],
					"condicoes": {
						"bronze": {"vencer": true},
						"prata": {"folga_s": _meia_folga(rival - tudo["tempo"])},
						"ouro": {"sem_categorias": Contratos.CATEGORIAS_POTENCIA},
					},
					"_referencia": {"sem_potencia": sem_pot["pecas"], "tudo": tudo["pecas"]},
				}
	return melhor


func _ultimo_credito(escola: Array, todos: Array, pistas: Array) -> Dictionary:
	var saldo := _saldo_ref
	var melhor := {}
	var melhor_custo := 0
	for pista in pistas:
		for c in escola:
			var fabrica := _tempo(_montar(c, []), pista)
			for g in todos:
				if g["id"] == c["id"]:
					continue
				var rival := _tempo(_montar(g, []), pista)
				if fabrica <= rival:
					continue
				var r := _mais_barato(c, pista, rival)
				# Tolerância do arredondamento da moeda: cada peça pode ter subido até
				# 0,5 G na conversão (importar_gt2.moeda), e o teto do GT2 era o saldo.
				if r.is_empty() or r["pecas"].size() < 2 or r["custo"] > saldo + 0.5 * r["pecas"].size() \
						or r["custo"] <= melhor_custo:
					continue
				melhor_custo = r["custo"]
				melhor = {
					"id": "ultimo_credito", "licenca": _licenca, "nome": "O último giro",
					"descricao": "A escola paga as peças até um teto. Vença o %s gastando o mínimo." % g["nome"],
					"carro": c["id"],
					"provas": [{"pista": pista, "voltas": _voltas, "condicao": "seco", "rivais": [{"carro": g["id"]}]}],
					"condicoes": {
						"bronze": {"vencer": true, "custo_max": _arredondar(r["custo"] * FOLGA_CUSTO_BRONZE)},
						"prata": {"custo_max": _arredondar(r["custo"] * FOLGA_CUSTO_PRATA)},
						"ouro": {"custo_max": r["custo"]},
					},
					"_referencia": r,
				}
	return melhor


func _dois_circuitos(escola: Array, todos: Array, pistas: Array) -> Dictionary:
	for i in pistas.size():
		for k in range(i + 1, pistas.size()):
			var p1: String = pistas[i]
			var p2: String = pistas[k]
			for c in escola:
				var so1 := _guloso(c, p1, [])
				var so2 := _guloso(c, p2, [])
				var so1_em_p2 := _tempo(_montar(c, so1["pecas"], so1["ajuste"]), p2)
				var so2_em_p1 := _tempo(_montar(c, so2["pecas"], so2["ajuste"]), p1)
				var tentativas := 0
				for par in _pares_de_rivais(c, p1, p2, todos, so1["tempo"], so2["tempo"]):
					if tentativas >= PARES_MAX:
						break
					var r1: Dictionary = par[0]
					var r2: Dictionary = par[1]
					var alvo := {p1: _fabrica(r1, p1), p2: _fabrica(r2, p2)}
					# Se a melhor montagem só para uma pista não vence ali, a conjunta também não.
					if so1["tempo"] >= alvo[p1] - FOLGA_MINIMA_DUPLA or so2["tempo"] >= alvo[p2] - FOLGA_MINIMA_DUPLA:
						continue
					# A melhor só para uma pista precisa perder na outra.
					var especializa: bool = so1_em_p2 >= alvo[p2] or so2_em_p1 >= alvo[p1]
					if not especializa:
						continue
					tentativas += 1
					_duplos += 1
					if _duplos > DUPLOS_MAX:
						push_warning("Dois circuitos: orçamento de %d montagens conjuntas esgotado" % DUPLOS_MAX)
						return {}
					if _duplos % 50 == 0:
						print("  dois circuitos: %d montagens conjuntas (%d s)" % [_duplos, Time.get_ticks_msec() / 1000])
					var junto := _guloso_duplo(c, alvo)
					if junto["deficit"] > -maxf(FOLGA_MINIMA_DUPLA, FOLGA_PRATA_DUPLA_S):
						continue
					var enxuta := _enxugar_duplo(c, alvo, junto)
					return {
						"id": "dois_circuitos", "licenca": _licenca, "nome": "Dois circuitos, um carro",
						"descricao": "Uma preparação só para vencer o %s em %s e o %s em %s." % [
								r1["nome"], _nome_pista(p1), r2["nome"], _nome_pista(p2)],
						"carro": c["id"],
						"provas": [
							{"pista": p1, "voltas": _voltas, "condicao": "seco", "rivais": [{"carro": r1["id"]}]},
							{"pista": p2, "voltas": _voltas, "condicao": "seco", "rivais": [{"carro": r2["id"]}]},
						],
						"condicoes": {
							"bronze": {"vencer": true},
							"prata": {"folga_s": FOLGA_PRATA_DUPLA_S if FOLGA_PRATA_DUPLA_S > 0.0 else _meia_folga(-junto["deficit"])},
							"ouro": {"pecas_max": enxuta["pecas"].size()},
						},
						"_referencia": {"junto": junto, "enxuta": enxuta},
					}
	return {}


## Pares (rival na pista 1, rival na pista 2), diferentes, que vencem o carro de
## fábrica em sua pista, do par mais fácil (menor soma de vantagem) ao mais difícil.
## Só entram rivais que a melhor montagem para a pista bate com folga (`so1`,
## `so2`; senão a conjunta também não bate) — o mesmo corte que _dois_circuitos faz.
func _pares_de_rivais(c: Dictionary, p1: String, p2: String, todos: Array, so1: float, so2: float) -> Array:
	var f1 := _fabrica(c, p1)
	var f2 := _fabrica(c, p2)
	var lista1 := []
	var lista2 := []
	for a in todos:
		if a["id"] == c["id"]:
			continue
		var ta := _fabrica(a, p1)
		if ta < f1 and so1 < ta - FOLGA_MINIMA_DUPLA:
			lista1.append([a, f1 - ta])
		var tb := _fabrica(a, p2)
		if tb < f2 and so2 < tb - FOLGA_MINIMA_DUPLA:
			lista2.append([a, f2 - tb])
	var pares := []
	for x in lista1:
		for y in lista2:
			if x[0]["id"] != y[0]["id"]:
				pares.append([x[0], y[0], x[1] + y[1]])
	pares.sort_custom(func(u, v): return u[2] < v[2])
	return pares


## Tempo de fábrica de um carro numa pista (montar é caro: cache por id).
var _fabricas := {}


func _fabrica(c: Dictionary, pista: String) -> float:
	var chave := "%s|%s" % [c["id"], pista]
	if not _fabricas.has(chave):
		_fabricas[chave] = _tempo(_montar(c, []), pista)
	return _fabricas[chave]


## Montagem gulosa: a cada passo, a opção (peça de categoria vazia ou ajuste
## do câmbio) que mais reduz o tempo. `proibidas`: categorias fora.
var _gulosos := {}


func _guloso(c: Dictionary, pista: String, proibidas: Array) -> Dictionary:
	var chave := "%s|%s|%s" % [c["id"], pista, str(proibidas)]
	if not _gulosos.has(chave):
		_gulosos[chave] = _guloso_calc(c, pista, proibidas)
	return _gulosos[chave]


func _guloso_calc(c: Dictionary, pista: String, proibidas: Array) -> Dictionary:
	var pecas := []
	var ajuste := ""
	var t := _tempo(_montar(c, pecas, ajuste), pista)
	while true:
		var melhor := {}
		for o in _opcoes(c, pecas, ajuste, proibidas):
			var tt := _tempo(_montar(c, o["pecas"], o["ajuste"]), pista)
			if tt < t - 0.005:
				t = tt
				melhor = o
		if melhor.is_empty():
			break
		pecas = melhor["pecas"]
		ajuste = melhor["ajuste"]
	return {"pecas": pecas, "ajuste": ajuste, "tempo": t}


## Mais barato que vence `rival`: a peça de maior ganho por giro a cada passo.
## O caminho não depende do rival (só onde parar): calculado uma vez por carro e pista.
func _mais_barato(c: Dictionary, pista: String, rival: float) -> Dictionary:
	for passo in _caminho_barato(c, pista):
		if passo["tempo"] < rival:
			return passo
	return {}


var _caminhos := {}


func _caminho_barato(c: Dictionary, pista: String) -> Array:
	var chave: String = c["id"] + "|" + pista
	if _caminhos.has(chave):
		return _caminhos[chave]
	var pecas := []
	var ajuste := ""
	var t := _tempo(_montar(c, pecas, ajuste), pista)
	var caminho := [{"pecas": pecas, "ajuste": ajuste, "custo": 0, "tempo": t}]
	while true:
		var melhor := {}
		var melhor_razao := 0.0
		for o in _opcoes(c, pecas, ajuste, []):
			var tt := _tempo(_montar(c, o["pecas"], o["ajuste"]), pista)
			var custo := maxi(_custo(o["pecas"]) - _custo(pecas), 1)
			if tt < t - 0.005 and (t - tt) / custo > melhor_razao:
				melhor_razao = (t - tt) / custo
				melhor = o
		if melhor.is_empty():
			break
		pecas = melhor["pecas"]
		ajuste = melhor["ajuste"]
		t = _tempo(_montar(c, pecas, ajuste), pista)
		caminho.append({"pecas": pecas, "ajuste": ajuste, "custo": _custo(pecas), "tempo": t})
	_caminhos[chave] = caminho
	return caminho


## Gulosa para as duas pistas: minimiza o pior déficit (tempo − rival).
func _guloso_duplo(c: Dictionary, alvo: Dictionary) -> Dictionary:
	var pecas := []
	var ajuste := ""
	var d := _deficit(c, pecas, ajuste, alvo)
	while true:
		var melhor := {}
		for o in _opcoes(c, pecas, ajuste, []):
			var dd := _deficit(c, o["pecas"], o["ajuste"], alvo)
			if dd < d - 0.005:
				d = dd
				melhor = o
		if melhor.is_empty():
			break
		pecas = melhor["pecas"]
		ajuste = melhor["ajuste"]
	return {"pecas": pecas, "ajuste": ajuste, "deficit": d}


## Tira peças enquanto a montagem continua vencendo nas duas pistas.
func _enxugar_duplo(c: Dictionary, alvo: Dictionary, sol: Dictionary) -> Dictionary:
	var pecas: Array = sol["pecas"].duplicate()
	var ajuste: String = sol["ajuste"]
	var mudou := true
	while mudou:
		mudou = false
		for pid in pecas.duplicate():
			var resto := pecas.filter(func(x): return x != pid)
			var aj := ajuste if resto.any(func(x): return _dados.peca(x)["categoria"] == "cambio") else ""
			if _deficit(c, resto, aj, alvo) < 0.0:
				pecas = resto
				ajuste = aj
				mudou = true
				break
	return {"pecas": pecas, "ajuste": ajuste, "deficit": _deficit(c, pecas, ajuste, alvo)}


func _deficit(c: Dictionary, pecas: Array, ajuste: String, alvo: Dictionary) -> float:
	var pior := -INF
	for pista in alvo:
		pior = maxf(pior, _tempo(_montar(c, pecas, ajuste), pista) - float(alvo[pista]))
	return pior


## Próximos passos: cada peça de uma categoria ainda vazia (ou troca de estágio
## na mesma categoria) e, com câmbio instalado, os ajustes.
func _opcoes(c: Dictionary, pecas: Array, ajuste: String, proibidas: Array) -> Array:
	var r := []
	if not _pecas_carro.has(c["id"]):
		var carro := Carro.new(c)
		_pecas_carro[c["id"]] = _dados.lista("pecas").filter(func(p): return carro.motivo_recusa(p) == "")
	for p in _pecas_carro[c["id"]]:
		if p["categoria"] in proibidas or p["id"] in pecas:
			continue
		var outras := pecas.filter(func(x): return _dados.peca(x)["categoria"] != p["categoria"])
		r.append({"pecas": outras + [p["id"]], "ajuste": ajuste})
	if pecas.any(func(x): return _dados.peca(x)["categoria"] == "cambio"):
		for aj in ["curto", "", "longo"]:
			if aj != ajuste:
				r.append({"pecas": pecas, "ajuste": aj})
	return r


func _montar(c: Dictionary, pecas: Array, ajuste := "") -> Carro:
	return Contratos.carro_montado(_dados, {"carro": c["id"], "pecas_escola": []}, {"pecas": pecas, "ajuste_cambio": ajuste})


## Tempo sozinho, na semente da bancada (a mesma de Contratos.avaliar).
func _tempo(carro: Carro, pista: String) -> float:
	var a := carro.atributos_efetivos("seco")
	var chave := str(a) + pista
	if _cache.has(chave):
		return _cache[chave]
	var res := Simulacao.correr(_dados.pista(pista), [{"id": "x", "atributos": a, "piloto": _piloto}], _voltas,
			_dados.simulacao(), Contratos.SEMENTE, false)
	var x: Dictionary = res["carros"]["x"]
	_cache[chave] = x["tempo_total"] if x["terminou"] else INF
	return _cache[chave]


func _custo(pecas: Array) -> int:
	var t := 0
	for pid in pecas:
		t += int(_dados.peca(pid)["preco"])
	return t


func _meia_folga(folga: float) -> float:
	return floorf(folga * 0.5 * 10.0) / 10.0


## Teto arredondado para cima no passo PASSO_CUSTO (em G).
func _arredondar(g: float) -> int:
	return int(ceil(g / PASSO_CUSTO)) * PASSO_CUSTO


func _nome_pista(id: String) -> String:
	return Aba.nome_pista(id)
