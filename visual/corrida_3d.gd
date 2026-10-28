class_name Corrida3D
extends SubViewportContainer
## Corrida em 3D com carros de blocos, câmera isométrica seguindo o jogador.
## Lê as distâncias de uma CorridaVisual (o minimapa) e não decide nada: o
## resultado já veio da Simulacao.
##
## A simulação é em uma dimensão (distância percorrida). A posição lateral é
## só visual: cada carro segue o traçado de corrida (Tracado: aberto, tangência
## na zebra, aberto) e quem está a menos de PROXIMIDADE_M de outro abre para
## uma faixa livre em volta dele, de preferência por dentro da próxima curva
## (o bote da ultrapassagem); na ultrapassagem ficam lado a lado. Se dois
## carros se tocam na troca de faixa, o contato aparece como batida: os dois
## se afastam, giram, soltam faíscas e a câmera treme (sem efeito no resultado).

const LARGURA_PISTA_M := 12.0
const FAIXAS_M := [0.0, 2.4, -2.4, 4.8, -4.8]
const PROXIMIDADE_M := 8.0
const VELOCIDADE_LATERAL := 1.5  # 1/s, aproximação da faixa-alvo
## Rapidez (1/s) com que o carro gira até o ângulo do traçado.
const GIRO_SUAVE := 12.0
var _giro_vis := {}  # id -> desvio mostrado do rumo da pista (rad)
## Batida: quanto cada carro é empurrado de lado (m), o giro (rad) e quanto dura.
const BATIDA_EMPURRAO_M := 0.9
const BATIDA_GIRO := 0.32
const BATIDA_S := 0.6
const BATIDA_INTERVALO_S := 6.0  # um carro não bate de novo antes disso
## Deriva nas curvas: ângulo (rad) por g de aceleração lateral, por tração.
const DERIVA := {"FR": 0.13, "MR": 0.12, "4WD": 0.08, "FF": 0.05}
const DERIVA_MAX := 0.1
## Relevo: abaixo dessa velocidade (m/s) o carro não sai do chão na rampa; cor da terra.
const VOO_V_MIN := 8.0
const COR_TERRA := Color(0.55, 0.4, 0.27)  # rad: mais que isso parece que o carro não faz a curva
const TAMANHO_CAMERA := 28.0
## Câmera de perseguição em perspectiva (o jogo se lê como 3D): FOV, altura
## (graus acima do chão) no normal e no modo velocidade, quanto ela abre para o
## lado na velocidade e a distância relativa ao quadro.
const FOV_GRAUS := 50.0
const ELEVACAO_GRAUS := 32.0
const ELEVACAO_VELOCIDADE_GRAUS := 16.0
const LADO_VELOCIDADE := 0.45  # rad
const DISTANCIA_FATOR := 0.85
const DISTANCIA_VELOCIDADE := 1.7  # multiplica a distância no modo velocidade
## Pórtico da largada: altura da faixa, distância da linha de visão em que ele
## atrapalha e a elevação da câmera para passar por cima.
const PORTICO_ALTURA_M := 7.0
const PORTICO_FOLGA_M := 9.0
const PORTICO_ELEVACAO_GRAUS := 62.0
var _sobe_portico := 0.0
const ALTURA_MARCADOR := 2.6

var _fonte: CorridaVisual
var _pista: Pista
var _mundo: Node3D
var _cena: Node3D
var _camera: Camera3D
var _carros := {}  # id -> CarroBloco
var _rotulos := {}  # id -> Label3D
var _lateral := {}  # id -> deslocamento atual (m, + = esquerda)
var _off := {}  # id -> afastamento do traçado de corrida (m), suavizado
## Grid de largada: id -> {s, lateral} da vaga (a mesma posição da simulação,
## um atrás do outro a cada distancia_minima_m, em lados alternados). Parado
## na vaga, o carro fica nela; ao andar, vai para o traçado.
var _vagas := {}
## Vagas do grid: lado de cada coluna (m) e marcação (colchete branco).
const GRID_LADO_M := 2.4
const VAGA_LARGURA_M := 3.0
const VAGA_FUNDO_M := 1.6
const VAGA_TRACO_M := 0.22
const XADREZ_M := 0.8  # lado de cada quadrado da linha de chegada
## Linha de chegada e pórtico: MontadorPista.LINHA_CHEGADA_M e PORTICO_M.
const LINHA_CHEGADA_M := MontadorPista.LINHA_CHEGADA_M
const PORTICO_M := MontadorPista.PORTICO_M
var _tracado: Tracado
## Relevo da pista de terra (Relevo): ondulações e rampas; os carros voam na
## saída das rampas. _voo: id -> {y, vz} enquanto o carro está no ar.
var _relevo: Relevo
## Curvas inclinadas (oval): por metro da volta, a tangente da inclinação (já
## suavizada na entrada e na saída) e o lado de dentro (+1 esquerda, -1 direita).
var _banco := PackedFloat32Array()
var _banco_lado := PackedFloat32Array()
const COR_CONCRETO := Color(0.62, 0.62, 0.64)
var _voo := {}
var _sombras_voo := {}
var _puxar := {}  # id -> {lado, ate}: defesa, só visual
var _tracao := {}  # id -> "FF", "FR", "MR", "4WD"
var _giro_batida := {}  # id -> giro da batida que ainda resta (rad)
var _em_contato := {}  # "a|b" -> true enquanto os dois se tocam
var _ultima_batida := {}  # id -> _tempo da última batida
var _tempo := 0.0
var _tremor := 0.0  # segundos de câmera tremendo (batida do carro seguido)
var _s_anterior := {}
var _tranco := {}  # id -> segundos restantes de tranco
## Largada com personalidade (só visual; a distância vem da simulação): cada
## carro deixa a fila do grid no seu ritmo (pressa), a traseira balança na
## arrancada conforme tração e potência por peso, e a carroceria arfa com a
## aceleração e a freada.
var _pot_peso := {}  # id -> ps/kg
var _jeito := {}  # id -> {pressa, fase}
var _saida := {}  # id -> _tempo em que deixou a vaga
var _arfagem := {}  # id -> inclinação atual (rad, + = frente para cima)
const SAIDA_GRID_S := 6.0  # depois disso todos convergem no mesmo ritmo
const BALANCO_S := 2.4
## Amplitude do balanço da traseira por tração, a 0,15 ps/kg (rad).
const BALANCO := {"FR": 0.05, "MR": 0.045, "RR": 0.05, "4WD": 0.015, "FF": 0.018}
## Saindo do grid: no máximo isto de lado por metro andado (≈ 6°).
const LARGADA_DESVIO := 0.1
const ARFAGEM_POR_MS2 := 0.006  # rad por m/s²
const ARFAGEM_MAX := 0.05
var _alvo_camera := Vector3.ZERO
## Carro que a câmera segue ("jogador" por padrão). Se não existir, o jogador.
var foco := "jogador"
## Faixas da pintura da Oficina por carro (id -> {padrao, faixa, filete}).
var faixas_pintura := {}
## Pista inteira na tela em vez de seguir um carro.
var visao_geral := false
## Estilo de cenário forçado ("chapado"), para comparar sem mudar o tema.
var estilo_forcado := ""
## Cenário de época (CenarioEpoca) no lugar do tema da pista: "" desliga.
var epoca := ""
var _centro_pista := Vector3.ZERO
var _ambiente: Environment

## Ambiente de cada pista (placeholder): cor do chão, do céu e o que fica em
## volta. Pista sem tema usa o padrão.
## Cada pista com hora do dia, cores e cenário próprios, para ser
## reconhecida de relance (placeholder da arte final).
const TEMAS := {
	"anel_do_vale": {"chao": Color(0.26, 0.5, 0.25), "ceu": Color(0.45, 0.66, 0.88), "props": "arvores",
		"luz": Color(1.0, 0.97, 0.9), "energia": 1.0, "sol": Vector3(-1.05, 0.6, 0), "ambiente": Color(0.62, 0.66, 0.7),
		"asfalto": Color(0.29, 0.3, 0.33), "muro": [Color(0.92, 0.92, 0.92), Color(0.8, 0.15, 0.12)], "fundo": "colinas", "neblina": 0.0},
	"parque_das_docas": {"chao": Color(0.42, 0.41, 0.42), "ceu": Color(0.95, 0.6, 0.4), "props": "cidade",
		"luz": Color(1.0, 0.75, 0.5), "energia": 1.0, "sol": Vector3(-0.65, -0.9, 0), "ambiente": Color(0.68, 0.58, 0.62),
		"asfalto": Color(0.22, 0.22, 0.25), "muro": [Color(0.95, 0.78, 0.1), Color(0.12, 0.12, 0.14)], "fundo": "porto", "neblina": 0.0},
	"serra_alta": {"chao": Color(0.36, 0.4, 0.28), "ceu": Color(0.68, 0.73, 0.8), "props": "serra",
		"luz": Color(0.85, 0.9, 1.0), "energia": 0.7, "sol": Vector3(-0.8, 2.2, 0), "ambiente": Color(0.62, 0.66, 0.74),
		"asfalto": Color(0.34, 0.35, 0.37), "muro": [Color(0.9, 0.92, 0.95), Color(0.2, 0.38, 0.75)], "fundo": "montanhas", "neblina": 0.0},
	# Colinas de vinhedo no fim da tarde (circuito misto).
	"circuito_misto": {"chao": Color(0.42, 0.45, 0.25), "ceu": Color(0.95, 0.72, 0.5), "props": "arvores",
		"luz": Color(1.0, 0.85, 0.65), "energia": 1.0, "sol": Vector3(-0.7, 1.4, 0), "ambiente": Color(0.66, 0.62, 0.58),
		"asfalto": Color(0.26, 0.26, 0.28), "muro": [Color(0.94, 0.92, 0.88), Color(0.55, 0.16, 0.18)], "fundo": "colinas", "neblina": 0.0},
	# Campo de provas no planalto seco: meio-dia, chão claro, mesas ao longe.
	"pista_de_testes": {"chao": Color(0.72, 0.62, 0.45), "ceu": Color(0.55, 0.75, 0.95), "props": "deserto",
		"luz": Color(1.0, 0.98, 0.92), "energia": 1.15, "sol": Vector3(-1.35, 0.3, 0), "ambiente": Color(0.7, 0.68, 0.64),
		"asfalto": Color(0.25, 0.25, 0.27), "muro": [Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12)], "fundo": "mesas", "neblina": 0.0},
	# Avenida da cidade à noite: luz fria de neon, concreto, muros magenta.
	"avenida_noturna": {"chao": Color(0.2, 0.2, 0.24), "ceu": Color(0.1, 0.1, 0.22), "props": "cidade",
		"luz": Color(0.7, 0.75, 1.0), "energia": 0.7, "sol": Vector3(-0.9, 0.4, 0), "ambiente": Color(0.45, 0.45, 0.62),
		"asfalto": Color(0.16, 0.16, 0.19), "muro": [Color(0.92, 0.92, 0.96), Color(0.85, 0.18, 0.6)], "fundo": "porto", "neblina": 0.0},
	# Estrada de serra entre araucárias, de manhã cedo: verde frio e luz baixa.
	"estrada_das_araucarias": {"chao": Color(0.24, 0.33, 0.24), "ceu": Color(0.72, 0.8, 0.82), "props": "serra",
		"luz": Color(0.92, 0.96, 1.0), "energia": 0.8, "sol": Vector3(-0.5, -0.8, 0), "ambiente": Color(0.6, 0.68, 0.66),
		"asfalto": Color(0.3, 0.31, 0.33), "muro": [Color(0.95, 0.95, 0.92), Color(0.9, 0.55, 0.1)], "fundo": "montanhas", "neblina": 0.0},
	# Trilha de terra num cânion: terra vermelha, rochas, sol forte da tarde.
	"trilha_do_canion": {"chao": Color(0.6, 0.38, 0.24), "ceu": Color(0.95, 0.72, 0.5), "props": "deserto",
		"luz": Color(1.0, 0.88, 0.7), "energia": 1.1, "sol": Vector3(-0.9, 1.1, 0), "ambiente": Color(0.7, 0.6, 0.55),
		"asfalto": Color(0.5, 0.36, 0.24), "muro": [Color(0.95, 0.93, 0.9), Color(0.85, 0.35, 0.1)], "fundo": "mesas", "neblina": 0.0},
	# Estrada à beira-mar ao pôr do sol: areia, rochas, mar de um lado.
	# Oval inclinado ao entardecer: gramado do miolo, concreto, refletores.
	"oval_inclinado": {"chao": Color(0.3, 0.42, 0.26), "ceu": Color(0.9, 0.62, 0.5), "props": "cidade",
		"luz": Color(1.0, 0.82, 0.62), "energia": 0.9, "sol": Vector3(-0.35, 0.9, 0), "ambiente": Color(0.62, 0.56, 0.58),
		"asfalto": Color(0.2, 0.2, 0.23), "muro": [Color(0.96, 0.96, 0.96), Color(0.12, 0.35, 0.8)], "fundo": "colinas", "neblina": 0.0},
	"mirante_da_costa": {"chao": Color(0.55, 0.5, 0.36), "ceu": Color(0.98, 0.6, 0.45), "props": "deserto",
		"luz": Color(1.0, 0.78, 0.6), "energia": 1.0, "sol": Vector3(-0.45, 1.9, 0), "ambiente": Color(0.7, 0.6, 0.6),
		"asfalto": Color(0.24, 0.24, 0.27), "muro": [Color(0.96, 0.96, 0.96), Color(0.1, 0.45, 0.6)], "fundo": "colinas", "neblina": 0.0},
}
## Montagem pelo kit de arte (MontadorPista, docs/arte_pistas.md): texturas do
## chão, árvores, luz (tinta), direção e força das sombras, bordas da tela.
## O Anel segue a referência de estilo: autódromo na mata ao entardecer.
const KITS := {
	# Estilo chapado (MontadorChapado, docs/arte_pistas.md): cores lisas, volumes
	# facetados, ilhas de luz no escuro; uma paleta por lugar ("cores").
	"anel_do_vale": {"estilo": "chapado", "kit": {"chao_a": "grama_a", "chao_b": "grama_b", "chao_mata": "mata",
			"aberto_m": 70.0, "arvores": ["arvore_1", "arvore_2", "arvore_3", "arvore_4", "arvore_5", "arvore_6"],
			"densidade": 1.0, "postes": true},
		"tinta": Color(0.8, 0.68, 0.58), "sombra_dir": Vector2(1.6, -0.9), "sombra_alfa": 0.5,
		"vinheta": 0.6, "fundo": Color(0.02, 0.025, 0.03),
		"escuro": {"perto_m": 45.0, "longe_m": 170.0, "minimo": 0.1}},
	# Serra: azul frio, pinheiros e rochas, céu encoberto.
	"serra_alta": {"estilo": "chapado", "kit": {"chao_a": "grama_b", "chao_b": "grama_a", "chao_mata": "mata",
			"aberto_m": 45.0, "arvores": ["pinheiro_1", "pinheiro_2", "pinheiro_3"], "raras": ["rocha_1", "rocha_2"],
			"chance_rara": 0.06, "densidade": 0.9, "postes": false},
		"cores": {"grama_a": Color(0.25, 0.33, 0.3), "grama_b": Color(0.21, 0.29, 0.28), "mata": Color(0.08, 0.12, 0.13),
			"escape": Color(0.22, 0.3, 0.29), "areia": Color(0.5, 0.48, 0.44), "pinheiro": Color(0.13, 0.22, 0.22),
			"rocha": Color(0.42, 0.45, 0.48)},
		"tinta": Color(0.8, 0.88, 1.0), "sombra_dir": Vector2(0.6, -0.5), "sombra_alfa": 0.4,
		"vinheta": 0.5, "fundo": Color(0.02, 0.03, 0.04), "cor_vazio": Color(0.02, 0.03, 0.04),
		"escuro": {"perto_m": 40.0, "longe_m": 160.0, "minimo": 0.12}},
	# Docas: noite, luz de sódio laranja, concreto, contêineres, água escura.
	"parque_das_docas": {"estilo": "chapado", "kit": {"chao_a": "concreto", "chao_b": "concreto_b", "escape": "concreto",
			"areia": "brita", "arvores": ["conteiner_1", "conteiner_2", "conteiner_3"], "densidade": 0.7, "postes": true,
			"alinhado": true, "altura_mata_m": 1.5, "agua": {"afastamento_m": 70.0}},
		"cores": {"concreto": Color(0.36, 0.34, 0.33), "concreto_b": Color(0.32, 0.31, 0.3), "brita": Color(0.42, 0.4, 0.37),
			"agua": Color(0.07, 0.13, 0.17), "cais": Color(0.12, 0.12, 0.12), "asfalto": Color(0.17, 0.17, 0.18)},
		"tinta": Color(1.0, 0.76, 0.55), "sombra_dir": Vector2(1.8, -1.0), "sombra_alfa": 0.5,
		"vinheta": 0.6, "fundo": Color(0.015, 0.02, 0.025),
		"escuro": {"perto_m": 50.0, "longe_m": 190.0, "minimo": 0.12}},
	# Misto: colinas de vinhedo ao entardecer; verde-oliva quente, ciprestes e
	# árvores esparsas, luz âmbar baixa.
	"circuito_misto": {"estilo": "chapado", "kit": {"chao_a": "grama_a", "chao_b": "grama_b", "chao_mata": "mata",
			"aberto_m": 55.0, "arvores": ["pinheiro_1", "arvore_2", "pinheiro_2", "arvore_5"], "densidade": 0.6,
			"postes": false},
		"cores": {"grama_a": Color(0.42, 0.44, 0.24), "grama_b": Color(0.37, 0.39, 0.21), "mata": Color(0.15, 0.17, 0.09),
			"escape": Color(0.4, 0.42, 0.24), "areia": Color(0.64, 0.53, 0.37), "pinheiro": Color(0.17, 0.23, 0.13)},
		"tinta": Color(1.0, 0.84, 0.64), "sombra_dir": Vector2(1.9, -0.6), "sombra_alfa": 0.5,
		"vinheta": 0.5, "fundo": Color(0.03, 0.025, 0.02),
		"escuro": {"perto_m": 55.0, "longe_m": 200.0, "minimo": 0.2}},
	# Testes: planalto seco ao meio-dia; claro, ocre, rochas, pouco escuro.
	"pista_de_testes": {"estilo": "chapado", "kit": {"chao_a": "areia", "chao_b": "brita", "escape": "areia",
			"arvores": ["rocha_1", "rocha_2", "rocha_3"], "densidade": 0.18, "postes": false},
		"cores": {"areia": Color(0.7, 0.58, 0.4), "brita": Color(0.64, 0.53, 0.37), "rocha": Color(0.55, 0.47, 0.38),
			"concreto": Color(0.55, 0.53, 0.5), "asfalto": Color(0.24, 0.23, 0.23)},
		"tinta": Color(1.04, 1.0, 0.94), "sombra_dir": Vector2(0.4, -0.3), "sombra_alfa": 0.35,
		"vinheta": 0.3, "fundo": Color(0.3, 0.25, 0.18), "cor_vazio": Color(0.3, 0.25, 0.18),
		"escuro": {"perto_m": 80.0, "longe_m": 300.0, "minimo": 0.55}},
	# Avenida: noite azulada, concreto escuro, caminhões estacionados, postes.
	"avenida_noturna": {"estilo": "chapado", "kit": {"chao_a": "concreto", "chao_b": "concreto_b", "escape": "concreto",
			"areia": "brita", "arvores": ["caminhao_1", "caminhao_2", "caminhao_3", "conteiner_1"], "densidade": 0.6,
			"postes": true, "alinhado": true, "altura_mata_m": 1.5},
		"cores": {"concreto": Color(0.24, 0.24, 0.3), "concreto_b": Color(0.21, 0.21, 0.27), "brita": Color(0.3, 0.29, 0.34),
			"asfalto": Color(0.14, 0.14, 0.17)},
		"tinta": Color(0.72, 0.78, 1.15), "sombra_dir": Vector2(1.2, -1.2), "sombra_alfa": 0.55,
		"vinheta": 0.65, "fundo": Color(0.01, 0.01, 0.03),
		"escuro": {"perto_m": 45.0, "longe_m": 170.0, "minimo": 0.08}},
	# Araucárias: pinheiros densos e rochas, verde frio, sem postes.
	"estrada_das_araucarias": {"estilo": "chapado", "kit": {"chao_a": "grama_a", "chao_b": "grama_b", "chao_mata": "mata",
			"aberto_m": 35.0, "arvores": ["pinheiro_1", "pinheiro_2", "pinheiro_3", "pinheiro_2"], "raras": ["rocha_1", "rocha_3"],
			"chance_rara": 0.08, "densidade": 1.15, "postes": false},
		"cores": {"grama_a": Color(0.22, 0.34, 0.24), "grama_b": Color(0.19, 0.3, 0.22), "mata": Color(0.06, 0.11, 0.08),
			"escape": Color(0.24, 0.33, 0.25), "areia": Color(0.46, 0.42, 0.36), "pinheiro": Color(0.1, 0.21, 0.14),
			"rocha": Color(0.45, 0.46, 0.44)},
		"tinta": Color(0.86, 0.96, 0.95), "sombra_dir": Vector2(-1.4, -0.8), "sombra_alfa": 0.45,
		"vinheta": 0.5, "fundo": Color(0.02, 0.04, 0.03), "cor_vazio": Color(0.02, 0.04, 0.03),
		"escuro": {"perto_m": 40.0, "longe_m": 150.0, "minimo": 0.15}},
	# Cânion: terra vermelha batida na pista, rochas e pouca vegetação.
	"trilha_do_canion": {"estilo": "chapado", "kit": {"chao_a": "areia", "chao_b": "brita", "escape": "areia",
			"arvores": ["rocha_1", "rocha_2", "rocha_3", "rocha_2"], "densidade": 0.55, "postes": false},
		"cores": {"areia": Color(0.62, 0.38, 0.24), "brita": Color(0.55, 0.34, 0.22), "rocha": Color(0.5, 0.3, 0.22),
			"concreto": Color(0.5, 0.42, 0.36), "asfalto": Color(0.48, 0.34, 0.22)},
		"tinta": Color(1.08, 0.92, 0.82), "sombra_dir": Vector2(1.4, -0.6), "sombra_alfa": 0.45,
		"vinheta": 0.35, "fundo": Color(0.22, 0.12, 0.07), "cor_vazio": Color(0.22, 0.12, 0.07),
		"escuro": {"perto_m": 70.0, "longe_m": 260.0, "minimo": 0.45}},
	# Costa: areia e rochas, o mar ao lado, luz rosada de fim de tarde.
	# Oval: miolo de grama aparada, faixa de concreto e refletores alinhados.
	"oval_inclinado": {"estilo": "chapado", "kit": {"chao_a": "grama_a", "chao_b": "grama_b", "escape": "concreto",
			"arvores": ["conteiner_1", "caminhao_1"], "densidade": 0.12, "postes": true, "alinhado": true},
		"cores": {"grama_a": Color(0.3, 0.44, 0.26), "grama_b": Color(0.27, 0.4, 0.23), "concreto": Color(0.5, 0.5, 0.52),
			"asfalto": Color(0.19, 0.19, 0.22), "escape": Color(0.5, 0.5, 0.52)},
		"tinta": Color(1.05, 0.92, 0.86), "sombra_dir": Vector2(0.8, -1.2), "sombra_alfa": 0.45,
		"vinheta": 0.45, "fundo": Color(0.08, 0.06, 0.07), "cor_vazio": Color(0.08, 0.06, 0.07),
		"escuro": {"perto_m": 70.0, "longe_m": 260.0, "minimo": 0.3}},
	"mirante_da_costa": {"estilo": "chapado", "kit": {"chao_a": "areia", "chao_b": "brita", "escape": "areia",
			"arvores": ["rocha_1", "rocha_2", "rocha_3", "arvore_1"], "densidade": 0.35, "postes": false,
			"agua": {"afastamento_m": 55.0}},
		"cores": {"areia": Color(0.74, 0.62, 0.45), "brita": Color(0.66, 0.56, 0.42), "rocha": Color(0.5, 0.42, 0.38),
			"agua": Color(0.08, 0.3, 0.4), "cais": Color(0.4, 0.34, 0.28), "asfalto": Color(0.22, 0.22, 0.25)},
		"tinta": Color(1.06, 0.86, 0.8), "sombra_dir": Vector2(2.0, -0.4), "sombra_alfa": 0.45,
		"vinheta": 0.4, "fundo": Color(0.05, 0.12, 0.16), "cor_vazio": Color(0.05, 0.12, 0.16),
		"escuro": {"perto_m": 70.0, "longe_m": 260.0, "minimo": 0.35}},
}
## Versões curtas usam o cenário da pista-mãe.
const TEMA_DE := {"docas_curta": "parque_das_docas", "anel_curto": "anel_do_vale", "serra_curta": "serra_alta"}
const TEMA_PADRAO := {"chao": Color(0.22, 0.45, 0.25), "ceu": Color(0.4, 0.6, 0.75), "props": "arvores",
	"luz": Color.WHITE, "energia": 1.0, "sol": Vector3(-1.0, 0.5, 0), "ambiente": Color(0.6, 0.62, 0.66),
	"asfalto": Color(0.27, 0.28, 0.31), "muro": [Color(0.82, 0.82, 0.84), Color(0.2, 0.35, 0.75)], "fundo": "", "neblina": 0.0}
