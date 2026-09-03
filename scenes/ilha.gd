extends Node2D
## Cena principal, provisória. Só HUD de debug + controles manuais de estado —
## ainda não há ilha desenhada, deslocamento nem edificações (bíblia #23.1: isso vem
## depois, em camadas de runtime). Os botões mudam Quint.estado diretamente, sem passar
## pela FilaTarefas (que ainda não tem produtor nenhum ligado a ela) — serve só pra
## exercitar Tempo/Quint/Economia de ponta a ponta antes de existir qualquer arte ou mapa.

@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_dormir: Button = $HudLayer/BotaoDormir
@onready var _botao_comer: Button = $HudLayer/BotaoComer
@onready var _botao_latrina: Button = $HudLayer/BotaoLatrina
@onready var _botao_parar: Button = $HudLayer/BotaoParar


func _ready() -> void:
	_botao_dormir.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.SLEEPING))
	_botao_comer.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.EATING))
	_botao_latrina.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.USING_LATRINE))
	_botao_parar.pressed.connect(_on_parar_pressed)

	Tempo.tick.connect(_atualizar_debug)
	_atualizar_debug()


## "Parar" resolve a necessidade que motivou o estado atual antes de voltar a IDLE —
## sem isso, sair de EATING/USING_LATRINE não credita a recuperação correspondente.
func _on_parar_pressed() -> void:
	if Quint.estado == Quint.Estado.USING_LATRINE:
		Quint.resolver_latrina()
	Quint.mudar_estado(Quint.Estado.IDLE)


func _atualizar_debug() -> void:
	var lxp := Economia.libras_xelins_pence()
	var nomes_estado := {
		Quint.Estado.IDLE: "ocioso", Quint.Estado.SLEEPING: "dormindo",
		Quint.Estado.EATING: "comendo", Quint.Estado.USING_LATRINE: "na latrina",
	}
	_debug_label.text = "dia %d (%s) · %s · fase %s\nQuint: %s\nenergia %.0f%% · fome %.0f%% · latrina %.0f%%\n£%d s.%d d.%d\nquerosene %.1fL · kit %.1f · peixe %.1fkg" % [
		Tempo.dia_geral, Tempo.dia_semana(), _visitante_texto(), Tempo.nome_fase(Tempo.fase_atual),
		nomes_estado.get(Quint.estado, "?"),
		Quint.energia, Quint.fome, Quint.latrina,
		lxp["libras"], lxp["xelins"], lxp["pence"],
		Economia.estoques["querosene_litros"], Economia.estoques["kit_sobrevivencia"], Economia.estoques["peixes_kg"],
	]


func _visitante_texto() -> String:
	var v = Tempo.visitante_de_hoje()
	return v if v != null else "sem visita"
