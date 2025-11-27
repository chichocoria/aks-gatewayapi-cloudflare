#!/bin/bash

# --- Variables de Configuración ---
RESOURCE_GROUP="rg-aks-dev"
LOCATION="eastus2"
VNET_NAME="vnet-aks"
SUBNET_NAME="subnet-aks"
AKS_CLUSTER_NAME="aks-cluster-dev" 

# --- Función para Crear los Recursos ---
crear_recursos() {
    # --- 1. Creación del Grupo de Recursos ---
    echo "Verificando el grupo de recursos: $RESOURCE_GROUP..."
    if [ $(az group exists --name $RESOURCE_GROUP) = "false" ]; then
        echo "Creando el grupo de recursos: $RESOURCE_GROUP..."
        az group create --name $RESOURCE_GROUP --location $LOCATION --tags env=dev
    else
        echo "El grupo de recursos '$RESOURCE_GROUP' ya existe. Omitiendo creación."
    fi

    # --- 2. Redes Principales ---
    echo "Verificando la red virtual: $VNET_NAME..."
    if [ -z "$(az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query id -o tsv 2>/dev/null)" ]; then
        echo "Creando la red virtual y la subred..."
        az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name $VNET_NAME \
        --address-prefix 10.10.0.0/16 \
        --subnet-name $SUBNET_NAME \
        --subnet-prefix 10.10.0.0/24 \
        --tags env=dev
    else
        echo "La red virtual '$VNET_NAME' ya existe. Omitiendo creación."
    fi

    # --- 3. Creación del Cluster de AKS (Dev/Test + CSI Driver) ---
    echo "Verificando el cluster de AKS: $AKS_CLUSTER_NAME..."
    
    if [ -z "$(az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --query id -o tsv 2>/dev/null)" ]; then
        echo "Creando el cluster de AKS. Esto puede tardar varios minutos..."
        
        SUBNET_ID=$(az network vnet subnet show \
            --resource-group $RESOURCE_GROUP \
            --vnet-name $VNET_NAME \
            --name $SUBNET_NAME \
            --query id -o tsv)

        # 1. --enable-managed-identity (Requerido para que el CSI Driver funcione)
        # 2. --enable-addons azure-keyvault-secrets-provider (El CSI Driver para Key Vault)
        az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_CLUSTER_NAME \
        --node-count 1 \
        --node-vm-size "Standard_B2s" \
        --tier "Free" \
        --vnet-subnet-id $SUBNET_ID \
        --network-plugin "azure" \
        --network-plugin-mode "overlay" \
        --enable-managed-identity \
        --enable-addons azure-keyvault-secrets-provider \
        --generate-ssh-keys \
        --tags env=dev
        
        echo "Cluster AKS '$AKS_CLUSTER_NAME' creado."
        
        echo "---"
        echo "Para conectarte a tu cluster, ejecuta:"
        echo "az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME"
        echo "---"
        echo "⚠️  ACCIÓN REQUERIDA: Debes dar permisos a la Identidad Administrada del cluster para que pueda leer tu Key Vault."
        echo "---"

    else
        echo "El cluster de AKS '$AKS_CLUSTER_NAME' ya existe. Omitiendo creación."
    fi

    echo "¡Proceso de despliegue completado!"
}

# --- Función para Borrar los Recursos ---
borrar_recursos() {
    ## Borrar Recursos de $RESOURCE_GROUP
    echo "⚠️  ADVERTENCIA: Esta acción eliminará permanentemente el grupo de recursos '$RESOURCE_GROUP' y todos los recursos que contiene (incluido el cluster de AKS)."
    read -p "¿Estás seguro de que quieres continuar? (s/n): " confirmacion

    if [[ "$confirmacion" == "s" || "$confirmacion" == "S" ]]; then
        echo "Eliminando el grupo de recursos '$RESOURCE_GROUP'..."
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        echo "✅ Solicitud de eliminación para '$RESOURCE_GROUP' enviada. La eliminación se está ejecutando en segundo plano."
    else
        echo "Operación cancelada."
    fi
}

# --- Menú Principal del Script ---
echo "--- Script de Gestión de Azure (Versión AKS + Addons) ---"
echo "1. Crear recursos (Grupo de Recursos, VNET, Subnet, Cluster AKS con Addons)"
echo "2. Borrar recursos (Grupo de Recursos)"
read -p "Elige una opción (1 o 2): " opcion

case $opcion in
    1)
        crear_recursos
        ;;
    2)
        borrar_recursos
        ;;
    *)
        echo "Opción no válida. Por favor, elige 1 o 2."
        exit 1
        ;;
esac

exit 0