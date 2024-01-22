## Deploy node target

### Node Selector

ดู label ทั้งหมด ของ nodes
```
kubectl get nodes --show-labels
```

Set label ที่ node
```
kubectl label nodes worker2 disktype=ssd
```
>ถ้าจะลบ label
>```
>kubectl label node worker2 disktype-
>```

ดู label อีกทีจะเห็น label ของ node มี disktype=ssd

Create nginx เตรียม deploy
```
nano nginx_node_selector.yaml
```

ตามนี้
```
apiVersion: v1
kind: Service
metadata:
  name: nginx-node-selector
spec:
  type: NodePort
  selector:
    app: nginx-node-selector
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-node-selector
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-node-selector
  template:
    metadata:
      labels:
        app: nginx-node-selector
    spec:
      containers:
        - name: nginx
          image: nginx:1.17.3
          ports:
            - containerPort: 80
      nodeSelector:
        disktype: ssd
```

apply
```
kubectl apply -f nginx_node_selector.yaml
```

ดูว่า deploy ที่ node ไหน
```
kubectl get pod -o wide
```
:computer: output:
จะเห็นว่า nginx-node-selector รันที่ node เดียวกันทั้งหมด
```
NAME                                                 READY   STATUS    RESTARTS      AGE   IP                NODE      NOMINATED NODE   READINESS GATES
nginx-node-selector-858f966495-46d44                 1/1     Running   0             6s    10.244.189.78     worker2   <none>           <none>
nginx-node-selector-858f966495-knphl                 1/1     Running   0             6s    10.244.189.79     worker2   <none>           <none>
nginx-node-selector-858f966495-m579b                 1/1     Running   0             6s    10.244.189.80     worker2   <none>           <none>
```

### affinity

ลบ อันเดิมก่อน
```
kubectl apply -f nginx_node_selector.yaml
```

Create nginx อีกอัน
```
nano nginx_affinity.yaml
```

ตามนี้
```
apiVersion: v1
kind: Service
metadata:
  name: nginx-affinity
spec:
  type: NodePort
  selector:
    app: nginx-affinity
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-affinity
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-affinity
  template:
    metadata:
      labels:
        app: nginx-affinity
    spec:
      containers:
        - name: nginx
          image: nginx:1.17.3
          ports:
            - containerPort: 80
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disktype
                operator: In
                values:
                - ssd
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: label-1
                operator: In
                values:
                - key-1
          - weight: 50
            preference:
              matchExpressions:
              - key: label-2
                operator: In
                values:
                - key-2
```

apply
```
kubectl apply -f nginx_affinity.yaml
```

#### Reference
[Operator](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators)
