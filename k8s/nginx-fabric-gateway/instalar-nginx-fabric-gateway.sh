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
GATEWAY_API_VERSION="v1.5.1"

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

# --- 2. Instalar CRDs de Gateway API (Prerrequisito Estándar) ---
echo -e "${C_CIAN}--- 1. Instalando CRDs Estándar de Gateway API ---${C_RESET}"
# Estos son los recursos base de K8s (Gateway, HTTPRoute, etc.) que Nginx necesita para funcionar.
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.1" | kubectl apply -f -

echo -e "${C_GRIS}Esperando a que los CRDs estén establecidos...${C_RESET}"
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s

# --- 3. Instalar NGINX Gateway Fabric con Helm (CAMBIO CLAVE) ---
echo -e "${C_CIAN}--- 2. Desplegando NGINX Gateway Fabric (vía Helm) ---${C_RESET}"

# Usamos el Chart OCI oficial. 
# --set service.type=LoadBalancer: Aquí definimos el tipo DE UNA VEZ, sin parches posteriores.
helm upgrade --install nginx-gateway oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --set service.type=LoadBalancer \
  --wait

echo -e "${C_VERDE}Instalación de Helm completada.${C_RESET}"

# --- 4. Obtener IP Externa ---
echo -e "${C_CIAN}--- 3. Verificando Acceso Externo ---${C_RESET}"
echo -e "${C_GRIS}Esperando asignación de IP Pública...${C_RESET}"

external_ip=""
while [ -z "$external_ip" ]; do
    # Buscamos la IP en el servicio que creó Helm (el nombre suele ser el del release)
    external_ip=$(kubectl get svc nginx-gateway -n nginx-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$external_ip" ]; then
        external_ip=$(kubectl get svc nginx-gateway -n nginx-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    fi

    if [ -z "$external_ip" ]; then
        echo -n "."
        sleep 3
    fi
done
echo "" 
echo -e "${C_VERDE}IP/Host asignado: ${C_AZUL}${external_ip}${C_RESET}"

# --- 5. Aplicar Configuraciones (Gateway y Redirección) ---
echo -e "${C_CIAN}--- 4. Aplicando Configuración de Rutas ---${C_RESET}"

GATEWAY_FILE="./nginx-fabric-gateway/gateway-principal.yaml"
REDIRECT_FILE="./nginx-fabric-gateway/redirect.yaml" # (Archivo del Punto 3)

if [ -f "$GATEWAY_FILE" ]; then
    echo -e "${C_GRIS}Aplicando Gateway Principal...${C_RESET}"
    kubectl apply -f "$GATEWAY_FILE"
else
    echo -e "${C_AMARILLO}Advertencia: No se encontró $GATEWAY_FILE${C_RESET}"
fi

if [ -f "$REDIRECT_FILE" ]; then
    echo -e "${C_GRIS}Aplicando Redirección HTTP -> HTTPS...${C_RESET}"
    kubectl apply -f "$REDIRECT_FILE"
    echo -e "${C_VERDE}Redirección activada.${C_RESET}"
else
    echo -e "${C_AMARILLO}Nota: No se encontró $REDIRECT_FILE (Redirección inactiva)${C_RESET}"
fi

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_VERDE}¡Despliegue finalizado exitosamente!${C_RESET}"
echo -e "Tu Gateway está listo en: ${C_AZUL}${external_ip}${C_RESET}"