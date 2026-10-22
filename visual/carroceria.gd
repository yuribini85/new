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
## id -> forma com as proporções da época aplicadas (proporcoes()).
static var _finais := {}
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
## carro até ele aprovar, só depois aplicar em todos; decisão 91): os ids
## aprovados um a um e as épocas/categorias liberadas depois da folha da frota.
## O resto usa os GLB. Testes e ferramentas trocam `ativos` e `regras` em
## tempo de execução.
const ATIVOS: Array[String] = ["kanaya_kestrel"]
const LIBERADOS := {
	"classico": ["cupe", "compacto", "seda", "picape", "utilitario"],
	"setenta": ["cupe", "compacto", "seda", "picape", "utilitario"],
	"oitenta": ["cupe", "compacto", "seda", "picape", "utilitario"],
	"noventa": ["cupe", "compacto", "seda", "picape", "utilitario"],
	"moderno": ["cupe", "compacto", "seda", "picape", "utilitario", "pesado"],
}
## Ângulo máximo (graus) entre faces vizinhas que ainda viram superfície lisa.
const SUAVE_GRAUS := 30.0
## Ângulo máximo entre faces de vidro de uma mesma placa (para-brisa, janela).
const VIDRO_GRAUS := 25.0
static var ativos: Array = ATIVOS.duplicate()
static var regras: Dictionary = LIBERADOS.duplicate(true)
## Arquétipos de silhueta (decisão 130, E3; segundo teste com pessoas: "os carros
## têm modelos muito parecidos"): sobre a forma medida, cada tipo clássico ganha
## o traço que o faz reconhecível, sem copiar carro nenhum. Desligado só para
## comparar (tools/folha_arquetipos.gd).
static var arquetipos_ligados := true


## O carro usa o gerado no jogo (tem forma e está nos ativos ou na época e
## categoria liberadas).
static func tem(id: String) -> bool:
	if not tem_forma(id):
		return false
	if id in ativos:
		return true
	if regras.is_empty():
		return false
	var ctx := contexto(_dados_do_carro(id, {}), "")
	return ctx["cat"] in regras.get(ctx["era"], [])


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
	_finais.clear()


static func em_cache(id: String) -> bool:
	return _corpos.has(id)


## O arquétipo do carro pela ficha: época, categoria, tração, escola e
## potência por peso ("" sem arquétipo: fica a forma medida e a época).
static func arquetipo(carro: Dictionary, esc: String) -> String:
	var cat := String(carro.get("categoria", ""))
	var tr := String(carro.get("tracao", ""))
	var ano := int(carro.get("ano", 1990))
	var pp: float = float(carro.get("potencia", 100)) / maxf(float(carro.get("peso", 1000)), 1.0)
	if tr == "RR" and cat in ["compacto", "cupe"] and ano < 1980:
		return "besouro"
	if cat == "cupe" and tr == "FR" and esc == "us" and ano < 1980:
		return "muscle"
	if cat == "cupe" and tr in ["FR", "4WD"] and esc == "jp" and ano >= 1985 and pp > 0.13:
		return "jdm"
	if cat == "compacto" and tr in ["FF", "4WD"] and ano >= 1976 and pp > 0.09:
		return "hot_hatch"
	if cat == "cupe" and tr == "FR" and esc in ["uk", "de", "it", "fr"] and pp > 0.13:
		return "gt"
	if cat == "picape" and tr == "4WD":
		return "picape_4x4"
	if cat == "utilitario":
		return "jipe" if tr == "4WD" else "van"
	return ""


## Contexto de design: época, categoria, escola e se é esportivo.
static func contexto(carro: Dictionary, escola: String) -> Dictionary:
	var ano := int(carro.get("ano", 1990))
	var era := "classico" if ano < 1972 else ("setenta" if ano < 1983 else ("oitenta" if ano < 1993 else ("noventa" if ano < 2004 else "moderno")))
	var cat := String(carro.get("categoria", "cupe"))
	var pp: float = float(carro.get("potencia", 100)) / maxf(float(carro.get("peso", 1000)), 1.0)
	var esportivo: bool = cat == "cupe" and pp > 0.13
	return {"era": era, "cat": cat, "escola": escola, "esportivo": esportivo, "ano": ano, "pp": pp}


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
	var f := forma_final(id, base)
	if f.is_empty():
		return null
	var ctx: Dictionary = f["ctx"]
	var m := MontagemMalha.new()
	if Pesados.tem(id):
		Pesados.montar(m, id, f)  # desenhados um a um, fora das regras
	else:
		_montar(m, f, ctx)
	# Capô, teto e laterais lisos: as facetas da loft (< SUAVE_GRAUS entre si)
	# ganham normal média; vincos e quinas de verdade continuam vivos.
	var malha: ArrayMesh = _vidros_planos(CarroBloco.suavizar_por_angulo(m.malha(), SUAVE_GRAUS, true))
	_corpos[id] = malha
	return malha


## Cada vidro (para-brisa, janela, vigia) vira uma placa plana: as faces de vidro
## vizinhas que fazem menos de VIDRO_GRAUS com a primeira do grupo recebem a
## normal média dele. Lisas mas curvas, as janelas refletiam manchadas.
static func _vidros_planos(malha: ArrayMesh) -> ArrayMesh:
	var cor_vidro: Color = MontagemMalha._attr("vidro")[0]
	var cos_lim := cos(deg_to_rad(VIDRO_GRAUS))
	var nova := ArrayMesh.new()
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var cores = arr[Mesh.ARRAY_COLOR]
		if cores != null:
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var vidros := []  # triângulos de vidro
			var por_aresta := {}
			for t in vs.size() / 3:
				var c: Color = cores[t * 3]
				# a cor do vértice volta em 8 bits: compara com folga
				if absf(c.r - cor_vidro.r) + absf(c.g - cor_vidro.g) + absf(c.b - cor_vidro.b) > 0.01:
					continue
				vidros.append(t)
				for k in 3:
					var a := vs[t * 3 + k].snapped(Vector3.ONE * 1e-4)
					var b := vs[t * 3 + (k + 1) % 3].snapped(Vector3.ONE * 1e-4)
					var chave := [a, b] if [a.x, a.y, a.z] < [b.x, b.y, b.z] else [b, a]
					if not por_aresta.has(chave):
						por_aresta[chave] = []
					por_aresta[chave].append(t)
			var face := func(t: int) -> Vector3:
				return (vs[t * 3 + 1] - vs[t * 3]).cross(vs[t * 3 + 2] - vs[t * 3])
			var visto := {}
			for t0 in vidros:
				if visto.has(t0):
					continue
				var semente: Vector3 = face.call(t0).normalized()
				var grupo := [t0]
				visto[t0] = true
				var soma := Vector3.ZERO
				var i := 0
				while i < grupo.size():
					var t: int = grupo[i]
					i += 1
					soma += face.call(t)
					for k in 3:
						var a := vs[t * 3 + k].snapped(Vector3.ONE * 1e-4)
						var b := vs[t * 3 + (k + 1) % 3].snapped(Vector3.ONE * 1e-4)
						for u in por_aresta[[a, b] if [a.x, a.y, a.z] < [b.x, b.y, b.z] else [b, a]]:
							if not visto.has(u) and face.call(u).normalized().dot(semente) >= cos_lim:
								visto[u] = true
								grupo.append(u)
				var n := soma.normalized()
				for t in grupo:
					for k in 3:
						nrm[t * 3 + k] = n
			arr[Mesh.ARRAY_NORMAL] = nrm
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nova.surface_set_material(s, malha.surface_get_material(s))
		nova.surface_set_name(s, malha.surface_get_name(s))
	for k in malha.get_meta_list():
		nova.set_meta(k, malha.get_meta(k))
	return nova


## O carro montado: nó com a carroceria ("Carroceria", pintura na superfície
## da meta "pintura") e as rodas (Mount_*, meta "lado" e "raio").
static func construir(id: String, base: Dictionary, cor: Color, faixas: Dictionary = {}) -> Node3D:
	var malha := corpo(id, base)
	if malha == null:
		return null
	var f := forma_final(id, base)
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
	# pesados: aro de aço por padrão (o jogador ainda troca na cabine)
	var desenho := Rodas.desenho_de(faixas) if faixas.has("roda") or not Pesados.tem(id) else "aco"
	var movel := Pesados.extras(id)
	if movel != null:
		raiz.add_child(movel)
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


