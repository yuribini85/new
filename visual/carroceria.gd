class_name Carroceria
extends RefCounted
## Carros gerados em código, no estilo facetado dos pilotos (aprovado pelo
## usuário): a forma de cada carro sai de arte/carros3d/formas.json (medidas da
## carroceria da frota 360, exportadas por tools/exportar_formas.py) e o desenho
## dos detalhes de uma linguagem por época, categoria e escola do fabricante
## (faróis, grade, para-choques, frisos, aerofólio).
##
## Mesmo sistema de eixos dos GLB da frota: frente em +Z, chão em y = 0, rodas
## Mount_* com o centro no eixo e o giro em X. A carroceria inteira é uma malha
## de duas superfícies (pintura e detalhes, MontagemMalha) guardada por carro
## durante a sessão; a pintura é um ShaderMaterial por instância (cores e
## faixas da Oficina). Cada roda é um nó com uma malha (Rodas).

const ARQUIVO := "res://arte/carros3d/formas.json"
const N := 22  # seções da carroceria: poucas, facetas grandes

static var _formas := {}
static var _lidas := false
## id -> ArrayMesh da carroceria (sem rodas).
static var _corpos := {}
## Escola (jp, de, us...) por fabricante, de data/fabricantes.json.
static var _escolas := {}


static func formas() -> Dictionary:
	if not _lidas:
		_lidas = true
		if FileAccess.file_exists(ARQUIVO):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
			if d is Dictionary:
				_formas = d.get("carros", {})
	return _formas


## Carros em que o gerado substitui o GLB (pedido do usuário: melhorar um
## carro até ele aprovar, só depois aplicar em todos). Vazia: o jogo usa os
## GLB como antes. Testes e ferramentas trocam `ativos` em tempo de execução.
const ATIVOS: Array[String] = []
static var ativos: Array = ATIVOS.duplicate()


## O carro usa o gerado no jogo (tem forma e está nos ativos).
static func tem(id: String) -> bool:
	return id in ativos and tem_forma(id)


## Há forma exportada para o carro (formas.json), ativo ou não.
static func tem_forma(id: String) -> bool:
	return id != "" and formas().has(id)


static func forma(id: String) -> Dictionary:
	return formas().get(id, {})


## Fila de carros a gerar antes de precisar (a lista de provas pede os do
## grid): um por quadro, para a largada não travar montando todos de uma vez.
static var _fila: Array = []


static func preparar(ids: Array) -> void:
	for id in ids:
		if tem(String(id)) and not _corpos.has(String(id)) and not String(id) in _fila:
			_fila.append(String(id))
	var arvore := Engine.get_main_loop() as SceneTree
	if not _fila.is_empty() and arvore != null and not arvore.process_frame.is_connected(_passo):
		arvore.process_frame.connect(_passo)


static func _passo() -> void:
	while not _fila.is_empty() and _corpos.has(_fila[0]):
		_fila.pop_front()
	if not _fila.is_empty():
		corpo(_fila.pop_front())
	if _fila.is_empty():
		var arvore := Engine.get_main_loop() as SceneTree
		if arvore != null and arvore.process_frame.is_connected(_passo):
			arvore.process_frame.disconnect(_passo)


## Esquece as malhas guardadas (testes de tempo).
static func limpar_cache() -> void:
	_corpos.clear()


static func em_cache(id: String) -> bool:
	return _corpos.has(id)


## Contexto de design: época, categoria, escola e se é esportivo.
static func contexto(carro: Dictionary, escola: String) -> Dictionary:
	var ano := int(carro.get("ano", 1990))
	var era := "classico" if ano < 1972 else ("setenta" if ano < 1983 else ("oitenta" if ano < 1993 else ("noventa" if ano < 2004 else "moderno")))
	var cat := String(carro.get("categoria", "cupe"))
	var esportivo: bool = cat == "cupe" and float(carro.get("potencia", 100)) / maxf(float(carro.get("peso", 1000)), 1.0) > 0.13
	return {"era": era, "cat": cat, "escola": escola, "esportivo": esportivo, "ano": ano}


