class_name CorridaVisual
extends Control
## Mostra uma corrida já resolvida pela Simulacao. Só lê `amostras`: a posição
## de cada carro no tempo vira ponto na pista e índice de sprite pelo rumo.

const LARGURA_PISTA_M := 12.0
## Pixels por metro dos carros e mínimo da largura da pista na tela: o sprite
## pré-renderizado tem tamanho fixo, independente do zoom da pista.
const ESCALA_CARRO := 7.0
const LARGURA_MIN_PX := 26.0
const COR_PISTA := Color(0.32, 0.33, 0.36)
const COR_BORDA := Color(0.85, 0.85, 0.85)

## Segundos desde a largada. Quem controla é o dono (tela de corrida).
var tempo := 0.0:
	set(v):
		tempo = v
		_posicionar()

var _pista: Pista
var _tempos := PackedFloat64Array()
var _s := {}  # id -> PackedFloat64Array
var _sprites := {}  # id -> CarroSprite
var _carros: Node2D
var _escala := 1.0
var _origem := Vector2.ZERO
var _contorno := PackedVector2Array()


func _init() -> void:
	_carros = Node2D.new()
	_carros.y_sort_enabled = true
	add_child(_carros)
	resized.connect(_enquadrar)


## cores: id -> Color. Ids sem cor ganham uma derivada do id.
func mostrar(pista: Pista, resultado: Dictionary, cores: Dictionary = {}) -> void:
	_pista = pista
	_tempos = PackedFloat64Array()
	_s = {}
	for a in resultado["amostras"]:
		_tempos.append(a["t"])
		for id in a["s"]:
			if not _s.has(id):
				_s[id] = PackedFloat64Array()
			_s[id].append(a["s"][id])
	for c in _carros.get_children():
		c.queue_free()
	_sprites = {}
	for id in _s:
		var sp := CarroSprite.new()
		sp.escala = ESCALA_CARRO
		sp.cor = cores.get(id, Color.from_hsv(fposmod(hash(id) / 1000.0, 1.0), 0.7, 0.95))
		_carros.add_child(sp)
		_sprites[id] = sp
	_enquadrar()


func limpar() -> void:
	_pista = null
	for c in _carros.get_children():
		c.queue_free()
	_sprites = {}
	queue_redraw()


func duracao() -> float:
	return _tempos[-1] if not _tempos.is_empty() else 0.0


## Distância percorrida pelo carro no tempo atual (interpolada).
func distancia(id: String) -> float:
	var serie: PackedFloat64Array = _s[id]
	var i := clampi(_tempos.bsearch(tempo) - 1, 0, _tempos.size() - 1)
	if i + 1 >= _tempos.size():
		return serie[i]
	var f := clampf((tempo - _tempos[i]) / maxf(_tempos[i + 1] - _tempos[i], 1e-6), 0.0, 1.0)
	return lerpf(serie[i], serie[i + 1], f)


## Ids na ordem de corrida no tempo atual.
func ordem() -> Array:
	var ids := _s.keys()
	ids.sort_custom(func(a, b): return distancia(a) > distancia(b))
	return ids


func _enquadrar() -> void:
	if _pista == null or size.x <= 0.0:
		return
	var pts := _pista.pontos(4.0)
	var caixa := Rect2(Iso.para_tela(pts[0], 1.0), Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(Iso.para_tela(p, 1.0))
	caixa = caixa.grow(LARGURA_PISTA_M)
	_escala = minf(size.x / caixa.size.x, size.y / caixa.size.y)
	_origem = size * 0.5 - caixa.get_center() * _escala
	_contorno = PackedVector2Array()
	for p in pts:
		_contorno.append(_origem + Iso.para_tela(p, _escala))
	_posicionar()
	queue_redraw()


func _posicionar() -> void:
	if _pista == null:
		return
	for id in _sprites:
		var s := distancia(id)
		var sp: CarroSprite = _sprites[id]
		sp.position = _origem + Iso.para_tela(_pista.posicao_em(s), _escala)
		sp.direcao = Iso.direcao(_pista.rumo_em(s))


func _draw() -> void:
	if _contorno.size() < 2:
		return
	var largura := maxf(LARGURA_PISTA_M * _escala * 0.75, LARGURA_MIN_PX)
	draw_polyline(_contorno, COR_BORDA, largura + 3.0, true)
	draw_polyline(_contorno, COR_PISTA, largura, true)
	var largada := _origem + Iso.para_tela(_pista.posicao_em(0.0), _escala)
	var normal := Iso.para_tela(Vector2.from_angle(_pista.rumo_em(0.0) + PI / 2.0), 1.0).normalized() * largura * 0.5
	draw_line(largada - normal, largada + normal, Color.WHITE, 3.0)