## A forma do carro com as proporções da época (guardada por id).
static func forma_final(id: String, base: Dictionary = {}) -> Dictionary:
	if _finais.has(id):
		return _finais[id]
	var f0 := forma(id)
	if f0.is_empty():
		return {}
	var carro := _dados_do_carro(id, base)
	var ctx := contexto(carro, escola(String(carro.get("fabricante", ""))))
	ctx["arquetipo"] = arquetipo(carro, ctx["escola"]) if arquetipos_ligados else ""
	if ctx["arquetipo"] == "besouro":
		ctx["era"] = "classico"  # faróis redondos nos para-lamas, frisos cromados
	var f := proporcoes(f0, ctx)
	f["ctx"] = ctx
	_finais[id] = f
	return f


## Proporções pela linguagem da época (aprovadas no Kestrel): para-brisa atrás
## do eixo dianteiro (capô longo), estufa baixa de teto reto, laterais chapadas
## e cintura reta nos anos 70/80, rodas rentes ao para-lama e, nos de 2
## portas, a coluna B no fim da porta. Picapes, utilitários e pesados ficam
## como a forma exportada (só as rodas rentes).
static func proporcoes(f0: Dictionary, ctx: Dictionary) -> Dictionary:
	var f := f0.duplicate(true)
	var rows: Array = f["rows"]
	if ctx["cat"] == "picape":
		_proporcoes_picape(f)
		rows = f["rows"]
	elif ctx["cat"] == "utilitario":
		_proporcoes_utilitario(f)
		rows = f["rows"]
	elif ctx["cat"] != "pesado":
		var axf: float = f["axles"][0]
		var axr: float = f["axles"][1]
		var eixos: float = axf - axr
		var reto: bool = ctx["era"] in ["setenta", "oitenta"]
		if reto:
			for i in rows.size():
				var ponta := 0.45 if (i == 0 or i == rows.size() - 1) else 0.75
				rows[i][1] = lerpf(float(rows[i][1]), float(f["W"]) * 0.5 * 0.97, ponta)
		var classico: bool = ctx["era"] == "classico"
		# capô: longo no cupê, médio no sedã (mais longos nos clássicos); o
		# compacto fica com o da forma
		var setenta: bool = ctx["era"] == "setenta"
		var moderno: bool = ctx["era"] == "moderno"
		var recuos := {"cupe": 0.2, "seda": 0.1}
		if classico:
			recuos = {"cupe": 0.32, "seda": 0.18}
		elif setenta:
			recuos = {"cupe": 0.26, "seda": 0.14}
		elif moderno:
			recuos = {"cupe": 0.14, "seda": 0.08}  # cabine mais à frente
		var recuo: float = recuos.get(ctx["cat"], -1.0)
		var zf: float = minf(float(f["wind"]), axf - eixos * recuo) if recuo >= 0.0 else float(f["wind"])
		if reto:
			# cintura reta da traseira ao pé do para-brisa; capô em cunha contínua
			var zt0: float = float(f["back"])
			var cowl := 0.0
			for r in rows:
				if float(r[0]) >= zt0 and float(r[0]) <= float(f["wind"]) + 0.25:
					cowl = maxf(cowl, float(r[2]))
			var nariz: float = rows[-1][2]
			var pneu: float = float(f["r"]) * 2.0 + 0.13  # o capô não desce abaixo do pneu
			for r in rows:
				var z: float = r[0]
				if z >= zf:
					# anos 70: o capô cai devagar e só se inclina perto do bico
					var tc: float = (z - zf) / maxf(float(rows[-1][0]) - zf, 0.01)
					var cunha: float = lerpf(cowl, nariz, pow(tc, 1.5) if setenta else tc)
					if absf(z - axf) < float(f["r"]) * 1.6:
						cunha = maxf(cunha, minf(float(r[2]), pneu))
					r[2] = cunha
				elif z >= zt0:
					r[2] = cowl
				elif setenta and not ctx["esportivo"]:
					r[2] = minf(float(r[2]), cowl + 0.02)  # sem aba: traseira reta
		elif moderno:
			# cintura que sobe para trás; capô curvo que desce até o bico
			var zt0: float = float(f["back"])
			var cowl := 0.0
			for r in rows:
				if float(r[0]) >= zt0 and float(r[0]) <= float(f["wind"]) + 0.25:
					cowl = maxf(cowl, float(r[2]))
			var nariz: float = rows[-1][2]
			var cauda: float = rows[0][0]
			var pneu: float = float(f["r"]) * 2.0 + 0.13
			for r in rows:
				var z: float = r[0]
				if z >= zf:
					var t: float = (z - zf) / maxf(float(rows[-1][0]) - zf, 0.01)
					var capo: float = lerpf(cowl, nariz, pow(t, 1.3))
					if absf(z - axf) < float(f["r"]) * 1.6:
						capo = maxf(capo, minf(float(r[2]), pneu))
					r[2] = capo
				else:
					r[2] = lerpf(cowl, cowl + 0.06, clampf((zf - z) / maxf(zf - cauda, 0.01), 0.0, 1.0))
		elif classico:
			# anos 60: cintura reta, capô que só cai perto do bico (arredondado) e
			# cauda que desce depois do vidro traseiro
			var zt0: float = float(f["back"])
			var cowl := 0.0
			for r in rows:
				if float(r[0]) >= zt0 and float(r[0]) <= float(f["wind"]) + 0.25:
					cowl = maxf(cowl, float(r[2]))
			var nariz: float = rows[-1][2]
			var cauda: float = rows[0][0]
			var pneu: float = float(f["r"]) * 2.0 + 0.13
			for r in rows:
				var z: float = r[0]
				if z >= zf:
					var t: float = (z - zf) / maxf(float(rows[-1][0]) - zf, 0.01)
					var capo: float = lerpf(cowl, nariz, t * t)
					if absf(z - axf) < float(f["r"]) * 1.6:
						capo = maxf(capo, minf(float(r[2]), pneu))
					r[2] = capo
				elif z >= zt0:
					r[2] = cowl
				else:
					r[2] = lerpf(cowl, cowl - 0.07, (zt0 - z) / maxf(zt0 - cauda, 0.01))
		f["wind"] = zf
		var cintura: float = _curva(rows, zf).y
		var altura := 0.0
		var larg := 0.0
		for r in f["roof"]:
			altura = maxf(altura, float(r[2]))
			larg = maxf(larg, float(r[1]))
		var compacto: bool = ctx["cat"] == "compacto"
		var h: float = minf(altura - cintura, 0.42 if ctx["esportivo"] else (0.5 if compacto else 0.47))
		if classico:
			h = minf(h, 0.4 if ctx["esportivo"] else 0.45)
		elif moderno:
			h = minf(h, 0.36 if ctx["esportivo"] else 0.42)  # vidros estreitos
		var yt: float = cintura + h
		var zr0: float = zf - h * (1.9 if moderno else 1.4 if ctx["esportivo"] and setenta else (1.5 if ctx["esportivo"] and not classico else (1.0 if compacto else (1.3 if classico else 1.15))))
		var zt: float = float(f["back"])
		# teto: curto no cupê, longo no sedã; no compacto vai até perto da traseira
		var zr1: float = zr0 - (0.8 if classico and ctx["cat"] == "cupe" else (0.7 if moderno and ctx["cat"] == "cupe" else (0.95 if ctx["cat"] == "cupe" else 1.25)))
		if compacto:
			zr1 = minf(zr0 - 0.6, zt + 0.3)
		var yb: float = _curva(rows, zt).y
		f["roof"] = [
			[lerpf(zt, zr1, 0.5), larg * 0.9, lerpf(yb, yt, 0.55)],
			[zr1, larg * 0.95, yt - 0.01],
			[lerpf(zr1, zr0, 0.5), larg, yt + 0.008],
			[zr0, larg * 0.97, yt - 0.005],
			[lerpf(zr0, zf, 0.5), larg * 0.88, lerpf(yt, cintura, 0.5)],
		]
		f["vidro_frente"] = zr0 + 0.04
		f["vidro_tras"] = zr1 - 0.04
		if setenta and ctx["esportivo"] and ctx["cat"] == "cupe":
			# venezianas no vidro traseiro: [z do teto, y do teto, z da base, y da base]
			f["venezianas"] = [zr1 - 0.06, yt - 0.02, zt + 0.06, lerpf(yb, yt, 0.15), larg]
		if int(f.get("doors", 4)) == 2:
			f["coluna_b"] = float(f.get("zb", 0.0)) + 0.05
	if ctx["cat"] == "pesado":
		return f
	_arquetipo(f, ctx)
	# rodas rentes ao para-lama (a face do pneu quase no alinhamento da lataria)
	for w in f["rodas"]:
		var borda: float = _curva(rows, float(w[3])).x + _alarga(f, float(w[3])) - 0.03 - float(f["r"]) * 0.31
		# no máximo 4 cm para fora: nos de bico baixo o pneu furava o para-lama
		w[1] = signf(float(w[1])) * clampf(borda, absf(float(w[1])), absf(float(w[1])) + 0.04)
	return f


