extends Aba

var _aviso := ""


func _init(d: Node, j: Node) -> void:
	super(d, j, "Licenças")


func construir() -> void:
	titulo("Licenças")
	var c := carro_ativo()
	texto("Carro: " + (ficha(c) if c != null else "nenhum — escolha na Garagem"))
	if _aviso != "":
		texto(_aviso, Color(1, 0.85, 0.4))
		_aviso = ""
	for lic in dados.lista("licencas"):
		separador()
		var tem: bool = lic["id"] in jogador.licencas
		var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
		titulo(lic["nome"] + (" ✓" if tem else (" (exige %s)" % lic["requisito"] if bloqueada else "")))
		for t in lic["testes"]:
			var grau: String = jogador.graus_licenca.get(t["id"], "—")
			var motivos := [] if c == null else Elegibilidade.motivos(c, t.get("restricoes", {}), jogador.licencas)
			var desc := "%s · ouro %.1f s · prata %.1f s · bronze %.1f s · melhor: %s" % [
				t["id"], t["tempos"]["ouro"], t["tempos"]["prata"], t["tempos"]["bronze"], grau]
			if not motivos.is_empty():
				desc += "\n  " + ", ".join(motivos)
			linha(desc, [
				["Fazer", _fazer.bind(lic, t), c != null and not bloqueada and motivos.is_empty()],
			])


func _fazer(lic: Dictionary, t: Dictionary) -> void:
	var r := Licencas.new(dados, jogador).fazer_teste(lic["id"], t["id"], jogador.carro_ativo, randi())
	if r.has("erro"):
		_aviso = r["erro"]
		return
	_aviso = "%s: %.2f s — %s" % [t["id"], r["tempo"], r["grau"] if r["grau"] != "" else "reprovado"]
	if r["licenca_concedida"]:
		_aviso += " · licença %s conquistada!" % lic["nome"]
