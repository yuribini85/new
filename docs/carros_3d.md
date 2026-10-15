# Carros em 3D: especificação de modelagem

Decisão 31 (`docs/plano_mvp.md`, revista em 2026-10-11): cada carro é **um modelo 3D**
(GLB) usado em todo lugar: corrida, arena, oficina, loja e fichas. Menus, diálogos e
retratos continuam 2D. Enquanto um carro não tem modelo, o jogo usa o sprite antigo e,
sem sprite, o carro gerado em código; a troca é carro a carro.

**Lista completa:** `docs/carros_3d/lista.md` (por família, na ordem de produção) e
`docs/carros_3d/lista.csv` (uma linha por carro). Geradas por
`godot --headless --path . --script res://tools/lista_carros_3d.gd`; não editar à mão.

## O que cada linha da lista traz

| Coluna | Uso na modelagem |
|---|---|
| `arquivo` | nome do arquivo a entregar (`<id>.glb`) |
| `familia`, `modelo_base` | a família é **um desenho**; o modelo base é feito primeiro e as versões saem dele (ano, para-choques, aerofólio, faróis, rodas) |
| `ano` | época do desenho (anos 80: cunha, vincos retos, faróis escamoteáveis no cupê; anos 90: formas arredondadas, faróis com lente, para-choques na cor) |
| `carroceria`, `arquetipo` | tipo (hatch compacto, sedã, cupê, roadster sem teto) e a classe do carro |
| `tracao` | posição do motor muda a silhueta: motor central = cabine avançada e traseira longa com tomadas laterais |
| `comprimento_m`, `largura_m`, `altura_m` | medidas da carroceria (largura sem retrovisores); o jogo usa as mesmas na corrida |
| `entre_eixos_m`, `raio_roda_m` | posição e tamanho das rodas; o raio é o da física da corrida, usar exato |
| `detalhes` | aerofólio, tipo de farol e grade, tomadas de ar, escape duplo, rodas traseiras maiores |
| `cores` | cores de fábrica (a primeira é a padrão); o jogo pinta, o modelo vem com a lataria branca |
| `fabricante`, `escola` | identidade da marca (jp, eu, us) e o texto de história em `lista.md` |
| `descricao_en` | descrição pronta em inglês para agente de imagem ou referência |
| `primeira_licenca` | quando o jogador vê o carro (ordem de produção) |

## Padrão do arquivo (obrigatório)

- **Formato:** GLB (glTF binário), um arquivo por carro, nome `<id>.glb`.
- **Escala:** metros, 1 unidade = 1 m. Medidas da lista com tolerância de 10%
  (a largura pode passar até 30% por causa dos retrovisores). Nunca esticar nem achatar
  para caber: o jogo não corrige escala.
- **Eixos:** Y para cima, **frente do carro em +Z**, lado esquerdo do motorista em +X.
- **Origem:** no chão (fundo dos pneus em y = 0), no meio do carro em X e Z.
- **Rodas separadas:** quatro objetos chamados `roda_de`, `roda_dd`, `roda_te`, `roda_td`
  (dianteira/traseira, esquerda/direita), cada um com a origem **no centro da roda** e o
  eixo de giro em X. O resto do carro num objeto (`carroceria`). Sem rodas separadas o
  carro funciona, mas as rodas não giram.
- **Polígonos:** de 1.000 a 2.500 triângulos no total (máximo 3.000). Low-poly
  facetado, sombreamento chapado (`docs/referencias/carro_estilo.webp`).
- **Normais para fora** (Blender: modo de edição, selecionar tudo, Shift+N
  "Recalculate Outside") e sem faces duplicadas.
- **Sem interior; vidros opacos** em cinza-escuro azulado.

## Pintura: dois formatos aceitos

1. **Material "Paint"** (o do pacote dos 386, 2026-10-11): um material chamado `Paint`
   com textura branca mínima para a lataria; as outras partes em materiais de cor própria
   (`Trim`, `Glass`, `Rubber`, `Wheel`, `Lens`, `Amber`, `Red`...). O jogo pinta só o
   `Paint` e o GLB é instalado como veio.
2. **Atlas de cores** (abaixo): um material com atlas; a lataria branca no atlas é pintada
   pelo shader.

## Textura (atlas de cores)

