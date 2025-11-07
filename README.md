# micro_iot

Proyecto de investigación de la materia de microcontroladores (USFX). Este repositorio contiene un servidor, una interfaz de usuario (UI) y ejemplos de código para manejar sensores y controlar una luz.

## Resumen

- Propósito: Plataforma de investigación para monitoreo y control de sensores (por ejemplo sensores de luminosidad) y control de una luz a través de un servidor y una UI.
- Componentes principales:
  - `server/` — código del servidor (Dart) que gestiona conexiones, mensajes y lógica de sensores.
  - `frontend/` — UI hecha con Flutter para visualizar el estado de sensores y controlar la luz.
  - `include/`, `lib/`, `src/` dentro de `server/` — código nativo/C++ para integración con dispositivos o microcontroladores (ej.: PlatformIO).

## Estructura del repositorio (resumen)

```
frontend/        # Aplicación Flutter (UI)
server/          # Servidor Dart y código nativo para microcontroladores
lib/             # Código Dart principal de la app (si aplica)
ios/ android/    # Plataformas generadas por Flutter
linux/ macos/ windows/ # Soporte multiplataforma
test/            # Tests (Flutter/Dart)
examples/        # Scripts/ejemplos auxiliares (Python, etc.)
```

## Requisitos

- Flutter SDK (para `frontend/`)
- Dart SDK (para `server/` si se ejecuta con `dart`)
- PlatformIO / toolchain de microcontrolador (opcional, para compilar/flash del firmware)

## Cómo ejecutar

1) Ejecutar el servidor (Dart)

Abre una terminal en la raíz del repositorio y ejecuta:

```powershell
dart run server/main.dart
```

Si prefieres ejecutar desde el directorio `server`:

```powershell
cd server; dart run main.dart
```

2) Ejecutar la UI (Flutter)

Desde la carpeta `frontend`:

```powershell
cd frontend
flutter pub get
flutter run -d <dispositivo>
```

Para compilar para web:

```powershell
flutter run -d chrome
```

3) Firmware / microcontrolador (opcional)

Hay código de ejemplo para microcontroladores en `server/include`, `server/src` y `examples/`.
Usa PlatformIO desde el directorio correspondiente para compilar y subir al dispositivo:

```powershell
cd server
platformio run --target upload
```

Nota: Ajusta el `platformio.ini` y los entornos según tu placa.

## Contribuir

- Describe problemas o mejoras en los *issues*.
- Haz fork, crea una rama, haz cambios, y abre un Pull Request.

## Próximos pasos sugeridos

- Añadir documentación de la API del servidor (endpoints / mensajes WebSocket/TCP).
- Añadir ejemplos detallados de PlatformIO para placas específicas.
- Documentar el formato de los mensajes entre UI y servidor.

## Licencia

Este proyecto no especifica licencia en este README. Añade un `LICENSE` si quieres compartirlo públicamente.

---
Si quieres, traduzco este README al inglés o añado secciones técnicas (diagramas, ejemplos de payloads, o comandos concretos para PlatformIO). Indícame qué prefieres.
