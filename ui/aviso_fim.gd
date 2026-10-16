class_name AvisoFim
extends RefCounted
## Aviso de fim de corrida com o jogo em segundo plano (decisão 96). Na versão
## web: a Notification API do navegador, agendada para o fim da corrida em
## andamento e mostrada só com a aba escondida. No celular, o Godot não tem
## notificação local sem plugin (pendência no plano). Sem suporte, nada acontece.

static var _agendado := ""  # chave da última agenda (evita refazer a cada segundo)


static func disponivel() -> bool:
	return OS.has_feature("web")


## Pede a permissão uma vez (só funciona logo depois de um toque do jogador).
static func pedir_permissao() -> void:
	if disponivel():
		JavaScriptBridge.eval("if ('Notification' in window && Notification.permission === 'default')"
				+ " { Notification.requestPermission(); }", true)


## Agenda o aviso para daqui a `segundos` (reais); refaz só se mudou.
static func agendar(segundos: float, titulo: String, texto: String) -> void:
	if not disponivel():
		return
	var ms := maxi(int(segundos * 1000.0), 0)
	var chave := "%s|%s|%d" % [titulo, texto, ms / 5000]  # 5 s de folga antes de refazer
	if chave == _agendado:
		return
	_agendado = chave
	JavaScriptBridge.eval(js_agendar(ms, titulo, texto), true)


## O JavaScript que agenda o aviso (separado para ser testado no navegador).
static func js_agendar(ms: int, titulo: String, texto: String) -> String:
	return ("clearTimeout(window._cwAviso); window._cwAviso = setTimeout(function () {"
			+ " if (document.hidden && 'Notification' in window && Notification.permission === 'granted')"
			+ " { new Notification(%s, {body: %s, icon: 'index.icon.png'}); } }, %d);") \
			% [JSON.stringify(titulo), JSON.stringify(texto), ms]


static func cancelar() -> void:
	if not disponivel() or _agendado == "":
		return
	_agendado = ""
	JavaScriptBridge.eval("clearTimeout(window._cwAviso);", true)