var _luz: DirectionalLight3D
var _cores_muro: Array = TEMA_PADRAO["muro"]
var _tamanho_geral := 200.0
var _proj := Rect2()
## Carro que o jogador persegue: na disputa (perto), anel vermelho no chão e
## rótulo "ALVO".
var alvo := ""
## Segundo carro do enquadramento (diretor de câmera): a câmera mira entre o
## seguido e ele e abre o bastante para os dois.
var enquadrar_com := ""
## 0..1: chegada do jogador; a câmera fecha devagar nele.
var chegada := 0.0
## Sem os rótulos sobre os carros (a volta da abertura: só o carro).
var sem_rotulos := false
## id -> nome curto do piloto: o rótulo dos rivais é "posição nome" (como os
## nomes que flutuam sobre os carros nos jogos de corrida de cima).
var nomes: Dictionary = {}
var _destaque_jogador := 0.0  # segundos restantes do anel temporário do jogador
const DESTAQUE_S := 1.6
var _anel_alvo: MeshInstance3D
var _anel_jogador: MeshInstance3D
## Momento de decisão em curso (0..1, dado pela tela): o rastro do seu carro na
## cor de destaque, as lanternas piscando e o efeito de velocidade.
var impulso := 0.0
## Comemoração (comemorar): onda no chão que abre em volta do seu carro.
var _onda: MeshInstance3D
var _t_onda := -1.0
const ONDA_S := 0.9
## Soco da câmera (acionar, comemorar): fecha um pouco e volta (0..1).
var _soco := 0.0
const SOCO_S := 0.5
## Traço do seu carro até o alvo, quando ele está perto (disputa).
var _traco: MeshInstance3D
const DISPUTA_M := 12.0
const TAMANHO_DISPUTA := 21.0


func _enter_tree() -> void:
	Desempenho.entrou_3d(self)


func _exit_tree() -> void:
	Desempenho.saiu_3d(self)


func _init() -> void:
	stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	Desempenho.preparar_viewport(vp)
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.42, 0.24)
	_ambiente = env
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	CarroBloco.reflexo(env)  # o reflexo do verniz na pintura
	amb.environment = env
	_mundo.add_child(amb)
	_luz = DirectionalLight3D.new()
	_luz.rotation = Vector3(-1.0, 0.5, 0)
	_mundo.add_child(_luz)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = TAMANHO_CAMERA
	_camera.far = 12000.0  # pista de 4 km na visão geral: o chão some antes de 6000
	_mundo.add_child(_camera)
	_cena = Node3D.new()
	_mundo.add_child(_cena)
	var efeito := ShaderMaterial.new()
	efeito.shader = preload("res://visual/shaders/velocidade.gdshader")
	material = efeito


## modelos: id -> dados do carro (data/carros.json), para a silhueta de cada um.
## pinturas: id -> cor da carroceria (Cores); sem ela, a cor de identidade do placar.
func mostrar(pista: Pista, fonte: CorridaVisual, modelos: Dictionary, pinturas: Dictionary = {}) -> void:
	limpar()
	_pista = pista
	_fonte = fonte
	_tracado = Tracado.de(pista)
	_relevo = Relevo.de(pista)
	_construir_pista()
	if not _relevo.vazio():
		_cena.add_child(_relevo_malha())
	_preparar_banco()
	if not _banco.is_empty():
		_cena.add_child(_banco_malha())
	for id in fonte.ordem():
		var base: Dictionary = modelos.get(id, {"id": id, "categoria": "seda"})
		# Modelo 3D (decisão 31) quando existe; senão o sprite antigo; senão o carro em código.
		var c: Node3D = CarroDesenho.new()
		if CarroBloco.tem_modelo(String(base.get("id", ""))) \
				or not c.configurar(String(base.get("id", "")), pinturas.get(id, Color(0, 0, 0, 0))):
			c.free()
			c = CarroBloco.new().configurar_modelo(base, pinturas.get(id, fonte.cor_de(id)), faixas_pintura.get(id, {}))
		_cena.add_child(c)
		_carros[id] = c
		var r := Label3D.new()
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.no_depth_test = true
		r.pixel_size = 0.045
		r.font_size = 48
		r.outline_size = 14
		r.modulate = Color(0.95, 0.94, 0.9)
		r.outline_modulate = Color(0, 0, 0, 0.75)
		_cena.add_child(r)
		_rotulos[id] = r
		_criar_efeitos(id, c)
		_lateral[id] = _tracado.lateral(fonte.distancia(id))
		_off[id] = 0.0
		_tracao[id] = String(base.get("tracao", "FF"))
		_pot_peso[id] = float(base.get("potencia", 100.0)) / maxf(float(base.get("peso", 1000.0)), 1.0)
		# Jeito de largar, fixo por carro e prova (só visual): quanto demora a
		# deixar a fila do grid e a fase do balanço da traseira.
		var h := absi(hash("%s|%s" % [id, String(base.get("id", ""))]))
		_jeito[id] = {"pressa": lerpf(0.45, 1.7, float(h % 1000) / 999.0), "fase": float(h % 628) / 100.0}
	_grid()
	atualizar(0.0)
	_camera_imediata()


## Desenha uma vez, sob a capa de carregamento da tela, o que só apareceria
## no meio da corrida (pontos da câmera de cima, marcas de pneu, rastro do
## vácuo, faíscas): o primeiro desenho de cada material compila o shader, e
## isso travava a corrida nos primeiros segundos. Volta tudo ao normal em
## dois quadros.
func aquecer() -> void:
	if _carros.is_empty() or not is_inside_tree():
		return
	var id: String = _carros.keys()[0]
	var c: Node3D = _carros[id]
	if _marcas == null:
		_criar_marcas()
	_marcas.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, c.position + Vector3(0, 0.05, 0)))
	_marcas.multimesh.set_instance_color(0, Color(0, 0, 0, 0.01))
	if not _rastros.has(id):
		_criar_rastro(id, c)
	_rastros[id].emitting = true
	var antes := _cena.get_child_count()
	_faiscas(c.position + Vector3(0, 0.6, 0))
	var faisca: Node = _cena.get_child(_cena.get_child_count() - 1) if _cena.get_child_count() > antes else null
	_mostrar_pontos(true)
	for k in 2:
		await get_tree().process_frame
	if not is_instance_valid(c):
		return
	_mostrar_pontos(false)
	if _rastros.has(id) and is_instance_valid(_rastros[id]):
		_rastros[id].emitting = false
	if _marcas != null:
		_marcas.multimesh.set_instance_color(0, Color(0, 0, 0, 0))
	if is_instance_valid(faisca):
		faisca.queue_free()


func limpar() -> void:
	for c in _cena.get_children():
		c.queue_free()
	_carros = {}
	_rotulos = {}
	_lateral = {}
	_off = {}
	_giro_batida = {}
	_em_contato = {}
	_s_anterior = {}
	_voo = {}
	_sombras_voo = {}
	_puxar = {}
	_tranco = {}
	_pot_peso = {}
	_jeito = {}
	_saida = {}
	_arfagem = {}
	_freio = {}
	_historico = []
	_copias_bloco = []
	_mats_bloco = []
	_fantasma = 0.0
	_fantasma_de = ""
	_fumaca = {}
	_esteira = {}
	_rastro_pts = {}
	_intensidade = {}
	_rear = {}
	_largura_carro = {}
	_luzes = {}
	_giro_vis = {}
	_pontos = {}
	_v_max = {}
	_rastros = {}
	_poeira = {}
	_marcas = null
	_marca_i = 0
	_marca_dist = {}
	_marca_ponto = {}
	_marcando = {}
	_deixas_mi = null
	_deixas_chave = ""
	_seta = null
	_pista = null


