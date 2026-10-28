# The Fastfather — identidade visual, abertura e primeira corrida

Pacote do usuário (2026-10-27, `Fastfather.zip`): o logo, a arte da abertura (escritório do
chefão), da loja (galpão do Tony) e da primeira corrida, e o "LEIA-ME PRIMEIRO". O jogo
idle (antes Chrome Racing Team) passa a se chamar **The Fastfather**: máfia, 1930–1950.

## 1. O que entrou

- **Nome e logo:** título, página web (`web/shell_idle.html`), nome do app Android
  (`export_presets.cfg`, "The Fastfather"), canal de avisos e ícones (`arte/idle/icone_*`,
  o carro do logo). O identificador do pacote (`com.yuribini.chromeracingteam`) ficou: trocar
  cria outro app na Play Store e o save não passa de um para o outro.
- **Arte:** `arte/fastfather/{abertura,loja,corrida}` em WebP, recortada sem mudar a
  proporção; as poses do mesmo personagem saem do mesmo quadro (trocar de pose não pula).
- **Cenas em quadrinho** (`idle/cena_quadrinho.gd`, textos em `data/idle/cenas.json`): o
  estilo das cenas do inFAMOUS 2 — a ilustração parada que a câmera percorre, aproxima de quem
  fala e anda o fundo menos que as figuras; a passada de tinta abrindo e fechando o quadro; a
  retícula de impressão nas bordas; balões facetados e tortos como a arte low poly dos
  personagens, com sombra dura, tarja do nome e letra de gibi pulp (Bangers).
- **Lugar e ano (2026-10-27):** depois do título, preto e o cartão "BROOKLYN, NOVA YORK — 1937"
  (`cenas.json` → abertura → "cartao"); a cena do chefão sobe do preto e espera 1 s antes da
  primeira fala. 1937: o Ford Model A de 1928 já é carro de ferro-velho, e as divisões seguintes
  chegam com o tempo (Ford De Luxe 1940, Hudson Hornet 1951). Brooklyn: o cais da GAZETA DO CAIS e
  do porto no alto da tela, e a Nova York das famílias.
- **SEQUÊNCIA 1 (abertura):** as nove falas do roteiro, na ordem, com o Tony entrando no
  "Tony! Venha aqui." e o sobrinho abrindo espaço.
- **SEQUÊNCIA 2 (loja):** a garagem nova (também a aba GARAGEM): o galpão do Tony ao fundo, a
  vitrine com os quatro carros — os de divisão ainda fechada em silhueta preta, sem nome nem
  preço —, o carro escolhido girando em 3D. O primeiro carro vem do ferro-velho (tinta queimada,
  ferrugem, poeira, riscos) por 1/3 do preço: US$ 175 com os US$ 525 riscados. O chefe dá US$ 275
  (os mesmos US$ 100 de sobra de antes; o resto do jogo não muda). No "E aquele ali?" o carro do
  meio pulsa como se desse para comprar; no "Agora compre!" pulsa o ferro-velho, e então aparece
  a compra com o botão pulsando.
- **Carro na garagem (2026-10-27):** a câmera 3D segue a perspectiva da arte do galpão —
  o horizonte na linha em que a cidade encontra o chão lá fora e o carro, antes do primeiro
  toque, alinhado com o ponto de fuga da parede; o chão do carro fica logo acima da ficha, do
  mesmo tamanho em qualquer tela (em tela baixa a câmera desce). Só gira com o dedo; a seta
  curva embaixo pisca devagar. Das duas luminárias sai um cone de luz em facetas, somado à
  arte, com a mancha no chão, respirando devagar.
- **SEQUÊNCIA 3 (corrida):** o arquivo do pacote repete o texto da loja. As falas que eu tinha
  proposto (antes da largada, último lugar, primeira vitória) saíram a pedido do usuário; a
  corrida começa logo depois da compra e as falas esperam o texto dele. Depois da primeira
  vitória o carro ainda sai do ferro-velho e ganha a pintura da família (preto, o 7).
- O Don e o sobrinho das conversas da escada usam a arte nova (`corpo/chefao`, `corpo/sobrinho`).

## 2. Tipografia

