#!/bin/bash

# --- Configuración de Colores ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Variables de Versión ---
KIND_VERSION="0.22.0"
ARGOCD_VERSION="2.10.0"
TERRAFORM_VERSION="1.8.0"
HELM_VERSION="3.14.0"
KUBECTL_VERSION="1.29.0" # Asegúrate de que esta versión sea compatible con tu clúster Kind

CLUSTER_NAME="go-cloud-native-lab"
ARGOCD_NAMESPACE="argocd"
APP_NAMESPACE="go-app-ns" # El namespace que Terraform gestionará

# --- Determinar Arquitectura ---
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    GO_ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    GO_ARCH="arm64"
else
    echo -e "${RED}Error: Arquitectura no soportada ($ARCH). Soportadas: x86_64, aarch664.${NC}"
    exit 1
fi
echo -e "${GREEN}Detectada arquitectura: ${ARCH} (${GO_ARCH})${NC}"

# --- Función para verificar la existencia de un comando ---
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 no encontrado. Por favor, instálalo y asegúrate de que esté en tu PATH.${NC}"
        exit 1
    fi
}

# --- 1. Verificar Requisitos Previos ---
echo -e "${YELLOW}Verificando requisitos previos...${NC}"
check_command docker
check_command kubectl
check_command curl
check_command unzip
check_command tar
echo -e "${GREEN}Requisitos previos verificados.${NC}"

# --- 2. Instalar Kind ---
echo -e "${YELLOW}Verificando instalación de Kind...${NC}"
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}Kind no encontrado. Instalando kind v${KIND_VERSION}...${NC}"
    # Go tools es necesario para 'go install'
    if ! command -v go &> /dev/null; then
        echo -e "${RED}Error: Go no encontrado. Necesario para instalar Kind. Por favor, instálalo.${NC}"
        exit 1
    fi
    go install sigs.k8s.io/kind@v${KIND_VERSION}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar Kind. Asegúrate de que Go esté configurado correctamente.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Kind instalado correctamente.${NC}"
else
    echo -e "${GREEN}Kind ya está instalado.${NC}"
fi

# --- 3. Crear Clúster Kind ---
echo -e "${YELLOW}Creando o configurando clúster Kind '${CLUSTER_NAME}'...${NC}"
if kind get clusters | grep -q "${CLUSTER_NAME}"; then
    echo -e "${YELLOW}El clúster '${CLUSTER_NAME}' ya existe. Asegurando el contexto...${NC}"
    kubectl config use-context "kind-${CLUSTER_NAME}"
    echo -e "${GREEN}Contexto de kubectl establecido en 'kind-${CLUSTER_NAME}'.${NC}"
else
    echo -e "${YELLOW}Creando clúster Kind '${CLUSTER_NAME}'... Esto puede tardar unos minutos.${NC}"
    kind create cluster --name "${CLUSTER_NAME}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al crear el clúster Kind '${CLUSTER_NAME}'. Revisa los logs de Docker.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Clúster Kind '${CLUSTER_NAME}' creado y configurado en kubectl.${NC}"
fi

# Verificar que el clúster esté listo
echo -e "${YELLOW}Esperando a que el clúster esté listo...${NC}"
kubectl wait --for=condition=ready node/${CLUSTER_NAME}-control-plane --timeout=300s
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: El nodo del clúster no está listo después de 5 minutos.${NC}"
    exit 1
fi
echo -e "${GREEN}Clúster Kind listo.${NC}"

# --- 4. Instalar Terraform (si no está presente) ---
echo -e "${YELLOW}Verificando instalación de Terraform...${NC}"
if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}Terraform no encontrado. Instalando Terraform v${TERRAFORM_VERSION} para ${GO_ARCH}...${NC}"
    TERRAFORM_ZIP="terraform_${TERRAFORM_VERSION}_linux_${GO_ARCH}.zip"
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIP}"
    unzip "${TERRAFORM_ZIP}" -d /usr/local/bin/ # Descomprimir directamente a un PATH
    chmod +x /usr/local/bin/terraform
    rm "${TERRAFORM_ZIP}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar Terraform.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Terraform instalado correctamente.${NC}"
