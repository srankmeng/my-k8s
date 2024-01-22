## Context & User & Role
![context](/images/context.png)
---
![user & role](/images/user_role.png)
---

ดู context เริ่มต้นที่ k8s สร้างมาให้
```
kubectl config get-contexts
```

:computer: output:
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin 
```
### 1. Create User Credentials

Create a private key for user, for example `user.key`
```
openssl genrsa -out user.key 2048
```

Create a certificate sign request `user.csr` 

[Certificate Attributes](https://docs.oracle.com/cd/E50612_01/doc.11122/user_guide/content/authz_cert_attributes.html)
```
openssl req -new -key user.key -out user.csr -subj "/CN=user/O=example"
```

Generate the final certificate `user.crt` with `user.csr` and your Kubernetes cluster certificate authority (CA), location is normally `/etc/kubernetes/pki/`
```
openssl x509 -req -in user.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out user.crt -days 500
```

Now I have `user.crt`, `user.csr` and `user.key`


### 2. Config Context
Normally context config file is locate on `/etc/kubernetes/admin.conf`

We can create new context config file with `--kubeconfig <FILE>`

Set credentials
```
kubectl --kubeconfig kube-config config set-credentials user --client-key user.key --client-certificate user.crt --embed-certs=true
```

:exclamation: :exclamation: Set cluster (replace `MASTER_NODE_IP` with master node ip)
```
kubectl --kubeconfig kube-config config set-cluster user-cluster --server=https://<MASTER_NODE_IP>:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --embed-certs=true
```

Set context
```
kubectl --kubeconfig kube-config config set-context user-context --cluster user-cluster --user user
```

View config
```
kubectl --kubeconfig kube-config config view
```

:computer:  output:
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://139.59.232.158:6443
  name: user-cluster
contexts:
- context:
    cluster: user-cluster
    user: user
  name: user-context
current-context: ""
kind: Config
preferences: {}
users:
- name: user
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```
>displays only the current context
>```
>kubectl --kubeconfig kube-config config view --minify
>```
>displays only the current context & raw
>```
>kubectl --kubeconfig kube-config config view --minify --raw
>```

Or custom `kube-config` file by manual

List all contexts
```
kubectl config --kubeconfig kube-config get-contexts
```

Use target context
```
kubectl config --kubeconfig kube-config use-context user-context
```

View current context
```
kubectl config --kubeconfig kube-config current-context
```

### 3. Create role & role binding
create `role.yaml`
```
nano role.yaml
```
ตามนี้
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: user-role
  namespace: default
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```
Custom resources and apiGroups that you want, view all [resource type list](https://kubernetes.io/docs/reference/kubectl/#resource-types), view all [verbs](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#determine-the-request-verb)

create `role-binding.yaml`
```
nano role-binding.yaml
```
ตามนี้
```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: user-rolebinding
  namespace: default
subjects:
- kind: User
  name: user
  apiGroup: "rbac.authorization.k8s.io"
roleRef:
  kind: Role
  name: user-role
  apiGroup: "rbac.authorization.k8s.io"
```

apply role and role binding
```
kubectl apply -f role.yaml
kubectl apply -f role-binding.yaml
```

View pods
```
kubectl --kubeconfig kube-config get pod
```

ลอง edit deployments
```
kubectl --kubeconfig kube-config edit deployment grafana
```
:exclamation: :exclamation: เลื่อนมา แก้ replicas
```
spec:
  progressDeadlineSeconds: 600
  replicas: 1  <=== เปลี่ยนเป็น 2
  revisionHistoryLimit: 10
