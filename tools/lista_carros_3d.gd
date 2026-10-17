extends SceneTree
## Lista dos carros para a modelagem 3D (docs/carros_3d.md): grava
## docs/carros_3d/lista.csv (um carro por linha) e docs/carros_3d/lista.md
## (por família, na ordem de produção). Não editar à mão: rodar de novo.
##
## Medidas: as do carro em código (CarroBloco.forma), as mesmas dos sprites e da
## física da corrida (raio da roda de data/carros.json). Descrição e cores: do
## manifesto e da paleta da arte (arte/carros/manifesto.json, cores.json).
## Ordem: licença em que o carro aparece primeiro (rival ou prêmio), depois o
## preço; a família entra na posição do primeiro membro.
##
## Uso: godot --headless --path . --script res://tools/lista_carros_3d.gd

const SAIDA := "res://docs/carros_3d/"
const VARIANTE := "; same basic body design as"
const NOMES_LIC := {"CLUB": "Club", "SPORT": "Sport", "NATIONAL": "National", "INTERNATIONAL": "International",
		"PRO": "Pro", "ELITE": "Elite"}
const TRACAO := {"FF": "dianteira, motor na frente", "FR": "traseira, motor na frente",
		"MR": "traseira, motor central", "RR": "traseira, motor atrás", "4WD": "integral"}
const CARROCERIA := {"compacto": "hatch compacto", "seda": "sedã", "cupe": "cupê", "roadster": "roadster"}
const ASA := {"teto": "defletor no teto", "aerofolio": "aerofólio", "grande": "asa grande de rali",
		"labio": "lábio na tampa traseira", "nenhuma": ""}
const FAROL := {"fino": "faróis finos", "redondo": "faróis redondos", "escamoteavel": "faróis escamoteáveis"}
const GRADE := {"fenda": "grade em fenda", "larga": "grade larga com moldura", "redonda": "grade redonda"}