## Posiciona os carros no tempo atual da fonte. delta suaviza a troca de faixa.
func atualizar(delta: float) -> void:
	if _pista == null:
		return
	_tremor = maxf(_tremor - delta, 0.0)
	_tempo += delta
	var s := {}
	for id in _carros:
		s[id] = _fonte.distancia(id)
	var ordem := _fonte.ordem()
	# Traçado de corrida de cada carro e, para quem ataca, o lado de dentro da
	# próxima curva.
	var base := {}
	var ataque := {}
	for id in _carros:
		base[id] = _tracado.lateral(float(s[id]))
		ataque[id] = signf(_tracado.curvatura(float(s[id]) + 45.0))
	var alvo := faixas(ordem, s, _off, _pista.comprimento, base, ataque)
	for id in _vagas:
		# Ainda parado na vaga do grid: fica nela (sem deslizar de lado).
		if absf(float(s[id]) - float(_vagas[id]["s"])) < 0.5:
			alvo[id] = float(_vagas[id]["lateral"]) - float(base[id])
			if delta <= 0.0 or float(_off[id]) == 0.0:
				_off[id] = alvo[id]
		elif not _saida.has(id) and delta > 0.0:
			_saida[id] = _tempo
	# Defesa: o rival de trás sai para um lado; com a porta fechada, o jogador vai junto.
	for id in _puxar.keys():
		if _tempo >= float(_puxar[id]["ate"]) or not _carros.has(id):
			_puxar.erase(id)
		else:
			alvo[id] = -float(_puxar[id]["lado"]) * PUXAR_M - float(base[id])
	var animar := delta > 0.0 and not Preferencias.reduzir_animacoes
	var antes := _lateral.duplicate()
	for id in _carros:
		# Logo depois da largada, cada um troca de faixa no seu ritmo.
		var pressa := 1.0
		if _saida.has(id) and _jeito.has(id):
			pressa = lerpf(float(_jeito[id]["pressa"]), 1.0, smoothstep(0.0, SAIDA_GRID_S, _tempo - float(_saida[id])))
		var k := clampf(delta * VELOCIDADE_LATERAL * pressa, 0.0, 1.0) if animar else 1.0
		var novo := lerpf(_off[id], alvo[id], k)
		# Saindo do grid, devagar ainda: o carro só vai de lado na proporção do
		# que anda para a frente (não desliza de lado como um caranguejo).
		if animar and _saida.has(id) and _tempo - float(_saida[id]) < SAIDA_GRID_S:
			var ds := maxf(float(s[id]) - float(_s_anterior.get(id, s[id])), 0.0)
			var passo := ds * LARGADA_DESVIO
			novo = clampf(novo, float(_off[id]) - passo, float(_off[id]) + passo)
		_off[id] = novo
		_lateral[id] = clampf(float(base[id]) + float(_off[id]), -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
	_separar(s, base, delta)
	# Os toques são vistos antes da separação firme (a batida mostra o toque);
	# depois dela, nenhum carro fica dentro do outro na tela.
	var toques: Array = [] if Preferencias.reduzir_animacoes or chegada > 0.0 else contatos(ordem, s, _lateral, _pista.comprimento)
	_separar_firme(s, base)
	var tocando := {}
	# Sem batidas depois da chegada (os carros param em fila, ver CorridaVisual).
	for par in toques:
		var chave := "%s|%s" % par
		tocando[chave] = true
		if _em_contato.has(chave) or _tempo - float(_ultima_batida.get(par[0], -99.0)) < BATIDA_INTERVALO_S \
				or _tempo - float(_ultima_batida.get(par[1], -99.0)) < BATIDA_INTERVALO_S:
			continue
		_bater(par[0], par[1], float(_lateral[par[0]]) - float(_lateral[par[1]]))
		_ultima_batida[par[0]] = _tempo
		_ultima_batida[par[1]] = _tempo
	_em_contato = tocando
	for i in ordem.size():
		var id: String = ordem[i]
		var c: Node3D = _carros[id]
		var dist: float = s[id]
		var rumo := _pista.rumo_em(dist)
		var normal := Vector2.from_angle(rumo + PI / 2.0)
		var p := _pista.posicao_em(dist) + normal * float(_lateral[id])
		c.position = Vector3(p.x, _altura_carro(id, dist, delta) + _altura_banco(dist, float(_lateral[id])), -p.y)
		if _relevo != null and not _relevo.vazio():
			_sombra_voo(id, c, dist)
		# Esterço visual: ângulo entre o avanço e o deslocamento de lado (o
		# traçado e as trocas de faixa), mais a deriva da traseira nas curvas.
		var ds: float = dist - float(_s_anterior.get(id, dist))
		# A direção em que o carro anda de fato: a inclinação da linha (exata,
		# pelo traçado) mais a troca de faixa do quadro, sobre o avanço no lado
		# em que ele está (por dentro da curva anda menos que o centro).
		var lat := float(_lateral[id])
		var k_centro := _tracado.curvatura(dist)
		var inclinacao := _tracado.inclinacao(dist)
		if delta > 0.0 and ds > 0.05:
			inclinacao = clampf((lat - float(antes[id])) / ds, -0.45, 0.45)
		var esterco := atan2(inclinacao, maxf(1.0 - k_centro * lat, 0.2))
		var v: float = float(_v.get(id, 0.0))
		var g_lateral := v * v * k_centro / 9.8
		esterco += clampf(g_lateral * float(DERIVA.get(_tracao.get(id, "FF"), 0.06)), -DERIVA_MAX, DERIVA_MAX)
		# Arrancada: a traseira balança (tração traseira e muita potência por peso
		# mais; tração integral quase nada), amortecendo em BALANCO_S.
		if _saida.has(id) and not Preferencias.reduzir_animacoes:
			var ts := _tempo - float(_saida[id])
			if ts < BALANCO_S:
				var amp := float(BALANCO.get(_tracao.get(id, "FF"), 0.04)) * clampf(float(_pot_peso.get(id, 0.1)) / 0.15, 0.4, 1.8)
				esterco += amp * sin(ts * 9.0 + float(_jeito[id]["fase"])) * exp(-ts * 1.6) * smoothstep(0.0, 0.15, ts)
		var t: float = _tranco.get(id, 0.0)
		if t > 0.0:
			esterco += sin(t * 55.0) * 0.07 * (t / BATIDA_S)
			_tranco[id] = maxf(t - delta, 0.0)
		var gb: float = _giro_batida.get(id, 0.0)
		if gb != 0.0:
			esterco += gb
			_giro_batida[id] = gb * exp(-delta * 4.0) if absf(gb) > 0.005 else 0.0
		# Na zebra (rodas de dentro sobre ela, na curva): trepida um pouco.
		_na_zebra[id] = absf(float(_lateral[id])) > Tracado.ABERTO_M + 0.2 and absf(_tracado.curvatura(dist)) > 0.002
		if _na_zebra[id]:
			esterco += sin(Time.get_ticks_msec() * 0.09 + i) * 0.015
		# Giro suave: o rumo do traçado tem quinas e o esterço oscila quadro a
		# quadro; o carro vira com atraso curto, sem saltos de ângulo.
		# Só o desvio do traçado é suavizado: o rumo da pista entra exato (girar o
		# ângulo inteiro com atraso deixava a frente para fora em toda curva).
		if delta > 0.0 and _giro_vis.has(id) and not Preferencias.reduzir_animacoes:
			_giro_vis[id] = lerp_angle(float(_giro_vis[id]), esterco, 1.0 - exp(-delta * GIRO_SUAVE))
		else:
			_giro_vis[id] = esterco
		c.rotation.y = rumo + float(_giro_vis[id])
		c.girar_rodas(maxf(ds, 0.0))
		if delta > 0.0:
			var v_antes := float(_v.get(id, 0.0))
			var dc := delta * taxa if taxa > 0.0 else delta  # tempo da corrida no quadro
			_v[id] = lerpf(v_antes, maxf(ds, 0.0) / dc, clampf(delta * 4.0, 0.0, 1.0))
			var acel := (float(_v[id]) - v_antes) / dc
			_efeitos_pista(id, acel, float(_v[id]), delta)
			# Arfagem: a frente sobe acelerando e mergulha freando.
			var arf_alvo := 0.0 if Preferencias.reduzir_animacoes else clampf(acel * ARFAGEM_POR_MS2, -ARFAGEM_MAX, ARFAGEM_MAX)
			_arfagem[id] = lerpf(float(_arfagem.get(id, 0.0)), arf_alvo, 1.0 - exp(-delta * 6.0))
			c.rotation.z = float(_arfagem[id]) + _arfagem_relevo(id, dist)
			if _fonte.tempo > 4.0:
				_v_max[id] = maxf(float(_v_max.get(id, 0.0)), float(_v[id]))
		c.rotation.x = _rolagem_banco(dist)
		_s_anterior[id] = dist
		var r: Label3D = _rotulos[id]
		# Sem nome, número nem seta sobre os carros: a classificação do HUD e os
		# anéis no chão bastam (decisão de polimento da corrida).
		r.text = ""
		r.visible = false
		r.position = c.position + Vector3(0, ALTURA_MARCADOR, 0)
	_apagar_marcas()
	_vacuo(s)
	_imagens_fantasma(delta)
	_ordenar_sprites(ordem)
	# Na visão geral, carros e números maiores para continuarem visíveis.
	var escala := 1.0
	_mostrar_pontos(visao_geral)
	for id in _carros:
		_carros[id].scale = Vector3.ONE * escala
		# Rótulos dos rivais pequenos e um pouco translúcidos; a seta e o ALVO em destaque.
		var forte: bool = id == "jogador" or (id == self.alvo and _anel_alvo != null and _anel_alvo.visible)
		_rotulos[id].pixel_size = (0.024 if forte else 0.0135) * (escala * 1.6 if visao_geral else 1.0)
		_rotulos[id].modulate.a = 1.0 if forte else 0.8
		# De cima, a altura não afasta o rótulo na tela: ele vai um pouco para o
		# alto da tela, para não cobrir o carro.
		var cima := _camera.global_basis.y * Vector3(1, 0, 1)
		cima = cima.normalized() if cima.length() > 0.01 else Vector3.ZERO
		_rotulos[id].position = _carros[id].position + Vector3(0, ALTURA_MARCADOR * escala, 0) \
				+ cima * 2.6 * escala * (1.0 - _b)
	var disputa := false
	if _anel_alvo != null:
		# Disputa: alvo a poucos metros; anel, rótulo ALVO, traço entre os dois e
		# câmera mais perto. Fora dela, nenhum marcador no chão.
		disputa = _carros.has(alvo) and _carros.has("jogador") and not visao_geral \
				and _carros["jogador"].position.distance_to(_carros[alvo].position) < DISPUTA_M
		_anel_alvo.visible = disputa
		if disputa:
			_anel_alvo.position = _carros[alvo].position + Vector3(0, 0.05, 0)
		# Seu carro: anel só por um instante, quando a câmera chega nele.
		_destaque_jogador = maxf(_destaque_jogador - delta, 0.0)
		_anel_jogador.visible = _destaque_jogador > 0.0 and _carros.has("jogador") and not visao_geral
		if _anel_jogador.visible:
			var u := 1.0 - _destaque_jogador / DESTAQUE_S
			_anel_jogador.position = _carros["jogador"].position + Vector3(0, 0.05, 0)
			_anel_jogador.scale = Vector3.ONE * lerpf(0.85, 1.25, smoothstep(0.0, 1.0, u))
			(_anel_jogador.material_override as StandardMaterial3D).albedo_color.a = (1.0 - smoothstep(0.35, 1.0, u)) * 0.9
		if _t_onda >= 0.0:
			_t_onda += delta
			var uo := _t_onda / ONDA_S
			_onda.visible = uo < 1.0 and _carros.has("jogador") and not visao_geral
			if _onda.visible:
				_onda.position = _carros["jogador"].position + Vector3(0, 0.08, 0)
				_onda.scale = Vector3.ONE * lerpf(0.5, 3.4, 1.0 - pow(1.0 - uo, 3.0))
				(_onda.material_override as StandardMaterial3D).albedo_color.a = pow(1.0 - uo, 1.5)
			else:
				_t_onda = -1.0
		_traco.visible = disputa
		if disputa:
			var a: Vector3 = _carros["jogador"].position
			var b: Vector3 = _carros[alvo].position
			_traco.position = (a + b) * 0.5 + Vector3(0, 0.08, 0)
			_traco.scale = Vector3(a.distance_to(b), 1, 1)
			_traco.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	if enquadrar_grid and not visao_geral and not _carros.is_empty():
		_camera_grid(s, ordem, delta)
		return
	if visao_geral:
		_enquadrar_geral()
		_camera.size = _tamanho_geral
		_alvo_camera = _centro_pista
		_mudar_modo("normal", true)
		efeito_velocidade = 0.0
		(material as ShaderMaterial).set_shader_parameter("intensidade", 0.0)
		_camera_imediata()
		return
	var seguido: String = foco if _carros.has(foco) else ("jogador" if _carros.has("jogador") else (ordem[0] if not ordem.is_empty() else ""))
	if seguido == "":
		return
	var disputa_seguida := disputa and foco == "jogador"
	var fixa := perseguicao and seguido == "jogador"
	var novo_modo := _decidir_modo(seguido, float(s[seguido]), disputa_seguida)
	if fixa and chegada <= 0.0:
		novo_modo = "normal"
	_mudar_modo(novo_modo, delta <= 0.0)
	_animar_modo(delta)
	# O isométrico só está certo para quem aponta como o carro seguido (a câmera
	# fica atrás dele); numa reta, os carros próximos também. Os outros seguem
	# com o sprite de cima.
	var rumo_seg := _pista.rumo_em(float(s[seguido]))
	for id in _carros:
		if _carros[id] is CarroDesenho:
			var alinhado := smoothstep(0.82, 0.96, cos(angle_difference(_pista.rumo_em(float(s[id])), rumo_seg)))
			_carros[id].mistura(_mistura_sprite() * alinhado)
	var tamanho_alvo := TAMANHO_PERSEGUICAO if fixa else (TAMANHO_DISPUTA if modo == "foco" else TAMANHO_CAMERA)
	# Dois carros no quadro (diretor): abre o bastante para os dois.
	var par := enquadrar_com if not fixa and _carros.has(enquadrar_com) and enquadrar_com != seguido \
			and _carros[seguido].position.distance_to(_carros[enquadrar_com].position) < 45.0 else ""
	if par != "":
		tamanho_alvo = maxf(TAMANHO_DISPUTA, _carros[seguido].position.distance_to(_carros[par].position) * 1.5 + 12.0)
	_tamanho_base = tamanho_alvo if delta <= 0.0 or Preferencias.reduzir_animacoes \
			else lerpf(_tamanho_base, tamanho_alvo, clampf(delta * 1.5, 0.0, 1.0))
	_camera.size = _tamanho_base / _zoom
	_rumo_seguido = _pista.rumo_em(float(s[seguido]))
	var v_seg := float(_v.get(seguido, 0.0))
	# Mais rápido, mais longe: a câmera abre com a velocidade (não na perseguição).
	if not fixa:
		_camera.size *= 1.0 + 0.22 * clampf(v_seg / V_FORTE, 0.0, 1.0)
	# Chegada: fecha devagar no carro.
	_camera.size *= lerpf(1.0, 0.76, smoothstep(0.0, 1.0, chegada))
	# Soco do toque e da comemoração: fecha e volta.
	_soco = maxf(_soco - delta / SOCO_S, 0.0)
	_camera.size *= 1.0 - SOCO_ZOOM * sin(_soco * PI) * _soco
	var novo: Vector3 = _carros[seguido].position
	if par != "" and modo != "velocidade":
		novo = (novo + _carros[par].position) * 0.5
	# Respiração: a câmera nunca fica parada. Deriva lenta de lado e para a
	# frente, e um zoom que vai e volta (períodos longos e diferentes, para não
	# parecer um ciclo).
	if not Preferencias.reduzir_animacoes and not fixa:
		var lado := Vector3(-sin(_rumo_seguido), 0.0, -cos(_rumo_seguido))
		var fr := Vector3(cos(_rumo_seguido), 0.0, -sin(_rumo_seguido))
		novo += lado * sin(_tempo * TAU / 11.0) * 1.3 + fr * sin(_tempo * TAU / 17.0 + 1.0) * 1.1
		_camera.size *= 1.0 + 0.045 * sin(_tempo * TAU / 13.0 + 2.0)
	# Na ultrapassagem, a câmera enquadra os dois carros.
	if modo == "velocidade" and _carros.has(_ultrapassado):
		var gap := float(s[_ultrapassado]) - float(s[seguido])
		var alvo_aperto := 1.0 - clampf(absf(gap) / 10.0, 0.0, 1.0)
		_aperto = alvo_aperto if delta <= 0.0 else lerpf(_aperto, alvo_aperto, clampf(delta * 3.0, 0.0, 1.0))
		novo = novo.lerp((novo + _carros[_ultrapassado].position) * 0.5, 0.6 * _b)
	else:
		_aperto = lerpf(_aperto, 0.0, clampf(delta * 3.0, 0.0, 1.0)) if delta > 0.0 else 0.0
	var frente := Vector3(cos(_rumo_seguido), 0.0, -sin(_rumo_seguido))
	# A câmera mira à frente do carro (mais pista livre adiante), mais no modo
	# velocidade.
	if fixa:
		novo += frente * _camera.size * AVANCO_PERSEGUICAO * (1.0 - _b)
	else:
		novo += frente * (minf(v_seg * 0.18, 7.0) * (1.0 - _b) + _camera.size * 0.18 * _b)
	# De cima, a câmera gira com o carro (a frente para o alto da tela), com
	# atraso: nas curvas o mundo gira em volta dele.
	var alvo_guinada := _rumo_seguido + PI
	# Com "Reduzir animações", a câmera não gira: fica a 45°, como o minimapa.
	if Preferencias.reduzir_animacoes:
		_guinada_normal = -PI / 4.0
	elif delta <= 0.0:
		_guinada_normal = alvo_guinada
	else:
		_guinada_normal = lerp_angle(_guinada_normal, alvo_guinada, clampf(delta * 1.6, 0.0, 1.0))
	# Inclinada, a câmera gira com o carro: atraso no seguimento vira deslocamento
	# grande na tela. Aí ela acompanha sem atraso.
	_alvo_camera = novo if delta <= 0.0 or Preferencias.reduzir_animacoes or _b > 0.0 \
			or _alvo_camera.distance_to(novo) > 40.0 else _alvo_camera.lerp(novo, clampf(delta * 5.0, 0.0, 1.0))
	efeito_velocidade = _b * clampf((float(_v.get(seguido, 0.0)) - V_MIN) / (V_FORTE - V_MIN), 0.3, 1.0)
	# Retas: perto da velocidade máxima que o carro já mostrou, um pouco do
	# efeito também de cima (linhas e borrão leves).
	var frac := v_seg / maxf(float(_v_max.get(seguido, 0.0)), RETA_V_MIN)
	var reta := 1.0 - smoothstep(0.0012, 0.0035, absf(_tracado.curvatura(float(s[seguido]))))
	efeito_velocidade = maxf(efeito_velocidade, RETA_EFEITO * smoothstep(0.84, 0.97, frac) * reta)
	efeito_velocidade = maxf(efeito_velocidade, IMPULSO_EFEITO * impulso) if seguido == "jogador" else efeito_velocidade
	# Efeitos leves (o padrão no navegador): sem o borrão, que lê a imagem 7
	# vezes por pixel da tela inteira; a vinheta continua.
	(material as ShaderMaterial).set_shader_parameter("intensidade",
			0.0 if Preferencias.reduzir_animacoes or Preferencias.efeitos_leves else efeito_velocidade)
	_camera_imediata()


## Largada: câmera de cima, com a frente do grid para o alto da tela,
## enquadrando todos os carros (com folga), sem efeito de velocidade.
var enquadrar_grid := false
const GRID_FOLGA_M := 9.0


func _camera_grid(s: Dictionary, ordem: Array, delta: float) -> void:
	var lider: String = ordem[0] if not ordem.is_empty() else "jogador"
	_rumo_seguido = _pista.rumo_em(float(s.get(lider, 0.0)))
	var frente := Vector3(cos(_rumo_seguido), 0.0, -sin(_rumo_seguido))
	var lado := Vector3(-sin(_rumo_seguido), 0.0, -cos(_rumo_seguido))
	# Caixa dos carros nos eixos do grid (comprimento e largura).
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var soma := Vector3.ZERO
	for id in _carros:
		var p: Vector3 = _carros[id].position
		soma += p
		var q := Vector2(p.dot(frente), p.dot(lado))
		mn = mn.min(q)
		mx = mx.max(q)
	var centro := soma / float(_carros.size())
	var meio := (mn + mx) * 0.5
	centro += frente * (meio.x - centro.dot(frente)) + lado * (meio.y - centro.dot(lado))
	var aspecto := size.x / size.y if size.y > 1.0 else 0.6
	# Altura da tela = comprimento do grid; a largura cabe pelo aspecto.
	var alvo_tamanho := maxf(mx.x - mn.x + 2.0 * GRID_FOLGA_M, (mx.y - mn.y + 2.0 * GRID_FOLGA_M) / aspecto)
	alvo_tamanho = maxf(alvo_tamanho, TAMANHO_CAMERA)
	var k := clampf(delta * 2.5, 0.0, 1.0) if delta > 0.0 else 1.0
	_tamanho_base = lerpf(_tamanho_base, alvo_tamanho, k)
	_camera.size = _tamanho_base
	_mudar_modo("normal", true)
	_b = 0.0
	_zoom = 1.0
	_guinada_normal = _rumo_seguido + PI
	_alvo_camera = centro
	efeito_velocidade = 0.0
	(material as ShaderMaterial).set_shader_parameter("intensidade", 0.0)
	for id in _carros:
		if _carros[id] is CarroDesenho:
			_carros[id].mistura(0.0)
	_camera_imediata()


## Anel no seu carro por DESTAQUE_S, crescendo e sumindo (a câmera chegou nele).
func destacar_jogador() -> void:
	if not Preferencias.reduzir_animacoes:
		_destaque_jogador = DESTAQUE_S


## Ponto do carro `id` na tela (coordenadas globais); (-1, -1) sem ele.
func posicao_tela(id: String) -> Vector2:
	if not _carros.has(id) or _camera == null or not is_inside_tree():
		return Vector2(-1, -1)
	var p := _camera.unproject_position(_carros[id].global_position)
	return get_global_transform() * (p * float(stretch_shrink))


## Defesa (Pilotagem): o carro `id` vai para o lado `lado` (-1 esquerda da
## tela, 1 direita) por `dura_s` segundos; só a tela.
const PUXAR_M := 2.6
func puxar(id: String, lado: int, dura_s: float) -> void:
	_puxar[id] = {"lado": lado, "ate": _tempo + dura_s}


## Momento de decisão: a escolha foi feita (soco da câmera e o anel no seu carro).
const IMPULSO_EFEITO := 0.6
const SOCO_ZOOM := 0.16
func acionar() -> void:
	if Preferencias.reduzir_animacoes:
		return
	_soco = 1.0
	_destaque_jogador = DESTAQUE_S


## A escolha deu certo: onda no chão, chuva de faíscas na cor, câmera treme.
func comemorar(cor: Color) -> void:
	if Preferencias.reduzir_animacoes or not _carros.has("jogador"):
		return
	_t_onda = 0.0
	(_onda.material_override as StandardMaterial3D).albedo_color = Color(cor, 1.0)
	_soco = 1.0
	_tremor = 0.35
	var p: Vector3 = _carros["jogador"].position + Vector3(0, 0.6, 0)
	_faiscas(p, cor, 60, 1.5)
	_faiscas(p + Vector3(0, 0.6, 0), Color(1, 1, 1), 24, 1.1)


func _camera_imediata() -> void:
	var tremor := Vector3.ZERO
	if efeito_velocidade > 0.85 and not Preferencias.reduzir_animacoes:
		tremor = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _camera.size * 0.0015
	if _tremor > 0.0 and not Preferencias.reduzir_animacoes:
		tremor += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.45 * minf(_tremor / 0.4, 1.0)
	var alvo_c := _alvo_camera + tremor
	if visao_geral:
		# Pista inteira: de cima, ortográfica, girada 45° (a projeção do minimapa).
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var hg := Vector3(cos(-PI / 4.0), 0.0, -sin(-PI / 4.0))
		var longe := 1400.0 * maxf(1.0, _camera.size / 960.0)
		_camera.look_at_from_position(alvo_c + (hg * 0.0005 + Vector3.UP) * longe, alvo_c, -hg)
		return
	# Seguindo um carro: perspectiva, atrás e acima dele (_guinada_normal gira
	# com o carro, com atraso nas curvas). No modo velocidade a câmera desce e
	# abre um pouco para o lado. _camera.size é a altura do quadro no chão: a
	# distância que mostra isso no FOV.
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = FOV_GRAUS
	var elevacao := deg_to_rad(lerpf(ELEVACAO_GRAUS, ELEVACAO_VELOCIDADE_GRAUS, _b))
	var guinada := lerp_angle(_guinada_normal, _rumo_seguido + PI + LADO_VELOCIDADE, _b)
	var h := Vector3(cos(guinada), 0.0, -sin(guinada))
	# Baixa e de lado (velocidade), a câmera precisa de mais distância para o
	# carro não encher a tela.
	var d := _camera.size * 0.5 / tan(deg_to_rad(FOV_GRAUS) * 0.5) * DISTANCIA_FATOR * lerpf(1.0, DISTANCIA_VELOCIDADE, _b)
	# Pórtico da largada entre a câmera e o carro: ela sobe por cima dele.
	var cam := alvo_c + (h * cos(elevacao) + Vector3.UP * sin(elevacao)) * d
	var tapa := 0.0
	if _pista != null:
		var p2 := _pista.posicao_em(PORTICO_M)
		var pp := Vector3(p2.x, PORTICO_ALTURA_M, -p2.y)
		var seg := alvo_c - cam
		var u := clampf((pp - cam).dot(seg) / maxf(seg.length_squared(), 1e-6), 0.0, 1.0)
		tapa = 1.0 - smoothstep(PORTICO_FOLGA_M * 0.5, PORTICO_FOLGA_M, (cam + seg * u).distance_to(pp))
		if u <= 0.02 or u >= 0.98:
			tapa = 0.0
	_sobe_portico = lerpf(_sobe_portico, tapa, 0.12) if not Preferencias.reduzir_animacoes else tapa
	elevacao = lerpf(elevacao, deg_to_rad(PORTICO_ELEVACAO_GRAUS), _sobe_portico)
	_camera.look_at_from_position(alvo_c + (h * cos(elevacao) + Vector3.UP * sin(elevacao)) * d, alvo_c, Vector3.UP)


# --- Modos de câmera (decisão 31) ---------------------------------------------

## "normal" (de cima), "foco" (disputa, mais perto) ou "velocidade" (inclinada,
## atrás do carro, sprite isométrico e efeito nas bordas).
var modo := "normal"
## Câmera de perseguição (revisão da corrida, decisão 131): seguindo o seu
## carro, sem zoom pela velocidade, sem respiração e sem os planos inclinados;
## o carro fica sempre no mesmo ponto, no terço de baixo da tela, e a pista à
## frente aparece — as deixas da pilotagem caem sempre no mesmo lugar.
var perseguicao := false
const TAMANHO_PERSEGUICAO := 34.0
## Quanto a câmera mira à frente do carro, em frações do quadro (põe o carro
## no terço de baixo).
const AVANCO_PERSEGUICAO := 0.42
## Intensidade do efeito de tela (0..1), lida pela tela da corrida.
var efeito_velocidade := 0.0
## Velocidade do relógio da corrida neste quadro (1×, o fator da aceleração ou 0
## parado), dada pela tela da corrida. A velocidade dos carros é medida no
## relógio da corrida: medida no tempo real, em 2× ela dobrava, e o borrão de
## tela cheia, a fumaça e os rastros ficavam no máximo (o jogo pesava).
var taxa := 1.0
var _b := 0.0  # 0 = de cima; 1 = velocidade
var _zoom := 1.0
var _tamanho_base := TAMANHO_CAMERA
var _rumo_seguido := 0.0
var _guinada_normal := -PI / 4.0
var _t_modo := 0.0
var _espera := 0.0
var _b_saida := 0.0
var _zoom_saida := 1.0
var _ultrapassado := ""  # quem o carro seguido está passando (câmera da ultrapassagem)
var _inicio_ultrapassagem := 0.0
var _fim_ultrapassagem := 0.0
var _aperto := 0.0  # 0..1: quão colados estão os dois (zoom da ultrapassagem)
var _v := {}  # id -> velocidade suavizada (m/s)
## Apresentação, não balanceamento: duração da entrada e da saída, tempo mínimo
## entre duas entradas, quanto de reta (em segundos de percurso) justifica o
## modo e velocidade a partir da qual ele faz sentido.
const ENTRADA_S := 0.45
const SAIDA_S := 0.5
const ESPERA_S := 3.0
## Câmera da ultrapassagem: entra quando o carro seguido está até
## ULTRAPASSAGEM_GAP_M atrás de outro e vai passá-lo em até ANTECEDENCIA_S;
## sai DEPOIS_S depois da passagem (ou em MAX_ULTRAPASSAGEM_S, se não vier).
const ULTRAPASSAGEM_GAP_M := 14.0
const ANTECEDENCIA_S := 1.8
const DEPOIS_S := 1.3
const MAX_ULTRAPASSAGEM_S := 5.0
const V_MIN := 22.0
const V_FORTE := 60.0


func _decidir_modo(id: String, _s: float, disputa: bool) -> String:
	var calmo := "foco" if disputa else "normal"
	if Preferencias.reduzir_animacoes or _fonte == null:
		return calmo
	# Chegada: a câmera inclinada atrás do carro, mais perto, até o fim.
	if chegada > 0.0:
		_ultrapassado = ""
		return "velocidade"
	var agora := _fonte.tempo
	if modo == "velocidade":
		# Fica até o carro seguido estar bem à frente do ultrapassado; sai antes
		# se a ultrapassagem não se confirmou.
		if _ultrapassado != "" and agora < _fim_ultrapassagem + DEPOIS_S \
				and agora < _inicio_ultrapassagem + MAX_ULTRAPASSAGEM_S:
			return "velocidade"
		_ultrapassado = ""
		return calmo
	if _espera > 0.0:
		return calmo
	# Ultrapassagem a caminho: um carro logo à frente que o seguido vai passar
	# nos próximos ANTECEDENCIA_S (o resultado já está decidido; a câmera só
	# sabe antes).
	var s_eu := _fonte.distancia_em(id, agora)
	for outro in _carros:
		if outro == id:
			continue
		var gap := _fonte.distancia_em(outro, agora) - s_eu
		if gap <= 0.0 or gap > ULTRAPASSAGEM_GAP_M:
			continue
		var t := agora
		while t < agora + ANTECEDENCIA_S:
			t += 0.1
			if _fonte.distancia_em(id, t) > _fonte.distancia_em(outro, t) + 0.5:
				_ultrapassado = outro
				_inicio_ultrapassagem = agora
				_fim_ultrapassagem = t
				return "velocidade"
	return calmo


func _mudar_modo(novo: String, imediato: bool) -> void:
	if novo == modo:
		return
	if novo == "velocidade" and not imediato and not Preferencias.reduzir_animacoes:
		_fantasma = FANTASMA_S
	if modo == "velocidade":
		_b_saida = _b
		_zoom_saida = _zoom
		_espera = ESPERA_S
	modo = novo
	_t_modo = 0.0
	if imediato:
		_b = 1.0 if novo == "velocidade" else 0.0
		_zoom = 1.32 if novo == "velocidade" else 1.0


## Entrada: aproxima com um pequeno passo além (1,00 → 1,38 → 1,32) enquanto
## inclina; saída: volta suave, sem passo além.
func _animar_modo(delta: float) -> void:
	_t_modo += delta
	_espera = maxf(_espera - delta, 0.0)
	if modo == "velocidade":
		var u := clampf(_t_modo / ENTRADA_S, 0.0, 1.0)
		_b = maxf(_b, smoothstep(0.1, 0.9, u))
		_zoom = lerpf(1.0, 1.38, smoothstep(0.0, 1.0, u / 0.7)) if u < 0.7 \
				else lerpf(1.38, 1.32, smoothstep(0.0, 1.0, (u - 0.7) / 0.3))
		# Lado a lado, a câmera fecha nos dois; depois da passagem, abre.
		_zoom *= lerpf(1.0, 1.45, _aperto)
	else:
		var u := clampf(_t_modo / SAIDA_S, 0.0, 1.0)
		_b = lerpf(_b_saida, 0.0, smoothstep(0.0, 1.0, u))
		_zoom = lerpf(_zoom_saida, 1.0, smoothstep(0.0, 1.0, u))
		if u >= 1.0:
			_b_saida = 0.0
			_zoom_saida = 1.0


## A troca de sprite acontece com a câmera já perto e quase inclinada.
func _mistura_sprite() -> float:
	return smoothstep(0.35, 0.75, _b)


## Batida entre a e b (dl = lateral de a menos a de b): os dois se afastam e
## giram para lados opostos, faíscas no ponto do toque, câmera treme se o
## carro seguido está na batida.
func _bater(a: String, b: String, dl: float) -> void:
	var lado := 1.0 if dl >= 0.0 else -1.0
	_off[a] = float(_off[a]) + lado * BATIDA_EMPURRAO_M
	_off[b] = float(_off[b]) - lado * BATIDA_EMPURRAO_M
	_giro_batida[a] = lado * BATIDA_GIRO * randf_range(0.7, 1.0)
	_giro_batida[b] = -lado * BATIDA_GIRO * randf_range(0.7, 1.0)
	_tranco[a] = BATIDA_S
	_tranco[b] = BATIDA_S
	var seguido := foco if _carros.has(foco) else "jogador"
	if a == seguido or b == seguido:
		_tremor = 0.4
	Sons.tocar_ui(self, "batida", -4.0 if a == seguido or b == seguido else -16.0, randf_range(0.9, 1.1))
	_faiscas((_carros[a].position + _carros[b].position) * 0.5 + Vector3(0, 0.4, 0))


# --- Efeitos de pista: luz de freio e fumaça dos pneus ---------------------
# Só leitura do movimento que a simulação já decidiu (a desaceleração da
# distância andada); nada aqui muda o resultado.

## Freada (m/s²): acende acima de FREIO_ON, apaga abaixo de FREIO_OFF.
const FREIO_ON := 3.5
const FREIO_OFF := 1.5
## Fumaça: freada forte, ou arrancada forte em baixa velocidade.
const FUMACA_FREADA := 10.0
const FUMACA_ARRANCADA := 5.5
const FUMACA_V_MAX := 8.0  # m/s: acima disso a arrancada não solta fumaça
var _freio := {}  # id -> intensidade da luz (0..1), suavizada
var _luzes := {}  # id -> StandardMaterial3D das lanternas
## Esteira de fumaça: uma fita macia no chão atrás de cada carro, pelo
## caminho que ele fez nos últimos ESTEIRA_S; fina e quase transparente com o
## carro andando, mais larga e densa na freada e na arrancada fortes.
const ESTEIRA_S := 0.45
const ESTEIRA_PONTOS := 22
const ESTEIRA_BASE := 0.45  # intensidade andando (0..1)
const ESTEIRA_ALFA := 0.22  # alfa no pico da intensidade, junto ao carro
var _fumaca := {}  # id -> true enquanto canta pneu (freada/arrancada forte)
var _esteira := {}  # id -> MeshInstance3D com ImmediateMesh
var _rastro_pts := {}  # id -> Array de [Vector3, tempo, intensidade]
var _intensidade := {}  # id -> intensidade atual (suavizada)
var _rear := {}  # id -> distância da traseira ao centro (m)
var _largura_carro := {}  # id -> largura do carro (m)


func _criar_efeitos(id: String, c: Node3D) -> void:
	var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(4.4, 1.75)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 3
	mat.albedo_texture = _brilho()
	mat.albedo_color = Color(1.0, 0.12, 0.08, 0.0)
	for lado in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		var m := QuadMesh.new()
		m.size = Vector2(0.95, 0.95)
		q.mesh = m
		q.material_override = mat
		q.position = Vector3(-dim.x * 0.5 + 0.1, 0.55, lado * dim.y * 0.33)
		c.add_child(q)
	_luzes[id] = mat
	_freio[id] = 0.0
	if Preferencias.efeitos_leves:
		return
	_criar_esteira(id, dim)


func _criar_esteira(id: String, dim: Vector2) -> void:
	var m := MeshInstance3D.new()
	m.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _faixa_macia()
	mat.render_priority = 1
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cena.add_child(m)
	_esteira[id] = m
	_rastro_pts[id] = []
	_rear[id] = dim.x * 0.45
	_largura_carro[id] = dim.y


## Guarda o ponto atrás do carro e redesenha a fita: largura cresce e alfa cai
## com a idade de cada ponto; a intensidade de cada ponto é a de quando ele
## foi deixado (a parte da freada fica mais densa).
func _atualizar_esteira(id: String) -> void:
	var c: Node3D = _carros[id]
	var pts: Array = _rastro_pts[id]
	var atras := Vector3(-cos(c.rotation.y), 0.0, sin(c.rotation.y))
	var p := c.position + atras * float(_rear[id]) * c.scale.x + Vector3(0, 0.25, 0)
	var inten := float(_intensidade[id])
	if pts.is_empty() or (pts[-1][0] as Vector3).distance_to(p) > 0.35:
		pts.append([p, _tempo, inten])
	else:
		pts[-1] = [p, _tempo, maxf(inten, float(pts[-1][2]))]
	while not pts.is_empty() and _tempo - float(pts[0][1]) > ESTEIRA_S:
		pts.pop_front()
	while pts.size() > ESTEIRA_PONTOS * 3:
		pts.pop_front()
	var im: ImmediateMesh = _esteira[id].mesh
	im.clear_surfaces()
	if pts.size() < 2 or not c.visible:
		return
	# Intensidade suavizada entre pontos vizinhos (nenhum trecho destoa).
	var suave := PackedFloat32Array()
	suave.resize(pts.size())
	for i in pts.size():
		var soma := 0.0
		var n := 0.0
		for j in range(maxi(i - 3, 0), mini(i + 4, pts.size())):
			soma += float(pts[j][2])
			n += 1.0
		suave[i] = soma / n
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var a: Vector3 = pts[i][0]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)][0] if i < pts.size() - 1 else pts[i][0] + (pts[i][0] - pts[i - 1][0])
		var dir := (b - a)
		dir.y = 0.0
		if dir.length() < 0.001:
			dir = atras * -1.0
		var lado := Vector3(-dir.z, 0.0, dir.x).normalized()
		var idade := clampf((_tempo - float(pts[i][1])) / ESTEIRA_S, 0.0, 1.0)
		var forca := suave[i]
		# Na proporção do carro: sai com metade da largura dele e abre até a
		# largura inteira (um pouco mais na freada forte).
		var largura := float(_largura_carro[id]) * lerpf(0.5, 1.0, idade) * lerpf(0.9, 1.15, forca) * c.scale.x
		# Junto ao carro entra suave; some com a idade.
		var alfa := ESTEIRA_ALFA * forca * smoothstep(0.0, 0.2, idade) * (1.0 - smoothstep(0.25, 1.0, idade))
		var cor := Color(0.87, 0.86, 0.84, alfa)
		if id == "jogador" and impulso > 0.0:
			cor = cor.lerp(Color(Aba.COR_DESTAQUE, minf(alfa * 2.6, 0.75)), impulso)
		var y := a + Vector3(0, idade * 0.2, 0)
		im.surface_set_color(cor)
		im.surface_set_uv(Vector2(0.0, idade))
		im.surface_add_vertex(y + lado * largura * 0.5)
		im.surface_set_color(cor)
		im.surface_set_uv(Vector2(1.0, idade))
		im.surface_add_vertex(y - lado * largura * 0.5)
	im.surface_end()


