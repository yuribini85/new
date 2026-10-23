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
- Tudo em `data/idle/idle.json`; o playtest e o teste de mercado ajustam.

## Monetização
AdMob (decisão do usuário): vídeo premiado (dobrar a renda offline, dobrar o prêmio da corrida)
e intersticial entre corridas com intervalo mínimo. Ids de teste do Google até o usuário mandar os
dele.

## Ordem
CRT1 plano · CRT2 modelo e testes · CRT3 tela · CRT4 app separado (presets e CI) · CRT5 AdMob.