func _initialize() -> void:
	var dados: Node = load("res://autoload/dados.gd").new()
	dados.carregar("res://data/")
	var manifesto := {}
	for e in _json("res://arte/carros/manifesto.json"):
		manifesto[e["id"]] = e
	var cores: Dictionary = _json("res://arte/carros/cores.json")
	var fabs := {}
	for f in dados.lista("fabricantes"):
		fabs[f["id"]] = f
	var licencas: Array = dados.lista("licencas").map(func(l): return String(l["id"]))
	# Primeira licença em que o carro aparece (rival ou prêmio).
	var aparece := {}
	for ev in dados.lista("eventos"):
		var k := licencas.find(String(ev["restricoes"].get("licenca", "")))
		if k < 0:
			continue
		var ids := []
		for a in ev.get("adversarios", []):
			if a is Dictionary and a.get("carro") is String:
				ids.append(a["carro"])
		var premio: Variant = ev.get("carro_premio")
		if premio is String and premio != "":
			ids.append(premio)
		for id in ids:
			aparece[id] = mini(int(aparece.get(id, 99)), k)
	var carros: Array = dados.lista("carros").duplicate()
	carros.sort_custom(func(a, b):
		var ka := int(aparece.get(a["id"], 99))
		var kb := int(aparece.get(b["id"], 99))
		return ka < kb if ka != kb else int(a["preco"]) < int(b["preco"]))
	# Famílias (as duas primeiras palavras do nome), na ordem do primeiro membro.
	var familias := {}
	var ordem_fam := []
	for c in carros:
		var fam := " ".join(String(c["nome"]).split(" ").slice(0, 2))
		if not familias.has(fam):
			familias[fam] = []
			ordem_fam.append(fam)
		familias[fam].append(c)
	var linhas := []
	var md := PackedStringArray()
	md.append("# Carros do jogo para modelagem 3D")
	md.append("")
	md.append("Gerado por `tools/lista_carros_3d.gd`; não editar à mão. Padrão de exportação e regras em `docs/carros_3d.md`.")
	md.append("")
	md.append("%d carros em %d famílias. Cada família é **um modelo base**; as versões são variações dele (ano, aerofólio, rodas, para-choques). Ordem = ordem de produção: a licença em que o carro aparece primeiro na carreira, depois o preço." % [carros.size(), ordem_fam.size()])
	md.append("")
	var n := 0
	for fam in ordem_fam:
		var membros: Array = familias[fam]
		# Modelo base: o que o manifesto não marca como variante de outro.
		var base: Dictionary = membros[0]
		for c in membros:
			if not String(manifesto.get(c["id"], {}).get("descricao", "")).contains(VARIANTE):
				base = c
				break
		membros.erase(base)
		membros.push_front(base)
		n += 1
		var fab: Dictionary = fabs.get(base["fabricante"], {})
		md.append("## %d. %s" % [n, fam])
		md.append("")
		md.append("**Fabricante:** %s (%s). %s" % [fab.get("nome", base["fabricante"]), fab.get("pais", ""), fab.get("historia", "")])
		md.append("")
		md.append("| Arquivo | Nome | Ano | Carroceria | Tração | cv / kg | C × L × A (m) | Entre-eixos | Raio roda | Detalhes | Cores (fábrica primeiro) |")
		md.append("|---|---|---|---|---|---|---|---|---|---|---|")
		for c in membros:
			var l := _linha(c, base, fam, n, aparece, licencas, manifesto, cores, fab)
			linhas.append(l)
			md.append("| `%s` | %s | %s | %s | %s | %s / %s | %s × %s × %s | %s | %s | %s | %s |" % [l["arquivo"], l["nome"], l["ano"],
					l["carroceria"], l["tracao"], l["potencia_cv"], l["peso_kg"], l["comprimento_m"], l["largura_m"],
					l["altura_m"], l["entre_eixos_m"], l["raio_roda_m"], l["detalhes"], l["cores"]])
		md.append("")
		md.append("Modelo base `%s` (descrição em inglês): %s" % [base["id"], _descricao(manifesto, base["id"])])
		for c in membros.slice(1):
			md.append("")
			md.append("- `%s`, variante do base: %s" % [c["id"], _descricao(manifesto, c["id"])])
		md.append("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var f := FileAccess.open(SAIDA + "lista.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	var csv := FileAccess.open(SAIDA + "lista.csv", FileAccess.WRITE)
	var colunas: Array = linhas[0].keys()
	csv.store_csv_line(PackedStringArray(colunas))
	for l in linhas:
		csv.store_csv_line(PackedStringArray(colunas.map(func(k): return str(l[k]))))
	csv.close()
	print("lista_carros_3d: %d carros, %d famílias" % [linhas.size(), ordem_fam.size()])
	dados.free()
	quit()


func _linha(c: Dictionary, base: Dictionary, fam: String, n: int, aparece: Dictionary, licencas: Array,
		manifesto: Dictionary, cores: Dictionary, fab: Dictionary) -> Dictionary:
	var f := CarroBloco.forma(c)
	var teto: bool = f["teto"]
	var altura: float = float(f["h"]) + float(f["hc"]) + 0.3 if teto else float(f["h"]) + 0.55
	var det := PackedStringArray()
	for d in [ASA.get(f["asa"], ""), FAROL.get(f["farol"], ""), GRADE.get(f["grade"], "")]:
		if d != "":
			det.append(d)
	if f["tomada_capo"]:
		det.append("tomada de ar no capô")
	if f["tomadas_laterais"]:
		det.append("tomadas laterais")
	if f["escape_duplo"]:
		det.append("escape duplo")
	if float(f["cunha"]) > 0.0:
		det.append("linhas retas em cunha (anos 80)")
	if float(f["roda_tras"]) > 1.0:
		det.append("rodas traseiras maiores")
	var nomes_cor := PackedStringArray()
	var paleta: Dictionary = cores.get("paleta", {})
	for k in cores.get("modelos", {}).get(c["id"], []):
		var p: Dictionary = paleta.get(k, {})
		nomes_cor.append("%s %s" % [p.get("nome", k), p.get("cor", "")])
	var k := int(aparece.get(c["id"], 99))
	var feito := CarroBloco.tem_glb(String(c["id"]))
	if feito:
		# Frota 360 (decisão 80): as medidas são as do próprio modelo.
		var cb := CarroBloco.new()
		cb.configurar_modelo(c, Color.WHITE)
		var d := cb.dimensoes()
		f["c"] = d.x
		f["l"] = d.y
		cb.free()
	return {
		"ordem_familia": n,
		"familia": fam,
		"modelo_base": base["id"],
		"arquivo": "%s.glb" % c["id"],
		"feito": "sim" if feito else "",
		"nome": c["nome"],
		"fabricante": fab.get("nome", c["fabricante"]),
		"escola": fab.get("escola", ""),
		"ano": int(c.get("ano", 0)),
		"carroceria": CARROCERIA.get(c["categoria"], c["categoria"]) + ("" if teto else " sem teto"),
		"arquetipo": c.get("arquetipo_ref", ""),
		"tracao": TRACAO.get(c["tracao"], c["tracao"]),
		"potencia_cv": int(c["potencia"]),
		"peso_kg": int(c["peso"]),
		"comprimento_m": snappedf(float(f["c"]), 0.01),
		"largura_m": snappedf(float(f["l"]), 0.01),
		"altura_m": snappedf(altura, 0.01),
		"entre_eixos_m": snappedf(float(f["c"]) * float(f["entre_eixos"]), 0.01),
		"raio_roda_m": snappedf(float(c.get("raio_roda", f["roda"])), 0.001),
		"detalhes": ", ".join(det),
		"cores": "; ".join(nomes_cor),
		"primeira_licenca": NOMES_LIC.get(licencas[k], licencas[k]) if k < licencas.size() else "só loja",
		"preco": int(c["preco"]),
		"descricao_en": _descricao(manifesto, c["id"]),
	}


## Descrição do manifesto sem a marca de variante (a lista já diz o base).
func _descricao(manifesto: Dictionary, id: String) -> String:
	var d := String(manifesto.get(id, {}).get("descricao", ""))
	var k := d.find(VARIANTE)
	return d.substr(0, k) if k >= 0 else d


func _json(caminho: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))
