# Captura 3D

Aplicacion Flutter para capturar un set guiado de fotos (poses) orientado a escaneo 3D.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Configuracion release Android

1. Crea `android/key.properties` desde `android/key.properties.example`.
2. Configura un keystore real (`.jks`) y credenciales de firma.
3. El archivo `android/key.properties` no se versiona (esta en `.gitignore`).

Tambien puedes configurar firma por variables de entorno:
- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

Si intentas compilar release sin firma configurada, Gradle falla con error explicito.

## Identificadores de app

- Android `applicationId`: `com.captura3d.app`
- iOS `PRODUCT_BUNDLE_IDENTIFIER`: `com.captura3d.app`
