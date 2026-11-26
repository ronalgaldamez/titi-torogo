# torogo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Compilaciones de publicación

Para un build `release` de Android o iOS, pasá los tres valores con `--dart-define`:

- `API_BASE_URL` es la URL HTTPS del backend, terminada en `/api` y sin barra al final.
- `REVERB_WS_URL` es el origen WSS de Reverb, por ejemplo `wss://ws.torogo.example`.
- `REVERB_APP_KEY` es la clave pública del proyecto de Reverb.

Android lee la firma de publicación desde `android/key.properties`. Ese archivo
usa `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. Las rutas
relativas de `storeFile` se resuelven desde `android/`. Guardá ese archivo y
el almacén de claves fuera de Git. [Guía oficial de firma de Flutter](https://docs.flutter.dev/deployment/android#sign-the-app)

El workflow **iOS Build** lee las variables de GitHub Actions
`TOROGO_API_BASE_URL`, `TOROGO_REVERB_WS_URL` y `TOROGO_REVERB_APP_KEY`. Un
perfil explícito de `builder.json` puede pasar estos valores con los nombres
sin el prefijo `TOROGO_`. La firma sigue usando el certificado y el perfil
de aprovisionamiento configurados para esa compilación. [Variables de GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables)
