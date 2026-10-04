# Gran Turismo Idle Mobile — conceito

> Projeto separado de The Way Back. Fica neste repositório só como registro.
> Nada aqui altera o escopo, as regras ou os dados de The Way Back.

## Princípio central

Preservar a estrutura de carreira, compra, coleção, preparação e progressão de um Gran
Turismo clássico; substituir a pilotagem por corridas automáticas isométricas; e criar
carros, fabricantes, pistas, arte e universo próprios.

Não é recriar Gran Turismo inteiro. Não é Motorsport Manager.

## Por que este projeto

- Deve ser simples e rápido de desenvolver depois de Dreadwick.
- Alternativa ao projeto de guildas medievais (inspirado em Mob Rule), que exigiria
  construção, população, pathfinding, economia, facções, prefeitura, igreja,
  trabalhadores, conflitos e IA sistêmica interligados.
- Este funciona principalmente com telas de gestão, banco de dados e uma simulação de
  corrida simples.
- **Regra de desenvolvimento:** não inventar sistema novo quando o GT2 já tem uma solução
  que funciona.

## O que se preserva do GT2

Comprar carros novos e usados · concessionárias · garagem · tuning e peças · pneus ·
campeonatos e eventos · restrições de entrada · licenças · dinheiro e prêmios · carros-prêmio
· coleção · progressão de carros baratos para melhores.

## O que muda: idle

O jogador decide; a IA executa.

1. Compra o carro.
2. Compra as peças.
3. Prepara o veículo.
4. Escolhe o evento.
5. Coloca o carro para correr.

Equipamento comprado é usado automaticamente quando necessário (ex.: pneu de chuva).
A decisão econômica fica; o microgerenciamento durante a corrida sai.

## Corridas

- Automáticas, em perspectiva isométrica.
- Sem física sofisticada e sem IA de direção tradicional.
- Cada pista tem uma trajetória invisível dividida em trechos: retas, curvas lentas,
  médias e rápidas, frenagens, acelerações, zonas de ultrapassagem, entrada e saída de box.
- O desempenho em cada trecho depende de atributos do carro, preparação e piloto.
- **O movimento visual é consequência da simulação**, nunca o contrário.
- A mesma IA controla o carro do jogador e os adversários.

### IA de referência

O GT2 é estudado, não copiado: tempos de volta, velocidades, diferença entre pilotos,
pontos de frenagem, relação carro × pista, comportamento dos adversários e curva de
progressão. Depois se reconstrói uma versão muito mais simples.

## Pistas

Originais. Pistas reais e do GT servem para entender a **função** do traçado:

- muito rápido
- técnico
- montanha
- alta velocidade
- urbano
- endurance longo

Como a IA lê trechos tipados e não a geometria, ela continua funcionando quando o
traçado muda completamente.

## Direção visual

- Pixel art isométrica.
- Carros nascem como modelos 3D, usados em garagem, concessionária, apresentação e ficha.
- Na pista: o mesmo modelo renderizado em ~16 direções, reduzido e tratado como pixel art.
  Ou seja, sprites 2D pré-renderizados.

## Pipeline automatizado de carros

Um agente recebe do GT2 referências de modelo, proporções, categoria, potência, peso,
preço, tração e posição na progressão, e produz um **equivalente fictício**.

Não é trocar o nome de um Toyota e colocar um aerofólio. Preserva-se o arquétipo e a
função; design e identidade são próprios.

Saídas automáticas: modelo 3D simplificado, cores, render de concessionária, render de
garagem, miniatura, sprites isométricos, versões em pixel art.

Objetivo: criação de carros como linha de produção contínua.

## Fabricantes fictícias

Sem Toyota, Nissan, BMW, Mercedes etc. Fabricantes próprias inspiradas nas escolas
automobilísticas. O fã reconhece o arquétipo (o papel de um Civic antigo, de um Skyline,
de um RX-7), mas o carro e a marca são deste universo.

## GT2 como matriz de estudo

Escolhido por ter progressão simples, muitos carros, usados, concessionárias, tuning,
licenças, campeonatos, economia, carros-prêmio e trabalho comunitário de engenharia
reversa (decompilação, ferramentas de modelos, texturas e bancos de dados).

Referência: versão americana, Simulation Disc 1.2, executável `SCUS_944.88`.

Os arquivos originais servem para estudo a partir de cópia legítima. **Nada deles é
redistribuído no jogo** — nem código, nem modelos, nem texturas, nem nomes.

## Lore

Entra depois que o jogo funcionar e não exige sistema novo. Aparece em: história das
fabricantes, rivalidades, pilotos históricos, campeonatos, carros lendários, projetos
fracassados, acidentes, corridas históricas, carros raros, histórico dos usados,
fabricantes falidas, modelos proibidos, espionagem industrial, recordes.

A garagem vira também uma coleção da história automobilística do universo.
