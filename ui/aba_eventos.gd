extends Aba

signal correr_iniciado

var _repeticoes := 1
var _aviso := ""
## Esconde as provas em que o carro em uso não pode entrar.
var _so_possiveis := true

const GRUPOS := [["", "Sem licença"], ["B", "Licença B"], ["A", "Licença A"]]


func _init(d: Node, j: Node) -> void:
	super(d, j, "Eventos")


func construir() -> void:
	cabecalho("Eventos", "Escolha uma prova e dispute prêmios em dinheiro.")
	var c := carro_ativo()
	if c == null:
		proximo_passo("Você precisa de um carro em uso para correr.", "Ir para a Garagem", GARAGEM)
		return
	_carro_em_uso(c)
	if _aviso != "":
		rotulo(_aviso, 0, COR_RUIM, cartao(COR_RUIM))
		_aviso = ""
	if not jogador.fila.is_empty():
		_fila()
	else:
		_repeticoes_ui()
	if jogador.vitorias.is_empty():
		dica("Cada prova tem regras (potência máxima, tração, licença...). Você larga em último. "
				+ "Os prêmios pagam por posição; vencer uma série pela primeira vez pode dar um carro.")
	var h := fileira()
	rotulo("Mostrando: " + ("só as que posso correr" if _so_possiveis else "todas"), FONTE_PEQUENA, COR_SECUNDARIA, h)
	botao("Ver todas" if _so_possiveis else "Só as minhas", func(): _so_possiveis = not _so_possiveis, true, false, h)
	var algum := false
	for g in GRUPOS:
		var eventos: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca", "") == g[0])
		var linhas := []
		for ev in eventos:
			var motivos := Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas)
			if motivos.is_empty() or not _so_possiveis:
				linhas.append([ev, motivos])
		if linhas.is_empty():
			continue
		algum = true
		linhas.sort_custom(func(a, b):
			if a[1].is_empty() != b[1].is_empty():
				return a[1].is_empty()
			return a[0]["nome"] < b[0]["nome"])
		var tem_licenca: bool = g[0] == "" or g[0] in jogador.licencas
		rotulo(g[1].to_upper() + ("" if tem_licenca else " · faça a licença para liberar"), FONTE_PEQUENA,
				COR_SECUNDARIA if tem_licenca else COR_RUIM)
		for l in linhas:
			_cartao_evento(c, l[0], l[1])
	if not algum:
		var v := cartao(COR_RUIM)
		rotulo("Nenhuma prova aceita este carro agora.", 0, Color.WHITE, v)
		rotulo("Veja todas para saber o que cada uma exige, troque de carro na Garagem ou faça uma licença.",
				FONTE_PEQUENA, COR_SECUNDARIA, v)


