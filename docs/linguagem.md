# Linguagem com o jogador

Público geral: quem nunca abriu um jogo de corrida precisa entender o que cada botão faz e
por que perdeu, sem saber o que é relação de câmbio ou potência por peso. Referências de
tela: `docs/referencias/ui_garagem.webp`, `ui_competicoes.webp`, `ui_resultado.webp`.

Levantamento: 659 textos de interface (`ui/`, `data_model/diagnostico.gd`,
`data_model/contratos.gd`).

## Problemas encontrados

1. **A mesma coisa com vários nomes.**
   - Corrida, prova, evento, competição, etapa, série e copa aparecem misturados. O texto
     da licença ainda manda para "Eventos", e essa aba se chama Competições.
   - Para colocar uma peça no carro aparecem preparar, oficina, equipar, instalar e
     reinstalar.
2. **Verbos que não dizem o resultado.**
   - "Preparar" e "Repetir" não dizem para quê.
   - "Desafiar" contra quem?
   - "Testar preparação" na verdade compara duas montagens.
   - "Estimar desempenho" na verdade prevê a posição.
   - "Enviar para avaliação" na verdade testa a montagem.
3. **Jargão técnico na frente.**
   - FF/FR/MR/4WD, aderência, potência/peso, corte, giro, câmbio curto/longo.
   - "Nos testes" e "fila" são termos internos.
   - "Modo de playtest" aparece para o jogador.
4. **Números soltos.**
   - "0.98 aderência" e "1.00 freio" não dizem se é bom.
   - Falta comparar com os rivais e dizer em que parte da pista o número ajuda.
5. **Telas que pedem leitura.**
   - O resultado tem quatro botões de peso igual.
   - Os cartões de competição repetem a mesma explicação em texto.
   - A Carreira mistura licenças, objetivos, coleção e preferências.

## Glossário proposto

Regra: o verbo diz o que acontece; o termo técnico vem depois, menor, para quem quiser.

| Hoje | Proposta | Por quê |
| --- | --- | --- |
| Prova / evento / corrida (uma largada) | **Corrida** | palavra de todo mundo |
| Série, copa, etapas | **Campeonato** (nome próprio: "Copa de Domingo"), **etapa 2 de 3** | agrupa as corridas |
| Desafiar | **Correr** | o jogador entende na hora |
| Correr ×N (vencidas) / "Renda: repetir vencidas" | **Correr de novo ×N** + linha "Rende créditos, até com o app fechado" | diz o ganho |
| Repetir (resultado) | **Correr de novo** | idem |
| Preparar (botão) | **Melhorar o carro** | diz o objetivo |
| Oficina (tela) | **Oficina** (mantém) | todo mundo sabe o que é |
| Preparação / preparação salva | **Montagem** / **Montagens salvas** | "preparação" soa técnico |
| Testar preparação | **Comparar montagens** | é o que faz |
| Estimar desempenho | **Prever minha posição** | é o que mostra |
| "1º–3º nos testes" | **"Previsão: 1º a 3º"** | sem termo interno |
| Equipar / instalar / reinstalar | **Usar** (peça já comprada) e **Comprar e usar** | um verbo por ação |
| Fila / faltam N corridas | **Sequência de corridas** / "faltam N" | "fila" é interno |
| Parar após esta / Parar já | **Parar no fim desta** / **Parar agora** | |
| Outra prova | **Escolher outra corrida** | |
| Potência/peso frente aos rivais: Abaixo/Próxima/Acima | **Seu carro x rivais: mais fraco / parelho / mais forte** | sem fração |
| Aderência | **Pneus (curvas)**; o número vira barra de 0 a 100 | diz onde ajuda |
| Freio 1.00 | **Freios (frenagem)**, barra | idem |
| Potência (cv) | **Potência (retas)**, com cv ao lado | idem |
| Peso (kg) | **Peso (quanto menor, melhor)** | |
| FF / FR / MR / 4WD | **Tração dianteira / traseira / motor central / 4x4**, com ícone; sigla só na ficha | |
| Câmbio curto / equilibrado / longo | **Arrancada / Equilibrado / Velocidade final** | diz o efeito |
| Corte, giro alto/baixo, rpm | só no gráfico do motor, em "Detalhes" | público técnico |
| Diagnosticar / DIAGNÓSTICO | **Por que perdi?** (já usado no título) | |
| Analisar / O QUE AJUDA? | **O que melhora meu resultado?** | |
| Contratos da licença / Enviar para avaliação | **Missões da licença** / **Testar montagem** | |
| Acompanhar nos usados | **Avisar quando aparecer usado** | diz o efeito |
| Agenda (mercado) | **Próximas ofertas** | |
| Cr | **Cr** com ícone de moeda | curto e já visto |
| Eventos (resto antigo) | **Competições** | um nome por aba |
| Modo de playtest | some do jogo final (só em versão de teste) | é ferramenta |

