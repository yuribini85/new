# Arte dos carros: especificação

Decisão 31 (`docs/plano_mvp.md`): cada modelo tem **dois sprites**, e nada mais.

| Arquivo | Vista | Uso |
|---|---|---|
| `arte/carros/<id>_topo.png` | de cima, **frente para cima** | corrida (o jogo gira o sprite pela direção do carro na pista) |
| `arte/carros/<id>_iso.png` | isométrica 2:1, **frente para baixo e à esquerda** (3/4 de frente) | garagem, mercado, oficina, fichas e o momento de velocidade da corrida |

`<id>` é o id do carro em `data/carros.json` (ex.: `hayase_soryu`).

## Regras

- **Escala:** 160 px por metro nas duas vistas, para todos os carros (4× para a vitrine da
  garagem ficar nítida; na corrida o jogo reduz com mipmaps). O comprimento real
  do modelo vem de `data/carros.json`; não ajustar o tamanho "para caber".
- **Fundo transparente**, sem sombra no chão (o jogo desenha a sombra) e sem cenário.
- **Luz:** de cima e da esquerda da tela, a mesma nas duas vistas.
- **Isométrico:** câmera a 30° acima do chão, projeção 2:1, na mesma direção da câmera
  da corrida. O carro aponta para baixo e à esquerda. Tela de 1120×800 px, carro centrado.
- **Top-down:** frente para o alto da imagem, eixo do carro na vertical. Tela do
  tamanho do carro mais uma margem pequena.
- **Cor:** carroceria **branca**; o jogo pinta por programação (`visual/shaders/pintura.gdshader`,
  aprovado na Oficina de Pintura com tolerância 70%). Nada branco ou cinza-claro fora da
  carroceria: lente do farol cinza-clara, placa cinza, interior cinza-escuro, frisos e
  aerofólios de corrida pretos, sem faixas nem duas cores. Como no GT2, cada modelo tem
  algumas cores de fábrica e a escolha é na compra (sem pintura livre depois).
- **Nada reconhecível:** sem marcas, logotipos ou desenho de carro real.
- **Estilo:** `docs/referencias/carro_estilo.webp` (low-poly facetado, sombreamento chapado,
  grão de pintura leve, cores sóbrias). A referência é de estilo, não de forma.

## Produção

1. `arte/carros/manifesto.json`: descrição (em inglês) e cor de fábrica de cada modelo, mais a
   geometria de cada vista (tela e retângulo do carro), medida nos provisórios por
   `tools/manifesto_carros.gd`. Carro novo: descrição e cor no manifesto, depois
   `gerar_sprites.gd` e `manifesto_carros.gd`.
2. `python3 tools/pacote_arte_carros.py` gera `build/pedido_arte_carros.zip` para o agente de
   imagem (`--so=id1,id2` para refazer só alguns).
3. `godot --headless --path . --script res://tools/importar_carros.gd -- --origem=/pasta`
   recorta, encaixa na escala e na posição do provisório e avisa proporção estranha;
   `--destino=` confere sem tocar nos arquivos do jogo.
4. `godot --headless --path . --script res://tools/medir_pintura.gd` grava
   `arte/carros/pintura.json`: quais sprites têm carroceria branca e a faixa de brilho da
   pintura de cada um (o shader usa). Sprite fora do arquivo aparece com a cor que veio.

## Pintura

`Pintura.textura(id, vista, cor)` (`visual/pintura.gd`) pinta o sprite branco uma vez por
modelo, vista e cor, num SubViewport, e guarda a textura (com mipmaps). Pintura = pixel
quase sem cor e claro (e a borda antisserrilhada cercada de pintura); cada um vira um tom
da cor (sombra, meio-tom, luz) pela posição do brilho dele na faixa da pintura do sprite.
Cores escuras: menos grão, mais contraste entre facetas e reflexo levemente frio.

## Cores de cada modelo

`python3 tools/gerar_cores.py` grava `arte/carros/cores.json`: a paleta (nome e cor) e as
cores de cada modelo, a de fábrica primeiro. As cores do GT2 ficam nas paletas do modelo 3D
de cada carro, fora das tabelas que o extrator lê; por isso a paleta é própria, por época
(ano do carro) e categoria, embaralhada pela família (versões da mesma família têm as mesmas
opções). Quantidade: a de cores diferentes do modelo nos usados do GT2, de 4 a 7 (sem dado,
5); versão de corrida, 4 cores fortes. No jogo (`visual/cores.gd`): carro novo, o jogador
escolhe na ficha antes de comprar; usado vem numa cor do modelo, fixa pela oferta; rivais
variam entre as cores do modelo, fixas por prova e posição no grid.

## Provisórios

`tools/gerar_sprites.gd` gera os dois arquivos de cada carro a partir do carro em
código, já nesta especificação. A arte final substitui o arquivo de mesmo nome; não
muda código. Uso: `godot --path . --script res://tools/gerar_sprites.gd` (precisa de
display; no servidor, `xvfb-run`).

## Carros do GT2 (frota de 386, decisão 40)

Os carros sem sprite próprio (todos menos os do primeiro build): no jogo aparecem como o carro em código (placeholder),
que já segue a categoria, o ano e os números de cada um. Os provisórios deles **não** entram
em `arte/carros/` (seriam ~1.200 imagens no build); ficam só no pedido de arte:

```
python3 tools/descrever_carros.py                      # descrição e cor no manifesto
godot --path . --script res://tools/gerar_sprites.gd -- --destino=/tmp/prov --so-faltando
godot --headless --path . --script res://tools/manifesto_carros.gd -- --origem=/tmp/prov
python3 tools/pacote_arte_carros.py --so-faltando --provisorios=/tmp/prov --lote=55 \
    --saida=build/pedido_arte_carros_novos.zip         # 11 lotes
```

Versões da mesma família pedem o mesmo desenho da primeira (a descrição diz qual).
O manifesto só tem os carros da frota: `descrever_carros.py` tira os que saíram (abertos e
repetidos). A arte de quatro que saíram (três abertos e um repetido) ficou em `arte/carros/` sem uso.
**Tamanho:** com a arte final nesta especificação (160 px/m), 386 carros somam centenas de MB.
Antes de importar em massa, decidir compressão (WebP com perdas) ou escala menor no build.

