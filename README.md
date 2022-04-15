# use ingress hosts INSIDE CLUSTER

## Deploy cluster:

```
minikube start --kubernetes-version=v1.22.2 --addons=ingress --cpus=4 --driver=virtualbox
```

## Enable ingress-dns plugin

```
minikube addons enable ingress-dns
```

## Add your desired domain at Core-DNS

```
kubectl edit configmap coredns -n kube-system
```

Add it after `.:53`

```
test:53 {
        errors
        cache 30
        forward . 192.168.59.137
    }
```

my final version is:

```
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        hosts {
           192.168.59.1 host.minikube.internal
           fallthrough
        }
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
    test:53 {
        errors
        cache 30
        forward . 192.168.59.137
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2022-04-15T02:23:10Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "320"
  uid: 4fd0e989-8fdc-409c-9506-b0bf9a9ab9c1
```

The IP 192.168.59.137 is the minikube IP, can be found by:

```
minikube ip
```

In case you are using profiled minikube, e.g you started minikube passing --profile the-name-of-my-profile you can find the proper IP by:


```
minikube ip --profile the-name-of-my-profile
```

## Deploy the IaC

```
kubectl apply -f iac.yml
```

## Check if deployed hosts got proper ADDRESS

```
kubectl get ingresses -n kube-system
```

If ADDRESS value is filled with minikube ip things are fine.

NOTE: it might take a few seconds to ingress get the address.


## Add hosts to /etc/hosts

To be able to use defined ingress hosts in local machine do:

```
sudo sh -c "echo '$(minikube ip)' hello-john.test hello-jane.test >> /etc/hosts"
```

## Check if DNS query returns records

```
nslookup hello-john.test $(minikube ip)
```

expected output:

```
Server:		192.168.59.137
Address:	192.168.59.137#53

Non-authoritative answer:
Name:	hello-john.test
Address: 192.168.59.137
Name:	hello-john.test
Address: 192.168.59.137
```

another one:

```
nslookup hello-jane.test $(minikube ip)
```

expected output:

```
Server:		192.168.59.137
Address:	192.168.59.137#53

Non-authoritative answer:
Name:	hello-jane.test
Address: 192.168.59.137
Name:	hello-jane.test
Address: 192.168.59.137
```

You can also try ping:

```
ping hello-john.test
```

expected response:

```
PING hello-john.test (192.168.59.137) 56(84) bytes of data.
64 bytes from hello-john.test (192.168.59.137): icmp_seq=1 ttl=64 time=0.496 ms
64 bytes from hello-john.test (192.168.59.137): icmp_seq=2 ttl=64 time=0.486 ms
64 bytes from hello-john.test (192.168.59.137): icmp_seq=3 ttl=64 time=0.399 ms
```

You can also try a curl:

```
curl http://hello-john.test
```

expected result:

```
Hello, world!
Version: 1.0.0
Hostname: hello-world-app-7b9bf45d65-clrxm
```

## Check if defined ingress hosts are visible inside of cluster

```
kubectl apply -f util.yml
```

Go inside the deployed Pod's container:

```
kubectl -n default exec -it pod/busybox /bin/sh
```

Then run:

```
nslookup hello-jane.test
```

The output is:

```
Server:		10.96.0.10
Address:	10.96.0.10#53

Non-authoritative answer:
Name:	hello-jane.test
Address: 192.168.59.137
Name:	hello-jane.test
Address: 192.168.59.137
```

Then, here is what you want:

```
curl hello-jane.test
```

expected output:

```
Hello, world!
Version: 1.0.0
Hostname: hello-world-app-7b9bf45d65-clrxm
```


## References
- [Ingress DNS](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/);



