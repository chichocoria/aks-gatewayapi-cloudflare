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

# --- 1. Solicitud de Datos (Token y Email) ---

# 1.1 Token
echo -e "${C_AMARILLO}Requerido: API Token de Cloudflare para los desafíos DNS-01.${C_RESET}"
echo -n "Por favor, introduce tu Token y presiona [ENTER] (el texto estará oculto): "

read -s -r CF_API_TOKEN
echo ""

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${C_ROJO}Error: El token no puede estar vacío. Abortando.${C_RESET}"
    exit 1
fi

# 1.2 Solicitud de Email
echo -e "${C_AMARILLO}Requerido: Email para notificaciones de Let's Encrypt.${C_RESET}"
echo -n "Por favor, introduce tu Email: "
read LE_EMAIL

# Cerifica que el mail no este vacio
if [ -z "$LE_EMAIL" ]; then
    echo -e "${C_ROJO}Error: El email es necesario para registrar los certificados.${C_RESET}"
    exit 1
fi
echo -e "${C_VERDE}Datos recibidos.${C_RESET}"


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

# --- 4. Configurar Secreto Cloudflare ---
## Generamos el secreto en memoria y lo aplicamos directo (sin tocar disco)
echo -e "${C_CIAN}--- Configurando Secreto de Cloudflare ---${C_RESET}"
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

echo -e "${C_GRIS}Configurando Issuers con el email: $LE_EMAIL ...${C_RESET}"

#Cargamos el mail en el archivo antes de aplicarlo
# No modificamos el archivo original en disco, solo lo que se envía al cluster.
sed "s/EMAIL_PLACEHOLDER/$LE_EMAIL/g" "$CLUSTER_ISSUER_FILE" | kubectl apply -f -

echo -e "${C_VERDE}Cluster Issuer aplicado correctamente.${C_RESET}"

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación de Cert-Manager completada!${C_RESET}"
