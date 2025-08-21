#!/bin/bash

# Azure Chat App Deployment Script

set -e

echo "🚀 Starting Azure Chat App deployment..."

# Variables (update these with your values)
RESOURCE_GROUP=""
ACR_NAME=""
AKS_NAME=""
LOCATION="eastus"

# Function to check if variable is set
check_variable() {
    if [ -z "$1" ]; then
        echo "❌ Error: $2 is not set"
        exit 1
    fi
}

# Get resource names from Terraform output if available
if [ -d "infrastructure" ] && [ -f "infrastructure/terraform.tfstate" ]; then
    echo "📋 Getting resource names from Terraform output..."
    cd infrastructure
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    ACR_NAME=$(terraform output -raw acr_login_server 2>/dev/null | cut -d'.' -f1 || echo "")
    AKS_NAME=$(terraform output -raw aks_cluster_name 2>/dev/null || echo "")
    cd ..
fi

# Check if we have all required variables
if [ -z "$RESOURCE_GROUP" ] || [ -z "$ACR_NAME" ] || [ -z "$AKS_NAME" ]; then
    echo "⚠️  Could not get resource names from Terraform output."
    echo "Please set the following variables manually in this script:"
    echo "RESOURCE_GROUP='your-resource-group-name'"
    echo "ACR_NAME='your-acr-name'"
    echo "AKS_NAME='your-aks-name'"
    exit 1
fi

echo "📋 Using resources:"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   ACR Name: $ACR_NAME"
echo "   AKS Name: $AKS_NAME"

# Login to Azure (if not already logged in)
echo "🔐 Checking Azure login..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure..."
    az login
fi

# Get AKS credentials
echo "🔑 Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

# Login to ACR
echo "🐳 Logging into Azure Container Registry..."
az acr login --name $ACR_NAME

# Build and push Docker images
echo "🏗️  Building and pushing Docker images..."

# Build chat-service
echo "   Building chat-service..."
cd backend/chat-service
docker build -t $ACR_NAME.azurecr.io/chat-service:latest .
docker push $ACR_NAME.azurecr.io/chat-service:latest
cd ../..

# Build session-service
echo "   Building session-service..."
cd backend/session-service
docker build -t $ACR_NAME.azurecr.io/session-service:latest .
docker push $ACR_NAME.azurecr.io/session-service:latest
cd ../..

# Build frontend
echo "   Building frontend..."
cd frontend
docker build -t $ACR_NAME.azurecr.io/frontend:latest .
docker push $ACR_NAME.azurecr.io/frontend:latest
cd ..

# Update Kubernetes manifests with ACR name
echo "📝 Updating Kubernetes manifests..."
sed -i "s/acrchatapp.azurecr.io/$ACR_NAME.azurecr.io/g" k8s/*.yaml

# Get Azure resource information
echo "📋 Getting Azure resource information..."
cd infrastructure
OPENAI_ENDPOINT=$(terraform output -raw openai_endpoint)
OPENAI_KEY=$(terraform output -raw openai_key)
REDIS_HOSTNAME=$(terraform output -raw redis_hostname)
REDIS_KEY=$(terraform output -raw redis_primary_access_key)
cd ..

# Create Kubernetes secrets
echo "🔐 Creating Kubernetes secrets..."
kubectl create namespace azure-chat-app --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secrets if they exist
kubectl delete secret app-secrets -n azure-chat-app --ignore-not-found=true

# Create new secrets
kubectl create secret generic app-secrets -n azure-chat-app \
    --from-literal=OPENAI_ENDPOINT="$OPENAI_ENDPOINT" \
    --from-literal=OPENAI_API_KEY="$OPENAI_KEY" \
    --from-literal=REDIS_HOST="$REDIS_HOSTNAME" \
    --from-literal=REDIS_PASSWORD="$REDIS_KEY" \
    --from-literal=REDIS_PORT="6380" \
    --from-literal=REDIS_SSL="true"

# Apply Kubernetes manifests
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f k8s/

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/chat-service -n azure-chat-app
kubectl wait --for=condition=available --timeout=300s deployment/session-service -n azure-chat-app
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n azure-chat-app

# Get frontend service external IP
echo "🌐 Getting frontend service information..."
echo "Waiting for LoadBalancer IP assignment..."
kubectl get svc frontend -n azure-chat-app -w &
WATCH_PID=$!
sleep 60
kill $WATCH_PID 2>/dev/null || true

FRONTEND_IP=$(kubectl get svc frontend -n azure-chat-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📋 Application Information:"
echo "   Frontend URL: http://$FRONTEND_IP:3000"
echo "   Namespace: azure-chat-app"
echo ""
echo "🔧 Useful Commands:"
echo "   View all resources: kubectl get all -n azure-chat-app"
echo "   View logs:"
echo "     - Chat Service: kubectl logs -l app=chat-service -n azure-chat-app"
echo "     - Session Service: kubectl logs -l app=session-service -n azure-chat-app"
echo "     - Frontend: kubectl logs -l app=frontend -n azure-chat-app"
echo "   Scale services: kubectl scale deployment/frontend --replicas=3 -n azure-chat-app"
echo ""

if [ -z "$FRONTEND_IP" ]; then
    echo "⚠️  Note: LoadBalancer IP not yet assigned. Run the following command to check:"
    echo "   kubectl get svc frontend -n azure-chat-app"
fi
