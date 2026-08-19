# Bonus: GitLab + Argo CD

This bonus part extends Part 3 by replacing GitHub with a **self-hosted GitLab instance**, deployed straight into the k3d cluster. Argo CD then tracks that local GitLab repository instead of an external one, giving a fully self-contained GitOps pipeline that never leaves the cluster.

## What is Argo CD?

[Argo CD](https://argo-cd.readthedocs.io/) is a **declarative, GitOps continuous delivery (CD) tool for Kubernetes**. Instead of running `kubectl apply` by hand, it constantly pulls the desired state from a Git repository and reconciles the cluster to match it.

### CI vs CD, and where Argo CD fits

- **CI (Continuous Integration)** builds, tests, and packages changes (compiling code, running tests, building an image). Argo CD does **not** do this — it has no build step.
- **CD (Continuous Delivery/Deployment)** rolls a validated change out to an environment. This is what Argo CD handles: it watches Git for changes to Kubernetes manifests and automatically applies them to the cluster.

### The GitOps model, self-hosted

In Part 3 the tracked repository lived on GitHub. Here, GitLab itself runs as a workload *inside* the k3d cluster.

Key ideas (same as Part 3, now applied to an in-cluster Git server):
- **Git is the single source of truth** — the desired state of `dev` lives in the GitLab repo, not in someone's terminal history.
- **Pull-based deployment** — Argo CD pulls from GitLab; nothing pushes credentials into the cluster from outside.
- **Self-healing & drift detection** — manual edits to a resource are detected and reverted (`selfHeal: true` in `confs/02_argocd.yaml`).
- **Automated pruning** — resources removed from Git are removed from the cluster (`prune: true`).

`confs/02_argocd.yaml` defines the Argo CD `Application` that syncs the `dev` namespace to whatever `deployment.yaml` currently holds in the GitLab repository.

## How this part is wired together

1. `scripts/01_gitlab.sh` installs GitLab into the cluster via Helm (`gitlab/gitlab` chart) and waits for its pods to become ready — this step alone can take several minutes.
2. `scripts/01_manifest_v1.sh` / `03_manifest_v2.sh` clone the GitLab repository (creating it first if it doesn't exist yet), copy either `confs/01_deployment_v1.yaml` or `confs/01_deployment_v2.yaml` into it as `deployment.yaml`, and commit/push the change.
3. Argo CD detects the new commit in GitLab and automatically deploys it into the `dev` namespace.
4. `wil-playground`, Argo CD, and GitLab are each exposed through their own Ingress rule (`confs/03_ingress.yaml`) so all three can be reached from outside the cluster.

## Quick Start

Install the required tools:

```bash
bash 00_install.sh
```

Run the main deployment script. It creates the k3d cluster, installs Argo CD, GitLab, and deploys the manifest v1 version of `wil-playground`:

```bash
bash 02_deploy.sh
```

When the deployment finishes, the script prints everything needed to access the applications:

```
>>> Setup completed successfully <<<

Application  : http://wil.akurochk.com

Argo CD UI   : http://argocd.akurochk.com
  - Username : admin
  - Password : < password for Argo CD >

GitLab       : http://gitlab.akurochk.com
  - Username : root
  - Password : < password for GitLab >
```

All three hostnames are routed through k3d's built-in Traefik ingress controller, and are automatically added to `/etc/hosts` pointing at `127.0.0.1` during `02_deploy.sh`.

## Switching the wil-playground Version

You can change the deployed version of `wil-playground` either through the GitLab UI or by running one of the following scripts, which push a new manifest to the GitLab repository:

```bash
# deploy v1
bash 01_manifest_v1.sh

# deploy v2
bash 03_manifest_v2.sh
```

> **Note:** After switching versions, Argo CD may take up to **5 minutes** to synchronize the changes automatically. You can also trigger synchronization immediately from the Argo CD UI.

## Cleaning up

```bash
# delete the k3d cluster
bash 98_delete_cluster.sh

# uninstall docker, k3d, kubectl, helm
bash 99_delete_tools.sh
```
