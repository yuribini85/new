# Plano de ação — primeiro teste com pessoas (2026-10-21)

Testadores: 3 (12–14 anos, dois jogam Brawl Stars todo dia, um joga RPG de mundo aberto). Todos
acharam o jogo bom e bem feito. As reclamações, da maior para a menor, e o plano para cada uma.
Nada aqui foi implementado: este documento existe para as decisões virem antes do código.

## Ordem de execução recomendada

| Fase | O quê | Por quê nessa ordem | Tamanho |
| --- | --- | --- | --- |
| 0 | Desempenho: APK Android para os testes + medição por aparelho | Sem rodar liso, nenhum outro teste é confiável (3) | 2–4 dias |
| 1 | Corte de diálogos e tutorial | Barato, sem risco, melhora o primeiro minuto (4) | 1–2 dias |
| 1 | Cartões de carro com identidade (parte rápida) | Barato e visível em todas as telas (2) | 2–3 dias |
| 2 | Protótipo de controle na corrida, numa pista | A maior reclamação muda o conceito do jogo: provar antes de reescrever (1) | 1 semana |
| 3 | Controle completo + arte dos carros + otimizações finas | Só depois do protótipo aprovado no teste | 3–5 semanas |

A fase 1 e o protótipo da fase 2 podem correr em paralelo assim que as decisões abaixo saírem.

## 1. "Queremos controlar o carro" (maior reclamação)

**O que muda:** o conceito escrito no README e em `docs/conceito.md` diz que o jogador decide e a IA
executa ("corridas automáticas"). Atender a reclamação muda essa regra: **é decisão sua** (D1). Os
cartões de jogada que já existem (decisão 117) não bastaram: são pausas raras, não controle.

**Opções:**

- **A. Pilotagem por toques (recomendada).** A corrida continua com a mesma pista, IA dos rivais e
  progressão, mas o jogador conduz nos pontos que decidem uma volta:
  - *Frenagem:* antes de cada curva aparece a marca; tocar na hora certa dá entrada perfeita, cedo
    perde tempo, tarde escapa da linha.
  - *Saída:* segurar para acelerar; soltar cedo demais perde tração.
  - *Ultrapassagem:* no vácuo de um rival, um botão de ataque com recarga.
  - Sem toque, o piloto contratado dirige sozinho (o nível dele é o "piloto automático"). A
    habilidade do jogador soma por cima, com teto: carro fraco não vence só com dedo, para o carro,
    as peças e o piloto continuarem valendo (a progressão do jogo de referência fica).
  - O idle não some: com o jogo fechado, a sequência de corridas continua automática.
  - Por que esta: dá controle de verdade com um dedo, cabe na tela em pé, aproveita a pista em
    trechos que a simulação já tem (retas, frenagens, curvas) e não exige física de direção.
- **B. Direção arcade completa** (virar, acelerar, frear o tempo todo). Controle total, mas é outro
  jogo: física de direção, colisão, pistas jogáveis, balanceamento novo. Meses de trabalho e perde o
  idle.
- **C. Só mais cartões de jogada.** Barato, mas já foi o que eles rejeitaram.

**Técnica (opção A):** hoje a corrida é resolvida inteira antes de passar na tela. Com controle, ela
passa a ser resolvida trecho a trecho com a entrada do jogador; a tela continua só lendo o
resultado (simulação separada da visualização segue valendo). A corrida automática (fechada,
sequência, previsões, O QUE AJUDA?) continua usando o caminho de hoje.

**Protótipo (fase 2, gate):** uma pista, um carro, frenagem + saída + ataque, com o resultado
comparado ao piloto automático. Passa se os testadores disserem que sentem que dirigem e se a
habilidade mudar a posição sem anular o carro. Medir: toques por volta, % de frenagens boas,
posição ganha contra o automático, e se continuam jogando por vontade própria.

**Cuidado com a amostra:** os três têm 12–14 anos e dois jogam Brawl Stars (ação rápida). O público
de um gestor de corrida idle costuma ser outro. Recomendo incluir 2 ou 3 testadores do público-alvo
(adultos que jogam gestão/idle) no teste do protótipo: se eles também pedirem controle, a mudança
está confirmada; se não, a opção A ainda serve como modo opcional.

## 2. Carros genéricos ("um monte de carrinho branco parecido")

**O que se vê hoje:** os modelos 3D gerados são lisos e parecidos entre si, e a cor de fábrica
quase não aparece nos cartões. Sem marca conhecida, o jogador não tem por que gostar de um carro.

**Rápido (fase 1, sem arte nova):**
- Cartão com a identidade da marca: cor e logo da loja (já existem), fundo na cor do fabricante.
- Cor de fábrica forte no carro em todas as telas (existe por modelo; hoje a vitrine e o cartão
  apagam).
- Selo de categoria e de raridade pelo preço e pela licença (ícone, sem frase: o usuário vetou a
  frase de personalidade, mais texto para ler era justamente uma das reclamações).
- Carro do jogador com a pintura, o número e o apelido em todos os cartões.

