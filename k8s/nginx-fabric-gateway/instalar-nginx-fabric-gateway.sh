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

# --- Variables ---
# Usamos la versión estándar v1.1.0 que es muy estable y compatible
GATEWAY_API_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml"

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_AZUL}   INSTALACIÓN DE NGINX GATEWAY FABRIC${C_RESET}"
echo -e "${C_AZUL}=============================================${C_RESET}"

# --- 1. Verificación de Dependencias ---
if ! command -v kubectl &> /dev/null; then
    echo -e "${C_ROJO}Error: kubectl no está instalado.${C_RESET}"
    exit 1
fi
if ! command -v helm &> /dev/null; then
    echo -e "${C_ROJO}Error: helm no está instalado.${C_RESET}"
    exit 1
fi

# --- 2. Instalar CRDs de Gateway API ---
echo -e "${C_CIAN}--- 1. Instalando CRDs Estándar de Gateway API ---${C_RESET}"
echo -e "${C_GRIS}Descargando y aplicando CRDs oficiales (Raw YAML)...${C_RESET}"

# Usamos YAML directo para evitar problemas de path con kustomize remoto
kubectl apply -f "$GATEWAY_API_URL"

echo -e "${C_GRIS}Esperando a que los CRDs estén establecidos...${C_RESET}"
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
echo -e "${C_VERDE}CRDs instalados correctamente.${C_RESET}"

# --- 3. Instalar NGINX Gateway Fabric con Helm (OCI) ---
echo -e "${C_CIAN}--- 2. Desplegando Control Plane (Helm OCI) ---${C_RESET}"

# Instalamos via OCI. El LoadBalancer se creará dinámicamente al aplicar un Gateway válido.
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --wait

echo -e "${C_VERDE}Control Plane instalado. Esperando configuración de Gateway...${C_RESET}"

# --- 4. Aplicar Gateway para activar el LoadBalancer ---
echo -e "${C_CIAN}--- 3. Aplicando Gateway Principal ---${C_RESET}"

GATEWAY_FILE="./nginx-fabric-gateway/gateway-principal.yaml"
REDIRECT_FILE="./nginx-fabric-gateway/redirect.yaml"

if [ -f "$GATEWAY_FILE" ]; then
    echo -e "${C_GRIS}Aplicando $GATEWAY_FILE...${C_RESET}"
    kubectl apply -f "$GATEWAY_FILE"
    echo -e "${C_VERDE}Gateway aplicado. Esto disparará la creación del LoadBalancer.${C_RESET}"
else
    echo -e "${C_ROJO}Error Crítico: No se encontró $GATEWAY_FILE.${C_RESET}"
    echo -e "${C_ROJO}Sin este archivo, NGINX no creará la IP pública.${C_RESET}"
    exit 1
fi

# --- 5. Esperar asignación de IP Pública ---
echo -e "${C_CIAN}--- 4. Esperando IP Pública ---${C_RESET}"
echo -e "${C_GRIS}Buscando servicios LoadBalancer en el namespace nginx-gateway...${C_RESET}"

external_ip=""
# Intentamos buscar durante 2 minutos
for i in {1..24}; do
    # Buscamos CUALQUIER servicio de tipo LoadBalancer en el namespace
    external_ip=$(kubectl get svc -n nginx-gateway --field-selector spec.type=LoadBalancer -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    # Si no es IP, probamos hostname
    if [ -z "$external_ip" ]; then
        external_ip=$(kubectl get svc -n nginx-gateway --field-selector spec.type=LoadBalancer -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    fi

    if [ -n "$external_ip" ]; then
        break
    fi
    
    echo -n "."
    sleep 5
done
echo "" 

if [ -z "$external_ip" ]; then
    echo -e "${C_AMARILLO}Aviso: Aún no se detecta IP externa. Azure puede tardar un poco más.${C_RESET}"
    echo -e "${C_GRIS}Ejecuta 'kubectl get svc -n nginx-gateway' en unos minutos.${C_RESET}"
else
    echo -e "${C_VERDE}¡IP/Host asignado!: ${C_AZUL}${external_ip}${C_RESET}"
fi

# --- 6. Aplicar Redirección ---
if [ -f "$REDIRECT_FILE" ]; then
    echo -e "${C_CIAN}--- 5. Configurando Redirección HTTP -> HTTPS ---${C_RESET}"
    kubectl apply -f "$REDIRECT_FILE"
    echo -e "${C_VERDE}Redirección activada.${C_RESET}"
fi

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación Finalizada!${C_RESET}"