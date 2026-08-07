# GitLab - bonus part

Instead of GitHub, the bonus scripts install a local GitLab instance into the k3d cluster using the manifest v1 configuration.

## Script ordeer

Before RE-starting, remove any existing cluster and installed tools.

```bash
# list aff all k3d clusters
k3d cluster list

# delete cluster command
k3d cluster delete < cluster name >

# delete docker, k3d, kubectl, helm
bash 99_delete_tools.sh
```

Install the required tools:

```bash
bash 00_install.sh
```

Run the main deployment script. During execution, it automatically runs the GitLab installation script (`01_gitlab.sh`) followed by the manifest v1 deployment script (`01_manifest_v1.sh`).

```bash
bash 02_deploy.sh
```

When the deployment finishes, the script prints all the information required to access the applications:

```bash

>>> Setup completed successfully <<<

Application  : http://wil.akurochk.com

Argo CD UI   : http://argocd.akurochk.com
  - Username : admin
  - Password : < password for Argo CD >

GitLab       : http://gitlab.akurochk.com
  - Username : root
  - Password : < password ro GitLab >

```

All three hostnames are routed through k3d's built-in Traefik ingress controller, and are automatically added to `/etc/hosts` pointing at `127.0.0.1` during `02_deploy.sh`.

## Switching the wil-playground Version

You can change the deployed version of the wil-playground application either through the GitLab UI or by running one of the following scripts:

```bash

# deploy v1
bash 01_manifest_v1.sh

# deploy v2
bash 01_manifest_v2.sh

```
> **Note:** After switching versions, Argo CD may take up to **5 minutes** to synchronize the changes automatically. You can also trigger synchronization immediately from the Argo CD UI.


### TODO:

- redirection order where it is really needed:  
`2>&1 >/dev/null`  ->  `>/dev/null 2>&1`

- typos in logs

- logs description

- add sleep time to avoid errors

- add comments if logs are not enough 

- add difference between `p3` and `bonus`
