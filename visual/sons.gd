class_name Sons
extends Node
## Sons provisórios gerados em código (sem arquivo de áudio): motor do carro
## do jogador, bipes da largada, chegada e ultrapassagem. Em AudioStreamWAV
## porque a exportação web sem threads não toca AudioStreamGenerator.

const TAXA := 22050

var _motor: AudioStreamPlayer
var _efeito: AudioStreamPlayer
var _bipe_curto: AudioStreamWAV
var _bipe_longo: AudioStreamWAV
var _subida: AudioStreamWAV
var _descida: AudioStreamWAV
var _chegada: AudioStreamWAV


func _init() -> void:
	_motor = AudioStreamPlayer.new()
	_motor.stream = _onda(90.0, 1.0, 0.18, true, true)  # 1 s: o laço fecha sem estalo
	_motor.volume_db = -14.0
	add_child(_motor)
	_efeito = AudioStreamPlayer.new()
	_efeito.max_polyphony = 3
	add_child(_efeito)
	_bipe_curto = _onda(660.0, 0.12, 0.35)
	_bipe_longo = _onda(990.0, 0.4, 0.35)
	_subida = _varredura(520.0, 880.0, 0.18)
	_descida = _varredura(520.0, 300.0, 0.2)
	_chegada = _varredura(660.0, 1320.0, 0.5)


## Motor: liga/desliga e acompanha a velocidade (m/s) do carro do jogador.
func motor(ligado: bool, velocidade := 0.0) -> void:
	if not ligado:
		if _motor.playing:
			_motor.stop()
		return
	if not _motor.playing:
		_motor.play()
	_motor.pitch_scale = clampf(0.6 + velocidade / 40.0, 0.5, 3.0)


func largada(final := false) -> void:
	_tocar(_bipe_longo if final else _bipe_curto)


func ultrapassagem(ganhou: bool) -> void:
	_tocar(_subida if ganhou else _descida)


func chegada() -> void:
	_tocar(_chegada)


func _tocar(s: AudioStream) -> void:
	_efeito.stream = s
	_efeito.play()


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
