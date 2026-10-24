class_name Nuvens
extends Control
## Ambientação do mapa das lojas: nuvens passando devagar com o vento, cada uma
## com a sombra no chão (a mesma silhueta, escura e deslocada). As sombras ficam
## numa camada à parte (`sombras`), abaixo das gaivotas; as nuvens, acima. Só
## visual (não recebe toque). Com "Reduzir animações", não aparece.
## Arte: arte/ui/nuvem_1..9.png (da maior para a menor).

const ARTES := 9
const MAX_NA_TELA := 2
const ESPERA_S := Vector2(8.0, 20.0)  # intervalo entre uma nuvem e a próxima
const VELOCIDADE := Vector2(9.0, 16.0)  # px/s, sempre no sentido do vento
const ESCALA := Vector2(0.85, 1.2)  # sobre o tamanho da arte (uniforme)
const FAIXA_Y := Vector2(-0.05, 0.75)  # onde passa (fração da altura)
const OPACIDADE := 0.78
const SOMBRA := Color(0.0, 0.02, 0.06, 0.38)
const SOMBRA_DESLOCA := Vector2(70.0, 150.0)  # o sol vem do alto, à esquerda

var sombras: Control
var _texturas: Array[Texture2D] = []
var _passando: Array = []  # {nuvem, sombra, vel}
var _espera := 0.0
var _vento := 1.0  # 1 = para a direita
var _rng := RandomNumberGenerator.new()


func _init(camada_sombras: Control) -> void:
	sombras = camada_sombras


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if sombras != null:
		sombras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sombras.clip_contents = true
	for i in ARTES:
		var t := Aba.arte("nuvem_%d" % (i + 1))
		if t != null:
			_texturas.append(t)
	if _texturas.is_empty() or Preferencias.reduzir_animacoes:
		set_process(false)
		return
	_rng.randomize()
	_vento = 1.0 if _rng.randf() < 0.5 else -1.0
	# Ao abrir, já há uma nuvem no meio do caminho.
	_soltar.call_deferred(true)
	_espera = _rng.randf_range(ESPERA_S.x, ESPERA_S.y)


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return
	_espera -= delta
	if _espera <= 0.0 and _passando.size() < MAX_NA_TELA:
		_soltar(false)
		_espera = _rng.randf_range(ESPERA_S.x, ESPERA_S.y)
	for p in _passando.duplicate():
		var n: TextureRect = p["nuvem"]
		var s: TextureRect = p["sombra"]
		n.position.x += p["vel"] * delta
		s.position = n.position + SOMBRA_DESLOCA
		var fora := n.position.x > size.x + 10.0 if _vento > 0.0 \
				else n.position.x < -n.size.x - SOMBRA_DESLOCA.x - 10.0
		if fora:
			n.queue_free()
			s.queue_free()
			_passando.erase(p)


## Uma nuvem nova (as grandes saem menos). `no_meio`: já dentro da tela.
func _soltar(no_meio: bool) -> void:
	if size.x <= 0.0:
		return
	# As médias são as mais comuns; a maior (índice 0) e as miúdas, raras.
	var i := clampi(int(round(_rng.randfn(3.0, 1.8))), 0, _texturas.size() - 1)
	var tex := _texturas[i]
	var tam := tex.get_size() * _rng.randf_range(ESCALA.x, ESCALA.y)
	var y := _rng.randf_range(FAIXA_Y.x, FAIXA_Y.y) * size.y
	var x := _rng.randf_range(0.0, size.x - tam.x * 0.5) if no_meio \
			else (-tam.x - SOMBRA_DESLOCA.x if _vento > 0.0 else size.x)
	var flip := _rng.randf() < 0.5
	var sombra := _figura(tex, tam, flip)
	sombra.modulate = SOMBRA
	sombras.add_child(sombra)
	var nuvem := _figura(tex, tam, flip)
	nuvem.modulate.a = OPACIDADE
	add_child(nuvem)
	nuvem.position = Vector2(x, y)
	sombra.position = nuvem.position + SOMBRA_DESLOCA
	_passando.append({"nuvem": nuvem, "sombra": sombra,
			"vel": _vento * _rng.randf_range(VELOCIDADE.x, VELOCIDADE.y)})


func _figura(tex: Texture2D, tam: Vector2, flip: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size = tam
	t.flip_h = flip
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
