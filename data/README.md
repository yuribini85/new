# data/

Balanceamento consumido pelo autoload `Dados` (`autoload/dados.gd`). **Nenhum valor aqui é
inventado:** os números vêm do estudo do GT2 e de playtest. O que ainda falta aparece em
`Dados.pendencias()` e como aviso ao abrir o projeto.

Os campos obrigatórios de cada arquivo estão em `Dados.ESQUEMAS`. Exemplos completos e
sintéticos (só para teste) em `tests/fixtures/`.

| Arquivo | Formato |
|---|---|
| `fabricantes.json` | lista de `{id, nome, escola}` |
| `carros.json` | lista de `{id, fabricante, arquetipo_ref, categoria, tracao, potencia, peso, aderencia, freio, velocidade_max, preco, ano}` |
| `pecas.json` | lista de `{id, categoria, efeitos, preco}`, opcionais `tracao_permitida`, `carros_permitidos` |
| `pneus.json` | lista de `{id, aderencia: {seco, chuva}, preco}` |
| `pistas.json` | lista de `{id, funcao, trechos}` |
| `pilotos_ia.json` | lista de `{id, ritmo, consistencia, agressividade}` |
| `simulacao.json` | objeto com os parâmetros de `Simulacao.PARAMS` |

## Unidades e semântica

- `tracao`: `FF`, `FR`, `MR`, `RR` ou `4WD`.
- `potencia` em cv; `peso` em kg; `velocidade_max` em km/h.
- `aderencia`: coeficiente de atrito do carro. Multiplicado pela aderência do pneu na
  condição (`seco`/`chuva`). A curva limita a velocidade a `sqrt(aderência · g · raio)`.
- `freio`: fração da aderência usada na frenagem (desaceleração = freio · aderência · g).
- `efeitos` de peça: lista de `{atributo, op, valor}`, `op` = `soma` ou `mult`. Todas as
  somas são aplicadas antes das multiplicações. Uma peça por `categoria`.
- `trechos`: `{tipo, comprimento_m, raio_m (curvas), ultrapassagem (bool),
  pontos_trajetoria (visualização)}`. Tipos em `Pista.TIPOS`. Trechos de box ficam fora
  da volta no primeiro build.
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
