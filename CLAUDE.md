# Instruções para o agente

## O que este repositório é
Material de design de um jogo mobile idle de automobilismo inspirado na estrutura de
progressão do Gran Turismo 2. O jogo ainda não existe.

## Leia antes de escrever qualquer código
- `docs/conceito.md` — princípios e limites
- `docs/plano_mvp.md` — escopo do primeiro build, sistemas, dados e ordem de implementação

## Regras de trabalho

**Não altere as regras do README.** São decisões de design.

**Não invente balanceamento.** Os números virão do estudo do GT2 e de playtest. Se faltar
algum, pergunte em vez de estimar.

**Balanceamento fica em JSON externo** (`data/`), nunca embutido no código.

**Simulação separada da visualização.** A corrida é resolvida sem renderizar; a tela só
lê o resultado.

**Nada do GT2 entra no build:** nem código, modelos, texturas, nomes de carros, marcas
ou traçados reconhecíveis. Campos de referência guardam o arquétipo, não o nome real.

**Decisões de projeto** estão na seção 8 de `docs/plano_mvp.md` (engine Godot 4.4, offline
real, um carro por vez com fila, licença como teste de tempo, usados por número de
corridas). Não as altere. Para o que não estiver decidido, pergunte.
