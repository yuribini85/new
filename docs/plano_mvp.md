# Apex Garage — plano operacional do primeiro build

Desdobramento de `docs/conceito.md` em sistemas, dados e ordem de trabalho. Estruturas abaixo
são formato, não balanceamento: **nenhum número aqui é definitivo**. Os valores virão do
estudo do GT2 e de playtest, sempre em JSON externo.

## 1. Escopo do primeiro build

Entra:

- 1 concessionária de novos, 1 de usados
- ~15 carros de 3 fabricantes fictícias (faixa de entrada do GT2: compactos, esportivos leves, um turbo)
- garagem com coleção
- 5 categorias de peça + 3 compostos de pneu (incluindo chuva)
- 2 licenças
- 3 pistas, uma de cada função: rápida, técnica, montanha
- ~6 eventos com restrição de entrada, prêmio em dinheiro e 1 carro-prêmio
- simulação de corrida + visualização isométrica
- save local e progresso offline

Fica fora: lore, endurance, box com estratégia, clima dinâmico além de seco/chuva,
monetização, pipeline 3D completo (o primeiro build usa sprites placeholder).

## 2. Sistemas

| Sistema | Responsabilidade | Depende de |
|---|---|---|
| Dados | carregar JSON de carros, peças, pistas, eventos, licenças | — |
| Economia | saldo, compra, venda, prêmio | Dados |
| Garagem | carros possuídos, peças instaladas, estado | Economia |
| Concessionária | estoque de novos; estoque rotativo de usados | Economia, Garagem |
| Tuning | instalar peça → recalcular atributos efetivos | Garagem |
| Elegibilidade | checar restrição do evento contra o carro e as licenças | Garagem, Licenças |
| Simulação | resolver a corrida trecho a trecho | Tuning, Pistas |
| Visualização | animar sprites a partir do resultado da simulação | Simulação |
| Carreira | eventos, campeonatos, licenças, carros-prêmio | tudo acima |

A visualização **lê** a simulação; nunca a influencia. Isso permite resolver corridas
offline sem renderizar nada.

## 3. Modelo da simulação

### Pista
Lista ordenada de trechos. Cada trecho:

```json
{ "tipo": "curva_media", "comprimento_m": 0, "raio_m": 0,
  "ultrapassagem": false, "pontos_trajetoria": [[0,0],[0,0]] }
```

Tipos: `reta`, `curva_lenta`, `curva_media`, `curva_rapida`, `frenagem`, `aceleracao`,
`entrada_box`, `saida_box`.

### Carro (atributos efetivos, já com peças)
`potencia`, `peso`, `tracao` (FF/FR/MR/RR/4WD), `aderencia`, `freio`, `velocidade_max`,
`composto_pneu`.

### Piloto de IA
`ritmo`, `consistencia`, `agressividade`. O mesmo modelo serve jogador e adversários.

### Resolução
Para cada carro, para cada trecho: velocidade de entrada, velocidade-alvo do trecho
(limitada por aderência em curva, por potência/peso em aceleração, por velocidade máxima
em reta) e tempo gasto. Ruído controlado por `consistencia`. Ultrapassagem só em trechos
marcados, decidida pela diferença de ritmo naquele trecho e por `agressividade`.

Saída: série temporal de posição ao longo da trajetória por carro. A visualização
interpola sobre ela e escolhe a direção do sprite (16) pelo ângulo da tangente.

### Calibração
Tempos de volta e velocidades do GT2 servem de alvo: se o carro-arquétipo X faz Y na pista
de função Z no GT2, o equivalente fictício deve ficar na mesma ordem relativa. A meta é
preservar **ordem e distância relativa** entre carros, não tempos absolutos.

## 4. Arquivos de dados

```
data/fabricantes.json   id, nome, escola (jp/de/it/us/uk/fr), descrição
data/carros.json        id, fabricante, arquétipo_ref, categoria, tração, potência, peso, preço, ano
data/usados.json        regras de estoque: faixa de km, desconto, rotação
data/pecas.json         id, categoria, efeitos por atributo, preço, compatibilidade
data/pneus.json         compostos, aderência seco/chuva, preço
data/pistas.json        id, função, trechos
data/eventos.json       id, restrições, adversários, voltas, prêmios, carro-prêmio
data/licencas.json      id, testes, requisito
data/pilotos_ia.json    perfis de piloto
```

