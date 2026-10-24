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
## Modelos acompanhados no Mercado (ids de carros).
var desejos: Array = []
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
## Arena (decisão 49): {lutas, vitorias, perdidos: [modelos perdidos]}.
var arena: Dictionary = {}
## Gestão da equipe (GestaoEquipe): {patrocinios: [contratos], semente_ofertas,
## sede: {id: nível}, treino_<piloto>: {nivel}, xp_<piloto>}.
var equipe: Dictionary = {}
## Identidade da equipe do jogador (IdentidadeEquipe): {nome, logo}; vazio = o padrão.
var identidade: Dictionary = {}
## The Grid (TheGrid): {vencidas: [ids, em ordem], riscar, vistas}.
var grid: Dictionary = {}
## Corrida (dias) do último comentário de contexto da história (cenas reativa).
var ultima_reativa: int = -1000
## Derrotas seguidas em provas ainda não vencidas (a vitória zera; a repetição
## de prova vencida não conta): a Mara aponta o "O que ajuda?" (TRAVADO).
var derrotas_seguidas: int = 0
var historia: Historia
## Equipe do jogador (fase 9): segundo piloto contratado ("" = nenhum) e o carro
## da garagem que ele usa nas provas (-1 = nenhum).
var segundo_piloto: String = ""
var carro_companheiro: int = -1
## Pilotos contratados (decisão 69, EquipeJogador): {corrida: id, arena: [id, id]}.
var pilotos: Dictionary = {}
## Escalação (Escalacao): {corrida: uid, arena: [uid, uid]}.
var escalacao: Dictionary = {}
## Nome do administrador (decisão 73): o jogador, que a Mara chama pelo nome.
var nome_admin: String = ""
## Última loja aberta em Lojas ("" = o mapa): reabre nela, também depois de fechar o jogo.
var ultima_loja: String = ""
## evento_id -> {corridas, melhor_pos, melhor_tempo, ultima_pos, ultimo_tempo}:
## evolução e recorde pessoal por prova.
var historico: Dictionary = {}
## Itens da cabine liberados pelas caixas de pintura ("tipo:id", CaixaPintura).
var caixa: Array = []
## Recorde pessoal de volta por carro e pista ("carro|pista" -> s): a evolução
## do piloto (decisão 130, E6).
var recordes_volta: Dictionary = {}
## Corridas disputadas; cada uma conta um dia.
var dias: int = 0
## Fila de repetições (ver data_model/fila.gd).
var fila: Dictionary = {}
## Relógio das corridas (Aceleracao.agora) da última vez que a fila foi processada.
var ultimo_processamento: float = 0.0
## Corridas aceleradas (Aceleracao, decisão 39): {ganho, inicio, fim, fator}.
var aceleracao: Dictionary = {}
## Combustível (Combustivel): {} = tanque cheio; {qtd, desde}.
var combustivel: Dictionary = {}
## Meta do dia (MetaDia): {dia, tarefas, contagem, coletadas}.
var meta_dia: Dictionary = {}
## Repetições de prova já vencida no período (Carreira.fator_repeticao):
## {periodo, provas: {evento_id: n}}.
var repeticoes: Dictionary = {}
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
	concessionaria.protegidos = func() -> Array: return Escalacao.uids(self)
	licencas = []
	graus_licenca = {}
	montagens = {}
	desejos = []
	fila = {}
	ultimo_processamento = 0.0
	aceleracao = {}
	combustivel = {}
	meta_dia = {}
	repeticoes = {}
	ampliacoes_garagem = 0
	contador_sementes = 0
	vitorias = {}
	caixa = []
	recordes_volta = {}
	campeonatos = {}
	titulos = {}
	treinos = {}
	personagem = ""
	segundo_piloto = ""
	carro_companheiro = -1
	escalacao = {}
	pilotos = {}
	nome_admin = ""
	ultima_loja = ""
	flags = {}
	dialogos_vistos = {}
	ultima_reativa = -1000
	derrotas_seguidas = 0
	arena = {}
	equipe = {}
	identidade = {}
	grid = {}
	historico = {}
	dias = 0
