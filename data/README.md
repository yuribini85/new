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
| `eventos.json` | lista de `{id, nome, pista, voltas, condicao, restricoes, adversarios, premios}`, opcionais `carro_premio`, `largada_kmh` |
| `licencas.json` | lista de `{id, nome, testes}`, opcionais `requisito` (id de outra licença), `gt2`, `preco` |
| `equipes.json` | lista de `{id, nome, pilotos: [{id, nome, retrato?}]}`, opcionais `nivel` (CLUB…ELITE), `numero`, `logo`, `jogador`, `dirigente` |
| `contratos.json` | lista de `{id, licenca, nome, carro, provas, condicoes}`, opcionais `descricao`, `pecas_escola`. **Gerado** por `tools/calibrar_contratos.gd` (não editar à mão) |
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
- `peso_dianteiro` do carro (opcional): fração do peso no eixo dianteiro
  (Chassis.FrontWeightDistribution ÷ 100). A tração usa o peso sobre o eixo motriz:
  dianteiro (FF), traseiro (FR, MR, RR) ou todo (4WD). Transferência de carga na
  aceleração ainda não entra: pede a altura do centro de gravidade, que o GT2 não guarda.
- `motor` do carro (opcional): `{rpm, torque_nm, corte}`. Curva da tabela Engine do GT2
  (TorqueCurve × 0,01 kgf·m → N·m; TorqueCurveRPM × 100; RedlineRPM × 100). Na
  simulação, a curva é escalada para que o pico de potência seja igual a `potencia`
  com as peças. Usamos só a **forma**: não é o modelo físico do GT2.
- `cambio` do carro: `{relacoes, final}` (tabela Gear, ÷ 1000). `raio_roda` em m, do
  TireSize dianteiro (diâmetro do aro + 2 × largura × perfil; leitura a confirmar).
  Com os três, a força na roda é torque × relação × diferencial ÷ raio na melhor marcha,
  e no corte da última marcha o carro não acelera mais. Sem eles, a simulação usa
  potência ÷ velocidade (câmbio ideal).
- Peça `motor` (opcional): `faixa_rpm` e `corte` (rpm a somar, NATune) ou
  `turbo_baixa`/`turbo_alta` (multiplicadores do torque no giro baixo e alto,
  TurbineKit). Peça de categoria `cambio`: `{final_min, final_max}` (estágio 3 do Gear).
Peça de categoria `corrida` (kit de corrida, `RacingModify` estágio 1): preço e peso do
GT2; muda a elegibilidade (copas "Corrida"). Pressão aerodinâmica e arrasto do kit ficam
de fora: a simulação não tem esses termos por carro.
  Os ajustes curto/longo andam `Carro.PASSO_CAMBIO` (0,5, **provisório**, decisão de
  interface) do diferencial de fábrica até esses limites.
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
| `fator_tracao` | `{FF, FR, MR, RR, 4WD}`: fração do peso nas rodas de tração, **só para carro sem `peso_dianteiro`** (fixtures) | FF 0,6 · FR 0,5 · MR 0,55 · RR 0,6 · 4WD 1,0 |

## economia.json

| Chave | O que é | Estado |
|---|---|---|
| `saldo_inicial` | dinheiro no começo do jogo | **pendente** |
| `fracao_revenda` | venda = preço de tabela (novo) × fração, seja qual for o preço pago; peças não entram no valor | 0,25 — medido no GT2 (3 carros: 8.000→2.000, 6.400→1.600, 2.800→700) |
| `pneu_de_fabrica` | id em `pneus.json` com que todo carro novo chega | **pendente** |

Regras fixas no código (`data_model/concessionaria.gd`): peça comprada fica com o carro e
reinstalá-la é grátis; um pneu de cada composto por carro; nada é cobrado se a compra é
recusada.

## eventos.json

- `condicao`: `seco` ou `chuva`, fixa por evento.
- `restricoes` (todas opcionais, ver `data_model/elegibilidade.gd`): `potencia_max` (cv
  efetivos, já com peças), `tracao`, `categoria`, `fabricante` (listas), `ano_min`,
  `ano_max`, `licenca`, `carros` (lista de ids: copas de marca do GT2, `Regulations`) e
  `corrida` (`true`: só versão de corrida, isto é, carro com a peça `corrida` ou carro
  `corrida` de fábrica; `false`: só carro de rua sem o kit; `CarRestrictionFlags` 512/256).