`arquétipo_ref` guarda a referência de estudo (ex.: "hatch FF leve de entrada") e não o
nome real do carro — esse campo pode ir para o build sem problema.

## 5. Pipeline de carros (ordem de construção)

1. Planilha de referência a partir do GT2: arquétipo, categoria, potência, peso, preço,
   tração, posição na progressão. Uso interno, nunca empacotado.
2. Agente gera ficha fictícia: fabricante, nome, números ajustados, briefing de design.
3. Modelo 3D simplificado (low-poly, paleta limitada).
4. Renders: concessionária, garagem, miniatura.
5. Render em 16 direções → redução → tratamento pixel art → spritesheet.
6. Validação: silhueta não pode reproduzir carro real; nome não pode colidir com marca.

Etapas 1–2 entram no primeiro build. 3–5 podem esperar: o build roda com sprites
placeholder por categoria.

## 6. Ordem de implementação

1. Dados — loader dos JSON, carro com atributos efetivos
2. Simulação headless — uma pista, dois carros, saída em texto; calibrar ordem relativa
3. Economia + garagem + concessionária de novos
4. Tuning e pneus, com uso automático de pneu de chuva
5. Eventos e elegibilidade
6. Visualização isométrica sobre a simulação já pronta
7. Usados, licenças, carros-prêmio
8. Save e offline

Cada etapa testada antes da próxima. A simulação vem antes da tela porque é o único risco
técnico real do projeto.

## 7. Riscos

- **Jurídico.** Usar o GT2 só como referência de estudo. Não empacotar código, modelos,
  texturas, músicas, nomes de carros, marcas ou traçados reconhecíveis. Dados numéricos
  devem ser reajustados, não copiados em bloco.
- **Design parecido demais.** O pipeline precisa de uma etapa explícita de checagem
  contra carros reais (item 5.6).
- **Corrida sem tensão.** Sem pilotagem, a corrida vira espera. Mitigação já prevista:
  isometria legível, ultrapassagens visíveis, opção de pular e ver só o resultado.
- **Deriva para Motorsport Manager.** Qualquer decisão durante a corrida está fora. Se
  surgir pedido de estratégia de box, recusar no primeiro build.

## 8. Decisões tomadas

1. **Engine: Godot 4.4.** 2D isométrico e exportação mobile resolvidos; código de save e
   offline de The Way Back (branch `backup/the-way-back`) pode ser adaptado.
2. **Offline de verdade.** As corridas acontecem com o app fechado e são resolvidas em
   lote na volta, pela simulação headless, com relatório de resultados, dinheiro e
   prêmios. Há um teto de tempo offline; o valor é balanceamento, fica em JSON.
3. **Um carro por vez, com fila de repetições.** O jogador escolhe evento, carro e número
   de repetições; offline, a fila é consumida. Corridas simultâneas com vários carros
   ficam fora do primeiro build.
4. **Licença é teste de tempo com o carro do próprio jogador.** Tempo-alvo numa pista,
   sob uma restrição de entrada. O resultado depende da compra e da preparação. Usa a
   mesma simulação das corridas. Graus ouro, prata e bronze.
5. **Usados giram por número de corridas**, não por tempo real. Cada corrida conta como
   um dia, como no GT2. Imune a manipulação do relógio; a fila offline avança o estoque.
6. **Fabricantes: 3 no primeiro build, 8 a 10 no lançamento.** Primeiro build: uma
   japonesa, uma alemã e uma de outra escola. Lançamento: ~3 japonesas, 2 alemãs, 1
   italiana, 1 americana, 1 britânica, 1 francesa.
7. **Nome provisório: Apex Garage.** Pendente de busca de marca registrada e nas lojas
   (App Store e Google Play) antes de ser fechado.

### Decisões de implementação (aprovadas)

8. **Ordem:** etapa 7 (usados, licenças, carros-prêmio) antes da 6 (visualização).
9. **Licença:** testes com pista, voltas, condição e restrição fixas; tempos de ouro,
   prata e bronze em `licencas.json`; concedida com todos os testes em bronze ou melhor.
10. **Usados:** cada carro tem uma faixa de dias em que aparece; quilometragem sorteada
    por período afeta só o preço.
11. **Piloto do jogador:** perfil fixo (`carreira.json`), sem evolução.
12. **Eventos:** restrições do GT2 (potência efetiva, tração, categoria, fabricante, ano,
    licença); jogador larga em último; prêmio por posição a cada disputa; carro-prêmio só
    na primeira vitória.
