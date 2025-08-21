# OpenAI Chat App

A comprehensive web chat application with OpenAI integration, Redis caching for message history, deployed on Azure Kubernetes Service (AKS) using Terraform infrastructure as code.

## 🏗️ Architecture

The application uses a secure **internal communication pattern** with API proxy routes for optimal security and performance.

### Frontend
- **Next.js** with Tailwind CSS and TypeScript
- Responsive chat interface with modern UI
- Session management with localStorage  
- **Internal API Routes**: `/api/chat`, `/api/sessions/*` (acts as proxy to backend)
- **External LoadBalancer**: Only component exposed to internet

### Backend Services (Internal Only)
- **Chat Service** (Python/FastAPI): Handles OpenAI communication
- **Session Service** (Python/FastAPI): Manages Redis operations and message persistence
- **ClusterIP Services**: Internal-only communication within Kubernetes cluster

### Infrastructure
- **Azure Kubernetes Service (AKS)**: Container orchestration
- **Azure OpenAI**: GPT-4o-mini for chat completions  
- **Azure Cache for Redis**: Message history storage (last 20 messages per session)
- **Azure Container Registry**: Docker image storage
- **Terraform**: Infrastructure as Code

## 🔒 Security Architecture

### Internal Communication Flow
```
Internet → Frontend (LoadBalancer) → Next.js API Routes → Backend Services (ClusterIP) → Redis/OpenAI
```

**Key Security Benefits:**
- ✅ **No External Backend Exposure**: Chat and Session services are ClusterIP only
- ✅ **API Proxy Pattern**: Frontend routes proxy requests to internal services
- ✅ **CORS Eliminated**: No cross-origin requests from browser
- ✅ **Kubernetes Service Discovery**: Uses internal DNS names (`chat-service:8000`)
- ✅ **Network Isolation**: Backend services only accessible within cluster

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** installed
3. **Docker** installed
4. **kubectl** installed
5. **Node.js** (for local frontend development)
6. **Python 3.11+** (for local backend development)

### 1. Deploy Infrastructure

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### 2. Deploy Application

#### Option A: Using GitHub Actions (Recommended)
1. Follow the [GitHub Actions Setup Guide](GITHUB_ACTIONS.md)
2. Push code to your repository
3. Automatic deployment will trigger

#### Option B: Using PowerShell (Windows)
```powershell
.\deploy.ps1
```

#### Option C: Using Bash (Linux/macOS/WSL)
```bash
chmod +x deploy.sh
./deploy.sh
```

### 3. Access the Application

After deployment, get the frontend URL:

```bash
kubectl get svc frontend -n azure-chat-app
```

Access your chat application at `http://<EXTERNAL-IP>:3000`

## 🔧 Local Development

### Backend Services

#### Chat Service
```bash
cd backend/chat-service
pip install -r requirements.txt

# Set environment variables
export OPENAI_ENDPOINT="your-openai-endpoint"
export OPENAI_API_KEY="your-openai-key"
export SESSION_SERVICE_URL="http://localhost:8001"

# Run the service
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

#### Session Service
```bash
cd backend/session-service
pip install -r requirements.txt

# Set environment variables
export REDIS_HOST="your-redis-host"
export REDIS_PASSWORD="your-redis-password"
export REDIS_PORT="6380"
export REDIS_SSL="true"

# Run the service
uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

### Frontend
```bash
cd frontend
npm install

# For local development, no external service URLs needed
# API routes will communicate with local backend services

# Run development server
npm run dev
```

**Note**: In production, the frontend uses internal API routes (`/api/chat`, `/api/sessions/*`) that proxy requests to backend services. No external service configuration needed!

## 📁 Project Structure

```
azure-chat-app/
├── infrastructure/          # Terraform configuration
│   ├── main.tf             # Main infrastructure resources
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
├── backend/
│   ├── chat-service/       # OpenAI communication service
│   │   ├── main.py         # FastAPI application
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   └── session-service/    # Redis session management
│       ├── main.py         # FastAPI application
│       ├── requirements.txt
│       └── Dockerfile
├── frontend/               # Next.js frontend
│   ├── app/
│   │   ├── api/            # Internal API routes (proxy to backend)
│   │   │   ├── chat/       # Chat API proxy route
│   │   │   └── sessions/   # Session API proxy routes
│   │   ├── page.tsx        # Main chat interface
│   │   ├── layout.tsx      # App layout
│   │   └── globals.css     # Global styles
│   ├── package.json
│   ├── next.config.js
│   ├── tailwind.config.js
│   └── Dockerfile
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── chat-service.yaml
│   ├── session-service.yaml
│   └── frontend.yaml
├── deploy.sh               # Bash deployment script
├── deploy.ps1              # PowerShell deployment script
└── README.md
```

## 🔍 API Endpoints

### Frontend API Routes (External)
- `POST /api/chat` - Send message and get AI response (proxies to chat-service)
- `GET /api/sessions/{session_id}/messages` - Get conversation history (proxies to session-service)
- `DELETE /api/sessions/{session_id}` - Delete session (proxies to session-service)

