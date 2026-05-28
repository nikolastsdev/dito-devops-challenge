apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-http
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/component: ingress
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`${ARGOCD_HOST}`)
      kind: Rule
      middlewares:
        - name: redirect-https
          namespace: argocd
      services:
        - name: argocd-server
          port: 80
