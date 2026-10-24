# Chrome Racing Team — plano do teste de mercado

Segundo app do mesmo projeto Godot (decisão do usuário, 2026-10-23): um idle de equipe de corrida
no modelo do Race Star (Cool Cats Games) e parecidos, feito com o que o Chrome & Wreckage já tem
(carros 3D, pistas, câmeras, simulação, salvamento, compras e exportação). Objetivo: publicar
rápido para medir custo por instalação e retenção; o Chrome & Wreckage segue sendo o jogo
principal.

## O jogo em uma frase
Sua equipe corre sozinha em cinco modalidades ao mesmo tempo, cada uma com carros, pistas e uma
escada de ligas; o dinheiro das corridas e dos patrocinadores compra melhorias; pilotos chegam
por contrato e fundem em níveis mais fortes; ao vencer, a equipe sobe de liga, ganha um carro
melhor e uma pista nova, e cada modalidade abre a próxima.

## Versão 2 (2026-10-24, pedido do usuário)
"Um idle simples, mas com interface bonita, opções de pistas e uma escala evolutiva que faça a
pessoa abrir o jogo por várias semanas." Decisões do usuário: **5 modalidades com Arena** e
**pilotos por contrato + fusão** (como o Race Star, que tem seis disciplinas, cada uma com
pilotos, carros e pistas próprios, recrutamento e fusão de pilotos).
- **Abre e já recolhe:** sem tela de entrada; a renda com o app fechado entra sozinha e uma faixa
  oferece o vídeo que dobra.
- **Modalidades** (`data/idle/idle.json` → `modalidades`): Compactos (circuitos curtos), Turismo
  (sedãs, circuitos), GT (cupês, velocidade), Terra (picapes e utilitários: cânion, araucárias,
  serra) e Arena (a demolição do Chrome & Wreckage, `Arena`/`Arena3D`). 8 ligas cada; a próxima
  abre na liga 4 da anterior; todas rendem juntas; liga e melhorias são de cada modalidade, o
  dinheiro é um só. Na Arena o Vácuo vira Blindagem (peso a mais).
- **Pilotos** (`pilotos`): os 76 pilotos das equipes do C&W, com retrato, perfil (agressivo,
  equilibrado, cauteloso) e frase. Contrato grátis a cada 4 h e por vídeo (5 ao dia) traz um
  piloto no nível 1; dois do mesmo nível fundem num nível acima (até 8; +1% de ritmo por nível).
  Um piloto por modalidade.
- **Interface:** menu de baixo desenhado (CORRIDA, PISTAS, PILOTOS, METAS) com aviso de pendência;
  PISTAS mostra as modalidades e a escada de ligas (pista, carro, prêmio, onde a equipe está);
  PILOTOS mostra o escalado, contratos e o elenco; engrenagem com som e visual simples; câmeras em
  ícones.
- **Ritmo medido** (`tools/calibrar_idle.gd`, 4 sessões de 8 min por dia, renda com o app fechado
  até 2 h, contrato grátis e fusões; multiplicador ×1,75 por liga, custo ^2,3): Turismo abre no dia
  0,3, GT no 0,8, Terra no 1,5, Arena no 3,3; a Arena termina no dia 7; Terra Elite e Lendas são o
  fim de jogo (dias 12–20); o jogo inteiro em ~23 dias e 600 corridas. Com ×2 por liga eram 54
  dias, com 40 só em Terra.
- **Paleta "cromo + ouro"** (decisão do usuário, tirada do logotipo; `IdleUI`): fundo #0B0E13,
  cartões #161B22 com borda cromada #3A4250, ações em ouro em relevo (#FFC53D→#F08A0C), vídeos em
  prata #C9CED6, renda em ouro claro #FFD873, verde #6FD08C só no ganho das melhorias, vermelho
  #E5484D só no alerta.
