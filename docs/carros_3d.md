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
