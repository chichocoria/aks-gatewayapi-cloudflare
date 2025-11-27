#!/bin/bash

# --- Configuración de Seguridad ---
set -e
set -o pipefail

# --- Definición de Colores ---
C_RESET='\e[0m'
C_ROJO='\e[1;31m'
C_VERDE='\e[1;32m'
C_AMARILLO='\e[1;33m'
C_AZUL='\e[1;34m'
C_CIAN='\e[1;36m'
C_GRIS='\e[0;37m'

# --- Variables de Versión ---
GATEWAY_API_VERSION="v1.5.1"
NGINX_FABRIC_VERSION="v1.6.1"

# --- Verificación de Dependencias ---
echo -e "${C_AZUL}Verificando dependencias (kubectl)...${C_RESET}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${C_ROJO}Error: kubectl no está instalado. Por favor, instala kubectl primero.${C_RESET}"
    exit 1
fi
echo -e "${C_VERDE}Dependencias encontradas.${C_RESET}"

# --- Función para instalar NGINX Gateway Fabric ---
install_nginx_gateway() {
    echo -e "${C_CIAN}=========================================${C_RESET}"
    echo -e "${C_CIAN}--- Iniciando instalación de NGINX Gateway Fabric ---${C_RESET}"

    # Asegúrate de que este archivo exista, ya que es la definición de tu Gateway
    local gateway_file="./nginx-fabric-gateway/gateway-principal.yaml"

    echo -e "${C_GRIS}[1/3] Instalando CRDs de Gateway API (ref: $GATEWAY_API_VERSION)...${C_RESET}"
    kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=$GATEWAY_API_VERSION" | kubectl apply -f -

    echo -e "${C_GRIS}Esperando a que se establezcan los CRDs de Gateway API...${C_RESET}"
    kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
    kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=60s

    echo -e "${C_GRIS}[2/3] Instalando NGINX Gateway Fabric (v$NGINX_FABRIC_VERSION)...${C_RESET}"
    kubectl apply -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/$NGINX_FABRIC_VERSION/deploy/crds.yaml"
    # Usamos 'deploy.yaml' de la carpeta 'nodeport' o 'clusterip'. Para este caso, cualquiera funciona.
    kubectl apply -f "https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/$NGINX_FABRIC_VERSION/deploy/nodeport/deploy.yaml"

    echo -e "${C_GRIS}Esperando a que el deployment 'nginx-gateway' esté listo...${C_RESET}"
    kubectl wait --for=condition=Available deployment/nginx-gateway -n nginx-gateway --timeout=180s
    echo -e "${C_GRIS}Pods de NGINX Gateway listos:${C_RESET}"
    kubectl get pods -n nginx-gateway
    echo -e "${C_VERDE}Servicio 'nginx-gateway' creado como ClusterIP.${C_RESET}"

    if [ ! -f "$gateway_file" ]; then
        echo -e "${C_AMARILLO}[3/3] ADVERTENCIA: No se encontró '$gateway_file'.${C_RESET}"
        echo -e "${C_AMARILLO}NGINX Gateway Fabric está instalado, pero el Gateway *principal* NO fue desplegado.${C_RESET}"
    else
        echo -e "${C_GRIS}[3/3] Aplicando Gateway principal desde $gateway_file...${C_RESET}"
        kubectl apply -f "$gateway_file"
        echo -e "${C_VERDE}Gateway principal aplicado.${C_RESET}"
    fi

    echo -e "${C_VERDE}--- NGINX Gateway Fabric instalado. ---${C_RESET}"
}

# --- Lógica Principal ---
install_nginx_gateway

echo -e "${C_CIAN}=========================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación completada!${C_RESET}"