| Uso | Antes | Agora | Por quê |
|---|---|---|---|
| Dinheiro e títulos de tela | Racing Sans One / Big Shoulders | **Limelight** (art déco) | letreiro dos cartazes de cinema e das fachadas dos anos 1930 |
| Falas (balões e conversas) | Barlow | **Bangers** | gibi pulp dos anos 1940; anguloso como a arte facetada |
| Botões e rótulos curtos | Big Shoulders | Big Shoulders | desenhada a partir das placas de Chicago dos anos 1920; lê bem em botão |

Licenças em `ui/fontes/LICENCA-*.txt` (OFL; Special Elite, a máquina de escrever, Apache 2.0 —
ficou fora das falas porque combina com a época mas não com o traço da arte).

## 3. O que os jogos de máfia de 1930–1950 fazem na interface (sugestões)

Estudo pelo que esses jogos mostram na tela (sem copiar nada deles):

- **Mafia (2002), cidade nos anos 1930:** cada missão abre com um cartão de capítulo em
  letreiro de cinema e data. → *Sugestão:* o "CAPÍTULO" das conversas como cartão de cinema em
  tela cheia por 1 s (letra Limelight, fundo preto, a data "Nova York, 1932").
- **Mafia II (1940–50):** dinheiro em notas, rádio de época, revistas e jornais colecionáveis.
  → *Sugestão:* manchete de jornal na subida de liga ("SOBRINHO DO BELLUCCI VENCE NO CAIS"),
  com retícula e papel amarelado; o prêmio contado como maço de notas.
- **The Godfather (2006):** respeito/medo como medidor e o "favor" como moeda de história.
  → *Sugestão:* a renda por segundo como "proteção" (o envelope do bairro), mesmo número.
- **L.A. Noire (1947):** caderno de anotações do detetive como menu. → *Sugestão:* a aba
  MISSÕES como o caderno do Tony (papel pautado, letra à mão nos riscados).