## Os dados do carro (data/carros.json) quando o autoload Dados existe; senão
## o que veio (sempre os mesmos para o mesmo id: a malha fica guardada por id).
static func _dados_do_carro(id: String, base: Dictionary) -> Dictionary:
	var arvore := Engine.get_main_loop() as SceneTree
	var dados: Node = arvore.root.get_node_or_null("Dados") if arvore != null else null
	if dados != null and dados.has_method("existe") and dados.existe("carros", id):
		return dados.carro(id)
	return base


static func escola(fabricante: String) -> String:
	if _escolas.is_empty():
		var l: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fabricantes.json"))
		if l is Array:
			for f in l:
				_escolas[String(f.get("id", ""))] = String(f.get("escola", "jp"))
	return String(_escolas.get(fabricante, "jp"))


## A carroceria do carro (malha guardada).
## Não olha `ativos` (o teste e a prancha geram qualquer carro com forma).
static func corpo(id: String, base: Dictionary = {}) -> ArrayMesh:
	if _corpos.has(id):
		return _corpos[id]
	var f := forma(id)
	if f.is_empty():
		return null
	var carro := _dados_do_carro(id, base)
	var ctx := contexto(carro, escola(String(carro.get("fabricante", ""))))
	var m := MontagemMalha.new()
	_montar(m, f, ctx)
	var malha := m.malha()
	_corpos[id] = malha
	return malha


## O carro montado: nó com a carroceria ("Carroceria", pintura na superfície
## da meta "pintura") e as rodas (Mount_*, meta "lado" e "raio").
static func construir(id: String, base: Dictionary, cor: Color, faixas: Dictionary = {}) -> Node3D:
	var malha := corpo(id, base)
	if malha == null:
		return null
	var f := forma(id)
	var raiz := Node3D.new()
	raiz.name = "Gerado"
	var mi := MeshInstance3D.new()
	mi.name = "Carroceria"
	mi.mesh = malha
	raiz.add_child(mi)
	var k := int(malha.get_meta("pintura", -1))
	if k >= 0:
		var sm := ShaderMaterial.new()
		sm.shader = CarroBloco.SHADER_LATARIA
		sm.set_shader_parameter("cor_base", cor)
		mi.set_surface_override_material(k, sm)
		CarroBloco._parametros_faixas(sm, mi, faixas)
	var desenho := Rodas.desenho_de(faixas)
	var r := float(f["r"])
	for w in f["rodas"]:
		var lado := signf(float(w[1]))
		var roda := Rodas.montar(desenho, r, lado)
		roda.name = String(w[0])
		roda.position = Vector3(w[1], w[2], w[3])
		roda.set_meta("lado", lado)
		roda.set_meta("raio", r)
		raiz.add_child(roda)
	return raiz


# ------------------------------------------------------------------ forma

static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Curva (Catmull-Rom) por pontos [z, meia largura, altura]: (largura, altura) em z.
static func _curva(pts: Array, z: float) -> Vector2:
	var n := pts.size()
	if z <= pts[0][0]:
		return Vector2(pts[0][1], pts[0][2])
	if z >= pts[n - 1][0]:
		return Vector2(pts[n - 1][1], pts[n - 1][2])
	var i := 0
	while i < n - 2 and z > pts[i + 1][0]:
		i += 1
	var t: float = (z - pts[i][0]) / maxf(pts[i + 1][0] - pts[i][0], 0.0001)
	var a0 = pts[maxi(i - 1, 0)]
	var a1 = pts[i]
	var a2 = pts[i + 1]
	var a3 = pts[mini(i + 2, n - 1)]
	return Vector2(_cr(a0[1], a1[1], a2[1], a3[1], t), _cr(a0[2], a1[2], a2[2], a3[2], t))


## Largura extra dos para-lamas perto das rodas (alargamento).
static func _alarga(f: Dictionary, z: float) -> float:
	var extra: float = maxf(float(f.get("sx", f["W"] * 0.5)) - float(f["W"]) * 0.5, 0.0) + 0.015
	var s := 0.0
	for ax in f["axles"]:
		var d: float = (z - float(ax)) / (float(f["r"]) * 1.9)
		s = maxf(s, exp(-d * d * 2.5))
	return extra * s


