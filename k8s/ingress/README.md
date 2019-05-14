```
# init setup
kubectl apply -f mandatory.yaml
kubectl apply -f service-nodeport.yaml
```

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/cloud-generic.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml
using nodeport

kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch

```
#view version
POD_NAMESPACE=ingress-nginx
POD_NAME=$(kubectl get pods -n $POD_NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller --version
```

upgrade

kubectl set image deployment/nginx-ingress-controller \
  nginx-ingress-controller=nginx:quay.io/kubernetes-ingress-controller/nginx-ingress-controller:xxx