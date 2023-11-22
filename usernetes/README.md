# Flux Usernetes

We are going to test deploying usernetes with Flux and [Lima](https://lima-vm.io). Instead of having different VMs to start a separate control plane and workers, we are going to have several (identical) VMs that are running Flux, one with a lead broker, and have them connect (to make a Flux instance on a single cluster) and then launch usernetes in the job. Will it work? I have no idea. Let's gooo! For installation instructions of lima see [this top level README.md](../README.md). Note that you also need the special mount type! In the steps below we will:

 - [Manual Usernetes](#manual-usernetes): setup Usernetes and Flux separately and run usernetes inside a flux broker instance (done).

Next we will do the same setup, but:

- Write the broker.toml in the VM build (it doesn't have anything changing in it)
- Do not setup usernetes manually, but instead in a batch job.

Note that for the VM builds it doesn't make it to the end, and I'm not sure why. I think I'm just bad with the probes? But the log reports exit code 0 and everything I expect is built, so likely me just being a noob.


## Semi-Automated Usernetes

### Nodes

Create two instances. If you create more than 2, you'll need to edit the [flux-usernetes.yaml](flux-usernetes.yaml)
hosts list.

```bash
limactl start --network=lima:user-v2 --name=flux-0 ./flux-usernetes.yaml
limactl start --network=lima:user-v2 --name=flux-1 ./flux-usernetes.yaml
```

You should be able to shell into each:

```bash
limactl shell --workdir /home/vanessa.linux/usernetes flux-0
limactl shell --workdir /home/vanessa.linux/usernetes flux-1
```

and sanity check that:

```
# We have the curve certificate and broker.toml
$ ls /etc/flux/system/
broker.toml  curve.cert

# flux is installed (try flux start --test-size=4)
$ which flux
/usr/bin/flux

# The hostname is lima-flux-0 or lima-flux-1
$ hostname
lima-flux-0
```

### Network

We need to get the ip addesses for each and update `/etc/hosts`

```
ip a
# look for:
inet 192.168.104.6/24
```

And then update `/etc/hosts`

```
sudo su
vim /etc/hosts
```
```
192.168.104.6  lima-flux-0
192.168.104.7  lima-flux-1
```

### Bootstrap

Start the broker on each (in different terminals)

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

And this is where we can test submitting a job that sets up usernetes.

### Batch Job with Usernetes

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

When it's done running, the volumes and containers will clean up. You're done!

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
docker compose rm
No stopped containers
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
docker compose rm
No stopped containers
```

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
limactl stop control-plane
limactl stop usernetes-worker
```

I haven't played around with restarting - likely services would need to be restarted, etc.
If you come back:

```bash
limactl start --network=lima:user-v2 control-plane
limactl start --network=lima:user-v2 usernetes-worker
```

or just nuke it!

```bash
limactl delete control-plane
limactl delete usernetes-worker
```