static func _perfil(w: float, topo: float, f: Dictionary, z: float, ctx: Dictionary) -> PackedVector2Array:
	var low: float = f["low"]
	var lo: float = f["lo"]
	var hi: float = minf(f["hi"], topo - 0.05)
	var wf := w + _alarga(f, z)
	var reto: bool = ctx["era"] in ["setenta", "oitenta"] or ctx["cat"] in ["utilitario", "picape", "pesado"]
	var p := PackedVector2Array()
	p.append(Vector2(0.0, low))
	p.append(Vector2(w * 0.84, low))
	p.append(Vector2(w * 0.93, low + 0.025))
	p.append(Vector2(w * 0.96, lerpf(low, lo, 0.55)))  # soleira recuada
	p.append(Vector2(wf, lo))  # vinco de baixo
	p.append(Vector2(wf * 1.0, lerpf(lo, hi, 0.5)))
	p.append(Vector2(wf * (0.995 if reto else 0.985), hi))  # ombro
	p.append(Vector2(w * (0.975 if reto else 0.95), lerpf(hi, topo, 0.6)))
	p.append(Vector2(w * (0.94 if reto else 0.86), topo - 0.01))
	p.append(Vector2(w * 0.66, topo + 0.006))
	p.append(Vector2(w * 0.33, topo + 0.014))
	p.append(Vector2(0.0, topo + 0.018))
	for ax in f["axles"]:
		var dz: float = absf(z - float(ax))
		var R: float = float(f["r"]) * 1.2
		if dz < R:
			var arco: float = float(f["r"]) + sqrt(R * R - dz * dz) + 0.015
			arco = minf(arco, hi - 0.03)
			for k in [1, 2, 3, 4, 5]:
				var t: float = float(k - 1) / 5.0
				p[k] = Vector2(p[k].x, maxf(p[k].y, lerpf(arco, hi, t * t)))
	return p


## O carro, parte por parte (cada função desenha uma parte e pode ser
## trocada sozinha ao iterar o desenho): lataria, caixas de roda, cabine,
## frente, traseira, lateral, caçamba, aerofólio e pinças. As rodas são de
## Rodas (montadas em construir()).
static func _montar(m: MontagemMalha, f: Dictionary, ctx: Dictionary) -> void:
	var secoes := _secoes(f, ctx)
	_loft(m, secoes)
	_caixas_de_roda(m, f)
	_cabine(m, f, ctx)
	_frente(m, f, secoes[N - 1], ctx)
	_traseira(m, f, secoes[0], ctx)
	_lateral(m, f, ctx)
	if ctx["cat"] == "picape":
		_cacamba(m, f)
	if ctx["esportivo"] and ctx["era"] in ["setenta", "oitenta", "noventa"]:
		_aerofolio(m, f)
	_pincas(m, f)


## Seções da lataria (de trás para a frente): o perfil de _perfil em N
## estações, mais densas nas pontas; as pontas se arredondam.
static func _secoes(f: Dictionary, ctx: Dictionary) -> Array:
	var rows: Array = f["rows"]
	var z0: float = rows[0][0]
	var z1: float = rows[-1][0]
	var secoes := []
	for i in N:
		var u := float(i) / (N - 1)
		var z := lerpf(z0, z1, 0.5 - 0.5 * cos(u * PI))
		var c := _curva(rows, z)
		var perf := _perfil(c.x, c.y, f, z, ctx)
		# pontas: a frente e a traseira se arredondam (mais nos modernos)
		var ponta := pow(absf(u * 2.0 - 1.0), 10.0)
		var e := 1.0 - ponta * (0.16 if ctx["era"] in ["setenta", "oitenta", "classico"] else 0.24)
		var pts := []
		for q in perf:
			var y := q.y
			if y > float(f["low"]) + 0.12:
				y = lerpf(float(f["low"]) + 0.12, y, 1.0 - ponta * 0.08)
			pts.append(Vector3(q.x * e, y, z))
		secoes.append(pts)
	return secoes


## Pinças de freio: na carroceria (aparecem pelos raios e não giram).
static func _pincas(m: MontagemMalha, f: Dictionary) -> void:
	var r: float = f["r"]
	for w in f["rodas"]:
		_caixa(m, "pinca", Vector3(0.05, r * 0.28, r * 0.16), Vector3(w[1], float(w[2]) + r * Rodas.ARO * 0.55, float(w[3]) - r * 0.2))


## Quadrado entre duas seções, espelhado pelo lado (winding do protótipo).
static func _quad(m: MontagemMalha, estilo: String, q: Array, lado: float) -> void:
	if lado > 0:
		m.tri(estilo, q[0], q[2], q[3])
		m.tri(estilo, q[0], q[3], q[1])
	else:
		m.tri(estilo, q[0], q[3], q[2])
		m.tri(estilo, q[0], q[1], q[3])