## Textura da fita: opaca no meio, some nas bordas (em u).
static var _textura_faixa: Texture2D
static func _faixa_macia() -> Texture2D:
	if _textura_faixa == null:
		var img := Image.create(64, 4, false, Image.FORMAT_RGBA8)
		for x in 64:
			var u := (x + 0.5) / 64.0
			var k := pow(sin(PI * u), 1.5)
			for y in 4:
				img.set_pixel(x, y, Color(1, 1, 1, k))
		_textura_faixa = ImageTexture.create_from_image(img)
	return _textura_faixa


## Mancha redonda suave (lanternas e fumaça), feita uma vez.
static var _textura_brilho: Texture2D
static var _textura_nuvem: Texture2D
## so_alfa: branca, só o alfa cai (fumaça); senão escurece junto (lanternas).
static func _brilho(so_alfa := false) -> Texture2D:
	if so_alfa and _textura_nuvem == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.4)))
		_textura_nuvem = ImageTexture.create_from_image(img)
	if so_alfa:
		return _textura_nuvem
	if _textura_brilho == null:
		# Escurece junto com o alfa: serve tanto somando (lanternas) quanto por
		# transparência (fumaça).
		var lado := 64
		var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		for y in lado:
			for x in lado:
				var d := Vector2(x + 0.5 - lado * 0.5, y + 0.5 - lado * 0.5).length() / (lado * 0.5)
				var k := pow(clampf(1.0 - d, 0.0, 1.0), 1.6)
				img.set_pixel(x, y, Color(k, k, k, k))
		_textura_brilho = ImageTexture.create_from_image(img)
	return _textura_brilho


