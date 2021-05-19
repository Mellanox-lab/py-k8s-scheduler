# Python scheduler for Kubernetes

The goal of this project -- provide a framework to run large amount of tests (programs) 
in the Kubernetes cluster as part of Jenkins job
Initially we assumed that Jenkins by itself could schedule 1000x of tasks. But it failed.


## Checkout kubernetes-client

First of all, you need to install `kubernetes-client`

Install via PIP

     pip3 install --pre  kubernetes==17.14.0a1
 
Build from source

     git clone git@github.com:kubernetes-client/python.git k8s-python
     cd k8s-python
     git checkout v17.14.0a1
     python3 setup.py build
     sudo python3 setup.py install

## Setup kube config

Please check you have `~/.kube/config` and `kubectl get nodes` works for you

## Run a test job

First, inspect the example job  file like `job0.yaml`

    workers_num: 200
    image: harbor.mellanox.com/swx-storage/x86_64/busybox
    name: pod-spawn-test
    multiply: 1
    nodeSelector:
        beta.kubernetes.io/os: linux
        kubernetes.io/arch: amd64
    tasks:
        - "pwd"
        - "date"
        - "sleep 1; echo OK"
        - "ls -l /bin/*sh"
        - "id"
        - "false"


And try to run it on your machine:

    $ python3 pod_spawn_n.py -j job0.yaml


## Some results

The above test job is used to exstimate overhead of the scheduler and the approach to run each command in a new container.
Having  number of workers set to 100-200 and number of tasks about 6000, I got the whole batch executed in 24 minutes


    $ time python3 pod_spawn_n.py  -j job6000.yaml
    ...
    real    24m23.999s
    user    11m59.474s
    sys     0m27.964s

So, it takes about 0.225-0.244 seconds to spawn a new container (pod), execute very simple command and destroy the pod.


# Using the scheduler in Docker 
## Build/update Docker image

    docker build -t py-k8s-scheduler:20210519 -f docker/Dockerfile .
    docker tag py-k8s-scheduler:20210519 harbor.mellanox.com/swx-storage/x86_64/py-k8s-scheduler:20210519
    docker push harbor.mellanox.com/swx-storage/x86_64/py-k8s-scheduler:20210519

## Run the container

	$ cat kubernetes/test-py-k8s-pod.yaml
	apiVersion: v1
	kind: Pod
	metadata:
	  name: test-py-k8s-pod
	spec:
	  serviceAccountName: demo-sa
	  volumes:
	  - name: work-data
		hostPath:
			path: /.autodirect/rdmzsysgwork/yuriis/k8s/il-blossom/
	  containers:
	  - name:  test-py-k8s-pod-1
		# image: harbor.mellanox.com/swx-storage/x86_64/python3-kubernetes:12.0
		image: harbor.mellanox.com/swx-storage/x86_64/py-k8s-scheduler:20210519
		volumeMounts:
		- name: work-data
		  mountPath: /work
		securityContext:
		  privileged: false
		tty: true
	  hostNetwork: false
	  dnsPolicy: Default
	  nodeSelector:
		beta.kubernetes.io/os: linux
		kubernetes.io/arch: amd64

    $ kubectl apply -f kubernetes/test-py-k8s-pod.yaml
    $ kubectl exec -ti test-py-k8s-pod -- /bin/bash

## On IL-BLOSSOM

Setup RBAC

    $ kubectl apply -n swx-infra-testci -f kubernetes/create-sa.yaml
    serviceaccount/swx-infra-testci-sa configured

    $ kubectl apply -n swx-infra-testci -f kubernetes/role3-swx-infra-testci_ns.yaml
    role.rbac.authorization.k8s.io/scheduler-role created

    $ kubectl apply -n swx-infra-testci -f kubernetes/rolebind3-swx-infra-testci_ns.yaml
    rolebinding.rbac.authorization.k8s.io/blossom-swx-infra-testci-sa created

Create a pod

    $ kubectl -n swx-infra-testci apply -f kubernetes/test-pod_il-blossom.yaml
    $ kubectl -n swx-infra-testci describe pod test-py-k8s-pod
    $ kubectl -n swx-infra-testci get pods

Enter the pod and run test job

    $ kubectl -n swx-infra-testci exec -ti test-py-k8s-pod -- /bin/bash

    $ cat <<EOF > /tmp/job1.yaml
    ---
    workers_num: 3
    # image: busybox
    image: harbor.mellanox.com/swx-storage/x86_64/busybox
    name: pod-test51
    ns: swx-infra-testci
    nodeSelector:
        beta.kubernetes.io/os: linux
        kubernetes.io/arch: amd64
    tasks:
          - "date"
          - "pwd"
          - "env"
    EOF


    $ pod_thr_sched2.py -j /tmp/job1.yaml

    Worker.run: pod-test51-002 << [0] date
    Worker.run: pod-test51-000 << [1] pwd
    Worker.run: pod-test51-001 << [2] env
    pod-test51-002-000: EXEC: date
    pod-test51-000-001: EXEC: pwd
    Worker.run: pod-test51-002 << [None] None
    Worker.run: pod-test51-002 << q
    res_collector: [0] 0
    Worker.run: pod-test51-000 << [None] None
    res_collector: [1] 0
    Worker.run: pod-test51-000 << q
    pod-test51-001-002: EXEC: env
    Worker.run: pod-test51-001 << [None] None
    res_collector: [2] 0
    Worker.run: pod-test51-001 << q
    res_collector: done
    main: done
