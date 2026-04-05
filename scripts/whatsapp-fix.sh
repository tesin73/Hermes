#!/bin/bash
# =============================================================================
# SCRIPTS DE AYUDA PARA WHATSAPP - Soluciona problemas comunes
# =============================================================================

set -e

HERMES_DIR="${HOME}/.hermes"
WHATSAPP_SESSION_DIR="$HERMES_DIR/whatsapp_sessions"

color_red='\033[0;31m'
color_green='\033[0;32m'
color_yellow='\033[1;33m'
color_blue='\033[0;34m'
color_nc='\033[0m'

# ---------------------------------------------------------------------------
# FUNCIONES DE AYUDA
# ---------------------------------------------------------------------------

show_help() {
    cat << EOF
Uso: whatsapp-fix.sh [COMANDO]

Comandos disponibles:
    status      - Ver estado de la sesión de WhatsApp
    reset       - Borrar sesión y forzar re-autenticación
    logs        - Ver logs de WhatsApp
    restart     - Reiniciar el servicio de WhatsApp
    qr          - Mostrar QR para escanear
    pair        - Emparejamiento por código (alternativa a QR)
    debug       - Modo debug con logs detallados

Ejemplos:
    docker exec hermes-gateway whatsapp-fix.sh status
    docker exec hermes-gateway whatsapp-fix.sh reset
    docker exec -it hermes-gateway whatsapp-fix.sh qr
EOF
}

check_status() {
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo -e "${color_blue}  ESTADO DE WHATSAPP${color_nc}"
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo ""
    
    # Verificar si hay archivos de sesión
    if [[ -d "$WHATSAPP_SESSION_DIR" ]]; then
        echo -e "${color_green}✓ Directorio de sesión existe${color_nc}"
        ls -la "$WHATSAPP_SESSION_DIR" 2>/dev/null || echo "  (vacío)"
    else
        echo -e "${color_yellow}⚠ No hay directorio de sesión${color_nc}"
    fi
    
    # Logs recientes
    echo ""
    echo -e "${color_blue}Logs recientes:${color_nc}"
    tail -50 ~/.hermes/logs/gateway.log 2>/dev/null | grep -i whatsapp || echo "  (no hay logs de WhatsApp)"
}

reset_session() {
    echo -e "${color_yellow}⚠ Esto borrará la sesión de WhatsApp actual${color_nc}"
    read -p "¿Continuar? (s/N): " confirm
    
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        echo -e "${color_blue}→ Borrando sesión...${color_nc}"
        rm -rf "$WHATSAPP_SESSION_DIR"
        echo -e "${color_green}✓ Sesión borrada${color_nc}"
        echo ""
        echo -e "${color_yellow}Reinicia el contenedor para generar nuevo QR:${color_nc}"
        echo "  docker restart hermes-gateway"
        echo ""
        echo -e "${color_yellow}O ejecuta el modo QR:${color_nc}"
        echo "  docker exec -it hermes-gateway whatsapp-fix.sh qr"
    fi
}

show_logs() {
    echo -e "${color_blue}Logs de WhatsApp:${color_nc}"
    tail -f ~/.hermes/logs/gateway.log 2>/dev/null | grep --color=always -i whatsapp || \
        echo "Esperando logs..."
}

generate_qr() {
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo -e "${color_blue}  GENERANDO CÓDIGO QR${color_nc}"
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo ""
    echo -e "${color_yellow}Instrucciones:${color_nc}"
    echo "1. Abre WhatsApp en tu teléfono"
    echo "2. Ve a Ajustes > Dispositivos vinculados"
    echo "3. Toca 'Vincular un dispositivo'"
    echo "4. Escanea el código QR que aparecerá abajo"
    echo ""
    echo -e "${color_yellow}Generando QR... (espera unos segundos)${color_nc}"
    echo ""
    
    # Comando para regenerar QR
    hermes gateway restart 2>/dev/null || true
    
    # Monitorear logs hasta que aparezca el QR
    timeout 60 tail -f ~/.hermes/logs/gateway.log 2>/dev/null | grep -A 20 -i "qr\|pairing" || \
        echo -e "${color_red}No se pudo generar QR automáticamente${color_nc}"
}

pairing_code() {
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo -e "${color_blue}  EMPAREJAMIENTO POR CÓDIGO${color_nc}"
    echo -e "${color_blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_nc}"
    echo ""
    echo -e "${color_yellow}Esta es una alternativa al QR${color_nc}"
    echo "1. Se mostrará un código de 8 dígitos"
    echo "2. En WhatsApp: Ajustes > Dispositivos vinculados"
    echo "3. Toca 'Vincular con número de teléfono'"
    echo "4. Ingresa el código"
    echo ""
    
    # Nota: Esto requiere implementación específica de Baileys
    echo -e "${color_yellow}Función en desarrollo...${color_nc}"
}

debug_mode() {
    echo -e "${color_blue}Modo DEBUG activado${color_nc}"
    export HERMES_LOG_LEVEL=DEBUG
    export DEBUG="*"
    
    echo -e "${color_blue}Variables de entorno:${color_nc}"
    env | grep -i whatsapp || echo "  (ninguna específica)"
    
    echo ""
    echo -e "${color_blue}Archivos de sesión:${color_nc}"
    ls -laR "$WHATSAPP_SESSION_DIR" 2>/dev/null || echo "  (no existe)"
    
    echo ""
    echo -e "${color_blue}Logs detallados:${color_nc}"
    tail -100 ~/.hermes/logs/gateway.log 2>/dev/null || echo "  (no hay logs)"
}

# ---------------------------------------------------------------------------
# ENTRYPOINT
# ---------------------------------------------------------------------------

COMMAND="${1:-help}"

case "$COMMAND" in
    status) check_status ;;
    reset) reset_session ;;
    logs) show_logs ;;
    restart) hermes gateway restart ;;
    qr) generate_qr ;;
    pair) pairing_code ;;
    debug) debug_mode ;;
    help|--help|-h) show_help ;;
    *)
        echo "Comando desconocido: $COMMAND"
        show_help
        exit 1
        ;;
esac