- **O jogo cresce com o jogador** (pedido do usuário, 2026-10-24: "a pessoa precisa sentir que a
  evolução acontece por causa dele"; um idle que já abre com tudo rodando sozinho parece não ter
  propósito). Padrão do gênero (Cookie Clicker, A Dark Room): começar com quase nada, o toque
  manual antes da automação, a interface que se revela aos poucos. Começo: vista de cima com os
  carros em pontos, só o cartão do Motor, sem menu de baixo, cada corrida largada no toque
  (LARGAR). Cada passo (`idle.json` → `desbloqueios`, na ordem) chega com a conversa de um
  personagem do acervo (arte de corpo inteiro): Mara (abertura, pneus, vácuo), Bianca
  (patrocínio e renda, arquibancada), Harold (largada automática, $150), Theo (ultrapassagem,
  primeira vitória), Jade (menu PILOTOS), Roxy (transmissão na TV: a corrida 3D, $1,5 mil), Rico
  (METAS), Edgar (PISTAS, quando abre o Turismo), Nora (analista: a previsão nos cartões, $6 mil),
  Kenji (mais câmeras, $15 mil) e Dex (Arena). O que custa o jogador compra; DEPOIS guarda a
  oferta no canto da corrida. Save de antes da escada abre o que a equipe já alcançou.
- **Polimento (cruzamento com as críticas do gênero, aprovado pelo usuário em 2026-10-24):**
  - vídeo que não carrega ou falha ao abrir paga a recompensa igual (a queixa mais comum do Race
    Star é o vídeo que trava e não paga);
  - intersticial só ao fechar a janela da liga nova, a partir da 4ª liga de qualquer modalidade, com
    5 min entre um e outro; nunca ao abrir o app nem entre corridas;
  - METAS (4ª aba): 3 metas do dia sorteadas pela data (correr, vencer, comprar melhorias,
    contratar, fundir, subir de liga), cada uma paga 10 min da renda;
  - avisos com o app fechado (renda no teto, contrato grátis pronto) pelo plugin Notification
    Scheduler v5.1; ligam na primeira liga nova, chave AVISOS nas Configurações;
  - o dinheiro do topo conta até o valor quando entra muito de uma vez e "+$X" sobe ao lado;
  - liga nova: a janela entra crescendo com brilho dourado e o aparelho vibra (mais forte na
    modalidade nova); piloto novo, fusão e meta dão um clarão curto;
  - cartões de motor, pneus, ultrapassagem e vácuo mostram a chegada prevista ("8º → 7º",
    "+3 NÍVEIS: 7º", "CHEGA EM 8º"), de corridas simuladas numa thread (não na Arena: a luta
    simulada leva segundos).

## O que reaproveita
- `Simulacao` (posição real, zonas de ultrapassagem, agressividade e o vácuo novo do piloto).
- Pistas (`data/pistas.json`), carros 3D da frota (`data/carros.json`), `Corrida3D` e câmeras.
- Fonte, cores e componentes de UI (`Aba`, `Tipografia`).
- A corrida como o Chrome & Wreckage mostra (2026-10-24, pedido do usuário: o CRT recebe o que o
  C&W já tem e melhora a experiência): câmera AUTO (`DiretorCamera`), painel da corrida
  (`HudCorrida`: posição que pulsa, vizinhos com diferença, classificação num toque), semáforo
  3-2-1, avisos de ultrapassagem/líder/perdeu a posição/rival se aproximando, bandeirada com a
  câmera fechando no seu carro, sons (`Sons`: motor, pneu, pelotão, torcida, bipes) e os rivais
  com piloto e pintura das equipes rivais (`data/equipes.json`, fixos por liga). Regra: toda
  melhoria de apresentação do C&W que sirva a quem só assiste entra também aqui.
- Exportação web/Android e o CI.

## O que é próprio
- `idle/` (estado, tela, calibrador) e `data/idle/idle.json` (todos os números).
- Save próprio (`user://crt.json`), sem tocar no do Chrome & Wreckage.
- O app abre direto no jogo idle com a feature de exportação `idle`.

## Laço
1. A corrida roda sozinha (10 carros, você larga em último), câmera AUTO do C&W.
2. Chegou: prêmio pela posição; a próxima corrida começa logo.
3. Renda por segundo (patrocínio e arquibancada) cai o tempo todo, também com o app fechado
   (até `offline_max_h`; o vídeo dobra).
