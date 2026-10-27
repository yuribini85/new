# The Fastfather (antes Chrome Racing Team): conversão máfia americana e automobilismo clássico (1930–1950)

Briefing de conversão v1.0 do usuário (2026-10-27). Ajustes do usuário no mesmo dia: o período é
**1930–1950** e **a temática de evento de TV acabou** — o jogo é um idle de tema mafioso, sem
emissora, selo AO VIVO nem faixa de TV. **Escopo fechado:** narrativa, visual e
nomenclatura. Não muda corrida, progressão, economia, melhorias, colisão nem arena (matriz do
briefing, item 9). Substitui a fantasia da Mara contra o Sal e a linguagem da transmissão de
`docs/idle/direcao.md`; o complexo da equipe continua, com a cara da época.

> **The Fastfather** (pacote do usuário, 2026-10-27): nome, logo, a abertura nova (chefão,
> sobrinho e Tony), a loja com o ferro-velho, as falas da primeira corrida e a tipografia estão
> em `docs/idle/identidade_fastfather.md`, que vale por cima deste quando divergem (a abertura
> da seção 2 foi substituída pela SEQUÊNCIA 1).

## 1. Elenco (arquétipos originais; a arte do acervo é provisória até o usuário trocar)

| Personagem | Papel | Arte provisória |
|---|---|---|
| **Don Carmine Bellucci** | o chefe, financia a escuderia | `edgar_halloway` (terno com colete) |
| **Frankie Bellucci** | o sobrinho vaidoso, o piloto | `walt_pruitt` (terno bege) |
| **Sal Moretti** | chefe da família rival | `sal_moretti` |
| Mara Hayes | chefe dos mecânicos | `mara_hayes` |
| Theo Lane | piloto aposentado (ensina a ultrapassar) | `theo_lane` |
| Bianca Sterling | viúva rica (patrocínio) | `bianca_sterling` |
| Harold Brandt | comissário de prova (largada automática) | `harold_brandt` |
| Jade Ryker | agenciadora de pilotos | `jade_ryker` |
| Roxy Vega | dona do camarote na torre (a corrida em 3D) | `roxy_vega` |
| Rico Salas | gerente (missões) | `rico_salas` |
| Nora Lindqvist | contadora da família (analista) | `nora_lindqvist` |
| Kenji Arata | olheiro da família (escolher de onde ver a corrida) | `kenji_arata` |

Nenhum nome ou fala vem de filme; os nomes são originais.

## 2. Abertura (feito, `idle/abertura_idle.gd`)
- **Cena 1** (~3 s): rua de Nova York, 1948, porta da "Bellucci & Filhos". O chefe: "Meu sobrinho vai ser campeão."
- **Cena 2** (~3 s): Frankie, encostado no carro de época, ajeita o cabelo (brilho no topete): "Nasci para correr!"
- **Corte seco para a 1ª corrida, que larga sozinha** (critério do briefing: corrida em até 15 s).
- **Cena 3 e 4**, na volta da 1ª corrida (conversa `inicio` da escada): "Que vergonha. Você vai fazer esse idiota vencer. E não me faça repetir." Em seguida o Theo abre a Ultrapassagem, como antes, e a dica aponta o +1; o primeiro +1 larga a corrida seguinte sozinha.
- Um toque completa a fala e pula a pausa. Sem modal de explicação.

## 3. Capítulos (falas da escada de desbloqueios, sem mudar quando nem o que libera)
A escada já liga cada passo a um marco da progressão. A conversão só troca quem fala, o que diz e
marca o capítulo. A ordem segue a progressão real: a arena abre depois do analista e das câmeras,
então "Ferro e Sangue" é o capítulo 6, e não o 4 do briefing (mover o desbloqueio mudaria a progressão).

| Capítulo | Passo da escada | Quem |
|---|---|---|
| 1 · O Favor | abertura, `inicio`, ultrapassagem, pneus, patrocínio, largada | o chefe, Theo, Mara, Bianca, Harold |
| 2 · A Família | `familia` (novo, só fala), pilotos, transmissão | Sal, Jade, Roxy |
| 3 · Os Negócios | vácuo, arquibancada, missões, pistas | Mara, o chefe, Rico |
| 4 · O Sindicato | analista | Nora |
| 5 · O Campeonato | câmeras | Kenji |
| 6 · Ferro e Sangue | arena | Sal |
| 7 · O Herdeiro | `herdeiro` (novo, só fala, liga 16 somada) | Frankie |

