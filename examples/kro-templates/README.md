# KRO (Kubernetes Resource Orchestrator) Templates

This directory contains examples of using Kubernetes Resource Orchestrator (KRO) templates with Azure Service Operator v2.

## What is KRO?

KRO is a pattern for creating reusable, composable templates for Kubernetes resources. It allows you to:
- Define resource blueprints
- Parameterize configurations
- Create composite resources from multiple Azure services
- Implement organizational standards

## Examples in this Directory

1. [Basic Resource Template](./01-basic-template.yaml) - Simple parameterized resource
2. [Composite Resource](./02-composite-resource.yaml) - Multiple resources working together
3. [Application Stack](./03-app-stack.yaml) - Full application infrastructure
4. [Multi-Environment](./04-multi-env.yaml) - Environment-specific configurations

## Using These Templates

### Basic Usage

```bash
# Apply a template
kubectl apply -f 01-basic-template.yaml

# Customize with kustomize
kubectl apply -k ./overlays/dev/
```

### With Helm

```bash
# Package as Helm chart
helm create my-aso-chart
# Copy templates to templates/

# Install
helm install my-app my-aso-chart --set environment=dev
```

### With Flux/Argo CD

Templates work seamlessly with GitOps tools. See [../gitops/](../gitops/) for examples.

## Best Practices

1. **Use meaningful names**: Make templates self-documenting
2. **Parameterize wisely**: Not everything needs to be a parameter
3. **Document requirements**: List prerequisites and dependencies
4. **Test thoroughly**: Validate in dev before production
5. **Version control**: Keep templates in Git
