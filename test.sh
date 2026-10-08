#!/usr/bin/env bash
set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  🎬 CinéK8s — Script d'automatisation et de tests    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Configuration de l'environnement Java (Java 21 requis)
if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
fi

echo -e "\n${YELLOW}[1/5] Vérification de la version Java...${NC}"
java -version || { echo -e "${RED}Erreur : Java non trouvé.${NC}"; exit 1; }

# 2. Exécution des tests unitaires Java
echo -e "\n${YELLOW}[2/5] Exécution des tests Java de movie-service...${NC}"
(
    cd "$ROOT_DIR/movie-service"
    ./mvnw test -q
)
echo -e "${GREEN}✔ Tests movie-service : SUCCÈS${NC}"

echo -e "\n${YELLOW}[3/5] Exécution des tests Java de ticket-service...${NC}"
(
    cd "$ROOT_DIR/ticket-service"
    ./mvnw test -q
)
echo -e "${GREEN}✔ Tests ticket-service : SUCCÈS${NC}"

# 4. Build des images Docker (Nécessaire avant le déploiement Kubernetes)
echo -e "\n${YELLOW}[4/5] Construction des images Docker locales...${NC}"
if command -v docker &> /dev/null; then
    # Si minikube est utilisé, on s'assure d'injecter les images dans son daemon
    if command -v minikube &> /dev/null && minikube status | grep -q "Running"; then
        echo "Minikube détecté, configuration de l'environnement Docker pour Minikube..."
        eval $(minikube docker-env)
    fi

    (cd "$ROOT_DIR/movie-service" && docker build -q -t movie-service:1.0.0 .)
    (cd "$ROOT_DIR/ticket-service" && docker build -q -t ticket-service:1.0.0 .)
    echo -e "${GREEN}✔ Images Docker construites avec succès !${NC}"
else
    echo -e "${RED}Docker n'est pas installé, les images ne seront pas construites.${NC}"
fi

# 5. Déploiement et vérification sur Kubernetes
echo -e "\n${YELLOW}[5/5] Vérification et déploiement Kubernetes (k8s/)...${NC}"
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    
    echo "Application des manifests Kubernetes..."
    kubectl apply -f "$ROOT_DIR/k8s/"
    
    echo "Attente de la disponibilité des Pods movie..."
    kubectl rollout status deployment/movie -n cinema-exam --timeout=90s
    
    echo "Attente de la disponibilité des Pods ticket..."
    kubectl rollout status deployment/ticket -n cinema-exam --timeout=90s

    echo -e "\n${BLUE}--- État des Pods ---${NC}"
    kubectl get pods -n cinema-exam
    
    echo -e "\n${BLUE}--- État des Endpoints ---${NC}"
    kubectl get endpoints -n cinema-exam movie ticket

    echo -e "\n${GREEN}✔ Cluster et microservices opérationnels !${NC}"
else
    echo -e "${YELLOW}Cluster Kubernetes non accessible, tests unitaires Java terminés.${NC}"
fi

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}  Tout s'est exécuté avec succès !                 ${NC}"
echo -e "${GREEN}======================================================${NC}"
