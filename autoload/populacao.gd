extends Node
## Módulo 5 — População. docs/mecanicas_para_godot.md #3.
## Chegada de órfãos, ciclo criança→adulto, sorteio de nome/aptidão/cicatriz, alocação.

signal orfao_chegou(id: String)
signal orfao_virou_adulto(id: String)
signal orfao_alocado(id: String, edificio_id: String)
signal orfao_desalocado(id: String)

var orfaos: Dictionary = {}  # id:String -> Orfao

var _segundos_desde_ultima_chegada: int = 0
var _proximo_numero: int = 1

# mecanicas_para_godot.md #3: "1 + 1 por nível"; 0 se o edifício ainda é ruína.
const CAPACIDADE_BASE_MORADIA := 1


func _ready() -> void:
	Sim.tick.connect(_on_tick)


func _on_tick() -> void:
	_processar_chegada()
	_processar_crescimento()


func capacidade_lar() -> int:
	return _capacidade_moradia("lar_dos_orfaos")


func capacidade_alojamento() -> int:
	return _capacidade_moradia("alojamento")


func _capacidade_moradia(edificio_id: String) -> int:
	if not Vila.edificios.has(edificio_id):
		return 0
	var nivel: int = Vila.edificios[edificio_id].nivel
	if nivel <= 0:
		return 0
	return CAPACIDADE_BASE_MORADIA + nivel


func contar_estado(estado: Orfao.Estado) -> int:
	var n := 0
	for id in orfaos:
		if orfaos[id].estado == estado:
			n += 1
	return n


## mecanicas_para_godot.md #3: 1 a cada 20 min de jogo ativo. O escalonamento com o
## nível do Lar não tem fórmula definida em nenhum documento — fica pendente; a taxa
## usada aqui é a base fixa de ciclo.json.
func _processar_chegada() -> void:
	_segundos_desde_ultima_chegada += 1
	var intervalo: int = Dados.ciclo().get("orfaos", {}).get("chegada_a_cada_seg", 1200)
	if _segundos_desde_ultima_chegada < intervalo:
		return
	if contar_estado(Orfao.Estado.CRIANCA) >= capacidade_lar():
		return  # sem vaga no Lar: o órfão espera, tentamos de novo no próximo tick
	_segundos_desde_ultima_chegada = 0
	_criar_orfao()


func _processar_crescimento() -> void:
	var cfg: Dictionary = Dados.ciclo().get("orfaos", {})
	var infancia: int = cfg.get("infancia_seg", 2700)
	if Sim.ato >= 4:
		infancia = cfg.get("infancia_atos_finais_seg", infancia)

	var agora := int(Time.get_unix_time_from_system())
	for id in orfaos:
		var o: Orfao = orfaos[id]
		if o.estado != Orfao.Estado.CRIANCA:
			continue
		if agora - o.nascido_em < infancia:
			continue
		if contar_estado(Orfao.Estado.ADULTO_OCIOSO) + contar_estado(Orfao.Estado.ALOCADO) >= capacidade_alojamento():
			continue  # sem vaga no Alojamento: fica criança até abrir espaço
		o.estado = Orfao.Estado.ADULTO_OCIOSO
		o.local_id = "alojamento"
		orfao_virou_adulto.emit(id)


func _criar_orfao() -> void:
	var o := Orfao.new()
	o.id = "orfao_%d" % _proximo_numero
	_proximo_numero += 1
	o.genero = "masculino" if randf() < 0.5 else "feminino"
	o.nome = _sortear_nome(o.genero)
	o.aptidao = _sortear_aptidao()
	var cicatriz := _sortear_cicatriz()
	o.cicatriz_id = cicatriz.get("id", "")
	o.cicatriz_visivel = cicatriz.get("visivel", false)
	o.estado = Orfao.Estado.CRIANCA
	o.local_id = "lar_dos_orfaos"
	o.nascido_em = int(Time.get_unix_time_from_system())
	o.velocidade = randf_range(0.9, 1.1)

	orfaos[o.id] = o
	orfao_chegou.emit(o.id)


