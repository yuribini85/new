# THE WAY BACK — Especificação de mecânicas para implementação

Documento de referência para o Codex. Descreve **o que o jogo faz**, não como escrever o
código. Cada sistema traz: estado que precisa existir, entradas, regras, e o que persiste
no save.

Ordem = ordem de implementação sugerida. Cada bloco depende só dos anteriores.

---

## 0 · Fundação

### Sim — autoload de simulação
Único `Timer` de **1 segundo** dispara todo o jogo. Nada de lógica em `_process`.

Estado global:
```
tempo_jogo_seg      int      acumulado de jogo ativo
tempo_unix_ultimo   int      último timestamp visto
max_time_seen       int      proteção de relógio
dia_vila            int      1, 2, 3…
fase_dia            enum     MANHA | TARDE | NOITE
ato                 int      1 a 5
```

### Ciclo do dia
- **20 minutos reais = 1 dia da vila.** 16 min de claro, 4 min de noite.
- `fase_dia` muda em 0:00 (manhã), 8:00 (tarde), 16:00 (noite).
- A mudança para NOITE dispara: aldeões voltam aos alojamentos, produção para, consumo cai
  para 50%, líderes vão à taberna, efeitos noturnos ligam.
- A mudança para MANHA reverte tudo.

### Save
JSON em `user://save.json`, campo `version` desde o primeiro build, função `migrate()` em
cadeia. Salva a cada ação relevante com debounce de 2 s, mais em
`NOTIFICATION_APPLICATION_PAUSED` e `NOTIFICATION_WM_CLOSE_REQUEST`. Backup rotativo de 3.

### Offline
Fórmula fechada. **Nunca simulação retroativa.**
```
delta = clamp(agora - tempo_unix_ultimo, 0, teto_fiandeiras)
producao = taxa_por_recurso * delta * 0.8      # 0.8 = fator médio da noite
consumo  = consumo_total * delta * 0.85        # noite come menos
```
Não processa eventos, não faz órfão crescer, não avança expedição.
Se `agora < max_time_seen`, usa `max_time_seen` e credita zero.
Se `delta > 30 dias`, credita apenas o teto.

**Teto por nível da Casa das Fiandeiras:** sem a casa, **0 h**. Depois: 2, 4, 6, 9, 12, 16,
20, 24 h.

---

## 1 · Recursos

Seis. Todos inteiros, exceto os que aceitam decimal na taxa.

| Recurso | Teto | Origem |
|---|---|---|
| comida | depósito | 5 produtores |
| madeira | depósito | lenhador |
| tecido | depósito | só compra do Alfaiate |
| ouro | sem teto | venda · mina nível 6 |
| fôlego | **sem teto, fora do depósito** | só expedição |
| diamante | sem teto | compra real · anúncio |

**Teto do depósito:** 200 no nível 1, +200 por nível. Excedente é descartado com aviso.

**Índice de Fome** (0–100): sobe com estoque de comida, cai com déficit.
`penalidade = clamp(1 - (100 - indice) * 0.008, 0.30, 1.0)`
Multiplica **toda** a produção da vila. Piso de 30%. Recuperação imediata, sem carência.
Ninguém morre nunca.

---

## 2 · Edifícios

```
Edificio {
  id, nome, zona, celula:Vector2i, footprint:Vector2i
  nivel:int                 0 = ruína, 1..11
  lider_id                  fixo, imortal, não removível
  vagas_orfaos:Array        tamanho = max(0, nivel - 1)
  item_especial             0 a 3, pertencem ao EDIFÍCIO e não à pessoa
  em_obra:bool, obra_termina_em:int
}
```

**Regra central: nível é capacidade, não potência.**
```
producao_por_seg = (0.2 * n_pessoas) * bonus_aptidao * bonus_cicatriz
                   * item_especial * indice_fome
```
0,2/s = 1 unidade a cada 5 s por pessoa. Linear, sem rendimento decrescente.
Um edifício nível 5 com 1 vaga ocupada rende como nível 1.

**Custo de nível:** `base * 1.35^(n-1)`, arredondado a múltiplos de 5.
Madeira = 40% do ouro. Comida (o Gigante) = `8 * nivel`, só a partir da Cabana do Construtor.

**Tempo de obra:** 30 s no nível 1, `* 1.6` por nível. Cada pessoa na Cabana do Construtor
corta 15%.

**Marcador de vaga aberta** flutua sobre o edifício **apenas se houver adulto ocioso**.
Um por edifício. Ícone distinto do de evento.

---