## Carros não se atravessam: dois que se sobrepõem no comprimento (Δs menor
## que SEPARA_COMPRIMENTO_M) e estão mais perto de lado que SEPARA_LADO_M são
## empurrados para os lados, suavemente, dentro da pista. Só visual: a posição
## na pista (s) é a da simulação.
const SEPARA_COMPRIMENTO_M := 7.0
const SEPARA_LADO_M := 2.3
const SEPARA_RAPIDEZ := 10.0  # 1/s


func _separar(s: Dictionary, base: Dictionary, delta: float) -> void:
	if _fonte == null or chegada >= 1.0:
		return
	var ids := _carros.keys()
	var k := clampf(delta * SEPARA_RAPIDEZ, 0.0, 1.0) if delta > 0.0 else 1.0
	for _passo in 3:
		var empurra := {}
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				var ds := absf(_ciclo(float(s[a]) - float(s[b])))
				if ds >= SEPARA_COMPRIMENTO_M:
					continue
				var dl := float(_lateral[a]) - float(_lateral[b])
				if absf(dl) >= SEPARA_LADO_M:
					continue
				# Quanto falta, pesado pela sobreposição no comprimento.
				var falta := (SEPARA_LADO_M - absf(dl)) * (1.0 - ds / SEPARA_COMPRIMENTO_M) * 0.5
				var lado := signf(dl) if absf(dl) > 0.01 else (1.0 if a < b else -1.0)
				empurra[a] = float(empurra.get(a, 0.0)) + lado * falta
				empurra[b] = float(empurra.get(b, 0.0)) - lado * falta
		if empurra.is_empty():
			return
		for id in empurra:
			var novo := clampf(float(_lateral[id]) + float(empurra[id]) * k, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
			_lateral[id] = novo
			_off[id] = novo - float(base[id])


## Separação firme (teste com pessoas de 2026-10-21: "carros muito próximos
## tinham uns bugs"): dois carros lado a lado no comprimento (Δs menor que
## FIRME_COMPRIMENTO_M) ficam a FIRME_LADO_M ou mais de lado, na hora. Quem
## está na beira da pista não sai dela: o outro vai o resto.
const FIRME_COMPRIMENTO_M := 4.6
const FIRME_LADO_M := 2.0


func _separar_firme(s: Dictionary, base: Dictionary) -> void:
	if _fonte == null or chegada >= 1.0:
		return
	var ids := _carros.keys()
	for _passo in 24:
		var mexeu := false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				if absf(_ciclo(float(s[a]) - float(s[b]))) >= FIRME_COMPRIMENTO_M:
					continue
				var dl := float(_lateral[a]) - float(_lateral[b])
				if absf(dl) >= FIRME_LADO_M - 0.001:
					continue
				var lado := signf(dl) if absf(dl) > 0.01 else (1.0 if a < b else -1.0)
				var falta := FIRME_LADO_M - absf(dl)
				var na := clampf(float(_lateral[a]) + lado * falta * 0.5, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
				var nb := clampf(float(_lateral[b]) - lado * falta * 0.5, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
				# Um deles na beira: o outro completa a distância.
				if absf(na - nb) < FIRME_LADO_M:
					if absf(na) >= Tracado.TANGENCIA_M:
						nb = clampf(na - lado * FIRME_LADO_M, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
					else:
						na = clampf(nb + lado * FIRME_LADO_M, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
				_lateral[a] = na
				_lateral[b] = nb
				_off[a] = na - float(base[a])
				_off[b] = nb - float(base[b])
				mexeu = true
		if not mexeu:
			return


## Altura do carro (m): o chão do relevo ou, no ar depois de uma rampa, a
## balística a partir da velocidade da simulação; ao tocar o chão, um tranco.
func _altura_carro(id: String, dist: float, delta: float) -> float:
	if _relevo == null or _relevo.vazio():
		return 0.0
	var chao := _relevo.altura(dist)
	if delta <= 0.0:
		_voo.erase(id)
		return chao
	var v := float(_v.get(id, 0.0))
	var dc := delta * taxa if taxa > 0.0 else delta
	var rampa := _relevo.rampa_cruzada(float(_s_anterior.get(id, dist)), dist)
	if not rampa.is_empty() and v > VOO_V_MIN and not _voo.has(id):
		_voo[id] = {"y": float(rampa[1]), "vz": _relevo.saida(rampa, v)}
	if not _voo.has(id):
		return chao
	var voo: Dictionary = _voo[id]
	voo["vz"] = float(voo["vz"]) - Relevo.G * dc
	voo["y"] = float(voo["y"]) + float(voo["vz"]) * dc
	if float(voo["y"]) <= chao:
		_voo.erase(id)
		if not Preferencias.reduzir_animacoes:
			_tranco[id] = BATIDA_S * 0.6  # o pouso sacode o carro
			if id == (foco if _carros.has(foco) else "jogador"):
				_tremor = 0.25
		return chao
	return float(voo["y"])


## Inclinação da carroceria pelo relevo: acompanha a rampa no chão; no ar, o
## nariz segue a trajetória.
func _arfagem_relevo(id: String, dist: float) -> float:
	if _relevo == null or _relevo.vazio() or Preferencias.reduzir_animacoes:
		return 0.0
	if _voo.has(id):
		return clampf(atan2(float(_voo[id]["vz"]), maxf(float(_v.get(id, 1.0)), 1.0)) * 0.6, -0.35, 0.35)
	return atan(_relevo.inclinacao(dist))


## Curvas inclinadas (trecho "inclinacao_graus", o oval): a tangente por metro,
## com rampa de 40 m na entrada e na saída para a pista não dar degrau.
func _preparar_banco() -> void:
	_banco = PackedFloat32Array()
	_banco_lado = PackedFloat32Array()
	if not _pista.trechos.any(func(t): return float(t.get("inclinacao_graus", 0.0)) > 0.0):
		return
	var n := maxi(int(_pista.comprimento), 1)
	var bruto := PackedFloat32Array()
	bruto.resize(n)
	_banco_lado.resize(n)
	for i in n:
		var t: Dictionary = _pista.trechos[_pista.indice_em(i + 0.5)]
		bruto[i] = tan(deg_to_rad(float(t.get("inclinacao_graus", 0.0))))
		_banco_lado[i] = -1.0 if t.get("sentido", "esquerda") == "direita" else 1.0
	# O lado das retas é o da curva mais perto (a rampa de saída fica do lado certo).
	for i in n:
		if bruto[i] == 0.0:
			for k in range(1, 60):
				if bruto[(i + k) % n] > 0.0:
					_banco_lado[i] = _banco_lado[(i + k) % n]
					break
				if bruto[(i - k + n) % n] > 0.0:
					_banco_lado[i] = _banco_lado[(i - k + n) % n]
					break
	_banco.resize(n)
	var meia := 20
	for i in n:
		var soma := 0.0
		for k in range(-meia, meia + 1):
			soma += bruto[(i + k + n) % n]
		_banco[i] = soma / (2 * meia + 1)


func _banco_em(dist: float) -> Vector2:
	if _banco.is_empty():
		return Vector2.ZERO
	var i := int(fposmod(dist, _banco.size()))
	return Vector2(_banco[i], _banco_lado[i])


## Altura do asfalto inclinado em `dist`, `lateral` m do centro (+ esquerda):
## zero na borda de dentro, sobe para fora.
func _altura_banco(dist: float, lateral: float) -> float:
	var b := _banco_em(dist)
	if b.x <= 0.0:
		return 0.0
	return maxf(LARGURA_PISTA_M * 0.5 - b.y * lateral, 0.0) * b.x


## A carroceria deita com a pista inclinada (para dentro da curva).
func _rolagem_banco(dist: float) -> float:
	var b := _banco_em(dist)
	return -b.y * atan(b.x) if b.x > 0.0 else 0.0


## As curvas inclinadas na tela: o asfalto deitado de dentro para fora, a faixa
## de concreto até o muro e a parede de fora até o chão.
func _banco_malha() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tema: Dictionary = TEMAS.get(TEMA_DE.get(_pista.id, _pista.id), TEMA_PADRAO)
	var asfalto: Color = tema["asfalto"]
	var meia := LARGURA_PISTA_M * 0.5
	var n := _banco.size()
	var antes := []
	for i in n + 1:
		var s := float(i % n)
		var b := _banco_em(s)
		var c := _pista.posicao_em(s)
		var nrm := Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0)
		var lado := b.y
		# Perfil de dentro para fora: borda de dentro, borda de fora, concreto, topo do muro, chão de fora.
		var laterais := [lado * meia, -lado * meia, -lado * (meia + 2.5), -lado * (meia + 2.5), -lado * (meia + 2.5)]
		var pts := []
		for k in laterais.size():
			var lat: float = laterais[k]
			var h := maxf(meia - lado * lat, 0.0) * b.x
			if k == 3:
				h += 1.1  # muro
			elif k == 4:
				h = 0.0
			var p := c + nrm * lat
			pts.append(Vector3(p.x, h + 0.04, -p.y))
		if b.x > 0.002 and not antes.is_empty():
			var cores := [asfalto, COR_CONCRETO, Color(0.92, 0.92, 0.94), COR_CONCRETO.darkened(0.3)]
			for f in 4:
				var a: Vector3 = antes[f]
				var bb: Vector3 = antes[f + 1]
				var cc: Vector3 = pts[f + 1]
				var d: Vector3 = pts[f]
				st.set_color(cores[f])
				for v in [a, bb, cc, a, cc, d]:
					st.add_vertex(v)
		antes = pts
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := CarroBloco._material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## O relevo na tela: a pista de terra levantada nas ondulações e nas rampas, com
## as laterais de terra até o chão.
func _relevo_malha() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trechos := []
	for o in _pista.relevo.get("ondulacoes", []):
		trechos.append([float(o[0]), float(o[1])])
	for r in _pista.relevo.get("rampas", []):
		trechos.append([float(r[0]) - float(r[2]) - 1.0, float(r[0]) + float(r[3]) + 1.0])
	var meia := LARGURA_PISTA_M * 0.5 + 0.6
	for tr in trechos:
		var s0: float = tr[0]
		var s1: float = tr[1]
		var n := maxi(int((s1 - s0) / 0.8), 2)
		var antes := []
		for k in n + 1:
			var sk := lerpf(s0, s1, float(k) / n)
			var c := _pista.posicao_em(sk)
			var nrm := Vector2.from_angle(_pista.rumo_em(sk) + PI / 2.0) * meia
			var h := _relevo.altura(sk) + 0.03
			var pts := [Vector3(c.x + nrm.x, 0.0, -(c.y + nrm.y)), Vector3(c.x + nrm.x, h, -(c.y + nrm.y)),
					Vector3(c.x - nrm.x, h, -(c.y - nrm.y)), Vector3(c.x - nrm.x, 0.0, -(c.y - nrm.y))]
			if not antes.is_empty():
				# Faixas claras e escuras a cada 1,6 m no topo (lê-se o desenho da
				# rampa e das costelas de cima); laterais mais escuras.
				var faixa := COR_TERRA.lightened(0.12) if int(sk / 1.6) % 2 == 0 else COR_TERRA.darkened(0.08)
				for f in 3:  # lateral esquerda, topo, lateral direita
					var a: Vector3 = antes[f]
					var b: Vector3 = antes[f + 1]
					var cc: Vector3 = pts[f + 1]
					var d: Vector3 = pts[f]
					st.set_color(faixa if f == 1 else COR_TERRA.darkened(0.35))
					for v in [a, b, cc, a, cc, d]:
						st.add_vertex(v)
			antes = pts
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := CarroBloco._material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## Sombra do carro no chão enquanto ele está no ar: mancha escura que encolhe
## e clareia com a altura (é ela que mostra o tamanho do salto).
func _sombra_voo(id: String, c: Node3D, dist: float) -> void:
	var sombra: MeshInstance3D = _sombras_voo.get(id)
	if not _voo.has(id):
		if sombra != null:
			sombra.visible = false
		return
	if sombra == null:
		sombra = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(4.6, 2.2)
		q.orientation = PlaneMesh.FACE_Y
		sombra.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _brilho(true)
		mat.albedo_color = Color(0, 0, 0, 0.5)
		sombra.material_override = mat
		sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cena.add_child(sombra)
		_sombras_voo[id] = sombra
	var chao := _relevo.altura(dist)
	var alto := maxf(c.position.y - chao, 0.0)
	sombra.visible = true
	sombra.position = Vector3(c.position.x, chao + 0.05, c.position.z)
	sombra.rotation.y = c.rotation.y
	sombra.scale = Vector3.ONE * clampf(1.0 - alto * 0.08, 0.55, 1.0)
	(sombra.material_override as StandardMaterial3D).albedo_color.a = clampf(0.55 - alto * 0.06, 0.15, 0.55)


## Diferença de distância na volta (para quem está uma volta à frente).
func _ciclo(d: float) -> float:
	var c := _pista.comprimento
	return fposmod(d + c * 0.5, c) - c * 0.5


## Imagens-fantasma na troca de câmera (de cima para a isométrica): o carro
## seguido deixa cópias tingidas nas posições dos últimos instantes, que somem
## em FANTASMA_S.
const FANTASMA_S := 0.9
const FANTASMA_N := 4
const FANTASMA_PASSO_S := 0.06  # distância no tempo entre duas cópias
const FANTASMA_COR := Color(0.55, 0.85, 1.0)
var _fantasma := 0.0
var _historico := []  # [tempo, Transform3D] do carro seguido
var _fantasma_de := ""


func _imagens_fantasma(delta: float) -> void:
	var seguido: String = foco if _carros.has(foco) else "jogador"
	if not _carros.has(seguido):
		return
	if seguido != _fantasma_de:
		if _carros.has(_fantasma_de) and _carros[_fantasma_de] is CarroDesenho:
			_carros[_fantasma_de].fantasmas([], 0.0, FANTASMA_COR)
		for copia in _copias_bloco:
			copia.queue_free()
		_copias_bloco.clear()
		_mats_bloco.clear()
		_historico.clear()
		_fantasma_de = seguido
	var c: Node3D = _carros[seguido]
	_historico.append([_tempo, c.global_transform])
	while not _historico.is_empty() and _tempo - float(_historico[0][0]) > FANTASMA_PASSO_S * (FANTASMA_N + 1):
		_historico.pop_front()
	_fantasma = maxf(_fantasma - delta, 0.0)
	if _fantasma <= 0.0:
		if c is CarroDesenho:
			c.fantasmas([], 0.0, FANTASMA_COR)
		_fantasmas_bloco([], 0.0)
		return
	var posicoes := []
	for k in range(1, FANTASMA_N + 1):
		var alvo := _tempo - FANTASMA_PASSO_S * k
		var melhor: Transform3D = _historico[0][1]
		for h in _historico:
			if float(h[0]) <= alvo:
				melhor = h[1]
		posicoes.append(melhor)
	# Só com a câmera já inclinando; some no fim do tempo.
	var forca := smoothstep(0.1, 0.5, _mistura_sprite()) * smoothstep(0.0, FANTASMA_S * 0.5, _fantasma)
	if c is CarroDesenho:
		c.fantasmas(posicoes, forca, FANTASMA_COR)
	else:
		_fantasmas_bloco(posicoes, forca)


## Carro de blocos (3D): cópias da malha com um material claro translúcido.
var _copias_bloco: Array = []
var _mats_bloco: Array = []


func _fantasmas_bloco(posicoes: Array, forca: float) -> void:
	var c: Node3D = _carros.get(_fantasma_de)
	if forca > 0.001 and c != null and _copias_bloco.size() < posicoes.size():
		for k in range(_copias_bloco.size(), posicoes.size()):
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(FANTASMA_COR, 0.0)
			mat.no_depth_test = true
			var copia := Node3D.new()
			copia.top_level = true
			for m in c.find_children("*", "MeshInstance3D", true, false):
				if m.get_parent() is CPUParticles3D or not m.visible:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = (m as MeshInstance3D).mesh
				mi.material_override = mat
				mi.transform = c.global_transform.affine_inverse() * m.global_transform
				copia.add_child(mi)
			_cena.add_child(copia)
			_copias_bloco.append(copia)
			_mats_bloco.append(mat)
	for k in _copias_bloco.size():
		var copia: Node3D = _copias_bloco[k]
		copia.visible = forca > 0.001 and k < posicoes.size()
		if copia.visible:
			copia.global_transform = posicoes[k]
			(_mats_bloco[k] as StandardMaterial3D).albedo_color.a = forca * (1.0 - float(k) / float(posicoes.size() + 1)) * 0.45


## Sprites transparentes se desenham pela ordem dada, não pela profundidade
## real: quem está mais perto da câmera fica por cima (empate, no chão visto
## de cima: o que vai à frente na corrida).
func _ordenar_sprites(ordem: Array) -> void:
	var f := -_camera.global_basis.z
	var o := _camera.global_position
	var lista := []
	for id in _carros:
		if _carros[id] is CarroDesenho:
			var prof := snappedf((_carros[id].global_position - o).dot(f), 0.05)
			lista.append([prof, ordem.find(id), id])
	lista.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	for k in lista.size():
		var id: String = lista[k][2]
		_carros[id].ordem_desenho(k)
		if _luzes.has(id):
			(_luzes[id] as StandardMaterial3D).render_priority = 41 + 2 * k


## Visão geral: cada carro vira um ponto na cor dele (o seu, ocre com borda
## clara), do mesmo tamanho na tela; os carros em si somem.
const PONTO_FRACAO := 0.011  # raio do ponto em fração do tamanho da câmera
var _pontos := {}  # id -> MeshInstance3D


func _mostrar_pontos(sim: bool) -> void:
	for id in _carros:
		_carros[id].visible = not sim
		if sim and not _pontos.has(id):
			_pontos[id] = _criar_ponto(id)
		if _pontos.has(id):
			_pontos[id].visible = sim
	if not sim:
		return
	var r := maxf(_camera.size * PONTO_FRACAO, 1.2)
	for id in _pontos:
		_pontos[id].position = _carros[id].position + Vector3(0, 0.3, 0)
		_pontos[id].scale = Vector3(r, 1.0, r) * (1.25 if id == "jogador" else 1.0)


func _criar_ponto(id: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.05
	disco.radial_segments = 24
	m.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Aba.COR_DESTAQUE if id == "jogador" else _fonte.cor_de(id)
	mat.no_depth_test = true
	mat.render_priority = 120 if id == "jogador" else 110
	m.material_override = mat
	# Borda: um disco escuro (rivais) ou claro (você) um pouco maior, por baixo.
	var borda := MeshInstance3D.new()
	borda.mesh = disco
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.albedo_color = Color(1, 1, 1) if id == "jogador" else Color(0.05, 0.05, 0.06)
	mb.no_depth_test = true
	mb.render_priority = 119 if id == "jogador" else 109
	borda.material_override = mb
	borda.scale = Vector3(1.3, 1.0, 1.3)
	borda.position.y = -0.01
	m.add_child(borda)
	_cena.add_child(m)
	return m


## Linhas de velocidade nas retas: intensidade máxima e velocidade mínima
## de referência (m/s) antes de o carro mostrar a dele.
const RETA_EFEITO := 0.32
const RETA_V_MIN := 25.0
var _v_max := {}  # id -> maior velocidade vista (m/s)

## Marcas de pneu: na freada forte, traços escuros no chão que somem devagar.
const MARCA_FREADA := 8.5  # m/s²
const MARCA_PASSO_M := 0.7
const MARCAS_MAX := 240
const MARCA_DURA_S := 5.0
var _marcas: MultiMeshInstance3D
var _marca_i := 0
var _marca_t := PackedFloat32Array()
var _marca_dist := {}  # id -> distância andada desde a última marca
var _marca_ponto := {}  # id -> [esquerda, direita] da última marca (Vector3)
var _marcando := {}  # id -> está deixando marca (histerese)
const MARCA_SOLTA := 4.0  # m/s²: abaixo disso a marca termina

## Vácuo: o seu carro logo atrás de outro numa reta deixa ver o ar que ele
## empurra (rastros finos saindo da traseira do da frente).
const VACUO_MIN_M := 3.0
const VACUO_MAX_M := 14.0
const VACUO_LADO_M := 1.4
var _rastros := {}  # id -> CPUParticles3D
var _poeira := {}  # id -> CPUParticles3D: a terra levantada atrás de cada carro (época)
var _na_zebra := {}  # id -> rodas sobre a zebra (para o som)


## Para o som: o carro está cantando pneu (fumaça ou marca) / na zebra.
func cantando(id: String) -> bool:
	return bool(_marcando.get(id, false)) or bool(_fumaca.get(id, false))


func na_zebra(id: String) -> bool:
	return bool(_na_zebra.get(id, false))


func _criar_marcas() -> void:
	_marcas = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(MARCA_PASSO_M, 0.11)
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = MARCAS_MAX
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	_marcas.material_override = mat
	for k in MARCAS_MAX:
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(0, -10, 0)))
		mm.set_instance_color(k, Color(0, 0, 0, 0))
	_marcas.multimesh = mm
	_marca_t.resize(MARCAS_MAX)
	_marca_t.fill(-INF)
	_cena.add_child(_marcas)


## Traços das rodas de trás: um segmento do ponto da marca anterior até o
## atual, para a freada deixar um risco contínuo.
func _marcar(id: String, c: Node3D) -> void:
	if _marcas == null:
		_criar_marcas()
	var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(4.4, 1.75)
	var giro := Basis(Vector3.UP, c.rotation.y)
	var antes: Array = _marca_ponto.get(id, [])
	var agora := []
	for k in 2:
		var lado := -1.0 if k == 0 else 1.0
		var p := c.position + giro * (Vector3(-dim.x * 0.32, 0.0, lado * dim.y * 0.36) * c.scale.x) + Vector3(0, 0.03, 0)
		agora.append(p)
		if antes.size() == 2:
			var a: Vector3 = antes[k]
			var d := p - a
			var comp := d.length()
			if comp > 0.05 and comp < 4.0:
				var b := Basis(Vector3.UP, atan2(-d.z, d.x)) * Basis.from_scale(Vector3(comp / MARCA_PASSO_M, 1.0, 1.0))
				_marcas.multimesh.set_instance_transform(_marca_i, Transform3D(b, (a + p) * 0.5))
				_marca_t[_marca_i] = _tempo
				_marca_i = (_marca_i + 1) % MARCAS_MAX
	_marca_ponto[id] = agora


## Marcas somem com o tempo (só as que ainda aparecem são tocadas).
func _apagar_marcas() -> void:
	if _marcas == null:
		return
	for k in MARCAS_MAX:
		var idade := _tempo - _marca_t[k]
		if idade < 0.0 or idade > MARCA_DURA_S + 1.0:
			continue
		# Entra suave (não "pinta" de uma vez) e some devagar.
		var a := 0.2 * smoothstep(0.0, 0.25, idade) * (1.0 - smoothstep(MARCA_DURA_S * 0.3, MARCA_DURA_S, idade))
		_marcas.multimesh.set_instance_color(k, Color(0.05, 0.045, 0.04, a))


func _criar_rastro(id: String, c: Node3D) -> void:
	var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(4.4, 1.75)
	var f := CPUParticles3D.new()
	f.emitting = false
	f.amount = 18
	f.lifetime = 0.55
	f.local_coords = false
	f.direction = Vector3(-1, 0, 0)
	f.spread = 4.0
	f.initial_velocity_min = 2.0
	f.initial_velocity_max = 4.0
	f.gravity = Vector3.ZERO
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(0.1, 0.25, dim.y * 0.45)
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 0.06)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.render_priority = 2
	q.material = m
	f.mesh = q
	var cores := Gradient.new()
	cores.set_color(0, Color(1, 1, 1, 0.0))
	cores.add_point(0.25, Color(1, 1, 1, 0.32))
	cores.set_color(cores.get_point_count() - 1, Color(1, 1, 1, 0.0))
	f.color_ramp = cores
	f.position = Vector3(-dim.x * 0.5, 0.4, 0.0)
	c.add_child(f)
	_rastros[id] = f


## Liga o rastro do carro logo à frente do jogador quando ele está no vácuo
## (perto, quase na mesma linha, numa reta). Só visual.
func _vacuo(s: Dictionary) -> void:
	var frente := ""
	if not (Preferencias.efeitos_leves or Preferencias.reduzir_animacoes) and _carros.has("jogador") and chegada <= 0.0:
		var meu := float(s["jogador"])
		if absf(_tracado.curvatura(meu)) < 0.0015 and absf(_tracado.curvatura(meu + 30.0)) < 0.0015:
			for id in _carros:
				var gap := float(s[id]) - meu
				if id != "jogador" and gap > VACUO_MIN_M and gap < VACUO_MAX_M \
						and absf(float(_lateral[id]) - float(_lateral["jogador"])) < VACUO_LADO_M:
					frente = id
	if frente != "" and not _rastros.has(frente):
		_criar_rastro(frente, _carros[frente])
	for id in _rastros:
		_rastros[id].emitting = id == frente


## a: aceleração (m/s², negativa freando); v: velocidade (m/s).
func _efeitos_pista(id: String, a: float, v: float, delta: float) -> void:
	if not _luzes.has(id):
		return
	var marcando: bool = _marcando.get(id, false)
	marcando = -a > (MARCA_SOLTA if marcando else MARCA_FREADA) and v > 6.0 and not Preferencias.efeitos_leves \
			and chegada < 1.0 and _fonte.tempo > 3.0
	_marcando[id] = marcando
	if marcando:
		_marca_dist[id] = float(_marca_dist.get(id, 0.0)) + v * delta
		if float(_marca_dist[id]) >= MARCA_PASSO_M or not _marca_ponto.has(id):
			_marca_dist[id] = 0.0
			_marcar(id, _carros[id])
	else:
		_marca_ponto.erase(id)
	var aceso := float(_freio[id]) > 0.5
	var freando := -a > (FREIO_OFF if aceso else FREIO_ON) and v > 3.0 and chegada < 1.0
	_freio[id] = move_toward(float(_freio[id]), 1.0 if freando else 0.0, delta / (0.06 if freando else 0.25))
	var luz := float(_freio[id]) * 0.95
	if id == "jogador" and impulso > 0.0:
		luz = maxf(luz, impulso * (0.65 + 0.35 * sin(_tempo * 30.0)))
	(_luzes[id] as StandardMaterial3D).albedo_color.a = luz
	if epoca != "" and not Preferencias.reduzir_animacoes:
		_levantar_poeira(id, v)
	if _esteira.has(id):
		var forte := (-a > FUMACA_FREADA and v > 8.0) or (a > FUMACA_ARRANCADA and v < FUMACA_V_MAX and v > 0.5)
		_fumaca[id] = forte
		var alvo := 0.0
		if v > 3.0 and chegada < 1.0 and not Preferencias.reduzir_animacoes:
			alvo = 1.0 if forte else ESTEIRA_BASE
			if id == "jogador":
				alvo = maxf(alvo, impulso)
		# Sobe e desce devagar: sem degraus de densidade ao longo da fita.
		_intensidade[id] = move_toward(float(_intensidade.get(id, 0.0)), alvo, delta * (1.8 if alvo > float(_intensidade.get(id, 0.0)) else 0.9))
		_atualizar_esteira(id)


## Terra batida: uma nuvem baixa de poeira atrás de cada carro, mais densa
## quanto mais rápido (golpes visuais, 2026-10-28; Art of Rally).
func _levantar_poeira(id: String, v: float) -> void:
	if not _poeira.has(id):
		var c: Node3D = _carros[id]
		var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(4.4, 1.75)
		var p := CPUParticles3D.new()
		p.amount = 34
		p.lifetime = 1.8
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.3, 0.1, dim.y * 0.45)
		p.direction = Vector3(-1, 0.35, 0)
		p.spread = 35.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 2.0
		p.gravity = Vector3(0, 0.25, 0)
		p.damping_min = 0.8
		p.damping_max = 1.6
		var curva := Curve.new()
		curva.add_point(Vector2(0, 0.7))
		curva.add_point(Vector2(1, 3.4))
		p.scale_amount_curve = curva
		var esfera := SphereMesh.new()
		esfera.radius = 0.8
		esfera.height = 0.9
		esfera.radial_segments = 6
		esfera.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		esfera.material = m
		p.mesh = esfera
		var cores := Gradient.new()
		cores.set_color(0, Color(0.74, 0.62, 0.44, 0.22))
		cores.set_color(1, Color(0.78, 0.68, 0.52, 0.0))
		p.color_ramp = cores
		p.position = Vector3(-dim.x * 0.5, 0.2, 0.0)
		c.add_child(p)
		_poeira[id] = p
	var poeira: CPUParticles3D = _poeira[id]
	poeira.emitting = v > 4.0 and chegada < 1.0
	poeira.speed_scale = clampf(0.6 + v / 40.0, 0.6, 1.6)


func _faiscas(onde: Vector3, cor := Color(1.0, 0.35, 0.05), quantas := 28, forca := 1.0) -> void:
	if Preferencias.efeitos_leves:
		return
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.amount = quantas
	f.lifetime = 0.5
	f.explosiveness = 1.0
	f.direction = Vector3.UP
	f.spread = 75.0
	f.initial_velocity_min = 5.0 * forca
	f.initial_velocity_max = 13.0 * forca
	f.gravity = Vector3(0, -22, 0)
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.78, 0.35)
	m.vertex_color_use_as_albedo = true
	q.material = m
	f.mesh = q
	var cores := Gradient.new()
	cores.set_color(0, Color(1.0, 0.95, 0.7))
	cores.set_color(1, Color(cor, 0.0))
	f.color_ramp = cores
	f.position = onde
	_cena.add_child(f)
	f.emitting = true
	get_tree().create_timer(1.2).timeout.connect(f.queue_free)


