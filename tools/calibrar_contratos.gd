extends SceneTree
## Gera data/contratos.json: escolhe carros, rivais e pistas dos contratos da
## licença B e calibra as condições com a própria simulação (bancada de
## Contratos: cada carro sozinho, piloto do jogador, semente fixa do contrato).
## O desenho de cada contrato (o que ele pede) é o da decisão 4; os carros e os
## números saem dos dados por estes critérios (provisórios, a confirmar em
## playtest; ver data/README.md):
##
## Comum: voltas e limite de potência do carro da escola vêm dos testes da
## licença B (licencas.json). A escola oferece todas as peças do catálogo que
## servem no carro. Busca de montagem: gulosa (a peça que mais ajuda por vez)
## e depois enxuta (tira o que não faz falta) — o jogador pode achar melhor.
##
## "O pequeno contra o gigante": rival com ao menos RAZAO_GIGANTE vezes a
##   potência do carro da escola, que vence o carro de fábrica. Precisa ter
##   solução sem peças de potência (ouro). Escolhe o par de maior razão.
##   bronze: vencer · prata: folga de metade da maior folga encontrada · ouro: vencer sem peças de potência.
## "O último crédito": rival que vence o carro de fábrica e só é batido com
##   ao menos 2 peças, ao menor custo C achado (peça de mais ganho por crédito
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
## crédito" é a soma dos prêmios de 1º lugar dos eventos da licença anterior
## (na primeira, o saldo inicial). Os ids levam o prefixo da licença ("pro_..."; os da antiga IC mantêm "ic_", que os saves já usam).
## Só os contratos da licença pedida são trocados em contratos.json.
## Uso: godot --headless --path . --script res://tools/calibrar_contratos.gd [-- --licenca=CLUB]

const CAMINHO := "res://data/contratos.json"
const RAZAO_GIGANTE := 1.3
const FOLGA_CUSTO_BRONZE := 1.5
const FOLGA_CUSTO_PRATA := 1.2
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--licenca="):
			_licenca = a.trim_prefix("--licenca=")
	var lic: Dictionary = _dados.item("licencas", _licenca)
	_voltas = int(lic["testes"][0]["voltas"])
	var limite := INF
	for t in lic["testes"]:
		limite = minf(limite, float(t.get("restricoes", {}).get("potencia_max", INF)))
	var pistas: Array = _dados.lista("pistas").map(func(p): return p["id"])
	var escola: Array = _dados.lista("carros").filter(func(c): return float(c["potencia"]) <= limite)
	var todos: Array = _dados.lista("carros").duplicate()
	_saldo_ref = int(_dados.economia()["saldo_inicial"])
	if _licenca != _dados.lista("licencas")[0]["id"]:
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
		_saldo_ref = 0
		for e in _eventos_da(String(lic.get("requisito", ""))):
			if not e["premios"].is_empty():
				_saldo_ref += int(e["premios"][0])
		print("%s: %d carros da escola, %d rivais, %d pistas, teto de custo %d Cr" % [_licenca, escola.size(),
				todos.size(), pistas.size(), _saldo_ref])
	escola.sort_custom(func(a, b): return a["id"] < b["id"])
	todos.sort_custom(func(a, b): return a["id"] < b["id"])
	var usados := []
	var contratos := []
	print("procurando: o pequeno contra o gigante (%d s)" % [Time.get_ticks_msec() / 1000])
	var c1 := _pequeno_contra_gigante(escola, todos, pistas)
	if not c1.is_empty():
		contratos.append(c1)
		usados.append(c1["carro"])
	print("procurando: o último crédito (%d s)" % [Time.get_ticks_msec() / 1000])
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
				if r.is_empty() or r["pecas"].size() < 2 or r["custo"] > saldo or r["custo"] <= melhor_custo:
					continue
				melhor_custo = r["custo"]
				melhor = {
					"id": "ultimo_credito", "licenca": _licenca, "nome": "O último crédito",
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
				var tentativas := 0
				for par in _pares_de_rivais(c, p1, p2, todos):
					if tentativas >= PARES_MAX:
						break
					var r1: Dictionary = par[0]
					var r2: Dictionary = par[1]
					var alvo := {p1: _tempo(_montar(r1, []), p1), p2: _tempo(_montar(r2, []), p2)}
					# Se a melhor montagem só para uma pista não vence ali, a conjunta também não.
					if so1["tempo"] >= alvo[p1] - FOLGA_MINIMA_DUPLA or so2["tempo"] >= alvo[p2] - FOLGA_MINIMA_DUPLA:
						continue
					# A melhor só para uma pista precisa perder na outra.
					var especializa: bool = _tempo(_montar(c, so1["pecas"], so1["ajuste"]), p2) >= alvo[p2] \
							or _tempo(_montar(c, so2["pecas"], so2["ajuste"]), p1) >= alvo[p1]
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
func _pares_de_rivais(c: Dictionary, p1: String, p2: String, todos: Array) -> Array:
	var f1 := _tempo(_montar(c, []), p1)
	var f2 := _tempo(_montar(c, []), p2)
	var pares := []
	for a in todos:
		var ta := _tempo(_montar(a, []), p1)
		if a["id"] == c["id"] or ta >= f1:
			continue
		for b in todos:
			var tb := _tempo(_montar(b, []), p2)
			if b["id"] == c["id"] or b["id"] == a["id"] or tb >= f2:
				continue
			pares.append([a, b, (f1 - ta) + (f2 - tb)])
	pares.sort_custom(func(x, y): return x[2] < y[2])
	return pares


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


## Mais barato que vence `rival`: a peça de maior ganho por crédito a cada passo.
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


func _arredondar(cr: float) -> int:
	return int(ceil(cr / 100.0)) * 100


func _nome_pista(id: String) -> String:
	return Aba.nome_pista(id)
