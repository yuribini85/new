# Apex Garage (nome provisório)

Jogo mobile idle de automobilismo, feito em Godot 4.4. O nome ainda depende de busca de
marca registrada.

Preserva a estrutura de carreira de um Gran Turismo clássico — comprar carros novos e usados, preparar, correr eventos, ganhar prêmios,
colecionar — e substitui a pilotagem por corridas automáticas isométricas.

## Estado

Todas as etapas (1 a 8) da ordem de implementação (`docs/plano_mvp.md`, seção 6) feitas: carga e
validação dos dados, carro com peças e pneus, pista em trechos, simulação de corrida
headless, saldo, garagem, concessionária de novos, eventos com restrições de entrada,
prêmios, carro-prêmio, licenças, usados, fila de repetições, progresso offline, save,
corrida isométrica ao vivo e telas provisórias (sem arte). `data/` tem o balanceamento
importado do disco do GT2: o jogo abre e é jogável. Falta o balanceamento real — ver
`data/README.md`. Ainda não há telas.

## Estrutura

```
autoload/dados.gd       carga e validação de data/*.json
data_model/carro.gd     atributos efetivos com peças e escolha automática de pneu
data_model/pista.gd     pista como lista de trechos tipados
data_model/economia.gd  saldo
data_model/garagem.gd   carros possuídos (coleção)
data_model/concessionaria.gd  compra e venda de carros, peças e pneus
data_model/elegibilidade.gd   restrições de entrada dos eventos
data_model/carreira.gd  disputa de eventos: grid, simulação, prêmios
data_model/licencas.gd  testes de licença e concessão
data_model/usados.gd    estoque de usados por faixa de dias
data_model/fila.gd      fila de repetições e progresso offline
data_model/save.gd      serialização do estado do jogador
autoload/save_manager.gd  grava/lê user://save.json e processa o offline ao abrir
visual/                 projeção isométrica, sprite provisório (16 direções), corrida ao vivo
ui/                     telas: garagem, loja, oficina, eventos, corrida, licenças
scenes/principal.tscn   cena principal (retrato 720×1280)
tools/editor_pista.tscn visualizador de pistas: traçado, zonas e fechamento da volta
tools/captura_telas.gd  captura PNG de todas as telas com dados de teste
autoload/jogador.gd     estado do jogador (saldo, garagem, licenças, vitórias, dias)
sim/simulacao.gd        corrida headless (envelope de velocidade + cortesia)
data/                   balanceamento (vazio até o estudo do GT2)
tests/                  testes e fixtures sintéticas
```

## Testes

```
tests/rodar.sh            # ou: tests/rodar.sh /caminho/do/godot
```

Rodam também no GitHub Actions a cada push e pull request.

## Ver as telas antes do balanceamento

Com `data/` vazio o jogo mostra a lista de pendências. Para navegar com os dados
sintéticos dos testes:

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