- Um material, um atlas de **cores chapadas** (sem luz, sombra ou desgaste pintados),
  PNG quadrado de 512 px (1024 é aceito; a ferramenta reduz). Roughness 0,9,
  metallic 0.
- **Lataria em branco** `#F2F2EE`: é a parte que o jogo pinta com a cor de cada carro.
- **Nada branco ou cinza-claro fora da lataria:** o jogo pintaria junto. Lente do farol
  com tom amarelado (ex.: `#E8DFA8`), lanterna vermelha, aros em cinza médio
  (até `#9A9DA2`), pneus, grades, frisos e aerofólios de corrida escuros, vidro
  cinza-escuro.
- Sem faixas, números, decalques ou duas cores na lataria.
- As versões da mesma família usam, de preferência, o mesmo atlas.

## Nada reconhecível

Sem marcas, logotipos, nomes ou desenho copiado de carro real. A lista dá o arquétipo e a
época; o desenho é próprio. Fabricantes, nomes e paletas são do jogo.

## Entrega e instalação

1. Entregar os `<id>.glb` (textura embutida ou `<id>_atlas.png` ao lado) numa pasta ou
   zip.
2. `python3 tools/preparar_glb.py PASTA` confere eixos, chão, escala pela lista, rodas e
   orçamento de triângulos; tira a textura de dentro do GLB, grava `<id>_atlas.png`
   (no máximo 512 px, mesma proporção) e instala em `arte/carros3d/`. Erro de medida ou
   eixo recusa o arquivo (corrigir na modelagem).
3. `godot --headless --import` e os testes (`tests/rodar.sh`, que roda
   `preparar_glb.py --checar` nos instalados).
4. Para ver no jogo: Configurações → Cenários de teste → "Carro 3D".

Tamanho por carro instalado: ~90 KB de modelo + ~60 KB de atlas; os 386 carros ficam
perto de 55 MB.

## No jogo

`CarroBloco` carrega `arte/carros3d/<id>.glb` quando existe (`CarroBloco.tem_glb`), com
prioridade sobre o sprite e o carro em código, gira o modelo para a frente em +X do jogo
e pinta a lataria pelo shader `visual/shaders/carro_glb.gdshader`. As fotos da loja e da
garagem (`Estudio`) e a vitrine da oficina (`VitrineCarro`) usam o mesmo modelo, no ângulo
e na escala dos antigos sprites isométricos.

## Carro gerado (Carroceria) e rodas

Gerador em código no estilo facetado dos pilotos (aprovado pelo usuário), em
`visual/carroceria.gd`. **Por enquanto só vale para os ids de `Carroceria.ATIVOS`**
e das épocas/categorias de `Carroceria.LIBERADOS` (hoje: o Kanaya Kestrel, aprovado
como piloto, e cupê, compacto e sedã dos clássicos (até 1971, piloto Calderwood Sabre)
dos anos 70 (piloto Hayase Cedro) e dos anos 80 e 90, e as picapes de todas as épocas,
piloto Kanaya Sulco; o resto usa os GLB). O usuário aprova um carro por vez; ao aprovar, o
id entra na lista. `CarroBloco.tem_modelo(id)` responde pelos dois (gerado ou GLB).

- **Forma:** `arte/carros3d/formas.json` (vai no jogo), gerado por
  `python3 tools/exportar_formas.py` a partir de `referencia/frota360/` (que nunca vai).
  Só as medidas que o gerador usa: `W, r, low, lo, hi, sx, za, zb, wind, back, axles,
  rows [z, meia largura, topo], roof [z, meia largura, altura]` e `rodas [nome, x, y, z]`;
  nada de nome, intenção ou referência. `--checar` (no `tests/rodar.sh`) confere que todo
  carro de `data/carros.json` tem forma e que o preset web inclui o arquivo. Não editar à
  mão.
- **Desenho:** contexto por época (ano), categoria, esportividade (potência/peso) e escola
  do fabricante (`data/fabricantes.json`). Uma função por parte, para iterar um carro:
  `_secoes`/`_loft` (lataria), `_caixas_de_roda`, `_cabine`, `_frente`, `_traseira`,
  `_lateral`, `_cacamba`, `_aerofolio`, `_pincas`; as rodas são de `Rodas`.
