class_name Preferencias
extends RefCounted
## Preferências do aparelho (não vão no save da carreira): volume, reduzir
## animações e modo de playtest. Ficam em user://preferencias.cfg.

const CAMINHO := "user://preferencias.cfg"

## 0..1
static var volume := 0.7
static var reduzir_animacoes := false
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
		modo_teste = String(cfg.get_value("teste", "modo", modo_teste))
		if not modo_teste in ["", "clareza", "ritmo"]:
			modo_teste = ""
	aplicar()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("som", "volume", volume)
	cfg.set_value("tela", "reduzir_animacoes", reduzir_animacoes)
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
