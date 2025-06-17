# Usa una imagen base Go oficial
FROM golang:1.24-alpine AS builder

# Establece el directorio de trabajo
WORKDIR /app

# Copia los archivos del proyecto
COPY . .

# Descarga las dependencias
RUN go mod init go-app || true # Inicializa go.mod si no existe
RUN go mod tidy

# Compila la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Imagen final
FROM alpine:latest

WORKDIR /root/

# Copia el ejecutable desde la etapa de construcción
COPY --from=builder /app/main .

# Expone el puerto que usa la aplicación
EXPOSE 8080

# Comando para ejecutar la aplicación
CMD ["./main"]