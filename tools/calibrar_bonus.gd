extends SceneTree
## Bônus do patrocínio por condição (decisão 100): mede no playtest automático
## (tools/agente.gd, campanha da história, perfis do playtest) com que frequência
## cada condição de patrocinador se cumpre por corrida e grava em
## equipe.json → patrocinio.bonus_condicao o multiplicador de cada uma:
## frequência do pódio ÷ frequência da condição. Assim o bônus esperado por
## corrida é o mesmo em todas; a condição mais difícil paga mais por vez.
## "licenca" conta só as corridas feitas com a licença já conquistada.
## Condição com menos de AMOSTRA_MIN corridas cumpridas fica de fora (1,0).
##
## Uso: godot --headless --path . --script tools/calibrar_bonus.gd -- [minutos] [gravar]

const PERFIS := ["sugestoes", "explora", "renda"]
const AMOSTRA_MIN := 30

var d: Node
var ag
var corridas := {}  # chave da condição -> n de corridas em que ela podia valer
var cumpridas := {}  # chave -> n cumpridas


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 600.0
	var gravar := args.size() > 1 and args[1] == "gravar"
	d = preload("res://autoload/dados.gd").new()
	d.carregar("res://data/")
	var condicoes := {}
	for p in d.patrocinadores():
		condicoes[GestaoEquipe.chave_condicao(p["condicao"])] = p["condicao"]
	for perfil in PERFIS:
		ag = preload("res://tools/agente.gd").new(d, perfil, 7)
		ag.ouvinte = func(acao: String, ctx: Dictionary):
			if acao != "corrida":
				return
			var ev: Dictionary = d.evento(ctx["evento"])
			for k in condicoes:
				var c: Dictionary = condicoes[k]
				if c["tipo"] == "licenca" and not String(c["valor"]) in ag.j.licencas:
					continue
				corridas[k] = int(corridas.get(k, 0)) + 1
				if GestaoEquipe.cumpre(c, ev, int(ctx["posicao"]), bool(ctx["campeonato"])):
					cumpridas[k] = int(cumpridas.get(k, 0)) + 1
		var r: Dictionary = ag.jogar_campanha(Prologo.campanha(d), minutos * 60.0)
		if r.has("erro"):
			print("ERRO: ", r["erro"])
			quit(1)
			return
		ag.liberar()
	var freq := {}
	for k in condicoes:
		var n := int(corridas.get(k, 0))
		var ok := int(cumpridas.get(k, 0))
		print("%-22s %5d corridas  %5d cumpridas  %5.1f%%" % [k, n, ok, 100.0 * ok / maxf(n, 1)])
		if ok >= AMOSTRA_MIN:
			freq[k] = float(ok) / n
	if not freq.has("podio"):
		print("pódio sem amostra: nada gravado")
		quit(1)
		return
	var mult := {}
	for k in freq:
		mult[k] = snappedf(freq["podio"] / freq[k], 0.01)
	print("multiplicadores: ", mult)
	if gravar:
		_gravar(mult, minutos)
	d.free()
	quit()


## Grava só o bloco bonus_condicao em patrocinio, no texto do arquivo (o resto
## fica como está: regravar o JSON inteiro mudaria a formatação dos números).
static func _gravar(mult: Dictionary, minutos: float) -> void:
	var caminho := "res://data/equipe.json"
	var texto := FileAccess.get_file_as_string(caminho)
	var velho := RegEx.create_from_string(',\\n  "bonus_condicao": \\{[^}]*\\},\\n  "_bonus_condicao": "[^"]*"')
	texto = velho.sub(texto, "")
	var ini := texto.find('"patrocinio": {')
	var fim := texto.find("\n }", ini)
	if ini < 0 or fim < 0:
		print("equipe.json sem patrocinio: nada gravado")
		return
	var linhas := []
	for k in mult:
		linhas.append('   "%s": %s' % [k, str(mult[k])])
	var bloco := ',\n  "bonus_condicao": {\n%s\n  },\n  "_bonus_condicao": "%s"' % [",\n".join(linhas),
			"Gerado por tools/calibrar_bonus.gd (%d min por perfil): frequência do pódio ÷ frequência da condição, medida no playtest automático. Condição ausente vale 1." % minutos]
	texto = texto.insert(fim, bloco)
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(texto)
	print("gravado em ", caminho)
