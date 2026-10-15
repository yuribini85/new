class_name Pesados
extends RefCounted
## Os três pesados, desenhados um a um (pedido do usuário: "melhoria individual
## sem motor"): sem as regras do gerador de carros, cada um com a sua forma,
## no mesmo estilo facetado e na mesma montagem (MontagemMalha: pintura e
## detalhes). As medidas e as rodas vêm de formas.json, como nos outros.
##
## Eixos: +Z frente, chão em y = 0, X para a direita.

const DESENHOS := {
	"brakhaus_coletor": "_coletor",
	"brakhaus_sentinela": "_resgate",
	"brakhaus_colosso": "_mineradora",
}
const PINTURA := MontagemMalha.PINTURA


static func tem(id: String) -> bool:
	return DESENHOS.has(id)


## Peças móveis do pesado (nó a acrescentar ao modelo), ou null. O resgate tem
## o canhão d'água: "Canhao" gira em Y (a arena mira os carros) e o jato
## ("Jato", partículas) liga quando há alvo.
const CANHAO_BASE := Vector3(0, 3.3, 0.3)
const CANHAO_INCL := 0.26  # elevação da lança
const CANHAO_TUBOS := [2.6, 2.4]  # primeiro tubo e o telescópico


static func extras(id: String) -> Node3D:
	if id != "brakhaus_sentinela":
		return null
	var no := Node3D.new()
	no.name = "Canhao"
	no.position = CANHAO_BASE
	var m := MontagemMalha.new()
	var dir := Vector3(0, sin(CANHAO_INCL), cos(CANHAO_INCL))
	var rot := Vector3(PI / 2 - CANHAO_INCL, 0, 0)
	var c1: float = CANHAO_TUBOS[0]
	var c2: float = CANHAO_TUBOS[1]
	_caixa(m, "aro", Vector3(0.3, 0.3, 0.3), Vector3.ZERO)
	_cil(m, "cromo", 0.09, c1, dir * c1 * 0.5, rot, 8)
	_cil(m, "cromo", 0.065, c2, dir * (c1 + c2 * 0.5 - 0.1), rot, 8)
	_cil(m, "aro", 0.1, 0.12, dir * (c1 - 0.05), rot, 8)  # luva
	_cil(m, "cromo", 0.11, 0.3, dir * (c1 + c2 - 0.05), rot, 8)  # bocal
	_caixa(m, "aro", Vector3(0.05, 0.3, 0.05), dir * c1 * 0.55 + Vector3(0, -0.15, 0))  # apoio
	var mi := MeshInstance3D.new()
	mi.name = "Lanca"
	mi.mesh = m.malha()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(mi)
	no.add_child(_jato(dir * (c1 + c2 + 0.1), dir))
	return no


## Jato d'água: partículas no mundo (caem com a gravidade e ficam para trás
## quando o caminhão anda), desligado até haver alvo.
static func _jato(pos: Vector3, dir: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Jato"
	p.position = pos
	p.emitting = false
	p.amount = 160
	p.lifetime = 1.1
	p.local_coords = false
	p.direction = dir
	p.spread = 4.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 21.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.94, 1.0, 0.9))
	g.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	p.color_ramp = g
	return p


static func montar(m: MontagemMalha, id: String, f: Dictionary) -> void:
	var funcao: String = DESENHOS[id]
	Callable(Pesados, funcao).call(m, f)


# ------------------------------------------------------------------ peças

