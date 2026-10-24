class_name Rodas
extends RefCounted
## Rodas dos carros gerados (pedido do usuário: "as rodas deveriam ser a mesma
## pra todos os carros com possibilidade de trocar na oficina"): um pneu para
## todos e um catálogo de aros, facetados. O jogador escolhe o aro de cada carro
## na cabine de pintura (aba RODAS; fica em Carro.faixas["roda"]).
##
## A roda é montada no raio do carro, com o eixo de giro em X e o centro no
## eixo; `lado` = +1 ou -1 (a face do aro olha para fora, para +X ou -X). Cada
## roda é uma malha só (uma superfície, shaders/carro_detalhe), guardada por
## desenho, raio (em cm) e lado durante a sessão.

const DESENHOS := ["cinco", "aco", "seis", "malha", "turbina", "disco", "estrela", "dez"]
const NOMES := {"cinco": "Cinco raios", "aco": "Aço com calota", "seis": "Seis raios", "malha": "Malha",
		"turbina": "Turbina", "disco": "Disco aero", "estrela": "Três raios", "dez": "Dez raios finos"}
const PADRAO := "cinco"
const ARO := 0.64  # raio do aro / raio da roda
const LARGURA := 0.62  # largura do pneu / raio

static var _cache := {}


static func valido(desenho: String) -> bool:
	return desenho in DESENHOS


## O desenho gravado, ou o padrão (saves antigos, valor desconhecido).
static func desenho_de(faixas: Dictionary) -> String:
	var d := String(faixas.get("roda", PADRAO))
	return d if valido(d) else PADRAO


static func nome(desenho: String) -> String:
	return String(NOMES.get(desenho, NOMES[PADRAO]))


