# Site oficial — Chrome & Wreckage

Página única (PT/EN) que convoca testadores para o teste fechado da Google Play.
Arquivos estáticos: `index.html`, `img/`, `fontes/`. Sem servidor: as inscrições
vão para um formulário do Google, que grava numa planilha.

Este diretório tem `.gdignore` para o Godot não importar as imagens no projeto do jogo.

## 1. Formulário do Google (onde caem as inscrições)

1. Em forms.google.com, crie um formulário em branco com 5 perguntas, **todas do tipo
   "Resposta curta"**, nesta ordem: `E-mail`, `Origem`, `Indicado por`, `Código`, `Idioma`.
   O visitante só digita o e-mail; o resto o site preenche sozinho:
   - `Origem`: de onde veio (`?ref=reddit`, `?utm_source=instagram`, ou o site anterior).
   - `Código`: o código pessoal do inscrito; o link dele para indicar é `?i=CÓDIGO`.
   - `Indicado por`: o código de quem indicou. Contar quantas vezes cada código aparece
     nessa coluna dá o ranking de indicações.
   - Não ligue "Coletar endereços de e-mail" nem "Restringir a usuários": isso obriga
     login e o envio pelo site falha.
   - Não marque nenhuma como obrigatória (o site já confere).
2. Aba **Respostas** → ícone do Planilhas → criar planilha. A lista de inscritos fica ali.
3. Menu ⋮ → **Gerar link pré-preenchido**. Preencha as 5 perguntas com qualquer coisa,
   clique em **Gerar link** e copie o link.
4. Mande o link para o Claude (ou preencha você): o trecho depois de `/forms/d/e/` até
   `/viewform` é o `id`, e cada `entry.NNNNN` é o número de uma pergunta, na ordem acima.
   Eles vão no bloco `FORMULARIO` no fim do `index.html`.

Enquanto o `id` estiver vazio, o botão de enviar avisa que as inscrições ainda não abriram.

## 2. Publicar (GitHub Pages) e ligar o domínio

O site sai no mesmo GitHub Pages da demo do jogo: o workflow `.github/workflows/pages.yml`
publica esta pasta na raiz e a demo em `/demo/`, a cada push (só se os testes passarem).

1. Settings → Pages → Custom domain: digite o domínio (ex.: `www.seudominio.com`) e salve.
   Marque **Enforce HTTPS** quando liberar.
2. No painel do registrador do domínio:
   - `www` → registro **CNAME** apontando para `yuribini85.github.io`
   - domínio sem `www` → 4 registros **A**: `185.199.108.153`, `185.199.109.153`,
     `185.199.110.153`, `185.199.111.153`
3. A propagação leva de minutos a algumas horas.

Depois que o domínio estiver definido, trocar `og:image` no `index.html` pelo endereço
completo (`https://seudominio.com/img/compartilhar.jpg`): Instagram, WhatsApp e fóruns
só mostram a imagem de prévia com o endereço completo.

## 3. Da planilha para o Play Console

Play Console → Testar → Teste fechado → Testadores → criar lista de e-mails →
colar a coluna `E-mail` da planilha (ou enviar como CSV). Depois, copiar o link de
inscrição do teste e mandar por e-mail para a lista.

## Divulgação

Use um `ref` diferente em cada lugar onde postar, para saber o que trouxe gente:

- Instagram (bio): `https://seudominio.com/?ref=instagram`
- Reddit: `https://seudominio.com/?ref=reddit&lang=en`
- Grupos de WhatsApp: `https://seudominio.com/?ref=whatsapp`
- Fórum X: `https://seudominio.com/?ref=forum-x`

Imagem de prévia para redes: `img/compartilhar.jpg` (1200×630). Vídeo da arena para
stories e posts: `img/arena.mp4` (14 s, vertical, sem som).

Contagem de visitas (para saber a taxa de inscrição por origem): crie uma conta grátis em
goatcounter.com e ponha o código na constante `GOATCOUNTER` do `index.html`. Não usa
cookies, então não precisa de aviso de cookies.

## Promessas da página que dependem do jogo

A página promete a quem completar o teste: **pintura Fundador exclusiva** e **nome nos
créditos**. As duas precisam existir no jogo até o lançamento.
