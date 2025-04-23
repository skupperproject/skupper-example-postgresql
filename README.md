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
* [Step 3: Install the Skupper command-line tool](#step-3-install-the-skupper-command-line-tool)
* [Step 4: Create your Kubernetes namespaces](#step-4-create-your-kubernetes-namespaces)
* [Step 5: Create your sites](#step-5-create-your-sites)
* [Step 6: Link your sites](#step-6-link-your-sites)
* [Step 7: Set up the demo](#step-7-set-up-the-demo)
* [Step 8: Deploy the PostgreSQL service](#step-8-deploy-the-postgresql-service)
* [Step 9: Expose the PostegreSQL on the Virtual Application Network](#step-9-expose-the-postegresql-on-the-virtual-application-network)
* [Step 10: Making the PostegreSQL database accessible to the public sites](#step-10-making-the-postegresql-database-accessible-to-the-public-sites)
* [Step 11: Create pod with PostgreSQL client utilities](#step-11-create-pod-with-postgresql-client-utilities)
* [Step 12: Create a database, a table and insert values](#step-12-create-a-database-a-table-and-insert-values)
* [Step 13: Access the product table from any site](#step-13-access-the-product-table-from-any-site)
* [Cleaning up](#cleaning-up)
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

* The `kubectl` command-line tool, version 1.15 or later ([installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
* The `skupper` command-line tool, version 2.0 or later ([installation guide](https://skupper.io/start/index.html#step-1-install-the-skupper-command-line-tool-in-your-environment))

The basis for the demonstration is to depict the operation of a PostgreSQL database in a private cluster and the ability to access the database from clients resident on other public clusters. As an example, the cluster deployment might be comprised of:

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

## Step 3: Install the Skupper command-line tool

This example uses the Skupper command-line tool to create Skupper
resources.  You need to install the `skupper` command only once
for each development environment.

On Linux or Mac, you can use the install script (inspect it
[here][install-script]) to download and extract the command:

~~~ shell
curl https://skupper.io/v2/install.sh | sh
~~~

The script installs the command under your home directory.  It
prompts you to add the command to your path if necessary.

For Windows and other installation options, see [Installing
Skupper][install-docs].

[install-script]: https://github.com/skupperproject/skupper-website/blob/main/input/install.sh
[install-docs]: https://skupper.io/install/

## Step 4: Create your Kubernetes namespaces

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

## Step 5: Create your sites

A Skupper _site_ is a location where your application workloads
are running.  Sites are linked together to form a network for your
application.

For each namespace, use `skupper site create` with a site name of
your choice.  This creates the site resource and deploys the
Skupper router to the namespace.

**Note:** If you are using Minikube, you need to [start minikube
tunnel][minikube-tunnel] before you run `skupper site create`.

<!-- XXX Explain enabling link acesss on one of the sites -->

[minikube-tunnel]: https://skupper.io/start/minikube.html#running-minikube-tunnel

_**Public 1 cluster:**_

~~~ shell
skupper site create public1 --enable-link-access
~~~

_Sample output:_

~~~ console
$ skupper site create public1 --enable-link-access
Waiting for status...
Site "public1" is configured. Check the status to see when it is ready
~~~

_**Public 2 cluster:**_

~~~ shell
skupper site create public2
~~~

_Sample output:_

~~~ console
$ skupper site create public2
Waiting for status...
Site "public2" is configured. Check the status to see when it is ready
~~~

_**Private 1 cluster:**_

~~~ shell
skupper site create private1
~~~

_Sample output:_

~~~ console
$ skupper site create private1
Waiting for status...
Site "private1" is configured. Check the status to see when it is ready
~~~

You can use `skupper site status` at any time to check the status
of your site.

## Step 6: Link your sites

A Skupper _link_ is a channel for communication between two sites.
Links serve as a transport for application connections and
requests.

Creating a link requires the use of two Skupper commands in
conjunction: `skupper token issue` and `skupper token redeem`.
The `skupper token issue` command generates a secret token that
can be transferred to a remote site and redeemed for a link to the
issuing site.  The `skupper token redeem` command uses the token
to create the link.

**Note:** The link token is truly a *secret*.  Anyone who has the
token can link to your site.  Make sure that only those you trust
have access to it.

First, use `skupper token issue` in public1 cluster to generate the token.
Then, use `skupper token redeem` in public2 and private1 clusters to link the sites.

_**Public 1 cluster:**_

~~~ shell
skupper token issue -r 2 ~/public1.token
~~~

_Sample output:_

~~~ console
$ skupper token issue -r 2 ~/public1.token
Waiting for token status ...

Grant "public1-cad4f72d-2917-49b9-ab66-cdaca4d6cf9c" is ready
Token file /run/user/1000/skewer/public1.token created

Transfer this file to a remote site. At the remote site,
create a link to this site using the "skupper token redeem" command:

  skupper token redeem <file>

The token expires after 2 use(s) or after 15m0s.
~~~

_**Public 2 cluster:**_

~~~ shell
skupper token redeem ~/public1.token
~~~

_Sample output:_

~~~ console
$ skupper token redeem ~/public1.token
Waiting for token status ...
Token "public1-cad4f72d-2917-49b9-ab66-cdaca4d6cf9c" has been redeemed
~~~

_**Private 1 cluster:**_

~~~ shell
skupper token redeem ~/public1.token
~~~

_Sample output:_

~~~ console
$ skupper token redeem ~/public1.token
Waiting for token status ...
Token "public1-cad4f72d-2917-49b9-ab66-cdaca4d6cf9c" has been redeemed
~~~

If your terminal sessions are on different machines, you may need
to use `scp` or a similar tool to transfer the token securely.  By
default, tokens expire after a single use or 15 minutes after
being issued.

## Step 7: Set up the demo

On your local machine, make a directory for this tutorial and clone the example repo:

_**Public 1 cluster:**_

~~~ shell
cd ~/
mkdir pg-demo
cd pg-demo
git clone -b v2 https://github.com/fgiorgetti/skupper-example-postgresql.git
~~~

## Step 8: Deploy the PostgreSQL service

After creating the application router network, deploy the PostgreSQL service.
The **private1** cluster will be used to deploy the PostgreSQL server and the **public1** and **public2** clusters
will be used to enable client communications to the server on the **private1** cluster.

_**Private 1 cluster:**_

~~~ shell
kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc.yaml
~~~

_Sample output:_

~~~ console
$ kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc.yaml
secret/postgresql created
deployment.apps/postgresql created
~~~

## Step 9: Expose the PostegreSQL on the Virtual Application Network

Now that the PostgreSQL is running in the **private1** cluster, we need to expose it into your Virtual Application Network (VAN).

_**Private 1 cluster:**_

~~~ shell
skupper connector create postgresql 5432 --workload deployment/postgresql
~~~

_Sample output:_

~~~ console
$ skupper connector create postgresql 5432 --workload deployment/postgresql
Waiting for create to complete...
Connector "postgresql" is configured.
~~~

## Step 10: Making the PostegreSQL database accessible to the public sites

In order to make the PostgreSQL database accessible to the **public1** and **public2** sites, we need to define a `Listener`
on each site, which will produce a Kubernetes service on each cluster, connecting them with the database running on **private1** cluster.

_**Public 1 cluster:**_

~~~ shell
skupper listener create postgresql 5432
~~~

_Sample output:_

~~~ console
$ skupper listener create postgresql 5432
Waiting for create to complete...
Listener "postgresql" is configured.
~~~

_**Public 2 cluster:**_

~~~ shell
skupper listener create postgresql 5432
~~~

_Sample output:_

~~~ console
$ skupper listener create postgresql 5432
Waiting for create to complete...
Listener "postgresql" is configured.
~~~

## Step 11: Create pod with PostgreSQL client utilities

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

## Step 12: Create a database, a table and insert values

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

## Step 13: Access the product table from any site

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
skupper site delete --all
~~~

_**Public 2 cluster:**_

~~~ shell
kubectl delete pod pg-shell --now
skupper site delete --all
~~~

_**Private 1 cluster:**_

~~~ shell
kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc.yaml
skupper site delete --all
~~~

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