else
    echo -e "${GREEN}Terraform ya está instalado.${NC}"
fi

# --- 5. Instalar Helm (si no está presente) ---
echo -e "${YELLOW}Verificando instalación de Helm...${NC}"
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm no encontrado. Instalando Helm v${HELM_VERSION} para ${GO_ARCH}...${NC}"
    HELM_TAR="helm-v${HELM_VERSION}-linux-${GO_ARCH}.tar.gz"
    curl -LO "https://get.helm.sh/${HELM_TAR}"
    tar -xzf "${HELM_TAR}"
    mv linux-${GO_ARCH}/helm /usr/local/bin/
    rm -rf linux-${GO_ARCH} "${HELM_TAR}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar Helm.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Helm instalado correctamente.${NC}"
else
    echo -e "${GREEN}Helm ya está instalado.${NC}"
fi

# --- 6. Instalar ArgoCD CLI ---
echo -e "${YELLOW}Verificando instalación de ArgoCD CLI...${NC}"
if ! command -v argocd &> /dev/null; then
    echo -e "${YELLOW}ArgoCD CLI no encontrado. Instalando argocd v${ARGOCD_VERSION} para ${GO_ARCH}...${NC}"
    curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${GO_ARCH}"
    chmod +x /usr/local/bin/argocd
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al instalar ArgoCD CLI.${NC}"
        exit 1
    fi
    echo -e "${GREEN}ArgoCD CLI instalado correctamente.${NC}"
else
    echo -e "${GREEN}ArgoCD CLI ya está instalado.${NC}"
fi

# --- 7. Instalar ArgoCD en el Clúster Kind ---
echo -e "${YELLOW}Instalando ArgoCD en el clúster Kind...${NC}"
if ! kubectl get namespace "${ARGOCD_NAMESPACE}" &> /dev/null; then
    echo -e "${YELLOW}Creando namespace '${ARGOCD_NAMESPACE}' para ArgoCD...${NC}"
    kubectl create namespace "${ARGOCD_NAMESPACE}"
else
    echo -e "${GREEN}Namespace '${ARGOCD_NAMESPACE}' ya existe.${NC}"
fi

echo -e "${YELLOW}Aplicando manifiestos de instalación de ArgoCD...${NC}"
kubectl apply -n "${ARGOCD_NAMESPACE}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
if [ $? -ne 0 ]; then
    echo -e "${RED}Error al aplicar los manifiestos de ArgoCD.${NC}"
    exit 1
fi
echo -e "${GREEN}Manifiestos de ArgoCD aplicados. Esperando a que los pods estén listos...${NC}"

# Esperar a que los pods de ArgoCD estén listos
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n "${ARGOCD_NAMESPACE}" --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=300s || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=300s || true

echo -e "${GREEN}Pods de ArgoCD listos.${NC}"

# --- 8. Obtener y Cambiar Contraseña de Administrador de ArgoCD ---
echo -e "${YELLOW}Configurando acceso a ArgoCD...${NC}"

# Obtener la contraseña inicial (autogenerada)
echo -e "${YELLOW}Obteniendo contraseña inicial de ArgoCD...${NC}"
INITIAL_ARGOCD_PASSWORD=""
MAX_RETRIES=10
RETRY_COUNT=0
while [ -z "$INITIAL_ARGOCD_PASSWORD" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    INITIAL_ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ -z "$INITIAL_ARGOCD_PASSWORD" ]; then
        echo -e "${YELLOW}Esperando que el secreto argocd-initial-admin-secret esté disponible... (Intento $((RETRY_COUNT+1))/${MAX_RETRIES})${NC}"
        sleep 10
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ -z "$INITIAL_ARGOCD_PASSWORD" ]; then
    echo -e "${RED}Error: No se pudo obtener la contraseña inicial de ArgoCD. Asegúrate de que ArgoCD se haya instalado correctamente.${NC}"
    exit 1
