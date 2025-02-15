The PVC has to manually be seeded with the image.

Save this to nginx.yaml and do kubectl apply -f nginx.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template: # template for the pods
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          volumeMounts:
            - mountPath: /usr/share/nginx/xd
              name: authentik-branding
      volumes:
        - name: authentik-branding
          persistentVolumeClaim:
            claimName: authentik-branding
      restartPolicy: Always
```

Copy file into the mount on the pod, replace "nginx-7ffb5f5d7c-jhd7c" with whatever the pods name is.
k cp -n security bg12.gif nginx-7ffb5f5d7c-jhd7c:/usr/share/nginx/xd
