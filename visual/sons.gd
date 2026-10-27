class_name Sons
extends Node
## Sons provisórios gerados em código (sem arquivo de áudio): motor do carro
## do jogador, bipes da largada, chegada e ultrapassagem. Em AudioStreamWAV
## porque a exportação web sem threads não toca AudioStreamGenerator.
##
## Motor em duas camadas gravadas: o grave é um V8 em marcha lenta
## (motor_grave), o agudo é o da Kenney (motor, CC0); o tom das duas segue o
## giro (cai na troca de marcha) e o agudo cresce com ele. Pneu da Kenney.
## Sem os arquivos, voltam os gerados: motor em duas camadas e chiado. Público, oficina, impacto e raspagem da arena e
## porta vêm do GDC Game Audio Bundle (tools/preparar_sons.py); sem eles,
## voltam os gerados (público, oficina) ou não toca nada. Zebra e bipes são
## sempre gerados.
## Sons de interface curtos (moeda, toque, batida, porta): Sons.tocar_ui().
## The Fastfather (docs/idle/sonorizacao.md): barramentos Musica, Efeitos,
## Ambiente e Corrida (Sons.barramentos); sem eles (Chrome & Wreckage) tudo vai
## ao Master, como sempre.

const TAXA := 22050

var _motor: AudioStreamPlayer
var _motor_alto: AudioStreamPlayer
var _motor_grave: AudioStreamPlayer
var _pelotao: AudioStreamPlayer  # rivais perto: o mesmo V8 em outro tom
var _pelotao_t := 0.0
var _pneu: AudioStreamPlayer
var _zebra: AudioStreamPlayer
var _torcida: AudioStreamPlayer
var _efeito: AudioStreamPlayer
var _bipe_curto: AudioStreamWAV
var _bipe_longo: AudioStreamWAV
var _subida: AudioStreamWAV
var _descida: AudioStreamWAV
var _chegada: AudioStreamWAV
var _aviso: AudioStreamWAV
var _volume := 1.0  # volume_motor (abertura)
var _giro := -1.0  # fração do giro (0..1); < 0: o tom segue a velocidade
## Volume alvo de cada laço (dB) e o atual, que segue devagar.
var _alvos := {}
const MUDO_DB := -60.0


const PASTA := "res://arte/sons/"
## Volume (dB) do motor gravado e do pneu gravado quando cantando.
const MOTOR_DB := -10.0
## Tom (pitch) do motor gravado no giro mínimo e no máximo da escala.
const MOTOR_TOM_MIN := 1.15
const MOTOR_TOM_MAX := 2.6
## Quanto o tom anda por segundo atrás do alvo (desce rápido na troca, sobe
## acompanhando o giro).
const MOTOR_TOM_RAPIDEZ := 9.0
## Tom do grave (V8 em marcha lenta, ~800 rpm na gravação) em relação ao do
## agudo: no giro mínimo da escala ele fica perto do original.
const GRAVE_RAZAO := 0.9
## Volume do grave no giro mínimo e no máximo (o agudo faz o contrário).
const GRAVE_DB_MIN_GIRO := -6.0
const GRAVE_DB_MAX_GIRO := -12.0
const AGUDO_DB_MIN_GIRO := -16.0
var _tom_alvo := -1.0
const PNEU_DB := -8.0
## Volume da torcida gravada no auge.
const TORCIDA_DB := -10.0
var _gravado := false
var _torcida_gravada := false


