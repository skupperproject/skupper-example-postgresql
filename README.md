# PostgreSQL Example

[![main](https://github.com/skupperproject/skupper-example-postgresql/actions/workflows/main.yaml/badge.svg)](https://github.com/skupperproject/skupper-example-postgresql/actions/workflows/main.yaml)

#### Sharing a PostgreSQL database across clusters

This example is part of a [suite of examples][examples] showing the
different ways you can use [Skupper][website] to connect services
across cloud providers, data centers, and edge sites.

[website]: https://skupper.io/
[examples]: https://skupper.io/examples/index.html

#### Contents

* [Overview](#overview)
* [Prerequisites](#prerequisites)
* [Step 1: Access your clusters](#step-1-access-your-clusters)
* [Step 2: Set up namespaces](#step-2-set-up-namespaces)
* [Step 3: Deploy the Virtual Application Network](#step-3-deploy-the-virtual-application-network)
* [Step 4: Deploy the PostgreSQL service](#step-4-deploy-the-postgresql-service)
* [Step 5: Create Skupper service for the Virtual Application Network](#step-5-create-skupper-service-for-the-virtual-application-network)
* [Step 6: Bind the Skupper service to the deployment target on the Virtual Application Network](#step-6-bind-the-skupper-service-to-the-deployment-target-on-the-virtual-application-network)
* [Step 7: Create interactive pod with PostgreSQL client utilities](#step-7-create-interactive-pod-with-postgresql-client-utilities)
* [Step 8: Create a Database, Create a Table, Insert Values](#step-8-create-a-database-create-a-table-insert-values)
* [Summary](#summary)
* [Cleaning up](#cleaning-up)
* [Next steps](#next-steps)

## Overview

This tutorial demonstrates how to share a PostgreSQL database across multiple Kubernetes clusters that are located in 
different public and private cloud providers.

## Prerequisites

* The `kubectl` command-line tool, version 1.15 or later
  ([installation guide][install-kubectl])

* The `skupper` command-line tool, the latest version ([installation
  guide][install-skupper])

* Access to at least one Kubernetes cluster, from any provider you
  choose

[install-kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[install-skupper]: https://skupper.io/install/index.html

## Step 1: Access your clusters

The methods for accessing your clusters vary by Kubernetes provider.
Find the instructions for your chosen providers and use them to
authenticate and configure access for each console session.  See the
following links for more information:

* [Minikube](https://skupper.io/start/minikube.html)
* [Amazon Elastic Kubernetes Service (EKS)](https://skupper.io/start/eks.html)
* [Azure Kubernetes Service (AKS)](https://skupper.io/start/aks.html)
* [Google Kubernetes Engine (GKE)](https://skupper.io/start/gke.html)
* [IBM Kubernetes Service](https://skupper.io/start/ibmks.html)
* [OpenShift](https://skupper.io/start/openshift.html)
* [More providers](https://kubernetes.io/partners/#kcsp)

Console for _public1_:

~~~ shell
export KUBECONFIG=~/.kube/public1
~~~

Console for _public2_:

~~~ shell
export KUBECONFIG=~/.kube/public2
~~~

Console for _private_:

~~~ shell
export KUBECONFIG=~/.kube/private1
~~~

## Step 2: Set up namespaces

Use `kubectl create namespace` to create the namespaces you wish to
use (or use existing namespaces).  Use `kubectl config set-context` to
set the current namespace for each session.

Console for _public1_:

~~~ shell
kubectl create namespace public1
kubectl config set-context --current --namespace public1
~~~

Console for _public2_:

~~~ shell
kubectl create namespace public2
kubectl config set-context --current --namespace public2
~~~

Console for _private_:

~~~ shell
kubectl create namespace private1
kubectl config set-context --current --namespace private1
~~~

## Step 3: Deploy the Virtual Application Network

Creating a link requires use of two `skupper` commands in conjunction,
`skupper token create` and `skupper link create`.

The `skupper token create` command generates a secret token that
signifies permission to create a link.  The token also carries the
link details.  Then, in a remote namespace, The `skupper link create`
command uses the token to create a link to the namespace that
generated it.

**Note:** The link token is truly a *secret*.  Anyone who has the
token can link to your namespace.  Make sure that only those you trust
have access to it.

First, use `skupper token create` in one namespace to generate the
token.  Then, use `skupper link create` in the other to create a link.

Console for _public1_:

~~~ shell
skupper init --site-name public1
skupper token create --uses 2 ~/public1-token.yaml
~~~

Console for _public2_:

~~~ shell
skupper init --site-name public2
skupper token create ~/public2-token.yaml
skupper link create ~/public1-token.yaml
skupper link status --wait 30
~~~

Console for _private_:

~~~ shell
skupper init --site-name private1
skupper link create ~/public1-token.yaml
skupper link create ~/public2-token.yaml
skupper link status --wait 30
~~~

If your console sessions are on different machines, you may need to
use `scp` or a similar tool to transfer the token.

## Step 4: Deploy the PostgreSQL service

After creating the application router network, deploy the PostgreSQL service. 
The **private1** cluster will be used to deploy the PostgreSQL server and the **public1** 
and **public2** clusters will be used to enable client communications to the server on 
the **private1** cluster.

Console for _private_:

~~~ shell
mkdir pg-demo
cd pg-demo
git clone https://github.com/skupperproject/skupper-example-postgresql.git
kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc.yaml
~~~

## Step 5: Create Skupper service for the Virtual Application Network

Console for _private_:

~~~ shell
skupper service create postgresql 5432
~~~

Console for _public1_:

~~~ shell
skupper service status
~~~

Console for _public2_:

~~~ shell
skupper service status
~~~

Note that the mapping for the service address defaults to `tcp`.

## Step 6: Bind the Skupper service to the deployment target on the Virtual Application Network

Console for _private_:

~~~ shell
skupper service bind postgresql deployment postgresql
~~~

Console for _public1_:

~~~ shell
skupper service status
~~~

Console for _public2_:

~~~ shell
skupper service status
~~~

Note that the **private1** is the only cluster to provide a target.

## Step 7: Create interactive pod with PostgreSQL client utilities

Console for _private_:

~~~ shell
kubectl run pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGUSER=postgres" --env="PGPASSWORD=skupper" --env="PGHOST=$(kubectl get service postgresql -o=jsonpath='{.spec.clusterIP}')" -- bash
~~~

Console for _public1_:

~~~ shell
kubectl run pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGUSER=postgres" --env="PGPASSWORD=skupper" --env="PGHOST=$(kubectl get service postgresql -o=jsonpath='{.spec.clusterIP}')" -- bash
~~~

Console for _public2_:

~~~ shell
kubectl run pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGUSER=postgres" --env="PGPASSWORD=skupper" --env="PGHOST=$(kubectl get service postgresql -o=jsonpath='{.spec.clusterIP}')" -- bash
~~~

Note that if the session is ended, it can be resumed with the following:
     ```bash
     kubectl attach pg-shell -c pg-shell -i -t
     ```

## Step 8: Create a Database, Create a Table, Insert Values

Using the 'pg-shell' pod running on each cluster, operate on the database:

Console for _private_:

~~~ shell
createdb -e markets
~~~

Console for _public1_:

~~~ shell
psql -d markets
create table if not exists product (id SERIAL, name VARCHAR(100) NOT NULL, sku CHAR(8));
~~~

Console for _public2_:

~~~ shell
psql -d markets
INSERT INTO product VALUES(DEFAULT, 'Apple, Fuji', '4131');
INSERT INTO product VALUES(DEFAULT, 'Banana', '4011');
INSERT INTO product VALUES(DEFAULT, 'Pear, Bartlett', '4214');
INSERT INTO product VALUES(DEFAULT, 'Orange', '4056');
~~~

From any cluster, access the `product` tables in the `markets` database to view contents.

## Summary

In this tutorial, you will create a Virtual Application Nework that enables communications 
across the public and private clusters. You will then deploy a PostgresSQL database 
instance to a private cluster and attach it to the Virtual Application Network. 
It will enable clients on different public clusters attached to the Virtual Application 
Nework to transparently access the database without the need for additional networking setup 
(e.g. no vpn or firewall rules required).

## Cleaning up

To remove Skupper and the other resources from this exercise, use the
following commands.

Console for _public1_:

~~~ shell
skupper delete
kubectl delete pod pg-shell
~~~

Console for _public2_:

~~~ shell
skupper delete
kubectl delete pod pg-shell
~~~

Console for _private_:

~~~ shell
kubectl delete pod pg-shell
skupper unexpose deployment postgresql
kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc.yaml
skupper delete
~~~

## Next steps

Check out the other [examples][examples] on the Skupper website.