## O traço de cada arquétipo sobre a forma já na proporção da época (antes das
## rodas rentes ao para-lama).
static func _arquetipo(f: Dictionary, ctx: Dictionary) -> void:
	var meia: float = float(f["W"]) * 0.5
	match String(ctx.get("arquetipo", "")):
		"muscle":
			# capô comprido com tomada de ar, teto baixo em fastback e quadril
			# largo e alto sobre a roda de trás
			_recuar_cabine(f, 0.16)
			_baixar_teto(f, 0.05)
			_fastback(f, 0.72)
			_quadril(f, float(f["axles"][1]), 0.06, 0.06)
			f["sx"] = maxf(float(f.get("sx", meia)), meia + 0.05)
			f["tomada_capo"] = true
		"jdm":
			# baixo, para-lamas alargados e asa
			_baixar_teto(f, 0.05)
			f["sx"] = maxf(float(f.get("sx", meia)), meia + 0.1)
			f["aerofolio"] = true
		"besouro":
			_besouro(f)
		"hot_hatch":
			# largo e baixo, aba no fim do teto
			_baixar_teto(f, 0.03)
			f["sx"] = maxf(float(f.get("sx", meia)), meia + 0.08)
			f["aba_teto"] = true
		"gt":
			# capô longo e cabine recuada em fastback
			_recuar_cabine(f, 0.24)
			_baixar_teto(f, 0.04)
			_fastback(f, 0.7)
		"picape_4x4":
			_elevar(f, 0.2, 1.25)
			f["sx"] = maxf(float(f.get("sx", meia)), meia + 0.07)
		"jipe":
			_elevar(f, 0.13, 1.15)
			f["sx"] = maxf(float(f.get("sx", meia)), meia + 0.06)


## Cabine para trás (capô mais comprido): teto, para-brisa e vidros.
static func _recuar_cabine(f: Dictionary, dz: float) -> void:
	for r in f["roof"]:
		r[0] = float(r[0]) - dz
	f["wind"] = float(f["wind"]) - dz
	f["back"] = float(f["back"]) - dz * 0.5
	for k in ["vidro_frente", "vidro_tras", "coluna_b"]:
		if f.has(k):
			f[k] = float(f[k]) - dz


static func _baixar_teto(f: Dictionary, dy: float) -> void:
	for r in f["roof"]:
		r[2] = float(r[2]) - dy


## Vidro traseiro longo e deitado até a tampa: o ponto de trás do teto sobe
## (fração `alto` entre a base e o topo da estufa) e a base desce para trás.
static func _fastback(f: Dictionary, alto: float) -> void:
	var roof: Array = f["roof"]
	if roof.size() < 2:
		return
	var zt: float = float(f["back"]) - 0.12
	var yb: float = _curva(f["rows"], zt).y
	var yt: float = float(roof[1][2])
	roof[0] = [lerpf(zt, float(roof[1][0]), 0.5), float(roof[0][1]), lerpf(yb, yt, alto)]
	f["back"] = zt


## Quadril sobre o eixo `z_eixo`: lataria mais larga (`dw`) e cintura mais alta (`dy`).
static func _quadril(f: Dictionary, z_eixo: float, dw: float, dy: float) -> void:
	var largura: float = float(f["r"]) * 3.0
	for r in f["rows"]:
		var g: float = exp(-pow((float(r[0]) - z_eixo) / largura, 2.0))
		r[1] = float(r[1]) + dw * g
		r[2] = float(r[2]) + dy * g


