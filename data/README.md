# data/

Balanceamento consumido pelo autoload `Dados` (`autoload/dados.gd`). **Nenhum valor aqui é
inventado:** os números vêm do estudo do GT2 e de playtest. O que ainda falta aparece em
`Dados.pendencias()` e como aviso ao abrir o projeto.

Os campos obrigatórios de cada arquivo estão em `Dados.ESQUEMAS`. Exemplos completos e
sintéticos (só para teste) em `tests/fixtures/`.

| Arquivo | Formato |
|---|---|
| `fabricantes.json` | lista de `{id, nome, escola}` |
| `carros.json` | lista de `{id, nome, fabricante, arquetipo_ref, categoria, tracao, potencia, peso, aderencia, freio, velocidade_max, preco, ano}`, opcional `usado_dias: [início, fim]` |
| `pecas.json` | lista de `{id, nome, categoria, efeitos, preco}`, opcionais `tracao_permitida`, `carros_permitidos` |
| `pneus.json` | lista de `{id, nome, aderencia: {seco, chuva}, preco}` |
| `pistas.json` | lista de `{id, funcao, trechos}` |
| `pilotos_ia.json` | lista de `{id, ritmo, consistencia, agressividade}` |
| `simulacao.json` | objeto com os parâmetros de `Simulacao.PARAMS` |
| `economia.json` | objeto `{saldo_inicial, fracao_revenda, pneu_de_fabrica}` |
| `eventos.json` | lista de `{id, nome, pista, voltas, condicao, restricoes, adversarios, premios}`, opcional `carro_premio` |
| `licencas.json` | lista de `{id, nome, testes}`, opcional `requisito` (id de outra licença) |
| `carreira.json` | objeto `{piloto_jogador, teto_offline_s}`: piloto dos carros do jogador (id em `pilotos_ia.json`) e máximo de tempo ausente que a fila aproveita |

## Unidades e semântica

- `tracao`: `FF`, `FR`, `MR`, `RR` ou `4WD`.
- `potencia` em cv; `peso` em kg; `velocidade_max` em km/h.
- `aderencia`: coeficiente de atrito do carro. Multiplicado pela aderência do pneu na
  condição (`seco`/`chuva`). A curva limita a velocidade a `sqrt(aderência · g · raio)`.
- `freio`: fração da aderência usada na frenagem (desaceleração = freio · aderência · g).
- `efeitos` de peça: lista de `{atributo, op, valor}`, `op` = `soma` ou `mult`. Todas as
  somas são aplicadas antes das multiplicações. Uma peça por `categoria`.
- `trechos`: `{tipo, comprimento_m, raio_m (curvas), sentido ("esquerda" padrão ou
  "direita"), ultrapassagem (bool)}`. Tipos em `Pista.TIPOS`. Trechos de box ficam fora
  da volta no primeiro build. O traçado é derivado dos trechos (reta avança; trecho com
  raio é arco) e precisa fechar a volta — conferir em `tools/editor_pista.tscn`.
- Piloto: `ritmo` é a fração do limite que o piloto usa; `consistencia` (0–1) reduz o
  ruído por volta; `agressividade` (0–1) é a chance de tentar ultrapassar em cada zona.

## simulacao.json

| Chave | Tipo | Estado |
|---|---|---|
| `passo_m` | precisão da discretização da pista | definido (técnico) |
| `dt_s` | passo de tempo | definido (técnico) |
| `amostra_dt_s` | intervalo das amostras para a visualização | definido (técnico) |
| `tempo_max_s` | trava de segurança da corrida | definido (técnico) |
| `distancia_minima_m` | distância de cortesia entre carros e espaço do grid | **pendente** |
| `sigma_ruido` | desvio do ruído por volta para consistência 0 | **pendente** |
| `fator_tracao` | `{FF, FR, MR, RR, 4WD}`: fração do peso nas rodas de tração | **pendente** |

## economia.json

| Chave | O que é | Estado |
|---|---|---|
| `saldo_inicial` | dinheiro no começo do jogo | **pendente** |
| `fracao_revenda` | venda = preço de tabela × fração; peças não entram no valor | **pendente** |
| `pneu_de_fabrica` | id em `pneus.json` com que todo carro novo chega | **pendente** |
| `usado_periodo_dias` | de quantos em quantos dias o estoque de usados muda | **pendente** |
| `usado_km_min`, `usado_km_max` | faixa da quilometragem sorteada | **pendente** |
| `usado_desconto_por_km` | preço do usado = tabela × (1 − km × desconto) | **pendente** |
| `usado_fracao_minima` | piso dessa fração | **pendente** |

Regras fixas no código (`data_model/concessionaria.gd`): peça comprada fica com o carro e
reinstalá-la é grátis; um pneu de cada composto por carro; nada é cobrado se a compra é
recusada.

## eventos.json

- `condicao`: `seco` ou `chuva`, fixa por evento.
- `restricoes` (todas opcionais, ver `data_model/elegibilidade.gd`): `potencia_max` (cv
  efetivos, já com peças), `tracao`, `categoria`, `fabricante` (listas), `ano_min`,
  `ano_max`, `licenca`.
- `adversarios`: lista de `{carro, piloto, pecas?, pneus?}`; sem `pneus`, usa o de fábrica.
- `premios`: dinheiro por posição (índice 0 = 1º). Posições além da lista não recebem.

Regras fixas no código (`data_model/carreira.gd`), seguindo o GT2: o jogador larga em
último; o prêmio em dinheiro é pago a cada disputa; o carro-prêmio só na primeira vitória;
cada corrida disputada conta um dia.

## licencas.json

Cada teste: `{id, pista, voltas, condicao, restricoes, tempos: {ouro, prata, bronze}}`,
tempos em segundos. O jogador usa o próprio carro dentro da restrição. Licença concedida
quando todos os testes têm ao menos bronze; o melhor grau de cada teste fica guardado.
Testes não contam dia.

## Usados

Carro com `usado_dias` aparece no usado enquanto o dia do jogador estiver na faixa. A
quilometragem é sorteada por carro e período e só afeta o preço. Comprado, sai do estoque
até o período seguinte.

## Fila e offline

Um carro por vez, com número de repetições. Cada corrida dura em tempo real o mesmo que
dura simulada. Ao abrir o jogo, as corridas concluídas durante a ausência são aplicadas
em lote, até `teto_offline_s`; o excesso é descartado e a fila continua de onde parou.
Carro vendido ou que deixou de ser elegível cancela a fila.
