class_name PaisagemParallax
extends Control
## Paisagem da tela inicial em quatro camadas (arte/inicio/): céu e montanhas,
## vales e água, autódromo, vegetação e cerca. Parallax híbrido: um movimento
## automático lento e contínuo (ciclo de CICLO_S, sem salto no fim) somado à
## inclinação do aparelho quando há sensor. A camada mais próxima mexe mais.
## Cada camada é escalada por inteiro (sem esticar) com folga suficiente para
## nunca mostrar a borda. Movimento reduzido nas preferências: tudo parado.
## Apresentação, não balanceamento: amplitudes e tempos são de composição.

const PASTA := "res://arte/inicio/"
const CAMADAS := ["camada_1_ceu", "camada_2_vale", "camada_3_autodromo", "camada_4_frente"]
## Deslocamento máximo de cada camada (px da tela de 720): automático e inclinação.
const AMP_AUTO := [4.0, 10.0, 18.0, 32.0]
const AMP_INCLINACAO := [4.0, 10.0, 18.0, 28.0]
const VERTICAL := 0.25  # oscilação vertical, fração da horizontal
const CICLO_S := 36.0
## Inclinação: zona morta (tremor da mão), resposta suavizada e limite.
const ZONA_MORTA := 0.03
const SUAVIZAR := 2.5  # 1/s
const INCLINACAO_MAX := 0.35  # fração da gravidade que leva ao deslocamento máximo
const GRAUS_MAX := 20.0  # no navegador: inclinação (graus) que leva ao máximo
## Lê a orientação no navegador (deviceorientation): o Godot web não entrega o
## sensor. iOS pede permissão para isso; sem ela, fica só o automático.
const JS_ORIENTACAO := "if(!window.__sdOri){window.__sdOri={b:null,g:null};" \
		+ "window.addEventListener('deviceorientation',function(e){if(e.beta!==null){" \
		+ "window.__sdOri.b=e.beta;window.__sdOri.g=e.gamma;}});}"

var _camadas: Array[TextureRect] = []
var _t := 0.0
var _neutro := Vector3.ZERO
var _inclinacao := Vector2.ZERO
var _folga := 0.0
var _neutro_web := Vector2.INF
## Diagnóstico (web, endereço com ?diag=1): camadas, deslocamentos e sensor na tela.
var _diag: Label
var _diag_t := 0.0


## Tamanho do retângulo das camadas em relação à tela (folga do maior
## deslocamento): o shell web usa a mesma conta para o carregamento casar.
static func escala_camadas(largura: float) -> float:
	return (largura + 2.0 * folga()) / maxf(largura, 1.0)


static func folga() -> float:
	return AMP_AUTO[-1] + AMP_INCLINACAO[-1] + 4.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for k in CAMADAS.size():
		var t := TextureRect.new()
		t.texture = load(PASTA + CAMADAS[k] + ".webp")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		_camadas.append(t)
	resized.connect(_enquadrar)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS_ORIENTACAO, true)
		if str(JavaScriptBridge.eval("location.search", true)).contains("diag"):
			_diag = Label.new()
			_diag.add_theme_font_size_override("font_size", 18)
			_diag.add_theme_color_override("font_color", Color.YELLOW)
			_diag.add_theme_color_override("font_outline_color", Color.BLACK)
			_diag.add_theme_constant_override("outline_size", 6)
			_diag.position = Vector2(12, 12)
			_diag.size = Vector2(696, 0)
			_diag.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			_diag.z_index = 10
			add_child(_diag)


## Todas as camadas no mesmo retângulo (a composição das quatro é uma só),
## maior que a tela pela folga do maior deslocamento, nas duas direções.
func _enquadrar() -> void:
	_folga = folga()
	var escala := escala_camadas(size.x)
	var tam := size * escala
	for t in _camadas:
		t.size = tam
	_posicionar()


