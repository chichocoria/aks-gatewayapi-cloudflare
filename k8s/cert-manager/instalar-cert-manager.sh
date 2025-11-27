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

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_AZUL}   INSTALACIÓN DE CERT-MANAGER + CLOUDFLARE${C_RESET}"
echo -e "${C_AZUL}=============================================${C_RESET}"

# --- 1. Solicitud Segura del Token ---
echo -e "${C_AMARILLO}Requerido: API Token de Cloudflare para los desafíos DNS-01.${C_RESET}"
echo -n "Por favor, introduce tu Token y presiona [ENTER] (el texto estará oculto): "
# -s oculta el input, -r evita que interprete barras invertidas
read -s -r CF_API_TOKEN
echo "" # Salto de línea después del input oculto

# Validamos que no esté vacío
if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${C_ROJO}Error: El token no puede estar vacío. Abortando.${C_RESET}"
    exit 1
fi
echo -e "${C_VERDE}Token recibido.${C_RESET}"

# --- 2. Preparación de Repositorios ---
echo -e "${C_CIAN}--- Configurando Helm ---${C_RESET}"
echo -e "${C_GRIS}Agregando repositorio de Jetstack...${C_RESET}"
helm repo add jetstack https://charts.jetstack.io
echo -e "${C_GRIS}Actualizando repositorios...${C_RESET}"
helm repo update

# --- 3. Instalación de Cert-Manager ---
echo -e "${C_CIAN}--- Instalando Cert-Manager ---${C_RESET}"
# Usamos 'upgrade --install' para idempotencia.
# --wait asegura que cert-manager esté listo antes de intentar crear issuers.
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true \
  --set crds.enabled=true \
  --wait

echo -e "${C_VERDE}Cert-Manager instalado y ejecutándose.${C_RESET}"

# --- 4. Creación del Secreto de Cloudflare (En Memoria) ---
echo -e "${C_CIAN}--- Configurando Secreto de Cloudflare ---${C_RESET}"
# Aquí está la magia de seguridad:
# 1. Generamos el secreto localmente con --dry-run=client (no lo manda al cluster aún).
# 2. Lo pasamos por tubería (|) directamente a 'kubectl apply'.
# El token NUNCA toca el disco en un archivo .yaml.
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token="$CF_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${C_VERDE}Secreto 'cloudflare-api-token-secret' configurado correctamente.${C_RESET}"

# --- 5. Despliegue del Cluster Issuer ---
CLUSTER_ISSUER_FILE="./cert-manager/cluster-issuer.yaml"
echo -e "${C_CIAN}--- Aplicando Cluster Issuer ---${C_RESET}"

if [ ! -f "$CLUSTER_ISSUER_FILE" ]; then
    echo -e "${C_ROJO}Error: No se encontró el archivo $CLUSTER_ISSUER_FILE${C_RESET}"
    exit 1
fi

kubectl apply -f "$CLUSTER_ISSUER_FILE"
echo -e "${C_VERDE}Cluster Issuer aplicado.${C_RESET}"

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación de Cert-Manager completada!${C_RESET}"
