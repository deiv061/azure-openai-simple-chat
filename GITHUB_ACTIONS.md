# GitHub Actions CI/CD Setup

This document explains how to set up GitHub Actions for automated deployment of the Azure Chat App.

## 🏗️ Workflow Overview

The CI/CD pipeline consists of three main workflows:

### 1. **Deploy Workflow** (`.github/workflows/deploy.yml`)
- **Triggers**: Push to `main` or `develop` branches, manual dispatch
- **Actions**:
  - Azure login with OIDC (no secrets required)
  - Deploy infrastructure with Terraform
  - Build and push Docker images to ACR
  - Deploy to AKS with kubectl
  - Output application URL

### 2. **Test Workflow** (`.github/workflows/test.yml`)
- **Triggers**: Pull requests, push to `develop`
- **Actions**:
  - Test backend services (Python)
  - Test frontend (Node.js)
  - Validate Terraform configuration
  - Code linting and formatting

### 3. **Destroy Workflow** (`.github/workflows/destroy.yml`)
- **Triggers**: Manual dispatch only (with confirmation)
- **Actions**:
  - Delete Kubernetes resources
  - Destroy Terraform infrastructure
  - Complete cleanup

## 🚀 Setup Instructions

### Prerequisites
1. Install [Git](https://git-scm.com/downloads)
2. Install [GitHub CLI](https://cli.github.com/)
3. Have an Azure subscription with appropriate permissions

### Step 1: Create GitHub Repository

```bash
# Initialize git repository
git init
git add .
git commit -m "Initial commit: Azure Chat App with Terraform and Kubernetes"
git branch -M main

# Create GitHub repository (replace YOUR_USERNAME)
gh repo create azure-chat-app --public --source=. --remote=origin --push
```

### Step 2: Create GitHub Environment

```bash
# Replace YOUR_USERNAME with your GitHub username
gh api --method PUT -H "Accept: application/vnd.github+json" \
  repos/YOUR_USERNAME/azure-chat-app/environments/dev
```

### Step 3: Create Azure Service Principal

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "azure-chat-app-gh-actions" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID
```

**Save the output!** You'll need:
- `appId` → `AZURE_CLIENT_ID`
- `tenant` → `AZURE_TENANT_ID`

### Step 4: Grant Additional Permissions

```bash
# Replace APP_ID with the appId from step 3
az role assignment create \
  --assignee APP_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

### Step 5: Create Federated Credentials

```bash
# Replace APP_ID, YOUR_USERNAME, and azure-chat-app with your values
az ad app federated-credential create \
  --id APP_ID \
  --parameters '{
    "name":"github-federated",
    "issuer":"https://token.actions.githubusercontent.com",
    "subject":"repo:YOUR_USERNAME/azure-chat-app:environment:dev",
    "audiences":["api://AzureADTokenExchange"]
  }'
```

### Step 6: Set GitHub Secrets

```bash
# Replace values with those from step 3
gh secret set AZURE_CLIENT_ID --body "YOUR_APP_ID" --env dev
gh secret set AZURE_TENANT_ID --body "YOUR_TENANT_ID" --env dev
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --env dev
```

## 🔧 Configuration

### Environment Variables

The workflows use these environment variables:

- `AZURE_LOCATION`: Azure region (default: eastus)
- `RESOURCE_GROUP_PREFIX`: Prefix for resource group name
- `ACR_NAME_PREFIX`: Prefix for container registry name

### Secrets (Automatically Set)

- `AZURE_CLIENT_ID`: Service principal application ID
- `AZURE_TENANT_ID`: Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

## 🔄 Deployment Process

### Automatic Deployment

1. **Push to `main` branch**: Triggers full deployment
2. **Push to `develop` branch**: Triggers deployment to dev environment
3. **Pull Request**: Triggers tests and validation only

### Manual Deployment

1. Go to **Actions** tab in your GitHub repository
2. Select **Deploy Azure Chat App** workflow
3. Click **Run workflow**
4. Choose branch and click **Run workflow**

### Manual Cleanup

1. Go to **Actions** tab in your GitHub repository
2. Select **Destroy Infrastructure** workflow
3. Click **Run workflow**
4. Type `destroy` in the confirmation field
5. Click **Run workflow**

## 📋 Workflow Steps Explained

### Deploy Workflow Steps

1. **Checkout code**: Downloads repository content
2. **Azure Login**: Authenticates using OIDC (no secrets stored)
3. **Setup Terraform**: Installs Terraform CLI
4. **Terraform Init/Plan/Apply**: Deploys Azure infrastructure
5. **ACR Login**: Authenticates to Azure Container Registry
6. **Build Images**: Builds Docker images for all services
7. **Push Images**: Pushes images to ACR with git SHA and latest tags
8. **AKS Deploy**: Deploys application to Kubernetes cluster
9. **Get URL**: Outputs the application URL

### Security Features

- **OIDC Authentication**: No long-lived secrets stored
- **Environment Protection**: Requires manual approval for production
- **Least Privilege**: Service principal has minimal required permissions
- **Federated Credentials**: GitHub-specific authentication

## 🐛 Troubleshooting

### Common Issues

1. **Workflow fails at Azure Login**
   - Verify OIDC setup is correct
   - Check service principal has correct permissions
   - Ensure federated credentials subject matches your repo

2. **Terraform fails**
   - Check Azure resource quotas
   - Verify service principal has Contributor role
   - Check if resource names are unique

3. **Docker build fails**
   - Check Dockerfiles are valid
   - Verify all dependencies are listed

4. **Kubernetes deployment fails**
   - Check AKS cluster is running
   - Verify ACR integration with AKS
   - Check Kubernetes manifests are valid

### Useful Commands

```bash
# Check workflow runs
gh run list

# View workflow logs
gh run view <run-id>

# Check service principal
az ad sp show --id <app-id>

# Check federated credentials
az ad app federated-credential list --id <app-id>

# Check GitHub secrets
gh secret list --env dev
```

## 🔗 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/)

## 📧 Support

If you encounter issues:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review workflow logs in GitHub Actions
3. Check Azure portal for resource status
4. Verify all prerequisites are met