func _sortear_nome(genero: String) -> String:
	var lista: Array = Dados.orfaos().get("nomes", {}).get(genero, [])
	if lista.is_empty():
		return "?"
	return lista[randi() % lista.size()]


func _sortear_aptidao() -> String:
	var lista: Array = Dados.ciclo().get("aptidoes", [])
	if lista.is_empty():
		return ""
	return lista[randi() % lista.size()]


## design/cicatrizes_orfaos.md: 35% sem cicatriz; a cota por domínio descrita no
## documento usa categorias (econômicas/expedição/sociais/ameaça/alocação) que não
## batem 1:1 com as tags de domínio gravadas em cada cicatriz — sem um mapeamento
## claro entre as duas, o sorteio aqui é uniforme entre as 20, sem ponderação por
## cota nem checagem de incompatível_com/sinergia_com ainda.
func _sortear_cicatriz() -> Dictionary:
	var pct_sem: float = Dados.cicatrizes().get("sem_cicatriz_pct", 0.35)
	if randf() < pct_sem:
		return {}
	var lista: Array = Dados.cicatrizes().get("cicatrizes", [])
	if lista.is_empty():
		return {}
	return lista[randi() % lista.size()]


func alocar(orfao_id: String, edificio_id: String) -> bool:
	if not orfaos.has(orfao_id) or not Vila.edificios.has(edificio_id):
		return false
	var o: Orfao = orfaos[orfao_id]
	if o.estado != Orfao.Estado.ADULTO_OCIOSO:
		return false
	var e: Edificio = Vila.edificios[edificio_id]
	var indice_livre := e.vagas_orfaos.find("")
	if indice_livre == -1:
		indice_livre = e.vagas_orfaos.find(null)
	if indice_livre == -1:
		return false

	e.vagas_orfaos[indice_livre] = orfao_id
	o.estado = Orfao.Estado.ALOCADO
	o.local_id = edificio_id
	orfao_alocado.emit(orfao_id, edificio_id)
	SaveManager.request_save(Sim.get_save_data())
	return true


func desalocar(orfao_id: String) -> bool:
	if not orfaos.has(orfao_id):
		return false
	var o: Orfao = orfaos[orfao_id]
	if o.estado != Orfao.Estado.ALOCADO:
		return false
	if Vila.edificios.has(o.local_id):
		var e: Edificio = Vila.edificios[o.local_id]
		var i := e.vagas_orfaos.find(orfao_id)
		if i != -1:
			e.vagas_orfaos[i] = ""

	o.estado = Orfao.Estado.ADULTO_OCIOSO
	o.local_id = "alojamento"
	orfao_desalocado.emit(orfao_id)
	SaveManager.request_save(Sim.get_save_data())
	return true


## Aptidão do edifício, a partir de orfaos.json#aptidoes_grupo (vazio = sem grupo).
func aptidao_do_edificio(edificio_id: String) -> String:
	var grupos: Dictionary = Dados.orfaos().get("aptidoes_grupo", {})
	for grupo in grupos:
		if edificio_id in grupos[grupo]:
			return grupo
	return ""


func get_save_data() -> Dictionary:
	var lista := []
	for id in orfaos:
		lista.append(orfaos[id].to_dict())
	return {
		"orfaos": lista,
		"segundos_desde_ultima_chegada": _segundos_desde_ultima_chegada,
		"proximo_numero": _proximo_numero,
	}


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		return
	orfaos.clear()
	for d in salvo.get("orfaos", []):
		var o := Orfao.from_dict(d)
		orfaos[o.id] = o
	_segundos_desde_ultima_chegada = salvo.get("segundos_desde_ultima_chegada", 0)
	_proximo_numero = salvo.get("proximo_numero", 1)