func _process(delta: float) -> void:
	if _diag != null:
		_diag_t += delta
		if _diag_t > 0.3:
			_diag_t = 0.0
			_diagnostico()
	if not is_visible_in_tree() or Preferencias.reduzir_animacoes:
		return
	_t = fmod(_t + delta, CICLO_S)
	_ler_inclinacao(delta)
	_posicionar()


func _notification(what: int) -> void:
	# Fora de foco (outra aba, app em segundo plano): pausa.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		set_process(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		set_process(true)


## Orientação estimada pela gravidade (não a velocidade angular crua): a
## primeira leitura é a posição neutra; zona morta, suavização e limite.
func _ler_inclinacao(delta: float) -> void:
	if OS.has_feature("web"):
		_ler_inclinacao_web(delta)
		return
	var g := Input.get_gravity()
	if g.length() < 1.0:
		g = Input.get_accelerometer()  # alguns navegadores só dão o acelerômetro
	var alvo := Vector2.ZERO
	if g.length() > 1.0:
		var u := g.normalized()
		if _neutro == Vector3.ZERO:
			_neutro = u
		var d := u - _neutro
		alvo = Vector2(d.x, -d.y) / INCLINACAO_MAX
		if alvo.length() < ZONA_MORTA:
			alvo = Vector2.ZERO
		alvo = alvo.limit_length(1.0)
	_inclinacao = _inclinacao.lerp(alvo, 1.0 - exp(-SUAVIZAR * delta))


func _ler_inclinacao_web(delta: float) -> void:
	var alvo := Vector2.ZERO
	var g = JavaScriptBridge.eval("window.__sdOri?window.__sdOri.g:null", true)
	var b = JavaScriptBridge.eval("window.__sdOri?window.__sdOri.b:null", true)
	if g != null and b != null:
		var v := Vector2(float(g), float(b))
		if _neutro_web == Vector2.INF:
			_neutro_web = v
		alvo = (v - _neutro_web) / GRAUS_MAX
		if alvo.length() < ZONA_MORTA:
			alvo = Vector2.ZERO
		alvo = alvo.limit_length(1.0)
	_inclinacao = _inclinacao.lerp(alvo, 1.0 - exp(-SUAVIZAR * delta))


func _diagnostico() -> void:
	var linhas := ["DIAG parallax  t=%.1f  tela=%s  reduzir=%s" % [_t, str(size.round()), str(Preferencias.reduzir_animacoes)]]
	for k in _camadas.size():
		var c := _camadas[k]
		var tx := c.texture
		linhas.append("%d %s idx=%d tex=%s pos=%s" % [k + 1, CAMADAS[k].get_slice("_", 2), c.get_index(),
				str(tx.get_size()) if tx != null else "NULA", str(c.position.round())])
	var g = JavaScriptBridge.eval("window.__sdOri?JSON.stringify(window.__sdOri):'sem listener'", true)
	var perm = JavaScriptBridge.eval("(window.DeviceOrientationEvent&&typeof DeviceOrientationEvent.requestPermission==='function')?'pede permissao':'sem permissao'", true)
	linhas.append("sensor=%s  %s  inclinacao=%s" % [str(g), str(perm), str(_inclinacao.snapped(Vector2(0.01, 0.01)))])
	linhas.append(str(JavaScriptBridge.eval("navigator.userAgent", true)))
	_diag.text = "\n".join(linhas)


func _posicionar() -> void:
	var fase := TAU * _t / CICLO_S
	# Lemniscata suave: volta ao início sem salto, sem parar nos extremos.
	var auto := Vector2(sin(fase), VERTICAL * sin(2.0 * fase))
	for k in _camadas.size():
		var d: Vector2 = auto * AMP_AUTO[k] + _inclinacao * AMP_INCLINACAO[k]
		d = d.clamp(Vector2(-_folga, -_folga), Vector2(_folga, _folga))
		_camadas[k].position = (size - _camadas[k].size) / 2.0 + d
