#!/bin/bash

# --- Configuración de Seguridad ---
set -e              # Detiene el script si un comando falla
set -o pipefail     # Detiene el script si falla algo en una tubería |

# --- Definición de Colores ---
C_RESET='\e[0m'
C_VERDE='\e[1;32m'
C_AZUL='\e[1;34m'
C_CIAN='\e[1;36m'
C_GRIS='\e[0;37m'
C_ROJO='\e[1;31m'
C_AMARILLO='\e[1;33m'

echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_AZUL}       INSTALACIÓN DE KITE (HELM)${C_RESET}"
echo -e "${C_AZUL}=============================================${C_RESET}"

# --- 1. Agregar repositorio Helm ---
echo -e "${C_CIAN}--- Configurando repositorio de Helm ---${C_RESET}"
echo -e "${C_GRIS}Agregando repositorio 'kite'...${C_RESET}"
helm repo add kite https://zxh326.github.io/kite

echo -e "${C_GRIS}Actualizando repositorios...${C_RESET}"
helm repo update

# --- 2. Instalar Kite ---
echo -e "${C_CIAN}--- Instalando Kite Chart ---${C_RESET}"
# Usamos --wait para asegurar que los pods estén listos antes de seguir
helm upgrade --install kite kite/kite \
  --namespace kube-system \
  --wait

echo -e "${C_VERDE}Kite instalado correctamente en namespace 'kube-system'.${C_RESET}"

# --- 3. Aplicar HTTPRoute ---
ROUTE_FILE="./kite/httproute.yaml"

echo -e "${C_CIAN}--- Exponiendo Kite con Gateway API ---${C_RESET}"

# Verificamos si el script se está ejecutando desde dentro de la carpeta 'kite' o desde fuera
if [ -f "httproute.yaml" ]; then
    ROUTE_FILE="httproute.yaml"
elif [ ! -f "$ROUTE_FILE" ]; then
    echo -e "${C_AMARILLO}ADVERTENCIA: No se encontró el archivo httproute.yaml.${C_RESET}"
    echo -e "${C_AMARILLO}Kite está instalado pero no tiene ruta de acceso externa.${C_RESET}"
    echo -e "${C_VERDE}Instalación finalizada (parcial).${C_RESET}"
    exit 0
fi

echo -e "${C_GRIS}Aplicando ruta desde $ROUTE_FILE...${C_RESET}"
kubectl apply -f "$ROUTE_FILE"

echo -e "${C_VERDE}Ruta aplicada.${C_RESET}"
echo -e "${C_AZUL}=============================================${C_RESET}"
echo -e "${C_VERDE}¡Instalación de Kite completada!${C_RESET}"