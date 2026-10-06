# Playtest do percurso inicial

Duas modalidades, com objetivos diferentes. **Só o teste de ritmo produz referência de
sessão e renda**; o de clareza mede compreensão e não serve para balanceamento.

| | Clareza | Ritmo |
|---|---|---|
| Pergunta | A pessoa entende o que comprar, preparar, inscrever e por quê? | Quanto dura uma sessão natural, quanto rende e quando a pessoa volta? |
| Modo (Carreira → Preferências → Modo de playtest) | **Clareza** (pode pular a corrida) | **Ritmo** (sem pular) |
| Duração | 20–30 min, o observador encerra | A pessoa para quando quiser; depois sai e volta por conta própria |
| Observador | Presente, anota os pontos abaixo | Presente na primeira sessão; nas voltas, só o registro |

Com o modo ligado, o aparelho grava as sessões em `user://registro_playtest.json`
(resumo em Carreira → Preferências): início e fim, fase (sem licença, B, A) no início e
no fim, saldo, tempo em cada tela (Corrida = acompanhando corrida; as outras = menus),
filas programadas (prova, repetições, duração, desafio ou renda), pulos e ausência
desde a sessão anterior. Nada sai do aparelho. O motivo de saída é perguntado e anotado
pelo observador.

## Preparação (as duas)

- Save zerado: apagar `save.json` e `save.json.bak` em
  `%APPDATA%\Godot\app_userdata\Apex Garage\` (ou o equivalente no celular) e "Apagar
  registro" em Preferências.
- Ligar o modo da modalidade **antes** de começar.
- Celular em retrato, se possível; senão, a janela de 405×720 no PC.
- Clareza: gravar a tela e o áudio (pedir para pensar em voz alta).

## O que dizer

Só isto: "É um jogo de carreira de corridas em que você não pilota. Jogue como quiser.
Fale em voz alta o que está pensando." Clareza: "…até eu pedir para parar." Ritmo:
"…e pare quando quiser; se tiver vontade de voltar mais tarde, volte." Não responder
perguntas sobre o jogo; se a pessoa travar por mais de 2 minutos, anotar onde e só então
dizer "o que você tentaria agora?".

## Clareza: pontos a observar (anotar o minuto)

| # | Momento | Pergunta da observação |
|---|---|---|
| 1 | Mercado | Escolheu um usado com ★? Leu a faixa ("1º–2º nos testes")? Disse por que escolheu? |
| 2 | Garagem/Competições | Achou como correr? Quanto tempo da compra até a primeira corrida? |
| 3 | Primeira corrida | Assistiu ou pulou? Entendeu a classificação e a cor do próprio carro? |
| 4 | Primeira derrota | Leu o resultado? Usou "Testar preparação" ou "O que ajuda?" sem ser pedido? |
| 5 | Compra | Comprou o sugerido, outra coisa ou nada? Explicou o motivo? Viu o aviso ⚠? |
| 6 | Preparações | Salvou uma preparação? Entendeu que a fila guarda a da inscrição? |
| 7 | Desafio e renda | Entendeu por que só a prova vencida repete? Programou uma fila de renda? |
| 8 | Contratos | Achou os contratos? Leu o relatório (curvas/retas, o que falta)? Mudou a montagem por causa dele? Diante de "à frente por X s", chamou a vitória de clara? Anotar a menor folga que a pessoa trata como vantagem (define a prata de "Dois circuitos"). |
| 9 | Fim | Em que ponto parou de querer jogar, se parou? |

Sinal de problema: a pessoa compra algo e piora sem entender por quê; não confia nas
estimativas; ou passa mais de 5 minutos sem correr.

## Ritmo: o que anotar além do registro

- Na primeira sessão: em que momento e por que a pessoa saiu (frase dela).
- Em cada volta (perguntar ou pedir que anote): o que pretendia fazer ao abrir; se
  lembrava do objetivo; se o relatório de retorno ajudou.
- Ao fim do período combinado (ex.: dois dias): quantas vezes voltou e por quê.

Leitura dos números: mediana e intervalo observado por fase, nunca uma média única.
Três a cinco pessoas acham os atritos grandes; **não** fixam uma duração comercial.
A hipótese "uma a duas sessões" vale para compras que abrem possibilidades (próximo
carro de uma fase, peça que muda de prova), não para toda compra.

## Perguntas no fim (abertas, nesta ordem)

1. O que você estava tentando fazer?
2. Por que comprou o que comprou?
3. O que significava "1º–3º nos testes"?
4. Por que você perdeu a corrida que perdeu?
5. O que faria nos próximos 10 minutos (ou na próxima vez que abrir)?

## Ficha (uma por pessoa)

```
Pessoa:            Data:         Aparelho:        Modalidade: clareza / ritmo
Min. até 1ª corrida:        Min. até 1ª derrota:       Min. até 1ª compra:
Comprou o sugerido? (s/n/outro):      Resolveu a prova que motivou? (s/n):
Licença B (min / contratos e medalhas):
Pulos / corridas assistidas:   /      (clareza)
Sessões e voltas (do registro):       Motivo de cada saída:        (ritmo)
Entendeu "nos testes" como estimativa? (s/n/?):
Travou em (onde, min):
Frases marcantes:
```

Repetir depois de cada ajuste de interface. Os números de ritmo entram como parâmetros
de `tools/medir_progressao.gd` (`--sessao_min=`, `--ausencia_h=`).
