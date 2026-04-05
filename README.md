# Hermes Agent - Docker Deployment

Despliegue containerizado de Hermes Agent para masificar instalaciones en VPS.

> 🏗️ **Arquitectura:** Esta imagen usa Hermes Agent original de [NousResearch](https://github.com/NousResearch/hermes-agent) como base, y agrega scripts personalizados (como el servidor QR remoto). Ver [ARQUITECTURA.md](ARQUITECTURA.md) para detalles técnicos.

## ⚡ Quick Start

```bash
# 1. Clonar y entrar
git clone <repo> && cd hermes-docker

# 2. Configurar credenciales
cp config/.env.example .env
nano .env  # Agregar tus API keys

# 3. Construir e iniciar
make build
make start

# 4. WhatsApp - Escanear QR
make whatsapp-qr
```

## 📁 Estructura

```
hermes-docker/
├── Dockerfile              # Imagen completa con todo el sistema
├── docker-compose.yml      # Orquestación de servicios
├── Makefile               # Comandos de conveniencia
├── config/
│   ├── config.yaml        # Configuración base
│   └── .env.example       # Template de variables
├── scripts/
│   ├── entrypoint.sh      # Inicialización del contenedor
│   └── whatsapp-fix.sh    # Helper para problemas de WhatsApp
└── custom-skills/         # Tus skills personalizadas
```

## 🔧 Estructura de la Imagen Docker

### ¿Cómo "embebe" todo sin referencia al repo?

1. **Build stage**: Clona el repo de GitHub UNA VEZ durante `docker build`
2. **Copia local**: Todo el código queda en `/opt/hermes-agent-source` dentro de la imagen
3. **Instalación**: Se instala con `pip install -e .` (modo editable desde la copia local)
4. **Runtime**: No necesita conectividad a GitHub

```dockerfile
# En Dockerfile - esto solo sucede en build
RUN git clone --depth 1 \
    https://github.com/NousResearch/hermes-agent.git \
    /opt/hermes-agent-source

# Instalación local
RUN pip install -e /opt/hermes-agent-source
```

## 🚀 Comandos Make

| Comando | Descripción |
|---------|-------------|
| `make build` | Construir imagen |
| `make start` | Iniciar servicios |
| `make stop` | Detener servicios |
| `make logs` | Ver logs en vivo |
| `make shell` | Terminal dentro del contenedor |
| `make whatsapp-qr` | Mostrar QR para escanear |
| `make whatsapp-reset` | Borrar sesión de WhatsApp |
| `make backup-create` | Backup de datos |
| `make qr-start` | Servidor web para QR remoto |
| `make qr-url` | Mostrar URL del QR |

## 📱 WhatsApp - Troubleshooting

Los problemas más comunes y sus soluciones:

### Problema: QR no aparece o no escanea
```bash
# Solución 1: Regenerar QR
make whatsapp-qr

# Solución 2: Resetear sesión completamente
make whatsapp-reset
make restart
```

### Problema: Desconexiones frecuentes
```bash
# Ver logs específicos
docker-compose exec hermes-gateway whatsapp-fix.sh logs

# Reiniciar solo el módulo de WhatsApp
docker-compose exec hermes-gateway hermes gateway restart
```

### Problema: "Session invalid"
```bash
# Borrar sesión y re-autenticar
docker-compose exec hermes-gateway rm -rf ~/.hermes/whatsapp_sessions
docker-compose restart
make whatsapp-qr
```

## 🌍 Despliegue en VPS

### 🌐 QR Remoto (para VPS en la nube)

Cuando Hermes está en una VPS remota y no puedes ver el QR en terminal:

```bash
# 1. Iniciar servidor web para QR
make qr-start

# 2. Obtener la URL para descargar
make qr-url
# Muestra: http://203.0.113.45:8081/qr.png

# 3. Desde tu PC local, descargar el QR
curl -O http://203.0.113.45:8081/qr.png
# Abre la imagen y escanea con WhatsApp

# 4. Detener servidor cuando termines
make qr-stop
```

Más detalles en [GUIA-DESPLIEGUE.md](GUIA-DESPLIEGUE.md)

### Requisitos mínimos
- 1 vCPU
- 2GB RAM
- 10GB SSD
- Ubuntu 20.04+ / Debian 11+
- Docker + Docker Compose

### Script de instalación rápida en VPS

```bash
#!/bin/bash
# install-on-vps.sh

# Instalar Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Descargar Hermes Docker
git clone https://github.com/tu-usuario/hermes-docker.git
cd hermes-docker

# Configurar
cp config/.env.example .env
nano .env  # Agregar tus API keys

# Iniciar
docker-compose up -d

# Ver logs
docker-compose logs -f
```

### Usar el archivo de distribución completo

Para distribuir Hermes sin necesidad de GitHub:

```bash
# Crear distribución standalone
tar czf hermes-docker-complete.tar.gz hermes-docker/

# En el VPS
tar xzf hermes-docker-complete.tar.gz
cd hermes-docker
make build && make start
```

## 🔒 Seguridad

### Variables sensibles
- Nunca commitees el archivo `.env`
- Usa secretos de Docker Swarm o Kubernetes para producción
- Rota las API keys regularmente

### Recomendaciones de red
```yaml
# En docker-compose.yml, restringe puertos si no los usas
ports:
  # Solo si necesitas webhooks externos
  - "127.0.0.1:8080:8080"  # Solo localhost
```

## 📊 Monitoreo

### Logs
```bash
# Logs en tiempo real
make logs

# Logs históricos
docker-compose logs --tail=500
```

### Métricas
```bash
# Uso de recursos
docker stats hermes-gateway

# Health check
hermes doctor
```

## 🔄 Actualizaciones

### Actualizar Hermes
```bash
# Bajar nueva versión del código
cd /opt/hermes-agent-source
git pull origin main

# Reconstruir imagen
make rebuild
make restart
```

### Actualizar imagen base
```bash
make update
```

## 🎯 Casos de Uso Avanzados

### Múltiples instancias (para diferentes clientes)
```bash
# Perfil 1
HERMES_PROFILE=cliente1 docker-compose -p cliente1 up -d

# Perfil 2
HERMES_PROFILE=cliente2 docker-compose -p cliente2 up -d
```

### Con reverse proxy (Nginx/Caddy)
```nginx
# /etc/nginx/sites-available/hermes
server {
    listen 443 ssl;
    server_name hermis.tudominio.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
    }
}
```

## 🆘 Soporte

- Documentación: https://hermes-agent.nousresearch.com/docs/
- Issues: https://github.com/NousResearch/hermes-agent/issues
- Comunidad: Discord de Nous Research
