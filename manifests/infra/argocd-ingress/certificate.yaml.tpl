apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/component: ingress
spec:
  secretName: argocd-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - ${ARGOCD_HOST}
