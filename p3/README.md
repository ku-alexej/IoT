
# Part 3: Argo CD

This part deploys a k3d cluster and installs Argo CD to continuously deploy the `wil-playground` application straight from a Git repository, following a GitOps workflow.

## What is Argo CD?

[Argo CD](https://argo-cd.readthedocs.io/) is a **declarative, GitOps continuous delivery (CD) tool for Kubernetes**. Instead of running `kubectl apply` by hand, it constantly pulls the desired state from a Git repository and reconciles the cluster to match it.

### CI vs CD, and where Argo CD fits

- **CI (Continuous Integration)** builds, tests, and packages changes (compiling code, running tests, building an image). Argo CD does **not** do this — it has no build step.
- **CD (Continuous Delivery/Deployment)** rolls a validated change out to an environment. This is what Argo CD handles: it watches Git for changes to Kubernetes manifests and automatically applies them to the cluster.

### The GitOps model

Key ideas:
- **Git is the single source of truth.** The desired state of the cluster (which image version, how many replicas, etc.) lives in a Git repository, not in someone's terminal history.
- **Pull-based deployment.** Argo CD runs *inside* the cluster and pulls from Git, rather than an external CI system pushing credentials into the cluster. This is more secure — the cluster never has to expose itself to the outside world for deployments.
- **Self-healing & drift detection.** If someone manually edits a resource with `kubectl edit`, Argo CD detects the drift from Git and can automatically revert it (`selfHeal: true` in `confs/02_argocd.yaml`).
- **Automated pruning.** If a resource is removed from Git, Argo CD deletes it from the cluster (`prune: true`).
- **Auditable history.** Every deployment is just a Git commit, so `git log` becomes the deployment history.

In this project, `confs/02_argocd.yaml` defines an Argo CD `Application` resource that points at this repository (`ku-alexej/akurochk-Inception-of-Things`) and continuously syncs the `dev` namespace to whatever `deployment.yaml` currently contains.

## How this part is wired together

1. `scripts/01_manifest_v1.sh` / `03_manifest_v2.sh` clone the Git repository, copy either `confs/01_deployment_v1.yaml` or `confs/01_deployment_v2.yaml` into it as `deployment.yaml`, and commit/push the change. This simulates a developer merging a new version.
2. Argo CD, running in the cluster, detects the new commit and automatically deploys it into the `dev` namespace — no manual `kubectl apply` needed after the initial setup.
3. `wil-playground` is exposed through an Ingress (`confs/03_ingress.yaml`) so the currently deployed version can be checked from outside the cluster.

## Quick Start

Install the required tools:

```bash
bash 00_install.sh
```

Run the main deployment script. It creates the k3d cluster, installs Argo CD, and deploys the manifest v1 version of `wil-playground`:

```bash
bash 02_deploy.sh
```

When the deployment finishes, the script prints everything needed to access the applications:

```
>>> Setup completed successfully <<<

Application  : http://wil.akurochk.com
Argo CD UI   : http://argocd.akurochk.com

Credentials
  - Username : admin
  - Password : < password for Argo CD >
```

Both hostnames are routed through k3d's built-in Traefik ingress controller, and are automatically added to `/etc/hosts` pointing at `127.0.0.1` during `02_deploy.sh`.

## Switching the wil-playground Version

You can change the deployed version of `wil-playground` either through the Argo CD UI or by running one of the following scripts, which push a new manifest to the tracked Git repository:

```bash
# deploy v1
bash 01_manifest_v1.sh

# deploy v2
bash 03_manifest_v2.sh
```

> **Note:** After switching versions, Argo CD may take up to **5 minutes** to detect and sync the change automatically. You can also trigger a sync immediately from the Argo CD UI.

## Cleaning up

```bash
# delete the k3d cluster
bash 98_delete_cluster.sh

# uninstall docker, k3d, kubectl
bash 99_delete_tools.sh
```