# Dockerfile para crear una imagen de Ubuntu 22.04 con herramientas de desarrollo
# y un usuario "arheanja" con permisos de sudo sin contraseña.
# Autor: arheanja
# Fecha: 2023-10-01
# Licencia: MIT
# Usa la imagen base de Ubuntu 22.04

# Base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    sudo \
    && apt-get clean

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    sudo ./aws/install && \
    rm -rf awscliv2.zip aws

# Instala sudo, curl, wget, git, python3, python3-pip, Go y dependencias necesarias
RUN apt-get update && \
    apt-get install -y sudo curl wget git python3 python3-pip software-properties-common gnupg && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y golang-go && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Kind
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64 \
    && chmod +x ./kind \
    && mv ./kind /usr/local/bin/kind

# Instala Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform

# Crea el usuario "arheanja" y agrégalo al grupo sudo
RUN useradd -ms /bin/bash arheanja && \
    echo 'arheanja:password' | chpasswd && \
    usermod -aG sudo arheanja && \
    echo 'arheanja ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER arheanja
WORKDIR /workspace
ENV HOME /home/arheanja