func _carro_em_uso(c: Carro) -> void:
	var v := cartao(COR_DESTAQUE)
	var h := fileira(v)
	var ic := icone_carro(c.base)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	rotulo("CARRO EM USO", FONTE_PEQUENA, COR_DESTAQUE, info)
	var a := c.atributos_efetivos("seco")
	rotulo("%s · %d cv · %d kg" % [c.base["nome"], a["potencia"], a["peso"]], 0, Color.WHITE, info)
	var b := botao("Trocar", func(): ir_para.emit(GARAGEM), true, false, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _fila() -> void:
	var f: Dictionary = jogador.fila
	var v := cartao(COR_BOM)
	rotulo("CORRENDO AGORA", FONTE_PEQUENA, COR_BOM, v)
	rotulo("%s · faltam %d corrida%s" % [dados.evento(f["evento_id"])["nome"], f["restantes"],
			"" if f["restantes"] == 1 else "s"], 0, Color.WHITE, v)
	rotulo("Com o app fechado a fila continua; os prêmios entram quando você volta.", FONTE_PEQUENA, COR_SECUNDARIA, v)
	var h := fileira(v)
	botao("Acompanhar", func(): ir_para.emit(CORRIDA), true, true, h)
	botao("Parar a fila", func(): jogador.fila_ctrl.cancelar(), true, false, h)


func _repeticoes_ui() -> void:
	var v := cartao()
	rotulo("REPETIÇÕES", FONTE_PEQUENA, COR_SECUNDARIA, v)
	var h := fileira(v)
	botao("−", func(): _repeticoes = maxi(1, _repeticoes - 1), _repeticoes > 1, false, h).custom_minimum_size.x = 90
	var n := rotulo("%d" % _repeticoes, 36, Color.WHITE, h)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao("+", func(): _repeticoes = mini(999, _repeticoes + 1), true, false, h).custom_minimum_size.x = 90
	botao("×10", func(): _repeticoes = mini(999, _repeticoes * 10), true, false, h).custom_minimum_size.x = 110
	rotulo("Corre a mesma prova várias vezes seguidas, inclusive com o app fechado. Bom para juntar dinheiro.",
			FONTE_PEQUENA, COR_SECUNDARIA, v)


func _cartao_evento(c: Carro, ev: Dictionary, motivos: Array) -> void:
	var pode := motivos.is_empty()
	var v := cartao(COR_BOM if pode else Color.TRANSPARENT)
	var topo := fileira(v)
	var ic := icone_pista(ev["pista"])
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(info)
	rotulo(ev["nome"], 30, Color.WHITE if pode else COR_SECUNDARIA, info)
	rotulo("%s · %d volta%s" % [nome_pista(ev["pista"]), ev["voltas"], "" if ev["voltas"] == 1 else "s"],
			FONTE_PEQUENA, COR_SECUNDARIA, info)
	var regras := [["Chuva", COR_INFO] if ev["condicao"] == "chuva" else ["Seco", COR_DESTAQUE]]
	for r in _regras(ev["restricoes"]):
		regras.append([r, COR_NEUTRA.lightened(0.3)])
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	if vitorias > 0:
		regras.append(["Vencida ×%d" % vitorias, COR_BOM])
	selos(regras, v)
	var premios: Array = ev["premios"]
	var partes := []
	for i in mini(3, premios.size()):
		partes.append("%dº %s" % [i + 1, dinheiro(int(premios[i]))])
	var txt := "Prêmios: " + " · ".join(partes)
	if ev.get("carro_premio") != null and vitorias == 0:
		txt += "\n+ carro na 1ª vitória: %s" % dados.carro(ev["carro_premio"]).get("nome", "")
	rotulo(txt, FONTE_PEQUENA + 2, COR_DESTAQUE.lightened(0.2), v)
	var h := fileira(v)
	if pode:
		rotulo("✓ Seu carro pode correr", FONTE_PEQUENA, COR_BOM, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		rotulo("✗ " + "; ".join(motivos), FONTE_PEQUENA, COR_RUIM, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao("Correr" if _repeticoes == 1 else "Correr ×%d" % _repeticoes, _correr.bind(ev["id"]),
			pode and jogador.fila.is_empty(), true, h)


## Regras da prova em texto curto ("até 150 cv", "tração FF").
func _regras(r: Dictionary) -> Array:
	var t := []
	if r.has("potencia_max"):
		t.append("até %d cv" % r["potencia_max"])
	if r.has("tracao"):
		t.append("tração " + "/".join(r["tracao"]))
	if r.has("categoria"):
		t.append("/".join(r["categoria"].map(func(x): return NOMES_CATEGORIA_CARRO.get(x, x))))
	if r.has("fabricante"):
		t.append("/".join(r["fabricante"].map(func(x): return dados.item("fabricantes", x).get("nome", x))))
	if r.has("ano_min"):
		t.append("de %d em diante" % r["ano_min"])
	if r.has("ano_max"):
		t.append("até %d" % r["ano_max"])
	if r.has("licenca"):
		t.append("licença " + r["licenca"])
	return t


func _correr(evento_id: String) -> void:
	_aviso = jogador.fila_ctrl.iniciar(evento_id, jogador.carro_ativo, _repeticoes, Time.get_unix_time_from_system())
	if _aviso == "":
		correr_iniciado.emit()