- **Proporções (`proporcoes`, aprovadas no Kanaya Kestrel):** a forma exportada é
  corrigida pela época antes do desenho (`forma_final`, guardada por id). Para-brisa
  atrás do eixo dianteiro (20% do entre-eixos no cupê, 10% no sedã; o compacto mantém o
  da forma); estufa baixa de teto reto (até 0,42 m no esportivo, 0,47 no normal, 0,5 no
  compacto); teto curto no cupê, longo no sedã e até perto da traseira no compacto; anos
  70/80 com laterais chapadas, cintura reta e capô em cunha (que não desce abaixo do
  pneu); coluna B no fim da porta nos de 2 portas (`doors` em formas.json); rodas até
  4 cm mais para fora, rentes ao para-lama; o para-lama sobe o necessário para cobrir o
  pneu. Picapes, utilitários e pesados mantêm a estufa da forma.
- **Linguagem dos anos 80 (esportivo):** faróis escamoteáveis no capô, grade fina,
  para-choque alto com piscas e tomada de ar, painel traseiro preto de ponta a ponta com
  lanterna, pisca e ré, aba traseira no lugar do aerofólio, friso de borracha na porta.
  A partir dos 80, molduras e colunas da estufa pretas. Todos: forro escuro dentro da
  estufa, retrovisor preso na porta.
- **Linguagem dos clássicos (até 1971, aprovada no Calderwood Sabre):** capô mais longo
  (32% do entre-eixos no cupê, 18% no sedã), estufa até 0,40 m com teto curto, cintura
  reta, capô arredondado mais baixo que os para-lamas, cauda que desce, seção redonda,
  faróis redondos grandes, grade oval cromada, para-choque cromado fino com garras,
  molduras das janelas cromadas e retrovisor redondo no para-lama.
- **Linguagem dos anos 70 (aprovada no Hayase Cedro):** capô longo (26% do entre-eixos
  no cupê, 14% no sedã) que cai devagar, grade preta de ponta a ponta com moldura cromada
  e quatro faróis redondos, para-choque cromado com faixa de borracha e garras, lanternas
  largas com moldura cromada, retrovisor cromado, traseira reta nos comuns; esportivos com
  venezianas no vidro traseiro e aba traseira.
- **Picape (aprovada na Kanaya Sulco):** para-brisa logo atrás da roda dianteira, cabine
  simples de parede traseira reta com vidro retangular, caçamba aberta (`FUNDO` abaixo
  da cintura: assoalho emborrachado, laterais, parede e tampa pintadas, beira preta),
  lanternas verticais nos cantos, grade larga entre os faróis. A forma pede seções
  extras no degrau da caçamba (`cortes`).
- **Mesmo eixo dos GLB:** frente em +Z, chão em y = 0, rodas `Mount_*` com o centro no
  eixo e giro em X. Blindagem (`<id>_protecao.glb`), giro, sombra, dano e fogo da arena
  funcionam igual.
- **Desenho (draw calls):** a carroceria é uma malha de 2 superfícies (`MontagemMalha`):
  a pintura (shader da lataria por instância: cor, faixas, número, logo, acabamento,
  desgaste) e todo o resto numa só (`shaders/carro_detalhe.gdshader`: cor, metálico,
  rugosidade, emissão e especular por vértice; `brilho_luzes` regula faróis e lanternas).
  Cada roda é um nó com uma malha de 1 superfície. Carro inteiro: 7 superfícies com a
  sombra. Orçamento: carroceria até 3.200 triângulos (média ~2.400), roda até 800.
- **Cache:** carroceria por id e roda por (desenho, raio em cm, lado), na sessão.
  A lista de provas pede os carros do grid de antemão (`Carroceria.preparar`, um por
  quadro). Medido no desktop: ~6 ms por carroceria nova (mediana), <1 ms em cache.

### Rodas (`visual/rodas.gd`)

Um pneu para todos e 8 aros: `cinco` (Cinco raios, padrão), `aco` (Aço com calota),
`seis`, `malha`, `turbina`, `disco` (Disco aero), `estrela` (Três raios), `dez` (Dez raios
finos). O jogador escolhe na cabine de pintura, aba RODAS (só nos carros gerados). Fica em
`Carro.faixas["roda"]` (o padrão não é gravado; save antigo = padrão) e não custa.
