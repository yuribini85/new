class_name ObjetosArena
extends Node3D
## Objetos de pista do pacote de dano (aprovado pelo usuário) na arena: barreira
## de concreto que racha e quebra, barreira de seis pneus que desmonta, cones,
## barris e árvores do lado de fora. Só tela: os carros seguem a simulação
## (corpo cinemático, camada 4) e empurram os objetos; nada disso muda o
## resultado. O concreto fica no muro (onde a simulação já segura o carro).
## Posição de tudo pela forma da arena e uma semente: a mesma arena, os mesmos
## objetos. Camadas do pacote: 1 chão, 2 objetos, 4 carros, 8 destroços.

const PASTA := "res://arte/dano/"
## Pacote: concreto racha a 2 m/s e quebra a 7 m/s; pneus soltam a 2,5 m/s.
const RACHA_MS := 2.0
const QUEBRA_MS := 7.0
const SOLTA_PNEU_MS := 2.5
const BARREIRA_M := 2.4  # comprimento da barreira de concreto
## Quantos de cada (decoração; limite pensado no celular).
const CONCRETO_MAX := 10
const PNEUS_MAX := 5
const CONES_FILAS := 3
const CONES_POR_FILA := 5
const BARRIS := 6
const ARVORES := 10

var _forma: ArenaForma
var _rng := RandomNumberGenerator.new()
## Trechos do muro com barreira: [a, b] (2D, simulação), para o muro de pneus pular.
var trechos_concreto: Array = []
var _quebraveis: Array = []  # [{tipo, no, area, solido, pecas, rachou, quebrou}]
## Lados do muro com arquibancada (Arena3D): sem árvores atrás.
var lados_ocupados: Array = []


func montar(forma: ArenaForma, semente: int) -> void:
	_forma = forma
	_rng.seed = semente
	var n := forma.muro.size()
	var c := 0
	var p := 0
	for i in n:
		var a := forma.muro[i]
		var b := forma.muro[(i + 1) % n]
		var lado := (b - a).length()
		if lado < BARREIRA_M + 1.0:
			continue
		var dir := (b - a) / lado
		var fora := dir.orthogonal()
		if i % 3 == 0 and c < CONCRETO_MAX:
			var quantas := mini(int((lado - 1.0) / BARREIRA_M), 3)
			var ini := (lado - quantas * BARREIRA_M) * 0.5
			for k in quantas:
				if c >= CONCRETO_MAX:
					break
				var meio := a + dir * (ini + (k + 0.5) * BARREIRA_M) + fora * 0.45
				_concreto(meio, dir)
				c += 1
			trechos_concreto.append([a + dir * ini, a + dir * (ini + quantas * BARREIRA_M)])
		elif i % 3 == 1 and p < PNEUS_MAX:
			_pneus(a.lerp(b, 0.5) - fora * 0.6, dir)
			p += 1
	for f in CONES_FILAS:
		var centro := _ponto_dentro(0.35, 0.7)
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		for k in CONES_POR_FILA:
			_cone(centro + dir * (k - CONES_POR_FILA * 0.5) * 1.6)
	for k in BARRIS:
		var q := forma.muro[_rng.randi_range(0, n - 1)]
		_barril(q + (forma.centro - q).normalized() * (1.5 + _rng.randf() * 2.0))
	for k in ARVORES:
		var i := _rng.randi_range(0, n - 1)
		if i in lados_ocupados:
			continue
		var a := forma.muro[i]
		var b := forma.muro[(i + 1) % n]
		var fora := (b - a).normalized().orthogonal()
		_arvore(a.lerp(b, _rng.randf()) + fora * (4.0 + _rng.randf() * 5.0))


## Ponto livre no chão: entre `de` e `ate` do caminho do centro ao muro.
func _ponto_dentro(de: float, ate: float) -> Vector2:
	var ang := _rng.randf() * TAU
	return _forma.largada(ang, _rng.randf_range(de, ate))


func _em(q: Vector2) -> Vector3:
	return Vector3(q.x, _forma.altura(q), -q.y)


## Gira o objeto para o eixo X local seguir `dir` (2D da simulação).
static func _rumo(dir: Vector2) -> float:
	return dir.angle()


