# THE WAY BACK — Segunda rodada de dúvidas

A primeira rodada resolveu *como o jogo é feito*. Esta resolve *o que acontece e quando* — é a
camada que o Codex não consegue inventar e que define se o jogo é bom ou apenas funcional.

Mesma regra: tudo já vem pré-respondido. Altere o que quiser.

---

## BLOCO 11 — A ordem de desbloqueio ⚠

É o roteiro do jogo em forma de tabela e a decisão mais importante que resta.

**Proposta para o Ato I**, na ordem em que o jogador vê:

| # | Construção | Destrava por | Motivo do lugar na fila |
|---|---|---|---|
| 1 | Cabana do Lenhador | início | Madeira é insumo de tudo |
| 2 | Horta | 1ª construção concluída | Primeira comida |
| 3 | Alojamento | 1º órfão chega | Sem ele o órfão não trabalha |
| 4 | Depósito | estoque no teto inicial | O jogador sente o teto antes de destravar |
| 5 | Lar dos Órfãos | 2º órfão chega | Abre o fluxo de chegada |
| 6 | Curral dos Animais | Horta nível 3 | Segunda fonte de comida |
| 7 | Mercado | primeiro excedente vendável | Primeiro ouro |
| 8 | Cabana do Construtor | 4 construções erguidas | O Gigante entra e a comida vira custo de obra |
| 9 | Padaria | Horta + Curral nível 3 | Terceira comida, e o pão é o marco de vila viva |
| 10 | Casa das Fiandeiras | fim do Ato I | O offline nasce aqui |
| 11 | Gazebo | após as Fiandeiras | Os Músicos chegam e fecham o ato |

**Ato II** abre com a Cabana da Expedição, e logo depois o anão procura o João: Mina, Casa dos
Anões, Forja. Depois Taberna, Cabana de Pesca, Vendedor de Armas, Alfaiataria, Sapataria.

**Ato III**: Biblioteca, Herbalista, Curandeiro, Moinho, Cemitério, Poço.

*Pergunta real:* a Casa das Fiandeiras deveria vir **antes** do Gazebo, ou o buff dos Músicos é
uma recompensa melhor para fechar o ato?

---

## BLOCO 12 — Os primeiros trinta minutos ⚠

O único trecho que precisa estar coreografado segundo a segundo.

- **0:00** Cutscene curta: a fuga, a casa, os pais mortos. Três telas, texto curto.
- **0:30** João fala. Aponta a cabana do lenhador em ruína. O jogador toca e constrói.
- **1:30** Primeira madeira entrando. João explica o depósito enchendo.
- **3:00** Um corvo pousa na horta em ruína. O jogador **enxota clicando** — primeira interação
  ativa, antes mesmo da horta existir.
- **4:00** Horta liberada.
- **7:00** Primeiro órfão aparece na borda do mapa e fica parado. Não entra até haver alojamento.
- **10:00** Alojamento. O órfão entra, ganha nome sorteado na frente do jogador.
- **15:00** Primeiro teto de depósito atingido. Frustração desenhada.
- **20:00** Mercado, primeiro ouro.
- **25:00** Segundo e terceiro órfãos. A comida começa a apertar.
- **30:00** O jogador fecha o app pela primeira vez — e **não ganha nada offline.** É a lição.

*Pergunta real:* o primeiro órfão deveria esperar visivelmente na borda, ou isso é cruel demais
para o minuto sete?

---

## BLOCO 13 — Volume de texto

Estimativa do que precisa ser escrito antes do primeiro build:

| Tipo | Quantidade | Nota |
|---|---|---|
| Falas do João (tutorial + reação a eventos) | ~60 | A voz mais presente do jogo |
| Falas da Maria (partida e retorno) | ~40 | Metade é o relatório variável |
| Linhas de expedição por região | 12 × 5 = 60 | Sorteadas |
| Falas dos líderes de edifício | 3 cada = 45 | Ditas ao abrir o painel |
| Nomes de órfão na roleta | 120 | 60 masculinos, 60 femininos, de raiz germânica |
| Descrição dos 50 itens especiais | 50 | Uma linha cada |
| Interface e rótulos | ~150 | Vai para o CSV de tradução |

*Pergunta real:* os nomes dos órfãos devem ser germânicos autênticos (Adelheid, Wenzel, Griet) ou
aportuguesados? Autêntico dá textura; aportuguesado é mais legível para o público brasileiro.

---

## BLOCO 14 — Ritmo dos eventos

Proposta de frequência, para nenhum evento pisar no outro:

- **Demanda da Holle:** 2 por ato, com aviso e prazo de 1 dia da vila (20 min).
- **Ratos:** crescimento contínuo, começando no Ato II. Chegam a 50% de penalidade em ~3 h
  de jogo ativo se ignorados.
- **Flautista:** só aparece quando os ratos passam de 20% de penalidade.
- **Maldições:** no máximo **uma ativa por vez**, com carência de 40 min entre elas.
- **Alfaiate:** 1 por dia da vila, fica 5 min, com aviso sonoro.
- **Gigante atravessando o mapa:** raro e puramente decorativo, ~1 a cada 2 h.

*Pergunta real:* uma maldição ativa por vez é conservador. Duas simultâneas no Ato IV e V
aumentariam a pressão final — vale abrir a exceção?

---

## BLOCO 15 — O que acontece quando o jogador erra feio

Idle precisa de fundo do poço definido, senão o jogador desiste em vez de se recuperar.

- **Comida zerada:** produção geral cai ao piso de 30%. Ninguém morre. As cinco fontes de comida
  continuam produzindo normalmente, então a vila sempre se recupera sozinha — só devagar.
- **Todos os adultos mortos em expedição:** as crianças continuam crescendo. O jogo nunca fica
  sem saída.
- **Ouro zerado com estoque cheio:** o Mercado sempre compra. Não existe estado sem venda possível.
- **Save corrompido:** backup rotativo de 3 saves.

*Pergunta real:* deveria existir um piso de comida abaixo do qual a vila **para de receber
órfãos**? Seria coerente — não se acolhe quem não se pode alimentar — mas é uma espiral.

---

## BLOCO 16 — Diamante e a economia premium

Ficou definido que diamante vem de compra real e de Rumpelstiltskin. Falta o quê ele compra:

**Proposta:** aceleração de obra, tecido em emergência, um slot extra de expedição simultânea,
e recuperação de órfão além do primeiro. **Nunca:** recursos direto, nem tier de equipamento,
nem anão. O que o dinheiro compra é **tempo**, nunca progresso que o jogador não fez.

*Pergunta real:* o slot extra de expedição é a única coisa da lista que altera o ritmo do jogo de
verdade. Mantém ou corta?

---

## BLOCO 17 — Coisas que eu ainda não sei como você quer

1. **A Maria tem tela própria** de equipamento, ou o equipamento dela é automático conforme o tier
   mais alto disponível? Automático é mais limpo; manual dá decisão.
2. **O jogador nomeia a vila?** Custa nada e cria apego.
3. **Existe algum tipo de conquista ou coleção visível** além do bestiário e dos itens especiais?
4. **A Marca aparece na Cabana da Expedição** como pistas acumuladas, ou só na Biblioteca?
5. **O que o jogador vê quando toca a casa de João e Maria?** É a única construção sem função.
   Sugestão: um painel com o resumo da história até ali — e é onde a lore vive.

---

## O que eu faria a seguir

Fechar o **Bloco 11** e escrever a **tabela de custos e tempos do Ato I** — onze construções,
com custo inicial, curva, tempo de produção e o que cada nível destrava. É o último documento
antes de o Codex conseguir gerar algo jogável.