## Sólido convexo de perfil lateral (z, y) extrudado em X de -w a +w. As faces
## saem viradas para fora (o centro do perfil decide o lado).
static func _perfil_x(m: MontagemMalha, estilo: String, perfil: Array, w: float, x0 := 0.0) -> void:
	var c := Vector2.ZERO
	for p in perfil:
		c += p
	c /= perfil.size()
	var centro := Vector3(x0, c.y, c.x)
	var n := perfil.size()
	for i in n:
		var a: Vector2 = perfil[i]
		var b: Vector2 = perfil[(i + 1) % n]
		var a0 := Vector3(x0 - w, a.y, a.x)
		var a1 := Vector3(x0 + w, a.y, a.x)
		var b0 := Vector3(x0 - w, b.y, b.x)
		var b1 := Vector3(x0 + w, b.y, b.x)
		_tri(m, estilo, a0, a1, b1, centro)
		_tri(m, estilo, a0, b1, b0, centro)
	for lado in [-1.0, 1.0]:
		var cc := Vector3(x0 + lado * w, c.y, c.x)
		for i in n:
			var a: Vector2 = perfil[i]
			var b: Vector2 = perfil[(i + 1) % n]
			_tri(m, estilo, cc, Vector3(x0 + lado * w, a.y, a.x), Vector3(x0 + lado * w, b.y, b.x), centro)


## Sólido convexo de seção (x, y) extrudado em Z de z0 a z1, com a seção de
## trás escalada por `afina` (afunila).
static func _secao_z(m: MontagemMalha, estilo: String, secao: Array, z0: float, z1: float, afina := 1.0) -> void:
	var c := Vector2.ZERO
	for p in secao:
		c += p
	c /= secao.size()
	var centro := Vector3(c.x, c.y, (z0 + z1) * 0.5)
	var n := secao.size()
	var tras := func(p: Vector2) -> Vector3: return Vector3(p.x * afina, lerpf(c.y, p.y, afina) if afina != 1.0 else p.y, z0)
	for i in n:
		var a: Vector2 = secao[i]
		var b: Vector2 = secao[(i + 1) % n]
		var a0: Vector3 = tras.call(a)
		var b0: Vector3 = tras.call(b)
		var a1 := Vector3(a.x, a.y, z1)
		var b1 := Vector3(b.x, b.y, z1)
		_tri(m, estilo, a0, a1, b1, centro)
		_tri(m, estilo, a0, b1, b0, centro)
	var cf := Vector3(c.x, c.y, z1)
	var ct := Vector3(c.x, c.y, z0)
	for i in n:
		var a: Vector2 = secao[i]
		var b: Vector2 = secao[(i + 1) % n]
		_tri(m, estilo, cf, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), centro)
		_tri(m, estilo, ct, tras.call(a), tras.call(b), centro)


