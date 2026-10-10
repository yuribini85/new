extends Node
## Estado do jogador: saldo, garagem e a concessionária que opera sobre eles.
## Criado a partir de data/economia.json; sem esses valores o jogo não começa.

var economia: Economia
var garagem: Garagem
var concessionaria: Concessionaria
## Criados só quando todos os dados de carreira existem.
var carreira: Carreira
var fila_ctrl: Fila
## Ids de licença conquistadas.
var licencas: Array = []
## teste_id -> melhor grau ("ouro", "prata", "bronze").
var graus_licenca: Dictionary = {}
## contrato_id -> última montagem enviada {pecas: [ids], ajuste_cambio}.
var montagens: Dictionary = {}
## Modelos acompanhados no Mercado (ids de carros): avisa quando aparecem nos usados.
var desejos: Array = []
## Chaves de ofertas de usados já compradas ("período:carro").
var usados_vendidos: Dictionary = {}
## evento_id -> número de vitórias.
var vitorias: Dictionary = {}
## Temporadas em andamento e títulos (Campeonatos).
var campeonatos: Dictionary = {}
var titulos: Dictionary = {}
## Treino de licença em andamento ou feito: {licença: início (segundos Unix)}.
var treinos: Dictionary = {}
## História (decisão 32): personagem jogável ("" = sem história, saves antigos),
## flags e cenas vistas.
var personagem: String = ""
var flags: Dictionary = {}
var dialogos_vistos: Dictionary = {}
## Corrida (dias) do último comentário de contexto da história (cenas reativa).
var ultima_reativa: int = -1000
var historia: Historia
## Equipe do jogador (fase 9): segundo piloto contratado ("" = nenhum) e o carro
## da garagem que ele usa nas provas (-1 = nenhum).
var segundo_piloto: String = ""
var carro_companheiro: int = -1
## evento_id -> {corridas, melhor_pos, melhor_tempo, ultima_pos, ultimo_tempo}:
## evolução e recorde pessoal por prova.
var historico: Dictionary = {}
## Corridas disputadas; cada uma conta um dia (rotação de usados).
var dias: int = 0
## Fila de repetições (ver data_model/fila.gd).
var fila: Dictionary = {}
## Relógio das corridas (Aceleracao.agora) da última vez que a fila foi processada.
var ultimo_processamento: float = 0.0
## Corridas aceleradas (Aceleracao, decisão 39): {ganho, inicio, fim, fator}.
var aceleracao: Dictionary = {}
## Ampliações da garagem compradas (VagasGaragem, decisão 43).
var ampliacoes_garagem: int = 0
var contador_sementes: int = 0
## Resumo da última corrida aplicada (relatório pós-corrida; não vai para o save).
var ultima_corrida: Dictionary = {}
## Carro escolhido na garagem para oficina, eventos e licenças (estado de tela).
var carro_ativo: int = -1


func _ready() -> void:
	var dados := get_node("/root/Dados")
	var regras: Dictionary = dados.economia()
	if regras.get("saldo_inicial") == null:
		push_warning("Jogador: economia.json pendente, estado não criado")
		return
	novo_jogo(regras, dados.pneu)
	if dados.carreira().get("teto_offline_s") != null:
		carreira = Carreira.new(dados, self)
		fila_ctrl = Fila.new(carreira, self, float(dados.carreira()["teto_offline_s"]))
	historia = Historia.new(dados, self)


func novo_jogo(regras: Dictionary, pneu_por_id: Callable) -> void:
	economia = Economia.new(int(regras["saldo_inicial"]))
	garagem = Garagem.new()
	concessionaria = Concessionaria.new(economia, garagem, regras, pneu_por_id)
	licencas = []
	graus_licenca = {}
	montagens = {}
	desejos = []
	usados_vendidos = {}
	fila = {}
	ultimo_processamento = 0.0
	aceleracao = {}
	ampliacoes_garagem = 0
	contador_sementes = 0
	vitorias = {}
	campeonatos = {}
	titulos = {}
	treinos = {}
	personagem = ""
	segundo_piloto = ""
	carro_companheiro = -1
	flags = {}
	dialogos_vistos = {}
	ultima_reativa = -1000
	historico = {}
	dias = 0
