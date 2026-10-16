class_name Gaivotas
extends Control
## Ambientação do mapa das lojas: de vez em quando uma gaivota cruza a tela,
## batendo asa e às vezes planando. Só visual (não recebe toque). A tira
## arte/ui/gaivota.png tem 12 quadros lado a lado (bico à direita, alinhados
## pelo bico): uma batida de asa inteira. Com "Reduzir animações", não aparece.

const QUADROS := 12
const CICLO := 12
const FPS := 14.0
const ESPERA_S := Vector2(5.0, 14.0)  # intervalo entre uma gaivota e a próxima
const TRAVESSIA_S := Vector2(7.0, 11.0)  # tempo para cruzar a tela
const ALTURA_PX := Vector2(44.0, 66.0)  # altura na tela (escala uniforme)
const FAIXA_Y := Vector2(0.04, 0.55)  # onde ela pode passar (fração da altura)
const PLANA := 5  # quadro de asa aberta, para planar

var _tira: Texture2D
var _quadros: Array[AtlasTexture] = []
var _voando: Array = []  # {no, vel, t, base_y, fase, plana}
var _espera := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_tira = Aba.arte("gaivota")
	if _tira == null or Preferencias.reduzir_animacoes:
		set_process(false)
		return
	var lw := float(_tira.get_width()) / QUADROS
	for i in QUADROS:
		var q := AtlasTexture.new()
		q.atlas = _tira
		q.region = Rect2(i * lw, 0, lw, _tira.get_height())
		_quadros.append(q)
	_rng.randomize()
	_espera = _rng.randf_range(1.0, 4.0)  # a primeira vem logo


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return
	_espera -= delta
	if _espera <= 0.0:
		_soltar()
		_espera = _rng.randf_range(ESPERA_S.x, ESPERA_S.y)
	for g in _voando.duplicate():
		var no: TextureRect = g["no"]
		g["t"] += delta
		no.position.x += g["vel"] * delta
		no.position.y = g["base_y"] + sin(g["t"] * 1.7 + g["fase"]) * 6.0
		# Bate asa; de vez em quando plana um pouco.
		g["plana"] -= delta
		if g["plana"] > 0.0:
			no.texture = _quadros[PLANA]
		else:
			no.texture = _quadros[int(g["t"] * FPS) % CICLO]
			if _rng.randf() < delta * 0.25:
				g["plana"] = _rng.randf_range(0.6, 1.4)
		if no.position.x > size.x + 20.0 or no.position.x < -no.size.x - 20.0:
			no.queue_free()
			_voando.erase(g)


func _soltar() -> void:
	var alto := _rng.randf_range(ALTURA_PX.x, ALTURA_PX.y)
	var q: AtlasTexture = _quadros[0]
	var tam := Vector2(alto * q.region.size.x / q.region.size.y, alto)  # escala uniforme
	var no := TextureRect.new()
	no.texture = q
	no.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	no.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	no.size = tam
	no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var para_direita := _rng.randf() < 0.5
	no.flip_h = not para_direita  # a arte olha para a direita
	var base_y := _rng.randf_range(FAIXA_Y.x, FAIXA_Y.y) * size.y
	no.position = Vector2(-tam.x if para_direita else size.x, base_y)
	# Mais longe (menor) voa mais devagar e mais apagada.
	var perto := inverse_lerp(ALTURA_PX.x, ALTURA_PX.y, alto)
	no.modulate.a = lerpf(0.8, 1.0, perto)
	var vel := (size.x + tam.x) / _rng.randf_range(TRAVESSIA_S.x, TRAVESSIA_S.y) * lerpf(0.85, 1.1, perto)
	add_child(no)
	_voando.append({"no": no, "vel": vel if para_direita else -vel, "t": 0.0, "base_y": base_y,
			"fase": _rng.randf() * TAU, "plana": 0.0})
