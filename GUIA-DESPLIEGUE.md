# 🚀 Guía de Despliegue - Hermes Agent Docker

> Despliegue completo paso a paso desde cero hasta tener Hermes Agent funcionando en producción.

---

## 📋 ÍNDICE

1. [Requisitos](#-requisitos)
2. [Preparación del Servidor](#-preparación-del-servidor)
3. [Opción A: Deploy Automático (Recomendado)](#-opción-a-deploy-automático-recomendado)
4. [Opción B: Deploy Manual](#-opción-b-deploy-manual)
5. [Configuración de WhatsApp](#-configuración-de-whatsapp)
6. [Verificación y Testing](#-verificación-y-testing)
7. [Comandos Útiles](#-comandos-útiles)
8. [Solución de Problemas](#-solución-de-problemas)
9. [Backup y Restauración](#-backup-y-restauración)
10. [Actualización](#-actualización)

---

## ✅ REQUISITOS

### Hardware Mínimo por VPS
```
CPU:     1 vCPU (2 recomendados)
RAM:     2 GB
Disco:   10 GB SSD
Red:     Conexión estable
OS:      Ubuntu 20.04+ / Debian 11+
```

### Credenciales Necesarias
- [ ] **API Key** de Anthropic (Claude) o OpenRouter
- [ ] Acceso SSH root a la VPS
- [ ] (Opcional) Token de bot de Telegram
- [ ] (Opcional) Número de WhatsApp para gateway

---

## 🖥️ PREPARACIÓN DEL SERVIDOR

### 1. Actualizar Sistema
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 2. Instalar Docker (si no existe)
```bash
# Descargar script oficial
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Recargar grupo (o logout/login)
newgrp docker

# Verificar instalación
docker --version
docker compose version
```

### 3. Verificar Requisitos
```bash
# Espacio en disco
df -h

# RAM disponible
free -h

# CPUs disponibles
nproc
```

---

## 🤖 OPCIÓN A: DEPLOY AUTOMÁTICO (RECOMENDADO)

### Paso 1: Descargar el Repositorio
```bash
cd /opt
sudo git clone https://github.com/tesin73/Hermes.git hermes-docker
```

### Paso 2: Ejecutar Script de Deploy
```bash
cd hermes-docker
chmod +x deploy-hermes.sh

# Opción A: Con API key de Anthropic
sudo ./deploy-hermes.sh sk-ant-api03-TU-API-KEY-AQUI

# Opción B: Con API key de OpenRouter
sudo ./deploy-hermes.sh sk-or-v1-TU-API-KEY-AQUI

# Opción C: Sin API key (la pedirá después)
sudo ./deploy-hermes.sh
```

### Paso 3: Configurar `.env` (si no lo hiciste antes)
```bash
sudo nano /opt/hermes-docker/.env
```

Contenido mínimo requerido:
```env
# API Key (REQUERIDO)
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxx

# Gateway
HERMES_GATEWAY_ENABLED=true
HERMES_LOG_LEVEL=INFO

# WhatsApp
WHATSAPP_ENABLED=true
WHATSAPP_SESSION_NAME=hermes-session
```

### Paso 4: Reiniciar con nuestra configuración
```bash
cd /opt/hermes-docker
sudo docker compose restart
```

**✅ Listo! Salta a [Configuración de WhatsApp](#-configuración-de-whatsapp)**

---

## 🔧 OPCIÓN B: DEPLOY MANUAL

### Paso 1: Clonar Repositorio
```bash
cd /opt
sudo git clone https://github.com/tesin73/Hermes.git hermes-docker
cd hermes-docker
```

### Paso 2: Crear Archivo de Configuración
```bash
sudo cp config/.env.example .env
sudo nano .env
```

Editar con tus valores:
```env
# ===========================================
# CONFIGURACIÓN OBLIGATORIA
# ===========================================

# API Key de Anthropic (REQUERIDO)
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxx

# O API Key de OpenRouter (alternativa)
# OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxx

# ===========================================
# GATEWAY
# ===========================================
HERMES_GATEWAY_ENABLED=true
HERMES_GATEWAY_PLATFORMS=whatsapp,telegram
HERMES_LOG_LEVEL=INFO

# ===========================================
# WHATSAPP (Opcional pero recomendado)
# ===========================================
WHATSAPP_ENABLED=true
WHATSAPP_SESSION_NAME=hermes-session
WHATSAPP_QR_TIMEOUT=60000

# ===========================================
# TELEGRAM (Opcional)
# ===========================================
TELEGRAM_ENABLED=false
TELEGRAM_BOT_TOKEN=

# ===========================================
# MEMORIA
# ===========================================
HERMES_MEMORY_ENABLED=true
```

### Paso 3: Construir la Imagen Docker
```bash
# Este proceso toma 5-10 minutos la primera vez
sudo docker compose build
```

Verás salida similar a:
```
[+] Building 234.5s (23/23) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 4.5kB
 => [6/8] RUN pip install -e /opt/hermes-agent-source
 ...
 => exporting to image
 => => naming to docker.io/library/hermes-agent:full
```

### Paso 4: Iniciar Servicios
```bash
# Iniciar en background
sudo docker compose up -d

# Verificar estado
sudo docker compose ps
```

### Paso 5: Ver Logs Iniciales
```bash
# Ver logs en tiempo real
sudo docker compose logs -f

# O ver últimas 100 líneas
sudo docker compose logs --tail 100
```

---

## 📱 CONFIGURACIÓN DE WHATSAPP

### Obtener el Código QR

**Opción 1: Ver logs buscando QR**
```bash
sudo docker compose logs -f hermes-gateway | grep -A 30 "QR"
```

**Opción 2: Usar el Makefile**
```bash
sudo make whatsapp-qr
```

**Opción 3: Entrar al contenedor**
```bash
sudo docker compose exec hermes-gateway bash
# Dentro del contenedor:
hermes gateway whatsapp-qr
```

### Escanear el QR

1. Abre **WhatsApp en tu teléfono**
2. Ve a: **Menú (⋮)** → **Dispositivos vinculados** → **Vincular dispositivo**
3. Escanea el código QR que aparece en los logs
4. **⏱️ Tienes 60 segundos** para escanear antes de que expire

### Verificar Conexión
```bash
# Ver estado del gateway
sudo docker compose exec hermes-gateway hermes doctor

# O ver logs específicos de WhatsApp
sudo docker compose logs hermes-gateway | grep -i whatsapp
```

Deberías ver: `✓ WhatsApp connected as: +1234567890`

---

## ✔️ VERIFICACIÓN Y TESTING

### 1. Verificar Contenedores
```bash
sudo docker compose ps
```

Debería mostrar:
```
NAME              STATUS
hermes-gateway    Up (healthy)
```

### 2. Probar Respuesta del Bot

**Por WhatsApp:**
- Envía un mensaje al número conectado
- El bot debería responder en segundos

**Por Terminal (sin gateway):**
```bash
sudo docker compose exec hermes-gateway hermes ask "Hola, ¿funcionas?"
```

### 3. Verificar Health Check
```bash
sudo docker compose exec hermes-gateway hermes doctor
```

Salida esperada:
```
✓ Docker container running
✓ Environment variables loaded
✓ API key valid
✓ Gateway service active
✓ WhatsApp connected
✓ Memory system operational
```

---

## 🛠️ COMANDOS ÚTILES

### Makefile (más fácil)
```bash
# Ver todos los comandos disponibles
make help

# Construir imagen
make build

# Iniciar servicios
make start

# Detener servicios
make stop

# Reiniciar
make restart

# Ver logs
make logs
make logs-whatsapp   # Solo logs de WhatsApp

# Acceder al shell del contenedor
make shell

# WhatsApp específico
make whatsapp-qr     # Mostrar QR
make whatsapp-reset  # Resetear sesión

# Backup
make backup-create   # Crear backup
make backup-list     # Listar backups
make restore         # Restaurar backup

# Actualizar
make update          # Actualizar código y rebuild

# Limpieza (⚠️ CUIDADO)
make clean           # Borra TODO incluyendo datos
make clean-images    # Borra imágenes no usadas
```

### Docker Compose Directo
```bash
# Estado
sudo docker compose ps
sudo docker compose top

# Logs
sudo docker compose logs -f              # Todos los servicios
sudo docker compose logs -f hermes-gateway  # Solo gateway
sudo docker compose logs --tail 50       # Últimas 50 líneas

# Gestión
sudo docker compose up -d                # Iniciar
sudo docker compose down                 # Detener
sudo docker compose restart              # Reiniciar
sudo docker compose down -v              # Detener + borrar volúmenes

# Acceder al contenedor
sudo docker compose exec hermes-gateway bash

# Ejecutar comando dentro del contenedor
sudo docker compose exec hermes-gateway hermes status
```

### Systemd (opcional - auto-start)
```bash
# Crear servicio systemd
sudo tee /etc/systemd/system/hermes-docker.service << 'EOF'
[Unit]
Description=Hermes Agent Docker
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/hermes-docker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

# Habilitar servicio
sudo systemctl daemon-reload
sudo systemctl enable hermes-docker
sudo systemctl start hermes-docker

# Verificar estado
sudo systemctl status hermes-docker
```

---

## 🔧 SOLUCIÓN DE PROBLEMAS

### Problema: "No se muestra el QR"
**Causa:** Timeout o sesión previa corrupta
**Solución:**
```bash
# Regenerar QR
make whatsapp-qr

# O reset completo si persiste
make whatsapp-reset
```

### Problema: "Session invalid" o desconexiones
**Causa:** Sesión expirada o WhatsApp Web abierto en otro lado
**Solución:**
```bash
# 1. Cerrar WhatsApp Web en tu navegador/navegadores
# 2. Resetear sesión
make whatsapp-reset
# 3. Escanear QR nuevamente
```

**⚠️ IMPORTANTE:** WhatsApp Web solo permite UNA sesión activa. Si abres WhatsApp Web en tu PC, el bot se desconectará.

### Problema: "Build falla" o errores de dependencias
**Solución:**
```bash
# Limpiar y rebuild limpio
make clean
make build
```

### Problema: "Container unhealthy"
**Verificar:**
```bash
# Ver logs de error
sudo docker compose logs --tail 100

# Verificar variables de entorno
cat .env

# Probar API key
sudo docker compose exec hermes-gateway hermes doctor
```

### Problema: "No hay respuesta del bot"
**Checklist:**
1. ¿El contenedor está corriendo? `sudo docker compose ps`
2. ¿WhatsApp está conectado? `make logs-whatsapp | grep "connected"`
3. ¿La API key es válida? Revisar en logs nulos
4. ¿El número de teléfono es el correcto? Verificar `.env`

### Recolectar Información para Debug
```bash
# Información del sistema
sudo docker version
sudo docker compose version
sudo docker info

# Estado de contenedores
sudo docker compose ps
sudo docker compose top

# Logs completos
sudo docker compose logs > hermes-logs-$(date +%Y%m%d).txt

# Configuración (sin secrets)
cat .env | grep -v "KEY\|TOKEN\|PASSWORD"
```

---

## 💾 BACKUP Y RESTAURACIÓN

### Crear Backup
```bash
# Con Makefile
make backup-create

# Manual
sudo tar czf hermes-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  -C /var/lib/docker/volumes \
  hermes-docker_hermes_config \
  hermes-docker_hermes_workspace
```

### Listar Backups
```bash
make backup-list
# o
ls -la backups/
```

### Restaurar Backup
```bash
# Con Makefile
make restore
# (muestra lista numerada, eliges el número)

# Manual
sudo docker compose down
sudo tar xzf backups/hermes-backup-XXXX.tar.gz -C /tmp/
# Copiar archivos a volúmenes Docker
sudo docker compose up -d
```

### Migrar a Nueva VPS
```bash
# En VPS origen:
make backup-create
scp backups/hermes-backup-*.tar.gz root@nueva-vps:/opt/hermes-docker/backups/

# En VPS nueva:
cd /opt/hermes-docker
./deploy-hermes.sh    # Deploy limpio
make restore          # Restaurar backup
```

---

## 🔄 ACTUALIZACIÓN

### Actualizar Hermes Agent
```bash
# Con Makefile (recomendado)
make update

# Manual paso a paso:
cd /opt/hermes-docker
sudo git pull origin main
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d
```

### Actualizar Ubuntu/Debian
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### Actualizar Docker
```bash
# El script oficial actualiza Docker
sudo sh -c "$(curl -fsSL https://get.docker.com)"
```

---

## 📊 MONITOREO

### Ver Recursos Usados
```bash
# Por contenedor
sudo docker stats hermes-gateway --no-stream

# Sistema completo
sudo docker system df
```

### Logs Rotados Automáticamente
Los logs se rotan cada 100MB, manteniendo 3 archivos (configuración en `docker-compose.yml`)

### Health Check
El contenedor incluye healthcheck automático cada 60 segundos. Si falla 3 veces, Docker lo marca como `unhealthy`.

---

## 🌐 DESPLIEGUE MASIVO (Múltiples VPS)

### Script para deploy en múltiples servidores

```bash
#!/bin/bash
# deploy-masivo.sh

API_KEY="sk-ant-api03-TU-API-KEY"
SERVERS=("vps1.ejemplo.com" "vps2.ejemplo.com" "vps3.ejemplo.com")

for SERVER in "${SERVERS[@]}"; do
  echo "🚀 Desplegando en $SERVER..."
  
  # Copiar script de deploy
  scp deploy-hermes.sh root@$SERVER:/tmp/
  
  # Ejecutar deploy remoto
  ssh root@$SERVER "chmod +x /tmp/deploy-hermes.sh && /tmp/deploy-hermes.sh $API_KEY"
  
  echo "✅ $SERVER completado"
done
```

### Múltiples Instancias en Mismo VPS

```bash
# Cliente A
cd /opt/hermes-docker-cliente-a
docker-compose -p cliente-a up -d

# Cliente B (puertos diferentes)
cd /opt/hermes-docker-cliente-b
# Modificar puertos en docker-compose.yml
docker-compose -p cliente-b up -d
```

---

## 🎯 CHECKLIST FINAL

Antes de dar por terminado el deploy, verifica:

- [ ] API key configurada en `.env`
- [ ] Contenedor corriendo (`hermes-gateway Up`)
- [ ] WhatsApp conectado (se ve en logs)
- [ ] Bot responde mensajes de prueba
- [ ] Backup inicial creado (`make backup-create`)
- [ ] Systemd service habilitado (opcional)
- [ ] Puertos abiertos en firewall si es necesario

---

## 📞 SOPORTE

Si tienes problemas:

1. Revisar logs: `sudo docker compose logs --tail 200`
2. Verificar estado: `sudo docker compose exec hermes-gateway hermes doctor`
3. Crear issue en: https://github.com/tesin73/Hermes/issues

---

**¡Listo! Tu Hermes Agent debería estar funcionando completamente. 🎉**