fi

echo -e "${GREEN}Contraseña inicial de ArgoCD (admin): ${INITIAL_ARGOCD_PASSWORD}${NC}"

# Establecer reenvío de puertos para el acceso a la UI
echo -e "${YELLOW}Estableciendo port-forward para la UI de ArgoCD (https://localhost:8081)...${NC}"
# El 'nohup' y '&' permiten que el port-forward se ejecute en segundo plano
nohup kubectl port-forward svc/argocd-server -n "${ARGOCD_NAMESPACE}" 8081:443 > /dev/null 2>&1 &
echo -e "${GREEN}Port-forward en segundo plano iniciado para ArgoCD UI (https://localhost:8081).${NC}"

# Iniciar sesión con el CLI de ArgoCD
echo -e "${YELLOW}Iniciando sesión en ArgoCD CLI con contraseña inicial...${NC}"
argocd login localhost:8081 --username admin --password "${INITIAL_ARGOCD_PASSWORD}" --insecure --grpc-web # --grpc-web puede ser necesario en algunos entornos
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Falló el inicio de sesión en ArgoCD CLI. Asegúrate de que el port-forward esté activo y ArgoCD esté listo.${NC}"
    exit 1
fi
echo -e "${GREEN}Sesión de ArgoCD CLI iniciada con éxito.${NC}"

# Cambiar la contraseña del administrador
echo -e "${YELLOW}Cambiando la contraseña de 'admin'. Por favor, introduce tu nueva contraseña segura cuando se te solicite...${NC}"
argocd account update-password --account admin --current-password "${INITIAL_ARGOCD_PASSWORD}"
echo -e "${GREEN}Contraseña de ArgoCD cambiada. ¡Recuerda tu nueva contraseña!${NC}"

# --- 9. Resumen del Acceso ---
echo ""
echo -e "--- ${GREEN}¡Configuración del Entorno Cloud-Native Completada!${NC} ---"
echo ""
echo -e "${YELLOW}Detalles del Clúster Kind:${NC}"
echo -e "  Nombre del Clúster: ${GREEN}${CLUSTER_NAME}${NC}"
echo -e "  Contexto kubectl:   ${GREEN}kind-${CLUSTER_NAME}${NC}"
echo -e "  Verifica:           ${GREEN}kubectl get nodes${NC}"
echo ""
echo -e "${YELLOW}Acceso a la UI de ArgoCD:${NC}"
echo -e "  URL:      ${GREEN}https://localhost:8081${NC}"
echo -e "  Usuario:  ${GREEN}admin${NC}"
echo -e "  Contraseña: ${RED}LA QUE ACABAS DE ESTABLECER${NC}"
echo -e "  (El port-forward se está ejecutando en segundo plano.)"
echo ""
echo -e "${YELLOW}Próximos Pasos en el Lab:${NC}"
echo -e "  1. Construye tu imagen Go: ${GREEN}docker build -t go-app:v1 ./go-app${NC}"
echo -e "  2. Carga la imagen en Kind: ${GREEN}kind load docker-image go-app:v1 --name ${CLUSTER_NAME}${NC}"
echo "  3. Ve a la carpeta 'terraform/' y ejecuta: "
echo -e "     ${GREEN}terraform init${NC}"
echo -e "     ${GREEN}terraform apply --auto-approve${NC}"
echo "  4. Configura tu repositorio GitOps remoto (Paso 7.3 en el lab)."
echo "  5. Crea la aplicación en ArgoCD UI o CLI (Paso 7.4 en el lab)."
echo -e "  6. ¡Prueba el despliegue continuo (Paso 7.5 en el lab)!${NC}"
echo ""
