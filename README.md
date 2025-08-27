# ❄️ Arctic Stock – Sistema de Gestión Comercial

![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue?logo=flutter)
![SQLite](https://img.shields.io/badge/SQLite-3-lightgrey?logo=sqlite)
![Status](https://img.shields.io/badge/status-Production-green)

## 🚀 Descripción
**Arctic Stock** es una aplicación desarrollada en **Flutter** (Desktop/Mobile) para la gestión integral de inventario, ventas, clientes y deudas, con reportes avanzados y estadísticas en tiempo real.  

💡 Diseñada para pequeños y medianos negocios que buscan una solución moderna, rápida y visualmente atractiva.

---

## 🖥️ Características principales

### 📦 Gestión de Inventario
- CRUD completo para productos con categorías.  
- Control de stock en tiempo real.  
- Badge dinámico que alerta productos agotados con animación.  
- Filtro rápido para listar productos sin stock.  
- Alertas automáticas al intentar vender sin stock suficiente.  

### 💰 Ventas
- Registro de ventas con múltiples métodos de pago.  
- Validación de stock antes de confirmar ventas.  
- Carrito interactivo con edición de cantidades.  
- Soporte para ventas fiadas → genera deudas automáticamente.  

### 📄 Reportes
- Exportación en **PDF** y **Excel**.  
- Reportes de ventas, deudas y stock.  

### 📊 Dashboard Inteligente
- KPIs en tiempo real:
  - Ventas del día y del mes.  
  - Deudas pendientes.  
  - Producto más vendido.  
  - Cantidad de productos sin stock 🔥  
- Gráfico de ventas últimos 7 días.  
- Gráfico circular de métodos de pago.  
- Filtros por categoría y rango de fechas.  

### 🌙 Experiencia de Usuario
- Modo claro/oscuro con persistencia de preferencias.  
- Animaciones suaves (AnimatedScale, AnimatedOpacity).  
- Interfaz responsive y moderna.  

---

## 🛠️ Tecnologías utilizadas
- **Flutter 3.22+**  
- **SQLite** con `sqflite_common_ffi`  
- **PDF & Excel** → `pdf`, `printing`, `excel`  
- **Gráficos** → `fl_chart`  
- **Persistencia** → `shared_preferences`  

---

## ⚡ Últimas mejoras implementadas
- ✅ Animación del badge de productos sin stock.  
- ✅ Filtro exclusivo para productos agotados.  
- ✅ Validación de stock en ventas con alertas.  
- ✅ KPI en Dashboard para productos sin stock.  
- ✅ Actualización en tiempo real con `notifyDbChange()` y streams.  

---

## 📂 Estructura del proyecto
```bash
lib/
 ├── screens/
 │   ├── dashboard_screen.dart
 │   ├── sales_screen.dart
 │   ├── product_list_screen.dart
 │   └── ...
 ├── services/
 │   ├── db_service.dart
 │   ├── backup_service.dart
 │   └── catalog_service.dart
 ├── widgets/
 │   ├── artic_background.dart
 │   ├── artic_container.dart
 │   └── artic_kpi_card.dart
 └── main.dart
