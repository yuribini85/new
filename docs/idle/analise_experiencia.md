# Chrome Racing Team: análise da experiência (2026-10-24)

Pedido do usuário: "ainda não estou satisfeito com a experiência do jogo, quero uma análise sua".
Método: um jogador robô (`tools/jogar_idle.gd`) começou um save novo e jogou 25 minutos como uma
pessoa atenta (lê cada conversa em 3 s, larga no toque, compra a melhoria mais barata, aceita a
oferta quando tem o dinheiro, sobe de liga), com a linha do tempo e uma foto por minuto e por marco.

## Linha do tempo medida

| Tempo | O que aconteceu |
|---|---|
| 0:00 | Mara; LARGAR; só o Motor |
| 1:16 | 1ª corrida: 6º, +$150 |
| 2:26 | Pneus (Mara) |
| 4:52 | Patrocínio (Bianca) |
| 7:36 | Largada automática, $150 (Harold) |
| 12:08 | **1ª vitória**, na 10ª corrida; Ultrapassagem (Theo); SUBIR DE LIGA |
| 13:26 | PILOTOS (Jade) |
| 14:37 | TV por $1,5 mil (Roxy): faltam $683, AGORA NÃO |
| 16:50 | 2ª liga vencida |
| 18:11 | Vácuo e Arquibancada (duas conversas seguidas) |
| 21:58 | Compra a TV |
| 23:59 | 3ª liga vencida |

21 corridas, 170 compras, ~70 s por corrida (3 s de semáforo, a volta e 4 s de pausa).

## O que pesa na experiência (em ordem)

1. **O jogador não sabe o objetivo.** Nada na tela diz "vença para subir de liga" nem mostra quão
   perto está. A 1ª vitória chegou em 12 min, na 10ª corrida; o plano mediu a 5ª (~5 min) antes
   da escada de desbloqueios, do LARGAR manual e das ofertas, e o ritmo não foi recalibrado.
2. **Comprar não muda o resultado de um jeito que se veja.** Posições em sequência: 6, 3, 5, 4, 9,
   9, 2, 7, 2, 1. Motor em +70% e o carro chega em 6º. A melhoria é um percentual abstrato
   ("+55% › +60%"); a única ligação entre compra e posição é a previsão do Analista, que custa
   $6 mil e chega na liga 4.
3. **Renda escondida.** `renda_base` ($5/s) corre desde o primeiro segundo, sem aparecer na tela
   (o POR SEGUNDO só abre com o Patrocínio). Nos primeiros 5 min ela rende ~$1,4 mil e as
   corridas ~$0,8 mil: o dinheiro vem mais do relógio que das corridas, contra o "a evolução
   acontece por causa do jogador".
4. **A vista de cima é pobre por tempo demais.** Por ~22 min a tela é um retângulo cinza com
   pontos sobre fundo preto. A TV, a maior recompensa visual, compete com as melhorias pelo mesmo
   dinheiro e o jogador que compra melhorias chega a ela só depois da 3ª liga.
5. **Toda melhoria parece igual.** Seis cartões com o mesmo formato e percentual; a melhor
   estratégia é comprar o mais barato, sem escolha. Na liga nova Motor e Pneus voltam a Nv. 0
   ("Nv. 25" vira "Nv. 0"), o que lê como perda.
6. **Anúncio a cada corrida.** PRÊMIO x2 aparece a cada ~70 s, por cima da pista.
7. **O botão de anúncio não dizia que era anúncio** (corrigido, ver abaixo).

## Proposta (a decidir; os números vêm da referência ou do calibrador)