4. Venceu na liga: PRÓXIMA LIGA libera a pista seguinte, um carro novo e prêmios maiores.

## Melhorias (cartões)
| Melhoria | O que faz na simulação |
|---|---|
| Motor | potência do carro |
| Pneus | aderência do carro |
| Ultrapassagem | agressividade do piloto (chance de tentar a passagem na zona) |
| Vácuo | velocidade extra colado no carro da frente |
| Patrocínio | renda por segundo |
| Arquibancada | renda por segundo |

## Números (estimativa, pedido do usuário: "procura na internet e chuta")
- Custo de cada nível: `base × crescimento^nível`, crescimento 1,15 — faixa comum de idle
  1,07–1,15 (Adventure Capitalist usa 1,07; Idle Idol 1,1) [gamedeveloper.com, "The Math of Idle
  Games" e "Balancing tips: Idle Idol"].
- Efeitos lineares por nível (o padrão: custo exponencial, ganho linear).
- Custos iniciais do anúncio do Race Star: ultrapassagem 40, vácuo 55, patrocínio 25,
  arquibancada 30 (print enviado pelo usuário); ultrapassagem e vácuo +4% no 1º nível.
- Metas de ritmo (estimadas): 1ª vitória em ~3 min de jogo; cada liga ~1,5× mais longa que a
  anterior. Calibradas com `tools/calibrar_idle.gd` (jogador que compra a melhoria mais barata).
- Duração: meta de 2–3 semanas para o jogo inteiro (faixa do gênero), medida em dias de
  calendário com um jogador de 4 sessões de 8 min por dia (a 1ª de 15 min) e a renda com o app
  fechado até `offline_max_h` (`tools/calibrar_idle.gd -- sessoes_dia=4`).
- Dificuldade igual em toda liga: a ficha dos rivais é a do carro da equipe com a potência de
  1,3× a 0,7× (e a aderência 0,6 disso, como Pneus × Motor) vezes a `forca_rivais` da liga,
  calibrada por `tools/calibrar_forca_idle.gd` para pedir ~12 níveis de motor com ultrapassagem e
  vácuo no máximo (pistas com poucas retas pedem rivais mais fracos). Os modelos dos rivais na
  tela continuam os da frota. Vácuo +0,4%/nível até 10 e Ultrapassagem até 12 (no 12 o piloto já
  tenta em toda reta): com +15% de vácuo o carro de fábrica passava rival 60% mais potente.
- O tempo de cada liga sai do custo: `expoente_custo_liga` 2,3 (o custo cresce mais rápido que
  prêmio e renda, que dobram a cada liga).
- Medido (2026-10-24): 1ª vitória na 5ª corrida (~5 min); ligas 1–3 na 1ª sessão; ligas 4–7 uma
  por sessão; Circuito Misto no dia 2, Mirante da Costa no 4, Anel do Vale no 8, Oval da Usina no
  14. Nas três últimas ligas o 2º lugar vem rápido e a vitória leva dias. Antes (1,25 sem
  forca_rivais) o jogo acabava em ~2 h de app aberto ou 1 dia de calendário.
- Tudo em `data/idle/idle.json`; o playtest e o teste de mercado ajustam.

## Monetização
AdMob (decisão do usuário; plugin godot-admob v5.3, Godot 4.5.1, decisão 134): vídeo premiado (dobrar a renda offline e, depois de cada corrida, "VÍDEO: PRÊMIO 2×" paga o prêmio de novo; vídeo que falha paga igual)
e intersticial só ao subir de liga (ver Polimento acima). O APK do idle sai só em arm64-v8a (a Play exige 64 bits; com o build Gradle as duas arquiteturas davam 184 MB, o pacote do jogo tem 30 MB). Ids de teste do Google até o usuário mandar os
dele.

## Som
Ver `docs/idle/sonorizacao.md`: como o gênero usa som, o que o CRT toca hoje, o que falta e a
ordem de implementação.

## Ordem
CRT1 plano · CRT2 modelo e testes · CRT3 tela · CRT4 app separado (presets e CI) · CRT5 AdMob.