## Besouro: teto em arco do capô à tampa, capô e traseira caindo arredondados,
## corpo estreito entre para-lamas que saltam sobre as rodas.
static func _besouro(f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var zf: float = f["wind"]
	var zt: float = f["back"]
	var bico: float = rows[-1][0]
	var cauda: float = rows[0][0]
	var cintura: float = _curva(rows, (zf + zt) * 0.5).y
	var altura := 0.0
	var larg := 0.0
	for r in f["roof"]:
		altura = maxf(altura, float(r[2]))
		larg = maxf(larg, float(r[1]))
	var h: float = maxf(altura - cintura, 0.4) + 0.04
	for r in rows:
		var z: float = r[0]
		r[1] = float(r[1]) * 0.9
		if z > zf:
			r[2] = lerpf(cintura, cintura - 0.2, pow((z - zf) / maxf(bico - zf, 0.01), 1.6))
		elif z < zt:
			r[2] = lerpf(cintura, cintura - 0.24, pow((zt - z) / maxf(zt - cauda, 0.01), 1.4))
		else:
			r[2] = cintura
	var arco := []
	for u in [0.12, 0.3, 0.5, 0.7, 0.88]:
		var z: float = lerpf(zt, zf, u)
		var s: float = pow(sin(PI * u), 0.55)
		arco.append([z, larg * lerpf(0.82, 1.0, s), cintura + h * s])
	f["roof"] = arco
	f["vidro_frente"] = lerpf(zt, zf, 0.76)
	f["vidro_tras"] = lerpf(zt, zf, 0.2)
	f["sx"] = float(f["W"]) * 0.5 + 0.1
	f["hi"] = minf(float(f["hi"]), cintura - 0.1)


## Suspensão alta e rodas maiores (fora de estrada): o carro sobe `dy` e o raio
## da roda cresce `fator`.
static func _elevar(f: Dictionary, dy: float, fator: float) -> void:
	var r0: float = f["r"]
	var r1: float = r0 * fator
	var sobe: float = dy + (r1 - r0)
	for r in f["rows"]:
		r[2] = float(r[2]) + sobe
	for r in f["roof"]:
		r[2] = float(r[2]) + sobe
	for k in ["low", "lo", "hi", "lanterna_vertical"]:
		if f.has(k):
			f[k] = float(f[k]) + sobe
	if f.has("cacamba"):
		f["cacamba"][2] = float(f["cacamba"][2]) + sobe
	if f.has("rack"):
		f["rack"][2] = float(f["rack"][2]) + sobe
	f["r"] = r1
	for w in f["rodas"]:
		w[2] = r1


## Picape (aprovada na Kanaya Sulco): capô de verdade, cabine simples de
## parede traseira reta e caçamba aberta. A cintura é reta na altura da beira
## da caçamba; o assoalho da caçamba fica `FUNDO` abaixo dela.
const FUNDO := 0.3


static func _proporcoes_picape(f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var axf: float = f["axles"][0]
	var axr: float = f["axles"][1]
	var eixos: float = axf - axr
	var r: float = f["r"]
	# cintura: a beira da caçamba (o meio da forma), nunca abaixo do pneu
	var cintura: float = maxf(_curva(rows, (axf + axr) * 0.5).y, r * 2.0 + 0.3)
	var zf: float = axf - eixos * 0.12  # pé do para-brisa logo atrás da roda
	var altura := 0.0
	var larg := 0.0
	for p in f["roof"]:
		altura = maxf(altura, float(p[2]))
		larg = maxf(larg, float(p[1]))
	var h: float = clampf(altura - cintura, 0.45, 0.58)
	var yt: float = cintura + h
	var zr0: float = zf - h * 0.75
	var zr1: float = zr0 - 0.8  # teto da cabine simples
	var zt: float = zr1 - 0.08  # parede traseira quase reta
	var cauda: float = rows[0][0]
	var bico: float = rows[-1][0]
	var nariz: float = maxf(float(rows[-1][2]), cintura - 0.12)
	var novas := []
	for p in rows:
		var z: float = p[0]
		if z > zt + 0.03:
			var t: float = clampf((z - zf) / maxf(bico - zf, 0.01), 0.0, 1.0)
			novas.append([z, p[1], lerpf(cintura, nariz, t * t)])
		elif z < zt - 0.03:
			novas.append([z, p[1], cintura - FUNDO])
	var wz: float = _curva(rows, zt).x
	novas.append([zt + 0.02, wz, cintura])
	novas.append([zt - 0.02, wz, cintura - FUNDO])
	f["cortes"] = [zt + 0.02, zt - 0.02]
	novas.sort_custom(func(a, b): return a[0] < b[0])
	f["rows"] = novas
	f["hi"] = minf(float(f["hi"]), cintura - FUNDO - 0.05)
	f["wind"] = zf
	f["back"] = zt + 0.03
	f["roof"] = [
		[zt + 0.05, larg * 0.95, yt - 0.02],
		[lerpf(zr1, zr0, 0.3), larg, yt],
		[lerpf(zr1, zr0, 0.7), larg, yt],
		[zr0, larg * 0.97, yt - 0.01],
		[lerpf(zr0, zf, 0.5), larg * 0.9, lerpf(yt, cintura, 0.5)],
	]
	f["vidro_frente"] = zr0 + 0.04
	f["za"] = zf - 0.02
	f["zb"] = zt + 0.1
	f["coluna_b"] = 99.0  # cabine simples: sem coluna no meio
	f["cacamba"] = [cauda + 0.02, zt - 0.02, cintura]
	f["lanterna_vertical"] = cintura
	f["parede_tras"] = true


## Utilitário (jipe/SUV, aprovado no Kanaya Chapada): caixote de dois volumes,
## capô médio e reto, para-brisa quase em pé, teto reto até a traseira, parede
## de trás reta com vidro, estepe na tampa e rack no teto.
static func _proporcoes_utilitario(f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var axf: float = f["axles"][0]
	var axr: float = f["axles"][1]
	var eixos: float = axf - axr
	var r: float = f["r"]
	var cintura: float = maxf(_curva(rows, (axf + axr) * 0.5).y, r * 2.0 + 0.3)
	var zf: float = axf - eixos * 0.15
	var altura := 0.0
	var larg := 0.0
	for p in f["roof"]:
		altura = maxf(altura, float(p[2]))
		larg = maxf(larg, float(p[1]))
	var h: float = clampf(altura - cintura, 0.5, 0.62)
	var yt: float = cintura + h
	var zr0: float = zf - h * 0.5
	var cauda: float = rows[0][0]
	var bico: float = rows[-1][0]
	var nariz: float = maxf(float(rows[-1][2]), cintura - 0.1)
	for i in rows.size():
		var p: Array = rows[i]
		var z: float = p[0]
		var ponta := 0.5 if (i == 0 or i == rows.size() - 1) else 0.8
		p[1] = lerpf(float(p[1]), float(f["W"]) * 0.5 * 0.97, ponta)  # laterais chapadas
		if z > zf:
			var t: float = clampf((z - zf) / maxf(bico - zf, 0.01), 0.0, 1.0)
			p[2] = lerpf(cintura, nariz, t * t)
		else:
			p[2] = cintura
	f["hi"] = minf(float(f["hi"]), cintura - 0.08)
	var zt: float = cauda + 0.03
	f["wind"] = zf
	f["back"] = zt
	f["roof"] = [
		[zt + 0.04, larg * 0.96, yt - 0.01],
		[lerpf(zt, zr0, 0.3), larg, yt],
		[lerpf(zt, zr0, 0.7), larg, yt],
		[zr0, larg * 0.97, yt - 0.01],
		[lerpf(zr0, zf, 0.5), larg * 0.92, lerpf(yt, cintura, 0.5)],
	]
	f["vidro_frente"] = zr0 + 0.04
	f["lanterna_vertical"] = cintura + 0.12
	f["parede_tras"] = true
	f["estepe"] = true
	f["rack"] = [zr0 - 0.1, zt + 0.15, yt, larg]


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
	# o para-lama cobre o pneu: perto dos eixos a lataria sobe até passar da roda
	var r: float = f["r"]
	var perto := 0.0
	for ax in f["axles"]:
		var d: float = (z - float(ax)) / (r * 1.5)
		perto = maxf(perto, exp(-d * d * 2.0))
	topo = maxf(topo, lerpf(topo, r * 2.0 + 0.11, perto))
	var hi: float = maxf(minf(f["hi"], topo - 0.05), lerpf(0.0, r * 2.0 + 0.03, perto))
	var wf := w + _alarga(f, z)
	var reto: bool = ctx["era"] in ["setenta", "oitenta"] or ctx["cat"] in ["utilitario", "picape", "pesado"]
	var p := PackedVector2Array()
	p.append(Vector2(0.0, low))
	p.append(Vector2(w * 0.84, low))
	p.append(Vector2(w * 0.93, low + 0.025))
	p.append(Vector2(w * 0.96, lerpf(low, lo, 0.55)))  # soleira recuada
	p.append(Vector2(wf, lo))  # vinco de baixo
	p.append(Vector2(wf * 1.0, lerpf(lo, hi, 0.5)))
	var redondo: bool = ctx["era"] == "classico" and not reto
	# capô mais baixo que os para-lamas (clássicos), só na frente do para-brisa
	var vale: float = 0.04 * clampf((z - float(f["wind"]) - 0.05) / 0.3, 0.0, 1.0) if redondo else 0.0
	p.append(Vector2(wf * (0.995 if reto else (0.97 if redondo else 0.985)), hi))  # ombro
	p.append(Vector2(w * (0.975 if reto else (0.9 if redondo else 0.95)), lerpf(hi, topo, 0.65 if redondo else 0.6)))
	p.append(Vector2(w * (0.94 if reto else (0.74 if redondo else 0.86)), topo - 0.01))
	p.append(Vector2(w * (0.52 if redondo else 0.66), topo + 0.006 - vale * 0.6))
	p.append(Vector2(w * 0.33, topo + 0.014 - vale))
	p.append(Vector2(0.0, topo + 0.018 - vale))
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
	_frente(m, f, secoes[-1], ctx)
	_traseira(m, f, secoes[0], ctx)
	_lateral(m, f, ctx)
	if ctx["cat"] == "picape":
		_cacamba(m, f)
	if f.has("venezianas"):
		_venezianas(m, f)
	if ctx["cat"] == "utilitario":
		_fora_de_estrada(m, f, secoes)
	if f.get("tomada_capo", false):
		_tomada_capo(m, f)
	if f.get("aba_teto", false):
		_aba_teto(m, f)
	if f.get("aerofolio", false):
		_aerofolio(m, f)
	elif ctx["esportivo"] and ctx["era"] in ["setenta", "oitenta"]:
		_aba_traseira(m, f)
	elif ctx["esportivo"] and ctx["era"] == "noventa":
		_aerofolio(m, f)
	elif ctx["esportivo"] and ctx["era"] == "moderno":
		# aerofólio só nos muito fortes; nos outros, aba na tampa
		if float(ctx.get("pp", 0.0)) > 0.4:
			_aerofolio(m, f)
		else:
			_aba_traseira(m, f)
	_pincas(m, f)


## Seções da lataria (de trás para a frente): o perfil de _perfil em N
## estações, mais densas nas pontas; as pontas se arredondam.
static func _secoes(f: Dictionary, ctx: Dictionary) -> Array:
	var rows: Array = f["rows"]
	var z0: float = rows[0][0]
	var z1: float = rows[-1][0]
	var secoes := []
	var zs := []
	for i in N:
		var u := float(i) / (N - 1)
		zs.append(lerpf(z0, z1, 0.5 - 0.5 * cos(u * PI)))
	# degraus pedidos pela forma (o pé da caçamba): uma seção em cada lado
	for zc in f.get("cortes", []):
		zs.append(float(zc))
	zs.sort()
	for i in zs.size():
		var z: float = zs[i]
		var u := float(i) / (zs.size() - 1)
		var c := _curva(rows, z)
		var perf := _perfil(c.x, c.y, f, z, ctx)
		# pontas: a frente e a traseira se arredondam (mais nos modernos)
		var ponta := pow(absf(u * 2.0 - 1.0), 10.0)
		var e := 1.0 - ponta * (0.08 if ctx["cat"] == "picape" else (0.16 if ctx["era"] in ["setenta", "oitenta"] else 0.24))
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
				MontagemMalha.xf(Vector3(x - signf(x) * 0.19, float(w[2]) + 0.02, float(w[3])), Vector3(0, 0, PI / 2)))


static func _cabine(m: MontagemMalha, f: Dictionary, ctx: Dictionary) -> void:
	var rows: Array = f["rows"]
	var roof: Array = f["roof"]
	var zf: float = f["wind"]
	var zt: float = f["back"]
	if f.get("parede_tras", false):
		zt = maxf(zt, float(roof[0][0]) - 0.15)
	var bf := _curva(rows, zf)
	var bt := _curva(rows, zt)
	# picape: a parede de trás da cabine sobe reta até o teto
	var tras: Array = [zt, roof[0][1], roof[0][2]] if f.get("parede_tras", false) else [zt, bt.x * 0.84, bt.y]
	var cima := [tras] + roof + [[zf, bf.x * 0.84, bf.y]]
	cima.sort_custom(func(a, b): return a[0] < b[0])
	var friso := "cromo" if ctx["era"] in ["classico", "setenta"] else "preto"
	# molduras e colunas pretas a partir dos anos 80
	var moldura: String = "preto" if ctx["era"] in ["oitenta", "noventa", "moderno"] else MontagemMalha.PINTURA
	var vf: float = float(f.get("vidro_frente", 99.0))
	var vt: float = float(f.get("vidro_tras", -99.0))
	# Coluna A reta (como nos carros reais): do pé do para-brisa até a frente do
	# teto a linha é reta; a curva só arredondaria o para-brisa e a coluna.
	var zr0: float = vf - 0.04
	var frente_teto: Array = cima[0]
	for p in cima:
		if absf(float(p[0]) - zr0) < absf(float(frente_teto[0]) - zr0):
			frente_teto = p
	var pe_vidro: Array = cima[cima.size() - 1]
	var reta := float(frente_teto[0]) < zf - 0.05 and vf < 90.0
	var n := 16
	var zs := []
	for i in n:
		zs.append(lerpf(zt, zf, float(i) / (n - 1)))
	if reta:
		# a seção mais perto da frente do teto vai para ela: a dobra cai numa aresta
		var mais_perto := 1
		for i in range(1, n - 1):
			if absf(zs[i] - float(frente_teto[0])) < absf(zs[mais_perto] - float(frente_teto[0])):
				mais_perto = i
		zs[mais_perto] = float(frente_teto[0])
	var secs := []
	for i in n:
		var z: float = zs[i]
		var base := _curva(rows, z)
		var top := _curva(cima, z)
		if reta and z >= float(frente_teto[0]):
			var t: float = (z - float(frente_teto[0])) / (zf - float(frente_teto[0]))
			top = Vector2(lerpf(frente_teto[1], pe_vidro[1], t), lerpf(frente_teto[2], pe_vidro[2], t))
		var yb: float = base.y + 0.004
		var wb: float = base.x * 0.8
		var yt: float = maxf(top.y, yb + 0.01)
		var wt: float = minf(top.x * 0.9, wb * 0.86)  # vidro inclinado para dentro
		var meio := 0.62
		secs.append([Vector3(wb, yb, z), Vector3(lerpf(wb, wt, 0.08), lerpf(yb, yt, 0.08), z),
				Vector3(lerpf(wb, wt, meio + 0.3), lerpf(yb, yt, meio + 0.3), z), Vector3(wt, yt, z),
				Vector3(wt * 0.5, yt + 0.022, z), Vector3(0, yt + 0.028, z)])
	var zb_col: float = float(f.get("coluna_b", (float(f.get("za", 0.0)) + float(f.get("zb", 0.0))) * 0.5))
	for lado in [1.0, -1.0]:
		for i in n - 1:
			var a: Array = secs[i]
			var b: Array = secs[i + 1]
			var zm: float = (a[0].z + b[0].z) * 0.5
			var u: float = (zm - zt) / maxf(zf - zt, 0.01)
			var col_c: bool = u < 0.07
			var col_a: bool = u > 0.94
			var col_b: bool = ctx["cat"] != "picape" and absf(zm - zb_col) < 0.05 and u > 0.12 and u < 0.8
			for k in 5:
				var estilo: String
				if k == 0:
					estilo = friso  # moldura de baixo da janela
				elif k == 1:
					estilo = moldura if (col_a or col_b or col_c) else "vidro"
				elif k == 2:
					estilo = "cromo" if ctx["era"] == "classico" else moldura  # moldura de cima da janela
				else:
					estilo = MontagemMalha.PINTURA
				if k >= 3 and (zm > vf or zm < vt):
					estilo = "vidro"  # para-brisa e vigia inclinados
				_quad(m, estilo, [_espelho(a[k], lado), _espelho(a[k + 1], lado), _espelho(b[k], lado),
						_espelho(b[k + 1], lado)], lado)
		# para-brisa e vigia: vidro emoldurado
		for s in [0, n - 1]:
			var a: Array = secs[s]
			var c := Vector3(0, (a[0].y + a[5].y) * 0.5, a[0].z)
			# picape: a parede de trás da cabine é pintada, com um vidro menor
			var parede: bool = s == 0 and f.get("parede_tras", false)
			var aperto := 0.35 if parede else 0.12
			var aro: String = MontagemMalha.PINTURA if parede else moldura
			if parede and lado > 0:
				# a faixa de baixo (entre o centro e a base) também é parede
				var e0 := _espelho(a[0], 1.0)
				var d0 := _espelho(a[0], -1.0)
				m.tri(MontagemMalha.PINTURA, c, e0, d0)
				m.tri(MontagemMalha.PINTURA, c, d0, e0)
				# vidro traseiro retangular, com moldura preta
				var yv: float = lerpf(a[0].y, a[3].y, 0.62)
				var hv: float = (a[3].y - a[0].y) * 0.42
				_caixa(m, "preto", Vector3(a[3].x * 1.5 + 0.04, hv + 0.04, 0.012), Vector3(0, yv, a[0].z - 0.004))
				_caixa(m, "vidro", Vector3(a[3].x * 1.5, hv, 0.014), Vector3(0, yv, a[0].z - 0.006))
			for k in 5:
				var p0 := _espelho(a[k], lado)
				var p1 := _espelho(a[k + 1], lado)
				var p0i := p0.lerp(c, aperto)
				var p1i := p1.lerp(c, aperto)
				for par in [[c, p0i, p1i, aro if parede else "vidro"], [p0i, p0, p1, aro], [p0i, p1, p1i, aro]]:
					if (s == 0) != (lado > 0):
						m.tri(par[3], par[0], par[1], par[2])
					else:
						m.tri(par[3], par[0], par[2], par[1])
		# forro escuro por dentro da estufa: as frestas mostram o interior, não o fundo
		for i in n - 1:
			for k in 3:
				var q := []
				for p in [secs[i][k], secs[i][k + 1], secs[i + 1][k], secs[i + 1][k + 1]]:
					q.append(Vector3(p.x * 0.93 * lado, p.y - 0.012, p.z))
				m.tri("interno", q[0], q[2], q[3])
				m.tri("interno", q[0], q[3], q[1])


static func _caixa(m: MontagemMalha, estilo: String, tam: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	m.caixa(estilo, tam, MontagemMalha.xf(pos, rot))


## Cilindro deitado em X (como o _cilindro do protótipo), ou com `rot` dada.
static func _cilindro(m: MontagemMalha, estilo: String, raio: float, alt: float, pos: Vector3,
		rot := Vector3(0, 0, PI / 2), lados := 12) -> void:
	m.cilindro(estilo, raio, alt, lados, MontagemMalha.xf(pos, rot))


## Lente: elipsoide achatado na face.
static func _lente(m: MontagemMalha, estilo: String, tam: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	m.esfera(estilo, 0.5, 1.0, 12, 4, MontagemMalha.xf(pos, rot, tam))


## Farol ou lanterna redondos: aro e lente (a lente a `dz` do aro).
static func _redondo(m: MontagemMalha, raio: float, pos: Vector3, aro: String, lente: String, dz := 0.012) -> void:
	m.cilindro(aro, raio, 0.04, 12, MontagemMalha.xf(pos, Vector3(PI / 2, 0, 0)))
	m.esfera(lente, raio * 0.88, raio * 0.7, 12, 2, MontagemMalha.xf(pos + Vector3(0, 0, dz), Vector3(PI / 2, 0, 0)))


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
		if ctx["cat"] == "utilitario":
			# faróis quadrados nas pontas da grade
			_caixa(m, "preto", Vector3(w * 0.3, 0.15, 0.025), Vector3(lado * w * 0.73, yl, z - 0.002))
			_caixa(m, "farol", Vector3(w * 0.26, 0.12, 0.03), Vector3(lado * w * 0.73, yl, z + 0.002))
			_caixa(m, "seta", Vector3(w * 0.12, 0.05, 0.03), Vector3(lado * w * 0.73, yl - 0.11, z + 0.002))
			continue
		match era:
			"classico":
				# faróis redondos grandes nas pontas dos para-lamas
				var raio: float = clampf(w * 0.2, 0.08, 0.125)
				var yf: float = clampf(lerpf(lo, topo, 0.72), lo + 0.08, topo - raio * 0.6)
				_redondo(m, raio, Vector3(lado * w * 0.64, yf, z - 0.01), "cromo", "farol")
			"setenta":
				# quatro faróis redondos dentro da grade preta larga
				var raio: float = clampf(w * 0.11, 0.05, 0.075)
				for k in 2:
					_redondo(m, raio, Vector3(lado * w * (0.8 - 0.24 * k), yl, z + 0.01), "cromo", "farol")
			"oitenta":
				if ctx["esportivo"]:
					# farol escamoteável fechado: a tampa no capô, com a fresta em volta
					var zc: float = z - 0.17
					var yc: float = _curva(f["rows"], zc).y
					var incl: float = atan2(yc - _curva(f["rows"], zc + 0.1).y, 0.1)
					_caixa(m, "preto", Vector3(w * 0.4, 0.012, 0.25), Vector3(lado * w * 0.56, yc + 0.006, zc), Vector3(incl, 0, 0))
					_caixa(m, MontagemMalha.PINTURA, Vector3(w * 0.37, 0.02, 0.225), Vector3(lado * w * 0.56, yc + 0.012, zc), Vector3(incl, 0, 0))
				else:
					_caixa(m, "farol", Vector3(w * 0.42, 0.1, 0.03), Vector3(lado * w * 0.56, yl, z))
					_caixa(m, "preto", Vector3(w * 0.4, 0.105, 0.025), Vector3(lado * w * 0.56, yl, z - 0.01))
			"noventa":
				_lente(m, "farol", Vector3(w * 0.4, 0.085, 0.06), Vector3(lado * w * 0.6, yl, z - 0.01), Vector3(0, 0, lado * 0.12))
			"moderno":
				# farol fino puxado para trás, dobrando no para-lama
				var yf: float = lerpf(yl, topo, 0.45)
				_caixa(m, "preto", Vector3(w * 0.6, 0.075, 0.04), Vector3(lado * w * 0.6, yf, z), Vector3(0, -lado * 0.18, lado * 0.1))
				_caixa(m, "farol", Vector3(w * 0.56, 0.04, 0.045), Vector3(lado * w * 0.6, yf + 0.01, z + 0.006), Vector3(0, -lado * 0.18, lado * 0.1))
				_caixa(m, "farol", Vector3(w * 0.4, 0.014, 0.05), Vector3(lado * w * 0.58, yf - 0.028, z + 0.008), Vector3(0, -lado * 0.18, lado * 0.1))  # luz diurna
		# seta (nos anos 80 fica no para-choque)
		if not era in ["oitenta", "moderno"]:
			_caixa(m, "seta", Vector3(0.06, 0.03, 0.02), Vector3(lado * w * 0.86, lerpf(lo, yl, 0.4), z - 0.01))
	# grade
	var gw: float = w * (0.9 if esc == "us" else (0.55 if esc in ["de", "uk"] else 0.75))
	var gh: float = clampf((yl - lo) * 0.9, 0.05, 0.14)
	if ctx["cat"] in ["picape", "utilitario"]:
		# picape e utilitário: grade larga entre os faróis, com moldura
		var moldura_g: String = "cromo" if era in ["classico", "setenta", "oitenta"] else "preto"
		_caixa(m, moldura_g, Vector3(w * 0.74, 0.15, 0.025), Vector3(0, yl, z - 0.002))
		_caixa(m, "preto", Vector3(w * 0.68, 0.11, 0.03), Vector3(0, yl, z))
		for k in 3:
			_caixa(m, moldura_g, Vector3(w * 0.66, 0.008, 0.035), Vector3(0, yl - 0.03 + 0.03 * k, z + 0.002))
	elif era == "classico" and esc == "us":
		_caixa(m, "cromo", Vector3(gw * 2.0, gh, 0.03), Vector3(0, lerpf(lo, yl, 0.5), z))
		for k in 7:
			_caixa(m, "preto", Vector3(gw * 2.0 - 0.04, 0.008, 0.035), Vector3(0, lerpf(lo, yl, 0.5) - gh * 0.4 + gh * 0.8 * k / 6.0, z + 0.002))
	elif era == "setenta" and ctx["cat"] != "picape":
		# grade preta de ponta a ponta, com moldura cromada
		_caixa(m, "cromo", Vector3(w * 1.86, 0.17, 0.02), Vector3(0, yl, z - 0.004))
		_caixa(m, "preto", Vector3(w * 1.8, 0.14, 0.025), Vector3(0, yl, z))
		for k in 4:
			_caixa(m, "cromo", Vector3(w * 0.6, 0.006, 0.03), Vector3(0, yl - 0.045 + 0.03 * k, z + 0.002))
	elif era == "classico":
		# grade oval com moldura cromada
		var yg: float = lerpf(lo, yl, 0.5)
		_lente(m, "cromo", Vector3(gw * 1.5 + 0.05, gh + 0.04, 0.07), Vector3(0, yg, z - 0.01))
		_caixa(m, "preto", Vector3(gw * 1.3, gh * 0.8, 0.04), Vector3(0, yg, z + 0.005))
		for k in 3:
			_caixa(m, "cromo", Vector3(gw * 1.3, 0.008, 0.02), Vector3(0, yg - gh * 0.25 + gh * 0.25 * k, z + 0.035))
	elif era == "oitenta" and ctx["esportivo"]:
		# grade fina entre os faróis escamoteáveis
		_caixa(m, "preto", Vector3(w * 1.3, 0.025, 0.03), Vector3(0, yl, z))
		_caixa(m, "preto", Vector3(w * 1.3, 0.025, 0.03), Vector3(0, yl - 0.045, z))
	elif era != "moderno" or not ctx["esportivo"]:
		_caixa(m, "preto", Vector3(gw * (0.9 if era in ["oitenta", "noventa"] else 1.0), gh * 0.7, 0.03), Vector3(0, lerpf(lo, yl, 0.5), z))
		if era in ["classico", "setenta"]:
			_caixa(m, "cromo", Vector3(gw + 0.02, gh * 0.7 + 0.02, 0.025), Vector3(0, lerpf(lo, yl, 0.5), z - 0.005))
	else:
		_caixa(m, "preto", Vector3(w * 1.2, 0.08, 0.03), Vector3(0, lo - 0.02, z))  # entrada de ar baixa
	if era == "moderno" and ctx["cat"] != "picape":
		# tomadas de ar: central larga e duas laterais, grade fina em cima
		var yb: float = lerpf(float(f["low"]), lo, 0.6)
		_caixa(m, "preto", Vector3(w * 0.9, 0.13, 0.03), Vector3(0, yb + 0.04, z + 0.004))
		for lado in [1.0, -1.0]:
			_caixa(m, "preto", Vector3(w * 0.32, 0.1, 0.03), Vector3(lado * w * 0.72, yb + 0.03, z + 0.002), Vector3(0, 0, -lado * 0.15))
		_caixa(m, "preto", Vector3(w * 0.5, 0.035, 0.03), Vector3(0, lerpf(yl, topo, 0.3), z + 0.002))
	_parachoque(m, f, w, z, 1.0, ctx)


static func _parachoque(m: MontagemMalha, f: Dictionary, w: float, z: float, frente: float, ctx: Dictionary) -> void:
	var low: float = f["low"]
	var y := low + 0.09
	match String(ctx["era"]):
		"classico":
			# lâmina cromada fina com garras
			_caixa(m, "cromo", Vector3(w * 1.95, 0.05, 0.06), Vector3(0, y, z + frente * 0.025))
			for lado in [1.0, -1.0]:
				_caixa(m, "cromo", Vector3(0.035, 0.13, 0.08), Vector3(lado * w * 0.36, y + 0.02, z + frente * 0.035))
		"setenta":
			# lâmina cromada com faixa de borracha e garras
			_caixa(m, "cromo", Vector3(w * 2.02, 0.08, 0.08), Vector3(0, y, z + frente * 0.025))
			_caixa(m, "borracha", Vector3(w * 2.03, 0.025, 0.085), Vector3(0, y, z + frente * 0.027))
			for lado in [1.0, -1.0]:
				_caixa(m, "borracha", Vector3(0.05, 0.12, 0.09), Vector3(lado * w * 0.42, y + 0.01, z + frente * 0.045))
		"oitenta":
			_caixa(m, "borracha", Vector3(w * 2.02, 0.1, 0.11), Vector3(0, y + 0.02, z + frente * 0.015))
			_caixa(m, "preto", Vector3(w * 1.7, 0.045, 0.06), Vector3(0, low + 0.025, z - frente * 0.02))
			if frente > 0:
				_caixa(m, "interno", Vector3(w * 1.1, 0.03, 0.02), Vector3(0, y + 0.01, z + 0.07))  # tomada de ar
				for lado in [1.0, -1.0]:
					_caixa(m, "seta", Vector3(w * 0.22, 0.035, 0.02), Vector3(lado * w * 0.78, y + 0.03, z + 0.07))
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
	if f.has("lanterna_vertical"):
		var topo_c: float = f["lanterna_vertical"]
		for lado in [1.0, -1.0]:
			_caixa(m, "lanterna", Vector3(0.07, 0.2, 0.03), Vector3(lado * (w - 0.06), topo_c - 0.16, z - 0.006))
			_caixa(m, "preto", Vector3(0.08, 0.21, 0.02), Vector3(lado * (w - 0.06), topo_c - 0.16, z + 0.004))
		_caixa(m, "preto", Vector3(0.2, 0.03, 0.02), Vector3(0, topo_c - 0.07, z - 0.006))  # puxador da tampa
		era = "picape"
	for lado in [1.0, -1.0]:
		match era:
			"classico":
				_redondo(m, 0.06, Vector3(lado * w * 0.66, yl, z), "cromo", "lanterna", -0.012)
				_caixa(m, "seta", Vector3(0.05, 0.035, 0.02), Vector3(lado * w * 0.42, yl, z - 0.008))
			"setenta":
				# lanternas largas com moldura cromada
				_caixa(m, "cromo", Vector3(w * 0.6, 0.11, 0.02), Vector3(lado * w * 0.6, yl, z + 0.004))
				_caixa(m, "lanterna", Vector3(w * 0.56, 0.085, 0.03), Vector3(lado * w * 0.6, yl, z - 0.004))
				_caixa(m, "re", Vector3(w * 0.1, 0.085, 0.032), Vector3(lado * w * 0.38, yl, z - 0.005))
			"oitenta":
				_caixa(m, "lanterna", Vector3(w * 0.5, 0.075, 0.03), Vector3(lado * w * 0.62, yl, z - 0.006))
				_caixa(m, "seta", Vector3(w * 0.12, 0.075, 0.03), Vector3(lado * w * 0.3, yl, z - 0.006))
				_caixa(m, "re", Vector3(w * 0.1, 0.075, 0.03), Vector3(lado * w * 0.17, yl, z - 0.006))
			"noventa":
				_lente(m, "lanterna", Vector3(w * 0.36, 0.08, 0.05), Vector3(lado * w * 0.62, yl, z + 0.01))
			"moderno":
				# lanterna fina que dobra no canto
				var yt2: float = lerpf(yl, topo, 0.4)
				_caixa(m, "preto", Vector3(w * 0.5, 0.06, 0.03), Vector3(lado * w * 0.62, yt2, z + 0.004), Vector3(0, lado * 0.3, 0))
				_caixa(m, "lanterna", Vector3(w * 0.48, 0.025, 0.035), Vector3(lado * w * 0.62, yt2, z - 0.002), Vector3(0, lado * 0.3, 0))
	if era == "oitenta":
		_caixa(m, "preto", Vector3(w * 1.92, 0.11, 0.025), Vector3(0, yl, z))  # painel de ponta a ponta
	if era == "moderno" and ctx["cat"] != "picape":
		# filete de luz entre as lanternas e difusor com aletas
		_caixa(m, "lanterna", Vector3(w * 0.7, 0.012, 0.03), Vector3(0, lerpf(yl, topo, 0.4), z - 0.002))
		var yd: float = float(f["low"]) + 0.07
		_caixa(m, "preto", Vector3(w * 1.6, 0.12, 0.06), Vector3(0, yd, z + 0.01))
		for k in 5:
			_caixa(m, "preto", Vector3(0.015, 0.1, 0.12), Vector3(w * (-0.5 + 0.25 * k), yd - 0.01, z - 0.02))
	_caixa(m, "placa", Vector3(0.32, 0.1, 0.012), Vector3(0, lerpf(lo, yl, 0.35), z - 0.008))
	if ctx["esportivo"]:
		for lado in [1.0, -1.0]:
			var saidas: Array = [0.62, 0.74] if era == "moderno" else [0.45]
			for xs in saidas:
				_cilindro(m, "cromo", 0.035, 0.12, Vector3(lado * w * xs, float(f["low"]) + 0.06, z - 0.03), Vector3(PI / 2, 0, 0), 8)
	_parachoque(m, f, w, z, -1.0, ctx)


static func _lateral(m: MontagemMalha, f: Dictionary, ctx: Dictionary) -> void:
	var rows: Array = f["rows"]
	var zw: float = f["wind"]
	var b := _curva(rows, zw - 0.14)
	var classico: bool = ctx["era"] in ["classico", "setenta"]
	for lado in [1.0, -1.0]:
		if ctx["era"] == "classico":
			# retrovisor redondo cromado no para-lama
			var zm: float = zw + 0.45
			var bm := _curva(rows, zm)
			_cilindro(m, "cromo", 0.014, 0.05, Vector3(lado * bm.x * 0.8, bm.y + 0.025, zm), Vector3.ZERO, 6)
			_cilindro(m, "cromo", 0.045, 0.03, Vector3(lado * bm.x * 0.8, bm.y + 0.075, zm), Vector3(PI / 2, lado * 0.3, 0), 8)
			continue
		# retrovisor preso na porta: base, haste e espelho
		var xb: float = b.x * 0.9
		_caixa(m, "preto", Vector3(0.03, 0.05, 0.12), Vector3(lado * (xb + 0.01), b.y + 0.025, zw - 0.12))
		_caixa(m, "preto", Vector3(0.07, 0.018, 0.035), Vector3(lado * (xb + 0.05), b.y + 0.05, zw - 0.13))
		var cor_esp: String = "cromo" if ctx["era"] == "setenta" else "preto"
		_caixa(m, cor_esp, Vector3(0.045, 0.065, 0.11), Vector3(lado * (xb + 0.095), b.y + 0.065, zw - 0.13), Vector3(0, lado * 0.2, 0))
	# saia preta entre as rodas (80/90) e friso de borracha na porta (80)
	if ctx["era"] in ["oitenta", "noventa"]:
		var axs: Array = f["axles"].duplicate()
		axs.sort()
		var zs0: float = float(axs[0]) + float(f["r"]) * 1.25
		var zs1: float = float(axs[1]) - float(f["r"]) * 1.25
		var zm: float = (zs0 + zs1) * 0.5
		var cs := _curva(rows, zm)
		for lado in [1.0, -1.0]:
			_caixa(m, "preto", Vector3(0.04, 0.07, zs1 - zs0), Vector3(lado * cs.x * 0.95, float(f["low"]) + 0.06, zm))
			if ctx["era"] == "oitenta":
				_caixa(m, "borracha", Vector3(0.016, 0.035, zs1 - zs0 - 0.06),
						Vector3(lado * (cs.x + _alarga(f, zm) + 0.006), lerpf(float(f["lo"]), float(f["hi"]), 0.5), zm))
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


## Caçamba aberta: assoalho emborrachado, laterais, parede da frente e tampa
## traseira pintadas, com a beira na altura da cintura.
static func _cacamba(m: MontagemMalha, f: Dictionary) -> void:
	if not f.has("cacamba"):
		return
	var cb: Array = f["cacamba"]
	var z0: float = cb[0]
	var z1: float = cb[1]
	var topo: float = cb[2]
	var zm: float = (z0 + z1) * 0.5
	var c := _curva(f["rows"], zm)
	var w: float = c.x * 0.95
	var piso: float = topo - FUNDO
	var e := 0.05
	_caixa(m, "borracha", Vector3(w * 2.0 - e * 2.0, 0.012, z1 - z0 - e), Vector3(0, piso + 0.025, zm))
	for lado in [1.0, -1.0]:
		_caixa(m, MontagemMalha.PINTURA, Vector3(e, FUNDO, z1 - z0), Vector3(lado * (w - e * 0.5), piso + FUNDO * 0.5, zm))
		# beira com friso
		_caixa(m, "preto", Vector3(e + 0.01, 0.015, z1 - z0), Vector3(lado * (w - e * 0.5), topo + 0.007, zm))
	_caixa(m, MontagemMalha.PINTURA, Vector3(w * 2.0, FUNDO, e), Vector3(0, piso + FUNDO * 0.5, z1 - e * 0.5))
	_caixa(m, MontagemMalha.PINTURA, Vector3(w * 2.0, FUNDO, e), Vector3(0, piso + FUNDO * 0.5, z0 + e * 0.5))
	_caixa(m, "preto", Vector3(w * 2.0, 0.015, e + 0.01), Vector3(0, topo + 0.007, z0 + e * 0.5))


static func _aerofolio(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var z: float = float(rows[0][0]) + 0.18
	var c := _curva(rows, z)
	_caixa(m, MontagemMalha.PINTURA, Vector3(c.x * 1.75, 0.025, 0.24), Vector3(0, c.y + 0.13, z), Vector3(-0.08, 0, 0))
	for lado in [1.0, -1.0]:
		_caixa(m, "preto", Vector3(0.03, 0.13, 0.08), Vector3(lado * c.x * 0.6, c.y + 0.06, z))


## Tomada de ar no capô (muscle): caixa pintada com a boca preta para a frente.
static func _tomada_capo(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var zc: float = lerpf(float(f["wind"]), float(rows[-1][0]), 0.4)
	var y: float = _curva(rows, zc).y
	var incl: float = atan2(y - _curva(rows, zc + 0.2).y, 0.2)
	_caixa(m, MontagemMalha.PINTURA, Vector3(0.5, 0.1, 0.7), Vector3(0, y + 0.045, zc), Vector3(incl, 0, 0))
	_caixa(m, "preto", Vector3(0.42, 0.065, 0.02), Vector3(0, y + 0.055, zc + 0.345), Vector3(incl, 0, 0))


## Aba no fim do teto (hot hatch).
static func _aba_teto(m: MontagemMalha, f: Dictionary) -> void:
	var roof: Array = f["roof"].duplicate()
	roof.sort_custom(func(a, b): return a[0] < b[0])
	var p: Array = roof[1] if roof.size() > 1 else roof[0]
	_caixa(m, MontagemMalha.PINTURA, Vector3(float(p[1]) * 1.8, 0.022, 0.2), Vector3(0, float(p[2]) + 0.005, float(p[0]) - 0.12), Vector3(0.18, 0, 0))


## Aba traseira (anos 80): uma lâmina pintada na beira da tampa, levemente erguida.
static func _aba_traseira(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = f["rows"]
	var z: float = float(rows[0][0]) + 0.07
	var c := _curva(rows, z)
	_caixa(m, MontagemMalha.PINTURA, Vector3(c.x * 1.7, 0.022, 0.16), Vector3(0, c.y + 0.035, z + 0.02), Vector3(0.28, 0, 0))


## Venezianas pretas sobre o vidro traseiro (esportivos dos anos 70).
static func _venezianas(m: MontagemMalha, f: Dictionary) -> void:
	var v: Array = f["venezianas"]
	var za: float = v[0]
	var ya: float = v[1]
	var zb: float = v[2]
	var yb: float = v[3]
	var larg: float = v[4]
	var incl: float = atan2(ya - yb, za - zb)
	var n := 6
	for k in n:
		var t: float = (float(k) + 0.5) / n
		var z: float = lerpf(za, zb, t)
		var y: float = lerpf(ya, yb, t) + 0.02
		_caixa(m, "preto", Vector3(larg * 1.7 * lerpf(1.0, 1.15, t), 0.012, 0.05), Vector3(0, y, z), Vector3(-incl, 0, 0))
	for lado in [1.0, -1.0]:
		var zc: float = (za + zb) * 0.5
		_caixa(m, "preto", Vector3(0.025, 0.02, Vector2(za - zb, ya - yb).length()), Vector3(lado * larg * 0.88, (ya + yb) * 0.5 + 0.02, zc), Vector3(-incl, 0, 0))


## Utilitário: estepe na tampa, rack no teto, para-choques robustos e
## molduras pretas nos para-lamas.
static func _fora_de_estrada(m: MontagemMalha, f: Dictionary, secoes: Array) -> void:
	var r: float = f["r"]
	var tras: Dictionary = _face(secoes[0])
	var frente: Dictionary = _face(secoes[-1])
	if f.get("estepe", false):
		var ye: float = float(f.get("lanterna_vertical", 1.0)) + 0.05
		var ze: float = float(tras["z"]) - r * 0.32
		_cilindro(m, "pneu", r * 0.95, r * 0.55, Vector3(0, ye, ze), Vector3(PI / 2, 0, 0), 14)
		_cilindro(m, "aro", r * 0.55, r * 0.58, Vector3(0, ye, ze), Vector3(PI / 2, 0, 0), 10)
	if f.has("rack"):
		var rk: Array = f["rack"]
		var z0: float = rk[0]
		var z1: float = rk[1]
		var y: float = float(rk[2]) + 0.06
		var lg: float = rk[3]
		for lado in [1.0, -1.0]:
			_caixa(m, "preto", Vector3(0.035, 0.03, z0 - z1), Vector3(lado * lg * 0.8, y, (z0 + z1) * 0.5))
			for k in 3:
				_caixa(m, "preto", Vector3(0.03, 0.06, 0.03), Vector3(lado * lg * 0.8, y - 0.03, lerpf(z1, z0, k / 2.0)))
		for k in 2:
			_caixa(m, "preto", Vector3(lg * 1.6, 0.025, 0.035), Vector3(0, y + 0.01, lerpf(z1, z0, 0.3 + 0.4 * k)))
	# para-choques robustos
	var low: float = f["low"]
	for par in [[frente, 1.0], [tras, -1.0]]:
		var fc: Dictionary = par[0]
		_caixa(m, "preto", Vector3(float(fc["w"]) * 2.06, 0.15, 0.14), Vector3(0, low + 0.1, float(fc["z"]) + float(par[1]) * 0.04))
	# molduras dos para-lamas
	for w in f["rodas"]:
		var x: float = w[1]
		var zc: float = w[3]
		var xb: float = _curva(f["rows"], zc).x + _alarga(f, zc) + 0.012
		for k in 7:
			var a: float = PI * (0.12 + 0.76 * k / 6.0)
			_caixa(m, "preto", Vector3(0.05, 0.07, r * 0.5), Vector3(signf(x) * xb, float(w[2]) + cos(a - PI / 2) * r * 1.22, zc - sin(a - PI / 2) * r * 1.22 * -1.0), Vector3(a - PI / 2, 0, 0))