## Afastamento de cada carro do seu traçado de corrida (base, m): o da frente
## fica no traçado; quem está a menos de PROXIMIDADE_M (na mesma volta ou não)
## de um carro já posicionado vai para a faixa livre mais perto da atual,
## preferindo o traçado (0) e, entre as outras, o lado de dentro da próxima
## curva (ataque: +1 esquerda, -1 direita). Livre = a posição final (base +
## faixa, dentro da pista) a 2,2 m ou mais dos vizinhos.
static func faixas(ordem: Array, s: Dictionary, atual: Dictionary, comprimento: float,
		base: Dictionary = {}, ataque: Dictionary = {}) -> Dictionary:
	var r := {}
	var pos := {}
	for id in ordem:
		var b: float = base.get(id, 0.0)
		var a: float = atual.get(id, 0.0)
		var lado: float = ataque.get(id, 0.0)
		var cands: Array = FAIXAS_M.slice(1)
		cands.sort_custom(func(x, y):
			return absf(x - a) + (0.6 if signf(x) != lado else 0.0) < absf(y - a) + (0.6 if signf(y) != lado else 0.0))
		cands.push_front(0.0)
		var escolhida: float = cands[0]
		for f in cands:
			var lat := clampf(b + f, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
			var livre := true
			for outro in r:
				if _perto(s[id], s[outro], comprimento, PROXIMIDADE_M) and absf(lat - pos[outro]) < 2.2:
					livre = false
					break
			if livre:
				escolhida = f
				break
		r[id] = escolhida
		pos[id] = clampf(b + escolhida, -Tracado.TANGENCIA_M, Tracado.TANGENCIA_M)
	return r


## Pares de carros que se tocam agora: sobrepostos no comprido e no lado.
static func contatos(ordem: Array, s: Dictionary, lateral: Dictionary, comprimento: float) -> Array:
	var r := []
	for i in ordem.size():
		for j in range(i + 1, ordem.size()):
			var a: String = ordem[i]
			var b: String = ordem[j]
			if _perto(s[a], s[b], comprimento, 4.0) and absf(float(lateral[a]) - float(lateral[b])) < 1.85:
				r.append([a, b])
	return r


static func _perto(sa: float, sb: float, comprimento: float, limite: float) -> bool:
	var d := fposmod(sa - sb, comprimento)
	return minf(d, comprimento - d) < limite


func _construir_pista() -> void:
	var pts := _pista.pontos(3.0)
	var caixa := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(p)
	# Enquadramento da visão geral: extensão do traçado na projeção da câmera
	# (a mesma do minimapa) e a proporção da tela.
	var proj := Rect2(Iso.para_tela(pts[0], 1.0), Vector2.ZERO)
	for p in pts:
		proj = proj.expand(Iso.para_tela(p, 1.0))
	_proj = proj
	_enquadrar_geral()
	var c_tela := proj.get_center()
	# Inverso de Iso.para_tela: x + y = cx, x - y = cy.
	var meio := Vector2((c_tela.x + c_tela.y) * 0.5, (c_tela.x - c_tela.y) * 0.5)
	_centro_pista = Vector3(meio.x, 0.0, -meio.y)
	var tema: Dictionary = TEMAS.get(TEMA_DE.get(_pista.id, _pista.id), TEMA_PADRAO)
	_ambiente.background_color = tema["ceu"]
	_ambiente.ambient_light_color = tema["ambiente"]
	_ambiente.fog_enabled = tema["neblina"] > 0.0 and not Preferencias.efeitos_leves
	_ambiente.fog_density = tema["neblina"]
	_ambiente.fog_light_color = tema["ceu"]
	_luz.light_color = tema["luz"]
	_luz.light_energy = tema["energia"]
	_luz.rotation = tema["sol"]
	_cores_muro = tema["muro"]
	var efeito_tela := material as ShaderMaterial
	efeito_tela.set_shader_parameter("filme", 0.0)
	efeito_tela.set_shader_parameter("grao", 0.0)
	efeito_tela.set_shader_parameter("tilt", 0.0)
	if epoca != "":
		CenarioEpoca.montar(_cena, _pista, LARGURA_PISTA_M, _ambiente, _luz)
		# Golpes visuais (2026-10-28): filme de 1937, grão e tilt-shift (a
		# pista em maquete), baratos o bastante para os efeitos leves; o grão
		# para com "reduzir animações".
		efeito_vinheta(0.32)
		efeito_tela.set_shader_parameter("filme", 1.0)
		efeito_tela.set_shader_parameter("grao", 0.0 if Preferencias.reduzir_animacoes else 1.0)
		efeito_tela.set_shader_parameter("tilt", 1.0)
		_marcadores()
		return
	var montado: Dictionary = KITS.get(TEMA_DE.get(_pista.id, _pista.id), {}).duplicate()
	if estilo_forcado != "" and not montado.is_empty():
		montado["estilo"] = estilo_forcado
	var efeito := material as ShaderMaterial
	if not montado.is_empty() and MontadorPista.disponivel():
		# Cenário pelo kit de arte; os anéis, a linha de largada e os muros seguem daqui.
		var montador: MontadorPista = MontadorChapado.new() if montado.get("estilo", "") == "chapado" else MontadorPista.new()
		montador.montar(_cena, _pista, montado, LARGURA_PISTA_M)
		_ambiente.background_color = montado.get("fundo", tema["ceu"])
		efeito.set_shader_parameter("vinheta", float(montado.get("vinheta", 0.0)))
		_marcadores()
		return
	efeito.set_shader_parameter("vinheta", 0.0)
	var grama := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = caixa.size + Vector2(8000, 8000)
	grama.mesh = plano
	grama.material_override = CarroBloco._material(tema["chao"])
	var centro := caixa.get_center()
	grama.position = Vector3(centro.x, -0.06, -centro.y)
	_cena.add_child(grama)
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M + 6.0, -0.04, tema["chao"].darkened(0.25)))  # área de escape
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M, 0.0, tema["asfalto"]))
	_cena.add_child(_zebras())
	for lado in [1.0, -1.0]:
		_cena.add_child(_muro(pts, lado * (LARGURA_PISTA_M * 0.5 + 3.4)))
	_marcadores()
	_arquibancada()
	_portico()
	_bordas()
	_placas_curva()
	_decorar(pts, tema["props"])
	_fundo(caixa, tema)


