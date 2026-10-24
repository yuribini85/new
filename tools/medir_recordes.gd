extends SceneTree
## Fração das corridas em que o piloto bate o recorde pessoal de volta (carro +
## pista), jogando a campanha com o agente (tools/agente.gd), por perfil e
## semente. Calibra a evolução do piloto pelo recorde (decisão 130, E6): para a
## média não mudar, um nível a cada round(xp_por_nivel × fração) recordes.
## O piloto de corrida entra contratado (o primeiro candidato), para a
## evolução aparecer. Com `treinador` (3º argumento): o treinador contratado a campanha toda; o
## relatório traz as provas vencidas e as licenças no tempo, para comparar o
## caminho com e sem ele (meta: ~10% mais curto).
## Uso: godot --headless --path . --script tools/medir_recordes.gd -- [minutos=90] [sementes=3] [treinador]

const PERFIS := ["sugestoes", "explora", "renda"]

var _corridas := 0
var _ag: Object
var _com_treinador := false
var _recordes := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 90.0
	var sementes := int(args[1]) if args.size() > 1 else 3
	var com_treinador := args.size() > 2 and args[2] == "treinador"
	var vencidas := 0
	var d: Node = preload("res://autoload/dados.gd").new()
	d.carregar("res://data/")
	var total_c := 0
	var total_r := 0
	for perfil in PERFIS:
		for s in sementes:
			_corridas = 0
			_recordes = 0
			var ag = preload("res://tools/agente.gd").new(d, perfil, 7 + s)
			ag.j.historia = Historia.new(d, ag.j)
			ag.ouvinte = _acao
			_ag = ag
			_com_treinador = com_treinador
			var r: Dictionary = ag.jogar_campanha(Prologo.campanha(d), minutos * 60.0)
			if r.has("erro"):
				print("ERRO: ", r["erro"])
			print("%-10s semente %d: %d corridas, %d recordes (%.0f%%), %d provas vencidas, licenças %s" % [perfil, 7 + s,
					_corridas, _recordes, 100.0 * _recordes / maxf(_corridas, 1.0), int(r.get("vencidas", 0)), r.get("licencas", [])])
			vencidas += int(r.get("vencidas", 0))
			total_c += _corridas
			total_r += _recordes
			ag.liberar()
	var f := float(total_r) / maxf(total_c, 1.0)
	var por_nivel := int(d.equipe().get("treino", {}).get("xp_por_nivel", 3))
	print("PROVAS VENCIDAS (soma): %d%s" % [vencidas, " com treinador" if com_treinador else ""])
	print("TOTAL %d corridas, %d recordes: fração %.3f -> recordes por nível = round(%d × %.3f) = %d"
			% [total_c, total_r, f, por_nivel, f, maxi(roundi(por_nivel * f), 1)])
	d.free()
	quit()


## O primeiro candidato de corrida do mercado (sem custo: só para medir).
func _piloto_corrida(d: Node) -> String:
	for c in EquipeJogador.candidatos(d):
		if String(c.get("tipo", "corrida")) == "corrida" and not c.get("premium", false):
			return String(c["id"])
	return ""


func _acao(acao: String, ctx: Dictionary) -> void:
	# O jogo novo da campanha zera a equipe: o treinador entra a cada largada.
	if acao == "largada":
		# Piloto de corrida contratado (o agente não contrata): é quem evolui.
		if EquipeJogador.piloto_vaga(_ag.j, "corrida") == "":
			var p: Dictionary = _ag.j.pilotos.duplicate(true)
			p["corrida"] = _piloto_corrida(_ag.d)
			_ag.j.pilotos = p
		if _com_treinador:
			_ag.j.equipe["treinador_ate"] = 1.0e15
	if acao == "corrida":
		_corridas += 1
		if ctx.get("recorde_volta", false):
			_recordes += 1
