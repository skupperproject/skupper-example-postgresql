<!-- NOTE: This file is generated from skewer.yaml.  Do not edit it directly. -->

# Sharing a PostgreSQL database across clusters

[![main](https://github.com/fgiorgetti/skupper-example-postgresql/actions/workflows/main.yaml/badge.svg)](https://github.com/fgiorgetti/skupper-example-postgresql/actions/workflows/main.yaml)

#### This tutorial demonstrates how to share a PostgreSQL database across multiple Kubernetes clusters that are located in different public and private cloud providers.

This example is part of a [suite of examples][examples] showing the
different ways you can use [Skupper][website] to connect services
across cloud providers, data centers, and edge sites.

[website]: https://skupper.io/
[examples]: https://skupper.io/examples/index.html

#### Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Step 1: Access your Kubernetes clusters](#step-1-access-your-kubernetes-clusters)
* [Step 2: Install Skupper on your Kubernetes clusters](#step-2-install-skupper-on-your-kubernetes-clusters)
* [Step 3: Create your Kubernetes namespaces](#step-3-create-your-kubernetes-namespaces)
* [Step 4: Set up the demo](#step-4-set-up-the-demo)
* [Step 5: Create your sites](#step-5-create-your-sites)
* [Step 6: Link your sites](#step-6-link-your-sites)
* [Step 7: Deploy the PostgreSQL service](#step-7-deploy-the-postgresql-service)
* [Step 8: Expose the PostgreSQL on the Virtual Application Network](#step-8-expose-the-postgresql-on-the-virtual-application-network)
* [Step 9: Making the PostgreSQL database accessible to the public sites](#step-9-making-the-postgresql-database-accessible-to-the-public-sites)
* [Step 10: Create pod with PostgreSQL client utilities](#step-10-create-pod-with-postgresql-client-utilities)
* [Step 11: Create a database, a table and insert values](#step-11-create-a-database-a-table-and-insert-values)
* [Step 12: Access the product table from any site](#step-12-access-the-product-table-from-any-site)
* [Cleaning up](#cleaning-up)
* [Summary](#summary)
* [Next steps](#next-steps)
* [About this example](#about-this-example)

## Overview

In this tutorial, you will create a Virtual Application Nework that enables communications across the public and private clusters.
You will then deploy a PostgreSQL database instance to a private cluster and attach it to the Virtual Application Network.
This will enable clients on different public clusters attached to the Virtual Application Nework to transparently access the database
without the need for additional networking setup (e.g. no vpn or sdn required).

## Prerequisites

* Access to at least one Kubernetes cluster, from [any provider you
  choose][kube-providers].

* The `kubectl` command-line tool, version 1.15 or later
  ([installation guide][install-kubectl]).

[kube-providers]: https://skupper.io/start/kubernetes.html
[install-kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/

The basis for the demonstration is to depict the operation of a PostgreSQL database in a private cluster and the ability to access the
database from clients resident on other public clusters. As an example, the cluster deployment might be comprised of:

* A private cloud cluster running on your local machine
* Two public cloud clusters running in public cloud providers

While the detailed steps are not included here, this demonstration can alternatively be performed with three separate namespaces on a single cluster.

## Step 1: Access your Kubernetes clusters

Skupper is designed for use with multiple Kubernetes clusters.
The `skupper` and `kubectl` commands use your
[kubeconfig][kubeconfig] and current context to select the cluster
and namespace where they operate.

[kubeconfig]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

This example uses multiple cluster contexts at once. The
`KUBECONFIG` environment variable tells `skupper` and `kubectl`
which kubeconfig to use.

For each cluster, open a new terminal window.  In each terminal,
set the `KUBECONFIG` environment variable to a different path and
log in to your cluster.

_**Public 1 cluster:**_

~~~ shell
export KUBECONFIG=$PWD/kubeconfigs/public1.config
<provider-specific login command>
~~~

_**Public 2 cluster:**_

~~~ shell
export KUBECONFIG=$PWD/kubeconfigs/public2.config
<provider-specific login command>
~~~

_**Private 1 cluster:**_

~~~ shell
export KUBECONFIG=$PWD/kubeconfigs/private1.config
<provider-specific login command>
~~~

**Note:** The login procedure varies by provider.

## Step 2: Install Skupper on your Kubernetes clusters

Using Skupper on Kubernetes requires the installation of the
Skupper custom resource definitions (CRDs) and the Skupper
controller.

For each cluster, use `kubectl apply` with the Skupper
installation YAML to install the CRDs and controller.

_**Public 1 cluster:**_

~~~ shell
kubectl apply -f https://skupper.io/v2/install.yaml
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl apply -f https://skupper.io/v2/install.yaml
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f https://skupper.io/v2/install.yaml
~~~

## Step 3: Create your Kubernetes namespaces

The example application has different components deployed to
different Kubernetes namespaces.  To set up our example, we need
to create the namespaces.

For each cluster, use `kubectl create namespace` and `kubectl
config set-context` to create the namespace you wish to use and
set the namespace on your current context.

_**Public 1 cluster:**_

~~~ shell
kubectl create namespace public1
kubectl config set-context --current --namespace public1
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl create namespace public2
kubectl config set-context --current --namespace public2
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl create namespace private1
kubectl config set-context --current --namespace private1
~~~

## Step 4: Set up the demo

On your local machine, make a directory for this tutorial and clone the example repo:

_**Public 1 cluster:**_

~~~ shell
cd ~/
mkdir pg-demo
cd pg-demo
git clone -b v2 https://github.com/skupperproject/skupper-example-postgresql.git
~~~

## Step 5: Create your sites

A Skupper _Site_ is a location where your application workloads
are running. Sites are linked together to form a network for your
application.

Use the `kubectl apply` command to declaratively create sites in the kubernetes
namespaces. This deploys the Skupper router. Then use `kubectl get site` to see
the outcome.

  **Note:** If you are using Minikube, you need to [start minikube
  tunnel][minikube-tunnel] before you configure skupper.

  [minikube-tunnel]: https://skupper.io/start/minikube.html#running-minikube-tunnel

The **public1** site definition sets `linkAccess: default`, because the other two sites **public2** and **private1**
will establish a Skupper link to **public1**. This extra definition tells that the **public1** site accepts incoming
Skupper links from other sites using the default ingress type for the target cluster (_route_ when using OpenShift or _loadbalancer_ otherwise).

_**Public 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public1/site.yaml
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public2/site.yaml
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/site.yaml
~~~

## Step 6: Link your sites

A Skupper _link_ is a channel for communication between two sites.
Links serve as a transport for application connections and
requests.

Creating an AccessToken requires the creation of an AccessGrant first,
on the target namespace (**public1**), then we can consume the AccessGrant's status
to write an AccessToken and apply if into the target clusters (**public2** and **private1**)
using `kubectl apply`.

**Note:** The link token is truly a *secret*.  Anyone who has the
token can link to your site.  Make sure that only those you trust
have access to it.

_**Public 1 cluster:**_

~~~ shell
kubectl wait --for=condition=ready site/public1 --timeout 300s
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public1/accessgrant.yaml
kubectl wait --for=condition=ready accessgrant/public1-grant --timeout 300s
kubectl get accessgrant public1-grant -o go-template-file=~/pg-demo/skupper-example-postgresql/kubernetes/token.template > ~/public1.token
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl apply -f ~/public1.token
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/public1.token
accesstoken.skupper.io/token-public1-grant created
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f ~/public1.token
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/public1.token
accesstoken.skupper.io/token-public1-grant created
~~~

If your terminal sessions are on different machines, you may need
to use `scp` or a similar tool to transfer the token securely.  By
default, tokens expire after a single use or 15 minutes after
being issued.

## Step 7: Deploy the PostgreSQL service

After creating the application router network, deploy the PostgreSQL service.
The **private1** cluster will be used to deploy the PostgreSQL server and the **public1** and **public2** clusters
will be used to enable client communications to the server on the **private1** cluster.

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/deployment-postgresql-svc.yaml
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/deployment-postgresql-svc.yaml
secret/postgresql created
deployment.apps/postgresql created
~~~

## Step 8: Expose the PostgreSQL on the Virtual Application Network

Now that the PostgreSQL is running in the **private1** cluster, we need to expose it into your Virtual Application Network (VAN).

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/connector.yaml
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/connector.yaml
connector.skupper.io/postgresql created
~~~

## Step 9: Making the PostgreSQL database accessible to the public sites

In order to make the PostgreSQL database accessible to the **public1** and **public2** sites, we need to define a `Listener`
on each site, which will produce a Kubernetes service on each cluster, connecting them with the database running on **private1** cluster.

_**Public 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public1/listener.yaml
kubectl wait --for=condition=ready listener/postgresql --timeout 300s
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public1/listener.yaml
listener.skupper.io/postgresql created
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public2/listener.yaml
kubectl wait --for=condition=ready listener/postgresql --timeout 300s
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/pg-demo/skupper-example-postgresql/kubernetes/public2/listener.yaml
listener.skupper.io/postgresql created
~~~

## Step 10: Create pod with PostgreSQL client utilities

Create a pod named `pg-shell` on each of the public clusters. This pod will be used to
communicate with the PostgreSQL database from **public1** and **public2** clusters.

_**Public 1 cluster:**_

~~~ shell
kubectl run pg-shell --image quay.io/skupper/simple-pg \
--env="PGUSER=postgres" \
--env="PGPASSWORD=skupper" \
--env="PGHOST=postgresql" \
--command sleep infinity
~~~

_Sample output:_

~~~ console
$ kubectl run pg-shell --image quay.io/skupper/simple-pg \
--env="PGUSER=postgres" \
--env="PGPASSWORD=skupper" \
--env="PGHOST=postgresql" \
--command sleep infinity
pod/pg-shell created
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl run pg-shell --image quay.io/skupper/simple-pg \
--env="PGUSER=postgres" \
--env="PGPASSWORD=skupper" \
--env="PGHOST=postgresql" \
--command sleep infinity
~~~

_Sample output:_

~~~ console
$ kubectl run pg-shell --image quay.io/skupper/simple-pg \
--env="PGUSER=postgres" \
--env="PGPASSWORD=skupper" \
--env="PGHOST=postgresql" \
--command sleep infinity
pod/pg-shell created
~~~

## Step 11: Create a database, a table and insert values

Now that we can access the PostgreSQL database from both public sites, let's create a database called **markets**,
then create a table named **product** and load it with some data.

_**Public 1 cluster:**_

~~~ shell
kubectl exec pg-shell -- createdb -e markets
kubectl exec -i pg-shell -- psql -d markets < ~/pg-demo/skupper-example-postgresql/sql/table.sql
kubectl exec -i pg-shell -- psql -d markets < ~/pg-demo/skupper-example-postgresql/sql/data.sql
~~~

_Sample output:_

~~~ console
$ kubectl exec pg-shell -- createdb -e markets
kubectl exec -i pg-shell -- psql -d markets < ~/pg-demo/skupper-example-postgresql/sql/table.sql
kubectl exec -i pg-shell -- psql -d markets < ~/pg-demo/skupper-example-postgresql/sql/data.sql
SELECT pg_catalog.set_config('search_path', '', false);
CREATE DATABASE markets;
CREATE TABLE
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
~~~

## Step 12: Access the product table from any site

Now that data has been added, try to read them from both the **public1** and **public2** sites.

_**Public 1 cluster:**_

~~~ shell
kubectl exec -i pg-shell -- psql -d markets <<< "SELECT * FROM product;"
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl exec -i pg-shell -- psql -d markets <<< "SELECT * FROM product;"
~~~

## Cleaning up

Restore your cluster environment by returning the resources created in the demonstration. On each cluster, delete the 
demo resources and the virtual application Network.

_**Public 1 cluster:**_

~~~ shell
kubectl delete pod pg-shell --now
kubectl delete -f ~/pg-demo/skupper-example-postgresql/kubernetes/public1/
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl delete pod pg-shell --now
kubectl delete -f ~/public1.token -f ~/pg-demo/skupper-example-postgresql/kubernetes/public2/
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl delete -f ~/public1.token -f ~/pg-demo/skupper-example-postgresql/kubernetes/private1/
~~~

## Summary

Through this example, we demonstrated how Skupper enables secure access to a PostgreSQL database hosted in a
private Kubernetes cluster, without exposing it to the public internet.

By deploying Skupper in each namespace, we established a **Virtual Application Network** (VAN), which allowed
the PostgreSQL service to be securely shared across clusters. The database was made available exclusively within
the VAN, enabling applications in the public1 and public2 clusters to access it seamlessly, as if it were running
locally in their own namespaces.

This approach not only simplifies multi-cluster communication but also preserves strict network boundaries,
eliminating the need for complex VPNs or firewall changes.

## Next steps

Check out the other [examples][examples] on the Skupper website.

## About this example

This example was produced using [Skewer][skewer], a library for
documenting and testing Skupper examples.

[skewer]: https://github.com/skupperproject/skewer

Skewer provides utility functions for generating the README and
running the example steps.  Use the `./plano` command in the project
root to see what is available.

To quickly stand up the example using Minikube, try the `./plano demo`
command.