## Laço gravado (ou null sem o arquivo).
static func _arquivo(nome: String, laco: bool) -> AudioStream:
	var caminho := PASTA + nome + ".ogg"
	if not ResourceLoader.exists(caminho):
		return null
	var s: AudioStream = load(caminho)
	if laco and s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func _init() -> void:
	if AudioServer.get_bus_index("Corrida") >= 0:
		child_entered_tree.connect(func(n):
			if n is AudioStreamPlayer:
				(n as AudioStreamPlayer).bus = "Corrida")
	var motor := _arquivo("motor", true)
	_gravado = motor != null
	_motor = _laco(motor if _gravado else _onda(90.0, 1.0, 0.18, true, true), MOTOR_DB if _gravado else -14.0)
	_motor_alto = _laco(_onda(180.0, 1.0, 0.12, true, true), MUDO_DB)
	var grave := _arquivo("motor_grave", true)
	_motor_grave = _laco(grave, MOTOR_DB + GRAVE_DB_MIN_GIRO if grave != null else MUDO_DB)
	_pelotao = _laco(_arquivo("motor_grave", true), MUDO_DB)
	var pneu := _arquivo("pneu", true)
	_pneu = _laco(pneu if pneu != null else _ruido(1.0, 0.22, 0.55), MUDO_DB)
	_zebra = _laco(_ruido(1.0, 0.3, 0.15, 28.0), MUDO_DB)
	var torcida_gravada := _arquivo("torcida", true)
	_torcida_gravada = torcida_gravada != null
	_torcida = _laco(torcida_gravada if _torcida_gravada else _ruido(2.0, 0.2, 0.9, 0.0, true), MUDO_DB)
	_efeito = AudioStreamPlayer.new()
	_efeito.max_polyphony = 4
	add_child(_efeito)
	_bipe_curto = _onda(660.0, 0.12, 0.35)
	_bipe_longo = _onda(990.0, 0.4, 0.35)
	_subida = _varredura(520.0, 880.0, 0.18)
	_descida = _varredura(520.0, 300.0, 0.2)
	_chegada = _varredura(660.0, 1320.0, 0.5)
	_aviso = _dois_bipes()