1. **Objetivo sempre visível:** uma faixa no topo da corrida com o alvo da liga ("VENÇA PARA SUBIR
   DE LIGA") e a melhor posição já alcançada; recalibrar a 1ª liga para a 1ª vitória voltar à
   meta do plano (critério: `tools/calibrar_idle.gd` com o robô de agora, meta "1ª vitória em
   ~3 min de jogo" que já está no plano).
2. **Compra ligada ao resultado:** a previsão básica ("CHEGA EM 8º") desde o começo, de graça; o
   Analista passa a vender a previsão de +3 níveis. Menos sorte nas primeiras ligas (o mesmo
   carro não pode ir de 2º a 7º seguidos), para a compra se ver na corrida seguinte.
3. **Renda só com o Patrocínio:** `renda_base` zero até a conversa da Bianca.
4. **Vista de cima mais rica** (pista com zebras, largada, rastro dos carros, o seu destacado com
   nome) e a TV mais cedo na escada, ou a 1ª corrida de uma liga nova na TV como amostra.
5. **Cartões com o efeito na língua da corrida** ("+12 km/h na reta", "freia mais tarde") e o
   carro novo da liga apresentado como ganho ("SEU CARRO NOVO: +40% de potência").
6. **PRÊMIO x2 com menos frequência:** só nas corridas que pagam bem (pódio) ou a cada N corridas,
   pelo padrão da referência.

## Feito nesta etapa

- **Botão de anúncio** (pedido do usuário): verde em duas partes, selo com o ícone de vídeo grande
  e a palavra VÍDEO, e a recompensa ao lado (PRÊMIO x2, COLETAR x2, CONTRATAR · 5 HOJE); sai o
  "CONTRATAR GRÁTIS" do botão de anúncio. Regra em `docs/idle/interface.md`, seção 5.
- **Defeito:** o "+$" que sobe ao lado do dinheiro quebrava no fim da corrida (fonte inexistente);
  corrigido.
- `tools/jogar_idle.gd`: o jogador robô, para medir de novo depois de cada mudança.

## Feito na 2ª etapa (aprovada pelo usuário: itens 1, 2 e 3)

- **Objetivo à vista:** faixa entre a corrida e os cartões com VENÇA PARA SUBIR DE LIGA (VITÓRIA!
  SUBA DE LIGA depois de vencer) e a MELHOR chegada na liga.
- **Sem sorte na passagem:** a sorte vinha quase toda do sorteio de cada reta (o piloto tenta ou
  não passar). No CRT a tentativa virou regular (`Simulacao`: `piloto.regular`, só no CRT; o C&W
  segue igual) e só conta onde dá para passar. Medido: a mesma equipe chega sempre no mesmo lugar,
  e Motor e Ultrapassagem movem a posição degrau a degrau (antes: ±2,5 posições de uma corrida
  para a outra). Resta ±1 em poucos casos (15 de ~240 combinações) pela física da corrida.
- **Ultrapassagem desde a 1ª corrida** (Theo): sem ela o carro não passa do 7º; antes ela só
  abria na 1ª vitória, que dependia de sorte.
- **Previsão de graça:** "8º › 7º" / "CHEGA EM 4º" desde o começo (agora exata); o Analista vende
  a chegada com três níveis a mais.
- **Renda só com o Patrocínio.**
- **Uma conversa por corrida** (Vácuo, Arquibancada e TV chegavam juntas).
- 1ª liga mais fácil (força dos rivais 0,85 → 0,55).

Medido de novo (robô, 20 min): chegadas 7º, 4º, 4º, 4º, 4º, **1º** (6ª corrida, 8 min; antes 10ª,
12 min) e na 2ª liga 7º, 4º, 3º, 2º, 1º. A 3ª liga chega aos 14 min (antes 17).

**O que ainda pesa:** cada corrida leva ~80 s (semáforo, uma volta e a pausa), o que faz a 1ª
vitória levar 8 min mesmo com 6 corridas; e Ultrapassagem muda a posição em degraus de 3–4 níveis
(entre um degrau e outro a compra só aparece no "CHEGA EM"). Próximos itens da proposta: 4 (vista
de cima), 5 (cartões na língua da corrida), 6 (PRÊMIO x2 menos frequente) e a duração da corrida.
