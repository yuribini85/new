class_name Edificio
extends RefCounted
## Modelo genérico de edifício — configurado por dado, nunca uma cena por
## construção (CLAUDE.md). docs/mecanicas_para_godot.md #2.

const NIVEL_RUINA := 0

var id: String
var nome: String
var zona: String
var celula: Vector2i
var footprint: Vector2i
var custo_n1: int
var disponivel: bool = true  # false = ruína decorativa, sem dado de custo/produção ainda (ato futuro)

var nivel: int = NIVEL_RUINA
var lider_id: String = ""            # atribuído pelo módulo de População
var vagas_orfaos: Array = []         # tamanho = max(0, nivel - 1)
var item_especial: int = 0           # 0 a 3; pertence ao edifício, não à pessoa
var em_obra: bool = false
var obra_termina_em: int = 0


## Constrói uma ruína (nível 0) a partir de uma entrada do catálogo
## (Dados.catalogo_edificios_ato1()).
static func from_definicao(def: Dictionary) -> Edificio:
	var e := Edificio.new()
	e.id = def.get("id", "")
	e.nome = def.get("nome", "")
	e.zona = def.get("zona", "")
	e.celula = def.get("celula", Vector2i.ZERO)
	e.footprint = def.get("footprint", Vector2i.ONE)
	e.custo_n1 = def.get("custo_n1", 0)
	e.disponivel = def.get("disponivel", true)
	return e


## especificacao_tecnica_v1.md #24 / mecanicas_para_godot.md #2:
## custo = custo_n1 * curva^(n-1), arredondado a múltiplos de 5.
## `curva` vem de Dados.economia()["curva_custo"] — nunca hardcoded aqui.
func custo_para_nivel(n: int, curva: float) -> int:
	if n <= 1:
		return custo_n1
	var bruto := custo_n1 * pow(curva, n - 1)
	return int(round(bruto / 5.0) * 5)


## Líder (sempre presente uma vez construído) + órfãos alocados nas vagas.
func n_trabalhadores() -> int:
	if nivel <= 0:
		return 0
	var n := 1
	for v in vagas_orfaos:
		if v != null and v != "":
			n += 1
	return n


func subir_nivel() -> void:
	nivel += 1
	_recalcular_vagas()


func _recalcular_vagas() -> void:
	vagas_orfaos.resize(maxi(0, nivel - 1))


## Aplica o subconjunto mutável vindo do save (id/nome/zona/celula/footprint/custo_n1
## vêm sempre do catálogo, nunca do save).
func aplicar_estado_salvo(d: Dictionary) -> void:
	nivel = d.get("nivel", nivel)
	lider_id = d.get("lider_id", lider_id)
	item_especial = d.get("item_especial", item_especial)
	em_obra = d.get("em_obra", em_obra)
	obra_termina_em = d.get("obra_termina_em", obra_termina_em)
	_recalcular_vagas()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"nivel": nivel,
		"lider_id": lider_id,
		"item_especial": item_especial,
		"em_obra": em_obra,
		"obra_termina_em": obra_termina_em,
	}
