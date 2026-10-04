# Apex Garage (nome provisório)

Jogo mobile idle de automobilismo, feito em Godot 4.4. O nome ainda depende de busca de
marca registrada.

Preserva a estrutura de carreira de um Gran Turismo clássico — comprar carros novos e usados, preparar, correr eventos, ganhar prêmios,
colecionar — e substitui a pilotagem por corridas automáticas isométricas.

## Estado

Demo jogável. As oito etapas da ordem de implementação (`docs/plano_mvp.md`, seção 6)
estão feitas, `data/` tem o balanceamento importado do disco do GT2 e há telas
provisórias para celular em retrato (sem arte).

O que existe hoje:

- concessionária de novos e usados (usados por período, como no GT2), garagem, oficina
  com peças e pneus por carro, venda;
- 38 eventos em 18 séries sem licença, B e A; licenças B e A por teste de tempo;
- corrida resolvida pela simulação e reproduzida em isometria, em tempo real;
- fila de repetições, progresso offline com teto, save com `.bak` e proteção contra
  arquivo corrompido ou de versão antiga.

Em aberto: o percurso inicial (20–30 min) ainda não foi fechado nem testado em celular;
há pouca variação entre corridas (ruído zero e pilotos iguais) e alguns valores "a
confirmar" em `data/README.md`.

## Jogar

Abra a pasta no Godot 4.4 (Importar → `project.godot`) e aperte F5. O save fica em
`user://save.json` (no Windows, `%APPDATA%\Godot\app_userdata\Apex Garage\`).

## Estrutura

```
autoload/dados.gd             carga e validação de data/*.json
autoload/jogador.gd           estado do jogador (saldo, garagem, licenças, vitórias, dias)
autoload/save_manager.gd      save com .bak e proteção; processa o offline ao abrir
data_model/                   carro, pista, economia, garagem, concessionária, elegibilidade,
                              carreira, licenças, usados, fila, save
sim/simulacao.gd              corrida headless (envelope de velocidade, arrasto, cortesia)
visual/                       projeção isométrica, carro provisório (16 direções), corrida ao vivo
ui/                           telas: garagem, loja, oficina, eventos, corrida, licenças
scenes/principal.tscn         cena principal (retrato 720×1280)
data/                         balanceamento (gerado do GT2; ver data/README.md)
tools/                        extração e importação do GT2, calibração, editor de pistas,
                              captura de telas, matriz de progressão
tests/                        testes Godot e Python, fixtures sintéticas
```

## Testes

```
tests/rodar.sh            # ou: tests/rodar.sh /caminho/do/godot
```

Roda os testes Godot (fixtures sintéticas) e os das ferramentas Python (disco
sintético). Também roda no GitHub Actions a cada push e pull request.

## Dados do GT2

`data/` é gerado a partir de uma cópia legítima do disco pelo fluxo
`tools/extrair_gt2.py` → `tools/importar_gt2.py` → `tools/calibrar_licencas.gd`. Passo a
passo, conversões e o que ainda está "a confirmar" em `data/README.md`.
`tools/simular_progressao.gd` mostra a posição de cada carro de fábrica em cada evento.

## Ver as telas com dados de teste

```
godot -- --dados=res://tests/fixtures/
```

O save desse modo fica separado (`user://save_fixtures.json`).

## Documentos

| Arquivo | O que é |
|---|---|
| `docs/conceito.md` | Conceito, princípios e limites do projeto. |
| `docs/plano_mvp.md` | Escopo do primeiro build, sistemas, modelo da simulação, dados, ordem de implementação, riscos e decisões tomadas. |

## Regras do projeto

1. O jogador decide; a IA executa. Nenhuma decisão durante a corrida.
2. Não é Motorsport Manager.
3. Não inventar sistema quando o GT2 já tem uma solução que funciona.
4. O movimento visual é consequência da simulação, nunca o contrário.
5. A mesma IA controla o jogador e os adversários.
6. Carros, fabricantes, pistas e arte são originais. Nenhuma marca, nome ou traçado real.
7. O GT2 é referência de estudo a partir de cópia legítima. Nada dele é redistribuído.
8. Lore só depois que o jogo funcionar, e sem sistema novo.

## Histórico

O conteúdo anterior deste repositório (The Way Back / Dreadwick HUD) está preservado na
branch `backup/the-way-back`.
