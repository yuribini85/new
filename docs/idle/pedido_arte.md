# The Fastfather — pedido de arte (2026-10-28)

Estilo de tudo: o da pasta `arte/fastfather/` (anos 30, sépia/carvão, traço de quadrinho). Basta salvar o
arquivo com o nome indicado na pasta indicada: o jogo passa a usar sozinho, sem mudar código.

## 1. Fotos das pistas (13)

Pasta `arte/fastfather/pistas/`, **1200×500 webp**, nome `banner_<id>.webp`. Aparecem no cabeçalho e na
lista de PISTAS, na faixa da corrida e na foto do jornal (em sépia). A versão "(curto)" usa a mesma foto.
O texto da tela fica por cima no canto inferior esquerdo: deixe essa área mais calma.

| Arquivo | Nome na tela | Categoria | Sugestão de cena (anos 30, EUA) |
|---|---|---|---|
| `banner_parque_das_docas` | Cais Velho | Corridas de Bairro, Circuito Clandestino | cais com guindastes, armazéns de tijolo, paralelepípedo molhado |
| `banner_serra_alta` | Alto da Capela | Corridas de Bairro, Stock Cars | estrada de serra com uma capela branca no alto |
| `banner_anel_do_vale` | Lago Sereno | Corridas de Bairro, Liga dos Hot Rods | oval de terra à beira de um lago, arquibancada de madeira |
| `banner_circuito_misto` | Colinas do Vinhedo | Circuito Clandestino | estradas entre vinhedos e casas de fazenda |
| `banner_mirante_da_costa` | Mirante da Costa | Circuito Clandestino | estrada no penhasco sobre o mar, farol |
| `banner_avenida_noturna` | Avenida das Luzes | Liga dos Hot Rods | avenida da cidade à noite, letreiros de neon, bondes |
| `banner_oval_inclinado` | Oval da Usina | Liga dos Hot Rods | oval inclinado de tábuas ao lado de uma usina com chaminés |
| `banner_trilha_do_canion` | Trilha do Cânion | Stock Cars | estrada de terra no cânion vermelho |
| `banner_estrada_das_araucarias` | Estrada dos Pinheiros | Stock Cars | estrada de terra num pinheiral |
| `banner_arena_patio_pedreira` | Pátio da Pedreira | Rinha das Famílias | fundo de pedreira, paredes de rocha cortada, guindaste de madeira |
| `banner_arena_fosso_docas` | Fosso das Docas | Rinha das Famílias | doca seca cercada de contêineres de madeira e correntes |
| `banner_arena_anel_ferro_velho` | Anel do Ferro-Velho | Rinha das Famílias | círculo de carcaças empilhadas, guincho, fogueira em tambor |
| `banner_arena_cratera_vale` | Cratera do Vale | Rinha das Famílias | cratera de terra no campo, carros de plateia em volta |

Estrada das Araucárias virou **Estrada dos Pinheiros** na tela (decisão do usuário, tema EUA); o arquivo
mantém o nome `banner_estrada_das_araucarias`.

## 2. Ícones (8)

Os 7 primeiros vão na pasta `arte/fastfather/icones/`, **256×256 png** com fundo transparente, desenho em
**branco chapado**: o jogo pinta na cor de cada lugar (creme, verde, cinza).

| Arquivo | Uso |
|---|---|
| `icone_correr.png` | Corridas de Bairro: selo da categoria na corrida e botão em PISTAS |
| `icone_pista.png` | Circuito Clandestino: idem |
| `icone_potencia.png` | Liga dos Hot Rods: idem |
| `icone_tracao_4x4.png` | Stock Cars: idem |
| `emblema_arena.png` | Rinha das Famílias: idem (hoje um escudo com estrela) |
| `icone_ok.png` | Visto de feito: missão completa, liga vencida em PISTAS, linha do fim da corrida |
| `icone_piloto.png` | Vaga de capanga ainda vazia em CAPANGAS (silhueta de capanga) |

O oitavo é diferente:

| Arquivo | Uso |
|---|---|
| `arte/fastfather/icones/cameras/dupla.png`, **160×160**, no estilo dos 4 de câmera que já existem | 5º botão de câmera: corrida 3D em cima e o mapa da pista embaixo |

## 3. Objetos da Rinha — feito em 3D no código

Fardos de feno (no lugar das barreiras de concreto; se espalham quando um carro bate), cavaletes de
madeira listrados (no lugar dos cones), barris de madeira com aros de ferro (no lugar dos tambores de
óleo) e pilhas de pneus estreitos da época. Os modelos antigos seguem só no Chrome & Wreckage.

## 4. Sons — fica para a imersão final

## 5. Criar depois

- Ícone da câmera dupla e fotos que faltavam: incluídos nas listas acima.
- Voz do locutor (largada, chegada, vitória): depois.
- Mapa de cada cidade: proposta abaixo, aguardando decisão.
- 16º troféu, loja à noite, capanga da Família Fundadora: sem pressa.

### O mapa de cada cidade (proposta)

Hoje a aba PISTAS é uma lista. A ideia (inspirada em Empire of Sin) é trocar o topo dela por um **mapa da
cidade desenhado à mão, visto de cima, como mapa de gângster aberto na mesa**: cada pista é um alfinete
no lugar dela (o Cais Velho no porto, a Avenida das Luzes no centro). O alfinete da liga atual pulsa e
os das pistas ainda fechadas não aparecem, seguindo a regra de entrega aos poucos: o mapa vai se
enchendo de alfinetes conforme o jogador avança, e cada pista nova "aparece na cidade". Ao mudar de cidade
(Brooklyn → Chicago → … → Las Vegas), o mapa troca, e essa troca vira o grande momento visual da mudança.

O que pediria: 7 mapas (um por cidade), **1080×900**, papel envelhecido com ruas, rio ou mar e bairros,
sem nomes escritos (o jogo escreve por cima). O jogo põe os alfinetes nas posições que eu marcar.