A conversa que abre um capítulo traz a tarja "CAPÍTULO N · NOME" acima do nome. O calendário da
escada não mudou (medido com o robô: empurrar a Ultrapassagem uma corrida deixava o carro mais tempo
em 7º). Na volta da 1ª corrida vêm duas conversas seguidas: a bronca do chefe e o Theo.

## 4. Divisões (nomes; as ligas e os números são os de antes)
O jogo tem 4 modalidades de pista com 8 ligas cada, mais a arena. As 7 divisões do briefing viram
as modalidades (1–4) e os nomes das ligas de topo (5–7):

| Antes | Agora |
|---|---|
| Compactos | **Corridas de Bairro** |
| Turismo | **Circuito Clandestino** |
| GT | **Liga dos Hot Rods** |
| Terra | **Stock Cars** |
| Arena | **Guerra das Famílias** (mesma arena, mesma física) |
| ligas Estreantes · Regional · Estadual · Nacional · Continental · Mestres · Elite · Lendas | Novatos · Regional · Estadual · Nacional · **Interestadual** · **Copa das Famílias** · **Grande Campeonato** · Lendas |

## 5. Identidade visual (feito em parte)
- **Paleta** (`IdleUI`):

  | Cor | Valor |
  |---|---|
  | Fundo | preto quente #0F0D0B |
  | Painéis | #1A1612 |
  | Texto | creme #F1E9D8 |
  | Ações | latão #D4A24C |
  | Ganho | verde-garrafa claro #74B08A |
  | Anúncio | verde-garrafa #2F7A52 |
  | Tarjas e alerta | vinho #8E2A26 / #B23A32 |

- **Título e abertura:** rua de tijolo de 1948 com janelas acesas, poste, cartaz "GRANDE CORRIDA ·
  SÁBADO · 1948" e o carro de época em planos chapados (para-lamas destacados, cabine alta, estribo,
  sem emblema).
- **Andares do complexo:** paredes de tijolo escuro, latão nos detalhes.

## 6. Carros históricos (em andamento, um por vez)
Nenhum modelo da frota do C&W serve para a época: cada carro é convertido em código
(`visual/carro_epoca.gd`, `CarroEpoca`), peça por peça, como os carros de 1928–1955 eram
construídos: capô estreito entre para-lamas soltos, estribo, grade em pé, faróis em tigela numa
barra, para-choque de lâminas, estepe atrás e rodas de raios de arame. Só a aparência: a ficha de
corrida continua a da liga.

