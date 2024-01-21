## User & Role
![user & role](/images/user_role.png)
---

### 1.Create User Credentials

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

Set context
```
kubectl --kubeconfig kube-config config set-context user-context --cluster user-cluster --user user
```

:exclamation: :exclamation: Set cluster (replace `YOUR_IP` with master node ip)
```
kubectl --kubeconfig kube-config config set-cluster user-cluster --server=https://<YOUR_IP>:6443 --certificate-authority /etc/kubernetes/pki/ca.crt --embed-certs=true
```

Or custom `kube-config` file by manual

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
- apiGroups: [""]
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

View deployments
```
kubectl --kubeconfig kube-config get deployments
```
Cannot view because apiGroup deployments is "apps", So you have to custom to `apiGroups: ["", "apps"]` in `role.yaml`

Username info
```
kubectl --kubeconfig=kube-config auth whoami
```

Check permission
```
kubectl --kubeconfig=kube-config auth can-i get pod
```

### 4. Access k8s cluster by client
Create new config file => `k-config-client` with kube-config
```
kubectl --kubeconfig kube-config config view --minify --raw > k-config-client
```
Copy `k-config-client` and paste to client machine

:technologist: Run get pod on client machine
```
kubectl --kubeconfig k-config-client get pod
```

---
[Reference](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)