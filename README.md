# Azure Service Operator v2 (ASO v2) Learning Lab

This repository is a hands-on learning lab for understanding and practicing with Azure Service Operator v2 (ASO v2). It provides comprehensive examples and documentation for deploying Azure resources declaratively using Kubernetes.

## 🎯 Learning Objectives

- ✅ Understand core concepts of Azure Service Operator v2
- ✅ Learn how ASO uses CRDs, Reconciler Patterns, API versions, and ownership semantics
- ✅ Practice building Azure resources using KRO (Kubernetes Resource Orchestrator) templates
- ✅ Deploy real Azure services (AKV, Storage, Log Analytics, AKS) using declarative YAML
- ✅ Build muscle memory for GitOps workflows using Flux/Argo + ASO

## 📚 Lab Structure

### 1. [Core Concepts](./docs/01-core-concepts.md)
Learn the fundamental concepts of ASO v2:
- Custom Resource Definitions (CRDs)
- Reconciler Patterns
- API Versions and compatibility
- Ownership semantics and resource relationships

### 2. [Prerequisites & Setup](./docs/02-prerequisites.md)
Get your environment ready:
- Azure subscription and credentials
- Kubernetes cluster setup
- ASO v2 installation
- Required CLI tools

### 3. [KRO Templates](./examples/kro-templates/)
Practice with Kubernetes Resource Orchestrator templates:
- Basic resource templates
- Composite resource patterns
- Template parameterization

### 4. [Azure Service Examples](./examples/azure-services/)
Deploy real Azure services:
- [Azure Key Vault](./examples/azure-services/key-vault/)
- [Storage Accounts](./examples/azure-services/storage/)
- [Log Analytics Workspace](./examples/azure-services/log-analytics/)
- [Azure Kubernetes Service (AKS)](./examples/azure-services/aks/)

### 5. [GitOps Workflows](./examples/gitops/)
Implement GitOps patterns:
- [Flux CD Integration](./examples/gitops/flux/)
- [Argo CD Integration](./examples/gitops/argocd/)

## 🚀 Quick Start

1. **Clone this repository**
   ```bash
   git clone https://github.com/sholaj/aso-lab.git
   cd aso-lab
   ```

2. **Review the prerequisites**
   ```bash
   cat docs/02-prerequisites.md
   ```

3. **Install ASO v2**
   Follow the installation guide in the prerequisites

4. **Start with a simple example**
   ```bash
   kubectl apply -f examples/azure-services/storage/basic-storage-account.yaml
   ```

5. **Explore GitOps workflows**
   Choose either Flux or Argo CD and follow the respective guides

## 📖 Recommended Learning Path

1. **Day 1**: Core Concepts → Prerequisites & Setup
2. **Day 2**: KRO Templates → Simple Azure Service (Storage)
3. **Day 3**: Complex Services (Key Vault, Log Analytics)
4. **Day 4**: AKS Deployment
5. **Day 5**: GitOps Workflows (Flux or Argo CD)

## 🤝 Contributing

This is a learning lab repository. Feel free to:
- Add more examples
- Improve documentation
- Share your learnings
- Report issues

## 📝 License

MIT License - Feel free to use this for learning and teaching.

## 🔗 Additional Resources

- [ASO v2 Official Documentation](https://azure.github.io/azure-service-operator/)
- [Azure Service Operator GitHub](https://github.com/Azure/azure-service-operator)
- [Kubernetes Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [GitOps Principles](https://opengitops.dev/)
