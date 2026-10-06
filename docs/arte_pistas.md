# Arte das pistas — kit de montagem

Nenhuma pista é pintada à mão. Cada pista é montada pelo jogo (`visual/montador_pista.gd`)
a partir de um **kit** de texturas e objetos, seguindo o traçado exato da simulação. Trocar
a arte é trocar os arquivos do kit; todas as pistas mudam juntas.

Referência de estilo: `docs/referencias/pista_estilo.png` (circuito na mata ao entardecer,
vista de cima, pintura digital). É referência de clima e acabamento, não de traçado.

## Lista de arquivos

`arte/pistas/kit_manifesto.json` é a fonte: nome, tipo, tamanho em px, tamanho em metros e
descrição de cada arquivo. Hoje são 35: 9 texturas, 1 faixa (zebra) e 25 objetos.

## Regras da arte

| Regra | Valor |
| --- | --- |
| Vista | de cima, ortográfica (90°, sem perspectiva, sem horizonte) |
| Escala | 32 px por metro (textura de 512 px = 16 m) |
| Luz interna do objeto | suave, de cima e da esquerda |
| Sombra projetada | **nenhuma** — o jogo desenha a sombra na direção da luz de cada pista |
| Cor | neutra, de dia; o jogo aplica a tinta do horário (entardecer, noite) e a vinheta |
| Texturas | quadradas, repetíveis sem emenda, sem objetos soltos, sem linhas pintadas |
| Objetos | fundo transparente (plano B: magenta chapado #FF00FF), um objeto por imagem, centrado |
| Proibido | texto, números, logotipos, marcas, placas legíveis, carros |
| Acabamento | pintura digital limpa, poucos detalhes finos, leitura clara em tela de celular |

Orientação dos objetos que o jogo gira ao longo da pista (está na descrição de cada um):
boxes e arquibancada com a frente para a **borda de baixo** da imagem; caminhões com a
cabine **em cima**; contêineres e pórtico com o eixo longo **na vertical**. Os provisórios
em `arte/pistas/kit/` mostram a orientação e a proporção.

## O que o jogo faz com o kit

- Chão: duas texturas misturadas em manchas por ruído (`chao_a`, `chao_b` do tema); chão de
  floresta (`chao_mata`) por baixo da mata fechada; água (`agua`) em cais do lado dos boxes,
  quando o tema pede.
- Por fora das curvas: areia nas fechadas (raio até 90 m), brita nas médias (até 200 m).
- Faixa de escape pintada, asfalto, linhas brancas e zebras (geradas, não desenhadas).
- Reta de largada: pit lane de concreto, boxes em módulos de 10 m encostados (portas para a
  pista), torre, arquibancada atrás, pórtico na linha; paddock do lado de dentro com caminhões
  e tendas espaçados. Cada lado só ocupa o espaço livre de outros trechos do traçado.
- Postes só no pátio dos boxes e no paddock; faixa aberta de grama perto da pista (`aberto_m`)
  com árvores isoladas, mata fechada depois, com clareiras e copas mais escuras no fundo; objetos raros (rochas) com chance baixa; contêineres em blocos, dentro de pátios.
- Sombras presas à base de cada objeto (silhueta arrastada na direção da luz do tema); objeto
  suspenso (pórtico) tem a sombra solta no chão.

Cada pista escolhe o tema em `Corrida3D.KITS` (chão, objetos de mata, densidade, postes,
tinta, direção da sombra, vinheta). Pista nova usa um tema existente ou ganha um tema novo
com os mesmos arquivos.

## Fluxo de produção

1. `python3 tools/pacote_arte_pistas.py` gera `build/pedido_arte_pistas.zip`: instruções em
   português, um pedido em inglês por arquivo, o manifesto, a referência de estilo e os
   provisórios.
2. O agente de imagem gera os PNG com os nomes do manifesto (qualquer tamanho; o importador
   ajusta).
3. Importar e conferir:
   `godot --headless --path . --script res://tools/importar_kit_pista.gd -- --origem=/pasta`
   (use `--destino=/outra/pasta` para conferir sem tocar no kit do jogo). O relatório diz
   aprovado, corrigido (redimensionado, recortado, emenda refeita, magenta removido) ou
   reprovado; reprovado não substitui o arquivo atual.
4. Refazer só alguns arquivos: `python3 tools/pacote_arte_pistas.py --so=nome1,nome2` gera o
   pacote de refação (com a versão atual de cada um para comparação).
5. Conferir nas fotos do cenário (`tools/fotos_cenario.gd`: largada, boxes, curva, mata e vista
   média, câmera parada) e da corrida (`tools/fotos_pistas.gd`); pedir de novo o que destoar.

`tools/gerar_kit_pista.gd` regenera o kit provisório; não rodar depois de importar a arte
final.
