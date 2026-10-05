# Medição de progressão — primeira referência do agente

`tools/medir_progressao.gd -- --limite_min=300`, dados do commit em que este arquivo
entrou. Três perfis (`tools/agente.gd`) × três carros iniciais que o saldo paga
(Tsubame, Soryu, Pika). **Tempo = só corrida.** Decisões, menus, contratos e espera
fora da fila não entram: vêm do playtest de ritmo. Isto é referência do agente, não
duração de sessão.

## Resultado

| Perfil | Fim da carreira (min de corrida) | Licença B (min) | Licença A (min) | Saldo final (Cr) | Corridas de renda |
|---|---|---|---|---|---|
| sugestoes | 134–140 | 3 | 14–28 | 95–112 mil | 0–2 |
| explora | 135–171 | 0 | 7–12 | 26–86 mil | 0–2 |
| renda | 131–144 | 3 | 14–25 | 110–132 mil | 1–2 |

Os 9 percursos vencem **38 de 38 provas** e param por falta de conteúdo, não de dinheiro.

| Fase | Minutos de corrida | Cr/min de corrida (mediana entre carros) |
|---|---|---|
| sem licença | 0–3 (uma prova) | ~1.000 |
| B | 5–24 | 520–850 |
| A | 114–163 | 1.500–1.800 |

Compras: 13–22 por percurso. Só 0–2 por percurso exigiram juntar dinheiro, sempre na
fase B, com 1–2 corridas de renda (3–6 min de fila). As demais foram pagas na hora com
os prêmios das primeiras vitórias.

## Leitura

1. **As licenças não seguram a progressão.** Os contratos da B não custam dinheiro nem
   corrida, e a B sai logo após a primeira vitória (ou antes dela). A A sai entre 7 e 28
   min porque os tempos dos testes da A foram calibrados com o carro e o saldo do jogador
   "pronto para a B" do percurso antigo (decisão 22), que agora chega muito antes.
2. **A renda automática quase não é usada.** Os prêmios da primeira vitória de cada prova
   pagam tudo; repetir prova vencida só aparece por 3–6 minutos, no começo da B. A
   separação desafio × renda existe, mas a economia atual não pede renda.
3. **O dinheiro sobra.** Fim com 26–132 mil Cr sem destino. O carro mais caro comprado
   custou ~15 mil.
4. **O conteúdo acaba em ~2h20 de corrida.** São 38 provas (as do disco do GT2
   importadas até aqui).
5. Os perfis quase não diferem, porque o dinheiro não restringe nada. A diferença deve
   aparecer quando houver restrição.

## Limites desta medição

- O agente decide sem custo de tempo e conhece a busca dos contratos (10 envios no
  total). Uma pessoa leva mais tempo e envia mais.
- Prêmio por posição só; carro-prêmio não é vendido.
- `Cr por hora ausente` só existe onde houve renda; com fila de renda contínua e a fila
  até o teto offline (8 h), na B, é ~61 mil Cr/h.
- Sessões e retornos (`--ausencia_h`, `--sessao_min`) dependem do playtest de ritmo.

## O que decidir antes de recalibrar (pendente)

- Se a B deve exigir algo além dos contratos. O GT2 libera os testes desde o início; o
  que segura o jogador lá é o carro necessário para vencer as provas B.
- Se os testes de tempo da A devem ser recalibrados agora, pela nova referência, ou só
  quando os contratos da A substituírem os testes.
- Quantidade de conteúdo: o resto dos eventos do GT2 ainda não foi importado.
