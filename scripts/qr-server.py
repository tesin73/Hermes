#!/usr/bin/env python3
"""
Servidor HTTP simple para mostrar el QR de WhatsApp como imagen.
Accede a: http://IP_DEL_SERVIDOR:8081/qr.png
"""

import http.server
import socketserver
import os
import json
import qrcode
from pathlib import Path
import subprocess
import time
import threading

PORT = 8081
QR_FILE = "/home/hermes/.hermes/whatsapp-qr.png"
LOGS_DIR = "/home/hermes/.hermes/logs"

def extract_qr_from_logs():
    """Extrae el código QR de los logs de WhatsApp."""
    try:
        # Buscar en logs recientes
        log_file = os.path.join(LOGS_DIR, "gateway.log")
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                content = f.read()
                # Buscar patron de QR (generalmente aparece como string largo)
                import re
                qr_pattern = re.search(r'qr\s*[:=]\s*["\']?([a-zA-Z0-9]{100,})', content)
                if qr_pattern:
                    return qr_pattern.group(1)
    except Exception as e:
        print(f"Error leyendo logs: {e}")
    return None

def generate_qr_image(qr_data, output_path):
    """Genera imagen PNG del código QR."""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(qr_data)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        img.save(output_path)
        return True
    except Exception as e:
        print(f"Error generando QR: {e}")
        return False

def monitor_and_generate():
    """Monitorea logs y genera imagen cuando detecta QR."""
    print(f"Monitoreando logs en {LOGS_DIR}...")
    last_qr = None
    
    while True:
        try:
            qr_data = extract_qr_from_logs()
            if qr_data and qr_data != last_qr:
                print(f"Nuevo QR detectado, generando imagen...")
                if generate_qr_image(qr_data, QR_FILE):
                    print(f"✓ QR guardado en: {QR_FILE}")
                    last_qr = qr_data
            time.sleep(5)
        except Exception as e:
            print(f"Error en monitoreo: {e}")
            time.sleep(10)

class QRHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/qr.png' or self.path == '/':
            # Verificar si existe el archivo QR
            if os.path.exists(QR_FILE):
                self.send_response(200)
                self.send_header('Content-type', 'image/png')
                self.end_headers()
                with open(QR_FILE, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                # Generar HTML con instrucciones
                html = b'''<!DOCTYPE html>
<html>
<head>
    <title>WhatsApp QR - Hermes Agent</title>
    <meta http-equiv="refresh" content="5">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .qr-container { margin: 20px auto; max-width: 400px; }
        .waiting { color: #666; }
        .ready { color: green; }
        img { max-width: 100%%; border: 2px solid #ddd; }
    </style>
</head>
<body>
    <h1>WhatsApp QR - Hermes Agent</h1>
    <div class="waiting">
        <p>Esperando c\xc3\xb3digo QR...</p>
        <p>La p\xc3\xa1gina se actualiza autom\xc3\xa1ticamente cada 5 segundos.</p>
    </div>
    <p>Si el QR no aparece en 2 minutos, revisa los logs:</p>
    <code>docker compose logs -f hermes-gateway</code>
</body>
</html>'''
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(html)
        elif self.path == '/status':
            status = {
                'qr_available': os.path.exists(QR_FILE),
                'qr_path': QR_FILE,
                'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
            }
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(status).encode())
        else:
            self.send_error(404)
    
    def log_message(self, format, *args):
        # Silenciar logs HTTP en consola
        pass

def main():
    # Crear directorio si no existe
    os.makedirs(os.path.dirname(QR_FILE), exist_ok=True)
    
    # Iniciar thread de monitoreo
    monitor_thread = threading.Thread(target=monitor_and_generate, daemon=True)
    monitor_thread.start()
    
    # Iniciar servidor HTTP
    with socketserver.TCPServer(("0.0.0.0", PORT), QRHandler) as httpd:
        print(f"\n" + "="*50)
        print(f"Servidor QR iniciado en puerto {PORT}")
        print(f"Accede a: http://IP_DEL_SERVIDOR:{PORT}/qr.png")
        print(f"Status JSON: http://IP_DEL_SERVIDOR:{PORT}/status")
        print("="*50 + "\n")
        httpd.serve_forever()

if __name__ == "__main__":
    main()