- `largada_kmh`: largada lançada (`RollingStartSpeed` do GT2); sem ela, largada parada.
- `adversarios`: lista de `{carro, piloto, pecas?, pneus?, potencia_mult?}`; sem `pneus`,
  usa o de fábrica. `potencia_mult` e `pneus` são a preparação do rival no GT2
  (`EnemyCars.PowerMultiplier` ÷ 100 e o estágio de `TiresFront`).
- Copas de marca: prova única por modelo (nome sem "etapa"); o GT2 sorteia a pista, aqui
  ela gira pelas pistas de corrida (`POOL_MARCA` no importador).
- `premios`: dinheiro por posição (índice 0 = 1º). Posições além da lista não recebem.

Regras fixas no código (`data_model/carreira.gd`), seguindo o GT2: o jogador larga em
último; o prêmio em dinheiro é pago a cada disputa; o carro-prêmio só na primeira vitória;
cada corrida disputada conta um dia.

## licencas.json

Licenças CLUB, SPORT, NATIONAL, INTERNATIONAL, PRO e ELITE (decisão 33): CLUB=B, SPORT=A,
NATIONAL=IC, INTERNATIONAL=IB, PRO=IA do GT2 (campo `gt2`); ELITE (a S, sem dados no
disco) libera as 7 resistências e não tem testes (avaliação por contratos). Estados e
regras em `data_model/licencas.gd`: requisitos (anterior; vencer em `fracao_series` das
séries da anterior; a partir de `campeonato_desde`, um título da anterior quando ela tem
campeonato), treino com duração = soma dos bronzes dos testes × `fator_treino` (**a
confirmar** no playtest; sem testes, a da anterior), começado pelo jogador, contado pelo
relógio (offline também), e a avaliação só depois do treino. Configuração em
`carreira.json` → `licencas`. Preço 0 (no GT2 a licença é grátis).

Equipe do jogador (decisão 38, `carreira.json` → `equipe_jogador`): caixa único (o
saldo); a cada corrida entra `patrocinio` e sai `custo_staff`. Valores em Cr;
**pendentes do playtest** (`null` = 0 até lá; a aba Equipe mostra "a definir").
`segundo_piloto`: quem entra na equipe na cena que libera, sem contrato nem salário
(`provisorio` até o nome do Drive).

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
| `pista_de_testes` | velocidade máxima (retas muito longas) | 4.112 m | reta principal e reta oposta |
| `circuito_misto` (Colinas do Vinhedo) | misto permanente (grupo 4) | 2.600 m | reta principal e reta oposta |
| `docas_curta` | técnico, versão curta | 1.457 m | três retas |
| `anel_curto` | alta velocidade, versão curta | 2.101 m | reta principal e reta oposta |
| `serra_curta` | montanha, versão curta | 1.356 m | reta de largada e duas retas finais |

As versões curtas recebem os eventos das versões curtas do GT2 e usam o cenário da
pista-mãe (`Corrida3D.TEMA_DE`).

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

**A confirmar** (não vêm do GT2): `teto_offline_s` (8 h, decisão de design),
`sigma_ruido`, `cda_m2`, consistência e agressividade dos pilotos (1,0).

## Estado atual de data/ (importado do GT2 americano, SCUS-94488 v1.2)

- **618 carros**, todos os do disco (538 de rua e 80 versões de corrida). Nome e fabricante
  fictícios: `tools/gerar_referencia_carros.py` monta `referencia/carros.csv` (fora do Git)
  com um fabricante inventado por fabricante do GT2 (36) e um nome por família de modelo,
  no idioma da escola do fabricante; as versões da família vão por potência (base, S, GT,
  GTS, R, SR, GX, SX; corrida = "Corrida") e levam o ano quando preciso. Os 17 do primeiro
  build mantêm id, nome e fabricante. **Busca de marca pendente** antes do lançamento.
