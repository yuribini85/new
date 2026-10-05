# data/

Balanceamento consumido pelo autoload `Dados` (`autoload/dados.gd`). **Nenhum valor aqui é
inventado:** os números vêm do estudo do GT2 e de playtest. O que ainda falta aparece em
`Dados.pendencias()` e como aviso ao abrir o projeto.

Os campos obrigatórios de cada arquivo estão em `Dados.ESQUEMAS`. Exemplos completos e
sintéticos (só para teste) em `tests/fixtures/`.

| Arquivo | Formato |
|---|---|
| `fabricantes.json` | lista de `{id, nome, escola}`, opcionais `pais`, `historia` |
| `carros.json` | lista de `{id, nome, fabricante, arquetipo_ref, categoria, tracao, potencia, peso, aderencia, freio, velocidade_max, preco, ano}`, opcional `usados: [[dia_inicio, dia_fim, preco], ...]` |
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
| `distancia_minima_m` | distância de cortesia entre carros e espaço do grid | 6,0 (comprimento de um carro + margem; confirmar em playtest) |
| `sigma_ruido` | desvio do ruído por volta para consistência 0 | 0,0 — **a confirmar** (o GT2 não tem; sem ruído até o playtest) |
| `cda_m2` | área frontal × coeficiente de arrasto, igual para todos | 0,6 — **a confirmar** (o GT2 não guarda arrasto de carro de rua) |
| `densidade_ar_kg_m3` | densidade do ar | 1,225 (nível do mar) |
| `fator_tracao` | `{FF, FR, MR, RR, 4WD}`: fração do peso nas rodas de tração | FF 0,6 · FR 0,5 · MR 0,55 · RR 0,6 · 4WD 1,0 (distribuição de peso típica; confirmar em playtest) |

## economia.json

| Chave | O que é | Estado |
|---|---|---|
| `saldo_inicial` | dinheiro no começo do jogo | **pendente** |
| `fracao_revenda` | venda = preço de tabela × fração; peças não entram no valor | 0,5 — **a confirmar** no GT2 (como medir: abaixo) |
| `pneu_de_fabrica` | id em `pneus.json` com que todo carro novo chega | **pendente** |

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

Como no GT2: cada carro lista as janelas em que aparece na concessionária de usados e o
preço de cada uma (`usados`). No GT2 são 60 períodos de 10 dias; o dia é o número de
corridas disputadas. Comprado, o carro sai do estoque até a janela seguinte. Não há
quilometragem (o GT2 não tem).

## Fila e offline

Um carro por vez, com número de repetições. Cada corrida dura em tempo real o mesmo que
dura simulada. Ao abrir o jogo, as corridas concluídas durante a ausência são aplicadas
em lote, até `teto_offline_s`; o excesso é descartado e a fila continua de onde parou.
Carro vendido ou que deixou de ser elegível cancela a fila.

## Pistas do primeiro build

| id | função | comprimento | ultrapassagem |
|---|---|---|---|
| `anel_do_vale` | alta velocidade | 2.941 m | reta principal e reta oposta |
| `parque_das_docas` | técnico | 2.085 m | reta principal e reta antes da última curva |
| `serra_alta` | montanha | 1.913 m | só a reta de largada |

Os rascunhos ficam em `data/rascunhos_pistas/`: curvas descritas por raio e ângulo, com
duas retas de comprimento `null`. `tools/fechar_pista.py rascunho.json` calcula essas
duas retas para a volta fechar e imprime a pista pronta para `pistas.json`.

## Fabricantes do primeiro build

`hayase` (Hayase Motor, Japão), `hartwig` (Hartwig, Alemanha), `ashcombe` (Ashcombe Cars,
Reino Unido). Nomes fictícios; **busca de marca pendente** antes do lançamento, como o
título do jogo.

## Carros a partir da referência do GT2

1. Monte a tabela CSV descrita em `tools/converter_carros.py` (exemplo em
   `tests/referencia/exemplo.csv`). Guarde em `referencia/` ou como
   `referencia*.csv` na raiz — os dois estão no `.gitignore`. Dentro do projeto, ponha um
   arquivo `.gdignore` vazio na pasta para o Godot não importar o CSV como tradução.
2. `tools/converter_carros.py referencia/carros.csv > data/carros.json`
3. A coluna `ref_real` é descartada; só nome fictício e arquétipo entram no jogo.

## Dados do GT2 (fonte de todo o balanceamento)

Fluxo, a partir de uma cópia legítima do disco (Simulation Disc, SCUS-94488):

```
python3 tools/extrair_gt2.py --disco "Gran Turismo 2 (Simulation).bin"   # -> referencia/gt2/
python3 tools/importar_gt2.py --sugerir      # liga cada carro nosso a um carro do GT2 (revise)
python3 tools/importar_gt2.py                # -> data/carros, pecas, pneus, pilotos_ia, eventos, licencas...
godot --headless --script res://tools/calibrar_licencas.gd   # tempos das licenças
```

`referencia/` nunca vai para o Git. O que entra em `data/` são os números convertidos
para os carros fictícios. As conversões estão no topo de `tools/importar_gt2.py`.

**A confirmar** (não vêm do GT2): `fracao_revenda`, `teto_offline_s` (8 h, decisão de design),
`sigma_ruido`, `cda_m2`, consistência e agressividade dos pilotos (1,0).

## Estado atual de data/ (importado do GT2 americano, SCUS-94488 v1.2)

- 17 carros ligados a modelos do GT2 (tabela de ligação em `referencia/carros.csv`, fora do
  Git). Potência pela curva de torque; peso, preço, tração, grip e freio do disco.
- 242 peças com preço e efeito do GT2; 7 compostos de pneu (fábrica a supermacio e o de
  simulação; o de terra fica fora).
- Usados: janelas e preços dos 60 períodos de 10 dias do GT2. Novos: só os carros que
  nunca aparecem no usado.
- 38 eventos de 18 séries sem licença, B e A (`SERIES` em `tools/importar_gt2.py`), com
  voltas, limites, prêmios e adversários do GT2. Pista do GT2 vira a nossa pela função.
- Licenças B e A: restrição = mediana dos limites dos eventos que abrem; tempos calibrados
  pela simulação.
- `tools/simular_progressao.gd` imprime a posição de cada carro de fábrica em cada evento.

## Como conferir a fração de revenda no GT2

No DuckStation, num save de teste (nunca nos saves existentes; copie o memory card antes):

1. Anote o preço de tabela de 3 a 5 carros (novo na concessionária ou no usado).
2. Compre, vá à garagem, escolha vender e anote o valor oferecido, sem peças instaladas.
3. Repita com um carro com peças, para confirmar que peças não entram no valor.
4. Fração = valor de venda ÷ preço de tabela. Se for igual em todos, ela vai para
   `tools/importar_gt2.py` (não editar `economia.json` à mão); se variar (por exemplo, com
   a quilometragem), anote os casos e o critério muda.

