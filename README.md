# IoT — Kubernetes & GitOps

Infrastructure project focused on Kubernetes, container orchestration, networking and GitOps.

The project progressively builds a Kubernetes environment from virtual machines to an automated GitOps workflow.

## Parts

### [Part 1 — K3s & Vagrant](./p1/)

Set up a lightweight Kubernetes cluster using:

* Vagrant
* VirtualBox
* Debian
* K3s
* Kubernetes

Two virtual machines are configured as a control-plane and worker node.

### [Part 2 — Ingress](./p2/)

Introduction to Kubernetes networking and HTTP routing using:

* Kubernetes Ingress
* Ingress Controller
* Services
* Host/path-based routing

### [Part 3 — GitOps](./p3/)

Automated Kubernetes deployment using:

* k3d
* Argo CD
* Git
* Kubernetes manifests

Git acts as the source of truth, while Argo CD continuously synchronizes the cluster with the desired state.

### [Bonus — Self-hosted GitOps](./bonus/)

Extended GitOps environment with:

* GitLab
* Argo CD
* k3d
* Traefik
* Helm

GitLab and Argo CD run inside the Kubernetes environment, creating a self-contained GitOps workflow.

## Technologies

**Infrastructure:** Vagrant, VirtualBox, Debian, k3d
**Kubernetes:** K3s, Kubernetes, Ingress, Services, Deployments
**GitOps:** Argo CD, Git, GitLab
**Networking:** Traefik, Ingress
**Automation:** Bash, Helm

## Project Structure

```text
IoT/
├── p1/       # K3s + Vagrant
├── p2/       # Kubernetes Ingress
├── p3/       # GitOps + Argo CD
└── bonus/    # GitLab + Argo CD + Traefik
```

## Key Concepts

* Kubernetes cluster provisioning
* Container orchestration
* Kubernetes networking
* Ingress and service routing
* Declarative infrastructure
* GitOps
* Continuous reconciliation
* Configuration drift detection
* Self-hosted deployment infrastructure
