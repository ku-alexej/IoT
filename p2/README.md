# Ingress

Ingress is a Kubernetes API object that manages external HTTP/HTTPS access to services running inside a cluster. Instead of exposing each service individually, Ingress lets you define routing rules (based on hostnames and URL paths) that map incoming traffic to the appropriate backend Service.

### Key points:

- Provides load balancing, SSL/TLS termination, and **name-based virtual hosting from a single entry point**.
- Requires an Ingress controller (e.g., **NGINX**, Traefik, HAProxy) to actually fulfill the rules - creating an Ingress resource alone has no effect.
- Supports routing based on **host and path**, with three path types: Exact, Prefix, and ImplementationSpecific.
- Limited to HTTP/HTTPS traffic only; other protocols require NodePort or LoadBalancer Service types.


### Minimal example:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
spec:
  ingressClassName: nginx-example
  rules:
  - http:
      paths:
      - path: /testpath
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80
```

*The Ingress API is stable but frozen - Kubernetes has the newer Gateway API.*

Full docs:
https://kubernetes.io/docs/concepts/services-networking/ingress/

### Usefull commands:
```bash
# show all Ingresses in the current namespace
kubectl get ingress

# show Ingresses in all namespaces
kubectl get ingress --all-namespaces

# show detailed information
kubectl describe ingress <ingress-name>

# show the YAML definition
kubectl get ingress <ingress-name> -o yaml

# check whether an Ingress Controller is running
kubectl get pods -A | grep -i ingress
```

```bash
kubectl get all

curl -H "Host:app2.com" 192.168.56.110
```

### For the host machine to test p2 in browser:
```bash
sudo nano /etc/hosts
# add:
#     192.168.56.110  app1.com
#     192.168.56.110  app2.com

```
Open in your browser:
- http://app1.com → "Hello from app1"
- http://app2.com → "Hello from app2"
- http://192.168.56.110 → "Hello from app3" (default backend)

```bash
vagrant reload akurochkS --provision
```
