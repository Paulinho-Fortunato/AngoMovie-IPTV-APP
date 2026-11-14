# AngoMovie IPTV

App de TV ao vivo no estilo Netflix para Android. Interface moderna com carregamento de canais M3U, player de vídeo integrado, busca e navegação por categorias.

## 🎯 Funcionalidades

- **Interface Netflix**: Tela principal com linhas horizontais por categoria
- **Player de Vídeo**: Suporte a HLS, MP4, TS com todos os codecs (H.264, H.265, AAC, AC-3)
- **Tela de Carregamento**: Animação estilo streaming com indicador circular
- **Cache Local**: Lista/canais em Hive; favoritos e histórico persistidos em Room no Android (API 21+).
- **Busca**: Filtro em tempo real por nome/categoria (debounce 350ms)
- **Aviso de Privacidade**: Exibido na primeira abertura
- **Segurança**: R8/ProGuard ativado no release; não aceita certificados TLS inválidos; HTTP legado continua disponível para listas que o exijam.
- **Configurações**: Gerenciar cache, privacidade e segurança de conexão

## 📦 Versão

- **Versão**: 1.2.0
- **Build**: 3
- **Android mínimo**: 5.0 (API 21)

## 🛠️ Tecnologias

| Componente       | Tecnologia         |
|------------------|--------------------|
| Framework        | Flutter 3.35.4     |
| Linguagem        | Dart 3.9.2         |
| Player           | flutter_vlc_player 7.x |
| Cache de canais  | Hive 2.2.3         |
| Favoritos/histórico Android | Room 2.6.1 |
| Imagens          | cached_network_image |
| Estado           | Provider 6.x       |
| HTTP             | http 1.x           |
| Backend          | FastAPI + httpx    |

## 🚀 Build

```bash
# Instalar dependências
flutter pub get

# Build APK release
flutter clean
flutter pub get
flutter build apk --release

# APK gerado em:
# build/app/outputs/flutter-apk/app-release.apk

# Se quiser instalar direto no aparelho ligado
flutter install
```

## 🔧 Backend (Opcional)

```bash
cd backend/
pip install -r requirements.txt
# Defina apenas uma playlist à qual tem autorização de acesso/distribuição.
# Prefira HTTPS e mantenha a URL/credenciais fora do Git e dos logs.
export ANGOMOVIE_M3U_URL='https://provider-authorized.example/playlist.m3u'
python server.py
```

O backend não tem uma playlist ou credenciais padrão; sem `ANGOMOVIE_M3U_URL`, não faz pedidos à fonte.

API disponível em `http://localhost:8000`:
- `GET /api/channels` – Lista de canais ao vivo
- `GET /api/categories` – Categorias disponíveis
- `GET /api/data-version` – Versão dos dados (para verificar atualizações)
- `GET /api/health` – Status do servidor

## 📱 Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada
├── models/
│   ├── channel.dart          # Modelo de canal
│   ├── channel.g.dart        # Adaptador Hive (gerado)
│   └── watch_history_entry.dart # Modelo de histórico
├── services/
│   ├── channel_service.dart  # Cache e fetch de canais
│   ├── local_media_store.dart # Bridge Room/fallback multiplataforma
│   └── m3u_parser.dart       # Parser M3U+ com filtros
├── providers/
│   └── channel_provider.dart # Estado global e dados pessoais locais
├── screens/
│   ├── splash_screen.dart    # Tela de carregamento
│   ├── home_screen.dart      # Tela principal
│   ├── watch_history_screen.dart # Histórico de reprodução
│   ├── player_screen.dart    # Player de vídeo
│   ├── settings_screen.dart  # Configurações
│   └── privacy_screen.dart   # Aviso de privacidade
├── widgets/
│   ├── channel_card.dart     # Card de canal
│   ├── featured_channel.dart # Destaque principal
│   └── search_bar_widget.dart # Barra de busca
└── utils/
    ├── app_colors.dart       # Paleta de cores
    └── app_theme.dart        # Tema escuro Netflix
```

## 🔒 Segurança

- **R8/ProGuard**: Minificação e obfuscação no release
- **TLS**: o cliente já não aceita certificados expirados, autoassinados ou inválidos por omissão.
- **HTTP legado**: o projeto ainda permite cleartext para streams IPTV antigos. O HTTP não cifra URL nem credenciais; usa apenas uma fonte autorizada, preferindo HTTPS.
- **Dados Locais**: o cache de canais continua em Hive; Room guarda metadados de favoritos/histórico sem URLs de stream. A base Room é privada à aplicação, mas não cifrada.

## 📡 Fonte de Dados

- **M3U**: configure uma URL de playlist autorizada nas definições da aplicação. Não inclua credenciais no código-fonte, documentação, logs ou repositório. O backend opcional recebe a URL pelo segredo de ambiente `ANGOMOVIE_M3U_URL`; prefere HTTPS. HTTP só deve ser usado quando exigido pelo serviço autorizado e transmite a URL sem cifragem.
- **Cache**: a lista de canais usa Hive; Room guarda metadados dos favoritos e o histórico no Android. URLs de stream não são copiadas para as tabelas Room. Limpar o cache de canais não elimina favoritos nem histórico.
- **Compatibilidade**: minSdk 21; inclui Android 7.1/API 25. Room 2.6.1.

## Persistência local Android

A base Room `angomovie_local_media.db` é criada automaticamente. Favoritos são migrados uma vez do antigo campo Hive `isFavorite`. O histórico guarda até 100 canais distintos, a última data de reprodução e o número de reproduções; uma entrada é gravada quando o player reporta que a reprodução começou. Não são persistidos nesta base a URL M3U nem URLs de stream. Os dados são privados da aplicação, mas o SQLite não está cifrado — não guardes nesta base dados secretos.

Testes:

```bash
flutter test
# Com Java 17, Gradle 8.12 e um dispositivo/emulador Android ligado:
gradle -p android :app:connectedDebugAndroidTest
```

Os testes Room são instrumentados e precisam de um dispositivo/emulador; também podem ser executados pela tarefa `:app:connectedDebugAndroidTest` no Android Studio.
