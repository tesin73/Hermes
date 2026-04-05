# =============================================================================
# HERMES AGENT - DOCKER IMAGE COMPLETA
# Incluye todo el sistema sin referencia externa post-build
# =============================================================================

FROM python:3.11-slim-bookworm

# ---------------------------------------------------------------------------
# ARGUMENTOS DE BUILD (se inyectan en tiempo de construcción)
# ---------------------------------------------------------------------------
ARG HERMES_VERSION=main
ARG INSTALL_WHATSAPP=true
ARG WHATSAPP_VERSION=latest

# ---------------------------------------------------------------------------
# DEPENDENCIAS DEL SISTEMA
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    # Herramientas básicas
    git \
    curl \
    wget \
    ca-certificates \
    # Edición de archivos
    nano \
    vim \
    # Procesos y monitoreo
    tmux \
    htop \
    procps \
    # Navegador para browser automation
    chromium \
    chromium-driver \
    # Audio para TTS/STT
    ffmpeg \
    libsndfile1 \
    # Compilación para dependencias Python
    build-essential \
    gcc \
    g++ \
    # Limpieza
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# INSTALACIÓN DE HERMES AGENT (código completo embebido)
# ---------------------------------------------------------------------------
WORKDIR /opt/hermes

# Clonamos el repo (esto se hace UNA VEZ en build, no en runtime)
RUN git clone --depth 1 --branch ${HERMES_VERSION} \
    https://github.com/NousResearch/hermes-agent.git \
    /opt/hermes-agent-source

# Instalamos dependencias Python de Hermes
WORKDIR /opt/hermes-agent-source
RUN pip install --no-cache-dir -e . && \
    pip install --no-cache-dir \
        # Dependencias opcionales pero recomendadas
        faster-whisper \
        kokoro-onnx \
        edge-tts \
        playwright && \
    playwright install chromium

# ---------------------------------------------------------------------------
# INSTALACIÓN DE WHATSAPP GATEWAY (si se habilita)
# ---------------------------------------------------------------------------
RUN if [ "$INSTALL_WHATSAPP" = "true" ]; then \
    apt-get update && apt-get install -y \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @whiskeysockets/baileys-cli@${WHATSAPP_VERSION} || true; \
    fi

# ---------------------------------------------------------------------------
# CONFIGURACIÓN DEL SISTEMA
# ---------------------------------------------------------------------------

# Crear usuario hermes (no root)
RUN useradd -m -s /bin/bash hermes && \
    mkdir -p /home/hermes/.hermes && \
    chown -R hermes:hermes /home/hermes

# Directorio de trabajo del usuario
WORKDIR /home/hermes
USER hermes

# Variables de entorno por defecto
ENV HERMES_HOME=/home/hermes/.hermes
ENV HOME=/home/hermes
ENV PATH="/opt/hermes-agent-source:$PATH"

# Crear estructura de directorios
RUN mkdir -p ~/.hermes/{skills,sessions,logs,profiles}

# ---------------------------------------------------------------------------
# COPIAR ARCHIVOS DE CONFIGURACIÓN BASE
# ---------------------------------------------------------------------------
COPY --chown=hermes:hermes config/config.yaml /home/hermes/.hermes/config.yaml.template
COPY --chown=hermes:hermes config/.env.example /home/hermes/.hermes/.env.example
COPY --chown=hermes:hermes scripts/entrypoint.sh /home/hermes/entrypoint.sh
COPY --chown=hermes:hermes scripts/init-hermes.sh /home/hermes/init-hermes.sh

RUN chmod +x /home/hermes/entrypoint.sh /home/hermes/init-hermes.sh

# ---------------------------------------------------------------------------
# SCRIPT DE INICIALIZACIÓN
# ---------------------------------------------------------------------------
ENTRYPOINT ["/home/hermes/entrypoint.sh"]
CMD ["gateway"]