## 3 · População

```
Orfao {
  id, nome, partes_visual:Dictionary, aptidao:enum, cicatriz_id, oculta:bool
  estado: CRIANCA | ADULTO_OCIOSO | ALOCADO | EM_EXPEDICAO | MORTO
  local_id, nascido_em:int, velocidade:float   # 0.9–1.1, puramente visual
}
```

**Ciclo:** chega criança → ocupa vaga no Lar → infância de 45 min (25 min nos atos finais)
→ vira adulto → precisa de vaga em Alojamento → pode ser alocado. Ao sair do Lar, libera a
vaga.

**Tetos:** Lar = 1 + 1 por nível (crianças). Alojamento = 1 + 1 por nível (adultos).
O gargalo alterna entre os dois, de propósito.

**Chegada:** 1 a cada 20 min de jogo ativo, escalando com o nível do Lar. Se não houver
vaga, o órfão **espera visivelmente na borda do mapa** e não entra.

**Consumo por minuto:** criança 1 · adulto 1,5 · líder 1,5 · anão 2. Noite = 50%.
A partir do Ato IV, tudo sobe 20%.

**Aptidões (6):** campo, cozinha, água, oficina, braços, letras. +25% no grupo
correspondente.

**Cicatrizes (20):** 15 visíveis, 5 ocultas. 35% chegam sem nenhuma.
Tags: origem, domínio, `incompativel_com`, `sinergia_com`. Cota por domínio no sorteio.
**Sem cura.** Duas ou três frases de origem sorteáveis por cicatriz.

**Despacho:** só adultos, na taberna. Cena sempre igual. Custo em moral que decai com o
tempo — despachar em série dói mais que uma vez.

---

## 4 · Rotas e sprites

**Desacoplado da economia.** A produção acontece por tempo fixo no edifício; o trajeto é
apresentação e não influencia número nenhum.

- Todo produtor faz rota até o **Depósito**. Frequência proporcional à produção.
- Caminhos com curva, nunca retas convergentes.
- Sprite carrega algo visível na ida ou na volta.
- Ponto de entrega **na borda** do depósito, não no centro.

**Colisão — cortesia, não física.** Sem `CharacterBody2D`. Cada agente checa um raio curto
à frente; quem tem prioridade menor para 0,5 s. Prioridade: anão com minério > adulto >
criança; o Gigante nunca para e todos desviam dele. Desempate por id. **Atravessa após 2 s**
para nunca travar.

**Velocidade** 0,9–1,1 sorteada por indivíduo, mais variação por tipo. Só a Lerdeza é
visivelmente lenta de propósito.

---

## 5 · Floresta

```
Arvore { celula:Vector2i, offset:Vector2, estado: DE_PE | TOCO, variante:int }
```

Geração por **semente fixa salva no save**, em grade com deslocamento aleatório dentro da
célula. Distância mínima entre árvores, mais densa longe da vila. Só as do raio de trabalho
são entidades; o resto é textura de terreno.

**Corte:** o Lenhador pega a árvore cortável **mais próxima da cabana**, não dele — o
desmatamento cresce em anel. Vários trabalhadores pegam alvos diferentes; se dois mirarem a
mesma, o segundo reavalia.

**Regeneração:** só à noite, e **contínua, não por limiar**:
```
taxa_reposicao = base * (1 - fracao_de_pe)^2
```
Corte é mais rápido que reposição no começo; as taxas se encontram perto de 30% de mata
restante. A reposição prioriza o **anel próximo à cabana** — o piso precisa ser espacial.

**Animação:** 3 a 4 frames de crescimento, com tremor no chão antes. Em regeneração massiva,
escalonar em onda da borda para a vila. Árvore nova é mais fina, torta e escura.

**Herbalista:** colhe arbustos sem destruí-los — a moita fica vazia e volta em horas.
**Pescador:** ponto fixo, e deve ficar parado bastante tempo.
Os três compartilham o mesmo código de coleta, mudando alvo e animação.

---

## 6 · Expedições — modelo Melvor

```
Expedicao {
  regiao_id, equipe:Array[id], mochilas:Dictionary[id -> Inventory]
  inicio_unix, duracao_seg, estado: EM_CURSO | CONCLUIDA
}
```

**Corre com o app fechado**, por timestamp. Uma por vez.

