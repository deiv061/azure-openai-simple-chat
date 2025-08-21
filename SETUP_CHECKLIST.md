# 🚀 Complete Setup Checklist for Azure Chat App

## ✅ Prerequisites Setup

### 1. Install Required Tools
- [ ] [Git](https://git-scm.com/downloads) - Version control
- [ ] [GitHub CLI](https://cli.github.com/) - GitHub repository management
- [ ] [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) - Azure management
- [ ] [Terraform](https://www.terraform.io/downloads.html) - Infrastructure as Code
- [ ] [Docker](https://docs.docker.com/get-docker/) - Container management
- [ ] [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes management

### 2. Azure Setup
- [ ] Azure subscription with appropriate permissions
- [ ] Azure CLI logged in: `az login`
- [ ] Verify subscription: `az account show`

## 🔧 Project Setup

### 3. Initialize Git Repository
```bash
git init
git add .
git commit -m "Initial commit: Azure Chat App with Terraform and Kubernetes"
git branch -M main
```

### 4. Create GitHub Repository
```bash
# Replace YOUR_USERNAME with your GitHub username
gh repo create azure-chat-app --public --source=. --remote=origin --push
```

## 🔐 GitHub Actions Authentication Setup

### 5. Create GitHub Environment
```bash
# Replace YOUR_USERNAME with your GitHub username
gh api --method PUT -H "Accept: application/vnd.github+json" \
  repos/YOUR_USERNAME/azure-chat-app/environments/dev
```

### 6. Create Azure Service Principal
```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "azure-chat-app-gh-actions" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID
```

**📝 Save the output:**
- [ ] Copy `appId` → This is your `AZURE_CLIENT_ID`
- [ ] Copy `tenant` → This is your `AZURE_TENANT_ID`
- [ ] Note `subscription` → This is your `AZURE_SUBSCRIPTION_ID`

### 7. Grant Additional Permissions
```bash
# Replace APP_ID with the appId from step 6
az role assignment create \
  --assignee APP_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

### 8. Create Federated Credentials
```bash
# Replace APP_ID and YOUR_USERNAME with your values
az ad app federated-credential create \
  --id APP_ID \
  --parameters '{
    "name":"github-federated",
    "issuer":"https://token.actions.githubusercontent.com",
    "subject":"repo:YOUR_USERNAME/azure-chat-app:environment:dev",
    "audiences":["api://AzureADTokenExchange"]
  }'
```

### 9. Set GitHub Secrets
```bash
# Replace values with those from step 6
gh secret set AZURE_CLIENT_ID --body "YOUR_APP_ID" --env dev
gh secret set AZURE_TENANT_ID --body "YOUR_TENANT_ID" --env dev
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env dev
```

## 🚀 Deployment Options

### Option A: GitHub Actions (Recommended)
- [ ] Push code to GitHub: `git push origin main`
- [ ] Check Actions tab in GitHub repository
- [ ] Monitor deployment progress
- [ ] Get application URL from workflow output

### Option B: Manual Deployment
- [ ] Run local deployment script:
  - Windows: `.\deploy.ps1`
  - Linux/macOS: `./deploy.sh`

## ✅ Verification Steps

### 10. Verify Deployment
- [ ] Check GitHub Actions workflow completed successfully
- [ ] Verify Azure resources in Azure Portal:
  - [ ] Resource Group created
  - [ ] AKS cluster running
  - [ ] Container Registry created
  - [ ] Azure OpenAI service deployed
  - [ ] Redis cache running

### 11. Test Application
- [ ] Get application URL: `kubectl get svc frontend -n azure-chat-app`
- [ ] Access chat application in browser
- [ ] Send test messages
- [ ] Verify AI responses
- [ ] Test message history persistence

### 12. Monitor Services
```bash
# Check all resources
kubectl get all -n azure-chat-app

# Check logs
kubectl logs -l app=chat-service -n azure-chat-app
kubectl logs -l app=session-service -n azure-chat-app
kubectl logs -l app=frontend -n azure-chat-app
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### GitHub Actions fails at Azure Login
- [ ] Verify service principal exists: `az ad sp show --id YOUR_APP_ID`
- [ ] Check federated credentials: `az ad app federated-credential list --id YOUR_APP_ID`
- [ ] Verify GitHub secrets are set correctly

#### Terraform deployment fails
- [ ] Check Azure quotas in subscription
- [ ] Verify service principal has Contributor role
- [ ] Check resource naming conflicts

#### Application not accessible
- [ ] Wait for LoadBalancer IP assignment (can take 5-10 minutes)
- [ ] Check AKS cluster status: `az aks show --name YOUR_AKS_NAME --resource-group YOUR_RG`
- [ ] Verify all pods are running: `kubectl get pods -n azure-chat-app`

#### Chat not working
- [ ] Check Azure OpenAI service status
- [ ] Verify Redis connection
- [ ] Check service logs for errors

## 🧹 Cleanup (Optional)

### To destroy all resources:

#### Option A: GitHub Actions
- [ ] Go to Actions tab → "Destroy Infrastructure" workflow
- [ ] Run workflow with confirmation "destroy"

#### Option B: Manual cleanup
```bash
# Delete Kubernetes resources
kubectl delete namespace azure-chat-app

# Destroy Terraform infrastructure
cd infrastructure
terraform destroy
```

## 📚 Additional Resources

- [ ] [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ ] [Azure OpenID Connect Setup](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [ ] [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [ ] [Azure Kubernetes Service Docs](https://docs.microsoft.com/en-us/azure/aks/)

## 🎉 Success!

Once all steps are complete, you'll have:
- ✅ Fully automated CI/CD pipeline
- ✅ Secure authentication with OIDC
- ✅ Scalable Azure infrastructure
- ✅ Production-ready chat application
- ✅ Comprehensive monitoring and logging

**Your Azure Chat App is ready for production use!** 🚀