- **Empire of Sin / Omerta (anos 1920):** mapa da cidade com territórios e livro-caixa.
  → *Sugestão:* a aba PISTAS como mapa com alfinetes, e o resumo de volta ao jogo ("BEM-VINDO DE
  VOLTA!") como página do livro-caixa.
- **inFAMOUS 2:** cenas em quadrinho com movimento de câmera — já em uso (seção 1).

Aplicado agora: as letras da seção 2, os cantos chanfrados de placa art déco em todos os painéis
do jogo (`IdleUI.caixa`), o dinheiro do alto em dourado déco e as cenas em quadrinho. As
sugestões acima ficam para a decisão do usuário.

## 4. "Corridas como Super Star Race" (LEIA-ME 1)

O laço do jogo já é esse: a mesma corrida se repete sem fim, o prêmio cai pela posição, o
dinheiro entra também parado (patrocínio, arquibancada, com o app fechado) e as melhorias
sobem a posição até o primeiro lugar, que abre a liga seguinte. Não mudou nada aqui.

## 5. Melhorias aprovadas (2026-10-27)

O usuário aprovou a lista de melhorias, menos o redesenho do elenco antigo: **Mara, Theo,
Bianca, Harold e o resto do elenco antigo saem; a história é outra.** Até a história nova:

- **Elenco:** as funções que eles entregavam (ultrapassagem, pneus, patrocínio, largada
  automática, pilotos, vácuo, missões, contador, olheiros) agora vêm do Tony ou do chefão, com
  falas provisórias; nas estações de melhoria, o Tony (oficina, pneus, túnel de vento), o
  sobrinho (simulador, arquibancada) e o chefão (patrocinadores). As conversas do Moretti e o
  camarote saíram.
- **1. Corrida em 3D desde a primeira** (a vista de cima saiu; `camera_tv` vem de saída).
- **3. Interface art déco:** moldura dupla de latão com cantos em degrau (`MolduraDeco`) no
  topo, no objetivo, nas estações e na ficha da garagem; placa de latão com o nome da estação;
  botões de latão chanfrados com o preço em Limelight; a barra de baixo como balcão de madeira;
  números da corrida e o dinheiro que pipoca em Limelight.
- **4. Jornal na subida de liga** (`JornalIdle`, "GAZETA DO CAIS"): manchete que muda a cada
  liga, foto da pista em sépia com retícula, a divisão nova como EXTRA; entra girando.
- **5. Livro-caixa** no BEM-VINDO DE VOLTA (`LivroCaixa`): papel pautado, margem vermelha, uma
  linha por divisão e o TOTAL sublinhado.
- **6. Notas de dólar** voando da corrida até o dinheiro do alto no prêmio.
- **7. Cenas de marco** (`data/idle/cenas.json`): o rival Moretti aparece (escritório), a
  divisão nova abre (escritório), o segundo carro chega (galpão). Falas provisórias.
- **8. Famílias rivais:** a plaquinha de posição mostra o sobrenome da família (Moretti,
  Calabrese, Greco...), uma por equipe, sempre a mesma cor.
- **9. Público da época:** torcida de terno e chapéu na arquibancada, o apostador com o
  quadro-negro das cotações na cerca e fumaça de charuto na torre dos fiscais.
- **10. Flash e foto da vitória:** clarão branco e a foto da chegada em sépia num papel de
  jornal, por 3 s no canto do telão.
- **11. Trilha da época:** três gravações de 1924 da Wolverine Orchestra (domínio público,
  `arte/sons/LICENCA.md`), uma depois da outra; na garagem a música passa por um rádio AM.
- **12. Locutor:** pronto para tocar `locutor_largada`, `locutor_vitoria` e `locutor_chegada`
  (arte/sons/), com o filtro de rádio, assim que forem gravados. Texto sugerido:
  - largada: "Estão na linha... e lá vão eles! O carro 7 dos Bellucci larga atrás!"
  - vitória: "Inacreditável, senhoras e senhores! O sobrinho dos Bellucci cruza em primeiro!"
  - chegada: "Fim de corrida! O 7 dos Bellucci ainda tem muito o que aprender."
- **13. PULAR ›** nas cenas em quadrinho, a partir da segunda fala.
- **14. Repintura:** depois da cena da vitória, a oficina do Tony: a ferrugem some, a lataria
  escurece e entra a pintura da família com o 7.
- **15. Mural de cartazes** de corrida no fundo da aba PISTAS.

## 6. O sobrinho corre; os rapazes vão para a Rinha (2026-10-27)

Pedido do usuário: o piloto é sempre o sobrinho; a mecânica de pilotos (contratar
grátis, contratar com vídeo, juntar dois do mesmo nível) vira **os rapazes da família**,
que lutam na **Rinha das Famílias** — a arena do Chrome & Wreckage com outro nome —
rodando o tempo todo ao lado da corrida. A corrida é o idle; assistir à Rinha de vez em
quando é o tempero.

- A corrida usa sempre o piloto base (o sobrinho); o nível dos rapazes não muda a corrida.
- A Rinha (`IdleEstado.lutar_rinha`/`pagar_rinha`, aba RINHA) abre junto com os rapazes
  (2ª liga dos Bairros) e luta sem parar enquanto o app está aberto: o rapaz de nível mais
  alto, num cupê 1940, contra carros de época das famílias rivais. Não tem compras
  próprias: o carro leva as melhorias da corrida, a liga acompanha a corrida mais alta e
  o prêmio usa a escada dos Bairros (multiplicador 1 a 50,3). Luta não conta como corrida.
- Vitória dos rapazes com o jogador em outra aba: aviso no alto e o prêmio sobe.
- Aba RAPAZES (hoje CAPANGAS, seção 18): nomes da época (`data/idle/cenas.json` → "rapazes"), retratos em silhueta
  até a arte chegar, o mais forte vai sozinho para a Rinha (sem ESCALAR).
- PISTAS mostra a Rinha como "luta sozinha"; a corrida não pode ir para lá.

## 7. Tela da corrida no layout do usuário (2026-10-27)

Imagem de referência do usuário: faixa do alto (CAIXA DA FAMÍLIA, LUCRO POR SEGUNDO, engrenagem);
a corrida do cabeçalho até a oficina, com a liga (objetivo e corrida da vez, posição com os pontos
do pelotão, volta) e o PRÊMIO ATUAL com as câmeras por cima, em faixas translúcidas; a OFICINA DO
TONY com MELHORIAS (a lista completa, com +10 e MÁX.) e os cartões de melhoria rolando de lado; o
COMBUSTÍVEL ADULTERADO (vídeo, 2 por dia; bônus e duração provisórios em `idle.json` →
"combustivel"); as TRAPAÇAS DA FAMÍLIA (Ultrapassagem = Corrida arranjada, Vácuo = Sabotagem; Fiscal
comprado fechado até ter efeito). Pedidos do usuário na mesma rodada: a letra ornamentada (Limelight)
só no caixa e no prêmio; a barra de baixo com o fundo da de cima; bordas finas e cantos pequenos;
sem ícones pequenos nem placas atrás da posição, da volta e da aba escolhida; sem o Tony e a fala
na oficina; sem barra de andamento. As abas continuam as de antes.

## 8. Engajamento da tela da corrida (2026-10-28)

Análise pelos idles de referência (AdVenture Capitalist, Egg Inc, Idle Miner, Idle Racing GO) e
implementação aprovada pelo usuário ("implemente tudo"):

- **Segurar a corrida acelera** (`idle.json` → "toque", provisório): a corrida já resolvida passa
  mais rápido enquanto há carga; a carga volta sozinha. O resultado não muda. Velocímetro
  analógico no canto de baixo à direita, acima da faixa do prêmio: o ponteiro sobe enquanto
  segura, a carga em ouro num arco por dentro das marcas e, carregado, "TOQUE" pulsando; dica na
  primeira vez. Arte do usuário: `arte/fastfather/corrida/velocimetro.png` e `ponteiro.png`.
- **Marcos por melhoria** (`idle.json` → "marcos", provisório): níveis 10, 25, 50 e 100; nas
  melhorias de renda o efeito dobra a cada marco; nas outras, só a fase nova. Barrinha até o próximo
  marco em cada cartão; ao passar, "×2 PATROCÍNIO!" com faíscas.
- **Prêmio pingando**: a corrida está resolvida na largada, então a parte do prêmio entra conforme o
  carro anda (o total não muda). Medido (`tools/medir_primeiros_minutos.gd`): a primeira corrida dura
  84 s; antes, 4 compras e nada até 1:40; agora 5 compras até 30 s e 6 no primeiro minuto.
- **Cada ultrapassagem estoura**: "+1 POSIÇÃO" sobre o carro e o PRÊMIO ATUAL salta em verde.
- **Comprar tem peso**: o botão que dá para pagar respira; seletor ×1 / ×10 / MÁX na oficina.
- **Meta concreta**: "CHEGUE EM 1º · MELHOR: 6º".
- Para o primeiro minuto ficar no alvo dos idles de referência (primeira compra em < 10 s e ~5 no
  primeiro minuto, já alcançado), o que mais pesa agora é a duração da corrida da 1ª liga (84 s) e o
  prêmio dela; mexer nisso é balanceamento e fica para o playtest.

## 9. Golpes visuais na corrida de época (2026-10-28)

Referências: Art of Rally (tilt-shift, poeira), Firewatch (cor e névoa), Lonely Mountains:
Downhill (profundidade), Burnout (câmera lenta), Crossy Road (tudo reage). Implementado:

1. **Filme de 1937** (`visual/shaders/velocidade.gdshader`): parte sépia, pretos levantados,
   luz quente, vinheta, grão de filme e o tremor de brilho do projetor.
2. **Tilt-shift**: o alto e o pé da tela desfocados (cruz de 5 leituras), a pista vira maquete.
3. **Poeira de terra batida** atrás de cada carro, mais densa quanto mais rápido.
4. **Fim de tarde** (`CenarioEpoca`): céu de poeira dourada, sol baixo e quente, névoa na cor do
   céu; sombras compridas fora dos efeitos leves.
5. **Momentos fortes**: meio segundo de câmera lenta, clarão e tremor na ultrapassagem e na
   bandeirada; segurando para acelerar, o borrão de velocidade e o rastro.
6. **Vida**: a torcida balança no lugar (de vez em quando alguém se levanta) e as bandeirolas
   (telhado da arquibancada e cordão novo sobre a largada) tremulam no vento
   (`visual/shaders/vida_epoca.gdshader`).
7. **Coerência**: a mesma paleta sépia e ouro da interface.

No navegador (efeitos leves ligados por padrão) tudo vale menos as sombras; "reduzir animações"
para o grão, a poeira, o balanço e a câmera lenta.

## 10. Bandeira do fiscal no lugar do semáforo (2026-10-28)

Nos anos 1930 a largada era dada na bandeira. Na corrida, por cima da imagem, a bandeira de
pano (`BandeiraIdle`, malha facetada que ondula em `visual/shaders/bandeira.gdshader`; só o pano,
sem haste, mão nem contorno, pedido do usuário): a verde
entra e tremula na contagem e desce num golpe na largada; a quadriculada tremula na chegada. O
semáforo e a faixa quadriculada do painel ficam desligados (`HudCorrida.sem_semaforo`). No 3D, o
fiscal de terno e chapéu na beira da largada com a bandeira de pano no alto da haste
(`visual/shaders/bandeira_3d.gdshader`), verde até a chegada e quadriculada nela.

## 11. Grid de largada dos anos 1930 (2026-10-28)

Entre 1930 e 1940 não havia grid padrão: os carros largavam em fileiras de três, muitas vezes
alternadas com fileiras de dois, conforme o circuito e o regulamento. A corrida desenha o grid em
fileiras 3-2-3-2 (`Corrida3D._grid`, 10 m entre fileiras, pole na frente à esquerda), marcado como
em 1940: linha branca simples de borda a borda nas fileiras de três, traço curto na frente de cada
carro nas de dois e o número da posição pintado no chão. A simulação
continua com a fila dela (nada muda no resultado); cada carro sai da vaga desenhada e se funde à
posição da simulação nos primeiros metros (`Corrida3D._recuo_grid`, só visual).

## 12. Câmera que alterna (2026-10-28)

Quarto botão no trilho das câmeras, o primeiro e o padrão: alterna sozinho entre AUTO, o seu
carro e a pista inteira, uma a cada 8 s (`TelaIdle.CICLO_CAMERA_S`, apresentação); no grid fica no
plano de cima. A câmera da vez acende em ouro no trilho. Na visão geral a neblina do cenário sai
(a câmera fica longe e a neblina cobria a pista).

Visão geral e câmera do seu carro mais afastadas (`Corrida3D.GERAL_FOLGA` 1,55, a pista inteira
entre as faixas da tela; `TAMANHO_PERSEGUICAO` 46 m).

## 13. Troféus (2026-10-28)

O botão MELHORIAS da Oficina do Tony virou TROFÉUS (pedido do usuário). Abre a coleção: um troféu
por pista (16), ganho na primeira vitória numa liga dela (`IdleEstado.ganhar_trofeu`, também na
Rinha). Os ainda não ganhos ficam em sombra preta, com "VENÇA EM 1º"; o bônus só aparece depois de
ganhar. Bônus em `idle.json` → "trofeus" (prêmio das corridas, lucro por segundo ou motor; 10% cada,
PROVISÓRIO). Na chegada, "TROFÉU NOVO!" e o botão pulsa. Save antigo: as ligas já vencidas dão os
troféus. Arte do usuário: 15 troféus recortados em `arte/fastfather/trofeus` (a 16ª pista repete
o 13). Os atlas de ícones enviados estão em `arte/fastfather/icones` para uso futuro.

## 14. O menino jornaleiro (2026-10-28)

De vez em quando (`idle.json` → "jornaleiro", números PROVISÓRIOS) o menino jornaleiro (380 px, nunca
mais que 2/3 à mostra) sobe de trás da faixa do prêmio, à esquerda, gritando e acenando com o jornal.
O corte dele fica no pé da área da corrida, escondido pela Oficina opaca logo abaixo: pela faixa
translúcida ele aparece inteiro, nunca cortado (pedido do usuário). 12 quadros da arte do
usuário em `arte/fastfather/jornaleiro`, a segunda fileira da folha ampliada para o mesmo tamanho).
O toque nele paga na hora a gorjeta (`IdleEstado.gorjeta_jornaleiro`: o maior entre um tempo de
lucro por segundo e uma parte do prêmio de 1º) e mostra GORJETA x2 por 6 s: o vídeo paga de novo.
Ele é o próprio botão: nada de texto explicando. Só aparece com a corrida na tela, sem conversa,
dica, bandeira ou grid esperando.

