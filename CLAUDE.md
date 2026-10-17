# Instruções para o agente

## O que este repositório é
Material de design de um jogo mobile idle de automobilismo inspirado na estrutura de
progressão do jogo de referência. O jogo ainda não existe.

## Leia antes de escrever qualquer código
- `docs/conceito.md` — princípios e limites
- `docs/plano_mvp.md` — escopo do primeiro build, sistemas, dados e ordem de implementação

## Testes
`tests/rodar.sh` (aceita o caminho do Godot como argumento). Falha também em erro de script.
Testar antes de avançar de etapa. Fixtures de `tests/fixtures/` são sintéticas — nunca
copiá-las para `data/`.

## Regras de trabalho

**Não altere as regras do README.** São decisões de design.

**Não invente balanceamento.** Os números virão do estudo da referência e de playtest. Se faltar
algum, pergunte em vez de estimar.

**Toda pergunta de decisão vem com sugestão.** Ao precisar que o usuário decida algo,
apresente as opções já com a recomendada e o motivo, preferindo a solução da referência. Para
números de balanceamento, sugira o critério ou a fonte (ex.: valor da referência a extrair), não
o valor inventado.

**Balanceamento fica em JSON externo** (`data/`), nunca embutido no código. Os números
vêm do disco da referência pelo fluxo `tools/extrair_referencia.py` → `tools/importar_referencia.py` →
`tools/calibrar_licencas.gd` (ver `data/README.md`). Não edite à mão os arquivos que o
importador gera; ajuste a conversão no importador.

**Assets só com escala uniforme.** Nunca esticar nem estreitar uma imagem (mudar a
proporção); para caber, escalar inteira ou recortar.

**Simulação separada da visualização.** A corrida é resolvida sem renderizar; a tela só
lê o resultado.

**Nada da referência entra no build:** nem código, modelos, texturas, nomes de carros, marcas
ou traçados reconhecíveis. Campos de referência guardam o arquétipo, não o nome real.

**Decisões de projeto** estão na seção 8 de `docs/plano_mvp.md` (engine Godot 4.4, offline
real, um carro por vez com fila, licença como teste de tempo, usados por número de
corridas). Não as altere. Para o que não estiver decidido, pergunte.
