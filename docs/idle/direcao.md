# Chrome Racing Team: direção (fantasia, tom e linguagem visual)

> **2026-10-27:** a fantasia (item 1) e a paleta (item 3) foram substituídas pela conversão máfia
> americana 1946–1955 (`docs/idle/conversao_mafia.md`). Seguem valendo a transmissão como linguagem,
> o complexo da equipe e os números que pipocam.

Aprovado pelo usuário em 2026-10-27 (`docs/idle/comparacao_white_foot.md`). Este documento é a
referência da reconstrução da camada de apresentação. A simulação, a economia por ligas, o save, o
som e as ferramentas continuam.

## 1. A fantasia em uma frase
**Mara herdou uma oficina falida e um carro velho; Sal Moretti, o dono da equipe rival, comprou a
pista da cidade e quer a oficina dela também.** Você é o chefe que transforma o fundo de quintal
numa equipe de fábrica e tira o Sal do caminho, liga a liga.

- **Protagonista do lado de lá da tela:** Mara Hayes (chefe dos mecânicos). Fala com você, reage ao
  que você faz e tem humor seco.
- **Antagonista:** Sal Moretti (camisa estampada, chaves na mão, sorriso de vendedor). Aparece nas
  ligas, provoca, perde com estilo. É o humor do jogo, e nunca é cruel.
- **Elenco:** os personagens do acervo viram os chefes das estações e as visitas: Bianca
  (patrocínio), Harold (diretor de prova), Theo (piloto veterano), Jade (agente de pilotos), Roxy
  (diretora da emissora), Kenji (cinegrafista), Nora (analista), Rico (gerente), Edgar
  (organizador) e Dex (Arena).

## 2. Tom
Comédia de oficina com coração: suor, graxa, gambiarra que dá certo e um rival exibido. Frases
curtas e uma piada por cena, no máximo. O jogador é sempre "chefe". Vale o vocabulário de
`docs/vocabulario.md`: um nome por coisa, o texto exato do botão, nada de termo interno.

## 3. Linguagem visual: a transmissão
Tudo o que é interface é o pacote gráfico da emissora da Roxy, que cobre a ascensão da equipe.

- **Torre de tempos** à esquerda na corrida (posição, abreviação do piloto, diferença).
- **Lower third** (faixa inferior) com nome e frase de quem fala; substitui a caixa de conversa.
- **Vinheta** de liga nova e de vitória (cortina com o logotipo, 1,5 s).
- **Selo AO VIVO** e relógio no canto; replays com a moldura da TV.
- **Mapa de cronometragem:** a vista de cima com pontos é o gráfico de cronometragem da emissora
  (traçado em linha fina luminosa, pontos com número, líder destacado).

**Paleta:**

| Uso | Cor |
|---|---|
| Fundo | #0B0E13 |
| Painéis da TV | #11161D (90%) |
| Cromo | #C9CED6 |
| Ouro das ações | #FFC53D → #F08A0C |
| Vermelho do AO VIVO e do rival | #E5484D |
| Verde do ganho | #6FD08C |

Herdada da paleta cromo + ouro atual, para não começar do zero.

**Fontes:** uma condensada pesada para números e títulos de TV e uma legível para texto. As do
projeto: Racing Sans One para os números e Barlow Condensed para o texto. Big Shoulders fica para
as vinhetas.

**Personagens:** a arte low-poly facetada do acervo (corpo inteiro). O cenário do complexo segue o
mesmo facetado (planos chapados, duas ou três luzes), para tudo parecer do mesmo mundo.

## 4. O complexo da equipe (tela principal)
Um corte vertical contínuo que rola, como um prédio visto de lado. Cada andar é uma estação; o
carro e o box ficam no térreo, e a corrida passa num telão da emissora no alto.

| Andar | Estação | Melhoria de hoje | Chefe |
|---|---|---|---|
| Térreo | Box (o carro, o pit stop) | — | Mara |
| 1 | Oficina de motores | Motor | Harold |
| 2 | Banco de pneus | Pneus | Theo |
| 3 | Simulador do piloto | Ultrapassagem | Jade |
| 4 | Túnel de vento | Vácuo | Nora |
| 5 | Sala dos patrocinadores | Patrocínio | Bianca |
| 6 | Arquibancada e camarote | Arquibancada | Rico |

- **Cada estação tem gente trabalhando:** a peça pronta desce pelo elevador de carga até o box e
  vai para o carro.
- **No começo, o toque é do jogador:** tocar na estação monta a peça e tocar no box faz o pit stop.
  O chefe da estação automatiza depois.
- **Andar novo entra no escuro:** um mecânico chega, acende as luzes, e só então o andar abre.
- **As estações envelhecem nos níveis 25, 50 e 100:** a gambiarra vira bancada e depois fábrica.

## 5. Números que pipocam (feito, `idle/efeitos_idle.gd`)
- **Compra:** o botão afunda e salta com clarão e solta faíscas; o nível novo pipoca acima e o "×N"
  cresce nas compras seguidas.
- **Dinheiro do topo:** salta e mostra "+$" ao lado quando entra prêmio.
- **Renda:** pipoca de leve no topo.
- **Botões:** o que passa a poder ser tocado pulsa uma vez.
- **Corrida:** o pódio solta faíscas.

## 6. Ordem de construção
1. Maquetes destas telas (`docs/idle/maquetes/`): título, abertura, complexo e corrida na TV. Aprovação do usuário.
2. Título e abertura. **Feito** (`idle/titulo_idle.gd`, `idle/abertura_idle.gd`). Pedido do
   usuário: abertura dinâmica e rápida como a do White Foot. Uma cena desenhada de ~12 s com um
   toque:
   - o carrão do Sal derrapa na porta da oficina (tremor e fumaça) e ele pede a assinatura;
   - o contrato espera o toque; o toque rasga o contrato e o papel voa;
   - "Você vai se arrepender!", e ele arranca;
   - o portão da oficina sobe aos trancos, a Mara aparece ao lado do carro velho: "Chefe, é com
     você";
   - corte para a corrida, com o LARGAR destacado.
3. Complexo: andares com chefe, cenário facetado, +1/+10/MÁX. e fases visuais nos níveis
   10/25/50. **Feito** (`idle/andar_idle.gd`). Falta: box no térreo, toque antes da automação e o
   ×2 de produção nos marcos (pede economia sem teto, a rebalancear).
4. Corrida na TV: torre de tempos, lower third e vinhetas.
5. O resto das estações, chefes com traço, retenção (baú, encomendas, evento tocável), anúncio na
   história e Nova Temporada.