## Roda pronta (nó com a malha), centrada no eixo.
static func montar(desenho: String, raio: float, lado: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha(desenho, raio, lado)
	return mi


## Malha da roda (guardada na sessão).
static func malha(desenho: String, raio: float, lado: float) -> ArrayMesh:
	if not valido(desenho):
		desenho = PADRAO
	var cm := roundi(raio * 100.0)
	var chave := "%s|%d|%d" % [desenho, cm, 1 if lado >= 0.0 else -1]
	if not _cache.has(chave):
		var m := MontagemMalha.new()
		_construir(m, desenho, cm / 100.0, 1.0 if lado >= 0.0 else -1.0)
		_cache[chave] = m.malha()
	return _cache[chave]


static func _construir(m: MontagemMalha, desenho: String, r: float, lado: float) -> void:
	var largura := r * LARGURA
	# pneu: banda de rodagem e flancos (prisma de 14 lados)
	_anel(m, "pneu", r, r * ARO * 1.02, largura, 14, 0.0)
	_anel(m, "flanco", r * 0.93, r * ARO * 1.02, largura * 1.06, 14, 0.0)
	# freio por trás do aro (a pinça fica na carroceria: não gira)
	_disco(m, "freio", r * ARO * 0.8, 0.02, 12, lado * -0.02)
	var face := lado * largura * 0.32
	# borda do aro
	_anel(m, "aro_roda", r * ARO, r * ARO * 0.9, 0.04, 14, face)
	match desenho:
		"aco":
			_disco(m, "aro_roda_escuro", r * ARO * 0.92, 0.03, 14, face - lado * 0.01)
			_disco(m, "cromo_roda", r * ARO * 0.7, 0.03, 12, face + lado * 0.005)
			_disco(m, "aro_roda", r * 0.16, 0.04, 8, face + lado * 0.02)
		"cinco", "seis", "estrela", "dez":
			var n: int = {"cinco": 5, "seis": 6, "estrela": 3, "dez": 10}[desenho]
			var esp: float = {"cinco": 0.22, "seis": 0.17, "estrela": 0.3, "dez": 0.07}[desenho] * r
			_disco(m, "aro_roda_escuro", r * ARO * 0.92, 0.02, 14, face - lado * 0.03)
			for k in n:
				_raio(m, "aro_roda", r * 0.17, r * ARO * 0.93, esp, 0.035, TAU * k / n, face, Vector3.ZERO)
			_disco(m, "aro_roda", r * 0.2, 0.05, 8, face + lado * 0.01)
		"malha":
			_disco(m, "aro_roda_escuro", r * ARO * 0.92, 0.02, 14, face - lado * 0.03)
			# Treliça: pares de raios inclinados que se cruzam.
			for k in 8:
				for inc in [0.42, -0.42]:
					_raio(m, "aro_roda", r * 0.15, r * ARO * 0.93, r * 0.045, 0.03, TAU * k / 8, face, Vector3(inc, 0, 0))
			_disco(m, "cromo_roda", r * 0.2, 0.05, 8, face + lado * 0.01)
		"turbina":
			_disco(m, "aro_roda", r * ARO * 0.92, 0.025, 14, face)
			for k in 12:
				_raio(m, "aro_roda_escuro", r * 0.22, r * ARO * 0.86, r * 0.07, 0.03, TAU * k / 12, face + lado * 0.01,
						Vector3(0, 0.5, 0))
			_disco(m, "aro_roda", r * 0.18, 0.05, 8, face + lado * 0.02)
		"disco":
			_disco(m, "aro_roda", r * ARO * 0.93, 0.03, 14, face)
			for k in 3:
				var a := TAU * k / 3
				_disco(m, "aro_roda_escuro", r * 0.09, 0.035, 8, face + lado * 0.002,
						Vector3(0, cos(a), sin(a)) * r * ARO * 0.55)
			_disco(m, "aro_roda", r * 0.14, 0.05, 8, face + lado * 0.01)


## Anel (tubo) no plano YZ: raio externo, interno, largura em X.
static func _anel(m: MontagemMalha, estilo: String, re: float, ri: float, larg: float, lados: int, x: float) -> void:
	var hx := Vector3(larg * 0.5, 0, 0)
	var c := Vector3(x, 0, 0)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var o0 := Vector3(0, cos(a0), sin(a0))
		var o1 := Vector3(0, cos(a1), sin(a1))
		for q in [[o0 * re - hx, o1 * re - hx, o1 * re + hx, o0 * re + hx],  # banda
				[o0 * ri + hx, o1 * ri + hx, o1 * ri - hx, o0 * ri - hx],  # dentro
				[o0 * re + hx, o1 * re + hx, o1 * ri + hx, o0 * ri + hx],  # face +
				[o0 * ri - hx, o1 * ri - hx, o1 * re - hx, o0 * re - hx]]:  # face -
			m.tri(estilo, c + q[0], c + q[1], c + q[2])
			m.tri(estilo, c + q[0], c + q[2], c + q[3])


## Disco (cilindro deitado em X) com centro em (x, desloc.y, desloc.z).
static func _disco(m: MontagemMalha, estilo: String, raio: float, esp: float, lados: int, x: float,
		desloc := Vector3.ZERO) -> void:
	m.cilindro(estilo, raio, esp, lados, MontagemMalha.xf(Vector3(x, desloc.y, desloc.z), Vector3(0, 0, PI / 2)))


## Raio do aro: barra do cubo até a borda, girada `ang` em torno de X; `giro`
## gira a barra no próprio lugar (malha, turbina).
static func _raio(m: MontagemMalha, estilo: String, de: float, ate: float, larg: float, esp: float, ang: float,
		x: float, giro: Vector3) -> void:
	var dir := Vector3(0, cos(ang), sin(ang))
	var base := MontagemMalha.xf(Vector3(x, 0, 0) + dir * (de + ate) * 0.5, Vector3(ang, 0, 0))
	if giro != Vector3.ZERO:
		base.basis = base.basis * Basis.from_euler(giro)
	m.caixa(estilo, Vector3(esp, ate - de, larg), base)
