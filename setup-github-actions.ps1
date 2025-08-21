# GitHub Actions Setup Script for Azure Chat App

# This script sets up GitHub Actions CI/CD pipeline for the Azure Chat App
# Run these commands manually in your terminal after installing git and gh CLI

$subscriptionId = ""

Write-Host "🚀 Setting up GitHub Actions CI/CD for Azure Chat App" -ForegroundColor Green
Write-Host ""

# Step 1: Initialize Git Repository (if not already done)
Write-Host "1️⃣ Initialize Git Repository" -ForegroundColor Yellow
Write-Host "Run these commands:" -ForegroundColor Cyan
Write-Host "git init" -ForegroundColor White
Write-Host "git add ." -ForegroundColor White
Write-Host "git commit -m 'Initial commit: Azure Chat App with Terraform and Kubernetes'" -ForegroundColor White
Write-Host "git branch -M main" -ForegroundColor White
Write-Host "git remote add origin https://github.com/YOUR_USERNAME/azure-chat-app.git" -ForegroundColor White
Write-Host "git push -u origin main" -ForegroundColor White
Write-Host ""

# Step 2: Create GitHub Environment
Write-Host "2️⃣ Create GitHub Environment" -ForegroundColor Yellow
Write-Host "Run this command (replace YOUR_USERNAME and YOUR_REPO):" -ForegroundColor Cyan
Write-Host "gh api --method PUT -H 'Accept: application/vnd.github+json' repos/YOUR_USERNAME/YOUR_REPO/environments/dev" -ForegroundColor White
Write-Host ""

# Step 3: Create Service Principal
Write-Host "3️⃣ Create Azure Service Principal" -ForegroundColor Yellow
Write-Host "Run this command:" -ForegroundColor Cyan
Write-Host "az ad sp create-for-rbac --name 'azure-chat-app-gh-actions' --role Contributor --scopes /subscriptions/$subscriptionId" -ForegroundColor White
Write-Host ""
Write-Host "Save the output! You'll need:" -ForegroundColor Red
Write-Host "- appId (AZURE_CLIENT_ID)" -ForegroundColor White
Write-Host "- tenant (AZURE_TENANT_ID)" -ForegroundColor White
Write-Host ""

# Step 4: Grant Additional Permissions
Write-Host "4️⃣ Grant User Access Administrator Role" -ForegroundColor Yellow
Write-Host "Run this command (replace APP_ID with the appId from step 3):" -ForegroundColor Cyan
Write-Host "az role assignment create --assignee APP_ID --role 'User Access Administrator' --scope /subscriptions/$subscriptionId" -ForegroundColor White
Write-Host ""

# Step 5: Create Federated Credentials
Write-Host "5️⃣ Create Federated Credentials" -ForegroundColor Yellow
Write-Host "Run this command (replace APP_ID, YOUR_USERNAME, and YOUR_REPO):" -ForegroundColor Cyan
Write-Host "az ad app federated-credential create --id APP_ID --parameters '{\"name\":\"github-federated\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_USERNAME/YOUR_REPO:environment:dev\",\"audiences\":[\"api://AzureADTokenExchange\"]}'" -ForegroundColor White
Write-Host ""

# Step 6: Set GitHub Secrets
Write-Host "6️⃣ Set GitHub Secrets" -ForegroundColor Yellow
Write-Host "Run these commands (replace values with those from step 3):" -ForegroundColor Cyan
Write-Host "gh secret set AZURE_CLIENT_ID --body 'YOUR_APP_ID' --env dev" -ForegroundColor White
Write-Host "gh secret set AZURE_TENANT_ID --body 'YOUR_TENANT_ID' --env dev" -ForegroundColor White
Write-Host "gh secret set AZURE_SUBSCRIPTION_ID --body '$subscriptionId' --env dev" -ForegroundColor White
Write-Host ""

Write-Host "✅ Setup Complete! Your GitHub Actions workflow is ready." -ForegroundColor Green
Write-Host ""
Write-Host "📋 What happens when you push code:" -ForegroundColor Cyan
Write-Host "1. Terraform deploys Azure infrastructure" -ForegroundColor White
Write-Host "2. Docker images are built and pushed to ACR" -ForegroundColor White
Write-Host "3. Application is deployed to AKS" -ForegroundColor White
Write-Host "4. You get the application URL in the workflow output" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Useful Links:" -ForegroundColor Cyan
Write-Host "- GitHub CLI: https://cli.github.com/" -ForegroundColor White
Write-Host "- Git: https://git-scm.com/downloads" -ForegroundColor White