func _laco(s: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	_alvos[p] = db
	return p


## Motor: liga/desliga. Sem giro informado, o tom acompanha a velocidade (m/s).
func motor(ligado: bool, velocidade := 0.0) -> void:
	if not ligado:
		for p in [_motor, _motor_alto, _motor_grave, _pelotao, _pneu, _zebra]:
			if p.playing:
				p.stop()
		_alvos[_pneu] = MUDO_DB
		_alvos[_zebra] = MUDO_DB
		_alvos[_pelotao] = MUDO_DB
		_giro = -1.0
		_tom_alvo = -1.0
		return
	for p in ([_motor] if _gravado else [_motor, _motor_alto]) + ([_motor_grave] if _motor_grave.stream else []):
		if not p.playing:
			p.play()
	if _giro < 0.0:
		_motor.pitch_scale = clampf(0.6 + velocidade / 40.0, 0.5, 3.0)
		_motor_grave.pitch_scale = _motor.pitch_scale * GRAVE_RAZAO


## Giro do motor (0..1 da escala): o tom das duas camadas e o volume do agudo.
func motor_giro(fracao: float) -> void:
	_giro = clampf(fracao, 0.0, 1.0)
	if _gravado:
		# Uma camada só: a gravação já tem corpo; o tom faz o giro. Tom base
		# alto (abaixo de ~1 a gravação soa como trator); a troca de marcha
		# desliza o tom em vez de saltar (_process).
		_tom_alvo = lerpf(MOTOR_TOM_MIN, MOTOR_TOM_MAX, _giro)
		if _motor_grave.stream:
			_alvos[_motor] = MOTOR_DB + lerpf(AGUDO_DB_MIN_GIRO, 0.0, _giro)
			_alvos[_motor_grave] = MOTOR_DB + lerpf(GRAVE_DB_MIN_GIRO, GRAVE_DB_MAX_GIRO, _giro)
		else:
			_alvos[_motor] = MOTOR_DB + lerpf(-3.0, 0.0, _giro)
		return
	_motor.pitch_scale = lerpf(0.55, 1.75, _giro)
	_motor_alto.pitch_scale = lerpf(0.6, 1.9, _giro)
	_alvos[_motor_alto] = lerpf(-34.0, -15.0, _giro * _giro)


## Rivais perto (0..1, pela menor diferença para o da frente ou o de trás): o
## mesmo motor gravado num tom um pouco diferente, que oscila (outros carros,
## outros giros). Sem o arquivo, nada.
const PELOTAO_DB := -9.0
func pelotao(f: float) -> void:
	if _pelotao.stream == null:
		return
	_ligar(_pelotao, lerpf(MUDO_DB, PELOTAO_DB, clampf(f, 0.0, 1.0)) if f > 0.02 else MUDO_DB)


## Pneu cantando (freada forte ou arrancada) e rodas na zebra.
func pneu(cantando: bool, zebra: bool) -> void:
	_ligar(_pneu, (PNEU_DB if _gravado else -17.0) if cantando else MUDO_DB)
	_ligar(_zebra, -20.0 if zebra else MUDO_DB)


## Torcida: 0..1 (sobe na reta final com disputa).
func torcida(f: float) -> void:
	var alto := TORCIDA_DB if _torcida_gravada else -16.0
	_ligar(_torcida, lerpf(MUDO_DB, alto, clampf(f, 0.0, 1.0)) if f > 0.01 else MUDO_DB)


func _ligar(p: AudioStreamPlayer, db: float) -> void:
	_alvos[p] = db
	if db > MUDO_DB and not p.playing:
		p.volume_db = MUDO_DB
		p.play()


## Volumes seguem os alvos (sem cortes secos); laço mudo para de tocar.
func _process(delta: float) -> void:
	if _gravado and _tom_alvo > 0.0:
		_motor.pitch_scale = lerpf(_motor.pitch_scale, _tom_alvo, 1.0 - exp(-delta * MOTOR_TOM_RAPIDEZ))
		_motor_grave.pitch_scale = _motor.pitch_scale * GRAVE_RAZAO
	_pelotao_t += delta
	if _pelotao.playing:
		_pelotao.pitch_scale = maxf(_motor.pitch_scale * GRAVE_RAZAO * (1.07 + 0.06 * sin(_pelotao_t * 0.9)), 0.5)
	for p in _alvos:
		var do_motor: bool = p == _motor or p == _motor_alto or p == _motor_grave or p == _pelotao
		var alvo: float = _alvos[p] + (linear_to_db(maxf(_volume, 0.001)) if do_motor else 0.0)
		p.volume_db = move_toward(p.volume_db, alvo, delta * 90.0)
		if p.playing and not do_motor and p.volume_db <= MUDO_DB + 0.5 and _alvos[p] <= MUDO_DB:
			p.stop()


## Volume do motor, 0..1 (entrada e saída suaves da abertura).
func volume_motor(f: float) -> void:
	_volume = f
	_motor.volume_db = float(_alvos[_motor]) + linear_to_db(maxf(f, 0.001))
	_motor_grave.volume_db = float(_alvos[_motor_grave]) + linear_to_db(maxf(f, 0.001))


func largada(final := false) -> void:
	_tocar(_bipe_longo if final else _bipe_curto)


const PASSAGEM_INTERVALO_MS := 2500
var _passagem_ms := -100000


## Ultrapassagem: o bipe (sobe se ganhou, desce se perdeu) e o carro passando.
func ultrapassagem(ganhou: bool) -> void:
	_tocar(_subida if ganhou else _descida)
	var agora := Time.get_ticks_msec()
	if agora - _passagem_ms >= PASSAGEM_INTERVALO_MS:  # pelotão trocando de posição: um só
		_passagem_ms = agora
		tocar_ui(self, "passagem", -6.0, randf_range(0.95, 1.1))


## Chegada: o sinal e o público comemorando.
func chegada() -> void:
	_tocar(_chegada)
	tocar_ui(self, "comemoracao", -10.0)


func ultima_volta() -> void:
	_tocar(_aviso)


func _tocar(s: AudioStream) -> void:
	_efeito.stream = s
	_efeito.play()


static var _ambientes := {}  # nome -> AudioStreamWAV


## Fundo acústico das cenas (historia.json → cenarios.<id>.som), em laço:
## "oficina" = galpão com máquinas e vozes (arte/sons/oficina.ogg); sem o
## arquivo, o gerado (ventilação, zumbido, relógio e metal ao longe). null se
## o nome não existe.
static func ambiente(nome: String) -> AudioStream:
	if nome != "oficina":
		return null
	if not _ambientes.has(nome):
		var gravado := _arquivo(nome, true)
		_ambientes[nome] = gravado if gravado != null else _oficina()
	return _ambientes[nome]


static func _oficina() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var vento := 0.0
	var vento2 := 0.0
	# Batidas de metal ao longe: [início (s), frequência base (Hz), força].
	var metais := [[1.7, 1830.0, 0.5], [5.3, 2410.0, 0.35], [6.1, 1290.0, 0.25]]
	for i in n:
		var t := float(i) / TAXA
		# Ventilação: ruído passado duas vezes num filtro baixo, ondulando devagar.
		vento = lerpf(vento, rng.randf_range(-1.0, 1.0), 0.06)
		vento2 = lerpf(vento2, vento, 0.08)
		var x := vento2 * 0.55 * (0.85 + 0.15 * sin(TAU * t / dur))
		# Zumbido de lâmpada/transformador.
		x += (sin(TAU * 120.0 * t) * 0.6 + sin(TAU * 240.0 * t) * 0.25) * 0.035
		# Relógio: um tique curto por segundo, alternando o tom (tic-tac).
		var dt := fmod(t, 1.0)
		if dt < 0.012:
			x += sin(TAU * (3200.0 if int(t) % 2 == 0 else 2700.0) * dt) * 0.12 * (1.0 - dt / 0.012)
		for m in metais:
			var tm: float = t - float(m[0])
			if tm >= 0.0 and tm < 1.2:
				var f: float = m[1]
				var env := exp(-tm * 5.0) * float(m[2]) * 0.18
				x += (sin(TAU * f * tm) + 0.6 * sin(TAU * f * 2.76 * tm) + 0.3 * sin(TAU * f * 5.4 * tm)) * env
		var borda := minf(1.0, minf(t / 0.05, (dur - t) / 0.05))
		dados.encode_s16(i * 2, int(clampf(x * lerpf(0.7, 1.0, borda), -1.0, 1.0) * 32767.0))
	return _wav(dados, true, n)


static var _curtos := {}  # nome -> AudioStream (ou null sem o arquivo)


## Som curto de arte/sons (moeda, toque, batida, porta) num tocador próprio que some
## ao acabar. Sem o arquivo, não toca nada.
static func tocar_ui(no: Node, nome: String, db := 0.0, tom := 1.0, variar := true) -> void:
	if no == null or not no.is_inside_tree():
		return
	if not _curtos.has(nome):
		_curtos[nome] = _arquivo(nome, false)
	var s: AudioStream = _curtos[nome]
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	# ±3% de tom: mil toques não soam iguais.
	p.pitch_scale = tom * (randf_range(0.97, 1.03) if variar else 1.0)
	if AudioServer.get_bus_index("Efeitos") >= 0:
		p.bus = "Efeitos"
	p.finished.connect(p.queue_free)
	# Adiado e com autoplay: funciona também chamado no meio do _ready de uma tela.
	p.autoplay = true
	no.get_tree().root.add_child.call_deferred(p)


# --- The Fastfather: barramentos, recompensa, rádio ----------------------------

## Cria os barramentos (uma vez): Musica, Efeitos, Ambiente e Corrida (que
## passa pelos Efeitos e tem o filtro do "rádio de box").
static func barramentos() -> void:
	if AudioServer.get_bus_index("Efeitos") >= 0:
		return
	for nome in ["Musica", "Efeitos", "Ambiente", "Corrida"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nome)
		AudioServer.set_bus_send(i, "Efeitos" if nome == "Corrida" else "Master")
	var filtro := AudioEffectLowPassFilter.new()
	filtro.cutoff_hz = 900.0
	var corrida := AudioServer.get_bus_index("Corrida")
	AudioServer.add_bus_effect(corrida, filtro)
	AudioServer.set_bus_effect_enabled(corrida, 0, false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), 0.0)


