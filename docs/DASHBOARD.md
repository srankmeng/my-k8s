## Dashboard UI
 - [Reference](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

### Deploying the Dashboard UI
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### Expose Dashboard Service

วิธีแรก: เข้าที่เครื่อง master node

รัน command
```
kubectl proxy 
```

เข้า url
```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

---

วิธีสอง: เข้าผ่านเครื่องอื่น

แก้ Kubernetes Dashboard Service ให้เปลี่ยนจาก type ClusterIP ไปเป็น NodePort เพื่อทำการ Expose Service ออกข้างนอก ให้เราสามารถ Access จากที่ใด ๆ ก็ได้
```
kubectl -n kubernetes-dashboard edit service kubernetes-dashboard
```

output
```
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
...
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  resourceVersion: "343478"
  selfLink: /api/v1/namespaces/kubernetes-dashboard/services/kubernetes-dashboard
  uid: 8e48f478-993d-11e7-87e0-901b0e532516
spec:
  clusterIP: 10.100.124.90
  externalTrafficPolicy: Cluster
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```
แก้ type: ClusterIP ไปเป็น type: NodePort

ลอง show Service ดูว่าที่แก้ไป 
```
kubectl -n kubernetes-dashboard get service kubernetes-dashboard
```

type จะเป็น NodePort
```
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard   NodePort   10.107.86.234   <none>        443:31707/TCP   26m
```

เอา port ที่ได้เข้าด้วย ip ของ master node `https://192.168.10.20:31707`


### Create user

create file
```
nano dashboard-user.yml
```

ข้างใน file dashboard-user.yml
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

apply dashboard-user.yml
```
kubectl apply -f dashboard-user.yml
```

### User Token
Generate token `kubectl create token <sa name>  --namespace <name>`
```
kubectl create token admin-user  --namespace kubernetes-dashboard
```


