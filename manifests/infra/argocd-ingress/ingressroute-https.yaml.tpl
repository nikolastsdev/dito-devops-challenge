apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-https
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/component: ingress
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`${ARGOCD_HOST}`)
      kind: Rule
      services:
        - name: argocd-server
          port: 80
          scheme: http
  tls:
    secretName: argocd-tls
