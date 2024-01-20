## HELM & PROMETHEUS & GRAFANA

![HELM flow](/images/helm_flow.png)
---
![HELM flow apply](/images/helm_flow_apply.png)
---
### 1. Helm
Installing Helm on master node

Linux, Ubuntu
```
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```
---
![monitor diagram](/images/monitor_diagram.png)
---
### 2. Prometheus Helm Charts
Search the packages that you want on [artifacthub](https://artifacthub.io/), then run command depend on your package that you want. 

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update
```

Install Prometheus Helm Chart on Kubernetes Cluster
```
helm install prometheus prometheus-community/prometheus
```

Check output
```
kubectl get all
```
:computer: output:
```
NAME                                                     READY   STATUS    RESTARTS   AGE
pod/nginx-project-78b94b9cc8-fv6qm                       1/1     Running   0          6m28s
pod/nginx-project-78b94b9cc8-n2cfc                       1/1     Running   0          9m40s
pod/nginx-project-78b94b9cc8-q9nnq                       1/1     Running   0          9m40s
pod/prometheus-alertmanager-0                            0/1     Pending   0          87s
pod/prometheus-kube-state-metrics-745b475957-mm2b9       1/1     Running   0          88s
pod/prometheus-prometheus-node-exporter-2kwms            1/1     Running   0          88s
pod/prometheus-prometheus-node-exporter-mt6wh            1/1     Running   0          88s
pod/prometheus-prometheus-node-exporter-r74g8            1/1     Running   0          88s
pod/prometheus-prometheus-pushgateway-6574ff77bb-c8sgj   1/1     Running   0          88s
pod/prometheus-server-85b7d5fd59-jbw5p                   0/2     Pending   0          88s

NAME                                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/kubernetes                            ClusterIP   10.96.0.1        <none>        443/TCP        11m
service/nginx-project                         NodePort    10.110.146.78    <none>        80:30181/TCP   9m40s
service/prometheus-alertmanager               ClusterIP   10.102.143.120   <none>        9093/TCP       88s
service/prometheus-alertmanager-headless      ClusterIP   None             <none>        9093/TCP       88s
service/prometheus-kube-state-metrics         ClusterIP   10.103.157.192   <none>        8080/TCP       88s
service/prometheus-prometheus-node-exporter   ClusterIP   10.99.83.99      <none>        9100/TCP       88s
service/prometheus-prometheus-pushgateway     ClusterIP   10.103.129.51    <none>        9091/TCP       88s
service/prometheus-server                     ClusterIP   10.107.97.220    <none>        80/TCP         88s

NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/prometheus-prometheus-node-exporter   3         3         3       3            3           kubernetes.io/os=linux   88s

NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-project                       3/3     3            3           9m40s
deployment.apps/prometheus-kube-state-metrics       1/1     1            1           88s
deployment.apps/prometheus-prometheus-pushgateway   1/1     1            1           88s
deployment.apps/prometheus-server                   0/1     1            0           88s

NAME                                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-project-78b94b9cc8                       3         3         3       9m40s
replicaset.apps/prometheus-kube-state-metrics-745b475957       1         1         1       88s
replicaset.apps/prometheus-prometheus-pushgateway-6574ff77bb   1         1         1       88s
replicaset.apps/prometheus-server-85b7d5fd59                   1         1         0       88s

NAME                                       READY   AGE
statefulset.apps/prometheus-alertmanager   0/1     87s
```

Some resource not ready

You have to create `pv` and connect with `pvc`

Check pvc
```
kubectl get pvc
```
:computer: output:
```
NAME                                STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
prometheus-server                   Pending                                                     3m13s
storage-prometheus-alertmanager-0   Pending                                                     3m12s
```
The status is pending, then create persistent volume and bind it for each other.


<br />

### 2.1
Create `prometheus-server-pv.yaml` persistent volume for `prometheus-server` 
```
nano prometheus-server-pv.yaml
```
:exclamation: :exclamation: ตามนี้ โดยเปลี่ยน `<WORKER_NODE_NAME>` เป็นชื่อของ worker node เช่น `worker1`
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-server-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/prometheus-server-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <WORKER_NODE_NAME> <========= *** เปลี่ยนชื่อ worker node ***
```
```
kubectl apply -f prometheus-server-pv.yaml
```

<br />

>>:busts_in_silhouette: then go to the **worker node** and run 
>>```
>>mkdir /mnt/prometheus-server-data
>>```

<br />

### 2.2 ผูก pvc ของ prometheus-server กับ directory ใน worker node
Back to master node, edit pvc `prometheus-server`
```
kubectl edit pvc prometheus-server
```

:exclamation: :exclamation: เลื่อนมาล่าง ๆ เพิ่มตามนี้ โดยพิมพ์ `i`
```
...

spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: local-storage <======= add this
  volumeMode: Filesystem
  volumeName: prometheus-server-pv <======= add this
```
แก้ไขเสร็จ ก็ `esc` แล้ว `:wq` ออกมา

ตรวจสอบโดย
```
kubectl get pvc
```

:computer: output
```
NAME                                STATUS    VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS    AGE
prometheus-server                   Bound     prometheus-server-pv   10Gi       RWO            local-storage   75m
storage-prometheus-alertmanager-0   Pending                                                                    75m
```
จะเห็นว่า `prometheus-server` status จะได้เป็น `Bound`

<br />

#### 2.3
เหมือนเดิมแต่มาทำกับ `rometheus-alertmanager`=> create `prometheus-alertmanager-pv.yaml` persistent volume for `storage-prometheus-alertmanager-0 `
```
nano prometheus-alertmanager-pv.yaml
```

:exclamation: :exclamation: ตามนี้ โดยเปลี่ยน `<WORKER_NODE_NAME>` เป็นชื่อของ worker node เช่น `worker1`
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-alertmanager-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/prometheus-alertmanager-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <WORKER_NODE_NAME> <========= *** เปลี่ยนชื่อ worker node ***
```
```
kubectl apply -f prometheus-alertmanager-pv.yaml
```

<br />

>>:busts_in_silhouette: then go to the **worker node** and run 
>>```
>>mkdir /mnt/prometheus-alertmanager-data
>>```

<br />


#### 2.4 ผูก pvc ของ storage-prometheus-alertmanager กับ directory ใน worker node 

Back to master node, edit pvc `storage-prometheus-alertmanager-0`
```
kubectl edit pvc storage-prometheus-alertmanager-0
```

:exclamation: :exclamation: เลื่อนมาล่าง ๆ เพิ่มตามนี้ โดยพิมพ์ `i`
```
...

spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: local-storage <======= add this
  volumeMode: Filesystem
  volumeName: prometheus-alertmanager-pv <======= add this
```

แก้ไขเสร็จ ก็ `esc` แล้ว `:wq` ออกมา

ตรวจสอบโดย
```
kubectl get pvc
```

:computer: output
```
NAME                                STATUS    VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS    STORAGECLASS    AGE
prometheus-server                   Bound    prometheus-server-pv         10Gi       RWO            local-storage   30m
storage-prometheus-alertmanager-0   Bound    prometheus-alertmanager-pv   10Gi       RWO            local-storage   30m
```
จะเห็นว่า `prometheus-alertmanager-0` status จะได้เป็น `Bound`


Checking all
```
kubectl get all
```
:computer: output
```
NAME                                                     READY   STATUS    RESTARTS   AGE
pod/nginx-project-78b94b9cc8-fv6qm                       1/1     Running   0          36m
pod/nginx-project-78b94b9cc8-n2cfc                       1/1     Running   0          40m
pod/nginx-project-78b94b9cc8-q9nnq                       1/1     Running   0          40m
pod/prometheus-alertmanager-0                            1/1     Running   0          31m
pod/prometheus-kube-state-metrics-745b475957-mm2b9       1/1     Running   0          31m
pod/prometheus-prometheus-node-exporter-2kwms            1/1     Running   0          31m
pod/prometheus-prometheus-node-exporter-mt6wh            1/1     Running   0          31m
pod/prometheus-prometheus-node-exporter-r74g8            1/1     Running   0          31m
pod/prometheus-prometheus-pushgateway-6574ff77bb-c8sgj   1/1     Running   0          31m
pod/prometheus-server-85b7d5fd59-jbw5p                   2/2     Running   0          31m

NAME                                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/kubernetes                            ClusterIP   10.96.0.1        <none>        443/TCP        41m
service/nginx-project                         NodePort    10.110.146.78    <none>        80:30181/TCP   40m
service/prometheus-alertmanager               ClusterIP   10.102.143.120   <none>        9093/TCP       31m
service/prometheus-alertmanager-headless      ClusterIP   None             <none>        9093/TCP       31m
service/prometheus-kube-state-metrics         ClusterIP   10.103.157.192   <none>        8080/TCP       31m
service/prometheus-prometheus-node-exporter   ClusterIP   10.99.83.99      <none>        9100/TCP       31m
service/prometheus-prometheus-pushgateway     ClusterIP   10.103.129.51    <none>        9091/TCP       31m
service/prometheus-server                     ClusterIP   10.107.97.220    <none>        80/TCP         31m

NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/prometheus-prometheus-node-exporter   3         3         3       3            3           kubernetes.io/os=linux   31m

NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-project                       3/3     3            3           40m
deployment.apps/prometheus-kube-state-metrics       1/1     1            1           31m
deployment.apps/prometheus-prometheus-pushgateway   1/1     1            1           31m
deployment.apps/prometheus-server                   1/1     1            1           31m

NAME                                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-project-78b94b9cc8                       3         3         3       40m
replicaset.apps/prometheus-kube-state-metrics-745b475957       1         1         1       31m
replicaset.apps/prometheus-prometheus-pushgateway-6574ff77bb   1         1         1       31m
replicaset.apps/prometheus-server-85b7d5fd59                   1         1         1       31m

NAME                                       READY   AGE
statefulset.apps/prometheus-alertmanager   1/1     31m
```

<br />

#### 2.5
Exposing the prometheus-server Kubernetes Service
```
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-ext
```

View prometheus running port
```
kubectl get svc | grep prometheus 
```

:computer: output
```
prometheus-alertmanager               ClusterIP   10.105.61.238    <none>        9093/TCP       99m
prometheus-alertmanager-headless      ClusterIP   None             <none>        9093/TCP       99m
prometheus-kube-state-metrics         ClusterIP   10.107.162.182   <none>        8080/TCP       99m
prometheus-prometheus-node-exporter   ClusterIP   10.98.149.103    <none>        9100/TCP       99m
prometheus-prometheus-pushgateway     ClusterIP   10.107.74.80     <none>        9091/TCP       99m
prometheus-server                     ClusterIP   10.97.229.241    <none>        80/TCP         99m
prometheus-server-ext                 NodePort    10.103.252.109   <none>        80:31229/TCP   6s
```
NodePort ของ `prometheus-server-ext` คือ 31229

เข้า browser ด้วย master node ip ตามด้วย NodePort ข้างบน เช่น `139.59.232.158:31229` จะได้หน้าของ Prometheus



### 3.Grafana
Grafana Helm chart, run this command
```
helm repo add grafana https://grafana.github.io/helm-charts 
helm repo update
```

Install grafana
```
helm install grafana grafana/grafana
```

Exposing the grafana Kubernetes Service
```
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-ext
```

View grafana running port
```
kubectl get svc | grep grafana 
```

เข้า browser ด้วย master node ip ตามด้วย NodePort ข้างบน เช่น `139.59.232.158:31229` จะได้หน้าของ Grafana

Generate password
```
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Login
```
username: admin
password: <GEN_PASSWORD>
```

:exclamation: :exclamation:  Then goto grafana home and click data source box and choose `prometheus`, update `http://prometheus_url:port` เช่น `http://139.59.232.158:31229` and save


Then goto grafana home and click dashboard box
- import dashboard
- input dashboard id for example `315`
- click load button
- select prometheus data source
- click import

Grafana dashboard should appear

All done!





