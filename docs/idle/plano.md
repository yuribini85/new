# Chrome Racing Team — plano do teste de mercado

Segundo app do mesmo projeto Godot (decisão do usuário, 2026-10-23): um idle de equipe de corrida
no modelo do Race Star (Cool Cats Games) e parecidos, feito com o que o Chrome & Wreckage já tem
(carros 3D, pistas, câmeras, simulação, salvamento, compras e exportação). Objetivo: publicar
rápido para medir custo por instalação e retenção; o Chrome & Wreckage segue sendo o jogo
principal.

## O jogo em uma frase
Sua equipe larga em último numa corrida que roda sozinha; o dinheiro da corrida e dos
patrocinadores compra melhorias; ao vencer, a equipe sobe de liga, ganha um carro melhor e uma
pista nova, e os rivais ficam mais fortes.

## O que reaproveita
- `Simulacao` (posição real, zonas de ultrapassagem, agressividade e o vácuo novo do piloto).
- Pistas (`data/pistas.json`), carros 3D da frota (`data/carros.json`), `Corrida3D` e câmeras.
- Fonte, cores e componentes de UI (`Aba`, `Tipografia`).
- Exportação web/Android e o CI.

## O que é próprio
- `idle/` (estado, tela, calibrador) e `data/idle/idle.json` (todos os números).
- Save próprio (`user://crt.json`), sem tocar no do Chrome & Wreckage.
- O app abre direto no jogo idle com a feature de exportação `idle`.

## Laço
1. A corrida roda sozinha (10 carros, você larga em último), câmera de cima da pista inteira.
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
AdMob (decisão do usuário; plugin godot-admob v5.3, Godot 4.5.1, decisão 134): vídeo premiado (dobrar a renda offline e, depois de cada corrida, "VÍDEO: PRÊMIO 2×" paga o prêmio de novo; quem viu o vídeo não vê o intersticial seguinte)
e intersticial entre corridas com intervalo mínimo. Ids de teste do Google até o usuário mandar os
dele.

## Ordem
CRT1 plano · CRT2 modelo e testes · CRT3 tela · CRT4 app separado (presets e CI) · CRT5 AdMob.
