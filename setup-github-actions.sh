#!/bin/bash

# GitHub Actions Setup Script for Azure Chat App (Bash version)

SUBSCRIPTION_ID=""

echo "🚀 Setting up GitHub Actions CI/CD for Azure Chat App"
echo ""

# Step 1: Initialize Git Repository (if not already done)
echo "1️⃣ Initialize Git Repository"
echo "Run these commands:"
echo "git init"
echo "git add ."
echo "git commit -m 'Initial commit: Azure Chat App with Terraform and Kubernetes'"
echo "git branch -M main"
echo "git remote add origin https://github.com/YOUR_USERNAME/azure-chat-app.git"
echo "git push -u origin main"
echo ""

# Step 2: Create GitHub Environment
echo "2️⃣ Create GitHub Environment"
echo "Run this command (replace YOUR_USERNAME and YOUR_REPO):"
echo "gh api --method PUT -H 'Accept: application/vnd.github+json' repos/YOUR_USERNAME/YOUR_REPO/environments/dev"
echo ""

# Step 3: Create Service Principal
echo "3️⃣ Create Azure Service Principal"
echo "Run this command:"
echo "az ad sp create-for-rbac --name 'azure-chat-app-gh-actions' --role Contributor --scopes /subscriptions/$SUBSCRIPTION_ID"
echo ""
echo "Save the output! You'll need:"
echo "- appId (AZURE_CLIENT_ID)"
echo "- tenant (AZURE_TENANT_ID)"
echo ""

# Step 4: Grant Additional Permissions
echo "4️⃣ Grant User Access Administrator Role"
echo "Run this command (replace APP_ID with the appId from step 3):"
echo "az role assignment create --assignee APP_ID --role 'User Access Administrator' --scope /subscriptions/$SUBSCRIPTION_ID"
echo ""

# Step 5: Create Federated Credentials
echo "5️⃣ Create Federated Credentials"
echo "Run this command (replace APP_ID, YOUR_USERNAME, and YOUR_REPO):"
echo "az ad app federated-credential create --id APP_ID --parameters '{\"name\":\"github-federated\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:YOUR_USERNAME/YOUR_REPO:environment:dev\",\"audiences\":[\"api://AzureADTokenExchange\"]}'"
echo ""

# Step 6: Set GitHub Secrets
echo "6️⃣ Set GitHub Secrets"
echo "Run these commands (replace values with those from step 3):"
echo "gh secret set AZURE_CLIENT_ID --body 'YOUR_APP_ID' --env dev"
echo "gh secret set AZURE_TENANT_ID --body 'YOUR_TENANT_ID' --env dev"
echo "gh secret set AZURE_SUBSCRIPTION_ID --body '$SUBSCRIPTION_ID' --env dev"
echo ""

echo "✅ Setup Complete! Your GitHub Actions workflow is ready."
echo ""
echo "📋 What happens when you push code:"
echo "1. Terraform deploys Azure infrastructure"
echo "2. Docker images are built and pushed to ACR"
echo "3. Application is deployed to AKS"
echo "4. You get the application URL in the workflow output"
echo ""
echo "🔗 Useful Links:"
echo "- GitHub CLI: https://cli.github.com/"
echo "- Git: https://git-scm.com/downloads"
