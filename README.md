# 📦 Sistema Jeremías – Gestión de Ventas, Deudas y Reportes

![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue?logo=flutter)
![SQLite](https://img.shields.io/badge/SQLite-Integrado-orange?logo=sqlite)
![Status](https://img.shields.io/badge/Status-En%20Desarrollo-brightgreen)

## 🚀 Descripción
**Sistema Jeremías** es una aplicación Flutter diseñada para la gestión de:
- ✅ **Productos**
- ✅ **Ventas** (con clientes y métodos de pago)
- ✅ **Deudas** (control de fiados y estados)
- ✅ **Reportes PDF / Excel**
- ✅ **Dashboard con estadísticas y gráficos**
- ✅ **Modo claro/oscuro con guardado de preferencias**

💡 Ideal para pequeños negocios que necesitan una solución simple y potente.

---

## 🖥️ **Características principales**

- 📋 **CRUD completo** para productos, clientes y deudas.
- 💰 **Registro de ventas** con soporte para fiados y generación automática de deudas.
- 📄 **Exportación de reportes** en **PDF** y **Excel**.
- 📊 **Dashboard interactivo** con:
  - Ventas de los últimos 7 días.
  - Métodos de pago (gráfico circular).
  - KPIs en tiempo real.
- 🌙 **Modo oscuro/claro** con animación y persistencia de estado.
- 🔄 **Actualización en tiempo real** gracias a `notifyDbChange()`.

---

## 🛠️ **Tecnologías usadas**

- **Flutter 3.22+**
- **SQLite** con `sqflite_common_ffi`
- **PDF & Excel** con paquetes `pdf`, `printing` y `excel`
- **Gráficos** con `fl_chart`
- **Persistencia de tema** con `shared_preferences`

---

## 📂 **Estructura del proyecto**