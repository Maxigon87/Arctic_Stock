📝 PROYECTO Artic Stock – CHECKPOINT 01
✅ Estado actual del proyecto
Plataforma actual: Flutter Desktop (Windows) usando sqflite_common_ffi

Funciona en: Windows ✅ (SQLite persiste)

No funciona en: Flutter Web ❌ (no soporta SQLite)

Objetivo logrado: CRUD de Productos completo (Agregar, Editar, Eliminar)

Estado UI: Lista de productos funcional con menú de edición/eliminación

📂 Estructura de archivos actual
less
Copiar
Editar
lib/
 ├─ models/
 │   ├─ producto.dart
 │   ├─ venta.dart
 │   └─ deuda.dart
 ├─ screens/
 │   └─ product_list_screen.dart   // CRUD completo de productos
 └─ services/
     └─ db_service.dart           // Base SQLite usando sqflite_common_ffi
main.dart                         // Carga ProductListScreen como home
📦 Dependencias actuales en pubspec.yaml
yaml
Copiar
Editar
dependencies:
  flutter:
    sdk: flutter
  sqflite_common_ffi: ^2.3.1
  path: ^1.8.3
✅ Funcionalidades terminadas
✔️ Base de datos SQLite funcional (sqflite_common_ffi)
✔️ Tablas creadas: productos, ventas, deudas
✔️ CRUD completo para productos (insert, get, update, delete)
✔️ UI de productos con:

Listado dinámico desde DB

Botón + para agregar productos

Menú de 3 puntos para Editar/Eliminar

🎯 Próximos pasos (Semana 2)
Agregar pantallas Ventas y Deudas (sales_screen.dart y debt_screen.dart).

Implementar BottomNavigationBar para navegar entre Productos, Ventas y Deudas.

Conectar Ventas y Deudas con sus tablas (getVentas(), getDeudas(), etc.).

UI básica para registrar ventas y deudas.

✅ Nota importante
Para correr en Windows:

bash
Copiar
Editar
flutter run -d windows
Visual Studio ya está instalado y configurado.

Para Web no usar SQLite (no compatible).

🚀 Siguiente acción cuando retomemos
👉 Implementar navegación con BottomNavigationBar y crear pantallas vacías de Ventas y Deudas.