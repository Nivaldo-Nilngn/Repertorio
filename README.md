# MusiCifras - Digital Songbook

Bem-vindo ao projeto MusiCifras! Como você estava ausente, eu adiantei a criação da arquitetura base (Clean Architecture por Features) e dos modelos e repositórios solicitados.

## Estrutura Criada

Foi implementada uma arquitetura orientada a **Features**, focada em escalabilidade e manutenção:

```
lib/
└── features/
    └── songs/
        ├── models/
        │   └── song.dart (Modelo com Freezed)
        └── repositories/
            └── song_repository.dart (CRUD e Riverpod Provider)
```

## Próximos Passos (Setup)

Como a pasta estava vazia, você precisará inicializar o projeto Flutter e instalar as dependências. Quando retornar, siga os passos abaixo:

1. **Inicialize o projeto Flutter** (na mesma pasta):
   ```bash
   flutter create .
   ```

2. **Adicione as dependências essenciais**:
   ```bash
   flutter pub add flutter_riverpod riverpod_annotation cloud_firestore firebase_core freezed_annotation json_annotation
   flutter pub add -d build_runner freezed json_serializable riverpod_generator
   ```

3. **Gere os arquivos do Freezed e Riverpod (`.g.dart` e `.freezed.dart`)**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Configuração do Firebase**:
   Configure o Firebase usando o FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. **Ativação da Persistência Offline**:
   No arquivo `lib/main.dart`, lembre-se de ativar o cache ilimitado conforme documentado no `song_repository.dart`:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
     FirebaseFirestore.instance.settings = const Settings(
       persistenceEnabled: true,
       cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
     );
     runApp(const ProviderScope(child: MyApp()));
   }
   ```

A base para a gerência das músicas está pronta! O modelo `Song` já comporta a sintaxe ChordPro no campo `content`, e o `SongRepository` gerencia o CRUD com Firestore de forma reativa (Streams). 

Me avise quando concluir o setup para continuarmos com o parse do ChordPro e a criação do *Visualizador de Músicas (Modo Ao Vivo)*!
