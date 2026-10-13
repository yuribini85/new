class_name Arena
extends RefCounted
## Arena de destruição resolvida sem renderizar (decisões 49–50; estudo
## Destruction Derby em docs/). Plano 2D, passo fixo e semente: o mesmo
## resultado com e sem amostras, como a corrida (Simulacao).
##
## Carro: cápsula (segmento entre os eixos + raio = meia largura), massa = peso,
## posição, rumo e velocidade contínuos. Contato carro–carro, carro–muro e
## carro–obstáculo (a forma da arena, ArenaForma: muro em polígono, ilhas e o
## chão irregular, cuja inclinação puxa os carros): impulso na normal com
## restituição e atrito; o ponto do contato fora do centro gira o carro.
##
## Dano em seis regiões (FRENTE_E, FRENTE_D, LADO_E, LADO_D, TRAS_E, TRAS_D),
## de 0 a 1: a energia do impacto E = ½·m_efetiva·v_normal² (v_normal = velocidade
## de aproximação no ponto de contato) dividida pela resistência da região,
## ½·m·v_ref² do próprio carro (o carro mais pesado aguenta mais). Cada contato
## novo cobra uma vez; encostado não cobra de novo. Uma região da frente em
## `limite_eliminacao` elimina: o carro para de andar e fica como obstáculo.
## Limites e estágios vêm do estudo (eliminação a 100%, ré a ~90%, cinco
## estágios visuais); velocidades e tempos estão em data/arena.json.
##
## Pilotos com jeitos diferentes (data/arena.json → perfis, sorteado por luta):
## alvo (acaso, perto, fraco), mira (traseira ou meio), velocidade, quando
## protege a frente, erro de mira e impaciência (sem acertar ninguém por um
## tempo, vai direto no meio do alvo, mais rápido).
## IA (as mesmas regras para todos): mantém um alvo por `alvo_s`, mira a quina traseira
## dele onde ele vai estar (antecedência pela própria velocidade), vira aos
## poucos e reduz até `v_curva_kmh` quanto maior o erro de rumo (ataca até
## `v_ataque_kmh` alinhada); com o muro à frente em `olhar_muro_s`, vira para o
## centro devagar; com a frente em `limite_re`, ataca
## de ré para poupar a frente; travado encostado por `travado_s`, recua
## `recuperacao_s` no sentido contrário ao ataque.

const G := 9.81
const CV_PARA_W := 735.5
const KMH := 1.0 / 3.6
const REGIOES := ["frente_e", "frente_d", "lado_e", "lado_d", "tras_e", "tras_d"]
const FRENTE := [0, 1]
## Medidas do carro quando os dados não têm (m).
const COMPRIMENTO_M := 4.4
const LARGURA_M := 1.75
## Chaves obrigatórias em data/arena.json.
const PARAMS := ["raio_m", "dt_s", "amostra_dt_s", "tempo_max_s", "restituicao", "atrito_contato",
	"v_ref_kmh", "v_min_dano_kmh", "limite_eliminacao", "limite_re", "estagios", "alvo_s",
	"antecedencia_max_s", "travado_s", "recuperacao_s", "v_travado_kmh", "v_ataque_kmh", "v_curva_kmh",
	"olhar_muro_s", "margem_muro_m"]