| Região | Requisito | Duração | Aldeões | Fôlego | Risco/indivíduo |
|---|---|---|---|---|---|
| Orla da mata | — | 5 min | 0 | +5 | 0% |
| Trilha velha | tier 1 | 20 min | 1 | +8 | 6% |
| Vale fundo | tier 2 | 1 h | 2 | +14 | 12% |
| Rio negro | tier 3 | 3 h | 3 | +25 | 20% |
| Mata cega | tier 4 | 8 h | 5 | +40 | 30% |

**Riscos dobrados** em relação à primeira estimativa — a original produzia só 0,1 morte por
hora e não gerava giro nenhum.

**Travas de morte:** nunca mais da metade da equipe; nunca Maria nem Pele-de-Urso; nunca o
primeiro da lista. Sorteio ponderado por cicatriz (Ossos frágeis ×2, Passos leves −40%,
Não deixa ninguém para trás −70% para os outros).

**Falha por requisito:** volta cedo e vazia, com Maria explicando. Perde tempo, nunca gente.

**Mochilas:** GLoot com `GridConstraint`, peças retangulares. Uma por expedicionário —
Maria é a referência, Pele-de-Urso um pouco menor, órfão ~metade, variando por cicatriz.
Tamanho representa peso. Preenchimento automático destravado por pergaminho, e **nunca
ótimo**: preenche só o essencial.

**Relatório:** tela cheia ao voltar. Uma linha fixa de dados e uma linha variável na voz da
Maria (12 por região). Botão de anúncio recupera **um** morto, válido só enquanto a tela
estiver aberta, pela Senhora Holle e pelo poço.

---

## 7 · Mina e anões

Ruína + 7 níveis. **Não gera recurso passivo** — destrava capacidade.

| Nível | Minério | Abre |
|---|---|---|
| 1 | pedra | infraestrutura |
| 2 | carvão | acende a forja |
| 3 | ferro | tier 1 das 5 linhas |
| 4 | bronze | tier 2 |
| 5 | prata | tier 3 · mãos da Menina sem Mãos |
| 6 | ouro | tier 4 · torneira modesta de ouro |
| 7 | pedra branca | fim do jogo |

**Ciclo do anão:** Maria alcança a região fixa → jogador melhora a Casa dos Anões → o anão
entra → a mina sobe um nível → cinco ou seis edifícios destravam ao mesmo tempo.

**Cadeia escalonada em degrau:** o anão do nível N é alcançável com o equipamento que o
nível N−1 permitiu. **Testar cada linha** — é o deadlock mais provável do jogo.

Fôlego por anão: 40 · 90 · 160 · 260 · 400 · 600.

---

## 8 · Produção e venda

**Cinco linhas vendáveis**, quatro tiers cada:
espada (sem insumo), escudo e arco (madeira), roupa e sapato (tecido).

**Preços base:** madeira 1 · vegetais 1 · carne 2 · pão 3 · espada tier 1 = 15 · tier 4 = 900.

**Ouro só entra por venda**, no Mercado e ao Alfaiate. Única exceção: torneira modesta a
partir da mina nível 6, que **nunca pode render mais que a venda**.

**Alfaiate:** passa 1× por dia da vila, fica 5 min. Oferece preço; recusar mexe no preço do
dia seguinte. Lote generoso de tecido com desconto por volume, para não punir quem joga
pouco. Estoque responde ao estado do mundo.

---

## 9 · Eventos

**Um por vez até o Ato III. Dois a partir do IV, três no V. Nunca dois do mesmo eixo.**
Carência de 40 min entre eventos.

| Evento | Eixo | Efeito | Quebra |
|---|---|---|---|
| Irmão-cervo | pessoa | ocupa lote, não produz | custo alto |
| Pele que não sai | moral | +produção, teto de moral | ritual de fogo |
| Sono | área | uma ala não produz | evento |
| Chuva de piche | produção | −30% global | completar a entrega da Holle |
| Ratos | produção | 5% → 50% conforme população | Flautista |
| Casa que apodrece | história | único, Ato III | expedição à clareira |

**Ratos:** crescem continuamente a partir do Ato II. 5% até 30 min, 15% até 90, 30% até 150,
50% depois. **O Flautista aparece aos 20%.** Preço = 2× o custo de um nível médio do ato.
Não pagar leva os órfãos (recuperáveis). **Sem órfãos, sem penalidade** — e essa esperteza
é conteúdo, não exploit.

**Demanda da Holle:** 2 por ato, 3 estados. Aberta (prazo de 1 dia da vila) → cumprida
(chuva de ouro + bônus) ou esgotada (chuva de piche até completar). **Não empilha:** a
segunda espera a primeira. Ela sempre pede o que a vila **acabou de aprender a produzir**.

