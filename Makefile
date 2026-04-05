# =============================================================================
# HERMES AGENT - COMANDOS DE DESPLIEGUE
# =============================================================================

.PHONY: help build start stop restart logs shell config status clean update

# Por defecto muestra ayuda
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  HERMES AGENT - Comandos de despliegue"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🔧 CONSTRUCCIÓN:"
	@echo "  make build          - Construir imagen Docker"
	@echo "  make rebuild        - Reconstruir sin caché"
	@echo "  make update         - Actualizar a última versión"
	@echo ""
	@echo "🚀 DESPLIEGUE:"
	@echo "  make start          - Iniciar servicios (detached)"
	@echo "  make stop           - Detener servicios"
	@echo "  make restart        - Reiniciar servicios"
	@echo "  make status         - Estado de los contenedores"
	@echo ""
	@echo "💻 ADMINISTRACIÓN:"
	@echo "  make shell          - Acceder al contenedor"
	@echo "  make logs           - Ver logs en tiempo real"
	@echo "  make config         - Editar configuración"
	@echo "  make cli            - Iniciar CLI interactivo"
	@echo ""
	@echo "📱 WHATSAPP:"
	@echo "  make whatsapp-qr    - Mostrar código QR (terminal)"
	@echo "  make whatsapp-reset - Borrar sesión y re-autenticar"
	@echo "  make whatsapp-logs  - Ver logs de WhatsApp"
	@echo ""
	@echo "🌐 SERVIDOR QR (para escanear remotamente):"
	@echo "  make qr-start       - Iniciar servidor web con QR"
	@echo "  make qr-stop        - Detener servidor QR"
	@echo "  make qr-url         - Mostrar URLs de acceso"
	@echo "  make qr-logs        - Ver logs del servidor"
	@echo ""
	@echo "🧹 MANTENIMIENTO:"
	@echo "  make clean          - Eliminar contenedores y volúmenes"
	@echo "  make backup         - Backup de configuración"
	@echo "  make restore        - Restaurar configuración"
	@echo ""
	@echo "📊 BACKUPS:"
	@echo "  make backup-create  - Crear backup de datos"
	@echo "  make backup-list    - Listar backups disponibles"
	@echo ""

# ---------------------------------------------------------------------------
# CONSTRUCCIÓN
# ---------------------------------------------------------------------------

build:
	@echo "🔨 Construyendo imagen hermes-agent..."
	docker-compose build

rebuild:
	@echo "🔨 Reconstruyendo sin caché..."
	docker-compose build --no-cache

update:
	@echo "🔄 Actualizando a última versión..."
	git pull origin main 2>/dev/null || echo "No es un repo git"
	docker-compose pull
	docker-compose build --no-cache
	docker-compose up -d

# ---------------------------------------------------------------------------
# DESPLIEGUE
# ---------------------------------------------------------------------------

start:
	@echo "🚀 Iniciando Hermes Agent..."
	docker-compose up -d
	@echo ""
	@echo "✅ Servicios iniciados. Ver logs con: make logs"
	@echo ""
	@echo "📱 Si usas WhatsApp, espera el QR y ejecuta:"
	@echo "   make whatsapp-qr"

stop:
	@echo "🛑 Deteniendo servicios..."
	docker-compose down

restart:
	@echo "🔄 Reiniciando servicios..."
	docker-compose restart

status:
	@echo "📊 Estado de los servicios:"
	docker-compose ps
	@echo ""
	@echo "💾 Uso de recursos:"
	docker stats --no-stream hermes-gateway 2>/dev/null || true

# ---------------------------------------------------------------------------
# ADMINISTRACIÓN
# ---------------------------------------------------------------------------

shell:
	@echo "💻 Accediendo al contenedor..."
	docker-compose exec hermes-gateway /bin/bash

logs:
	@echo "📜 Mostrando logs (Ctrl+C para salir)..."
	docker-compose logs -f hermes-gateway

config:
	@echo "⚙️  Abriendo configuración..."
	$(EDITOR) config/config.yaml || nano config/config.yaml

cli:
	@echo "💻 Iniciando CLI interactivo..."
	docker-compose run --rm hermes-cli

# ---------------------------------------------------------------------------
# WHATSAPP
# ---------------------------------------------------------------------------

whatsapp-qr:
	@echo "📱 Generando código QR..."
	docker-compose exec -T hermes-gateway sh /home/hermes/scripts/whatsapp-fix.sh qr

