#!/bin/bash
# =============================================================================
# ENTRYPOINT - Inicialización del contenedor Hermes
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  HERMES AGENT - Docker Container${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ---------------------------------------------------------------------------
# VALIDACIÓN DE CONFIGURACIÓN
# ---------------------------------------------------------------------------

# Verificar que existe al menos una API key
if [[ -z "$ANTHROPIC_API_KEY" && -z "$OPENROUTER_API_KEY" && -z "$OPENAI_API_KEY" && -z "$DEEPSEEK_API_KEY" ]]; then
    echo -e "${RED}ERROR: No se configuró ninguna API key${NC}"
    echo "Por favor configura al menos una de:"
    echo "  - ANTHROPIC_API_KEY"
    echo "  - OPENROUTER_API_KEY"
    echo "  - OPENAI_API_KEY"
    echo "  - DEEPSEEK_API_KEY"
    exit 1
fi

# ---------------------------------------------------------------------------
# INICIALIZACIÓN DEL DIRECTORIO DE CONFIGURACIÓN
# ---------------------------------------------------------------------------

HERMES_DIR="$HOME/.hermes"
CONFIG_FILE="$HERMES_DIR/config.yaml"
ENV_FILE="$HERMES_DIR/.env"

echo -e "${YELLOW}→ Inicializando configuración...${NC}"

# Crear estructura de directorios
mkdir -p "$HERMES_DIR"/{skills,sessions,logs,profiles}

# Copiar config base si no existe
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}  → Creando config.yaml desde template...${NC}"
    envsubst < "$HERMES_DIR/config.yaml.template" > "$CONFIG_FILE"
fi

# Crear archivo .env con las variables del contenedor
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${YELLOW}  → Creando archivo .env...${NC}"
    # Exportar todas las variables relevantes al .env
    cat > "$ENV_FILE" << EOF
# Auto-generado por el contenedor en $(date)
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
COPILOT_GITHUB_TOKEN=${COPILOT_GITHUB_TOKEN:-}
HF_TOKEN=${HF_TOKEN:-}
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY:-}
GROQ_API_KEY=${GROQ_API_KEY:-}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN:-}
SLACK_SIGNING_SECRET=${SLACK_SIGNING_SECRET:-}
EMAIL_PASSWORD=${EMAIL_PASSWORD:-}
EOF
    chmod 600 "$ENV_FILE"
fi

# ---------------------------------------------------------------------------
# VERIFICACIÓN DE DEPENDENCIAS
# ---------------------------------------------------------------------------

echo -e "${YELLOW}→ Verificando instalación...${NC}"
hermes doctor --fix 2>/dev/null || true

# ---------------------------------------------------------------------------
# MODO DE EJECUCIÓN
# ---------------------------------------------------------------------------

MODE="${1:-gateway}"

case "$MODE" in
    gateway)
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  INICIANDO HERMES GATEWAY${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}Plataformas habilitadas:${NC}"
        [[ "$WHATSAPP_ENABLED" == "true" ]] && echo "  ✓ WhatsApp"
        [[ "$TELEGRAM_ENABLED" == "true" ]] && echo "  ✓ Telegram"
        [[ "$DISCORD_ENABLED" == "true" ]] && echo "  ✓ Discord"
        [[ "$SLACK_ENABLED" == "true" ]] && echo "  ✓ Slack"
        [[ "$EMAIL_ENABLED" == "true" ]] && echo "  ✓ Email"
        echo ""
        
        # WhatsApp: mostrar QR si es primera vez
        if [[ "$WHATSAPP_ENABLED" == "true" ]]; then
            echo -e "${YELLOW}📱 Si es la primera vez, escanea el código QR que aparecerá a continuación${NC}"
            echo -e "${YELLOW}   con WhatsApp en tu teléfono (Ajustes > Dispositivos vinculados)${NC}"
            echo ""
        fi
        
        exec hermes gateway run
        ;;
    
    cli)
        echo -e "${GREEN}Iniciando CLI interactivo...${NC}"
        exec hermes
        ;;
    
    cron)
        echo -e "${GREEN}Iniciando scheduler de cron jobs...${NC}"
        # Aquí iría la lógica para ejecutar cron jobs
        # Hermes tiene su propio scheduler integrado
        exec hermes cron status && hermes gateway run
        ;;
    
    setup)
        echo -e "${GREEN}Ejecutando setup interactivo...${NC}"
        exec hermes setup
        ;;
    
    bash|shell|sh)
        echo -e "${GREEN}Iniciando shell...${NC}"
        exec /bin/bash
        ;;
    
    hermes)
        # Pasar argumentos directamente a hermes
        shift
        exec hermes "$@"
        ;;
    
    *)
        # Ejecutar el comando proporcionado
        exec "$@"
        ;;
esac
