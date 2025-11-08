# Configuración del Proyecto BlueChat P2P

## Requisitos del Sistema
- Flutter SDK 3.16+
- Android Studio o VS Code
- Android SDK (API 23+)
- Dispositivos Android con Bluetooth

## Instalación Paso a Paso

### 1. Clonar el Repositorio
```bash
git clone https://github.com/kimmyflorees45/-bluechat-p2p.git
cd bluechat-p2p
```

### 2. Instalar Dependencias
```bash
flutter pub get
```

### 3. Configurar Android
- Habilitar modo desarrollador
- Activar depuración USB
- Conectar dispositivo Android

### 4. Ejecutar la Aplicación
```bash
flutter run
```

## Troubleshooting

### Problema: Bluetooth no funciona
**Solución:** Verificar permisos en AndroidManifest.xml

### Problema: No se detectan dispositivos
**Solución:** Asegurar que ambos dispositivos estén visibles

### Problema: Error de compilación
**Solución:** Ejecutar `flutter clean` y `flutter pub get`

## Notas del Equipo
- Desarrollado en pair programming
- Probado en múltiples dispositivos Android
- Optimizado para Android 6.0+