- **Feito: o cupê de 1928 (Corridas de Bairro).** Medidas do arquétipo (entre-eixos 2,63 m, bitola
  1,42 m, pneu alto e fino de aro 21", 1,73 m de altura) e conferido lado a lado com fotos de
  época. Peças: corpo e torpedo numa loft, cabine alta com teto de lona, pala, vidros planos em
  moldura, para-lamas abaulados em preto brilhante ligados ao estribo, grade alta e estreita com
  colmeia e tampa, faróis, para-choques de duas lâminas, longarinas e eixos à vista, venezianas na
  traseira do capô, faixa preta da cintura até a grade, maçaneta, lanterna, estepe e rodas de 30
  raios cruzados. Sem emblema.
- **Ligação:** a modalidade com `"epoca"` em `data/idle/idle.json` põe todo o grid nesse carro
  (cores e faixas das equipes por cima). Folha de vistas: `tools/folha_carro_epoca.gd`.
- **Feito: os carros das outras três divisões de pista** (pedido do usuário: "continue desenhando os
  carros"), conferidos com fotos de época:
  - **Circuito Clandestino — cupê comercial de 1940** (`cupe_1940`): entre-eixos de 2,84 m, capô
    comprido de proa em V com barras em pé e grades baixas dos lados, para-lamas em gota da cor do
    carro com a frente maciça e o farol nela, estribo curto, para-brisa bipartido, traseira em gota,
    para-choques com garras, rodas de aço com calota grande.
  - **Liga dos Hot Rods — hot rod de 1932** (`hotrod_1932`): cupê de três janelas com teto rebaixado,
    sem para-lamas nem capô, motor à mostra (tampas cromadas, compressor com cornetas, quatro escapes
    de cada lado), grade em pé, faróis em bala numa barra, eixo da frente rebaixado, para-choques de
    tubo, caixas de roda recortadas, pneus de trás largos e rodas cromadas.
  - **Stock Cars — sedã de 1951** (`seda_1951`): carroceria envelope rebaixada, entre-eixos de 3,15 m,
    cabine baixa, friso cromado de ponta a ponta, grade larga de barras deitadas com moldura em V,
    faróis nos cantos, para-choques maciços com garras, roda de trás meio coberta pela saia, pneus de
    faixa branca com calota inteira.
  - O gerador ganhou um estilo por "tipo" com peças comuns: seções de laterais inclinadas, caixas de
    roda recortadas na lataria, vidros projetados na curva da cabine e rodas de disco.
- **Ainda sem carro de época:** a arena (Guerra das Famílias) segue com os carros dela.

**Pista de época (pedido do usuário):** nas divisões com `"epoca"`, a corrida troca o cenário do
tema por um **autódromo rural** do fim dos anos 1920 à tarde (`visual/cenario_epoca.gd`,
`CenarioEpoca`), em cores chapadas e poucas peças: pista de terra batida, cerca de madeira branca dos
dois lados, gramado e retalhos de plantação, árvores, celeiro vermelho com silo, arquibancada de
madeira coberta com bandeirolas e a torre dos fiscais na largada, fardos de feno por fora das curvas
e a largada quadriculada com a faixa de pano. A primeira tentativa (rua de bairro com prédios) foi
descartada pelo usuário: os prédios não davam imersão. O **traçado** continua o das pistas da
divisão: traçado novo mudaria a força dos rivais calibrada por pista (`forca_rivais`), que o
briefing não deixa mexer. Um traçado novo, mais simples, fica como opção com recalibração.

**Nomes:** a regra do projeto é que nome e marca de carro real não entram no build (CLAUDE.md), e
o briefing pede nomes visíveis configuráveis e verificação jurídica. Por isso a lista de modelos
reais fica **só aqui**, como referência de silhueta; no jogo, cada carro tem nome neutro e
original.

| Divisão | Referência de silhueta (só documento) |
|---|---|
| Corridas de Bairro | Ford Model A 1928, Ford Model B 1932, Plymouth P4 1937 |
| Circuito Clandestino | Ford De Luxe Coupé 1940, Willys Americar 1941, Chevrolet Fleetline 1948 |
| Liga dos Hot Rods | Ford 1932 hot rod, Willys coupé preparado, Mercury Eight 1949 |
| Stock Cars | Oldsmobile 88 1950, Hudson Hornet 1951, Studebaker Commander 1953 |
| Interestadual (ligas) | Tucker 48, Chevrolet Corvette 1953, Kaiser Darrin 1954 |
| Copa das Famílias (ligas) | Cadillac Fleetwood 1941, Packard Custom Eight 1948, Lincoln Continental 1946 |
| Grande Campeonato (ligas) | Chevrolet Bel Air 1955, Ford Thunderbird 1955, Chrysler C-300 1955 |

## 7. Pendente (próximas etapas)
1. Carros de época das outras divisões (item 6) e nomes neutros dos carros por liga.
2. Arte definitiva do chefe, do sobrinho e do elenco em roupas da época (o usuário sugere os assets).
3. Arena "Guerra das Famílias": cartaz de luta de carros na apresentação; sedãs e coupés de época.
4. Som: trilha swing/jazz/jump blues (a atual é provisória), locutor de corrida, motores de 6 e 8 cilindros.
5. Fundo do topo (foto do porto do C&W) por cenário de época; cenário de época nas outras divisões.
6. Verificação de direitos antes de publicar (briefing, item 8).

## 8. Regressão
- Testes do jogo, robô e calibrador rodam sobre a mesma economia: os números de `data/idle/idle.json`
  só mudaram em textos e nomes.
- A arena não foi tocada.

## 9. Sem TV (ajuste do usuário)
- O passo `transmissao` da escada continua no mesmo lugar e libera o mesmo (a corrida em 3D), mas
  é o **camarote na torre**: antes dele a corrida é ouvida pelo rádio do box (a vista de cima com
  pontos); a Roxy é a dona do camarote. Oferta: CAMAROTE NA TORRE.
- O passo `cameras` são os **olheiros nas curvas** do Kenji (o mesmo seletor de vista).
- Saíram o selo AO VIVO da corrida e da conversa; a conversa é a faixa da fala em vinho e creme.
- **Autódromo rural** (pedido do usuário, no lugar da rua com prédios): ver item 6.

## 10. Garagem (pedido do usuário, 2026-10-27)
Decisões do usuário (opções recomendadas): **um carro por divisão**, comprado uma vez; **preço de
tabela da época + sobra** no dinheiro inicial; garagem **na abertura e numa aba**.

- **Dados:** `garagem` em `data/idle/idle.json` (id, nome no jogo, ano, `modelo` de CarroEpoca,
  divisão e preço). Divisão sem carro na lista corre como antes.
- **Preço:** cupê de 1928 a **US$ 525** (cupê comercial, ficha da ConceptCarz:
  https://www.conceptcarz.com/s1618/ford-model-a.aspx — fonte secundária; trocar se houver tabela
  de concessionária). **Dinheiro inicial US$ 625** = o carro + os US$ 100 do começo de antes: depois
  da compra a 1ª corrida é igual à de antes.
- **Só aparência:** o carro não mexe na ficha da corrida; a velocidade vem das melhorias.
- **Tela** (`idle/garagem_idle.gd`): oficina de tijolo e tábuas com luminária, o carro girando (o
  dedo gira), nome, divisão, preço e COMPRAR · $X / FALTAM $X / NA PISTA / CORRER COM ESTE; setas
  quando houver mais de um carro.
- **Fluxo:** depois da cena do chefe e do sobrinho vem "O CARRO DO SOBRINHO" ("O chefe deu $625
  para o carro."); comprado, a 1ª corrida larga. Depois disso a aba GARAGEM fica na barra. Sem o
  carro da divisão, LARGAR leva à garagem.
- **Save antigo:** quem já correu na divisão recebe o carro dela.
- **Divisões 2 a 4** (decisão do usuário: preço medido pela economia): o carro custa 10 prêmios de
  1º lugar na primeira liga da divisão (o carro se paga em 10 vitórias): Cupê 1940 US$ 12 mil,
  Hot Rod 1932 US$ 48 mil, Sedã 1951 US$ 192 mil. Mostrado em dólares, mas não é preço de época.
- **Sem o carro:** a corrida da divisão espera no grid (mesmo com a largada automática); LARGAR e a
  troca em PISTAS levam à garagem, aberta no carro que falta; comprado, a corrida larga. O FALTAM
  acompanha o dinheiro entrando.
- **Calibrador:** o jogador simulado junta o dinheiro do carro (sem comprar melhorias) correndo onde
  está, compra e troca de divisão.

## 11. Pinturas de época (briefing de pinturas do usuário, 2026-10-27)
Entre 1930 e 1950 a identidade do carro era a cor da carroceria e o número pintado; publicidade
pouca e pequena. `visual/pintura_epoca.gd` (`PinturaEpoca`) gera as pinturas por família:

| Família | Onde | Cores (aproximações para a tela) | Regra |
|---|---|---|---|
| Garagem de bairro | Corridas de Bairro | preto, vinho, creme, verde, azul | cor única, número opcional pintado à mão, rodas escuras ou creme |
| Hot rod clandestino | Circuito Clandestino, Hot Rods | vermelho, preto, azul, branco, amarelo | contraste, número sempre, filete lateral em segunda cor, rodas vermelhas/pretas |
| Stock car | Stock Cars | azul, vermelho, branco, verde, amarelo | cor sólida, número grande nas portas e no teto, teto ou capô em segunda cor às vezes |
| Copa das Famílias | ligas Copa das Famílias, Grande Campeonato e Lendas de qualquer divisão | preto, bordô, esmeralda, marfim, prata | brilhante, teto em segunda cor, número serifado discreto num círculo |

- **Regras:** a cor principal cobre quase toda a lataria; no máximo uma segunda cor (teto, capô ou
  filete); nada de degradê, zigue-zague, xadrez nem padrão moderno (teste `test_pinturas_de_epoca`).
- **Equipes:** a cor sai da equipe (a mesma equipe tem a mesma cor de uma corrida para outra); o
  número é o do piloto na equipe; nenhum rival usa a cor do carro do jogador.
- **O carro do jogador (família Bellucci), sempre o 13:** bairro preto com o 13 branco pintado à mão
  e rodas vinho; hot rod preto com filete vinho; stock car creme com teto azul e o 13 azul; Copa das
  Famílias preto com teto marfim e o 13 serifado no círculo.
- **Peças novas:** o padrão "teto" (segunda cor da base da cabine para cima) e as rodas pintadas
  (`roda_epoca`: creme, vinho, vermelha, preta, marfim, azul, verde).
- **Ainda não:** o nome pequeno da oficina ou do patrocinador na lateral (pede letras na pintura);
  a arena segue com as cores das equipes de antes.
- Folha para conferir: `tools/folha_pinturas_epoca.gd`.