static func _espelho(v: Vector3, lado: float) -> Vector3:
	return Vector3(v.x * lado, v.y, v.z)


static func _loft(m: MontagemMalha, secoes: Array) -> void:
	var n := secoes.size()
	for lado in [1.0, -1.0]:
		for i in n - 1:
			var a: Array = secoes[i]
			var b: Array = secoes[i + 1]
			for k in a.size() - 1:
				_quad(m, MontagemMalha.PINTURA, [_espelho(a[k], lado), _espelho(a[k + 1], lado),
						_espelho(b[k], lado), _espelho(b[k + 1], lado)], lado)
		for s in [0, n - 1]:
			var a: Array = secoes[s]
			var centro := Vector3(0, (a[0].y + a[a.size() - 1].y) * 0.5, a[0].z)
			for k in a.size() - 1:
				var p0 := _espelho(a[k], lado)
				var p1 := _espelho(a[k + 1], lado)
				if (s == 0) == (lado > 0):
					m.tri(MontagemMalha.PINTURA, centro, p0, p1)
				else:
					m.tri(MontagemMalha.PINTURA, centro, p1, p0)


## Abertura escura atrás das rodas (o vão da caixa de roda).
static func _caixas_de_roda(m: MontagemMalha, f: Dictionary) -> void:
	var r: float = f["r"]
	for w in f["rodas"]:
		var x := float(w[1])
		# Não passa do arco do para-lama (nos baixos o arco é cortado pelo
		# vinco de cima e o vão escuro furava a lataria).
		var topo: float = _curva(f["rows"], float(w[3])).y
		var arco: float = minf(float(f["hi"]), topo - 0.05) - 0.03
		var raio := clampf(arco - (float(w[2]) + 0.02) - 0.015, r * 1.02, r * 1.16)
		m.cilindro("interno", raio, 0.34, 12,
				MontagemMalha.xf(Vector3(x - signf(x) * 0.12, float(w[2]) + 0.02, float(w[3])), Vector3(0, 0, PI / 2)))


static func _cabine(m: MontagemMalha, f: Dictionary, ctx: Dictionary) -> void:
	var rows: Array = f["rows"]
	var roof: Array = f["roof"]
	var zf: float = f["wind"]
	var zt: float = f["back"]
	if ctx["cat"] == "picape":
		zt = maxf(zt, float(roof[0][0]) - 0.15)
	var bf := _curva(rows, zf)
	var bt := _curva(rows, zt)
	var cima := [[zt, bt.x * 0.84, bt.y]] + roof + [[zf, bf.x * 0.84, bf.y]]
	cima.sort_custom(func(a, b): return a[0] < b[0])
	var friso := "cromo" if ctx["era"] in ["classico", "setenta"] else "preto"
	var n := 16
	var secs := []
	for i in n:
		var u := float(i) / (n - 1)
		var z := lerpf(zt, zf, u)
		var base := _curva(rows, z)
		var top := _curva(cima, z)
		var yb: float = base.y + 0.004
		var wb: float = base.x * 0.84
		var yt: float = maxf(top.y, yb + 0.01)
		var wt: float = minf(top.x, wb)
		var meio := 0.62
		secs.append([Vector3(wb, yb, z), Vector3(lerpf(wb, wt, 0.08), lerpf(yb, yt, 0.08), z),
				Vector3(lerpf(wb, wt, meio + 0.3), lerpf(yb, yt, meio + 0.3), z), Vector3(wt, yt, z),
				Vector3(wt * 0.5, yt + 0.022, z), Vector3(0, yt + 0.028, z)])
	var zb_col: float = (float(f.get("za", 0.0)) + float(f.get("zb", 0.0))) * 0.5
	for lado in [1.0, -1.0]:
		for i in n - 1:
			var a: Array = secs[i]
			var b: Array = secs[i + 1]
			var zm: float = (a[0].z + b[0].z) * 0.5
			var u: float = (zm - zt) / maxf(zf - zt, 0.01)
			var coluna: bool = u < 0.07 or u > 0.93 or (ctx["cat"] != "picape" and absf(zm - zb_col) < 0.045 and u > 0.25 and u < 0.8)
			for k in 5:
				var estilo: String
				if k == 0:
					estilo = friso  # moldura de baixo da janela
				elif k == 1:
					estilo = MontagemMalha.PINTURA if coluna else "vidro"
				else:
					estilo = MontagemMalha.PINTURA
				_quad(m, estilo, [_espelho(a[k], lado), _espelho(a[k + 1], lado), _espelho(b[k], lado),
						_espelho(b[k + 1], lado)], lado)
		# para-brisa e vigia: vidro emoldurado
		for s in [0, n - 1]:
			var a: Array = secs[s]
			var c := Vector3(0, (a[0].y + a[5].y) * 0.5, a[0].z)
			for k in 5:
				var p0 := _espelho(a[k], lado)
				var p1 := _espelho(a[k + 1], lado)
				var p0i := p0.lerp(c, 0.12)
				var p1i := p1.lerp(c, 0.12)
				for par in [[c, p0i, p1i, "vidro"], [p0i, p0, p1, MontagemMalha.PINTURA], [p0i, p1, p1i, MontagemMalha.PINTURA]]:
					if (s == 0) == (lado > 0):
						m.tri(par[3], par[0], par[1], par[2])
					else:
						m.tri(par[3], par[0], par[2], par[1])


