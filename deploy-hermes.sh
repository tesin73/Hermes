#!/bin/bash
# =============================================================================
# SCRIPT DE DESPLIEGUE AUTOMÁTICO DE HERMES AGENT
# Uso: ./deploy-hermes.sh [API_KEY] [WHATSAPP_NUMERO_OPCIONAL]
# =============================================================================

set -e  # Detenerse en cualquier error

HERMES_DIR="/opt/hermes-docker"
API_KEY="${1:-}"
WHATSAPP_NUM="${2:-}"

echo "=========================================="
echo "  DESPLIEGUE DE HERMES AGENT"
echo "=========================================="

# -----------------------------------------------------------------------------
# PASO 1: INSTALAR DOCKER SI NO EXISTE
# -----------------------------------------------------------------------------
echo "[1/8] Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo "  → Instalando Docker..."
    apt-get update -qq
    apt-get install -y -qq curl ca-certificates gnupg lsb-release
    
    # Instalar Docker oficial
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Agregar usuario actual al grupo docker
    usermod -aG docker $USER || true
    
    echo "  ✓ Docker instalado"
else
    echo "  ✓ Docker ya está instalado"
fi

# Verificar docker compose
if ! docker compose version &> /dev/null; then
    echo "  → Instalando Docker Compose plugin..."
    apt-get update -qq
    apt-get install -y -qq docker-compose-plugin
fi

# -----------------------------------------------------------------------------
# PASO 2: CREAR DIRECTORIO Y EXTRAER ARCHIVOS
# -----------------------------------------------------------------------------
echo "[2/8] Preparando directorio de trabajo..."
mkdir -p "$HERMES_DIR"
cd "$HERMES_DIR"

if [ -f /tmp/hermes-deploy.tar.gz ]; then
    tar xzf /tmp/hermes-deploy.tar.gz
    echo "  ✓ Archivos extraídos"
else
    echo "  ✗ ERROR: No se encontró hermes-deploy.tar.gz"
    echo "    Copia el archivo primero: scp hermes-deploy.tar.gz root@vps:/tmp/"
    exit 1
fi

# -----------------------------------------------------------------------------
# PASO 3: CONFIGURAR VARIABLES DE ENTORNO
# -----------------------------------------------------------------------------
echo "[3/8] Configurando variables de entorno..."
if [ ! -f .env ]; then
    # Crear .env desde template
    cat > .env << 'EOF'
# ============================================
# CONFIGURACIÓN HERMES AGENT
# ============================================

# API KEYS - REQUERIDO
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
# O usa OpenRouter:
# OPENROUTER_API_KEY=sk-or-v1-...

# GATEWAY CONFIGURATION
HERMES_GATEWAY_ENABLED=true
HERMES_GATEWAY_PLATFORMS=whatsapp,telegram
HERMES_LOG_LEVEL=INFO

# WHATSAPP (opcional)
WHATSAPP_ENABLED=true
WHATSAPP_SESSION_NAME=hermes-session
WHATSAPP_QR_TIMEOUT=60000
WHATSAPP_PHONE_NUMBER=${WHATSAPP_PHONE_NUMBER}

# TELEGRAM (opcional)
TELEGRAM_ENABLED=false
TELEGRAM_BOT_TOKEN=

# MEMORIA PERSISTENTE
HERMES_MEMORY_ENABLED=true

# PUERTOS
HERMES_API_PORT=8080
HERMES_WEBHOOK_PORT=3000
EOF

    # Reemplazar placeholders si se proporcionaron argumentos
    if [ -n "$API_KEY" ]; then
        sed -i "s/\${ANTHROPIC_API_KEY}/$API_KEY/g" .env
    else
        echo "⚠️  ADVERTENCIA: No se proporcionó API_KEY"
        echo "   Edita $HERMES_DIR/.env y agrega tu ANTHROPIC_API_KEY"
    fi
    
    if [ -n "$WHATSAPP_NUM" ]; then
        sed -i "s/\${WHATSAPP_PHONE_NUMBER}/$WHATSAPP_NUM/g" .env
    fi
    
    echo "  ✓ Archivo .env creado"
else
    echo "  ℹ️  Archivo .env ya existe, se mantiene configuración actual"
fi

# -----------------------------------------------------------------------------
# PASO 4: CONSTRUIR LA IMAGEN DOCKER
# -----------------------------------------------------------------------------
echo "[4/8] Construyendo imagen Docker..."
echo "  (Este proceso puede tomar 5-10 minutos la primera vez)"
docker compose build --no-cache 2>&1 | tee build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "  ✓ Imagen construida exitosamente"
else
    echo "  ✗ ERROR: Falló la construcción de la imagen"
    echo "    Revisa build.log para más detalles"
    exit 1
fi

# -----------------------------------------------------------------------------
# PASO 5: INICIAR SERVICIOS
# -----------------------------------------------------------------------------
echo "[5/8] Iniciando servicios..."
docker compose up -d

# Esperar a que el contenedor esté saludable
echo "  → Esperando a que el servicio esté listo..."
sleep 5

MAX_RETRIES=30
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker compose ps | grep -q "healthy"; then
        echo "  ✓ Servicio saludable"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  → Intento $RETRY/$MAX_RETRIES..."
    sleep 2
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    echo "  ⚠️  El servicio no reporta estado 'healthy' pero puede estar funcionando"
fi

# -----------------------------------------------------------------------------
# PASO 6: MOSTRAR INFORMACIÓN DE ACCESO
# -----------------------------------------------------------------------------
echo ""
echo "[6/8] Información del despliegue:"
echo "========================================"
echo " IP del servidor: $(hostname -I | awk '{print $1}')"
echo " Directorio: $HERMES_DIR"
echo " Logs: docker compose logs -f"
echo "========================================"

# -----------------------------------------------------------------------------
# PASO 7: INSTRUCCIONES DE WHATSAPP (si está habilitado)
# -----------------------------------------------------------------------------
if grep -q "WHATSAPP_ENABLED=true" .env 2>/dev/null; then
    echo ""
    echo "[7/8] CONFIGURACIÓN DE WHATSAPP:"
    echo "========================================"
    echo " Para escanear el código QR:"
    echo "   docker compose logs -f hermes-gateway | grep -A 20 'QR'"
    echo ""
    echo " O usa el Makefile:"
    echo "   make whatsapp-qr"
    echo ""
    echo "⚠️  IMPORTANTE:"
    echo "   - El QR aparecerá en los logs"
    echo "   - Tienes 60 segundos para escanearlo"
    echo "   - Usa WhatsApp en tu teléfono → Dispositivos vinculados → Vincular"
    echo "========================================"
fi

# -----------------------------------------------------------------------------
# PASO 8: COMANDOS ÚTILES
# -----------------------------------------------------------------------------
echo ""
echo "[8/8] COMANDOS ÚTILES:"
echo "========================================"
echo " Ver logs en tiempo real:"
echo "   cd $HERMES_DIR && docker compose logs -f"
echo ""
echo " Reiniciar servicio:"
echo "   cd $HERMES_DIR && docker compose restart"
echo ""
echo " Ver estado:"
echo "   cd $HERMES_DIR && docker compose ps"
echo ""
echo " Acceder al shell:"
echo "   cd $HERMES_DIR && docker compose exec hermes-gateway bash"
echo ""
echo " Backup de configuración:"
echo "   cd $HERMES_DIR && make backup-create"
echo "========================================"

echo ""
echo "✅ DESPLIEGUE COMPLETADO"
echo ""

# Mostrar estado actual
docker compose ps
