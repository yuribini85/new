class_name Sons
extends Node
## Sons provisórios gerados em código (sem arquivo de áudio): motor do carro
## do jogador, bipes da largada, chegada e ultrapassagem. Em AudioStreamWAV
## porque a exportação web sem threads não toca AudioStreamGenerator.
##
## Motor e pneu gravados (arte/sons, CC0 da Kenney); o tom do motor segue o
## giro (cai na troca de marcha). Sem os arquivos, voltam os gerados: motor
## em duas camadas e chiado. Zebra, torcida e bipes são sempre gerados.
## Sons de interface curtos (moeda, toque, batida): Sons.tocar_ui().

const TAXA := 22050

var _motor: AudioStreamPlayer
var _motor_alto: AudioStreamPlayer
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
var _tom_alvo := -1.0
const PNEU_DB := -8.0
var _gravado := false


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
	var motor := _arquivo("motor", true)
	_gravado = motor != null
	_motor = _laco(motor if _gravado else _onda(90.0, 1.0, 0.18, true, true), MOTOR_DB if _gravado else -14.0)
	_motor_alto = _laco(_onda(180.0, 1.0, 0.12, true, true), MUDO_DB)
	var pneu := _arquivo("pneu", true)
	_pneu = _laco(pneu if pneu != null else _ruido(1.0, 0.22, 0.55), MUDO_DB)
	_zebra = _laco(_ruido(1.0, 0.3, 0.15, 28.0), MUDO_DB)
	_torcida = _laco(_ruido(2.0, 0.2, 0.9, 0.0, true), MUDO_DB)
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
		for p in [_motor, _motor_alto, _pneu, _zebra]:
			if p.playing:
				p.stop()
		_alvos[_pneu] = MUDO_DB
		_alvos[_zebra] = MUDO_DB
		_giro = -1.0
		_tom_alvo = -1.0
		return
	for p in ([_motor] if _gravado else [_motor, _motor_alto]):
		if not p.playing:
			p.play()
	if _giro < 0.0:
		_motor.pitch_scale = clampf(0.6 + velocidade / 40.0, 0.5, 3.0)


## Giro do motor (0..1 da escala): o tom das duas camadas e o volume do agudo.
func motor_giro(fracao: float) -> void:
	_giro = clampf(fracao, 0.0, 1.0)
	if _gravado:
		# Uma camada só: a gravação já tem corpo; o tom faz o giro. Tom base
		# alto (abaixo de ~1 a gravação soa como trator); a troca de marcha
		# desliza o tom em vez de saltar (_process).
		_tom_alvo = lerpf(MOTOR_TOM_MIN, MOTOR_TOM_MAX, _giro)
		_alvos[_motor] = MOTOR_DB + lerpf(-3.0, 0.0, _giro)
		return
	_motor.pitch_scale = lerpf(0.55, 1.75, _giro)
	_motor_alto.pitch_scale = lerpf(0.6, 1.9, _giro)
	_alvos[_motor_alto] = lerpf(-34.0, -15.0, _giro * _giro)


## Pneu cantando (freada forte ou arrancada) e rodas na zebra.
func pneu(cantando: bool, zebra: bool) -> void:
	_ligar(_pneu, (PNEU_DB if _gravado else -17.0) if cantando else MUDO_DB)
	_ligar(_zebra, -20.0 if zebra else MUDO_DB)


## Torcida: 0..1 (sobe na reta final com disputa).
func torcida(f: float) -> void:
	_ligar(_torcida, lerpf(MUDO_DB, -16.0, clampf(f, 0.0, 1.0)) if f > 0.01 else MUDO_DB)


func _ligar(p: AudioStreamPlayer, db: float) -> void:
	_alvos[p] = db
	if db > MUDO_DB and not p.playing:
		p.volume_db = MUDO_DB
		p.play()


## Volumes seguem os alvos (sem cortes secos); laço mudo para de tocar.
func _process(delta: float) -> void:
	if _gravado and _tom_alvo > 0.0:
		_motor.pitch_scale = lerpf(_motor.pitch_scale, _tom_alvo, 1.0 - exp(-delta * MOTOR_TOM_RAPIDEZ))
	for p in _alvos:
		var alvo: float = _alvos[p] + (linear_to_db(maxf(_volume, 0.001)) if p == _motor or p == _motor_alto else 0.0)
		p.volume_db = move_toward(p.volume_db, alvo, delta * 90.0)
		if p.playing and p != _motor and p != _motor_alto and p.volume_db <= MUDO_DB + 0.5 and _alvos[p] <= MUDO_DB:
			p.stop()


## Volume do motor, 0..1 (entrada e saída suaves da abertura).
func volume_motor(f: float) -> void:
	_volume = f
	_motor.volume_db = float(_alvos[_motor]) + linear_to_db(maxf(f, 0.001))


func largada(final := false) -> void:
	_tocar(_bipe_longo if final else _bipe_curto)


func ultrapassagem(ganhou: bool) -> void:
	_tocar(_subida if ganhou else _descida)


func chegada() -> void:
	_tocar(_chegada)


func ultima_volta() -> void:
	_tocar(_aviso)


func _tocar(s: AudioStream) -> void:
	_efeito.stream = s
	_efeito.play()


static var _ambientes := {}  # nome -> AudioStreamWAV


## Fundo acústico das cenas (historia.json → cenarios.<id>.som), gerado em
## laço: "oficina" = ventilação abafada, zumbido elétrico baixo, o tique de um
## relógio e, de vez em quando, metal ao longe. null se o nome não existe.
static func ambiente(nome: String) -> AudioStream:
	if nome != "oficina":
		return null
	if not _ambientes.has(nome):
		_ambientes[nome] = _oficina()
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


## Som curto de arte/sons (moeda, toque, batida) num tocador próprio que some
## ao acabar. Sem o arquivo, não toca nada.
static func tocar_ui(no: Node, nome: String, db := 0.0, tom := 1.0) -> void:
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
	p.pitch_scale = tom
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