---

## 10 · Torre do Vigia

Edifício independente da mina. **Único sem líder fixo** — os cinco postos são de órfão,
todos noturnos, e por isso ela **pode ser apagada**.

| Nível | Entra | Efeito |
|---|---|---|
| 1 | vigia | observação, sem consumo |
| 2 | +1 | braseiro aceso, **consome madeira por noite** |
| 3 | +1 | chama alta, mais alcance e mais consumo |
| 4 | +1 | espelho girando à mão |
| 5 | +1 | espelho maior, dois girando |

**Bônus:** alcance para expedições **em curso** (não para as que vão sair), e redução de
maldição com **teto de 40%**, nunca contra maldição de história.

**A luz não afasta nada.** Nenhum efeito sobre lobos, sombras ou olhos.

---

## 11 · Noite e atmosfera

Sete camadas, cada uma com limiar próprio ligado ao **índice de fome**: olhos, sombras,
árvores que andam, luzes falhando, corvos, lobos, e a bruxa (irrepetível).

**Nada disso tem consequência mecânica.** Se um lobo roubasse comida, o jogador ficaria
vigiando e a noite viraria tarefa.

**Noites vazias existem**, no máximo 2 ou 3 em sequência, e a primeira noite do jogador
sempre tem algo.

**Chuva:** shader de tela cheia, três presets (normal, ouro, piche), inclinação acompanhando
o eixo isométrico. Clima normal em ~20% dos dias, 3 a 8 min, **nunca com ouro ou piche
ativo**. As duas especiais nascem do poço com máscara radial. Piche deixa mancha nos
telhados até a entrega.

**Vento:** variável global alimentando o shader de vértice das árvores, as partículas e a
inclinação da chuva. Para completamente no fim do Ato V.

**Sol:** um ângulo global alimenta sombras (cópia achatada do sprite), a curva de cor do
`CanvasModulate` e as aves.

---

## 12 · Diálogo

```
Bloco { id, speaker, emocao, text_key, action:{tipo, arg} }
```
13 tipos de ação: none, next, unlock, highlight, give, take, start_quest, end_quest,
open_screen, spawn, cutscene, wait, end.

Retrato grande com caixa embaixo. Seis emoções para os seis que mais falam, três para os
demais. **Grunhido por personagem na troca de falante**, pitch 0,92–1,08. Narrador não tem
som.

**Localização desde a primeira linha:** chaves semânticas em CSV, nada de concatenação,
caixa dimensionada para 40% mais texto que o inglês.

---

## 13 · Monetização

**Sem banner.** Rewarded video apenas.

**Rumpelstiltskin** aparece só em gargalo real, com balão em forma de contrato e botão
**Assinar**. Ofertas: lucro de 1 h, pergaminho sem expedição, tecido de emergência.
Compra única remove anúncios para sempre e dá bonificação permanente.

**Músicos de Bremen** no gazebo: anúncio ou pagamento dobra a produção por um período.

**Diamante nunca compra:** recurso direto, tier de equipamento, anão, vaga de expedição.
Compra **tempo**: acelerar leitura 10, obra 15, expedição 20, tecido 25, recuperar órfão
extra 40.

**Sem internet:** o jogo funciona inteiro. Rumpelstiltskin aparece dizendo que hoje não
trouxe nada e some. Nunca deixar botão de anúncio que falha ao ser tocado.

---

## Ordem de implementação

1. **Fundação** — Sim, ciclo do dia, save, offline
2. **Dados** — carga dos JSON de balanceamento, modelo de edifício genérico
3. **Mapa** — lotes fixos de `vila_lotes.json`, ruínas, construção
4. **Economia** — recursos, produção, teto, índice de fome, venda
5. **População** — órfãos, cicatrizes, alocação, tela de aldeões
6. **Rotas** — sprites, colisão por cortesia, floresta e coleta
7. **Expedição** — regiões, mochilas, risco, relatório
8. **Mina** — sete níveis, anões, tiers
9. **Eventos** — maldições, ratos, Holle
10. **Atmosfera** — noite, chuva, vento, sol, filtro
11. **Diálogo e monetização**

---

## Os três pontos onde isso mais provavelmente quebra

1. **Deadlock da cadeia anão↔equipamento.** Testar cada degrau explicitamente.
2. **Offline com muitos dias.** Confirmar que o teto trunca antes de qualquer laço.
3. **Reposição de órfão menor que a taxa de morte.** Com risco dobrado, conferir que a
   chegada cobre as baixas em todas as regiões.
