# Playtest do percurso inicial

Objetivo: saber se uma pessoa que nunca viu o jogo, **sem orientação**, entende o que
comprar e por quê nos primeiros 20–30 minutos. O teste automático
(`tests/test_percurso.gd`) já garante que o caminho existe; aqui se mede se ele é
encontrado e compreendido.

## Preparação

- Save zerado: apagar `save.json` e `save.json.bak` em
  `%APPDATA%\Godot\app_userdata\Apex Garage\` (ou o equivalente no celular).
- `PERMITIR_PULAR` (em `ui/aba_corrida.gd`) **ligado**: sem ele a sessão vira espera.
  Anote quantas vezes a pessoa usa e quantas assiste à corrida inteira.
- Celular em retrato, se possível; senão, a janela de 405×720 no PC.
- Gravar a tela e o áudio (pedir para pensar em voz alta).

## O que dizer

Só isto: "É um jogo de carreira de corridas em que você não pilota. Jogue como quiser
até eu pedir para parar. Fale em voz alta o que está pensando." Não responder perguntas
sobre o jogo durante a sessão; se a pessoa travar por mais de 2 minutos, anotar onde e
só então dizer "o que você tentaria agora?".

## Pontos a observar (anotar o minuto)

| # | Momento | Pergunta da observação |
|---|---|---|
| 1 | Loja | Escolheu um usado com ★? Leu a faixa ("1º–2º nos testes")? Disse por que escolheu? |
| 2 | Garagem/Eventos | Achou como correr? Quanto tempo levou da compra até a primeira corrida? |
| 3 | Primeira corrida | Assistiu ou pulou? Entendeu a classificação e a cor do próprio carro? |
| 4 | Primeira derrota | Leu o painel "Última corrida"? Comentou a diferença para o vencedor (cv, kg)? |
| 5 | "O que ajuda?" | Apertou sem ser pedido? Leu "nos testes" como estimativa ou como promessa? |
| 6 | Compra | Comprou a opção sugerida, outra, ou nenhuma? Explicou o motivo? Viu o aviso ⚠ se apareceu? |
| 7 | Revanche | Voltou à mesma prova? Ganhou? Atribuiu o resultado à compra? |
| 8 | Licenças | Descobriu sozinha que precisava de licença? Entendeu bronze/prata/ouro? |
| 9 | Fim | Em que ponto parou de querer jogar, se parou? |

Sinal de problema: a pessoa compra algo e piora sem entender por quê; aperta "O que
ajuda?" e não confia; ou passa mais de 5 minutos sem correr.

## Perguntas no fim (abertas, nesta ordem)

1. O que você estava tentando fazer?
2. Por que comprou o que comprou?
3. O que significava "1º–3º nos testes"?
4. Por que você perdeu a corrida que perdeu?
5. O que faria nos próximos 10 minutos?

## Ficha (uma por pessoa)

```
Pessoa:            Data:         Aparelho:
Min. até 1ª corrida:        Min. até 1ª derrota:       Min. até 1ª compra:
Comprou o sugerido? (s/n/outro):      Resolveu a prova que motivou? (s/n):
Licença B obtida? (min):              Pulos / corridas assistidas:   /
Entendeu "nos testes" como estimativa? (s/n/?):
Travou em (onde, min):
Frases marcantes:
```

Três a cinco pessoas bastam para achar os problemas grandes. Repetir depois de cada
ajuste de interface.