## Rádio de box: a corrida abafada (antes da transmissão na TV).
static func radio(ligado: bool) -> void:
	var i := AudioServer.get_bus_index("Corrida")
	if i >= 0:
		AudioServer.set_bus_effect_enabled(i, 0, ligado)
		AudioServer.set_bus_volume_db(i, -4.0 if ligado else 0.0)


## A família de recompensa (docs/idle/sonorizacao.md, 3.2): o mesmo desenho que
## sobe, em quatro tamanhos (1 coleta pequena … 4 modalidade nova, com aplauso).
## A música abaixa por um instante para a recompensa aparecer.
static func recompensa(no: Node, tamanho: int) -> void:
	var t := clampi(tamanho, 1, 4)
	tocar_ui(no, "recompensa_%d" % t, [-6.0, -4.0, -2.0, -2.0][t - 1], 1.0, false)
	if t == 4:
		tocar_ui(no, "comemoracao", -12.0)
	abaixar_musica(no, 0.6 + 0.3 * t)


## Cascata de moedas (coletar): `n` moedas em ~0,6 s, subindo de tom.
static func cascata(no: Node, n: int) -> void:
	if no == null or not no.is_inside_tree():
		return
	var k := clampi(n, 1, 12)
	for i in k:
		var atraso := 0.6 * i / maxf(k - 1, 1)
		var tom := 1.0 + 0.5 * i / maxf(k - 1, 1)
		if atraso <= 0.0:
			tocar_ui(no, "moeda", -8.0, tom)
		else:
			no.get_tree().create_timer(atraso).timeout.connect(tocar_ui.bind(no, "moeda", -8.0, tom))
	abaixar_musica(no, 1.0)