### Backend Services (Internal Only - ClusterIP)

#### Chat Service (chat-service:8000)
- `GET /health` - Health check
- `POST /chat` - Send message and get AI response

#### Session Service (session-service:8001)
- `GET /health` - Health check
- `GET /sessions/{session_id}/messages` - Get conversation history
- `POST /sessions/{session_id}/messages` - Add message to session
- `GET /sessions/{session_id}/info` - Get session information
- `DELETE /sessions/{session_id}` - Delete session
- `GET /sessions` - List active sessions

**Note**: Backend services are only accessible from within the Kubernetes cluster via internal service names.

## 🛠️ Configuration

### Environment Variables

#### Chat Service (Internal)
- `OPENAI_ENDPOINT`: Azure OpenAI endpoint URL
- `OPENAI_API_KEY`: Azure OpenAI access key
- `OPENAI_DEPLOYMENT`: Model deployment name (default: gpt-4o-mini)
- `SESSION_SERVICE_URL`: Internal service URL (`http://session-service:8001`)

#### Session Service (Internal)
- `REDIS_HOST`: Redis cache hostname
- `REDIS_PASSWORD`: Redis access key
- `REDIS_PORT`: Redis SSL port (6380)
- `REDIS_SSL`: Use SSL connection (true)

#### Frontend (Production)
- `CHAT_SERVICE_URL`: Internal service URL (`http://chat-service:8000`) - used by API routes
- `SESSION_SERVICE_URL`: Internal service URL (`http://session-service:8001`) - used by API routes

**Note**: No `NEXT_PUBLIC_*` variables needed in production - frontend uses internal API routes!

### Redis Configuration
- **Max Messages**: 20 messages per session
- **Session Expiry**: 24 hours
- **SSL**: Enabled by default for Azure Cache for Redis

## 🔐 Security Features

- SSL/TLS encryption for Redis connections
- Kubernetes secrets for sensitive data
- CORS configuration for API security
- Resource limits and health checks for all services
- Azure managed identities for service authentication

## 📊 Monitoring & Logging

### View Logs
```bash
# Chat service logs
kubectl logs -l app=chat-service -n azure-chat-app

# Session service logs
kubectl logs -l app=session-service -n azure-chat-app

# Frontend logs
kubectl logs -l app=frontend -n azure-chat-app

# All services
kubectl logs -l app -n azure-chat-app
```

### Scale Services
```bash
# Scale frontend
kubectl scale deployment/frontend --replicas=3 -n azure-chat-app

# Scale backend services
kubectl scale deployment/chat-service --replicas=3 -n azure-chat-app
kubectl scale deployment/session-service --replicas=3 -n azure-chat-app
```

## 🚨 Troubleshooting

### Common Issues

1. **LoadBalancer IP not assigned**
   ```bash
   kubectl get svc frontend -n azure-chat-app -w
   ```

2. **Pod not starting**
   ```bash
   kubectl describe pod -l app=<service-name> -n azure-chat-app
   ```

3. **Check service connectivity**
   ```bash
   kubectl port-forward svc/chat-service 8000:8000 -n azure-chat-app
   kubectl port-forward svc/session-service 8001:8001 -n azure-chat-app
   ```

4. **Redis connection issues**
   - Verify Redis credentials in Kubernetes secrets
   - Check Azure Cache for Redis firewall rules
   - Ensure SSL is properly configured

### Useful Commands

```bash
# Get all resources
kubectl get all -n azure-chat-app

# Check secrets
kubectl get secrets -n azure-chat-app

# Execute into a pod
kubectl exec -it <pod-name> -n azure-chat-app -- /bin/bash

# Check resource usage
kubectl top pods -n azure-chat-app
```

## 🧹 Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace azure-chat-app

# Destroy infrastructure
cd infrastructure
terraform destroy
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 💡 Features

✅ **Implemented**
- Real-time chat with Azure OpenAI
- Message history persistence (last 20 messages)
- Session management
- Responsive UI with Tailwind CSS
- Containerized microservices
- Infrastructure as Code with Terraform
- Kubernetes deployment
- Health checks and monitoring
- Auto-scaling capabilities

🚧 **Future Enhancements**
- User authentication
- Multiple chat rooms
- File upload support
- Message encryption
- Prometheus metrics
- Database integration for persistent storage

## 🔄 CI/CD with GitHub Actions

This project includes comprehensive GitHub Actions workflows for automated deployment:

### Workflows Available
- **Deploy**: Automatic deployment on push to main/develop
- **Test**: Run tests and validation on pull requests
- **Destroy**: Manual infrastructure cleanup

### Setup GitHub Actions
1. Follow the [GitHub Actions Setup Guide](GITHUB_ACTIONS.md)
2. Configure Azure authentication with OIDC (no secrets required)
3. Push code to trigger automatic deployment

### Benefits
- **Secure**: Uses OIDC authentication (no stored secrets)
- **Automated**: Deploy on every push
- **Reliable**: Includes testing and validation
- **Scalable**: Environment-specific deployments