```
กด `esc` แล้วพิมพ์ `:wq` จะโดนเตือนว่าแก้ไม่ได้

Username info
```
kubectl --kubeconfig=kube-config auth whoami
```

Check permission
```
kubectl --kubeconfig=kube-config auth can-i get pod
```
```
kubectl --kubeconfig=kube-config auth can-i update pod
```

### 4. Create another User Credentials
Create a private key for user, for example `officer.key`
```
openssl genrsa -out officer.key 2048
```

Create a certificate sign request `officer.csr` 

[Certificate Attributes](https://docs.oracle.com/cd/E50612_01/doc.11122/user_guide/content/authz_cert_attributes.html)
```
openssl req -new -key officer.key -out officer.csr -subj "/CN=officer/O=example"
```

Generate the final certificate `officer.crt` with `officer.csr` and your Kubernetes cluster certificate authority (CA), location is normally `/etc/kubernetes/pki/`
```
openssl x509 -req -in officer.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out officer.crt -days 500
```

Now I have `officer.crt`, `officer.csr` and `officer.key`

### 5. Create another Config Context

Set credentials
```
kubectl --kubeconfig kube-config config set-credentials officer --client-key officer.key --client-certificate officer.crt --embed-certs=true
```

:exclamation: :exclamation: Set cluster (replace `MASTER_NODE_IP` with master node ip)
```
kubectl --kubeconfig kube-config config set-cluster officer-cluster --server=https://<MASTER_NODE_IP>:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --embed-certs=true
```

Set context
```
kubectl --kubeconfig kube-config config set-context officer-context --cluster officer-cluster --user officer
```

View config
```
kubectl --kubeconfig kube-config config view
```

:computer:  output:
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://139.59.232.158:6443
  name: officer-cluster
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://139.59.232.158:6443
  name: user-cluster
contexts:
- context:
    cluster: officer-cluster
    user: officer
  name: officer-context
- context:
    cluster: user-cluster
    user: user
  name: user-context
current-context: user-context
kind: Config
preferences: {}
users:
- name: officer
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
- name: user
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```
>displays only the current context
>```
>kubectl --kubeconfig kube-config config view --minify
>```
>displays only the current context & raw
>```
>kubectl --kubeconfig kube-config config view --minify --raw
>```

Or custom `kube-config` file by manual

List all contexts
```
kubectl config --kubeconfig kube-config get-contexts
```

Use target context
```
kubectl config --kubeconfig kube-config use-context officer-context
```

View current context
```
kubectl config --kubeconfig kube-config current-context
```

### 6. Create role & role binding for officer user
create `officer-role.yaml`
```
nano officer-role.yaml
```
ตามนี้
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: officer-role
  namespace: default
rules:
- apiGroups: ["", "apps"]
  resources: ["*"]
  verbs: ["*"]
```
Custom resources and apiGroups that you want, view all [resource type list](https://kubernetes.io/docs/reference/kubectl/#resource-types), view all [verbs](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#determine-the-request-verb)

create `officer-role-binding.yaml`
```
nano officer-role-binding.yaml
```
ตามนี้
```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: officer-rolebinding
  namespace: default
subjects:
- kind: User
  name: officer
  apiGroup: "rbac.authorization.k8s.io"
roleRef:
  kind: Role
  name: officer-role
  apiGroup: "rbac.authorization.k8s.io"
```

apply role and role binding
```
kubectl apply -f officer-role.yaml
kubectl apply -f officer-role-binding.yaml
```

View pods
```
kubectl --kubeconfig kube-config get pod
```

Edit deployments
```
kubectl --kubeconfig kube-config edit deployment grafana
```
:exclamation: :exclamation: เลื่อนมา แก้ replicas
```
spec:
  progressDeadlineSeconds: 600
  replicas: 1  <=== เปลี่ยนเป็น 2
  revisionHistoryLimit: 10
```
กด `esc` แล้วพิมพ์ `:wq` จะแก้ได้

View pods จะได้ grafana 2 pods
```
kubectl --kubeconfig kube-config get pod
```

Username info
```
kubectl --kubeconfig=kube-config auth whoami
```

Check permission
```
kubectl --kubeconfig=kube-config auth can-i get pod
```
```
kubectl --kubeconfig=kube-config auth can-i update pod
```

### 7. Access k8s cluster by client
Create new config file => `k-config-client` with kube-config
```
kubectl --kubeconfig kube-config config view --minify --raw > k-config-client
```
Copy `k-config-client` and paste to client machine


<br />


:technologist: Go to **client machine** then run get pod (not on master node)

> [!IMPORTANT]  
> ต้อง install kubectl ที่เครื่อง client ก่อน [link](https://kubernetes.io/docs/tasks/tools/)

```
kubectl --kubeconfig k-config-client get pod
```

---
[Reference](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)