static var _musica_tw: Tween

## A música cede −6 dB por `segundos` e volta (fanfarra, coleta grande).
static func abaixar_musica(no: Node, segundos: float) -> void:
	var i := AudioServer.get_bus_index("Musica")
	if i < 0 or no == null or not no.is_inside_tree():
		return
	if _musica_tw != null and _musica_tw.is_valid():
		_musica_tw.kill()
	var f := func(db: float): AudioServer.set_bus_volume_db(i, db)
	_musica_tw = no.get_tree().create_tween()
	_musica_tw.tween_method(f, AudioServer.get_bus_volume_db(i), -6.0, 0.08)
	_musica_tw.tween_interval(segundos)
	_musica_tw.tween_method(f, -6.0, 0.0, 0.6)


static var _impacto_ms := -1000


## Batida na arena: impacto metálico grave nas fortes, raspagem de lataria nas
## leves; volume pelo dano. No máximo uma a cada IMPACTO_INTERVALO_MS (vários
## carros batendo no mesmo quadro viram um som só).
const IMPACTO_INTERVALO_MS := 120
static func impacto(no: Node, dano: float) -> void:
	var agora := Time.get_ticks_msec()
	if agora - _impacto_ms < IMPACTO_INTERVALO_MS:
		return
	_impacto_ms = agora
	var forte := dano > 0.08
	tocar_ui(no, "impacto" if forte else "raspagem",
			lerpf(-12.0, 0.0, clampf(dano / 0.3, 0.0, 1.0)) if forte else -16.0, randf_range(0.9, 1.1))


static var _estrondo: AudioStreamWAV


