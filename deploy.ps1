# Azure Chat App Deployment Script for PowerShell

param(
    [string]$ResourceGroup = "",
    [string]$AcrName = "",
    [string]$AksName = "",
    [string]$Location = "westeurope"
)

Write-Host "🚀 Starting Azure Chat App deployment..." -ForegroundColor Green

# Function to check if variable is set
function Test-Variable {
    param($Value, $Name)
    if ([string]::IsNullOrEmpty($Value)) {
        Write-Host "❌ Error: $Name is not set" -ForegroundColor Red
        exit 1
    }
}

# Get resource names from Terraform output if available
if ((Test-Path "infrastructure") -and (Test-Path "infrastructure/terraform.tfstate")) {
    Write-Host "📋 Getting resource names from Terraform output..." -ForegroundColor Yellow
    Push-Location infrastructure
    try {
        $ResourceGroup = terraform output -raw resource_group_name 2>$null
        $AcrLoginServer = terraform output -raw acr_login_server 2>$null
        if ($AcrLoginServer) {
            $AcrName = $AcrLoginServer.Split('.')[0]
        }
        $AksName = terraform output -raw aks_cluster_name 2>$null
    }
    catch {
        Write-Host "Could not get Terraform outputs" -ForegroundColor Yellow
    }
    Pop-Location
}

# Check if we have all required variables
if ([string]::IsNullOrEmpty($ResourceGroup) -or [string]::IsNullOrEmpty($AcrName) -or [string]::IsNullOrEmpty($AksName)) {
    Write-Host "⚠️  Could not get resource names from Terraform output." -ForegroundColor Yellow
    Write-Host "Please run this script with parameters:" -ForegroundColor Yellow
    Write-Host ".\deploy.ps1 -ResourceGroup 'your-rg' -AcrName 'your-acr' -AksName 'your-aks'" -ForegroundColor Yellow
    exit 1
}

Write-Host "📋 Using resources:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "   ACR Name: $AcrName" -ForegroundColor Cyan
Write-Host "   AKS Name: $AksName" -ForegroundColor Cyan

# Check Azure login
Write-Host "🔐 Checking Azure login..." -ForegroundColor Yellow
try {
    az account show | Out-Null
}
catch {
    Write-Host "Please login to Azure..." -ForegroundColor Yellow
    az login
}

# Get AKS credentials
Write-Host "🔑 Getting AKS credentials..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $AksName --overwrite-existing

# Login to ACR
Write-Host "🐳 Logging into Azure Container Registry..." -ForegroundColor Yellow
az acr login --name $AcrName

# Build and push Docker images
Write-Host "🏗️  Building and pushing Docker images..." -ForegroundColor Yellow

# Build chat-service
Write-Host "   Building chat-service..." -ForegroundColor Cyan
Push-Location backend/chat-service
docker build -t "$AcrName.azurecr.io/chat-service:latest" .
docker push "$AcrName.azurecr.io/chat-service:latest"
Pop-Location

# Build session-service
Write-Host "   Building session-service..." -ForegroundColor Cyan
Push-Location backend/session-service
docker build -t "$AcrName.azurecr.io/session-service:latest" .
docker push "$AcrName.azurecr.io/session-service:latest"
Pop-Location

# Build frontend
Write-Host "   Building frontend..." -ForegroundColor Cyan
Push-Location frontend
docker build -t "$AcrName.azurecr.io/frontend:latest" .
docker push "$AcrName.azurecr.io/frontend:latest"
Pop-Location

# Update Kubernetes manifests with ACR name
Write-Host "📝 Updating Kubernetes manifests..." -ForegroundColor Yellow
Get-ChildItem k8s/*.yaml | ForEach-Object {
    (Get-Content $_.FullName) -replace 'acrchatapp\.azurecr\.io', "$AcrName.azurecr.io" | Set-Content $_.FullName
}

# Get Azure resource information
Write-Host "📋 Getting Azure resource information..." -ForegroundColor Yellow
Push-Location infrastructure
$OpenAIEndpoint = terraform output -raw openai_endpoint
$OpenAIKey = terraform output -raw openai_key
$RedisHostname = terraform output -raw redis_hostname
$RedisKey = terraform output -raw redis_primary_access_key
Pop-Location

# Create Kubernetes secrets
Write-Host "🔐 Creating Kubernetes secrets..." -ForegroundColor Yellow
kubectl create namespace azure-chat-app --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secrets if they exist
kubectl delete secret app-secrets -n azure-chat-app --ignore-not-found=true

# Create new secrets
kubectl create secret generic app-secrets -n azure-chat-app `
    --from-literal=OPENAI_ENDPOINT="$OpenAIEndpoint" `
    --from-literal=OPENAI_API_KEY="$OpenAIKey" `
    --from-literal=REDIS_HOST="$RedisHostname" `
    --from-literal=REDIS_PASSWORD="$RedisKey" `
    --from-literal=REDIS_PORT="6380" `
    --from-literal=REDIS_SSL="true"

# Apply Kubernetes manifests
Write-Host "☸️  Deploying to Kubernetes..." -ForegroundColor Yellow
kubectl apply -f k8s/

# Wait for deployments to be ready
Write-Host "⏳ Waiting for deployments to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/chat-service -n azure-chat-app
kubectl wait --for=condition=available --timeout=300s deployment/session-service -n azure-chat-app
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n azure-chat-app

# Get frontend service external IP
Write-Host "🌐 Getting frontend service information..." -ForegroundColor Yellow
Write-Host "Waiting for LoadBalancer IP assignment..." -ForegroundColor Cyan

$timeout = 60
$timer = 0
$frontendIP = ""

while ($timer -lt $timeout -and [string]::IsNullOrEmpty($frontendIP)) {
    Start-Sleep 5
    $timer += 5
    $frontendIP = kubectl get svc frontend -n azure-chat-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if (-not [string]::IsNullOrEmpty($frontendIP)) {
        break
    }
    Write-Host "." -NoNewline -ForegroundColor Cyan
}

Write-Host ""
Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Application Information:" -ForegroundColor Cyan
Write-Host "   Frontend URL: http://$frontendIP:3000" -ForegroundColor Cyan
Write-Host "   Namespace: azure-chat-app" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔧 Useful Commands:" -ForegroundColor Yellow
Write-Host "   View all resources: kubectl get all -n azure-chat-app" -ForegroundColor White
Write-Host "   View logs:" -ForegroundColor White
Write-Host "     - Chat Service: kubectl logs -l app=chat-service -n azure-chat-app" -ForegroundColor White
Write-Host "     - Session Service: kubectl logs -l app=session-service -n azure-chat-app" -ForegroundColor White
Write-Host "     - Frontend: kubectl logs -l app=frontend -n azure-chat-app" -ForegroundColor White
Write-Host "   Scale services: kubectl scale deployment/frontend --replicas=3 -n azure-chat-app" -ForegroundColor White
Write-Host ""

if ([string]::IsNullOrEmpty($frontendIP)) {
    Write-Host "⚠️  Note: LoadBalancer IP not yet assigned. Run the following command to check:" -ForegroundColor Yellow
    Write-Host "   kubectl get svc frontend -n azure-chat-app" -ForegroundColor White
}