- 7.717 peças com preço e efeito do GT2 (por carro); 7 compostos de pneu.
- Usados: janelas e preços dos 60 períodos de 10 dias do GT2 (~140 por período). Novos:
  os 420 que nunca aparecem no usado.
- 103 eventos de 31 séries sem licença, B, A, IC, IB e IA (`SERIES` em
  `tools/importar_gt2.py`), com voltas, limites, prêmios, adversários (o carro do próprio
  GT2) e carros-prêmio do disco. Resistência: as 7 provas do GT2 (30 a 99 voltas), prova
  única, sem pit stop nem desgaste de pneu. Copas de marca: 94 provas (ver `eventos.json`).
  Fora: rali e terra e a licença S (sem pista no disco). Pista do GT2 vira a nossa pela função
  (`PISTAS` no importador; grupos em `docs/pistas_arquetipos.md`).
- Licenças CLUB a PRO (B, A, IC, IB, IA do GT2): restrição = mediana (B) ou mediana e quartis (as outras) dos
  limites dos eventos que abrem; tempos calibrados pela simulação
  (`tools/calibrar_licencas.gd`). **Pendente:** o critério da ferramenta parte dos carros
  iniciais (B) ou do jogador ao tirar a B (A); IC, IB e IA saíram com os tempos da B. Falta
  decidir o ponto de partida de cada licença alta.
- Lojas (como no GT2): uma concessionária de novos por fabricante, agrupadas por região
  (Japão, Estados Unidos, Europa, pela escola do fabricante); usados em lotes por
  fabricante (no GT2 só as marcas japonesas têm lote). As versões de corrida ficam na
  concessionária do fabricante.
- Contratos da B (`contratos.json`): mantidos da calibração com os 17 carros (os carros e
  peças deles não mudaram). Recalibrar com os 618 pede restringir a busca de
  `tools/calibrar_contratos.gd`, que é por pares de carros.
- `tools/simular_progressao.gd` imprime a posição de cada carro de fábrica em cada evento.

## Como conferir a fração de revenda no GT2

No DuckStation, num save de teste (nunca nos saves existentes; copie o memory card antes):

1. Anote o preço de tabela de 3 a 5 carros (novo na concessionária ou no usado).
2. Compre, vá à garagem, escolha vender e anote o valor oferecido, sem peças instaladas.
3. Repita com um carro com peças, para confirmar que peças não entram no valor.
4. Fração = valor de venda ÷ preço de tabela. Se for igual em todos, ela vai para
   `tools/importar_gt2.py` (não editar `economia.json` à mão); se variar (por exemplo, com
   a quilometragem), anote os casos e o critério muda.

## contratos.json (licenças por contrato, decisão 4)

`provas`: `[{pista, voltas, condicao, rivais: [{carro, pecas?}]}]`. Avaliação em
`Contratos.avaliar`: cada carro corre sozinho, com o piloto do jogador e a semente fixa da
bancada; vencer = tempo menor que o de todos os rivais. `condicoes`: `{bronze, prata,
ouro}`, cada uma com `vencer`, `folga_s`, `custo_max`, `pecas_max` ou `sem_categorias`
(prata e ouro somam ao bronze).

Os carros, rivais, pistas e números são escolhidos por `tools/calibrar_contratos.gd` a
partir dos dados. Voltas e limite de potência do carro da escola vêm dos testes da licença
B (GT2). Critérios **provisórios** (confirmar em playtest), no topo da ferramenta:

| Constante | Valor | Uso |
|---|---|---|
| `RAZAO_GIGANTE` | 1,3 | potência mínima do "gigante" em relação ao carro da escola |
| `FOLGA_CUSTO_BRONZE` / `_PRATA` | 1,5 / 1,2 | teto de custo do bronze e da prata sobre o menor custo achado |
| `FOLGA_MINIMA_DUPLA` | 0,2 s | folga mínima da solução de "Dois circuitos" |
| `FOLGA_PRATA_DUPLA_S` | **pendente** (playtest de clareza) | prata de "Dois circuitos" por folga fixa; enquanto pendente, metade da folga da solução |
| prata por folga | metade da maior folga achada | "O pequeno contra o gigante" e "Dois circuitos" |
