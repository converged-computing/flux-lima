# Flux Usernetes

We are going to test deploying usernetes with Flux and [Lima](https://lima-vm.io). Instead of having different VMs to start a separate control plane and workers, we are going to have several (identical) VMs that are running Flux, one with a lead broker, and have them connect (to make a Flux instance on a single cluster) and then launch usernetes in the job. Will it work? I have no idea. Let's gooo! For installation instructions of lima see [this top level README.md](../README.md). Note that you also need the special mount type! In the steps below we will:

 - [Manual Usernetes](#manual-usernetes): setup Usernetes and Flux separately and run usernetes inside a flux broker instance (done).
 - [Semi-automated Useretes](#semiautomated-usernetes): Started via a batch job in a Flux allocation.
 
Next we will do the same setup, but:

- Write the broker.toml in the VM build (it doesn't have anything changing in it)
- Do not setup usernetes manually, but instead in a batch job.

Note that associated "one off" scripts (for other use cases) are provided in [scripts](scripts).

Note that for the VM builds it doesn't make it to the end, and I'm not sure why. I think I'm just bad with the probes? But the log reports exit code 0 and everything I expect is built, so likely me just being a noob.

## Semi-Automated Usernetes

This approach is semi-automated because we still need to start the flux broker for each node.

### Nodes

Create two instances. If you create more than 2, you'll need to edit the [flux-usernetes.yaml](flux-usernetes.yaml)
hosts list.

```bash
limactl start --network=lima:user-v2 --name=flux-0 ./flux-usernetes.yaml
limactl start --network=lima:user-v2 --name=flux-1 ./flux-usernetes.yaml
```

Note that I get this message 

```
FATA[0601] did not receive an event with the "running" status 
```

But can't narrow down the log to find some error that something didn't work! You should be able to list:

```bash
$ limactl list
NAME             STATUS     SSH                VMTYPE    ARCH      CPUS    MEMORY    DISK      DIR
default          Stopped    127.0.0.1:0        qemu      x86_64    4       4GiB      100GiB    ~/.lima/default
flux-0           Running    127.0.0.1:37091    qemu      x86_64    4       4GiB      100GiB    ~/.lima/flux-0
flux-1           Running    127.0.0.1:42509    qemu      x86_64    4       4GiB      100GiB    ~/.lima/flux-1
```

and shell into each:

```bash
limactl shell --workdir /home/vanessa.linux/usernetes flux-0
limactl shell --workdir /home/vanessa.linux/usernetes flux-1
```

#### Sanity Checks

If you choose, here are some sanity checks to ensure that everything started / is working as expected.

```
# 1. We have the curve certificate and broker.toml
$ ls /etc/flux/system/
broker.toml  curve.cert
```

And feel free to check the content.

```
# flux is installed (try flux start --test-size=4)
$ which flux
/usr/bin/flux
```

To check hostnames:

```
# The hostname is lima-flux-0 or lima-flux-1
$ hostname
lima-flux-0
```

And you should be able to reach other hosts via `<hostname>.internal`

### Bootstrap

Start the broker on each (in different terminals). 

```bash
command="flux broker --config-path /etc/flux/system/broker.toml -Stbon.fanout=256 -Slog-stderr-level=7"
limactl shell --workdir /home/vanessa.linux/usernetes flux-0 $command
limactl shell --workdir /home/vanessa.linux/usernetes flux-1 $command
```

The first terminal (after the second follower connects) should shell into an interactive
session.

```bash
Nov 22 04:18:57.864857 resource.debug[0]: reslog_cb: online event posted
Nov 22 04:18:57.865436 sched-fluxion-resource.debug[0]: resource status changed (rankset=[1] status=UP)
Nov 22 04:18:57.861593 broker.info[1]: quorum-full: quorum->run 0.206754s
vanessa@lima-flux-0:~/usernetes$ echo $FLUX_URI
local:///tmp/flux-vI20kb/local-0
```

You should see two nodes!

```bash
$ flux resource list
Nov 22 18:55:37.608721 sched-fluxion-resource.debug[0]: status_request_cb: status succeeded
Nov 22 18:55:37.608839 sched-fluxion-qmanager.debug[0]: status_request_cb: resource-status succeeded
     STATE NNODES   NCORES    NGPUS NODELIST
      free      2        8        0 lima-flux-[0-1]
 allocated      0        0        0 
      down      0        0        0 
```

Do a test job:

```bash
$ flux run -N 2 hostname
Nov 22 23:39:12.468908 sched-fluxion-qmanager.debug[0]: alloc success (queue=default id=1036479627264)
lima-flux-0
lima-flux-1
```

And this is where we can test submitting a job that sets up usernetes.

### Batch Job with Usernetes

The current idea I have is that a user can use a batch job to create their own personal usernetes cluster.
In fact, the job itself only cares about creating the cluster (and does not need to be changed). When the cluster
is created, a kubeconfig exists that the user can interact with even outside of the flux instance.
Since this design also makes it easier to test, this is what we are going to do.
You can write the contents of [batch-job.sh](batch-job.sh) into your interactive broker shell (in flux-0)
and submit:

```bash
flux batch -N 2 batch-job.sh
```

And you can watch `usernetes-job.out` to see that we list nodes.
Note that the join-command is a bit fussy, I find that sometimes it tells me containerd is not started.
We might need to work on the timing for that (it is currently my best guess).
If it works, you should see full nodes:

```console
...
make: Leaving directory '/home/vanessa.linux/usernetes'
Sleeping a bit...
No resources found in default namespace.
NAME              STATUS   ROLES           AGE     VERSION
u7s-lima-flux-0   Ready    control-plane   2m10s   v1.28.0
u7s-lima-flux-1   Ready    <none>          106s    v1.28.0
```

When the job ends (hopefully) the trap command ends to bring down the containers.
If something happens and they don't go down on each node you likely need to do it manually. 😬️

```console
docker compose down -v
 Container usernetes-node-1  Stopping
 Container usernetes-node-1  Stopped
 Container usernetes-node-1  Removing
 Container usernetes-node-1  Removed
 Volume usernetes_node-etc  Removing
 Volume usernetes_node-var  Removing
 Volume usernetes_node-opt  Removing
 Network usernetes_default  Removing
 Volume usernetes_node-etc  Removed
 Volume usernetes_node-opt  Removed
 Volume usernetes_node-var  Removed
 Network usernetes_default  Removed
docker compose down -v
 Container usernetes-node-1  Stopping
 Container usernetes-node-1  Stopped
 Container usernetes-node-1  Removing
 Container usernetes-node-1  Removed
 Volume usernetes_node-etc  Removing
 Volume usernetes_node-opt  Removing
 Volume usernetes_node-var  Removing
 Network usernetes_default  Removing
 Volume usernetes_node-etc  Removed
 Volume usernetes_node-var  Removed
 Volume usernetes_node-opt  Removed
 Network usernetes_default  Removed
```

Once your cluster is running you should be able to export the KUBECONFIG in your home,
and (regardless of being in the flux instance) interact with your cluster.

```bash
export KUBECONFIG=/home/vanessa.linux/usernetes/kubeconfig
kubectl get nodes
```
```
$ kubectl get nodes
NAME              STATUS   ROLES           AGE   VERSION
u7s-lima-flux-0   Ready    control-plane   22m   v1.28.0
u7s-lima-flux-1   Ready    <none>          22m   v1.28.0
```

### Testing Other Abstractions

Once you have your cluster running, let's test it!

#### Batch Job

We can take the basic job example from the [Kubernetes site](https://kubernetes.io/docs/concepts/workloads/controllers/job/).
I find this example especially good because it's for Pi, and tomorrow is Thanksgiving ;)

```bash
kubectl apply -f https://kubernetes.io/examples/controllers/job.yaml
kubectl get pods
kubectl describe pods
```
If all goes well, the log should show... Pi! 

```bash
$ kubectl logs pi-x9xbw
3.141592653589...
```

#### Flux Operator

Let's run Flux inside of usernetes inside of Flux!

```bash
kubectl apply -f https://raw.githubusercontent.com/flux-framework/flux-operator/main/examples/dist/flux-operator.yaml
```

<details>

<summary>Flux operator creation</summary>

```console
namespace/operator-system created
customresourcedefinition.apiextensions.k8s.io/miniclusters.flux-framework.org created
serviceaccount/operator-controller-manager created
role.rbac.authorization.k8s.io/operator-leader-election-role created
clusterrole.rbac.authorization.k8s.io/operator-manager-role created
clusterrole.rbac.authorization.k8s.io/operator-metrics-reader created
clusterrole.rbac.authorization.k8s.io/operator-proxy-role created
rolebinding.rbac.authorization.k8s.io/operator-leader-election-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/operator-manager-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/operator-proxy-rolebinding created
configmap/operator-manager-config created
service/operator-controller-manager-metrics-service created
deployment.apps/operator-controller-manager created
```

</details>

You can look at the logs of the pod in the operator namespace to see the operator running! Next try running a LAMMPS job.

```bash
kubectl get pods -n operator-system 
```

Write this into `minicluster.yaml` on flux-0.

```yaml
apiVersion: flux-framework.org/v1alpha1
kind: MiniCluster
metadata:
  name: flux-sample
spec:
  size: 2
  tasks: 2
  containers:
    - image: ghcr.io/rse-ops/lammps:flux-sched-focal
      workingDir: /home/flux/examples/reaxff/HNS
      command: lmp -v x 2 -v y 2 -v z 2 -in in.reaxc.hns -nocite
```

Apply and watch it.

```bash
kubectl apply -f ./minicluster.yaml
kubectl get pods --watch
```

You can then see the whole log. Note that (on my local machine with VMs) it did seem to take a tiny bit longer to start than I'd expect on a local machine, but that is subjective.


```bash
kubectl logs flux-sample-0-qkm85 -f
```

Behold - the ultimate turducken! _Flux inside Kubernetes (Usernetes) inside Flux_


<details>

<summary>Flux inside Kubernetes (Usernetes) inside Flux</summary>

```console
Flux username: flux

Flux install root: /usr
flux user is already added.
flux user identifiers:
uid=1234(flux) gid=1234(flux) groups=1234(flux)

As Flux prefix for flux commands: sudo -u flux -E PYTHONPATH= -E PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin -E LD_LIBRARY_PATH= -E HOME=/home/flux

👋 Hello, I'm flux-sample-0
The main host is flux-sample-0
The working directory is /home/flux/examples/reaxff/HNS, contents include:
/home/flux/examples/reaxff/HNS:
README.txt	ffield.reax.hns  log.8Mar18.reaxc.hns.g++.1
data.hns-equil	in.reaxc.hns	 log.8Mar18.reaxc.hns.g++.4
End of file listing, if you see nothing above there are no files.
flux R encode --hosts=flux-sample-[0-1] 

📦 Resources
{"version": 1, "execution": {"R_lite": [{"rank": "0-1", "children": {"core": "0-3"}}], "starttime": 0.0, "expiration": 0.0, "nodelist": ["flux-sample-[0-1]"]}}

🐸 Diagnostics: false

🦊 Independent Minister of Privilege
[exec]
allowed-users = [ "flux", "root" ]
allowed-shells = [ "/usr/libexec/flux/flux-shell" ]

🐸 Broker Configuration
# Flux needs to know the path to the IMP executable
[exec]
imp = "/usr/libexec/flux/flux-imp"

[access]
allow-guest-user = true
allow-root-owner = true

# Point to resource definition generated with flux-R(1).
[resource]
path = "/etc/flux/system/R"

[bootstrap]
curve_cert = "/etc/curve/curve.cert"
default_port = 8050
default_bind = "tcp://eth0:%p"
default_connect = "tcp://%h.flux-service.default.svc.cluster.local:%p"
hosts = [
	{ host="flux-sample-[0-1]"},
]
[archive]
dbpath = "/var/lib/flux/job-archive.sqlite"
period = "1m"
busytimeout = "50s"

# Configure the flux-sched (fluxion) scheduler policies
# The 'lonodex' match policy selects node-exclusive scheduling, and can be
# commented out if jobs may share nodes.
[sched-fluxion-qmanager]
queue-policy = "fcfs"
🧊️ State Directory:
total 0


🔒️ Working directory permissions:
total 96
-rwxrwxrwx 1 flux root  2517 May  4  2023 README.txt
-rwxrwxrwx 1 flux root 54692 May  4  2023 data.hns-equil
-rwxrwxrwx 1 flux root 13576 May  4  2023 ffield.reax.hns
-rwxrwxrwx 1 flux root   870 May  4  2023 in.reaxc.hns
-rwxrwxrwx 1 flux root  4172 May  4  2023 log.8Mar18.reaxc.hns.g++.1
-rwxrwxrwx 1 flux root  4168 May  4  2023 log.8Mar18.reaxc.hns.g++.4


✨ Curve certificate generated by helper pod
#   ****  Generated on 2023-04-26 22:54:42 by CZMQ  ****
#   ZeroMQ CURVE **Secret** Certificate
#   DO NOT PROVIDE THIS FILE TO OTHER USERS nor change its permissions.
    
metadata
    name = "flux-cert-generator"
    keygen.hostname = "flux-sample-0"
curve
    public-key = "J>w]gQGe0]C8P{S:13%xJUdLlJ9K@j<BJTj^OYB2"
    secret-key = "B$)![8bG1>cYHM@65BZrH^w#=[8x93LX.an/j4g]"
Extra command arguments are: lmp -v x 2 -v y 2 -v z 2 -in in.reaxc.hns -nocite

🌀 Submit Mode: flux start -o --config /etc/flux/config -Scron.directory=/etc/flux/system/cron.d   -Stbon.fanout=256   -Srundir=/run/flux    -Sstatedir=/var/lib/flux   -Slocal-uri=local:///run/flux/local     -Slog-stderr-level=6    -Slog-stderr-mode=local  flux submit   -N 2 -n 2 --quiet  --watch lmp -v x 2 -v y 2 -v z 2 -in in.reaxc.hns -nocite
broker.info[0]: start: none->join 0.201127ms
broker.info[0]: parent-none: join->init 0.012021ms
cron.info[0]: synchronizing cron tasks to event heartbeat.pulse
job-manager.info[0]: restart: 0 jobs
job-manager.info[0]: restart: 0 running jobs
job-manager.info[0]: restart: checkpoint.job-manager not found
broker.info[0]: rc1.0: running /etc/flux/rc1.d/01-sched-fluxion
sched-fluxion-resource.info[0]: version 0.27.0-15-gc90fbcc2
sched-fluxion-resource.warning[0]: create_reader: allowlist unsupported
sched-fluxion-resource.info[0]: populate_resource_db: loaded resources from core's resource.acquire
sched-fluxion-qmanager.info[0]: version 0.27.0-15-gc90fbcc2
broker.info[0]: rc1.0: running /etc/flux/rc1.d/02-cron
broker.info[0]: rc1.0: /etc/flux/rc1 Exited (rc=0) 0.3s
broker.info[0]: rc1-success: init->quorum 0.349188s
broker.info[0]: online: flux-sample-0 (ranks 0)
broker.info[0]: online: flux-sample-[0-1] (ranks 0-1)
broker.info[0]: quorum-full: quorum->run 0.300113s
LAMMPS (29 Sep 2021 - Update 2)
OMP_NUM_THREADS environment is not set. Defaulting to 1 thread. (src/comm.cpp:98)
  using 1 OpenMP thread(s) per MPI task
Reading data file ...
  triclinic box = (0.0000000 0.0000000 0.0000000) to (22.326000 11.141200 13.778966) with tilt (0.0000000 -5.0260300 0.0000000)
  2 by 1 by 1 MPI processor grid
  reading atoms ...
  304 atoms
  reading velocities ...
  304 velocities
  read_data CPU = 0.072 seconds
Replicating atoms ...
  triclinic box = (0.0000000 0.0000000 0.0000000) to (44.652000 22.282400 27.557932) with tilt (0.0000000 -10.052060 0.0000000)
  2 by 1 by 1 MPI processor grid
  bounding box image = (0 -1 -1) to (0 1 1)
  bounding box extra memory = 0.03 MB
  average # of replicas added to proc = 5.00 out of 8 (62.50%)
  2432 atoms
  replicate CPU = 0.072 seconds
Neighbor list info ...
  update every 20 steps, delay 0 steps, check no
  max neighbors/atom: 2000, page size: 100000
  master list distance cutoff = 11
  ghost atom cutoff = 11
  binsize = 5.5, bins = 10 5 6
  2 neighbor lists, perpetual/occasional/extra = 2 0 0
  (1) pair reax/c, perpetual
      attributes: half, newton off, ghost
      pair build: half/bin/newtoff/ghost
      stencil: full/ghost/bin/3d
      bin: standard
  (2) fix qeq/reax, perpetual, copy from (1)
      attributes: half, newton off, ghost
      pair build: copy
      stencil: none
      bin: none
Setting up Verlet run ...
  Unit style    : real
  Current step  : 0
  Time step     : 0.1
Per MPI rank memory allocation (min/avg/max) = 143.9 | 143.9 | 143.9 Mbytes
Step Temp PotEng Press E_vdwl E_coul Volume 
       0          300   -113.27833    437.52118   -111.57687   -1.7014647    27418.867 
      10    299.38517   -113.27631    1439.2824   -111.57492   -1.7013813    27418.867 
      20    300.27107   -113.27884     3764.342   -111.57762   -1.7012247    27418.867 
      30    302.21063   -113.28428    7007.6629   -111.58335   -1.7009363    27418.867 
      40    303.52265   -113.28799    9844.8245   -111.58747   -1.7005186    27418.867 
      50    301.87059   -113.28324    9663.0973   -111.58318   -1.7000523    27418.867 
      60    296.67807   -113.26777    7273.8119   -111.56815   -1.6996137    27418.867 
      70    292.19999   -113.25435    5533.5522   -111.55514   -1.6992158    27418.867 
      80    293.58677   -113.25831    5993.4438   -111.55946   -1.6988533    27418.867 
      90    300.62635   -113.27925    7202.8369   -111.58069   -1.6985592    27418.867 
     100    305.38276   -113.29357    10085.805   -111.59518   -1.6983874    27418.867 
Loop time of 73.484 on 2 procs for 100 steps with 2432 atoms

Performance: 0.012 ns/day, 2041.222 hours/ns, 1.361 timesteps/s
26.8% CPU use with 2 MPI tasks x 1 OpenMP threads

MPI task timing breakdown:
Section |  min time  |  avg time  |  max time  |%varavg| %total
---------------------------------------------------------------
Pair    | 10.646     | 11.045     | 11.444     |  12.0 | 15.03
Neigh   | 0.37693    | 0.37756    | 0.37819    |   0.1 |  0.51
Comm    | 1.5046     | 1.8875     | 2.2705     |  27.9 |  2.57
Output  | 0.23966    | 0.23985    | 0.24003    |   0.0 |  0.33
Modify  | 59.917     | 59.929     | 59.942     |   0.2 | 81.55
Other   |            | 0.005098   |            |       |  0.01

Nlocal:        1216.00 ave        1216 max        1216 min
Histogram: 2 0 0 0 0 0 0 0 0 0
Nghost:        7591.50 ave        7597 max        7586 min
Histogram: 1 0 0 0 0 0 0 0 0 1
Neighs:        432912.0 ave      432942 max      432882 min
Histogram: 1 0 0 0 0 0 0 0 0 1

Total # of neighbors = 865824
Ave neighs/atom = 356.01316
Neighbor list builds = 5
Dangerous builds not checked
Total wall time: 0:01:16
broker.info[0]: rc2.0: flux submit -N 2 -n 2 --quiet --watch lmp -v x 2 -v y 2 -v z 2 -in in.reaxc.hns -nocite Exited (rc=0) 76.7s
broker.info[0]: rc2-success: run->cleanup 1.27788m
broker.info[0]: cleanup.0: flux queue stop --quiet --all --nocheckpoint Exited (rc=0) 0.1s
broker.info[0]: cleanup.1: flux cancel --user=all --quiet --states RUN Exited (rc=0) 0.1s
broker.info[0]: cleanup.2: flux queue idle --quiet Exited (rc=0) 0.1s
broker.info[0]: cleanup-success: cleanup->shutdown 0.239601s
broker.info[0]: children-complete: shutdown->finalize 76.8874ms
broker.info[0]: rc3.0: running /etc/flux/rc3.d/01-sched-fluxion
broker.info[0]: online: flux-sample-0 (ranks 0)
broker.info[0]: rc3.0: /etc/flux/rc3 Exited (rc=0) 0.2s
broker.info[0]: rc3-success: finalize->goodbye 0.242231s
broker.info[0]: goodbye: goodbye->exit 0.043608ms
```

</details>

I can't believe that worked! Amazing!
Since we have a tiny set of resources, let's cleanup when we are done.

```bash
kubectl delete -f https://raw.githubusercontent.com/flux-framework/flux-operator/main/examples/dist/flux-operator.yaml
```

#### Pytorch Operator

Let's install the [Kubeflow training operator](https://github.com/kubeflow/training-operator) to try submitting
a pytorch machine learning job.

```bash
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.5.0"
```

Save this yaml as pytorch.yaml:

```yaml
apiVersion: "kubeflow.org/v1"
kind: "PyTorchJob"
metadata:
  name: "pytorch-dist-mnist-gloo"
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          containers:
            - name: pytorch
              image: docker.io/kubeflowkatib/pytorch-mnist-cpu:latest
              args: ["--backend", "gloo"]
    Worker:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          containers: 
            - name: pytorch
              image: docker.io/kubeflowkatib/pytorch-mnist-cpu:latest
              args: ["--backend", "gloo"]
```

Save to pytorch.yaml and apply:

```bash
kubectl apply -f pytorch.yaml
```

And check out the model running!

<details>

<summary>Mnist output</summary>

```console
$ kubectl logs pytorch-dist-mnist-gloo-master-0 -f
2023-11-23T21:59:01Z INFO     Added key: store_based_barrier_key:1 to store for rank: 0
2023-11-23T21:59:01Z INFO     Rank 0: Completed store-based barrier for key:store_based_barrier_key:1 with 2 nodes.
100.0%
100.0%
100.0%
100.0%
/usr/local/lib/python3.10/site-packages/torch/nn/parallel/__init__.py:12: UserWarning: torch.nn.parallel.DistributedDataParallelCPU is deprecated, please use torch.nn.parallel.DistributedDataParallel instead.
  warnings.warn("torch.nn.parallel.DistributedDataParallelCPU is deprecated, "
2023-11-23T21:59:11Z INFO     Train Epoch: 1 [0/60000 (0%)]	loss=2.2980
2023-11-23T21:59:11Z INFO     Reducer buckets have been rebuilt in this iteration.
2023-11-23T21:59:12Z INFO     Train Epoch: 1 [640/60000 (1%)]	loss=2.3059
2023-11-23T21:59:13Z INFO     Train Epoch: 1 [1280/60000 (2%)]	loss=2.2698
2023-11-23T21:59:14Z INFO     Train Epoch: 1 [1920/60000 (3%)]	loss=2.2623
2023-11-23T21:59:16Z INFO     Train Epoch: 1 [2560/60000 (4%)]	loss=2.2693
2023-11-23T21:59:17Z INFO     Train Epoch: 1 [3200/60000 (5%)]	loss=2.2677
2023-11-23T21:59:19Z INFO     Train Epoch: 1 [3840/60000 (6%)]	loss=2.2156
2023-11-23T21:59:22Z INFO     Train Epoch: 1 [4480/60000 (7%)]	loss=2.1947
2023-11-23T21:59:23Z INFO     Train Epoch: 1 [5120/60000 (9%)]	loss=2.1869
2023-11-23T21:59:25Z INFO     Train Epoch: 1 [5760/60000 (10%)]	loss=2.1378
2023-11-23T21:59:26Z INFO     Train Epoch: 1 [6400/60000 (11%)]	loss=2.0358
2023-11-23T21:59:28Z INFO     Train Epoch: 1 [7040/60000 (12%)]	loss=1.9699
2023-11-23T21:59:31Z INFO     Train Epoch: 1 [7680/60000 (13%)]	loss=1.8555
2023-11-23T21:59:32Z INFO     Train Epoch: 1 [8320/60000 (14%)]	loss=1.5440
2023-11-23T21:59:33Z INFO     Train Epoch: 1 [8960/60000 (15%)]	loss=1.3375
2023-11-23T21:59:35Z INFO     Train Epoch: 1 [9600/60000 (16%)]	loss=1.1917
2023-11-23T21:59:37Z INFO     Train Epoch: 1 [10240/60000 (17%)]	loss=1.2503
2023-11-23T21:59:38Z INFO     Train Epoch: 1 [10880/60000 (18%)]	loss=1.0592
2023-11-23T21:59:40Z INFO     Train Epoch: 1 [11520/60000 (19%)]	loss=1.1549
2023-11-23T21:59:41Z INFO     Train Epoch: 1 [12160/60000 (20%)]	loss=1.1678
2023-11-23T21:59:42Z INFO     Train Epoch: 1 [12800/60000 (21%)]	loss=0.9152
2023-11-23T21:59:44Z INFO     Train Epoch: 1 [13440/60000 (22%)]	loss=1.1466
2023-11-23T21:59:45Z INFO     Train Epoch: 1 [14080/60000 (23%)]	loss=0.9987
2023-11-23T21:59:46Z INFO     Train Epoch: 1 [14720/60000 (25%)]	loss=0.8237
2023-11-23T21:59:48Z INFO     Train Epoch: 1 [15360/60000 (26%)]	loss=0.9158
2023-11-23T21:59:49Z INFO     Train Epoch: 1 [16000/60000 (27%)]	loss=0.9389
2023-11-23T21:59:51Z INFO     Train Epoch: 1 [16640/60000 (28%)]	loss=1.0364
2023-11-23T21:59:52Z INFO     Train Epoch: 1 [17280/60000 (29%)]	loss=0.9512
2023-11-23T21:59:54Z INFO     Train Epoch: 1 [17920/60000 (30%)]	loss=1.0208
2023-11-23T21:59:56Z INFO     Train Epoch: 1 [18560/60000 (31%)]	loss=1.0480
2023-11-23T21:59:58Z INFO     Train Epoch: 1 [19200/60000 (32%)]	loss=0.8931
2023-11-23T21:59:59Z INFO     Train Epoch: 1 [19840/60000 (33%)]	loss=0.8314
2023-11-23T22:00:01Z INFO     Train Epoch: 1 [20480/60000 (34%)]	loss=0.7959
2023-11-23T22:00:02Z INFO     Train Epoch: 1 [21120/60000 (35%)]	loss=0.8931
2023-11-23T22:00:03Z INFO     Train Epoch: 1 [21760/60000 (36%)]	loss=0.8445
2023-11-23T22:00:05Z INFO     Train Epoch: 1 [22400/60000 (37%)]	loss=0.8577
2023-11-23T22:00:07Z INFO     Train Epoch: 1 [23040/60000 (38%)]	loss=0.8272
2023-11-23T22:00:08Z INFO     Train Epoch: 1 [23680/60000 (39%)]	loss=1.0768
2023-11-23T22:00:10Z INFO     Train Epoch: 1 [24320/60000 (41%)]	loss=0.9333
2023-11-23T22:00:12Z INFO     Train Epoch: 1 [24960/60000 (42%)]	loss=0.8143
2023-11-23T22:00:13Z INFO     Train Epoch: 1 [25600/60000 (43%)]	loss=0.7880
2023-11-23T22:00:15Z INFO     Train Epoch: 1 [26240/60000 (44%)]	loss=0.7469
2023-11-23T22:00:16Z INFO     Train Epoch: 1 [26880/60000 (45%)]	loss=0.8006
2023-11-23T22:00:18Z INFO     Train Epoch: 1 [27520/60000 (46%)]	loss=0.7839
2023-11-23T22:00:19Z INFO     Train Epoch: 1 [28160/60000 (47%)]	loss=1.0564
2023-11-23T22:00:21Z INFO     Train Epoch: 1 [28800/60000 (48%)]	loss=0.8097
2023-11-23T22:00:22Z INFO     Train Epoch: 1 [29440/60000 (49%)]	loss=0.6554
2023-11-23T22:00:23Z INFO     Train Epoch: 1 [30080/60000 (50%)]	loss=0.8464
2023-11-23T22:00:25Z INFO     Train Epoch: 1 [30720/60000 (51%)]	loss=0.5195
2023-11-23T22:00:26Z INFO     Train Epoch: 1 [31360/60000 (52%)]	loss=0.8303

...

2023-11-23T22:23:40Z INFO     Train Epoch: 10 [53760/60000 (90%)]	loss=0.2748
2023-11-23T22:23:42Z INFO     Train Epoch: 10 [54400/60000 (91%)]	loss=0.5284
2023-11-23T22:23:43Z INFO     Train Epoch: 10 [55040/60000 (92%)]	loss=0.2992
2023-11-23T22:23:45Z INFO     Train Epoch: 10 [55680/60000 (93%)]	loss=0.2807
2023-11-23T22:23:47Z INFO     Train Epoch: 10 [56320/60000 (94%)]	loss=0.2427
2023-11-23T22:23:48Z INFO     Train Epoch: 10 [56960/60000 (95%)]	loss=0.1792
2023-11-23T22:23:49Z INFO     Train Epoch: 10 [57600/60000 (96%)]	loss=0.3599
2023-11-23T22:23:51Z INFO     Train Epoch: 10 [58240/60000 (97%)]	loss=0.3039
2023-11-23T22:23:52Z INFO     Train Epoch: 10 [58880/60000 (98%)]	loss=0.2242
2023-11-23T22:23:54Z INFO     Train Epoch: 10 [59520/60000 (99%)]	loss=0.3991
2023-11-23T22:23:58Z INFO     {metricName: accuracy, metricValue: 0.8710};{metricName: loss, metricValue: 0.3519}

Using distributed PyTorch with gloo backend
Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-images-idx3-ubyte.gz
Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-images-idx3-ubyte.gz to ./data/FashionMNIST/raw/train-images-idx3-ubyte.gz
Extracting ./data/FashionMNIST/raw/train-images-idx3-ubyte.gz to ./data/FashionMNIST/raw

Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-labels-idx1-ubyte.gz
Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/train-labels-idx1-ubyte.gz to ./data/FashionMNIST/raw/train-labels-idx1-ubyte.gz
Extracting ./data/FashionMNIST/raw/train-labels-idx1-ubyte.gz to ./data/FashionMNIST/raw

Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-images-idx3-ubyte.gz
Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-images-idx3-ubyte.gz to ./data/FashionMNIST/raw/t10k-images-idx3-ubyte.gz
Extracting ./data/FashionMNIST/raw/t10k-images-idx3-ubyte.gz to ./data/FashionMNIST/raw

Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-labels-idx1-ubyte.gz
Downloading http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/t10k-labels-idx1-ubyte.gz to ./data/FashionMNIST/raw/t10k-labels-idx1-ubyte.gz
Extracting ./data/FashionMNIST/raw/t10k-labels-idx1-ubyte.gz to ./data/FashionMNIST/raw
```

So awesome! 🦃️

</details>


Note that I tried examples with more pods, and ran into [this issue](https://github.com/rootless-containers/usernetes/issues/311).
Likely if/when we want to scale we should consider this.


## Manual Usernetes

> This is no longer being used in favor of automated usernetes

Let's manually create two nodes to start (you can run these in separate terminals).
The index 0 (flux-0) will be the lead broker, and flux-1 a follower. These correspond
to hostnames lima-flux-0 and lima-flux-1, and each has their own IP address that we will 
need to derive for `/etc/hosts` in each VM.

```bash
limactl start --network=lima:user-v2 --name=flux-0 ./flux-usernetes.yaml
limactl start --network=lima:user-v2 --name=flux-1 ./flux-usernetes.yaml
```

The "user-v2" refers to the network, which you can find in `~/.lima/_config/networks.yaml`.
We can now shell in and start flux or finish the usernetes control plane.
This will eventually be done by flux, but not yet.
Note that typically usernetes would be in a home, but we aren't binding or creating one here.

```bash
# Change your home here to be your {username}.linux
limactl shell --workdir /home/vanessa.linux/usernetes flux-0
```

If you do this manually, flux-0 needs:

```bash
make up
make kubeadm-init
make install-flannel
make kubeconfig
export KUBECONFIG$HOME/kubeconfig
make join-command
echo "export KUBECONFIG=$HOME/kubeconfig" >> ~/.bashrc
```

And flux-1 needs:

```bash
# Change your home here to be your {username}.linux
limactl shell --workdir /home/vanessa.linux/usernetes flux-1
make -C ~/usernetes up kubeadm-join
```

### Manual Flux

Let's start trying to manually create a flux instance that connects the two VMs. The `/tmp/lima/broker.toml` references flux-lima-[0-1] so you'll need to get ip addresses for each vm with `ip a` and then add to the `/etc/hosts` of each VM:

```console
192.168.104.6  lima-flux-0
192.168.104.7  lima-flux-1
```

#### Lead Broker

Then shell into the flux-0

```bash
limactl shell --workdir /home/vanessa.linux/usernetes flux-0
```

And start the lead broker.

```bash
sudo chown $USER /etc/flux/system/curve.cert
brokerOptions="-Stbon.fanout=256 -Slog-stderr-level=7"
flux broker --config-path /tmp/lima/broker.toml $brokerOptions
```
```console
Nov 22 02:36:40.080343 broker.debug[0]: insmod connector-local
Nov 22 02:36:40.080479 broker.info[0]: start: none->join 0.788668ms
Nov 22 02:36:40.080575 broker.info[0]: parent-none: join->init 0.068678ms
Nov 22 02:36:40.081433 connector-local.debug[0]: allow-guest-user=true
Nov 22 02:36:40.081449 connector-local.debug[0]: allow-root-owner=true
Nov 22 02:36:40.095172 broker.debug[0]: insmod content
Nov 22 02:36:40.098541 broker.debug[0]: insmod barrier
Nov 22 02:36:40.116660 broker.debug[0]: insmod content-sqlite
Nov 22 02:36:40.119567 content-sqlite.debug[0]: /tmp/flux-EwoRJc/content.sqlite (0 objects) journal_mode=OFF synchronous=OFF
Nov 22 02:36:40.120575 content.debug[0]: content backing store: enabled content-sqlite
Nov 22 02:36:40.128957 broker.debug[0]: insmod kvs
Nov 22 02:36:40.147420 broker.debug[0]: insmod kvs-watch
Nov 22 02:36:40.182680 broker.debug[0]: insmod resource
Nov 22 02:36:40.198714 resource.debug[0]: reslog_cb: resource-init event posted
Nov 22 02:36:40.203514 broker.debug[0]: insmod cron
Nov 22 02:36:40.203852 cron.info[0]: synchronizing cron tasks to event heartbeat.pulse
Nov 22 02:36:40.210528 broker.debug[0]: insmod job-manager
Nov 22 02:36:40.210987 job-manager.debug[0]: jobtap plugin .history registered method job-manager.history.get
Nov 22 02:36:40.211196 job-manager.info[0]: restart: 0 jobs
Nov 22 02:36:40.211203 job-manager.info[0]: restart: 0 running jobs
Nov 22 02:36:40.211344 job-manager.info[0]: restart: checkpoint.job-manager not found
Nov 22 02:36:40.211356 job-manager.debug[0]: restart: max_jobid=ƒ1
Nov 22 02:36:40.227538 broker.debug[0]: insmod job-info
Nov 22 02:36:40.246082 broker.debug[0]: insmod job-list
Nov 22 02:36:40.246701 job-list.debug[0]: job_state_init_from_kvs: read 0 jobs
Nov 22 02:36:40.290943 broker.debug[0]: insmod job-ingest
Nov 22 02:36:40.291381 job-ingest.debug[0]: configuring validator with plugins=(null), args=(null) (enabled)
Nov 22 02:36:40.291685 job-ingest.debug[0]: fluid ts=1ms
Nov 22 02:36:40.304415 broker.debug[0]: insmod job-exec
Nov 22 02:36:40.305177 job-exec.debug[0]: using default shell path /usr/libexec/flux/flux-shell
Nov 22 02:36:40.305199 job-exec.debug[0]: using imp path /usr/libexec/flux/flux-imp (with helper)
Nov 22 02:36:40.312364 broker.debug[0]: insmod heartbeat
Nov 22 02:36:40.313178 broker.info[0]: rc1.0: running /etc/flux/rc1.d/01-sched-fluxion
Nov 22 02:36:40.324007 broker.debug[0]: insmod sched-fluxion-resource
Nov 22 02:36:40.324160 sched-fluxion-resource.info[0]: version 0.30.0
Nov 22 02:36:40.324219 sched-fluxion-resource.debug[0]: mod_main: resource module starting
Nov 22 02:36:40.327597 broker.debug[0]: insmod sched-fluxion-qmanager
Nov 22 02:36:40.327783 sched-fluxion-qmanager.info[0]: version 0.30.0
Nov 22 02:36:40.327839 sched-fluxion-qmanager.debug[0]: service_register
Nov 22 02:36:40.327861 sched-fluxion-qmanager.debug[0]: enforced policy (queue=default): fcfs
Nov 22 02:36:40.327868 sched-fluxion-qmanager.debug[0]: effective queue params (queue=default): default
Nov 22 02:36:40.327871 sched-fluxion-qmanager.debug[0]: effective policy params (queue=default): default
Nov 22 02:36:40.328220 broker.info[0]: rc1.0: running /etc/flux/rc1.d/02-cron
Nov 22 02:36:40.405501 broker.info[0]: rc1.0: /etc/flux/rc1 Exited (rc=0) 0.3s
Nov 22 02:36:40.405618 broker.info[0]: rc1-success: init->quorum 0.325012s
Nov 22 02:36:40.506174 broker.debug[0]: groups: broker.online=0
Nov 22 02:36:40.507277 broker.info[0]: online: lima-flux-0 (ranks 0)
Nov 22 02:36:40.509453 resource.debug[0]: reslog_cb: online event posted
```


Now on the flux-1 (first worker node) we do the same to connect.

#### Worker Broker

Then shell into the flux-1

```bash
limactl shell --workdir /home/vanessa.linux/usernetes flux-1
```

And start the follower broker:

```bash
sudo chown $USER /etc/flux/system/curve.cert
brokerOptions="-Stbon.fanout=256 -Slog-stderr-level=7"
flux broker --config-path /tmp/lima/broker.toml $brokerOptions
```

When it connects, the lead broker will appear to exit, but you are actually in the instance
and can get the URI.

```
$ echo $FLUX_URI
local:///tmp/flux-u3C8of/local-0
```

#### Usernetes

Finally, shell into the lead broker and connect to the running flux instance:

```bash
limactl shell --workdir /home/vanessa.linux/usernetes flux-0
```

You should see two nodes:

```bash
$ flux proxy local:///tmp/flux-u3C8of/local-0 bash
vanessa@lima-flux-0:~/usernetes$ flux resource list
     STATE NNODES   NCORES    NGPUS NODELIST
      free      2        8        0 lima-flux-[0-1]
 allocated      0        0        0 
      down      0        0        0 
```

Note that we are on the lead broker flux-0 which also is the control plane for usernetes.
Try exporting KUBECONFIG and then seeing if it's still working...

```bash
export KUBECONFIG=$HOME/usernetes/kubeconfig
```
```
kubectl  get nodes
NAME              STATUS   ROLES           AGE   VERSION
u7s-lima-flux-0   Ready    control-plane   90m   v1.28.0
u7s-lima-flux-1   Ready    <none>          61m   v1.28.0
```

This is great! We now know that (with manual setup) we can run usernetes inside of a flux instance.
Now we need to put these two steps together so a batch job can both setup Usernetes and still get a working
instance.

```bash
$ kubectl  get pods -n kube-system
```
```console
NAME                                      READY   STATUS    RESTARTS   AGE
coredns-5dd5756b68-7cftg                  1/1     Running   0          91m
coredns-5dd5756b68-9q8vs                  1/1     Running   0          91m
etcd-u7s-lima-flux-0                      1/1     Running   0          91m
kube-apiserver-u7s-lima-flux-0            1/1     Running   0          91m
kube-controller-manager-u7s-lima-flux-0   1/1     Running   0          91m
kube-proxy-48ndz                          1/1     Running   0          91m
kube-proxy-sml2j                          1/1     Running   0          63m
kube-scheduler-u7s-lima-flux-0            1/1     Running   0          91m
```

## Clean Up

You can stop:

```bash
limactl stop flux-0
limactl stop flux-1
```

I haven't played around with restarting - likely services would need to be restarted, etc.
If you come back:

```bash
limactl start --network=lima:user-v2 flux-0
limactl start --network=lima:user-v2 flux-1
```

or just nuke it!

```bash
limactl delete flux-0
limactl delete flux-1
```
