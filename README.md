# Nymbus Coletor

Aplicativo Flutter para coleta de dados com leitura de códigos de barras, consulta de preços, inventário e entrada de produtos. Projeto focado em segurança, testabilidade e observabilidade.

## Sobre

- Nome do app: `nymbus_coletor`
- Plataformas: Android (principal), iOS, Web, Desktop
- Principais funcionalidades:
  - Leitura de código de barras (scanner)
  - Consulta de preço e exibição de detalhes do produto
  - Inventário (listagem e atualização de estoque)
  - Entrada e etiquetas de produtos
  - Persistência local de configuração e dados

## Arquitetura

Estrutura modular em camadas:

```
lib/
  models/        -> Modelos de domínio (Produto, InventarioItem, AppConfig, Licenca)
  services/      -> Serviços (ApiService, StorageService, ScannerService, FeedbackService, LoggerService)
  providers/     -> Estado via Provider (ConfigProvider)
  screens/       -> Telas (config, consulta_preco, inventario, entrada, etiqueta, login, splash)
  router/        -> Rotas nomeadas (GoRouter / onGenerateRoute)
  utils/         -> Utilitários (BarcodeUtils)
```

Pontos-chave:
- `ApiService`: requisições HTTP, timeouts, retry e handler de 401/403.
- `StorageService`: persistência com `SharedPreferences` e `flutter_secure_storage` (com adapter e telemetria).
- `LoggerService`: logging com máscara/redação de dados sensíveis.
- `FeedbackService`: mensagens ao usuário (SnackBar/AlertDialog).
- `BarcodeUtils`: sanitização de códigos de barras.

## Configuração

Requisitos de ambiente:
- Flutter (canal stable)
- Java 11 (JDK)
- Android SDK e Build Tools

Instalação e verificação:
- `flutter pub get`
- `flutter doctor`
- `flutter analyze`

Executar o app (debug):
- `flutter run`

## Build & Release

Assinatura de release via `key.properties` e `release.keystore`:

1) Posicione o keystore de produção:
- Arquivo: `android/app/release.keystore`

2) Crie o arquivo `key.properties` (em `android/` ou na raiz do projeto):

```
storeFile=app/release.keystore
storePassword=<sua_senha_do_keystore>
keyAlias=<seu_alias>
keyPassword=<sua_senha_da_chave>
```

3) Build de release (Windows, PowerShell):
- `scripts/build_release.ps1`

Saída esperada:
- APK assinado em `build\releases\nymbus_coletor-<versão>.apk`

Observações:
- Em ausência de `key.properties`, o build usa o debug keystore padrão (`~/.android/debug.keystore`) com credenciais de debug — não recomendado para distribuição oficial.
- `compileOptions` configurado para Java 11 no Gradle.

## Testes

Testes de unidade e widgets:
- `flutter test`

Categorias existentes:
- `test/services/` -> `ApiService`, `StorageService`
- `test/utils/` -> `BarcodeUtils`
- `test/widgets/` -> fluxos de scanner (consulta preço, entrada, etiqueta, inventário)
- `test/models/` -> validações de modelos

Cobertura (opcional):
- `flutter test --coverage`
- Geração de relatório com ferramentas externas (ex.: `genhtml`)

## CI/CD

Workflow em `.github/workflows/ci.yml` (personalizável):
- Instalar dependências (`flutter pub get`)
- Análise estática (`flutter analyze`)
- Testes (`flutter test` e opcionalmente `--coverage`)
- Publicação de artefatos de cobertura (opcional)

Sugerido:
- Gate de cobertura mínima (ex.: 75%)
- Build de release sob tag (mantendo segredos fora do repositório)

## Padrões

Lints configurados em `analysis_options.yaml`:
- `avoid_print`, `prefer_final_locals`, `directives_ordering`, entre outros.

Diretrizes de código:
- Preferir imutabilidade local (`final`)
- Evitar chamadas dinâmicas
- Respeitar ordem de imports e organização por camadas

## Logging Seguro

`LoggerService` realiza máscara e redação de dados sensíveis:
- URLs: redige tokens e licenças em caminhos e query params
- Cabeçalho `Authorization: Bearer <token>`: redigido
- Códigos de barras: mascarados quando detectados em mensagens
- Licenças: mascaradas em logs

Boas práticas:
- Não logar tokens em texto claro
- Não colocar tokens em query string (usar headers)
- Usar `LoggerService` para todas mensagens sensíveis

## Contribuição

Como contribuir:
- Abra issues descrevendo contexto e cenário
- Envie PRs com descrição objetiva e evidências (testes)
- Siga o estilo de código e passe em `flutter analyze` e `flutter test`

Commits e PRs:
- Mensagens claras, escopo limitado
- PRs pequenos e revisáveis

## Referências

- Flutter Docs: https://docs.flutter.dev/
- Provider: https://pub.dev/packages/provider
- GoRouter: https://pub.dev/packages/go_router
- Flutter Secure Storage: https://pub.dev/packages/flutter_secure_storage
