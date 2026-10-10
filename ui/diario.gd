class_name Diario
extends RefCounted
## Diário de conversas (documento Chrome & Wreckage, seção 3: "rever no
## Diário"): as cenas da história já vistas, da mais recente para a mais
## antiga, com quem fala e o texto. Só lê o estado; ações de tutorial e
## comentários repetíveis ficam de fora. Variáveis das falas usam os valores de
## agora; a que só existia no momento (posição, peça) vira "…".


static func montar(aba: Aba, v: VBoxContainer, jogador: Node) -> void:
	var h: Historia = jogador.historia
	if h == null:
		aba.rotulo("Sem história neste jogo.", Aba.FONTE_PEQUENA + 2, Aba.COR_SECUNDARIA, v)
		return
	var vars := h.variaveis({})
	var ids: Array = jogador.dialogos_vistos.keys()
	ids.reverse()
	var n := 0
	for id in ids:
		if not h.dados.existe("dialogos", id):
			continue
		var c: Dictionary = h.dados.item("dialogos", id)
		if not c.get("uma_vez", true):
			continue
		var linhas := []
		for f in c.get("falas", []):
			if not f.has("quem"):
				continue
			linhas.append([String(f["quem"]), _texto(String(f["texto"]), vars)])
		if linhas.is_empty():
			continue
		var cart := aba.cartao(Color.TRANSPARENT, v)
		var antes := ""
		for l in linhas:
			var p := h.personagem(l[0])
			var sistema: bool = l[0] == "sistema"
			if not sistema and l[0] != antes:  # o nome só quando muda quem fala
				var nome := aba.rotulo(String(p.get("nome", l[0])), Aba.FONTE_PEQUENA, Aba.COR_DESTAQUE, cart)
				nome.add_theme_constant_override("line_spacing", 0)
			aba.rotulo(l[1], Aba.FONTE_PEQUENA + 2, Aba.COR_SECUNDARIA if sistema else Color.WHITE, cart)
			antes = l[0]
		n += 1
	if n == 0:
		aba.rotulo("Nenhuma conversa ainda.", Aba.FONTE_PEQUENA + 2, Aba.COR_SECUNDARIA, v)


## Texto com as variáveis conhecidas; as que faltam viram "…".
static func _texto(t: String, vars: Dictionary) -> String:
	var r := t.format(vars)
	var re := RegEx.create_from_string("\\{[a-z_]+\\}")
	return re.sub(r, "…", true)
