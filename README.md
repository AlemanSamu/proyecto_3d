# Captura 3D

Aplicacion Flutter para capturar un set guiado de fotos (poses) orientado a escaneo 3D.

## Guia de captura 3D

Para un flujo completo de toma de fotos orientado a reconstruccion, revisa:

- [CAPTURE_GUIDE_3D.md](CAPTURE_GUIDE_3D.md)

Modo Captura Profesional 3D:
- `rapido`: menos espera entre disparos.
- `estable`: balance recomendado.
- `maxima_calidad`: mas control de estabilidad y mas fotos sugeridas.

Interfaz simplificada (por defecto en camara):
- contador de fotos
- perfil actual
- estado corto (Mueve alrededor / Sube altura / Buena toma / Estabilizando)
- boton capturar
- boton finalizar

Los detalles tecnicos se conservan en `capture_metadata.json`.

## Validacion del Modo Captura Profesional 3D

- Ejecutar `flutter pub get`.
- Ejecutar `flutter analyze`.
- Ejecutar `flutter build apk --debug` para validar compilacion Android.
- Si hay bloqueo temporal de archivos en `windows/flutter/ephemeral/.plugin_symlinks`, reintentar `flutter pub get`.

Comandos recomendados:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug -v
flutter build apk --release
flutter build apk --release --split-per-abi
```

Si aparece lock en `.plugin_symlinks`:
- Cierra procesos que puedan estar usando la carpeta (`Gradle/IDE/Explorer` sobre `build`).
- Reejecuta `flutter clean` y luego `flutter pub get`.

Ubicacion de APK generado:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`
- Release liviano por ABI: `build/app/outputs/flutter-apk/app-*-release.apk`

## Rendimiento de captura

- `rapido`: `ResolutionPreset.high`, analisis en preview minimo.
- `estable`: `ResolutionPreset.veryHigh`, balance de calidad/rendimiento.
- `maxima_calidad`: `ResolutionPreset.max`, mayor validacion para evidencia final.

## Analisis de metadata de captura

Ejemplo:

```bash
dart run tools/analyze_capture_metadata.dart <ruta_capture_metadata.json>
```

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Conexion backend (Android)

- En **emulador Android**, puedes usar `http://10.0.2.2:8000`.
- En **celular Android fisico**, usa `http://IP_DE_TU_PC:8000` (misma red Wi-Fi).
- La pantalla de ajustes prueba `/health` y ahora intenta candidatos comunes automaticamente (loopback, `10.0.2.2` y variantes con `/api/v1`).
- Puedes pasar URL/API key por compilacion:

```bash
flutter run \
  --dart-define=LOCAL_BACKEND_URL=http://192.168.1.120:8000 \
  --dart-define=LOCAL_BACKEND_API_KEY=TU_API_KEY
```

## E2E contra backend local (opcional)

Por defecto, `test/integration/local_backend_e2e_test.dart` se omite.  
Para ejecutarlo contra `PROCESAMIENTO`:

```bash
flutter test test/integration/local_backend_e2e_test.dart \
  --dart-define=RUN_LOCAL_BACKEND_E2E=true \
  --dart-define=LOCAL_BACKEND_URL=http://127.0.0.1:8000 \
  --dart-define=LOCAL_BACKEND_API_KEY=TU_API_KEY
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