## 15. Seletor de compra ×1 · ×10 · PRÓX. · MÁX (2026-10-28)

Como nos melhores idles (x1, x10, Next, Max; pedido do usuário): PRÓX. compra até o próximo marco
da melhoria (`idle.json` → "marcos"; sem marco à frente, até o fim) — "Next" em português, pela
regra do texto de tela na língua do jogador. ×10 e PRÓX. param no máximo da melhoria.

## 16. Paleta Noir Industrial 1937 (aprovada pelo usuário, 2026-10-28)

Carvão #1C2021 nos fundos (72%), petróleo #303F40 nos painéis e aço #69716B nos neutros (16%);
destaques (12%): latão #B4945D (dinheiro e conquistas), vinho #A7463A (trapaças e alerta), verde
militar #546C55 (melhorias), couro #76543E (garagem e madeira), marfim #E0D6BC no texto. Ajustes
de contraste (WCAG, medidos): tons claros para texto e números — verde #9CB896, latão #D9C08C,
vinho #D88577, aço #98A099 —; botão de compra no verde militar clareado #86A382 com texto em
carvão (5,9:1), apagado em petróleo sem dinheiro; vídeo em verde militar com marfim; trapaças em
vinho com marfim. Tudo em `IdleUI` (COR_CARVAO … COR_VERDE_BOTAO); `test_paleta_tem_contraste_para_texto`
barra texto abaixo de 4,5:1. A arte (garagem, quadrinhos, jornal, livro-caixa) e o filtro de filme
da corrida não mudam.

