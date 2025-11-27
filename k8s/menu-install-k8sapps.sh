#!/bin/bash

# --- Definición de Colores ---
C_RESET='\e[0m'
C_ROJO='\e[1;31m'
C_VERDE='\e[1;32m'
C_AMARILLO='\e[1;33m'
C_AZUL='\e[1;34m'
C_CIAN='\e[1;36m'
C_GRIS='\e[0;37m'

# --- Configuración del Log ---
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-menu-$(date +'%Y-%m-%d_%H-%M-%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${C_AZUL}Iniciando el script de menú...${C_RESET}"
echo -e "${C_AZUL}Todo el progreso se guardará en: ${C_AMARILLO}$LOG_FILE${C_RESET}"
echo "================================================="

# --- Funciones Auxiliares ---

run_script() {
    local script_path="$1"
    local app_name="$2"
    if [ ! -f "$script_path" ]; then
        echo -e "${C_ROJO}Error: No se encontró el script en '$script_path'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    echo -e "${C_CIAN}--- Instalando $app_name ---${C_RESET}"
    chmod +x "$script_path"
    if bash "$script_path"; then
        echo -e "${C_VERDE}--- $app_name se instaló correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR: Hubo un problema instalando $app_name. ---${C_RESET}"
    fi
    echo
    read -p "Presiona Enter para volver al menú..."
}

apply_yaml() {
    local yaml_path="$1"
    local app_name="$2"
    if [ ! -f "$yaml_path" ]; then
        echo -e "${C_ROJO}Error: No se encontró el archivo YAML en '$yaml_path'.${C_RESET}"
        read -p "Presiona Enter para volver al menú..."
        return
    fi
    echo -e "${C_CIAN}--- Desplegando $app_name ---${C_RESET}"
    if kubectl apply -f "$yaml_path"; then
        echo -e "${C_VERDE}--- $app_name se desplegó correctamente. ---${C_RESET}"
    else
        echo -e "${C_ROJO}--- ERROR: Hubo un problema desplegando $app_name. ---${C_RESET}"
    fi
    echo
    read -p "Presiona Enter para volver al menú..."
}

# --- Función wrapper para Cert-Manager con ayuda ---
install_cert_manager_with_help() {
    # --- AYUDA PARA EL TOKEN DE API DE CLOUDFLARE ---
    echo -e "${C_AZUL}ℹ️  AYUDA: ¿Dónde obtener el API Token de Cloudflare?${C_RESET}"
    echo -e "${C_GRIS}   1. Ve a tu Perfil de Cloudflare > API Tokens.${C_RESET}"
    echo -e "${C_GRIS}   2. Crea un token con permisos: 'Zone - DNS - Edit' y 'Zone - Zone - Read'.${C_RESET}"
    echo -e "${C_GRIS}   3. Copia el token generado.${C_RESET}"
    echo ""
    # Llamamos al script original que ya pide el token
    run_script "cert-manager/instalar-cert-manager.sh" "Cert-Manager"
}

# --- Bucle principal del menú ---
while true; do
    clear
    echo -e "${C_AZUL}=============================================${C_RESET}"
    echo -e "${C_AZUL}    MENU DE INSTALACIÓN DEL CLUSTER K8S${C_RESET}"
    echo -e "${C_AZUL}=============================================${C_RESET}"
    echo
    echo -e "${C_AMARILLO}--- Infraestructura Base (Orden Recomendado) ---${C_RESET}"
    echo -e "  ${C_VERDE}1. Nginx Fabric Gateway${C_RESET} ${C_GRIS}(Requerido primero)${C_RESET}"
    echo -e "  ${C_VERDE}2. Cert-Manager${C_RESET} ${C_GRIS}(Requiere token de API Cloudflare)${C_RESET}"
    echo
    echo -e "${C_AMARILLO}--- Aplicaciones y Monitoreo ---${C_RESET}"
    echo -e "  ${C_GRIS}4. Kite (Dashboard Ligero)${C_RESET}"
    echo
    echo -e "  ${C_AMARILLO}q. Salir${C_RESET}"
    echo
    
    echo -n -e "${C_AMARILLO}Selecciona una opción: ${C_RESET}" > /dev/tty
    read opcion < /dev/tty

    echo "Opción seleccionada por el usuario: $opcion"

    case $opcion in
        # Infraestructura Base
        1)  run_script "nginx-fabric-gateway/instalar-nginx-fabric-gateway.sh" "Nginx Gateway" ;;
        2)  install_cert_manager_with_help ;;
        3)  deploy_cloudflare_tunnel ;;
        
        # Aplicaciones
        4)  run_script "kite/install-kite.sh" "Kite Dashboard" ;;
        5)  deploy_avatares ;;
        6)  apply_yaml "app-test/app-test-443.yaml" "App-Test" ;;
        7)  run_script "kube-prom-stack/instalar-kube-prom-stack.sh" "Kube-Prom-Stack" ;;
        
        q|Q)
            echo -e "${C_AZUL}Saliendo... Log guardado en $LOG_FILE${C_RESET}"
            break
            ;;
        *)
            echo -e "${C_ROJO}Opción no válida. Intenta de nuevo.${C_RESET}"
            read -p "Presiona Enter para continuar..." < /dev/tty
            ;;
    esac
done