whatsapp-reset:
	@echo "🔄 Reseteando sesión de WhatsApp..."
	docker-compose exec hermes-gateway sh /home/hermes/scripts/whatsapp-fix.sh reset

whatsapp-logs:
	@echo "📜 Logs de WhatsApp:"
	docker-compose exec hermes-gateway sh /home/hermes/scripts/whatsapp-fix.sh logs

whatsapp-status:
	@echo "📱 Estado de WhatsApp:"
	docker-compose exec hermes-gateway sh /home/hermes/scripts/whatsapp-fix.sh status

# ---------------------------------------------------------------------------
# QR WEB SERVER - Para escanear remotamente
# ---------------------------------------------------------------------------

qr-start:
	@echo "🌐 Iniciando servidor QR en http://localhost:8081..."
	@echo "Accede desde tu navegador para ver el código QR como imagen"
	@echo ""
	docker-compose --profile qr-server up -d qr-server
	@echo ""
	@echo "📱 Servidor QR iniciado. Accede a:"
	@echo "   http://$$(hostname -I | awk '{print $$1}'):8081/qr.png"
	@echo ""
	@echo "⚠️  IMPORTANTE: Abre el puerto 8081 en tu firewall si es necesario"

qr-stop:
	@echo "🛑 Deteniendo servidor QR..."
	docker-compose --profile qr-server down qr-server

qr-logs:
	@echo "📜 Logs del servidor QR:"
	docker-compose logs -f qr-server

qr-url:
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  URL DEL SERVIDOR QR"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@IP=$$(hostname -I | awk '{print $$1}'); \
	if [ -n "$$IP" ]; then \
		echo "  🌐 http://$$IP:8081/qr.png"; \
		echo "  🌐 http://$$IP:8081/status (JSON)"; \
	else \
		echo "  🌐 http://localhost:8081/qr.png"; \
	fi
	@echo ""
	@echo "  💡 Si estás en VPS remota, usa:"
	@echo "     curl -O http://IP:8081/qr.png"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ---------------------------------------------------------------------------
# MANTENIMIENTO
# ---------------------------------------------------------------------------

clean:
	@echo "🧹 Eliminando contenedores y volúmenes..."
	@echo "⚠️  Esto borrará todos los datos persistentes"
	@read -p "¿Estás seguro? (s/N): " confirm && [ $$confirm = "s" ] || exit 1
	docker-compose down -v
	docker volume rm hermes-docker_hermes_config 2>/dev/null || true
	docker volume rm hermes-docker_hermes_workspace 2>/dev/null || true
	@echo "✅ Limpieza completada"

backup-create:
	@echo "💾 Creando backup..."
	@mkdir -p backups
	@BACKUP_NAME="hermes-backup-$$(date +%Y%m%d-%H%M%S).tar.gz"
	docker run --rm \
		-v hermes-docker_hermes_config:/source:ro \
		-v "$$(pwd)/backups:/backup" \
		alpine tar czf /backup/$$BACKUP_NAME -C /source .
	@echo "✅ Backup creado: backups/$$BACKUP_NAME"

backup-list:
	@echo "📂 Backups disponibles:"
	@ls -lh backups/ 2>/dev/null || echo "No hay backups"

restore:
	@echo "📂 Backups disponibles:"
	@ls -1 backups/ 2>/dev/null | nl
	@read -p "Número del backup a restaurar: " num
	@BACKUP_FILE=$$(ls -1 backups/ | sed -n "$${num}p") && \
		docker run --rm \
			-v hermes-docker_hermes_config:/target \
			-v "$$(pwd)/backups:/backup:ro" \
			alpine sh -c "rm -rf /target/* && tar xzf /backup/$$BACKUP_FILE -C /target"
	@echo "✅ Backup restaurado. Reinicia con: make restart"

# ---------------------------------------------------------------------------
# UTILIDADES
# ---------------------------------------------------------------------------

dev-setup:
	@echo "🛠️  Configurando entorno de desarrollo..."
	@cp config/.env.example .env
	@echo "✅ Archivo .env creado. Edítalo con tus credenciales:"
	@echo "   nano .env"

scale:
	@echo "📈 Escalando múltiples instancias..."
	@read -p "Número de instancias: " n
	docker-compose up -d --scale hermes-gateway=$$n

push:
	@echo "📤 Subiendo imagen a registry..."
	@read -p "Nombre de imagen (ej: tuusuario/hermes-agent): " name
	docker tag hermes-agent:full $$name:latest
	docker push $$name:latest