static func _tri(m: MontagemMalha, estilo: String, a: Vector3, b: Vector3, c: Vector3, centro: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot((a + b + c) / 3.0 - centro) < 0.0:
		m.tri(estilo, a, c, b)
	else:
		m.tri(estilo, a, b, c)


static func _caixa(m: MontagemMalha, estilo: String, tam: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	m.caixa(estilo, tam, MontagemMalha.xf(pos, rot))


static func _cil(m: MontagemMalha, estilo: String, raio: float, alt: float, pos: Vector3, rot := Vector3.ZERO, lados := 10) -> void:
	m.cilindro(estilo, raio, alt, lados, MontagemMalha.xf(pos, rot))


## Para-lama preto em arco sobre a roda (segmentos).
static func _paralama(m: MontagemMalha, x: float, y: float, z: float, r: float, larg: float) -> void:
	for k in 6:
		var a: float = PI * (0.1 + 0.8 * k / 5.0)
		_caixa(m, "borracha", Vector3(larg, 0.04, r * 0.62), Vector3(x, y + sin(a) * r * 1.15, z + cos(a) * r * 1.15), Vector3(-(a - PI / 2), 0, 0))


## Cabine avançada: perfil com para-brisa inclinado, vidros laterais, grade,
## faróis, para-choque, retrovisores e sinalizador.
static func _cabine_avancada(m: MontagemMalha, z0: float, z1: float, base: float, topo: float, w: float, inclina: float, estilo_grade := "preto") -> void:
	var zp: float = z1 - inclina
	var yv: float = lerpf(base, topo, 0.45)  # pé do para-brisa
	_perfil_x(m, PINTURA, [Vector2(z0, base), Vector2(z1, base), Vector2(z1, yv), Vector2(zp, topo), Vector2(z0, topo)], w)
	# para-brisa (sobre a face inclinada)
	var meio := Vector2((z1 + zp) * 0.5, (yv + topo) * 0.5)
	var ang: float = atan2(z1 - zp, topo - yv)
	var comp: float = Vector2(z1 - zp, topo - yv).length()
	_caixa(m, "preto", Vector3(w * 1.94, comp * 0.92, 0.02), Vector3(0, meio.y, meio.x + 0.012), Vector3(-ang, 0, 0))
	_caixa(m, "vidro", Vector3(w * 1.86, comp * 0.84, 0.03), Vector3(0, meio.y, meio.x + 0.02), Vector3(-ang, 0, 0))
	# vidros laterais e fresta da porta
	for lado in [1.0, -1.0]:
		var zl: float = lerpf(z0, zp, 0.62)
		_caixa(m, "preto", Vector3(0.02, (topo - yv) * 0.78, (zp - z0) * 0.62), Vector3(lado * (w + 0.006), lerpf(yv, topo, 0.48), zl))
		_caixa(m, "vidro", Vector3(0.024, (topo - yv) * 0.7, (zp - z0) * 0.56), Vector3(lado * (w + 0.01), lerpf(yv, topo, 0.48), zl))
		_caixa(m, "preto", Vector3(0.02, yv - base - 0.1, 0.02), Vector3(lado * (w + 0.006), (base + yv) * 0.5, z0 + (zp - z0) * 0.3))
		# retrovisor em braço
		_caixa(m, "preto", Vector3(0.35, 0.04, 0.04), Vector3(lado * (w + 0.17), yv + 0.2, z1 - 0.15))
		_caixa(m, "preto", Vector3(0.06, 0.38, 0.16), Vector3(lado * (w + 0.34), yv + 0.12, z1 - 0.15))
	# frente: grade, faróis, para-choque
	var hg: float = yv - base
	_caixa(m, estilo_grade, Vector3(w * 1.1, hg * 0.5, 0.03), Vector3(0, base + hg * 0.55, z1 + 0.015))
	for k in 4:
		_caixa(m, "cromo", Vector3(w * 1.0, 0.018, 0.035), Vector3(0, base + hg * (0.36 + 0.12 * k), z1 + 0.02))
	for lado in [1.0, -1.0]:
		_caixa(m, "preto", Vector3(w * 0.4, hg * 0.24, 0.03), Vector3(lado * w * 0.74, base + hg * 0.32, z1 + 0.012))
		_caixa(m, "farol", Vector3(w * 0.36, hg * 0.18, 0.035), Vector3(lado * w * 0.74, base + hg * 0.32, z1 + 0.016))
		_caixa(m, "seta", Vector3(w * 0.12, hg * 0.12, 0.035), Vector3(lado * w * 0.93, base + hg * 0.52, z1 + 0.016))
	_caixa(m, "borracha", Vector3(w * 2.1, 0.28, 0.22), Vector3(0, base - 0.05, z1 + 0.08))
	# pala e sinalizador
	_caixa(m, "preto", Vector3(w * 1.9, 0.05, 0.28), Vector3(0, topo + 0.02, zp + 0.08))
	for lado in [1.0, -1.0]:
		_caixa(m, "seta", Vector3(0.16, 0.12, 0.16), Vector3(lado * w * 0.6, topo + 0.1, lerpf(z0, zp, 0.6)))


static func _chassi(m: MontagemMalha, z0: float, z1: float, y: float, x: float) -> void:
	for lado in [1.0, -1.0]:
		_caixa(m, "preto", Vector3(0.18, 0.28, z1 - z0), Vector3(lado * x, y, (z0 + z1) * 0.5))


# ------------------------------------------------------------------ coletor

## Coletor de lixo: cabine avançada baixa, compactador facetado com nervuras e
## boca de carga traseira com o vão escuro e os cilindros hidráulicos.
static func _coletor(m: MontagemMalha, f: Dictionary) -> void:
	var r: float = f["r"]
	var wc := 1.2
	_chassi(m, -3.8, 3.7, r + 0.28, 0.45)
	_cabine_avancada(m, 2.05, 4.0, 0.95, 3.0, wc, 0.3)
	# compactador: seção chanfrada, um pouco mais estreita atrás
	var corpo := [Vector2(-1.28, 1.1), Vector2(1.28, 1.1), Vector2(1.3, 2.7), Vector2(1.0, 3.1), Vector2(-1.0, 3.1), Vector2(-1.3, 2.7)]
	_secao_z(m, PINTURA, corpo, -3.35, 1.95, 0.97)
	for k in 6:
		var z: float = lerpf(-3.1, 1.7, k / 5.0)
		for lado in [1.0, -1.0]:
			_caixa(m, PINTURA, Vector3(0.06, 1.5, 0.1), Vector3(lado * 1.31, 1.9, z))
	for lado in [1.0, -1.0]:
		_caixa(m, "placa", Vector3(0.02, 0.12, 5.0), Vector3(lado * 1.34, 1.3, -0.7))  # faixa refletiva
		_caixa(m, "preto", Vector3(0.05, 0.25, 4.0), Vector3(lado * 1.2, 0.95, -0.9))  # saia
	# boca de carga
	_perfil_x(m, PINTURA, [Vector2(-3.35, 0.95), Vector2(-3.35, 3.1), Vector2(-3.85, 2.75), Vector2(-4.05, 1.5), Vector2(-3.95, 0.95)], 1.25)
	_caixa(m, "interno", Vector3(2.0, 0.75, 0.04), Vector3(0, 1.55, -4.05))
	_caixa(m, "preto", Vector3(2.2, 0.06, 0.06), Vector3(0, 1.95, -4.03))
	for lado in [1.0, -1.0]:
		_cil(m, "cromo", 0.06, 1.4, Vector3(lado * 1.28, 2.2, -3.5), Vector3(0.8, 0, 0), 8)
		_caixa(m, "lanterna", Vector3(0.12, 0.3, 0.03), Vector3(lado * 1.05, 1.2, -4.0))
		_caixa(m, "seta", Vector3(0.14, 0.12, 0.14), Vector3(lado * 0.9, 2.85, -3.6))
	_caixa(m, "borracha", Vector3(2.3, 0.08, 0.4), Vector3(0, 0.85, -4.1))  # degrau
	# tanque e para-lamas
	_cil(m, "cromo", 0.28, 0.9, Vector3(-1.05, 0.95, 1.2), Vector3(0, 0, PI / 2), 10)
	for w in f["rodas"]:
		_paralama(m, float(w[1]), float(w[2]), float(w[3]), r, 0.4)


# ------------------------------------------------------------------ resgate

## Resgate: cabine dupla avançada, baú com portas de enrolar, faixa refletiva,
## canhão d'água no teto e barra de luzes.
static func _resgate(m: MontagemMalha, f: Dictionary) -> void:
	var r: float = f["r"]
	var wc := 1.32
	_chassi(m, -4.3, 4.2, r + 0.32, 0.5)
	_cabine_avancada(m, 1.3, 4.5, 1.15, 3.2, wc, 0.28, "preto")
	# segunda fileira de janelas (cabine dupla)
	for lado in [1.0, -1.0]:
		_caixa(m, "preto", Vector3(0.02, 0.62, 0.9), Vector3(lado * (wc + 0.006), 2.55, 1.9))
		_caixa(m, "vidro", Vector3(0.024, 0.56, 0.84), Vector3(lado * (wc + 0.01), 2.55, 1.9))
	# barra de luzes
	_caixa(m, "preto", Vector3(wc * 1.5, 0.12, 0.24), Vector3(0, 3.28, 3.9))
	for k in 4:
		_caixa(m, "lanterna" if k % 2 == 0 else "seta", Vector3(wc * 0.34, 0.1, 0.26), Vector3(wc * (-0.56 + 0.375 * k), 3.3, 3.9))
	# baú
	var bau := [Vector2(-1.42, 1.15), Vector2(1.42, 1.15), Vector2(1.42, 2.95), Vector2(1.25, 3.1), Vector2(-1.25, 3.1), Vector2(-1.42, 2.95)]
	_secao_z(m, PINTURA, bau, -4.5, 1.2)
	for lado in [1.0, -1.0]:
		for k in 4:
			var zc: float = lerpf(-3.85, 0.5, k / 3.0)
			_caixa(m, "aro", Vector3(0.03, 1.3, 1.0), Vector3(lado * 1.43, 2.05, zc))
			for j in 4:
				_caixa(m, "preto", Vector3(0.035, 0.015, 0.96), Vector3(lado * 1.44, 1.6 + 0.3 * j, zc))
		_caixa(m, "placa", Vector3(0.02, 0.1, 5.6), Vector3(lado * 1.44, 1.3, -1.7))
		_caixa(m, "lanterna", Vector3(0.03, 0.08, 5.6), Vector3(lado * 1.44, 1.2, -1.7))
	# canhão d'água e escada no teto
	# torre do canhão d'água (a lança gira: é a peça `canhao`, fora da malha)
	_cil(m, "aro", 0.24, 0.22, Vector3(0, 3.2, CANHAO_BASE.z), Vector3.ZERO, 10)
	for lado in [1.0, -1.0]:
		_caixa(m, "aro", Vector3(0.05, 0.05, 4.4), Vector3(lado * 0.9, 3.22, -2.2))
	for k in 9:
		_caixa(m, "aro", Vector3(1.8, 0.04, 0.04), Vector3(0, 3.22, lerpf(-4.3, -0.1, k / 8.0)))
	# traseira
	for lado in [1.0, -1.0]:
		_caixa(m, "lanterna", Vector3(0.14, 0.4, 0.03), Vector3(lado * 1.25, 1.55, -4.51))
		_caixa(m, "seta", Vector3(0.14, 0.14, 0.03), Vector3(lado * 1.25, 1.95, -4.51))
	_caixa(m, "aro", Vector3(2.4, 1.5, 0.03), Vector3(0, 2.1, -4.51))
	_caixa(m, "borracha", Vector3(2.6, 0.1, 0.45), Vector3(0, 1.0, -4.6))
	for w in f["rodas"]:
		_paralama(m, float(w[1]), float(w[2]), float(w[3]), r, 0.42)


# ------------------------------------------------------------------ mineradora

## Caminhão de mineração: chassi exposto, grade enorme, deque com cabine à
## esquerda e escada, caçamba aberta afunilada com cobertura sobre a cabine,
## cilindros de basculamento e rodado duplo atrás.
static func _mineradora(m: MontagemMalha, f: Dictionary) -> void:
	var r: float = f["r"]
	_chassi(m, -3.6, 4.2, 1.75, 0.85)
	_caixa(m, "preto", Vector3(1.9, 0.7, 2.2), Vector3(0, 2.2, 3.4))  # motor
	# grade e deque
	_caixa(m, "preto", Vector3(2.8, 1.6, 0.25), Vector3(0, 3.0, 4.55))
	for k in 6:
		_caixa(m, "aro", Vector3(2.6, 0.05, 0.05), Vector3(0, 2.35 + 0.26 * k, 4.69))
	_caixa(m, PINTURA, Vector3(5.2, 0.18, 2.9), Vector3(0, 3.9, 3.4))
	for lado in [1.0, -1.0]:
		_caixa(m, PINTURA, Vector3(1.0, 1.4, 2.6), Vector3(lado * 1.95, 3.15, 3.4))  # caixas sobre as rodas
		for k in 2:
			_caixa(m, "farol", Vector3(0.28, 0.2, 0.04), Vector3(lado * (1.6 + 0.4 * k), 3.6, 4.71))
	# corrimão do deque
	for k in 5:
		_caixa(m, "seta", Vector3(0.05, 0.9, 0.05), Vector3(lerpf(-2.55, 2.55, k / 4.0), 4.4, 4.8))
	_caixa(m, "seta", Vector3(5.1, 0.06, 0.06), Vector3(0, 4.85, 4.8))
	# escada diagonal na frente
	for lado in [-0.6, 0.6]:
		_caixa(m, "aro", Vector3(0.05, 0.06, 3.0), Vector3(-1.5 + lado, 2.4, 5.05), Vector3(0.95, 0, 0))
	for k in 6:
		_caixa(m, "aro", Vector3(1.2, 0.04, 0.2), Vector3(-1.5, 1.2 + 0.45 * k, 5.85 - 0.33 * k))
	# cabine à esquerda do deque
	_caixa(m, PINTURA, Vector3(1.6, 1.4, 1.8), Vector3(-1.75, 4.7, 3.5))
	_caixa(m, "vidro", Vector3(1.5, 0.75, 1.84), Vector3(-1.75, 4.95, 3.5))
	_caixa(m, "vidro", Vector3(1.64, 0.75, 1.6), Vector3(-1.75, 4.95, 3.5))
	_caixa(m, "seta", Vector3(0.2, 0.15, 0.2), Vector3(-1.75, 5.5, 3.2))
	# escapes
	for lado in [1.0, -1.0]:
		_cil(m, "preto", 0.12, 1.4, Vector3(lado * 0.7, 4.6, 2.3), Vector3.ZERO, 8)
	# caçamba: piso inclinado, laterais afuniladas, frente alta com cobertura
	var zf := 2.2
	var zt := -4.8
	_perfil_x(m, PINTURA, [Vector2(zt, 3.0), Vector2(zf, 2.6), Vector2(zf, 3.0), Vector2(zt, 3.35)], 2.5)  # piso
	for lado in [1.0, -1.0]:
		_perfil_x(m, PINTURA, [Vector2(zt, 3.0), Vector2(zf, 2.6), Vector2(zf, 5.7), Vector2(zt + 0.8, 4.8), Vector2(zt, 4.0)], 0.12, lado * 2.6)
		for k in 5:
			_caixa(m, PINTURA, Vector3(0.16, 1.7, 0.18), Vector3(lado * 2.72, 3.9, lerpf(zt + 0.6, zf - 0.4, k / 4.0)))
	_perfil_x(m, PINTURA, [Vector2(zf - 0.2, 2.6), Vector2(zf, 2.6), Vector2(zf, 5.7), Vector2(zf - 0.2, 5.7)], 2.72)  # frente
	_caixa(m, PINTURA, Vector3(5.5, 0.15, 3.0), Vector3(0, 5.8, zf + 1.35))  # cobertura sobre a cabine
	_caixa(m, "interno", Vector3(4.8, 0.03, 6.6), Vector3(0, 3.22, (zt + zf) * 0.5 - 0.1), Vector3(-0.055, 0, 0))
	# cilindros de basculamento e para-lamas
	for lado in [1.0, -1.0]:
		_cil(m, "cromo", 0.13, 1.6, Vector3(lado * 1.1, 2.45, 0.2), Vector3(0.35, 0, 0), 8)
		_caixa(m, "lanterna", Vector3(0.25, 0.25, 0.04), Vector3(lado * 2.2, 2.2, zt - 0.02))
	for w in f["rodas"]:
		if not String(w[0]).contains("Inner"):
			_paralama(m, float(w[1]), float(w[2]), float(w[3]), r, 0.9)
