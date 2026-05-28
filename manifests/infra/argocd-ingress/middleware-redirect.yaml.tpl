apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/component: ingress
spec:
  redirectScheme:
    scheme: https
    permanent: true