## Mudanças de estrutura (comunicação, não balanceamento)

1. **Resultado** (referência `ui_resultado.webp`):
   - pódio dos 3 primeiros e a sua posição em destaque;
   - uma frase de motivo, saída do diagnóstico ("Perdeu nas retas: falta potência");
   - **um** botão principal, que muda com o motivo: "Melhorar o carro" se o carro é o
     problema, "Correr de novo" se foi a corrida;
   - os outros botões menores.
2. **Cartão de competição** (referência `ui_competicoes.webp`):
   - banner da pista, desenho do traçado e prêmio do 1º lugar grande;
   - barra "Seu carro x rivais" colorida, no lugar do texto;
   - "Seu melhor" com troféu.
3. **Ficha e oficina** (referência `ui_garagem.webp`):
   - quatro atributos com ícone, número e barra, e embaixo onde ajuda (retas, curvas,
     frenagem);
   - cada peça com miniatura, uma linha do que faz e o ganho em verde (+5 cv).
4. **Primeira vez**: cada conceito novo (montagem, sequência de corridas, licença)
   aparece uma vez num balão curto, no momento em que é usado; "Entenda os números"
   continua para quem quiser ler.
5. **Ícones fixos para conceitos**: o mesmo ícone em todas as telas para potência, peso,
   pneus, freios, tração, créditos, troféu, licença, melhorar, correr e comparar.
6. **Ícone antes do texto nos botões**: o jogador entende para onde vai pelo ícone; ele
   fica em cima e maior que o texto, que vem menor embaixo e só confirma (`Aba.com_icone`:
   ícone de 64 px e texto de 26 nas ações; 78 px e texto de 20 na barra de navegação).

7. **Explicação curta na tela, detalhe no ⓘ**: nada de parágrafo no fluxo da tela. Cada
   explicação vira ícone + uma frase de até ~40 caracteres (`Aba.nota`); o porquê e o
   detalhe ficam atrás do botão ⓘ, num painel (`Aba.botao_info`, `Aba.titulo_secao`).
   Dentro de um painel não se usa ⓘ (abriria outro painel por cima).

## Estado

O glossário e as mudanças de estrutura estão aplicados nas telas, junto com a arte:
- abas com ícone;
- atributos com ícone e barra;
- oficina com miniaturas das peças e dos pneus;
- cartões de corrida com banner, emblema, troféu e a barra "Seu carro x rivais";
- resultado com palco, pódio com silhuetas e troféus;
- cabeçalhos ilustrados.

Textos explicativos encurtados pela regra 7 (de 62 textos longos visíveis para 16, quase
todos agora dentro dos painéis ⓘ). Ícones pedidos para isso: `icone_app_fechado`,
`icone_camera`, `icone_trafego` (sem a arte, a linha aparece só com o texto).

Falta: a dica de primeira vez (item 4 das mudanças de estrutura) e o botão principal do
resultado escolhido pelo motivo da derrota (hoje vem do objetivo).

## Pacote de arte da interface

`arte/ui/ui_manifesto.json` lista os arquivos. `python3 tools/pacote_arte_ui.py` gera
`build/pedido_arte_ui.zip` para o agente de imagem (`--so=` para refazer só alguns), e
`tools/importar_ui.gd -- --origem=/pasta` importa:
- ícones, emblemas e silhuetas: recorta e encaixa o desenho;
- miniaturas, banners e fundos: corta ao centro na proporção pedida.

O jogo lê os arquivos por nome (`Aba.arte`); arquivo que falta só tira a imagem.

Estilo: o das três referências (grafite escuro, destaque âmbar, ilustração pintada ao
entardecer). Nenhum texto na arte: os textos são do jogo (e mudam com o glossário).
Painéis, botões e abas são desenhados em código (`StyleBox`), não pedidos ao agente.
