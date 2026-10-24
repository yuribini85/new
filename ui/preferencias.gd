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
## Na web começa ligado (celulares fracos) até o jogador escolher.
static var efeitos_leves := OS.has_feature("web")
## O jogo já ligou os efeitos leves sozinho (Desempenho): não liga de novo se
## o jogador desligar.
static var leves_automatico := false
## Limita a 30 quadros por segundo (economiza bateria).
static var limitar_fps := false
## Janela do resultado fecha sozinha (30 s); a caixa na própria janela muda.
static var fechar_resultado := true
## Coleção da garagem em lista (true) ou em ícones.
static var garagem_lista := false
## Vista da corrida preferida: "" (a câmera 3D, AUTO) ou "dados" (vista tática,
## sem 3D). A última escolha vale para as próximas corridas.
static var vista_corrida := ""
## Câmera da arena: "briga", "geral" ou "dinamica" (Arena3D.modo).
static var camera_arena := "briga"
## Playtest (docs/playtest_percurso.md): "" desligado, "clareza" (pular corrida
## permitido) ou "ritmo" (sem pular). Ligado, grava RegistroSessao.
static var modo_teste := ""
## Avisos do aparelho com o jogo fechado (Notificacoes, decisão 107).
static var notificacoes := false
## Música de fundo (Chrome Racing Team: chave MÚSICA, separada dos efeitos, que
## seguem `volume`). Só vale onde existe o barramento "Musica" (Sons.barramentos).
static var musica := true
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
		leves_automatico = bool(cfg.get_value("tela", "leves_automatico", leves_automatico))
		limitar_fps = bool(cfg.get_value("tela", "limitar_fps", limitar_fps))
		fechar_resultado = bool(cfg.get_value("tela", "fechar_resultado", fechar_resultado))
		garagem_lista = bool(cfg.get_value("tela", "garagem_lista", garagem_lista))
		vista_corrida = String(cfg.get_value("tela", "vista_corrida", vista_corrida))
		camera_arena = String(cfg.get_value("tela", "camera_arena", camera_arena))
		modo_teste = String(cfg.get_value("teste", "modo", modo_teste))
		notificacoes = bool(cfg.get_value("avisos", "notificacoes", notificacoes))
		musica = bool(cfg.get_value("som", "musica", musica))
		if not modo_teste in ["", "clareza", "ritmo"] or not ferramentas_teste():
			modo_teste = ""
	aplicar()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("som", "volume", volume)
	cfg.set_value("som", "musica", musica)
	cfg.set_value("tela", "reduzir_animacoes", reduzir_animacoes)
	cfg.set_value("tela", "efeitos_leves", efeitos_leves)
	cfg.set_value("tela", "leves_automatico", leves_automatico)
	cfg.set_value("tela", "limitar_fps", limitar_fps)
	cfg.set_value("tela", "fechar_resultado", fechar_resultado)
	cfg.set_value("tela", "garagem_lista", garagem_lista)
	cfg.set_value("tela", "vista_corrida", vista_corrida)
	cfg.set_value("tela", "camera_arena", camera_arena)
	cfg.set_value("teste", "modo", modo_teste)
	cfg.set_value("avisos", "notificacoes", notificacoes)
	cfg.save(CAMINHO)
	aplicar()


## "Ver resultado" na corrida: só no playtest de clareza (fora da interface final).
static func permite_pular() -> bool:
	return modo_teste == "clareza"


static func aplicar() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var efeitos := AudioServer.get_bus_index("Efeitos")
	if efeitos >= 0:
		# Barramentos do Chrome Racing Team: EFEITOS (com o ambiente) e MÚSICA à parte.
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, 0.0)
		for nome in ["Efeitos", "Ambiente"]:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(nome), volume <= 0.001)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Musica"), not musica)
	else:
		AudioServer.set_bus_mute(bus, volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
	Engine.max_fps = 30 if limitar_fps else 0


## Ferramentas de teste (modo de playtest, cenários, liberar as compras, Teste
## completo): só no editor e nos builds com a feature "playtest" (a demo web do
## playtest, export_presets.cfg). No build da loja não existem: liberavam as
## compras pagas para qualquer jogador.
static func ferramentas_teste() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")
