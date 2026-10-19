class_name Notificacoes
extends RefCounted
## Avisos do aparelho com o jogo fechado (decisão 107): quando o jogo sai de
## foco, agenda o que vai acontecer longe dele (contrato de patrocínio que
## acaba, tanque cheio, treino de licença pronto); ao voltar,
## cancela tudo. O jogador desliga nas Configurações (Preferencias.notificacoes).
## `planejar` só lê o estado (testável); o envio vai para o plugin de avisos
## locais do aparelho (singleton LocalNotification); sem ele (editor, Web),
## nada acontece.

const PLUGIN := "LocalNotification"
const MINIMO_S := 60.0  # o que falta menos que isso não vira aviso


## [{id, em_s, titulo, texto}] dos avisos a partir de `agora` (segundos Unix).
static func planejar(dados: Node, jogador: Node, agora: float) -> Array:
	var r := []
	for c in GestaoEquipe.contratos(jogador):
		var p := GestaoEquipe.patrocinador(dados, String(c["id"]))
		_somar(r, "contrato_" + String(c["id"]), float(c["fim"]) - agora, "Patrocínio encerrado",
				"O contrato com %s terminou. Abra o jogo e a equipe assina o próximo." % String(p.get("nome", "o patrocinador")))
	if Combustivel.vale(dados, jogador) and Combustivel.quantidade(dados, jogador, agora) < Combustivel.tanque(dados):
		_somar(r, "combustivel", Combustivel.cheio_em_s(dados, jogador, agora), "Tanque cheio",
				"O combustível está no máximo. Bora correr.")
	var lic := Licencas.new(dados, jogador)
	for l in dados.lista("licencas"):
		var id := String(l["id"])
		if lic.estado(id, agora) == Licencas.TRAINING:
			_somar(r, "licenca_" + id, lic.restante(id, agora), "Licença %s" % id.capitalize(),
					"O treino terminou: a licença é sua.")
	return r


static func _somar(r: Array, id: String, em_s: float, titulo: String, texto: String) -> void:
	if em_s >= MINIMO_S:
		r.append({"id": id, "em_s": em_s, "titulo": titulo, "texto": texto})


## Agenda os avisos no aparelho (jogo saindo de foco).
static func agendar(dados: Node, jogador: Node) -> void:
	cancelar()
	if not Preferencias.notificacoes or not Engine.has_singleton(PLUGIN):
		return
	var plugin := Engine.get_singleton(PLUGIN)
	for n in planejar(dados, jogador, Time.get_unix_time_from_system()):
		plugin.call("show", String(n["texto"]), String(n["titulo"]), int(n["em_s"]), absi(hash(String(n["id"]))) % 100000)


## Cancela os avisos agendados (jogo de volta, ou chave desligada).
static func cancelar() -> void:
	if Engine.has_singleton(PLUGIN):
		Engine.get_singleton(PLUGIN).call("cancel_all")
