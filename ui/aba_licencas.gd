extends Aba

## Resultado do último teste: {"teste", "tempo", "grau", "tempos", "concedida", "licenca"} ou erro.
var _resultado := {}

const CORES_GRAU := {
	"ouro": Color(0.98, 0.8, 0.2), "prata": Color(0.8, 0.83, 0.88), "bronze": Color(0.85, 0.55, 0.3),
}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Licenças")


func construir() -> void:
	cabecalho("Licenças", "Testes de tempo que liberam provas maiores.")
	var c := carro_ativo()
	if c == null:
		proximo_passo("Os testes são feitos com o carro em uso.", "Ir para a Garagem", GARAGEM)
		return
	if jogador.licencas.is_empty():
		dica("Cada teste é uma volta sozinho na pista com o seu carro em uso. Bata o tempo de "
				+ "bronze, prata ou ouro. Com bronze ou melhor em todos os testes, a licença é sua. "
				+ "Carro mais rápido (peças, pneus) faz tempo melhor.")
	rotulo("Carro em uso: " + ficha(c), FONTE_PEQUENA, COR_SECUNDARIA)
	_mostrar_resultado()
	for lic in dados.lista("licencas"):
		_cartao_licenca(c, lic)


func _mostrar_resultado() -> void:
	if _resultado.is_empty():
		return
	if _resultado.has("erro"):
		rotulo(_resultado["erro"], 0, COR_RUIM, cartao(COR_RUIM))
		_resultado = {}
		return
	var grau: String = _resultado["grau"]
	var v := cartao(CORES_GRAU.get(grau, COR_RUIM))
	rotulo("TESTE %s" % String(_resultado["teste"]).to_upper(), FONTE_PEQUENA, COR_SECUNDARIA, v)
	rotulo("%.2f s · %s" % [_resultado["tempo"], grau.to_upper() if grau != "" else "REPROVADO"], 36,
			CORES_GRAU.get(grau, COR_RUIM), v)
	var tempos: Dictionary = _resultado["tempos"]
	var proximo := ""
	for g in ["bronze", "prata", "ouro"]:
		if _resultado["tempo"] > float(tempos[g]):
			proximo = g
			break
	if proximo != "":
		rotulo("Faltaram %.2f s para o %s." % [_resultado["tempo"] - float(tempos[proximo]), proximo],
				FONTE_PEQUENA + 2, Color.WHITE, v)
	if _resultado["concedida"]:
		rotulo("Licença %s conquistada! Novas provas liberadas em Eventos." % _resultado["licenca"], 0, COR_BOM, v)
		botao("Ver eventos", func(): ir_para.emit(EVENTOS), true, true, v)
	_resultado = {}


func _cartao_licenca(c: Carro, lic: Dictionary) -> void:
	var tem: bool = lic["id"] in jogador.licencas
	var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
	var feitos: int = lic["testes"].filter(func(t): return jogador.graus_licenca.has(t["id"])).size()
	var provas: int = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"]).size()
	var v := cartao(COR_BOM if tem else (COR_NEUTRA if bloqueada else COR_INFO))
	rotulo(lic["nome"], 34, Color.WHITE, v)
	var estado := ["CONQUISTADA", COR_BOM] if tem else (["exige a licença %s" % lic["requisito"], COR_RUIM] if bloqueada
			else ["%d de %d testes" % [feitos, lic["testes"].size()], COR_INFO])
	selos([estado, ["libera %d prova%s" % [provas, "" if provas == 1 else "s"], COR_NEUTRA.lightened(0.3)]], v)
	for t in lic["testes"]:
		separador(v)
		var topo := fileira(v)
		var ic := icone_pista(t["pista"])
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		topo.add_child(ic)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topo.add_child(info)
		var grau: String = jogador.graus_licenca.get(t["id"], "")
		rotulo("Teste %s · %s" % [String(t["id"]).to_upper(), nome_pista(t["pista"])], 0, Color.WHITE, info)
		var metas := []
		for g in ["ouro", "prata", "bronze"]:
			metas.append(["%s %.1f s" % [g, t["tempos"][g]], CORES_GRAU[g]])
		selos(metas, info)
		var regras := []
		if t.get("restricoes", {}).has("potencia_max"):
			regras.append("até %d cv" % t["restricoes"]["potencia_max"])
		if t.get("condicao", "seco") == "chuva":
			regras.append("chuva")
		var motivos := Elegibilidade.motivos(c, t.get("restricoes", {}), jogador.licencas)
		var h := fileira(v)
		var status := "Seu melhor: %s" % (grau.to_upper() if grau != "" else "—")
		if not regras.is_empty():
			status += " · regras: " + ", ".join(regras)
		if not motivos.is_empty():
			status += "\n✗ " + "; ".join(motivos)
		var l := rotulo(status, FONTE_PEQUENA, CORES_GRAU.get(grau, COR_RUIM if not motivos.is_empty() else COR_SECUNDARIA), h)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao("Fazer" if grau == "" else "Tentar de novo", _fazer.bind(lic, t),
				not bloqueada and motivos.is_empty(), grau == "", h)


func _fazer(lic: Dictionary, t: Dictionary) -> void:
	var r := Licencas.new(dados, jogador).fazer_teste(lic["id"], t["id"], jogador.carro_ativo, randi())
	if r.has("erro"):
		_resultado = {"erro": r["erro"]}
		return
	set_deferred("scroll_vertical", 0)  # o resultado aparece no topo
	_resultado = {"teste": t["id"], "tempo": r["tempo"], "grau": r["grau"], "tempos": t["tempos"],
			"concedida": r["licenca_concedida"], "licenca": lic["nome"]}
