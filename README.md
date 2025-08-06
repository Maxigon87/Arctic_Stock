# 📦 Artic Stock – Sistema de Gestión de Inventario, Ventas y Reportes  

![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue?logo=flutter)
![SQLite](https://img.shields.io/badge/SQLite-Integrado-orange?logo=sqlite)
![Status](https://img.shields.io/badge/Status-En%20Desarrollo-brightgreen)

---

## 🚀 **Descripción**

**Artic Stock** es una aplicación Flutter (Desktop – Windows) diseñada para gestionar inventario, ventas, clientes y deudas con reportes avanzados y estadísticas en tiempo real.  
💡 Ideal para pequeños negocios que buscan una **solución moderna, rápida y visualmente atractiva**.

---

## 🖥️ **Características principales**

### ✅ **Gestión de Inventario**
- CRUD completo para productos con categorías.
- **Control de stock en tiempo real**.
- **Badge dinámico** en el Home indicando productos agotados con animación.
- **Filtro de productos sin stock** con un solo click.
- **Alertas automáticas** al intentar vender productos con stock insuficiente.

### 💰 **Ventas**
- Registro de ventas con múltiples métodos de pago.
- Validación de stock antes de confirmar la venta.
- Modal de carrito interactivo con edición de cantidades.
- Soporte para **ventas fiadas**, generando deudas automáticamente.

### 📄 **Reportes**
- Exportación de datos en **PDF** y **Excel**.
- Reportes de ventas, deudas y stock.

### 📊 **Dashboard Inteligente**
- KPIs en tiempo real:
  - **Ventas del día**
  - **Ventas del mes**
  - **Deudas pendientes**
  - **Producto más vendido**
  - **Productos sin stock** 🔥 (nuevo KPI)
- Gráfico de ventas de los últimos 7 días.
- Gráfico circular de métodos de pago.
- Filtros por categoría y rango de fechas.

### 🌙 **Experiencia de Usuario**
- Modo claro/oscuro con persistencia de preferencias.
- Animaciones suaves (`AnimatedScale`, `AnimatedOpacity`) para feedback visual.
- Interfaz responsive y moderna.

---

## 🛠️ **Tecnologías utilizadas**

- **Flutter 3.22+**
- **SQLite** con `sqflite_common_ffi`
- **PDF & Excel** con `pdf`, `printing` y `excel`
- **Gráficos** con `fl_chart`
- **Persistencia de tema** con `shared_preferences`

---

## ⚡ **Últimas mejoras implementadas (Checkpoint Actual)**  
- ✅ Animación del badge de productos sin stock.  
- ✅ Filtro exclusivo para listar solo productos agotados.  
- ✅ Validación de stock antes de confirmar ventas (con alertas).  
- ✅ KPI en Dashboard para mostrar cantidad de productos sin stock.  
- ✅ Actualización en tiempo real gracias a `notifyDbChange()` y streams.  

---

## 📂 **Estructura del proyecto**
lib/
├── screens/
│ ├── product_list_screen.dart
│ ├── sales_screen.dart
│ ├── dashboard_screen.dart
│ └── ...
├── services/
│ └── db_service.dart
├── widgets/
│ └── artic_background.dart
│ └── artic_container.dart
│ └── artic_kpi_card.dart
└── main.dart

---

## 🗺️ **Próximos pasos**
- 🔔 Notificaciones locales para alertar stock crítico.
- 📈 Historial de movimientos de stock.
- 📦 Integración con escáner de códigos de barras.
- ☁️ Sincronización con la nube y backups automáticos.
- 👥 Roles de usuario y control de acceso.

---
