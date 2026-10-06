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
- **Cor:** uma por modelo (não há pintura livre no jogo).
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

## Provisórios

`tools/gerar_sprites.gd` gera os dois arquivos de cada carro a partir do carro em
código, já nesta especificação. A arte final substitui o arquivo de mesmo nome; não
muda código. Uso: `godot --path . --script res://tools/gerar_sprites.gd` (precisa de
display; no servidor, `xvfb-run`).