static func _caixa(m: MontagemMalha, estilo: String, tam: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	m.caixa(estilo, tam, MontagemMalha.xf(pos, rot))


## Cilindro deitado em X (como o _cilindro do protótipo), ou com `rot` dada.
static func _cilindro(m: MontagemMalha, estilo: String, raio: float, alt: float, pos: Vector3,
		rot := Vector3(0, 0, PI / 2), lados := 12) -> void:
	m.cilindro(estilo, raio, alt, lados, MontagemMalha.xf(pos, rot))


## Lente: elipsoide achatado na face.
static func _lente(m: MontagemMalha, estilo: String, tam: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	m.esfera(estilo, 0.5, 1.0, 8, 4, MontagemMalha.xf(pos, rot, tam))


## Farol ou lanterna redondos: aro e lente (a lente a `dz` do aro).
static func _redondo(m: MontagemMalha, raio: float, pos: Vector3, aro: String, lente: String, dz := 0.012) -> void:
	m.cilindro(aro, raio, 0.04, 10, MontagemMalha.xf(pos, Vector3(PI / 2, 0, 0)))
	m.esfera(lente, raio * 0.88, raio * 0.7, 10, 3, MontagemMalha.xf(pos + Vector3(0, 0, dz), Vector3(PI / 2, 0, 0)))


## Dados da face (frente ou traseira): meia largura útil e alturas.
static func _face(sec: Array) -> Dictionary:
	var wmax := 0.0
	for p in sec:
		wmax = maxf(wmax, p.x)
	return {"w": wmax, "z": sec[0].z, "topo": sec[sec.size() - 1].y, "base": sec[0].y}


static func _frente(m: MontagemMalha, f: Dictionary, sec: Array, ctx: Dictionary) -> void:
	var fc := _face(sec)
	var z: float = fc["z"] + 0.005
	var w: float = fc["w"]
	var lo: float = f["lo"]
	var topo: float = fc["topo"]
	var yl: float = clampf(lerpf(lo, topo, 0.62), lo + 0.06, topo - 0.05)
	var era: String = ctx["era"]
	var esc: String = ctx["escola"]
	for lado in [1.0, -1.0]:
		match era:
			"classico", "setenta":
				var raio: float = clampf(w * 0.16, 0.07, 0.11)
				if ctx["cat"] == "seda" and esc in ["de", "uk", "us"] and era == "setenta":
					for k in 2:
						_redondo(m, raio * 0.8, Vector3(lado * w * (0.42 + 0.2 * k), yl, z), "cromo", "farol")
				else:
					_redondo(m, raio, Vector3(lado * w * 0.62, yl, z), "cromo", "farol")
			"oitenta":
				if ctx["esportivo"]:
					# farol escamoteável fechado: só a fresta
					_caixa(m, "preto", Vector3(w * 0.36, 0.012, 0.02), Vector3(lado * w * 0.58, topo - 0.02, z - 0.06))
				else:
					_caixa(m, "farol", Vector3(w * 0.42, 0.1, 0.03), Vector3(lado * w * 0.56, yl, z))
					_caixa(m, "preto", Vector3(w * 0.4, 0.105, 0.025), Vector3(lado * w * 0.56, yl, z - 0.01))
			"noventa":
				_lente(m, "farol", Vector3(w * 0.4, 0.085, 0.06), Vector3(lado * w * 0.6, yl, z - 0.01), Vector3(0, 0, lado * 0.12))
			"moderno":
				_caixa(m, "farol", Vector3(w * 0.42, 0.035, 0.03), Vector3(lado * w * 0.6, yl + 0.03, z))
				_caixa(m, "preto", Vector3(w * 0.42, 0.06, 0.025), Vector3(lado * w * 0.6, yl + 0.01, z - 0.01))
		# seta
		_caixa(m, "seta", Vector3(0.06, 0.03, 0.02), Vector3(lado * w * 0.86, lerpf(lo, yl, 0.4), z - 0.01))
	# grade
	var gw: float = w * (0.9 if esc == "us" else (0.55 if esc in ["de", "uk"] else 0.75))
	var gh: float = clampf((yl - lo) * 0.9, 0.05, 0.14)
	if era == "classico" and esc == "us":
		_caixa(m, "cromo", Vector3(gw * 2.0, gh, 0.03), Vector3(0, lerpf(lo, yl, 0.5), z))
		for k in 7:
			_caixa(m, "preto", Vector3(gw * 2.0 - 0.04, 0.008, 0.035), Vector3(0, lerpf(lo, yl, 0.5) - gh * 0.4 + gh * 0.8 * k / 6.0, z + 0.002))
	elif era != "moderno" or not ctx["esportivo"]:
		_caixa(m, "preto", Vector3(gw * (0.9 if era in ["oitenta", "noventa"] else 1.0), gh * 0.7, 0.03), Vector3(0, lerpf(lo, yl, 0.5), z))
		if era in ["classico", "setenta"]:
			_caixa(m, "cromo", Vector3(gw + 0.02, gh * 0.7 + 0.02, 0.025), Vector3(0, lerpf(lo, yl, 0.5), z - 0.005))
	else:
		_caixa(m, "preto", Vector3(w * 1.2, 0.08, 0.03), Vector3(0, lo - 0.02, z))  # entrada de ar baixa
	_parachoque(m, f, w, z, 1.0, ctx)


static func _parachoque(m: MontagemMalha, f: Dictionary, w: float, z: float, frente: float, ctx: Dictionary) -> void:
	var low: float = f["low"]
	var y := low + 0.09
	match String(ctx["era"]):
		"classico":
			_caixa(m, "cromo", Vector3(w * 2.05, 0.07, 0.07), Vector3(0, y, z + frente * 0.02))
		"setenta", "oitenta":
			_caixa(m, "borracha", Vector3(w * 2.04, 0.09, 0.09), Vector3(0, y, z + frente * 0.02))
		_:
			_caixa(m, "preto", Vector3(w * 1.7, 0.05, 0.05), Vector3(0, low + 0.03, z - frente * 0.02))


static func _traseira(m: MontagemMalha, f: Dictionary, sec: Array, ctx: Dictionary) -> void:
	var fc := _face(sec)
	var z: float = fc["z"] - 0.005
	var w: float = fc["w"]
	var lo: float = f["lo"]
	var topo: float = fc["topo"]
	var yl: float = clampf(lerpf(lo, topo, 0.6), lo + 0.05, topo - 0.04)
	var era: String = ctx["era"]
	for lado in [1.0, -1.0]:
		match era:
			"classico":
				_redondo(m, 0.05, Vector3(lado * w * 0.66, yl, z), "cromo", "lanterna", -0.012)
			"setenta":
				_caixa(m, "lanterna", Vector3(w * 0.34, 0.1, 0.03), Vector3(lado * w * 0.6, yl, z))
			"oitenta":
				_caixa(m, "lanterna", Vector3(w * 0.62, 0.085, 0.03), Vector3(lado * w * 0.5, yl, z))
				_caixa(m, "preto", Vector3(w * 0.64, 0.1, 0.02), Vector3(lado * w * 0.5, yl, z + 0.008))
			"noventa":
				_lente(m, "lanterna", Vector3(w * 0.36, 0.08, 0.05), Vector3(lado * w * 0.62, yl, z + 0.01))
			"moderno":
				_caixa(m, "lanterna", Vector3(w * 0.46, 0.03, 0.03), Vector3(lado * w * 0.58, yl + 0.02, z))
	if era == "oitenta":
		_caixa(m, "preto", Vector3(w * 0.4, 0.06, 0.03), Vector3(0, yl, z))
	_caixa(m, "placa", Vector3(0.32, 0.1, 0.012), Vector3(0, lerpf(lo, yl, 0.35), z - 0.008))
	if ctx["esportivo"]:
		for lado in [1.0, -1.0]:
			_cilindro(m, "cromo", 0.035, 0.12, Vector3(lado * w * 0.45, float(f["low"]) + 0.06, z - 0.03), Vector3(PI / 2, 0, 0))
	_parachoque(m, f, w, z, -1.0, ctx)


static func _lateral(m: MontagemMalha, f: Dictionary, ctx: Dictionary) -> void:
	var rows: Array = f["rows"]
	var zw: float = f["wind"]
	var b := _curva(rows, zw - 0.14)
	var classico: bool = ctx["era"] in ["classico", "setenta"]
	for lado in [1.0, -1.0]:
		# retrovisor e haste
		_lente(m, "preto", Vector3(0.05, 0.07, 0.12), Vector3(lado * (b.x * 0.86 + 0.07), b.y + 0.07, zw - 0.16))
		_caixa(m, "preto", Vector3(0.06, 0.02, 0.03), Vector3(lado * (b.x * 0.86 + 0.03), b.y + 0.05, zw - 0.16))
	# Trechos da lateral fora das caixas de roda (frisos cromados dos antigos).
	if classico:
		var cortes := [float(rows[0][0]) + 0.22]
		var axs: Array = f["axles"].duplicate()
		axs.sort()
		for ax in axs:
			cortes.append(float(ax) - float(f["r"]) * 1.25)
			cortes.append(float(ax) + float(f["r"]) * 1.25)
		cortes.append(float(rows[-1][0]) - 0.22)
		var y: float = lerpf(float(f["lo"]), float(f["hi"]), 0.45)
		for i in range(0, cortes.size() - 1, 2):
			if cortes[i + 1] - cortes[i] <= 0.08:
				continue
			var zc: float = (cortes[i] + cortes[i + 1]) * 0.5
			var xw: float = _curva(rows, zc).x + _alarga(f, zc)
			for lado in [1.0, -1.0]:
				_caixa(m, "cromo", Vector3(0.012, 0.014, cortes[i + 1] - cortes[i]), Vector3(lado * (xw + 0.004), y, zc))
	# Linhas das portas: frestas finas na lateral (za e zb) e maçanetas.
	for zp in [float(f.get("za", 0.5)), float(f.get("zb", -0.5))]:
		var c := _curva(rows, zp)
		var xw: float = c.x + _alarga(f, zp)
		var ya: float = float(f["lo"]) + 0.02
		var yb: float = minf(float(f["hi"]) + 0.05, c.y - 0.03)
		for lado in [1.0, -1.0]:
			_caixa(m, "preto", Vector3(0.006, yb - ya, 0.008), Vector3(lado * (xw + 0.002), (ya + yb) * 0.5, zp))
			_caixa(m, "cromo" if classico else "preto", Vector3(0.012, 0.018, 0.09),
					Vector3(lado * (xw + 0.005), lerpf(ya, yb, 0.82), zp - 0.14))


static func _cacamba(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var zt: float = float(rows[0][0]) + 0.08
	var zc: float = float(f["roof"][0][0]) - 0.25
	var c := _curva(rows, (zt + zc) * 0.5)
	_caixa(m, "interno", Vector3(c.x * 1.62, 0.012, zc - zt), Vector3(0, c.y + 0.012, (zt + zc) * 0.5))


static func _aerofolio(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var z: float = float(rows[0][0]) + 0.18
	var c := _curva(rows, z)
	_caixa(m, MontagemMalha.PINTURA, Vector3(c.x * 1.75, 0.025, 0.24), Vector3(0, c.y + 0.13, z), Vector3(-0.08, 0, 0))
	for lado in [1.0, -1.0]:
		_caixa(m, "preto", Vector3(0.03, 0.13, 0.08), Vector3(lado * c.x * 0.6, c.y + 0.06, z))