## Anéis do jogador e do alvo, traço de disputa e linha de largada.
## Clarão branco-quente na tela (ultrapassagem, bandeirada), que some sozinho.
func clarao(forca := 0.6) -> void:
	if Preferencias.reduzir_animacoes:
		return
	var m := material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("clarao", v), forca, 0.0, 0.35)


## Câmera tremendo por `s` segundos (contato, momentos fortes).
func tremer(s := 0.25) -> void:
	_tremor = maxf(_tremor, s)


func efeito_vinheta(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("vinheta", v)


func _marcadores() -> void:
	_anel_alvo = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.6
	tor.outer_radius = 3.1
	tor.rings = 32  # a padrão (64 × 32) tem 4 mil triângulos num anel fino
	tor.ring_segments = 6
	_anel_alvo.mesh = tor
	var mat_alvo := CarroBloco._material(Color(1.0, 0.3, 0.25))
	mat_alvo.emission_enabled = true
	mat_alvo.emission = Color(1.0, 0.2, 0.15) * 0.7
	_anel_alvo.material_override = mat_alvo
	_anel_alvo.visible = false
	_cena.add_child(_anel_alvo)
	_anel_jogador = MeshInstance3D.new()
	var tor_j := TorusMesh.new()
	tor_j.inner_radius = 2.5
	tor_j.outer_radius = 2.9
	tor_j.rings = 32
	tor_j.ring_segments = 6
	_anel_jogador.mesh = tor_j
	var mat_j := CarroBloco._material(Aba.COR_DESTAQUE)
	mat_j.emission_enabled = true
	mat_j.emission = Aba.COR_DESTAQUE * 0.6
	mat_j.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_anel_jogador.material_override = mat_j
	_anel_jogador.visible = false
	_cena.add_child(_anel_jogador)
	_onda = MeshInstance3D.new()
	var tor_o := TorusMesh.new()
	tor_o.inner_radius = 2.6
	tor_o.outer_radius = 3.0
	tor_o.rings = 32
	tor_o.ring_segments = 6
	_onda.mesh = tor_o
	var mat_o := StandardMaterial3D.new()
	mat_o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_o.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_onda.material_override = mat_o
	_onda.visible = false
	_t_onda = -1.0
	_cena.add_child(_onda)
	_traco = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.04, 0.35)
	_traco.mesh = bm
	var mat_t := CarroBloco._material(Color(1.0, 0.55, 0.2))
	mat_t.emission_enabled = true
	mat_t.emission = Color(1.0, 0.5, 0.15) * 0.7
	_traco.material_override = mat_t
	_traco.visible = false
	_cena.add_child(_traco)
	# Linha de chegada: faixa quadriculada pintada de borda a borda da pista.
	var p0 := _pista.posicao_em(LINHA_CHEGADA_M)
	var rumo := _pista.rumo_em(LINHA_CHEGADA_M)
	var frente := Vector2.from_angle(rumo)
	var lado := Vector2.from_angle(rumo + PI / 2.0)
	var colunas := int(round(LARGURA_PISTA_M / XADREZ_M))
	for linha in 2:
		for k in colunas:
			var q: Vector2 = p0 + frente * ((linha - 0.5) * XADREZ_M) \
					+ lado * ((k + 0.5) * XADREZ_M - LARGURA_PISTA_M * 0.5)
			var quadro := _bloco(Vector3(XADREZ_M, 0.02, XADREZ_M),
					Color(0.94, 0.94, 0.92) if (k + linha) % 2 == 0 else Color(0.07, 0.07, 0.08))
			quadro.position = Vector3(q.x, 0.012, -q.y)
			quadro.rotation.y = rumo
			_cena.add_child(quadro)


## Grid de largada: uma vaga por carro onde a simulação o põe (s = -g ·
## distancia_minima_m), em lados alternados como num grid de verdade; cada
## vaga é um colchete branco pintado (traço na frente e dois para trás).
func _grid() -> void:
	_vagas = {}
	var ordem := _fonte.ordem()
	for g in ordem.size():
		var id: String = ordem[g]
		var s0 := _fonte.distancia_em(id, 0.0)
		var lateral := GRID_LADO_M if g % 2 == 0 else -GRID_LADO_M
		_vagas[id] = {"s": s0, "lateral": lateral}
		var sv := fposmod(s0, _pista.comprimento)
		var rumo := _pista.rumo_em(sv)
		var frente := Vector2.from_angle(rumo)
		var lado := Vector2.from_angle(rumo + PI / 2.0)
		var centro := _pista.posicao_em(sv) + lado * lateral
		var bico := centro + frente * 2.7  # à frente do carro (que tem ~4,3 m)
		var tracos := [
			[bico, Vector3(VAGA_TRACO_M, 0.02, VAGA_LARGURA_M)],
			[bico - frente * (VAGA_FUNDO_M * 0.5) + lado * (VAGA_LARGURA_M * 0.5 - VAGA_TRACO_M * 0.5),
					Vector3(VAGA_FUNDO_M, 0.02, VAGA_TRACO_M)],
			[bico - frente * (VAGA_FUNDO_M * 0.5) - lado * (VAGA_LARGURA_M * 0.5 - VAGA_TRACO_M * 0.5),
					Vector3(VAGA_FUNDO_M, 0.02, VAGA_TRACO_M)],
		]
		for t in tracos:
			var b := _bloco(t[1], Color(0.92, 0.92, 0.9))
			b.position = Vector3(t[0].x, 0.012, -t[0].y)
			b.rotation.y = rumo
			_cena.add_child(b)


## Pórtico de largada e chegada sobre a pista, com faixa quadriculada.
func _portico() -> void:
	var p0 := _pista.posicao_em(PORTICO_M)
	var rumo := _pista.rumo_em(PORTICO_M)
	var lado := Vector2.from_angle(rumo + PI / 2.0)

	for k in [-1.0, 1.0]:
		var q: Vector2 = p0 + lado * k * (LARGURA_PISTA_M * 0.5 + 1.6)
		var poste := _bloco(Vector3(0.6, 7.5, 0.6), Color(0.3, 0.31, 0.34))
		poste.position = Vector3(q.x, 3.75, -q.y)
		_cena.add_child(poste)
	var quadros := 12
	for k in quadros:
		var t := (float(k) + 0.5) / quadros * 2.0 - 1.0
		var q := p0 + lado * t * (LARGURA_PISTA_M * 0.5 + 1.6)
		var quadro := _bloco(Vector3(0.4, 1.4, (LARGURA_PISTA_M + 3.2) / quadros),
				Color.WHITE if k % 2 == 0 else Color(0.08, 0.08, 0.09))
		quadro.position = Vector3(q.x, 7.0, -q.y)
		quadro.rotation.y = rumo
		_cena.add_child(quadro)


## Bordas: brita e pneus empilhados por fora das curvas; placas nas retas.
func _bordas() -> void:
	var brita := SurfaceTool.new()
	brita.begin(Mesh.PRIMITIVE_TRIANGLES)
	brita.set_normal(Vector3.UP)
	var pneus := []
	var placas := 0
	var s := 0.0
	var passo := 4.0
	while s < _pista.comprimento:
		var t := _pista.trecho_em(s)
		var raio := float(t.get("raio_m", 0.0))
		var rumo := _pista.rumo_em(s)
		var p := _pista.posicao_em(s)
		if raio > 0.0:
			# Por fora da curva: o lado oposto ao sentido dela.
			var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
			var n := Vector2.from_angle(rumo + PI / 2.0) * fora
			var n2 := Vector2.from_angle(_pista.rumo_em(s + passo) + PI / 2.0) * fora
			var p2 := _pista.posicao_em(s + passo)
			var q := [p + n * (LARGURA_PISTA_M * 0.5 + 1.2), p + n * (LARGURA_PISTA_M * 0.5 + 3.3),
					p2 + n2 * (LARGURA_PISTA_M * 0.5 + 1.2), p2 + n2 * (LARGURA_PISTA_M * 0.5 + 3.3)]
			for idx in [0, 2, 1, 1, 2, 3]:
				brita.add_vertex(Vector3(q[idx].x, 0.015, -q[idx].y))
			pneus.append(p + n * (LARGURA_PISTA_M * 0.5 + 2.8))
		elif placas < 24 and fposmod(s, 140.0) < passo:
			var lado := 1.0 if int(s / 140.0) % 2 == 0 else -1.0
			var q := p + Vector2.from_angle(rumo + PI / 2.0) * lado * (LARGURA_PISTA_M * 0.5 + 5.5)
			var cores := [Color(0.85, 0.15, 0.15), Color(0.15, 0.4, 0.85), Color(0.95, 0.75, 0.1), Color(0.15, 0.6, 0.35)]
			var placa := _bloco(Vector3(0.3, 2.2, 8.0), cores[placas % cores.size()])
			placa.position = Vector3(q.x, 1.6, -q.y)
			placa.rotation.y = rumo + PI / 2.0
			_cena.add_child(placa)
			var faixa := _bloco(Vector3(0.32, 0.4, 8.0), Color.WHITE)
			faixa.position = Vector3(q.x, 1.6, -q.y)
			faixa.rotation.y = rumo + PI / 2.0
			_cena.add_child(faixa)
			placas += 1
		s += passo
	var mb := MeshInstance3D.new()
	mb.mesh = brita.commit()
	var mat_b := CarroBloco._material(Color(0.72, 0.66, 0.52))
	mat_b.cull_mode = BaseMaterial3D.CULL_DISABLED
	mb.material_override = mat_b
	_cena.add_child(mb)
	# Pneus em MultiMesh: muitos objetos iguais, um só desenho.
	if not pneus.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cil := CylinderMesh.new()
		cil.top_radius = 0.45
		cil.bottom_radius = 0.45
		cil.height = 0.9
		cil.radial_segments = 8
		# Uma faixa só e sem a tampa de baixo (no chão, nunca aparece).
		cil.rings = 0
		cil.cap_bottom = false
		mm.mesh = cil
		mm.instance_count = pneus.size()
		for i in pneus.size():
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(pneus[i].x, 0.45, -pneus[i].y)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = CarroBloco._material(Color(0.1, 0.1, 0.11))
		_cena.add_child(mmi)


## Arquibancada ao lado da largada: referência para saber onde a volta começa.
func _arquibancada() -> void:
	var cores := [Color(0.75, 0.2, 0.2), Color(0.2, 0.4, 0.75), Color(0.85, 0.65, 0.15)]
	for k in 3:
		var s0 := -45.0 + k * 34.0
		var p0 := _pista.posicao_em(s0)
		var rumo := _pista.rumo_em(s0)
		var lado := Vector2.from_angle(rumo + PI / 2.0)
		var base := p0 + lado * (LARGURA_PISTA_M * 0.5 + 8.0)
		for degrau in 4:
			var b := _bloco(Vector3(30.0, 1.2, 3.0), cores[k] if degrau % 2 == 0 else Color(0.85, 0.85, 0.87))
			var q := base + lado * (degrau * 3.0)
			b.position = Vector3(q.x, 0.6 + degrau * 1.2, -q.y)
			b.rotation.y = rumo
			_cena.add_child(b)
		var cobertura := _bloco(Vector3(31.0, 0.3, 13.0), Color(0.88, 0.88, 0.9))
		var qc := base + lado * 4.5
		cobertura.position = Vector3(qc.x, 7.6, -qc.y)
		cobertura.rotation.y = rumo
		_cena.add_child(cobertura)
	# Prédio dos boxes do outro lado, com portas escuras.
	var pb := _pista.posicao_em(0.0)
	var rb := _pista.rumo_em(0.0)
	var outro := Vector2.from_angle(rb - PI / 2.0)
	var qb := pb + outro * (LARGURA_PISTA_M * 0.5 + 10.0)
	var predio := _bloco(Vector3(70.0, 5.0, 8.0), Color(0.82, 0.83, 0.86))
	predio.position = Vector3(qb.x, 2.5, -qb.y)
	predio.rotation.y = rb
	_cena.add_child(predio)
	for k in 8:
		var qp := pb + Vector2.from_angle(rb) * (-30.0 + k * 8.5) + outro * (LARGURA_PISTA_M * 0.5 + 5.95)
		var porta := _bloco(Vector3(6.0, 3.6, 0.1), Color(0.15, 0.16, 0.18))
		porta.position = Vector3(qp.x, 1.8, -qp.y)
		porta.rotation.y = rb
		_cena.add_child(porta)