**Médio (fase 3, arte):** o que cria apego de verdade é silhueta e ilustração. Recomendo (D2)
ilustração 2D própria por carro nos cartões, começando pelos ~60 carros das licenças Club e Sport
(o que o jogador vê nas primeiras horas), pelo mesmo fluxo de pedido de arte já usado nos pacotes
anteriores (`tools/pacote_arte_*.py`); os demais carros ficam com o cartão de marca. Alternativa:
melhorar a variedade dos modelos 3D gerados (mais barato, menos expressivo).

## 3. Lento e travando em vários celulares

**O que sabemos:** o teste foi pela versão web. Ela baixa ~98 MB (pacote de 54 MB + motor de
44 MB) e roda o motor em WebAssembly, sem threads: em celular de entrada é bem mais pesada que o
app nativo. O A20s nem passou do carregamento.

**Plano (fase 0):**
1. **APK Android para os testes (recomendado, D3).** O mesmo jogo exportado como app nativo roda
   várias vezes mais rápido que no navegador e não baixa tudo a cada visita. Distribuição: link do
   APK (instalação manual) agora; teste fechado do Play quando a conta estiver pronta.
2. **Medir antes de otimizar:** no modo de teste, gravar aparelho, FPS médio e mínimo por tela e o
   tempo de abertura; pedir aos testadores o modelo do celular.
3. **Qualidade automática:** se o FPS cair, o jogo baixa sozinho a resolução da corrida, tira
   partículas e sombras e troca efeitos pesados (a corrida leve da decisão 111 é o ponto de partida).
4. **Pacote menor:** texturas comprimidas para celular, artes de tela no tamanho da tela, cenários
   e carros carregados só quando aparecem.
Meta: 30 FPS estáveis num aparelho da classe do Galaxy A20s e abertura em menos de 15 s no APK.

## 4. Mara fala demais, tutorial e diálogos chatos

**Medido:** nos primeiros ~13 minutos o jogador lê 15 cenas, 54 falas, ~600 palavras antes de
jogar de verdade. O jogo tem 249 falas no total.

**Plano (fase 1):**
- **Tutorial fazendo, não lendo:** cada ensino vira destaque no botão + uma frase curta; sem cena
  de diálogo para explicar tela.
- **Teto por cena:** no máximo 2 falas; história só nos marcos (primeira vitória, licença, arena,
  Grid). Os comentários depois de cada corrida saem ou viram uma linha curta no resultado.
- **Abertura enxuta:** do primeiro toque à primeira corrida em menos de 1 minuto. Hoje são várias
  cenas antes da largada.
- **Pular sempre à mão:** tocar fora avança a cena inteira, não fala por fala.
- Meta: cortar ~60% das palavras dos primeiros 15 minutos (de ~600 para menos de 250) e ~40% das
  falas do jogo.

## Decisões pendentes

- **D1 — Controle na corrida:** A (pilotagem por toques, recomendada), B (direção completa) ou C
  (mais cartões). A muda o conceito "corridas automáticas" do README.
- **D2 — Arte dos carros:** ilustração 2D por carro começando pelos ~60 iniciais (recomendada) ou
  só melhorar os modelos 3D.
- **D3 — Teste no celular:** APK Android para os testadores (recomendada) ou seguir só na web.
- **Amostra:** incluir 2–3 testadores do público-alvo no teste do protótipo (recomendado).

## Decididas (2026-10-21, usuário)

- D1: **A, pilotagem por toques.** Muda o "corridas automáticas" do conceito: o jogador conduz
  quando assiste; fechado, segue automático. Protótipo antes da implementação completa.
- D2: **ilustração 2D por carro**, começando pelos ~60 das licenças Club e Sport.
- D3: **APK Android** para os testes.
- Amostra: incluir testadores adultos do público-alvo no teste do protótipo.
- Cartões: sem frase de personalidade (mais leitura era uma reclamação); só selos e identidade
  visual.

## Andamento

- **Fase 0, APK:** exportado no CI a cada envio e publicado em `/demo/chrome-wreckage.apk` do
  site (105 MB, armeabi-v7a e arm64-v8a, chave só de teste em `android/`). O Android exige a
  compressão de textura ETC2/ASTC, agora ligada no projeto.
- **Fase 0, medição e qualidade automática** (`ui/desempenho.gd`): nos builds de teste, aparelho,
  tempo de abertura e quadros por segundo por tela (média e pior segundo) nas Configurações e em
  `user://desempenho.json`. Em todos os builds, com 3D na tela e média abaixo de 85% da meta (30)
  por 8 s, os efeitos leves ligam sozinhos uma vez (3D a 75% da resolução) e o jogo avisa.
  Pendente: pacote menor (artes de tela no tamanho da tela, carregar cenários sob demanda).
- **Fase 1, diálogos:** primeiros 15 min de 620 para 225 palavras; o jogo de 249 para 148 falas;
  no máximo 2 falas de personagem por cena (a abertura tem 4); uma frase por fala do tutorial.
- **Fase 1, cartões:** a cor de fábrica caía no branco em todos os carros (o manifesto de cores
  era da frota antiga); agora é a primeira cor forte da paleta do modelo. Loja e garagem com fundo
  e faixa na cor do carro, logo da loja da marca, selo de categoria e losangos de raridade
  (quartis de preço da frota). Pendente: pintura, número e apelido nos demais cartões.
