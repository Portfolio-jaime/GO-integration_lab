# Laboratorio: Integración Cloud-Native con Go, DevContainers, Kind, Terraform y ArgoCD

Este laboratorio integral te guía a través de la configuración de un entorno de desarrollo completamente autocontenido y reproducible para aplicaciones Go en un stack cloud-native. Aprenderás a desarrollar, probar, desplegar y automatizar el ciclo de vida de una aplicación utilizando herramientas clave como DevContainers, Kind (Kubernetes in Docker), Terraform para la infraestructura como código, y ArgoCD para la entrega continua (GitOps).

## Contenido

- [Introducción](#introducción)
- [Arquitectura y Tecnologías Clave](#arquitectura-y-tecnologías-clave)
- [Diagrama de Arquitectura](#diagrama-de-arquitectura)
- [Requisitos Previos](#requisitos-previos)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Configuración del Entorno](#configuración-del-entorno)
  - [Paso 1: Clonar el Repositorio](#paso-1-clonar-el-repositorio)
  - [Paso 2: Ejecutar el Script de Configuración Inicial](#paso-2-ejecutar-el-script-de-configuración-inicial)
  - [Paso 3: Abrir el Proyecto en DevContainer](#paso-3-abrir-el-proyecto-en-devcontainer)
- [Desarrollo y Despliegue de la Aplicación Go](#desarrollo-y-despliegue-de-la-aplicación-go)
  - [Paso 4: Preparar y Probar la Aplicación Go](#paso-4-preparar-y-probar-la-aplicación-go)
  - [Paso 5: Desplegar Infraestructura con Terraform](#paso-5-desplegar-infraestructura-con-terraform)
  - [Paso 6: Acceder a la Aplicación Go Desplegada](#paso-6-acceder-a-la-aplicación-go-desplegada)
- [Despliegue Continuo con ArgoCD (GitOps)](#despliegue-continuo-con-argocd-gitops)
  - [Paso 7: Acceder a la UI de ArgoCD](#paso-7-acceder-a-la-ui-de-argocd)
  - [Paso 8: Configurar y Probar el Flujo GitOps](#paso-8-configurar-y-probar-el-flujo-gitops)
- [Limpieza del Laboratorio](#limpieza-del-laboratorio)
- [Solución de Problemas Comunes](#solución-de-problemas-comunes)
- [Exploración Adicional](#exploración-adicional)

---

## Introducción

En este laboratorio, construirás una aplicación web simple en Go, la empaquetarás en un contenedor Docker, la desplegarás en un clúster Kubernetes local (Kind) utilizando Terraform para definir la infraestructura, y finalmente automatizarás su entrega continua mediante ArgoCD, siguiendo los principios de GitOps. Todo esto se realizará dentro de un entorno de desarrollo unificado proporcionado por VS Code DevContainers.

## Arquitectura y Tecnologías Clave

- **Go**: Lenguaje de programación para la aplicación de ejemplo.
- **Docker**: Motor de contenedorización utilizado para empaquetar la aplicación y para que Kind ejecute los nodos del clúster Kubernetes.
- **DevContainers**: Proporciona un entorno de desarrollo aislado y preconfigurado con todas las herramientas necesarias (Go, Kind, kubectl, Terraform, Helm, ArgoCD CLI).
- **Kind (Kubernetes in Docker)**: Un clúster de Kubernetes ligero que se ejecuta dentro de contenedores Docker en tu máquina local.
- **Terraform**: Herramienta de Infraestructura como Código (IaC) utilizada para provisionar los recursos iniciales de Kubernetes.
- **ArgoCD**: Una herramienta de Entrega Continua basada en GitOps que sincroniza el estado del clúster de Kubernetes con la configuración definida en Git.
- **GitHub (o cualquier Git remoto)**: Fuente de verdad para la configuración deseada de tu aplicación, utilizada por ArgoCD.

## Diagrama de Arquitectura

Este diagrama ilustra el flujo y la interacción entre los diferentes componentes del laboratorio:

```mermaid
graph TD
    subgraph Host Machine (Tu PC Local)
        Docker["Docker Desktop"]
        VSCode["Visual Studio Code"]
        BashScript["Bash Script<br>(setup_cloud_native_env.sh)"]
    end

    subgraph DevContainer (Entorno de Desarrollo Aislado)
        direction LR
        DevEnv["Entorno de Desarrollo"]
        GoAppSrc[/"Código Fuente Go<br>(go-app/)"/]
        GoTests[("Tests Go")]
        DockerCLI(("Docker CLI"))
        Kubectl["kubectl CLI"]
        TerraformCLI["Terraform CLI"]
        ArgoCDCLI["ArgoCD CLI"]

        subgraph Kubernetes Cluster (Kind)
            K8sAPI("Kubernetes API Server")
            K8sNodes[K8s Nodos<br>(Contenedores Docker)]
            GoAppPods[(Pods de la App Go)]
            ArgoCDComponents[ArgoCD Components]
        end

        DevEnv --- GoAppSrc
        DevEnv --- GoTests
        DevEnv -- Acceso a Daemon --> DockerCLI
        DockerCLI -- Control de Contenedores --> K8sNodes
        DevEnv -- Control de Clúster --> Kubectl
        Kubectl -- Interactúa con --> K8sAPI
        TerraformCLI -- Crea Recursos en --> K8sAPI
        ArgoCDCLI -- Configura y Monitoriza --> ArgoCDComponents
        ArgoCDComponents -- Gestiona --> K8sAPI

        K8sAPI -- Despliega App --> GoAppPods
        K8sAPI -- Despliega ArgoCD --> ArgoCDComponents
    end

    subgraph Git Remote (GitHub)
        MainRepo["go-integration_lab.git"]
        K8sManifests[/"Manifiestos K8s<br>(k8s-manifests/)"/]
    end

    VSCode -- Accede al --> DevContainer
    Docker -- Provee Daemon --> DevContainer
    BashScript -- Instala Herramientas & Crea Clúster --> Docker
    BashScript -- Instala Herramientas & Crea Clúster --> Kubectl
    BashScript -- Instala Herramientas & Crea Clúster --> K8sAPI
    BashScript -- Configura --> ArgoCDComponents

    GoAppSrc -- Buildea Imagen --> DockerCLI
    DockerCLI -- Carga Imagen --> K8sNodes
    MainRepo -- Contiene --> K8sManifests

    K8sManifests -- Sincroniza --> ArgoCDComponents
    GoAppPods -- Se accede via --> HostMachine
```

---

## Requisitos Previos

Asegúrate de tener instalado en tu máquina anfitriona:

- Docker Desktop (o Docker Engine / Podman Desktop)
- Visual Studio Code
- Extensión "Dev Containers" para VS Code
- git

---

## Estructura del Proyecto

```
.
├── .devcontainer/                # Configuración del DevContainer (Dockerfile y devcontainer.json)
├── go-app/                       # Código fuente y Dockerfile de la aplicación Go
│   ├── main.go
│   ├── main_test.go
│   └── Dockerfile
├── k8s-manifests/                # Manifiestos de Kubernetes para ArgoCD
│   └── application.yaml
├── terraform/                    # Configuraciones de Terraform para el despliegue inicial
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── setup_cloud_native_env.sh     # Script bash para la configuración inicial (Kind, ArgoCD)
└── README.md                     # Este archivo
```

---

## Configuración del Entorno

### Paso 1: Clonar el Repositorio

```sh
git clone https://github.com/Portfolio-jaime/GO-integration_lab.git
cd GO-integration_lab
```

### Paso 2: Ejecutar el Script de Configuración Inicial

Haz el script ejecutable y ejecútalo:

```sh
chmod +x setup_cloud_native_env.sh
sudo ./setup_cloud_native_env.sh
```

Este script instalará Kind, creará el clúster, instalará ArgoCD y configurará el entorno.

### Paso 3: Abrir el Proyecto en DevContainer

Abre la carpeta en VS Code y acepta "Reopen in Container" cuando se te solicite.

---

## Desarrollo y Despliegue de la Aplicación Go

### Paso 4: Preparar y Probar la Aplicación Go

```sh
cd /workspaces/GO-integration_lab/go-app
go mod init github.com/Portfolio-jaime/GO-integration_lab/go-app
go mod tidy
go test ./...
```

### Construir la Imagen Docker

```sh
cd /workspaces/GO-integration_lab
docker build -t go-app:v1 ./go-app
```

### Cargar la Imagen en Kind

```sh
kind load docker-image go-app:v1 --name go-cloud-native-lab
```

### Paso 5: Desplegar Infraestructura con Terraform

```sh
cd /workspaces/GO-integration_lab/terraform
terraform init
terraform plan
terraform apply --auto-approve
```

Esto creará el namespace, deployment y service necesarios.

### Paso 6: Acceder a la Aplicación Go Desplegada

Verifica los recursos:

```sh
kubectl get deployments -n go-app-ns
kubectl get services -n go-app-ns
kubectl get pods -n go-app-ns
```

Haz port-forward y accede desde tu navegador:

```sh
kubectl port-forward service/go-cloud-app -n go-app-ns 8080:80
```

Abre [http://localhost:8080](http://localhost:8080) en tu navegador.

---

## Despliegue Continuo con ArgoCD (GitOps)

### Paso 7: Acceder a la UI de ArgoCD

Haz port-forward para la UI de ArgoCD (el script lo hace automáticamente):

Abre [https://localhost:8081](https://localhost:8081) y accede con usuario `admin` y la contraseña que configuraste.

### Paso 8: Configurar y Probar el Flujo GitOps

Asegúrate de que los manifiestos estén en `k8s-manifests/`.

Ejemplo de `k8s-manifests/application.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-cloud-app
  namespace: go-app-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-cloud-app
  template:
    metadata:
      labels:
        app: go-cloud-app
    spec:
      containers:
      - name: go-cloud-app
        image: go-app:v1
        ports:
        - containerPort: 8080
        env:
        - name: APP_NAME
          value: "Go App via ArgoCD"
---
apiVersion: v1
kind: Service
metadata:
  name: go-cloud-app
  namespace: go-app-ns
spec:
  selector:
    app: go-cloud-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: NodePort
```

Haz commit y push de los manifiestos:

```sh
cd /workspaces/GO-integration_lab
git add .
git commit -m "Initial Kubernetes manifests in k8s-manifests for ArgoCD"
git push origin main
```

#### Crear la Aplicación en ArgoCD

**Opción A: UI**

- Application Name: go-app-argo
- Project: default
- Sync Policy: Automatic
- Repository URL: tu repo
- Path: k8s-manifests
- Cluster: in-cluster
- Namespace: go-app-ns

**Opción B: CLI**

```sh
argocd app create go-app-argo \
  --repo https://github.com/Portfolio-jaime/GO-integration_lab.git \
  --path k8s-manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace go-app-ns \
  --sync-policy automated \
  --kube-context kind-go-cloud-native-lab
```

Haz cambios en los manifiestos, haz commit y push, y observa la sincronización automática en ArgoCD.

---

## Limpieza del Laboratorio

```sh
cd /workspaces/GO-integration_lab/terraform
terraform destroy --auto-approve

argocd app delete go-app-argo --cascade=true --yes
kubectl delete namespace argocd
kind delete cluster --name go-cloud-native-lab
```

Opcional: limpia imágenes Docker en tu máquina local:

```sh
docker rmi go-app:v1
# docker rmi kindest/node:<version-del-clúster>
```

---

## Solución de Problemas Comunes

- **go: go.mod requires go >= X.Y**: Actualiza la versión de Go en el Dockerfile.
- **FATA[0000] error resolving context**: Usa el flag `--kube-context kind-go-cloud-native-lab` en ArgoCD CLI.
- **Post "http://localhost/api/v1/namespaces": connection refused**: Verifica que el clúster Kind esté corriendo y el config_path en Terraform.
- **permission denied al usar argocd login/app create**: Ajusta permisos en `~/.config/argocd`.
- **Problemas de arquitectura (amd64 vs arm64)**: Asegúrate de descargar binarios arm64 si usas Mac M1/M2/M3.
- **kubectl port-forward no abre en el navegador**: Verifica que el comando esté activo y que `forwardPorts` esté configurado en `devcontainer.json`.

---

## Exploración Adicional

- Monitoreo: Integra Prometheus y Grafana.
- GitOps Avanzado: Usa Kustomize o Helm con ArgoCD.
- CI/CD: Configura un pipeline de CI (ej. GitHub Actions) para automatizar la construcción y despliegue.