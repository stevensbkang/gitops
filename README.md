# Terraform, FluxCD and Portainer for Kubernetes Based Setup
## Repository Structure
### infrastructure
* `coredns-config.yaml` to configure a custom DNS forwarder for my own domain
* `csi-release.yaml` to integrate with Azure Key Vault and retrieve the secrets
* `kured-release.yaml` to automatically apply OS patching for the AKS nodes every Saturday and Sunday
* `public-ingress-release.yaml` to provide ingress rules exposing HTTP/HTTPS web traffics in public
### monitoring
* `monitoring-namespace.yaml` to create a namespace including certificate and PVCs for Prometheus and Grafana
* `grafana-release.yaml` to deploy a Grafana instance with Azure AD integration, an ingress rule with Letsencrypt TLS and an existing PVC
* `loki-release.yaml` to deploy Loki  v2 with a storage account (S3 bucket version in Azure) for index and chunk persistence
* `prometheus-release` to deploy a Prometheus instance with an existing PVC
* `promtail-release.yaml` to deploy Promtail across all nodes for log collection
### portainer
* `portainer-release.yaml` to create a namespace and deploy Portainer
### terraform
* Enable AKS Managed Identity for service to:
  * Assign `AcrPull` access to an Azure Container Registry instance
  * Assign `Network Contributor` access to the AKS resource group
* Assign an Azure AD group with ClusterAdmin Role
* Authorised list of IP addresses
* A storage account for Loki indexers and chunks