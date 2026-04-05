# Arquitectura de Hermes Docker - Explicación Técnica

## 📦 Estructura de la Imagen Docker

### Componentes Base (de NousResearch)
```
Hermes Agent Original (GitHub)
├── Core Agent (Python)
├── CLI Interface
├── Skills System
├── Memory System
└── Gateway (WhatsApp, Telegram, etc.)
```

### Componentes Personalizados (Tus Add-ons)
```
Tu Repo (github.com/tesin73/Hermes)
├── scripts/
│   ├── entrypoint.sh           # Inicialización personalizada
│   ├── whatsapp-fix.sh         # Helper para problemas WhatsApp
│   └── qr-server.py           # 🆕 Servidor web para QR remoto
├── docker-compose.yml          # Orquestación + servicio qr-server
├── Makefile                   # Comandos personalizados
└── config/
    └── .env.example           # Variables de entorno
```

---

## 🔄 Flujo de Construcción (Build Process)

### Paso 1: Dockerfile Construye la Imagen Base
```dockerfile
# 1. Clona Hermes original de NousResearch
RUN git clone https://github.com/NousResearch/hermes-agent.git \
    /opt/hermes-agent-source

# 2. Instala Hermes desde la copia local
RUN pip install -e /opt/hermes-agent-source

# 3. Copia TUS scripts personalizados
COPY scripts/entrypoint.sh /home/hermes/entrypoint.sh
COPY scripts/init-hermes.sh /home/hermes/init-hermes.sh
```

**Resultado:** Imagen `hermes-agent:full` con:
- ✅ Hermes original (core)
- ✅ Tus scripts de inicialización
- ✅ TODO el código necesario (no requiere internet después del build)

---

### Paso 2: Docker Compose Orquesta los Servicios

#### Servicio Principal (hermes-gateway)
```yaml
services:
  hermes-gateway:
    image: hermes-agent:full  # La imagen que construimos arriba
    container_name: hermes-gateway
    env_file:
      - .env                  # Variables personalizadas (API keys, etc.)
    volumes:
      - hermes_config:/home/hermes/.hermes  # Persistencia de datos
```

**Qué hace:**
- Corre Hermes Agent con tus configuraciones
- Lee API keys de `.env`
- Guarda sesiones de WhatsApp en volumen persistente

---

#### Servicio QR Server (NUEVO - Opcional)
```yaml
services:
  qr-server:
    image: hermes-agent:full
    container_name: hermes-qr-server
    volumes:
      - hermes_logs:/home/hermes/.hermes/logs:ro  # Lee logs de WhatsApp
      - ./scripts/qr-server.py:/home/hermes/qr-server.py:ro  # Tu script
    ports:
      - "8081:8081"  # Expone puerto web
    command: >
      bash -c "pip install qrcode && python3 /home/hermes/qr-server.py"
    profiles:
      - qr-server  # ⭐ NO inicia automáticamente
```

**Qué hace:**
- Lee los logs de WhatsApp del contenedor principal
- Extrae el código QR cuando aparece
- Genera imagen PNG del QR
- Sirve imagen vía HTTP en `http://IP:8081/qr.png`
- Se inicia **solo cuando ejecutas** `make qr-start` (no auto-inicia)

---

## 🎯 Arquitectura Visual

```
┌─────────────────────────────────────────────────────────────┐
│                      DOCKER HOST                           │
│                    (Tu VPS/Servidor)                         │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │                                       │
┌───────▼────────┐                    ┌─────────▼─────────┐
│ hermes-gateway │                    │   qr-server      │
│   (principal)  │                    │   (opcional)     │
│                │                    │                  │
│ ┌───────────┐  │                    │ ┌─────────────┐  │
│ │  Hermes   │  │                    │ │qr-server.py │  │
│ │  Original │  │◄──── Lee logs ─────│ │   Script    │  │
│ │  (Core)   │  │   (WhatsApp)       │ │  Personal   │  │
│ └───────────┘  │                    │ └─────────────┘  │
│                │                    │                  │
│ ┌───────────┐  │                    │ ┌─────────────┐  │
│ │  WhatsApp │  │                    │ │  Genera   │  │
│ │  Gateway  │──┼────── QR string ──►│ │  Imagen   │  │
│ │           │  │                    │ │   PNG     │  │
│ └───────────┘  │                    │ └─────────────┘  │
└────────────────┘                    └────────┬─────────┘
                                                  │
                                                  │ HTTP:8081
                                                  │
                                                  ▼
                                           ┌──────────────┐
                                           │  TU PC/PHONE  │
                                           │  Descarga PNG  │
                                           │  Escanear QR   │
                                           └──────────────┘
```

---

## 🔧 ¿Por qué Funciona Así?

### 1. **Separación de Responsabilidades**
- `hermes-gateway`: Solo corre Hermes (core de NousResearch)
- `qr-server`: Solo sirve imágenes QR (tu add-on)

### 2. **Cero Modificaciones al Código Original**
- No editas Hermes original
- Tu script `qr-server.py` lee logs externos
- Si Hermes se actualiza, tu código sigue funcionando

### 3. **Totalmente Opcional**
- El QR server NO inicia automáticamente
- Si no lo usas, Hermes funciona igual (comportamiento por defecto)
- Solo consumes recursos cuando lo necesitas

---

## 📝 Ejemplo de Uso Completo

```bash
# ========== EN TU VPS REMOTA ==========

# 1. Clonar tu repo (con todos tus scripts)
git clone https://github.com/tesin73/Hermes.git /opt/hermes
cd /opt/hermes

# 2. Configurar
cp config/.env.example .env
nano .env  # Agregar tu API key

# 3. Construir imagen (incluye Hermes + tus scripts)
make build

# 4. Iniciar Hermes
make start

# 5. Iniciar servidor QR (OPCIONAL - para escaneo remoto)
make qr-start

# 6. Ver URL para descargar QR
make qr-url
# Output: http://203.0.113.45:8081/qr.png


# ========== EN TU PC LOCAL ==========

# 7. Descargar la imagen QR
curl -O http://203.0.113.45:8081/qr.png

# 8. Abrir la imagen y escanear con WhatsApp
# (Abre WhatsApp → Menú → Dispositivos vinculados → Vincular)


# ========== DE VUELTA EN VPS ==========

# 9. Detener servidor QR (seguridad)
make qr-stop

# 10. Hermes sigue funcionando normalmente ✅
```

---

## 🎉 Resumen

| Aspecto | Descripción |
|---------|-------------|
| **Base** | Hermes original de NousResearch |
| **Add-ons** | Tus scripts (`qr-server.py`, etc.) |
| **Método** | Docker Compose orquesta todo |
| **Comportamiento default** | Hermes solo (sin QR server) |
| **Opcional** | QR server inicia manualmente con `make qr-start` |

**Tu código NO modifica Hermes original**, solo lo complementa con funcionalidad adicional vía logs y servicios externos. 🎯
