apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: openbao-external
  namespace: demo-dev
  labels:
    kubernetes.io/service-name: openbao-external
addressType: IPv4
ports:
  - name: http
    protocol: TCP
    port: 8200
endpoints:
  - addresses:
      - ${OPENBAO_HOST_GATEWAY}