## 17. Os rapazes com arte (2026-10-28)

14 figuras da arte do usuário (`arte/fastfather/rapazes`, recortadas da folha) formam o elenco em
`cenas.json` → "rapazes" → "elenco": pela ordem de contratação, cada rapaz é uma figura, com nome e
apelido casados com ela (Nicky Gravata, Paulie Fumaça, Rosie Brasa, Tommy Ferrolho, Rocco Martelo,
Bruno Muralha, Benny Ligeiro, Aldo Contas, Nino Cicatriz, Mei Seda, Enzo Bigode, Tito Trovão,
Vinnie Navalha, Lola Raposa). Do 15º em diante o elenco volta com outro apelido. O retrato na aba
RAPAZES é o busto recortado da figura (`IdleUI.busto_de`), no lugar da silhueta provisória.

## 18. RAPAZES vira CAPANGAS (2026-10-28)

Com mulheres no elenco, a aba e os textos passam a dizer CAPANGAS ("o/a capanga", vocabulário da
máfia da época; escolha do usuário entre CAPANGAS, COMPARSAS, BANDO e GANGUE): SEUS CAPANGAS,
NOVO CAPANGA, "2 capangas do mesmo nível = 1 capanga de nível acima", a fala do Tony e o aviso
da Rinha. As chaves internas ("rapazes", `arte/fastfather/rapazes`) continuam.

## 19. Ícones do HUD (2026-10-28)

A folha de ícones do usuário (69 ícones, `arte/fastfather/icones/hud`, nomes descritivos) entra no
HUD por `IdleUI.icone_hud`: no alto, o maço de notas (CAIXA DA FAMÍLIA) e a engrenagem; no menu de
baixo, CORRIDA = carro de corrida, PISTAS = estrada, CAPANGAS = chapéu fedora, RINHA = escudo,
MISSÕES = prancheta, GARAGEM = garagem. A aba fora de uso fica apagada sem perder a cor. Os outros
ícones ficam prontos para as próximas telas.

Câmeras (folha de ícones de câmera do usuário, `arte/fastfather/icones/cameras`): ALTERNAR = câmera
com setas girando, AUTO = rolo de filme, SEU CARRO = mira, PISTA INTEIRA = lupa de afastar. A arte
é creme; o botão ativo escurece o ícone sobre o latão e, no alternar, a câmera da vez fica dourada.