## Estrondo da explosão (pacote de dano): a gravação (explosao.ogg) ou, sem
## ela, ruído filtrado com uma varredura grave, caindo em 1 s. Toca num
## tocador próprio, como tocar_ui.
static func estrondo(no: Node, db := -6.0) -> void:
	if no == null or not no.is_inside_tree():
		return
	if ResourceLoader.exists(PASTA + "explosao.ogg"):
		tocar_ui(no, "explosao", db)
		return
	if _estrondo == null:
		var n := TAXA
		var dados := PackedByteArray()
		dados.resize(n * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 71023
		var filtrado := 0.0
		for i in n:
			var t := float(i) / TAXA
			filtrado = lerpf(filtrado, rng.randf_range(-1, 1), .10)
			var x := (filtrado * .8 + sin(TAU * (62 * t - 12 * t * t)) * .4) * exp(-5 * t) * minf(1, t * 500)
			dados.encode_s16(i * 2, int(clampf(x, -1, 1) * 28000))
		_estrondo = _wav(dados, false, n)
	var p := AudioStreamPlayer.new()
	p.stream = _estrondo
	p.volume_db = db
	p.finished.connect(p.queue_free)
	no.get_tree().root.add_child(p)
	p.play()


## Tom de `freq` Hz por `dur` s; dente de serra suave (motor) ou seno.
static func _onda(freq: float, dur: float, amp: float, serra := false, laco := false) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var t := float(i) / TAXA
		var fase := fmod(t * freq, 1.0)
		var x := (2.0 * fase - 1.0) * 0.6 + sin(TAU * t * freq * 0.5) * 0.4 if serra else sin(TAU * t * freq)
		var env := 1.0 if laco else minf(1.0, minf(t / 0.01, (dur - t) / 0.05))
		dados.encode_s16(i * 2, int(clampf(x * amp * env, -1.0, 1.0) * 32767.0))
	return _wav(dados, laco, n)


## Laço de ruído (`dur` s, amplitude `amp`). `brilho` 0..1: 0 abafado, 1
## chiado. `trem` > 0: pulsa nessa frequência (Hz, a zebra). `ondas`: o volume
## sobe e desce devagar (a torcida). O fim emenda no começo (sem estalo).
static func _ruido(dur: float, amp: float, brilho: float, trem := 0.0, ondas := false) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := 0.0
	var k := lerpf(0.04, 0.9, brilho)
	for i in n:
		var t := float(i) / TAXA
		y = lerpf(y, rng.randf_range(-1.0, 1.0), k)
		var x := y
		if trem > 0.0:
			x *= 0.55 + 0.45 * signf(sin(TAU * t * trem))
		if ondas:
			x *= 0.7 + 0.3 * sin(TAU * t / dur) * sin(TAU * t * 3.0 / dur)
		var borda := minf(1.0, minf(t / 0.02, (dur - t) / 0.02))
		dados.encode_s16(i * 2, int(clampf(x * amp * lerpf(0.6, 1.0, borda), -1.0, 1.0) * 32767.0))
	return _wav(dados, true, n)


## Aviso da última volta: dois bipes subindo.
static func _dois_bipes() -> AudioStreamWAV:
	var a := _onda(880.0, 0.14, 0.32)
	var b := _onda(1175.0, 0.22, 0.32)
	var vao := PackedByteArray()
	vao.resize(int(TAXA * 0.06) * 2)
	var dados := a.data + vao + b.data
	return _wav(dados, false, dados.size() / 2)


static func _varredura(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		fase += lerpf(f0, f1, t / dur) / TAXA
		var env := minf(1.0, minf(t / 0.01, (dur - t) / 0.08))
		dados.encode_s16(i * 2, int(sin(TAU * fase) * 0.3 * env * 32767.0))
	return _wav(dados, false, n)


static func _wav(dados: PackedByteArray, laco: bool, n: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	if laco:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w
