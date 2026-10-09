class_name Preferencias
extends RefCounted
## Preferências do aparelho (não vão no save da carreira): volume, efeitos,
## quadros por segundo, reduzir animações, vista da corrida e modo de playtest.
## Ficam em user://preferencias.cfg. Editadas na tela de Configurações.

const CAMINHO := "user://preferencias.cfg"

## 0..1
static var volume := 0.7
static var reduzir_animacoes := false
## Efeitos leves: 3D sem suavização de bordas, sombras, neblina e faíscas
## (aparelhos mais fracos). Vale para as cenas 3D criadas depois da troca.
static var efeitos_leves := false
## Limita a 30 quadros por segundo (economiza bateria).
static var limitar_fps := false
## Vista da corrida preferida: "" (a câmera 3D, AUTO) ou "dados" (vista tática,
## sem 3D). A última escolha vale para as próximas corridas.
static var vista_corrida := ""
## Playtest (docs/playtest_percurso.md): "" desligado, "clareza" (pular corrida
## permitido) ou "ritmo" (sem pular). Ligado, grava RegistroSessao.
static var modo_teste := ""
static var _carregado := false


static func carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO) == OK:
		volume = clampf(float(cfg.get_value("som", "volume", volume)), 0.0, 1.0)
		reduzir_animacoes = bool(cfg.get_value("tela", "reduzir_animacoes", reduzir_animacoes))
		efeitos_leves = bool(cfg.get_value("tela", "efeitos_leves", efeitos_leves))
		limitar_fps = bool(cfg.get_value("tela", "limitar_fps", limitar_fps))
		vista_corrida = String(cfg.get_value("tela", "vista_corrida", vista_corrida))
		modo_teste = String(cfg.get_value("teste", "modo", modo_teste))
		if not modo_teste in ["", "clareza", "ritmo"]:
			modo_teste = ""
	aplicar()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("som", "volume", volume)
	cfg.set_value("tela", "reduzir_animacoes", reduzir_animacoes)
	cfg.set_value("tela", "efeitos_leves", efeitos_leves)
	cfg.set_value("tela", "limitar_fps", limitar_fps)
	cfg.set_value("tela", "vista_corrida", vista_corrida)
	cfg.set_value("teste", "modo", modo_teste)
	cfg.save(CAMINHO)
	aplicar()


## "Ver resultado" na corrida: só no playtest de clareza (fora da interface final).
static func permite_pular() -> bool:
	return modo_teste == "clareza"


static func aplicar() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
	Engine.max_fps = 30 if limitar_fps else 0