## Placas de 100 e 50 m antes de cada curva, por fora: o piloto (e quem
## assiste) sabe que vem freada.
func _placas_curva() -> void:
	for i in _pista.trechos.size():
		var t: Dictionary = _pista.trechos[i]
		var anterior: Dictionary = _pista.trechos[i - 1]
		if float(t.get("raio_m", 0.0)) <= 0.0 or float(anterior.get("raio_m", 0.0)) > 0.0:
			continue
		var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
		for d in [100.0, 50.0]:
			var s: float = float(_pista.inicios[i]) - d
			var p := _pista.posicao_em(s) + Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0) * fora * (LARGURA_PISTA_M * 0.5 + 2.4)
			var placa := _bloco(Vector3(0.15, 1.3, 1.0), Color.WHITE)
			placa.position = Vector3(p.x, 1.0, -p.y)
			placa.rotation.y = _pista.rumo_em(s)
			_cena.add_child(placa)
			for k in int(d / 50.0):
				var faixa := _bloco(Vector3(0.17, 0.16, 1.02), Color(0.1, 0.1, 0.12))
				faixa.position = Vector3(p.x, 0.65 + k * 0.4, -p.y)
				faixa.rotation.y = _pista.rumo_em(s)
				_cena.add_child(faixa)


## Cenário de fundo, fora do traçado: colinas (vale), água, guindastes e
## postes (porto), picos nevados (serra).
func _fundo(caixa: Rect2, tema: Dictionary) -> void:
	var centro := caixa.get_center()
	var raio := caixa.size.length() * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_pista.id + "fundo")
	match tema["fundo"]:
		"colinas":
			for k in 14:
				var ang := TAU * k / 14.0 + rng.randf() * 0.3
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(80.0, 160.0))
				var colina := MeshInstance3D.new()
				var esf := SphereMesh.new()
				var r := rng.randf_range(50.0, 90.0)
				esf.radius = r
				esf.height = r * 0.7
				esf.radial_segments = 12
				esf.rings = 6
				colina.mesh = esf
				colina.material_override = CarroBloco._material(tema["chao"].lightened(rng.randf_range(0.04, 0.14)))
				colina.position = Vector3(p.x, -r * 0.12, -p.y)
				_cena.add_child(colina)
		"porto":
			# Água de um lado e guindastes na borda.
			var agua := MeshInstance3D.new()
			var plano := PlaneMesh.new()
			plano.size = Vector2(caixa.size.x + 600.0, 400.0)
			agua.mesh = plano
			var mat := CarroBloco._material(Color(0.12, 0.3, 0.45))
			mat.roughness = 0.2
			agua.material_override = mat
			agua.position = Vector3(centro.x, -0.05, -(caixa.position.y - 230.0))
			_cena.add_child(agua)
			for k in 5:
				var x := caixa.position.x + caixa.size.x * (k + 0.5) / 5.0
				var base := Vector3(x, 0.0, -(caixa.position.y - 40.0))
				var torre := _bloco(Vector3(3.0, 34.0, 3.0), Color(0.9, 0.55, 0.15))
				torre.position = base + Vector3(0, 17.0, 0)
				_cena.add_child(torre)
				var braco := _bloco(Vector3(3.0, 2.5, 36.0), Color(0.9, 0.55, 0.15))
				braco.position = base + Vector3(0, 33.0, 10.0)
				_cena.add_child(braco)
			var luz_poste := CarroBloco._material(Color(1.0, 0.85, 0.5))
			luz_poste.emission_enabled = true
			luz_poste.emission = Color(1.0, 0.8, 0.4)
			var s := 0.0
			while s < _pista.comprimento:
				var p := _pista.posicao_em(s) + Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0) * (LARGURA_PISTA_M * 0.5 + 5.0)
				var poste := _bloco(Vector3(0.3, 7.0, 0.3), Color(0.25, 0.25, 0.28))
				poste.position = Vector3(p.x, 3.5, -p.y)
				_cena.add_child(poste)
				var lampada := _bloco(Vector3(0.9, 0.35, 0.9), Color.WHITE)
				lampada.material_override = luz_poste
				lampada.position = Vector3(p.x, 7.1, -p.y)
				_cena.add_child(lampada)
				s += 70.0
		"mesas":
			# Mesas de topo plano ao longe, cor de rocha avermelhada.
			for k in 8:
				var ang := TAU * k / 8.0 + rng.randf() * 0.5
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(180.0, 320.0))
				var h := rng.randf_range(40.0, 90.0)
				var mesa := MeshInstance3D.new()
				var cil := CylinderMesh.new()
				cil.bottom_radius = rng.randf_range(90.0, 160.0)
				cil.top_radius = cil.bottom_radius * 0.75
				cil.height = h
				cil.radial_segments = 8
				cil.rings = 1
				mesa.mesh = cil
				mesa.material_override = CarroBloco._material(Color(0.7, 0.45, 0.32).lerp(Color(0.62, 0.58, 0.62), 0.35))
				mesa.position = Vector3(p.x, h * 0.5 - 2.0, -p.y)
				_cena.add_child(mesa)
		"montanhas":
			for k in 9:
				var ang := TAU * k / 9.0 + rng.randf() * 0.4
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(160.0, 260.0))
				var h := rng.randf_range(120.0, 200.0)
				var monte := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = h * 0.9
				cone.height = h
				cone.radial_segments = 7
				cone.rings = 1
				monte.mesh = cone
				monte.material_override = CarroBloco._material(Color(0.48, 0.53, 0.6))  # azulado: distância
				monte.position = Vector3(p.x, h * 0.5 - 2.0, -p.y)
				_cena.add_child(monte)
				var neve := MeshInstance3D.new()
				var topo := CylinderMesh.new()
				topo.top_radius = 0.0
				topo.bottom_radius = h * 0.9 * 0.3
				topo.height = h * 0.3
				topo.radial_segments = 7
				topo.rings = 1
				neve.mesh = topo
				neve.material_override = CarroBloco._material(Color(0.95, 0.96, 1.0))
				neve.position = Vector3(p.x, h - 2.0 - h * 0.15 + 0.5, -p.y)
				_cena.add_child(neve)


## Objetos em volta da pista, longe do asfalto, sempre no mesmo lugar para a
## mesma pista (semente pelo id).
func _decorar(pts: PackedVector2Array, tipo: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_pista.id)
	var amostra := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		amostra.append(pts[i])
	var colocados := 0
	for tentativa in 800:
		if colocados >= maxi(110, int(_pista.comprimento / 25.0)):
			break
		var s := rng.randf() * _pista.comprimento
		var rumo := _pista.rumo_em(s)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var dist := rng.randf_range(16.0, 70.0)
		var p := _pista.posicao_em(s) + Vector2.from_angle(rumo + PI / 2.0) * lado * dist
		var livre := true
		for q in amostra:
			if p.distance_squared_to(q) < 14.0 * 14.0:
				livre = false
				break
		if not livre:
			continue
		colocados += 1
		var n := _objeto(tipo, rng, dist)
		n.position.x = p.x
		n.position.z = -p.y
		n.rotation.y = rng.randf() * TAU
		_cena.add_child(n)


func _objeto(tipo: String, rng: RandomNumberGenerator, dist: float) -> Node3D:
	match tipo:
		"cidade":
			# Perto da pista só contêineres baixos: prédio alto ali tapa a corrida.
			if rng.randf() < 0.35 or dist < 40.0:
				var cont := _bloco(Vector3(6.0, 2.6, 2.4), [Color(0.8, 0.3, 0.2), Color(0.2, 0.45, 0.7), Color(0.85, 0.65, 0.2)][rng.randi() % 3])
				cont.position.y = 1.3
				return cont
			var h := rng.randf_range(6.0, 22.0)
			var predio := _bloco(Vector3(rng.randf_range(8.0, 14.0), h, rng.randf_range(8.0, 14.0)),
					Color(0.5, 0.52, 0.56).lerp(Color(0.7, 0.62, 0.52), rng.randf()))
			predio.position.y = h * 0.5
			return predio
		"deserto":
			# Placas de distância (marcas brancas) e pedras baixas: nada alto perto
			# das retas, que são o assunto da pista.
			if rng.randf() < 0.3 and dist < 40.0:
				var placa := _bloco(Vector3(0.3, 2.4, 1.6), Color(0.95, 0.95, 0.95))
				placa.position.y = 1.2
				return placa
			var rocha := _bloco(Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(0.6, 1.8), rng.randf_range(1.5, 4.0)),
					Color(0.6, 0.48, 0.36).darkened(rng.randf_range(0.0, 0.2)))
			rocha.position.y = 0.4
			return rocha
		"serra":
			if rng.randf() < 0.4:
				var pedra := _bloco(Vector3.ONE * rng.randf_range(2.0, 5.0), Color(0.45, 0.43, 0.4))
				pedra.position.y = 0.8
				return pedra
			return _arvore(rng, Color(0.16, 0.32, 0.2), 1.3)
	if rng.randf() < 0.35:
		var arbusto := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = rng.randf_range(1.2, 2.2)
		esf.height = esf.radius * 1.3
		esf.radial_segments = 8
		esf.rings = 4
		arbusto.mesh = esf
		arbusto.material_override = CarroBloco._material(Color(0.22, 0.45, 0.2).darkened(rng.randf_range(0.0, 0.25)))
		arbusto.position.y = esf.height * 0.4
		return arbusto
	return _arvore(rng, Color(0.2, 0.5, 0.25), 1.0)


func _arvore(rng: RandomNumberGenerator, cor: Color, alongar: float) -> Node3D:
	var n := Node3D.new()
	var tronco := _bloco(Vector3(0.6, 2.0, 0.6), Color(0.4, 0.28, 0.18))
	tronco.position.y = 1.0
	n.add_child(tronco)
	var copa := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = rng.randf_range(2.0, 3.2)
	cone.height = rng.randf_range(5.0, 8.0) * alongar
	cone.radial_segments = 7
	cone.rings = 1
	copa.mesh = cone
	copa.material_override = CarroBloco._material(cor)
	copa.position.y = 2.0 + cone.height * 0.5
	n.add_child(copa)
	return n


static func _bloco(tam: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = CarroBloco._material(cor)
	return mi


## Visão geral: o traçado inteiro cabe na tela, qualquer que seja o tamanho
## dela agora (recalculado: a tela pode ter mudado desde a montagem).
func _enquadrar_geral() -> void:
	var aspecto := size.x / size.y if size.y > 1.0 else 1.2
	_tamanho_geral = maxf(_proj.size.y, _proj.size.x / aspecto) / sqrt(2.0) * 1.12 + 24.0


## Zebras vermelhas e brancas nas bordas das curvas.
func _zebras() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var passo := 3.0
	var s := 0.0
	var k := 0
	while s < _pista.comprimento:
		if float(_pista.trecho_em(s).get("raio_m", 0.0)) > 0.0:
			var cor := Color(0.85, 0.12, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.95)
			for lado in [1.0, -1.0]:
				var q := []
				for ss in [s, s + passo]:
					var p := _pista.posicao_em(ss)
					var n: Vector2 = Vector2.from_angle(_pista.rumo_em(ss) + PI / 2.0) * lado
					q.append(p + n * (LARGURA_PISTA_M * 0.5))
					q.append(p + n * (LARGURA_PISTA_M * 0.5 + 1.2))
				var v := q.map(func(p): return Vector3(p.x, 0.02, -p.y))
				for idx in [0, 2, 1, 1, 2, 3]:
					st.set_color(cor)
					st.add_vertex(v[idx])
		s += passo
		k += 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## Muro baixo ao longo da pista, a `deslocamento` m do eixo (lado pelo sinal).
func _muro(pts: PackedVector2Array, deslocamento: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_pts := pts.size()
	for i in n_pts - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var na := (pts[mini(i + 1, n_pts - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var nb := (pts[mini(i + 2, n_pts - 1)] - pts[i]).normalized().orthogonal()
		var pa := a - na * deslocamento
		var pb := b - nb * deslocamento
		var cor: Color = _cores_muro[(i / 4) % 2]
		var v := [Vector3(pa.x, 0.0, -pa.y), Vector3(pb.x, 0.0, -pb.y), Vector3(pb.x, 0.9, -pb.y), Vector3(pa.x, 0.9, -pa.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(cor)
			st.add_vertex(v[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


static func _faixa(pts: PackedVector2Array, largura: float, y: float, cor: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := pts.size()
	var bordas := []
	for i in n:
		var antes := pts[maxi(i - 1, 0)]
		var depois := pts[mini(i + 1, n - 1)]
		var normal := (depois - antes).normalized().orthogonal() * largura * 0.5
		bordas.append([pts[i] + normal, pts[i] - normal])
	for i in n - 1:
		var a: Array = bordas[i]
		var b: Array = bordas[i + 1]
		var v := [a[0], a[1], b[0], b[1]].map(func(p): return Vector3(p.x, y, -p.y))
		for idx in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(v[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := CarroBloco._material(cor)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## Deixas pintadas no asfalto (decisão 131): faixas de lado a lado da pista,
## `lista` = [[de_m, ate_m, Color], ...] em distância da corrida. Só refaz a
## malha quando a lista muda; [] apaga.
var _deixas_mi: MeshInstance3D
var _deixas_chave := ""
func deixas(lista: Array) -> void:
	if _pista == null:
		return
	var chave := str(lista.map(func(f): return [roundi(float(f[0]) * 4.0), roundi(float(f[1]) * 4.0), f[2]]))
	if chave == _deixas_chave and (lista.is_empty() or is_instance_valid(_deixas_mi)):
		return
	_deixas_chave = chave
	if is_instance_valid(_deixas_mi):
		_deixas_mi.queue_free()
	_deixas_mi = null
	if lista.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meia := LARGURA_PISTA_M * 0.5 - 0.3
	for f in lista:
		var s0 := float(f[0])
		var s1 := float(f[1])
		var n := maxi(int((s1 - s0) / 1.0), 1)
		var antes := []
		for k in n + 1:
			var sk := lerpf(s0, s1, float(k) / n)
			var c := _pista.posicao_em(sk)
			var nrm := Vector2.from_angle(_pista.rumo_em(sk) + PI / 2.0)
			var chao := 0.07 + (_relevo.altura(sk) if _relevo != null and not _relevo.vazio() else 0.0)
			var pts := []
			for lat in [meia, -meia]:
				var p: Vector2 = c + nrm * float(lat)
				pts.append(Vector3(p.x, chao + _altura_banco(sk, lat), -p.y))
			if not antes.is_empty():
				st.set_color(f[2])
				for v in [antes[0], antes[1], pts[1], antes[0], pts[1], pts[0]]:
					st.add_vertex(v)
			antes = pts
	_deixas_mi = MeshInstance3D.new()
	_deixas_mi.mesh = st.commit()
	_deixas_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_deixas_mi.material_override = mat
	_cena.add_child(_deixas_mi)


## Setas no chão ao lado do seu carro (o deslize): `lado` -1 esquerda da tela,
## 1 direita; 0 apaga. Pulsam e andam para o lado indicado.
var _seta: MeshInstance3D
const SETA_M := 2.4
func seta(lado: int) -> void:
	if _seta == null or not is_instance_valid(_seta):
		_seta = _malha_seta()
		_cena.add_child(_seta)
	_seta.visible = lado != 0 and _carros.has("jogador") and _pista != null and not visao_geral
	if not _seta.visible:
		return
	var dist := _fonte.distancia("jogador")
	var rumo := _pista.rumo_em(dist)
	# lado da tela → lateral da pista (+ = esquerda do carro): a tela olha por trás.
	var lat := -float(lado)
	var onda := fposmod(_tempo * 1.6, 1.0)
	var c: Vector3 = _carros["jogador"].position
	var nrm := Vector2.from_angle(rumo + PI / 2.0) * lat * (SETA_M + onda * 1.2)
	_seta.position = Vector3(c.x + nrm.x, c.y + 0.1, c.z - nrm.y)
	# A malha aponta para +X local; gira para a normal do lado indicado.
	_seta.rotation = Vector3(0, rumo + PI / 2.0 * lat, 0)
	(_seta.material_override as StandardMaterial3D).albedo_color.a = 0.95 - onda * 0.5


func _malha_seta() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Três chevrons em fila apontando para +X (no plano do chão).
	for k in 3:
		var x0 := float(k) * 0.9
		var a := Vector3(x0, 0, -1.1)
		var b := Vector3(x0 + 0.9, 0, 0)
		var c := Vector3(x0, 0, 1.1)
		var w := 0.45
		for v in [a, b, a + Vector3(-w, 0, 0), b, b + Vector3(-w, 0, 0), a + Vector3(-w, 0, 0),
				b, c, b + Vector3(-w, 0, 0), c, c + Vector3(-w, 0, 0), b + Vector3(-w, 0, 0)]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mi.material_override = mat
	mi.visible = false
	return mi
