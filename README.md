# Lanche Fácil — Gestão do Cardápio

Projeto Flutter da Etapa 3 da disciplina de Desenvolvimento de Aplicações Móveis e Distribuídas, na Faculdade FANS. O funcionário entra com e-mail e senha, consulta os produtos e envia fotos e fichas técnicas. A API armazena os arquivos e o Android exibe uma notificação local após a confirmação do envio.

## Executar

- **Android**. Baixe o APK em [Releases](../../releases/latest) e instale em um dispositivo ou emulador. Se o Android solicitar, autorize a instalação pela origem usada para abrir o APK. O cadastro e o envio precisam de internet.
- **Navegador**. Abra a [versão web da Etapa 3](https://lanche-facil-etapa3.mateus2002ns.workers.dev/app/) para testar o cadastro, o login, o catálogo e os arquivos.
- **Código-fonte**. Com Flutter 3.41.9, Android SDK e JDK 17, execute `flutter pub get` e `flutter run` na raiz. Para usar o Chrome, execute `flutter run -d chrome`.
- **API**. O app usa a [API da Etapa 3](https://lanche-facil-etapa3.mateus2002ns.workers.dev/). O Chrome mantém a sessão em memória até recarregar a página. A notificação local é avaliada no Android.

Use um e-mail de exemplo, como `avaliacao.seunome@exemplo.test`, e uma senha de 8 a 128 caracteres. O cadastro entra na conta imediatamente e dispensa confirmação. Cada conta tem uma cópia lógica do cardápio de exemplo, com anexos visíveis apenas para ela. Use imagens e PDFs de teste.

## Roteiro de avaliação

Siga os passos no Android. Use uma foto PNG ou JPG e um PDF, ambos de até **1 MiB**. Separe também um arquivo acima de 1 MiB. Uma foto próxima do limite em uma rede lenta ajuda a observar a barra de progresso.

| Passo | O que fazer | Resultado esperado |
|---|---|---|
| **1. Cadastro e login** | Abra o app, toque em **Criar conta** e informe um e-mail de teste e uma senha. Depois de criar a conta, toque em **Sair**, tente entrar com uma senha incorreta e então use a senha correta. | O cadastro libera o acesso na hora. O login com senha incorreta mostra **HTTP 401**. Com a senha certa, o cardápio carrega e aparece **Perfil de funcionário**. |
| **2. Sessão armazenada** | Feche o aplicativo pela tela de recentes e abra novamente. | A API valida a sessão guardada pelo Android e abre a gestão do cardápio sem pedir a senha novamente. |
| **3. Permissão de notificação** | Abra **Cachorro-quente** e toque em **Ativar notificações**. Conceda a permissão quando o Android pedir. | O app informa que as notificações estão ativadas. |
| **4. Validação** | No mesmo produto, selecione **Foto do produto**. Inspecione o botão **Enviar** antes de escolher um arquivo. Depois, tente selecionar uma foto acima de 1 MiB. | Envio desabilitado sem seleção. O app informa o limite e mantém o envio bloqueado quando a foto é grande demais. |
| **5. Foto** | Escolha um PNG ou JPG válido, confira o nome e o tamanho e toque em **Enviar**. Abra a área de notificações do Android. | O app mostra o percentual durante a transmissão e mantém 100% enquanto aguarda a resposta da API e confirma **Arquivo salvo no servidor**. A foto aparece no produto e o Android exibe **Arquivo enviado com sucesso**. |
| **6. Ficha técnica** | Selecione **Ficha técnica**, escolha um PDF válido e envie. Volte à lista, abra o produto novamente e toque no ícone de baixar a ficha. | O produto conserva a foto e exibe a ficha pelo nome. O PDF baixado é o mesmo enviado. A conclusão também gera uma notificação local. |
| **7. Controle de acesso** | Saia e entre com `consulta@lanchefacil.test` e `ConsultaFANS2026!`. Abra um produto, selecione um arquivo válido e toque em **Enviar**. O comando `node test/staff_api_smoke.mjs` também verifica os códigos HTTP diretamente na API. | O catálogo abre e a tentativa recebe **HTTP 403** na própria tela. O servidor rejeita o envio e nenhum anexo é salvo. |
| **8. Logout** | Toque em **Sair**, tente voltar e reabra o app. Em seguida, entre novamente com sua conta de funcionário. | A tela solicita login e o botão Voltar não reabre a área protegida. Ao reconectar, os arquivos já enviados continuam no produto. |

No navegador, abra **F12 → Console** e filtre por `[Lanche Fácil]` para ver o método, a rota e o status de cada resposta da API. Após enviar uma foto, por exemplo, aparece `POST /produtos/cachorro-quente/anexos/foto → HTTP 200`. A aba **Rede** mostra a requisição correspondente. No passo 7, a tentativa de upload da conta de consulta mostra **HTTP 403** tanto no detalhe do produto quanto no console.

### Onde encontrar cada requisito

| Nº | Requisito | Passo | Implementação |
|---|---|---|---|
| 01 | Tela de login | 1 | [Formulário](lib/staff/staff_app.dart) |
| 02 | Autenticação por token | 1 | [Cadastro, login e emissão de token](cloudflare-api/src/session.js) |
| 03 | Armazenamento do token | 2 | [Flutter Secure Storage no Android](lib/staff/staff_app.dart) |
| 04 | Requisições autenticadas | 5–7 | [Cliente Dio e cabeçalho Bearer](lib/staff/staff_api.dart) |
| 05 | Controle de acesso | 7 | [Verificação da sessão](cloudflare-api/src/session.js) e [permissão de envio](cloudflare-api/src/catalog.js) |
| 06 | Seleção de PDF, PNG e JPG | 4–6 | [Seletor de arquivos](lib/staff/staff_product.dart) |
| 07 | Nome e tamanho do arquivo | 5–6 | [Detalhe do produto](lib/staff/staff_product.dart) |
| 08 | Validação de seleção e tamanho | 4 | [Validação no app](lib/staff/staff_product.dart) e [na API](cloudflare-api/src/catalog.js) |
| 09 | POST multipart/form-data | 5–6 | [Envio com Dio](lib/staff/staff_api.dart) |
| 10 | Progresso do upload | 5–6 | [Progresso e confirmação](lib/staff/staff_product.dart) |
| 11 | HTTP 200, 401 e 403 | 1, 5–7 | [Rotas e respostas da API](cloudflare-api/src/index.js) e [teste HTTP](test/staff_api_smoke.mjs) |
| 12 | Notificação local após sucesso | 3, 5–6 | [Notificações Android](lib/staff/staff_notifications.dart) |
| 13 | Logout | 8 | [Remoção local da sessão](lib/staff/staff_app.dart) e [revogação no servidor](cloudflare-api/src/session.js) |

### Onde encontrar Tecnologias e recursos

| Tecnologia ou recurso | O que usamos | Onde encontrar |
|---|---|---|
| Framework e linguagem | Flutter e Dart | [Configuração do projeto](pubspec.yaml) · [Entrada do app](lib/main.dart) |
| Seleção de arquivos | `file_picker` para selecionar PDF, PNG e JPG | [Seletor de arquivos](lib/staff/staff_product.dart) |
| Comunicação HTTP | `Dio` para enviar requisições e acompanhar o progresso do envio | [Cliente HTTP](lib/staff/staff_api.dart) |
| Upload | `POST` com `multipart/form-data` para fotos e fichas técnicas | [Envio no app](lib/staff/staff_api.dart) · [Recebimento na API](cloudflare-api/src/catalog.js) |
| Notificações locais | `flutter_local_notifications` para avisar no Android quando o envio é confirmado | [Serviço de notificações](lib/staff/staff_notifications.dart) |
| Autenticação | Token de acesso Bearer, guardado no Android com `flutter_secure_storage` | [Emissão e validação do token](cloudflare-api/src/session.js) · [Armazenamento no app](lib/staff/staff_app.dart) |
| Backend | API REST no Cloudflare Workers com banco Cloudflare D1 | [Rotas da API](cloudflare-api/src/index.js) · [Esquema do banco](cloudflare-api/schema.sql) |

## Backend local

Na pasta `cloudflare-api`, com Node.js 22 ou superior:

```bash
npx --yes wrangler@4.54.0 d1 execute DB --local --file schema.sql
npx --yes wrangler@4.54.0 dev
```

Na raiz do projeto, execute `flutter run --dart-define=STAFF_API_URL=http://10.0.2.2:8787` para o emulador Android ou `flutter run -d chrome --dart-define=STAFF_API_URL=http://localhost:8787` para o navegador. Para reproduzir o perfil de consulta localmente, crie a conta de consulta no app e execute, na pasta `cloudflare-api`:

```bash
npx --yes wrangler@4.54.0 d1 execute DB --local --command "UPDATE usuarios SET perfil = 'consulta' WHERE email = 'consulta@lanchefacil.test'"
```

Saia e entre novamente para o app mostrar o perfil atualizado. A API guarda usuários, sessões e anexos no Cloudflare D1. As senhas são derivadas com PBKDF2 e sal aleatório. O servidor guarda o hash do token e valida o perfil em cada upload. O token expira após 24 horas e é revogado no logout quando há conectividade.

## Autores

Rafael Araújo Nascimento e Mateus Artur Santos — Faculdade FANS.