## participantes: [{id, atributos (Carro.atributos_efetivos), piloto {ritmo,
## consistencia, agressividade}}], opcionais para testes: pos (Vector2), rumo,
## vel (Vector2), acelerador (fixo; sem IA).
## Retorna {classificacao, carros{id: {dano[6], eliminado, eliminado_em, por,
## sobreviveu_s, giros (provocados), eliminou}}, eventos (impacto, giro,
## eliminado), amostras, duracao}.
static func correr(participantes: Array, params: Dictionary, semente: int, com_amostras := true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var dt := float(params["dt_s"])
	var forma := ArenaForma.de(params)
	var v_ref := float(params["v_ref_kmh"]) * KMH
	var carros := []
	var n := participantes.size()
	for i in n:
		var p: Dictionary = participantes[i]
		var a: Dictionary = p["atributos"]
		var ang := TAU * i / maxf(n, 1)
		var m := float(a["peso"])
		var c := {
			"id": p["id"], "m": m, "L": float(a.get("comprimento", COMPRIMENTO_M)),
			"W": float(a.get("largura", LARGURA_M)),
			"pot": float(a["potencia"]) * CV_PARA_W, "mu": float(a["aderencia"]),
			# Largada nas extremidades, junto ao muro (decisão do usuário).
			"pos": p.get("pos", forma.largada(ang, float(params.get("largada_raio_frac", 0.6)))),
			# Largada em roda, todos de frente para o centro (decisão do usuário).
			"rumo": float(p.get("rumo", (forma.centro - forma.largada(ang, 0.85)).angle())),
			"vel": p.get("vel", Vector2.ZERO), "w": 0.0,
			"dano": PackedFloat32Array([0, 0, 0, 0, 0, 0]), "eliminado": false, "eliminado_em": -1.0,
			"por": "", "ultimo_golpe": "", "giro_acum": 0.0, "giros": 0, "eliminou": 0,
			"acel_fixo": p.get("acelerador", null), "agress": float(p.get("piloto", {}).get("agressividade", 0.5)),
			# Equipe (arena em duplas): colegas não se miram; sem equipe, cada um por si.
			"equipe": String(p.get("equipe", p["id"])),
			"consist": float(p.get("piloto", {}).get("consistencia", 0.9)),
			"alvo": -1, "t_alvo": 0.0, "t_travado": 0.0, "t_recua": 0.0, "re": false,
		}
		c["perfil"] = _perfil(p, params, rng)
		c["t_sem_golpe"] = 0.0
		c["desvio"] = Vector2.ZERO
		c["I"] = c["m"] * (c["L"] * c["L"] + c["W"] * c["W"]) / 12.0
		c["resist"] = 0.5 * c["m"] * v_ref * v_ref
		carros.append(c)
	var contatos := {}  # "i:j" ou "i:muro" -> true enquanto encostados
	var eventos := []
	var amostras := []
	var t := 0.0
	var t_amostra := 0.0
	var tempo_max := float(params["tempo_max_s"])
	while t < tempo_max:
		for i in n:
			_dirigir(carros, i, params, rng, dt, forma)
		for c in carros:
			_mover(c, dt, forma)
		_colisoes(carros, contatos, params, eventos, t, forma)
		_giros(carros, params, eventos, t)
		t += dt
		for c in carros:
			if not c["eliminado"]:
				c["sobreviveu_s"] = t
		if com_amostras and t >= t_amostra:
			t_amostra += float(params["amostra_dt_s"])
			amostras.append(_amostra(carros, t))
		# Acaba quando sobra uma equipe de pé (ou ninguém).
		var equipes_vivas := {}
		for c in carros:
			if not c["eliminado"]:
				equipes_vivas[c["equipe"]] = true
		if equipes_vivas.size() <= 1:
			break
	if not com_amostras or amostras.is_empty() or amostras[-1]["t"] < t:
		amostras.append(_amostra(carros, t))
	return _resultado(carros, eventos, amostras, t)


## IA: alvo, interceptação, ré com a frente quase destruída e recuperação.
static func _dirigir(carros: Array, i: int, params: Dictionary, rng: RandomNumberGenerator, dt: float,
		forma: ArenaForma) -> void:
	var c: Dictionary = carros[i]
	c["cmd_acel"] = 0.0
	c["cmd_giro"] = 0.0
	if c["eliminado"]:
		return
	if c["acel_fixo"] != null:
		c["cmd_acel"] = float(c["acel_fixo"])
		return
	var perfil: Dictionary = c["perfil"]
	c["re"] = FRENTE.any(func(r): return c["dano"][r] >= float(perfil.get("limite_re", params["limite_re"])))
	c["t_sem_golpe"] += dt
	# Impaciente: tempo demais sem acertar ninguém → vai direto no meio do alvo,
	# mais rápido (quebra o "balé" de dois carros rodeando um ao outro).
	# No duelo final a paciência cai pela metade; impaciente esquece a ré (a
	# traseira não elimina: dois carros em ré nunca se acabariam).
	var restantes: int = carros.reduce(func(n, x): return n + (0 if x["eliminado"] else 1), 0)
	var paciencia := float(perfil.get("impaciencia_s", 999.0)) * (0.5 if restantes <= 2 else 1.0)
	var impaciente: bool = c["t_sem_golpe"] > paciencia
	if impaciente:
		c["re"] = false
		# Ainda sem acertar: os dois perseguindo um ao outro entram em órbita.
		# A cada `impaciencia_recua_s`, recua para abrir distância e volta reto.
		var passo := float(params.get("impaciencia_recua_s", 0.0))
		if passo > 0.0 and fmod(c["t_sem_golpe"] - paciencia, passo) < dt:
			c["t_recua"] = float(params["recuperacao_s"]) * 0.6
	# Recuperação: recua no sentido contrário ao ataque, sem virar.
	if c["t_recua"] > 0.0:
		c["t_recua"] -= dt
		c["cmd_acel"] = 1.0 if c["re"] else -1.0
		return
	# Alvo: mantido por alvo_s; troca antes se ele foi eliminado.
	c["t_alvo"] -= dt
	var alvo_ok: bool = c["alvo"] >= 0 and not carros[c["alvo"]]["eliminado"]
	if c["t_alvo"] <= 0.0 or not alvo_ok:
		var vivos := []
		for j in carros.size():
			if j != i and not carros[j]["eliminado"] and carros[j]["equipe"] != c["equipe"]:
				vivos.append(j)
		if vivos.is_empty():
			return
		c["alvo"] = _escolher_alvo(carros, c, vivos, String(perfil.get("alvo", "acaso")), rng)
		c["t_alvo"] = float(params["alvo_s"]) * float(perfil.get("alvo_s_mult", 1.0)) * rng.randf_range(0.6, 1.4)
		# Cada escolha de alvo vem com um erro de mira próprio (m).
		c["desvio"] = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(perfil.get("imprecisao_m", 0.0))
	var a: Dictionary = carros[c["alvo"]]
	var dist: float = (a["pos"] - c["pos"]).length()
	var antecedencia := minf(dist / maxf(c["vel"].length(), 1.0), float(params["antecedencia_max_s"]))
	# Mira a quina traseira do alvo (o que o faz girar e poupa a própria frente
	# de um frontal), onde ele vai estar.
	var traseira := 0.0 if impaciente else float(perfil.get("mira_traseira", params.get("mira_traseira", 0.35)))
	var mira: Vector2 = a["pos"] - Vector2.from_angle(a["rumo"]) * a["L"] * traseira + a["vel"] * antecedencia \
			+ c["desvio"]
	var rumo_alvo: float = (mira - c["pos"]).angle()
	if c["re"]:
		rumo_alvo += PI  # a traseira aponta para o alvo
	var v_alvo := float(params["v_ataque_kmh"]) * KMH * float(perfil.get("v_mult", 1.0)) * (1.2 if impaciente else 1.0)
	# Muro à frente: a posição prevista sai da arena → vira para o centro e reduz.
	var margem := float(params["margem_muro_m"])
	var previsto: Vector2 = c["pos"] + c["vel"] * float(params["olhar_muro_s"])
	if forma.muro_perto(previsto)[0] < margem:
		rumo_alvo = (forma.centro - c["pos"]).angle() + (PI if c["re"] else 0.0)
		v_alvo = float(params["v_curva_kmh"]) * KMH
	else:
		# Obstáculo à frente: contorna pelo lado para onde já está indo.
		var ob := forma.obstaculo_perto(previsto)
		if float(ob[0]) < margem * 0.6:
			var tangente: Vector2 = (ob[1] as Vector2).orthogonal()
			if tangente.dot(c["vel"]) < 0.0:
				tangente = -tangente
			rumo_alvo = (tangente + ob[1] * 0.6).angle() + (PI if c["re"] else 0.0)
			v_alvo = float(params["v_curva_kmh"]) * KMH
	# Erro de rumo com um pouco de imprecisão (consistência do piloto).
	var erro := wrapf(rumo_alvo - float(c["rumo"]), -PI, PI) + rng.randfn(0.0, (1.0 - c["consist"]) * 0.2)
	c["cmd_giro"] = clampf(erro * 3.0, -1.0, 1.0)
	# Velocidade pela curva (estudo: a propulsão cai com o erro de rumo):
	# alinhado, ataca; virando muito, devagar para fechar a curva.
	v_alvo = lerpf(v_alvo, float(params["v_curva_kmh"]) * KMH, clampf(absf(erro) / (PI / 2.0), 0.0, 1.0))
	var sentido := -1.0 if c["re"] else 1.0
	var v_agora: float = c["vel"].dot(Vector2.from_angle(c["rumo"])) * sentido
	if v_agora > v_alvo:
		c["cmd_acel"] = -sentido * clampf((v_agora - v_alvo) / 3.0, 0.2, 1.0)  # freia
	else:
		c["cmd_acel"] = sentido * lerpf(0.75, 1.0, c["agress"])
	# Travado: quase parado e encostado, ou grudado em alguém (empurrando e
	# girando junto, sem se separar não há batida nova): recua e volta.
	if c.get("encostado", false):
		var devagar: bool = c["vel"].length() < float(params["v_travado_kmh"]) * KMH
		c["t_travado"] += dt * (1.0 if devagar else 0.5)
		if c["t_travado"] >= float(params["travado_s"]):
			c["t_travado"] = 0.0
			c["t_recua"] = float(params["recuperacao_s"])
	else:
		c["t_travado"] = 0.0


## Perfil do piloto na arena: o do participante ("perfil": id em
## params.perfis) ou um sorteado pela semente da luta. {} sem perfis nos dados.
static func _perfil(p: Dictionary, params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var perfis: Dictionary = params.get("perfis", {})
	if perfis.is_empty():
		return {}
	var id := String(p.get("perfil", ""))
	if not perfis.has(id):
		var ids := perfis.keys()
		ids.sort()
		id = ids[rng.randi_range(0, ids.size() - 1)]
	var r: Dictionary = perfis[id].duplicate()
	r["id"] = id
	return r


## Alvo pelo jeito do piloto: ao acaso, o mais perto ou o mais danificado.
static func _escolher_alvo(carros: Array, c: Dictionary, vivos: Array, modo: String, rng: RandomNumberGenerator) -> int:
	if modo == "perto":
		vivos.sort_custom(func(x, y): return (carros[x]["pos"] - c["pos"]).length() < (carros[y]["pos"] - c["pos"]).length())
		return vivos[0]
	if modo == "fraco":
		vivos.sort_custom(func(x, y): return _total(carros[x]["dano"]) > _total(carros[y]["dano"]))
		return vivos[0]
	return vivos[rng.randi_range(0, vivos.size() - 1)]


## Integra: força motriz (potência limitada pela aderência), giro limitado pela
## velocidade e aderência lateral que tira o escorregamento aos poucos.
static func _mover(c: Dictionary, dt: float, forma: ArenaForma) -> void:
	# Chão irregular: a gravidade puxa morro abaixo (destroço também desliza).
	var grad := forma.gradiente(c["pos"])
	c["vel"] -= grad * G * dt
	var frente := Vector2.from_angle(c["rumo"])
	var lado := frente.orthogonal()
	var v_long: float = c["vel"].dot(frente)
	var v_lat: float = c["vel"].dot(lado)
	var aderencia: float = c["mu"] * G
	if not c["eliminado"]:
		var f := absf(c["cmd_acel"]) * minf(c["pot"] / maxf(absf(v_long), 3.0), c["mu"] * c["m"] * G)
		# Subindo (de frente ou de ré): o motor rende menos na rampa.
		var contra := grad.dot(frente) * signf(c["cmd_acel"])
		f *= clampf(1.0 - forma.subida_perda * maxf(contra, 0.0), 0.4, 1.0)
		v_long += signf(c["cmd_acel"]) * f / c["m"] * dt
		# Giro: taxa máxima pela velocidade (raio mínimo ~ entre-eixos) e pela aderência.
		var taxa_max := minf(absf(v_long) / (c["L"] * 0.6), aderencia / maxf(absf(v_long), 1.0))
		var alvo_w: float = c["cmd_giro"] * taxa_max * signf(v_long if absf(v_long) > 0.1 else 1.0)
		c["w"] = move_toward(c["w"], alvo_w, 8.0 * dt)
	else:
		c["w"] = move_toward(c["w"], 0.0, 2.0 * dt)
	# Rolagem e arrasto simples; destroço freia mais.
	v_long = move_toward(v_long, 0.0, (0.15 if not c["eliminado"] else 0.6) * G * dt)
	v_lat = move_toward(v_lat, 0.0, aderencia * dt)
	c["vel"] = frente * v_long + lado * v_lat
	c["pos"] += c["vel"] * dt
	var dr: float = c["w"] * dt
	c["rumo"] = wrapf(c["rumo"] + dr, -PI, PI)
	c["giro_acum"] += dr


## Segmento da cápsula (entre os centros das pontas) em coordenadas do mundo.
static func _segmento(c: Dictionary) -> Array:
	var meio: float = c["L"] * 0.5 - c["W"] * 0.5
	var f := Vector2.from_angle(c["rumo"]) * meio
	return [c["pos"] - f, c["pos"] + f]


static func _mais_proximos(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var u := 0.0
	var cc := d1.dot(r)
	var b := d1.dot(d2)
	var den := a * e - b * b
	if den > 1e-9:
		s = clampf((b * f - cc * e) / den, 0.0, 1.0)
	u = (b * s + f) / e if e > 1e-9 else 0.0
	if u < 0.0:
		u = 0.0
		s = clampf(-cc / a, 0.0, 1.0) if a > 1e-9 else 0.0
	elif u > 1.0:
		u = 1.0
		s = clampf((b - cc) / a, 0.0, 1.0) if a > 1e-9 else 0.0
	return [p1 + d1 * s, p2 + d2 * u]


static func _colisoes(carros: Array, contatos: Dictionary, params: Dictionary, eventos: Array, t: float,
		forma: ArenaForma) -> void:
	for c in carros:
		c["encostado"] = false
	var tocando := {}
	for i in carros.size():
		var a: Dictionary = carros[i]
		var sa := _segmento(a)
		# Muro (o polígono) e obstáculos: cada ponta da cápsula.
		for ponta in sa:
			var pm := forma.muro_perto(ponta)
			var pen: float = a["W"] * 0.5 - float(pm[0])
			if pen > 0.0:
				var nrm: Vector2 = pm[1]  # aponta para dentro
				var ponto: Vector2 = ponta - nrm * a["W"] * 0.5
				a["pos"] += nrm * pen
				var chave := "%d:muro" % i
				tocando[chave] = true
				a["encostado"] = true
				_impulso(a, {}, ponto, nrm, params, eventos, t, not contatos.has(chave))
			var ob := forma.obstaculo_perto(ponta)
			var pen_o: float = a["W"] * 0.5 - float(ob[0])
			if pen_o > 0.0:
				var nrm_o: Vector2 = ob[1]
				a["pos"] += nrm_o * pen_o
				var chave_o := "%d:obst" % i
				tocando[chave_o] = true
				a["encostado"] = true
				_impulso(a, {}, ponta - nrm_o * a["W"] * 0.5, nrm_o, params, eventos, t, not contatos.has(chave_o))
		for j in range(i + 1, carros.size()):
			var b: Dictionary = carros[j]
			var sb := _segmento(b)
			var pp := _mais_proximos(sa[0], sa[1], sb[0], sb[1])
			var dlt: Vector2 = pp[0] - pp[1]
			var dist := dlt.length()
			var soma: float = (a["W"] + b["W"]) * 0.5
			if dist >= soma:
				continue
			var nrm := dlt / dist if dist > 1e-6 else Vector2.from_angle(a["rumo"]).orthogonal()
			var pen := soma - dist
			var ma: float = a["m"]
			var mb: float = b["m"]
			a["pos"] += nrm * pen * mb / (ma + mb)
			b["pos"] -= nrm * pen * ma / (ma + mb)
			var ponto: Vector2 = pp[1] + nrm * b["W"] * 0.5
			var chave := "%d:%d" % [i, j]
			tocando[chave] = true
			a["encostado"] = true
			b["encostado"] = true
			_impulso(a, b, ponto, nrm, params, eventos, t, not contatos.has(chave))
	contatos.clear()
	contatos.merge(tocando)


## Impulso no ponto de contato (normal de b para a); dano só em contato novo.
static func _impulso(a: Dictionary, b: Dictionary, ponto: Vector2, nrm: Vector2, params: Dictionary,
		eventos: Array, t: float, novo: bool) -> void:
	var ra: Vector2 = ponto - a["pos"]
	var va: Vector2 = a["vel"] + Vector2(-ra.y, ra.x) * a["w"]
	var vb := Vector2.ZERO
	var rb := Vector2.ZERO
	if not b.is_empty():
		rb = ponto - b["pos"]
		vb = b["vel"] + Vector2(-rb.y, rb.x) * b["w"]
	var vrel := va - vb
	var vn := vrel.dot(nrm)
	if vn >= 0.0:
		return  # já se afastando
	var inv_a: float = 1.0 / a["m"] + pow(ra.cross(nrm), 2) / a["I"]
	var inv_b: float = 0.0 if b.is_empty() else 1.0 / b["m"] + pow(rb.cross(nrm), 2) / b["I"]
	var e := float(params["restituicao"])
	var jn := -(1.0 + e) * vn / (inv_a + inv_b)
	# Atrito no contato (Coulomb, limitado pela normal): o que faz girar de lado.
	var tang := nrm.orthogonal()
	var vt := vrel.dot(tang)
	var inv_ta: float = 1.0 / a["m"] + pow(ra.cross(tang), 2) / a["I"]
	var inv_tb: float = 0.0 if b.is_empty() else 1.0 / b["m"] + pow(rb.cross(tang), 2) / b["I"]
	var jt := clampf(-vt / (inv_ta + inv_tb), -float(params["atrito_contato"]) * jn, float(params["atrito_contato"]) * jn)
	var imp := nrm * jn + tang * jt
	a["vel"] += imp / a["m"]
	a["w"] += ra.cross(imp) / a["I"]
	if not b.is_empty():
		b["vel"] -= imp / b["m"]
		b["w"] -= rb.cross(imp) / b["I"]
	if not novo or -vn < float(params["v_min_dano_kmh"]) * KMH:
		return
	var m_ef: float = a["m"] if b.is_empty() else a["m"] * b["m"] / (a["m"] + b["m"])
	var energia := 0.5 * m_ef * vn * vn
	_danificar(a, ponto, energia, "" if b.is_empty() else String(b["id"]), params, eventos, t)
	if not b.is_empty():
		a["t_sem_golpe"] = 0.0
		b["t_sem_golpe"] = 0.0
		_danificar(b, ponto, energia, String(a["id"]), params, eventos, t)


## Região pelo ponto do contato no referencial do carro: terços do comprimento
## (frente, lado, traseira) e o lado pelo sinal.
static func regiao(c: Dictionary, ponto: Vector2) -> int:
	var local: Vector2 = (ponto - c["pos"]).rotated(-float(c["rumo"]))
	var lado := 0 if local.y > 0.0 else 1  # y>0: esquerda (ângulos crescem no sentido anti-horário)
	if local.x > c["L"] / 6.0:
		return 0 + lado
	if local.x < -c["L"] / 6.0:
		return 4 + lado
	return 2 + lado


static func _danificar(c: Dictionary, ponto: Vector2, energia: float, quem: String, params: Dictionary,
		eventos: Array, t: float) -> void:
	if c["eliminado"]:
		return
	var r := regiao(c, ponto)
	var antes: float = c["dano"][r]
	c["dano"][r] = minf(antes + energia / c["resist"], 1.0)
	if quem != "":
		c["ultimo_golpe"] = quem
		c["giro_acum"] = 0.0  # conta o giro provocado a partir deste golpe
		c["giros_feitos"] = []
	eventos.append({"t": t, "tipo": "impacto", "carro": c["id"], "por": quem, "regiao": REGIOES[r],
			"dano": c["dano"][r] - antes})
	if r in FRENTE and c["dano"][r] >= float(params["limite_eliminacao"]):
		c["eliminado"] = true
		c["eliminado_em"] = t
		c["por"] = quem if quem != "" else String(c["ultimo_golpe"])
		eventos.append({"t": t, "tipo": "eliminado", "carro": c["id"], "por": c["por"]})


## Giro provocado: depois de um golpe de outro carro, cada limite de
## `giros_graus` passado conta uma vez para quem bateu.
static func _giros(carros: Array, params: Dictionary, eventos: Array, t: float) -> void:
	for c in carros:
		if c["ultimo_golpe"] == "" or c["eliminado"]:
			continue
		var graus := absf(rad_to_deg(float(c["giro_acum"])))
		for limite in params.get("giros_graus", []):
			if graus >= float(limite) and not int(limite) in c.get("giros_feitos", []):
				c["giros_feitos"] = c.get("giros_feitos", []) + [int(limite)]
				eventos.append({"t": t, "tipo": "giro", "carro": c["id"], "por": c["ultimo_golpe"], "graus": int(limite)})


## Estágio visual (0..estagios-1) de um valor de dano.
static func estagio(dano: float, estagios: int) -> int:
	return mini(int(dano * estagios), estagios - 1)


static func _amostra(carros: Array, t: float) -> Dictionary:
	var a := {"t": t}
	for c in carros:
		a[c["id"]] = {"pos": c["pos"], "rumo": c["rumo"], "dano": c["dano"].duplicate(), "eliminado": c["eliminado"],
				"re": c.get("re", false)}
	return a


## Classificação: quem sobrou primeiro; depois os eliminados do último para o
## primeiro (quem durou mais fica na frente). Eliminações creditadas a quem deu o
## golpe final; giros contam a partir do último golpe recebido.
static func _resultado(carros: Array, eventos: Array, amostras: Array, t: float) -> Dictionary:
	for c in carros:
		if c["por"] != "":
			for o in carros:
				if o["id"] == c["por"]:
					o["eliminou"] += 1
	var ordem := carros.duplicate()
	# Equipe vencedora: a de quem ficou de pé (ou do último a cair).
	var vencedora := ""
	var ultimo := -INF
	for c in carros:
		if not c["eliminado"]:
			vencedora = c["equipe"]
			break
		if float(c["eliminado_em"]) > ultimo:
			ultimo = float(c["eliminado_em"])
			vencedora = c["equipe"]
	ordem.sort_custom(func(x, y):
		if x["eliminado"] != y["eliminado"]:
			return not x["eliminado"]
		if x["eliminado"]:
			return x["eliminado_em"] > y["eliminado_em"]
		return _total(x["dano"]) < _total(y["dano"]))
	var res := {}
	for c in carros:
		res[c["id"]] = {"dano": c["dano"], "eliminado": c["eliminado"], "eliminado_em": c["eliminado_em"],
				"por": c["por"], "sobreviveu_s": c.get("sobreviveu_s", t), "eliminou": c["eliminou"],
				"perfil": String(c["perfil"].get("id", "")),
				"giros": eventos.filter(func(e): return e["tipo"] == "giro" and e["por"] == c["id"]).size()}
	for c in carros:
		res[c["id"]]["equipe"] = c["equipe"]
	return {"classificacao": ordem.map(func(c): return c["id"]), "carros": res, "eventos": eventos,
			"amostras": amostras, "duracao": t, "equipe_vencedora": vencedora}


static func _total(d: PackedFloat32Array) -> float:
	var s := 0.0
	for x in d:
		s += x
	return s