func _corpo(massa: float, atrito: float, quique: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = massa
	b.collision_layer = 2
	b.collision_mask = 1 | 2 | 4 | 8
	b.continuous_cd = true
	b.linear_damp = .2
	b.angular_damp = .3
	var m := PhysicsMaterial.new()
	m.friction = atrito
	m.bounce = quique
	b.physics_material_override = m
	return b


func _forma_convexa(pai: Node3D, pontos: PackedVector3Array) -> void:
	var cs := CollisionShape3D.new()
	var f := ConvexPolygonShape3D.new()
	f.points = pontos
	cs.shape = f
	pai.add_child(cs)


func _cone(q: Vector2) -> void:
	var b := _corpo(1.2, .35, .08)
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	b.center_of_mass = Vector3(0, .24, 0)
	b.linear_damp = .12
	b.angular_damp = .22
	b.add_child(load(PASTA + "cone/model.glb").instantiate())
	_forma_convexa(b, PackedVector3Array([Vector3(-.2, .025, -.2), Vector3(-.2, .025, .2), Vector3(.2, .025, .2),
		Vector3(.2, .025, -.2), Vector3(-.17, .055, -.17), Vector3(-.17, .055, .17), Vector3(.17, .055, .17),
		Vector3(.17, .055, -.17), Vector3(-.03, .55, -.03), Vector3(-.03, .55, .03), Vector3(.03, .55, .03),
		Vector3(.03, .55, -.03)]))
	add_child(b)
	b.global_position = _em(q)


func _barril(q: Vector2) -> void:
	var b := _corpo(30.0, .55, .05)
	b.add_child(load(PASTA + "barril_oleo/model.glb").instantiate())
	var pts := PackedVector3Array()
	for y in [.01, .878]:
		for k in 12:
			var ang := TAU * k / 12.0
			pts.append(Vector3(cos(ang) * .285, y, sin(ang) * .285))
	_forma_convexa(b, pts)
	add_child(b)
	b.global_position = _em(q)


func _arvore(q: Vector2) -> void:
	var s := StaticBody3D.new()
	s.collision_layer = 2
	s.collision_mask = 0
	s.add_child(load(PASTA + "arvore_tronco/model.glb").instantiate())
	var copa: Node3D = load(PASTA + "arvore_copa/model.glb").instantiate()
	copa.position.y = 1.8
	s.add_child(copa)
	var cs := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = .18
	cil.height = 2.36
	cs.shape = cil
	cs.position = Vector3(.04, 1.18, .02)
	s.add_child(cs)
	add_child(s)
	s.global_position = _em(q)
	s.rotation.y = _rng.randf() * TAU


## Barreira de concreto no muro: sólida (camada 2) até quebrar; a frente dela
## é a linha do muro.
func _concreto(meio: Vector2, dir: Vector2) -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = _em(meio)
	raiz.rotation.y = _rumo(dir)
	var visual: Node3D = load(PASTA + "concreto/model.glb").instantiate()
	raiz.add_child(visual)
	var solido := StaticBody3D.new()
	solido.collision_layer = 2
	solido.collision_mask = 0
	var perfil := PackedVector3Array()
	for x in [-1.2, 1.2]:
		for zy in [Vector2(-.4, 0), Vector2(.4, 0), Vector2(.4, .18), Vector2(.16, .52), Vector2(.13, .85),
				Vector2(-.13, .85), Vector2(-.16, .52), Vector2(-.4, .18)]:
			perfil.append(Vector3(x, zy.y, zy.x))
	_forma_convexa(solido, perfil)
	raiz.add_child(solido)
	_quebraveis.append({"tipo": "concreto", "no": raiz, "visual": visual, "solido": solido,
			"area": _area(raiz, Vector3(2.8, 1.1, 1.8)), "rachou": false, "quebrou": false})


## Barreira de seis pneus (três em baixo, três em cima), presa até um carro
## acertar acima de SOLTA_PNEU_MS.
func _pneus(meio: Vector2, dir: Vector2) -> void:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = _em(meio)
	raiz.rotation.y = _rumo(dir)
	var pecas := []
	var malha: PackedScene = load(PASTA + "pneu_individual/model.glb")
	for x in [-.73, 0.0, .73]:
		for y in [0.0, .31]:
			var b := _corpo(22.0, .9, .05)
			b.freeze = true
			b.linear_damp = .7
			b.angular_damp = .35
			var m: Node3D = malha.instantiate()
			m.position.y = -.15
			b.add_child(m)
			for setor in 12:
				var pts := PackedVector3Array()
				for yy in [-.15, .15]:
					for r in [.19, .355]:
						for ang in [setor * TAU / 12, (setor + 1) * TAU / 12]:
							pts.append(Vector3(cos(ang) * r, yy, sin(ang) * r))
				_forma_convexa(b, pts)
			raiz.add_child(b)
			b.position = Vector3(x, y + .15, 0)
			pecas.append(b)
	_quebraveis.append({"tipo": "pneus", "no": raiz, "pecas": pecas,
			"area": _area(raiz, Vector3(2.8, 1.1, 1.8)), "quebrou": false})


func _area(pai: Node3D, tam: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 4
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tam
	cs.shape = caixa
	cs.position.y = .45
	a.add_child(cs)
	pai.add_child(a)
	return a


## Carro dentro da área de uma barreira: a velocidade dele contra ela
## (meta "vel" do corpo cinemático, posta pela Arena3D) racha, quebra ou solta.
func _physics_process(_delta: float) -> void:
	for q in _quebraveis:
		if q["quebrou"]:
			continue
		for corpo in (q["area"] as Area3D).get_overlapping_bodies():
			var v: Vector3 = corpo.get_meta("vel", Vector3.ZERO)
			var no: Node3D = q["no"]
			var normal := absf(v.dot(no.global_basis.z))
			if q["tipo"] == "pneus":
				if v.length() >= SOLTA_PNEU_MS:
					_soltar_pneus(q, v)
				break
			if normal >= QUEBRA_MS:
				_quebrar(q, v)
				break
			if normal >= RACHA_MS and not q["rachou"]:
				q["rachou"] = true
				_rachar(no)


func _soltar_pneus(q: Dictionary, v: Vector3) -> void:
	q["quebrou"] = true
	for b: RigidBody3D in q["pecas"]:
		b.freeze = false
		b.sleeping = false
		b.apply_central_impulse(v * b.mass * .025)
		# Impulso fora do centro: solta a fileira de cima sem explodir a pilha.
		if b.position.y > .3:
			b.apply_impulse(v * b.mass * .02, Vector3(0, .12, .08))


func _rachar(no: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("30322e")
	var linha := [Vector3(-.36, .83, -.135), Vector3(-.15, .62, -.154), Vector3(-.28, .48, -.19), Vector3(.02, .29, -.32),
			Vector3(-.08, .06, -.407)]
	for lado in [-1.0, 1.0]:
		for j in linha.size() - 1:
			var a: Vector3 = linha[j] * Vector3(1, 1, lado)
			var b: Vector3 = linha[j + 1] * Vector3(1, 1, lado)
			var mi := MeshInstance3D.new()
			var caixa := BoxMesh.new()
			caixa.size = Vector3(.036, .012, a.distance_to(b))
			mi.mesh = caixa
			mi.material_override = m
			mi.name = "Racha"
			no.add_child(mi)
			mi.position = (a + b) / 2
			mi.look_at(mi.global_position + no.global_basis * (b - a), Vector3.UP)


## Quebra em seis blocos (concrete-fracture.json do pacote), que ficam no chão.
func _quebrar(q: Dictionary, _v: Vector3) -> void:
	q["quebrou"] = true
	var no: Node3D = q["no"]
	(q["visual"] as Node3D).hide()
	for f in no.get_children():
		if f.name.begins_with("Racha"):
			f.hide()
	var solido: StaticBody3D = q["solido"]
	solido.collision_layer = 0
	var blocos: Array = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "concrete-fracture.json"))
	for r in blocos:
		var centro := Vector3(r["center"][0], r["center"][1], r["center"][2])
		var b := _corpo(float(r["mass"]), 1.2, .05)
		b.linear_damp = 1.8
		b.angular_damp = 1.2
		var m: Node3D = load(PASTA + String(r["id"]) + "/model.glb").instantiate()
		m.position = -centro
		b.add_child(m)
		for casco in r["collision_hulls"]:
			var pts := PackedVector3Array()
			for p in casco:
				pts.append(Vector3(p[0], p[1], p[2]))
			_forma_convexa(b, pts)
		no.add_child(b)
		b.position = centro
