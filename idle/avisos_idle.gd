class_name IdleAvisos
extends RefCounted
## Avisos do aparelho com o The Fastfather fechado (docs/idle/plano.md):
## quando o app sai de foco, agenda o que vai acontecer longe dele (a renda com
## o app fechado chega ao teto, o contrato grátis fica pronto); ao voltar,
## cancela tudo. A chave AVISOS fica nas Configurações (Preferencias.notificacoes).
## `planejar` só lê o estado (testável); o envio vai para o plugin Notification
## Scheduler (godot-notification-scheduler, instalado pelo CI só no APK do idle);
## sem ele (editor, Web, testes) nada acontece.

const PLUGIN := "NotificationSchedulerPlugin"
const CANAL := "crt"
const MINIMO_S := 60.0  # o que falta menos que isso não vira aviso
const IDS := {"teto": 1, "contrato": 2}

static var _iniciado := false


## [{id, em_s, titulo, texto}] dos avisos a partir de `agora` (segundos Unix).
static func planejar(estado: IdleEstado, agora: float) -> Array:
	var r := []
	_somar(r, "teto", float(estado.cfg.get("offline_max_h", 0.0)) * 3600.0, "Cofre cheio!",
			"Sua equipe parou de faturar. Volte para coletar.")
	if not estado.contrato_gratis_pronto(agora):
		_somar(r, "contrato", estado.contrato_em - agora, "Contrato grátis pronto!",
				"Um piloto novo quer correr pela sua equipe. Toque para contratar.")
	return r


static func _somar(r: Array, id: String, em_s: float, titulo: String, texto: String) -> void:
	if em_s >= MINIMO_S:
		r.append({"id": id, "em_s": em_s, "titulo": titulo, "texto": texto})


static func _plugin() -> Object:
	if not Engine.has_singleton(PLUGIN):
		return null
	var p := Engine.get_singleton(PLUGIN)
	if not _iniciado:
		_iniciado = true
		p.call("initialize")
		p.call("create_notification_channel", {"id": CANAL, "name": "The Fastfather",
				"description": "Cofre cheio e contrato grátis", "importance": 3})
	return p


## Pede ao aparelho a permissão de avisar (Android 13+); devolve se já tem.
static func pedir_permissao() -> bool:
	var p := _plugin()
	if p == null:
		return false
	if bool(p.call("has_post_notifications_permission")):
		return true
	p.call("request_post_notifications_permission")
	return false


## Agenda os avisos no aparelho (app saindo de foco).
static func agendar(estado: IdleEstado) -> void:
	cancelar()
	var p := _plugin()
	if p == null or not Preferencias.notificacoes:
		return
	for n in planejar(estado, Time.get_unix_time_from_system()):
		p.call("schedule", {"notification_id": int(IDS[n["id"]]), "channel_id": CANAL, "title": String(n["titulo"]),
				"content": String(n["texto"]), "small_icon_name": "ic_crt_aviso", "delay": int(n["em_s"])})


## Cancela os avisos agendados (app de volta, ou chave desligada).
static func cancelar() -> void:
	var p := _plugin()
	if p == null:
		return
	for id in IDS.values():
		p.call("cancel", int(id))
