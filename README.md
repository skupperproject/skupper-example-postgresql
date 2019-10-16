# Sharing a PostgreSQL database across clusters

This tutorial demonstrates how to share a PostgreSQL database across multiple Kubernetes clusters that are located in different public and private cloud providers.

In this tutorial, you will deploy a PostgreSQL database instance to a private cluster. You will also create and application router network, which will enable clients on different public clusters to transparently access the database without the need for additional networking setup (e.g. no vpn or sdn required).

To complete this tutorial, do the following:

* [Prerequisites](#prerequisites)
* [Step 1: Set up the demo](#step-1-set-up-the-demo)
* [Step 2: Deploy the Virtual Application Network](#step-2-deploy-the-virtual-application-network)
* [Step 3: Deploy the PostgreSQL service](#step-3-deploy-the-postgresql-service)
* [Step 4: Annotate PostgreSQL service to join the Virtual Application Network](#step-4-annotate-postgresql-service-to-join-the-virtual-application-network)
* [Step 5: Deploy interactive Pod with Postgresql client utilities](#step-5-deploy-interactive-pod-with-postgresql-client-utilities)
* [Step 6: Create a Database, Create a Table, Insert Values](#step-6-create-a-database-create-a-table-insert-values)
* [Cleaning up](#cleaning-up)
* [Next steps](#next-steps)

## Prerequisites

* The `kubectl` command-line tool, version 1.15 or later ([installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
* The `skupper` command-line tool, the latest version ([installation guide](https://skupper.io/start/index.html#step-1-install-the-skupper-command-line-tool-in-your-environment))

The basis for the demonstration is to depict the operation of a PostgreSQL database in a private cluster and the ability to access the database from clients resident on other public clusters. As an example, the cluster deployment might be comprised of:

* A "private cloud" cluster running on your local machine
* Two public cloud clusters running in public cloud providers

While the detailed steps are not included here, this demonstration can alternatively be performed with three separate namespaces on a single cluster.

## Step 1: Set up the demo

1. On your local machine, make a directory for this tutorial and clone the example repo:

   ```bash
   mkdir pg-demo
   cd pg-demo
   git clone https://github.com/skupperproject/skupper-example-postgresql.git
   ```

2. Prepare the target clusters.

   1. On your local machine, log in to each cluster in a separate terminal session.
   2. In each cluster, create a namespace to use for the demo.
   3. In each cluster, set the kubectl config context to use the demo namespace [(see kubectl cheat sheet)](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Step 2: Deploy the Virtual Application Network

On each cluster, define the virtual application network and the connectivity for the peer clusters.

1. In the terminal for the first public cluster, deploy the **public1** application router. Create two connection tokens for connections from the **public2** cluster and the **private1** cluster:

   ```bash
   skupper init --id public1
   skupper connection-token private1-to-public1-token.yaml
   skupper connection-token public2-to-public1-token.yaml
   ```

2. In the terminal for the second public cluster, deploy the **public2** application router, and connect to the **public1** cluster:

   ```bash
   skupper init --id public2
   skupper connection-token private1-to-public2-token.yaml
   skupper connect public2-to-public1-token.yaml
   ```

3. In the terminal for the private cluster, deploy the **private1** application router and define its connections to the **public1** cluster

   ```bash
   skupper init --edge --id private1
   skupper connect private1-to-public1-token.yaml
   skupper connect private1-to-public2-token.yaml
   ```
   
## Step 3: Deploy the PostgreSQL service

After creating the application router network, deploy the PostgreSQL service. The **private1** cluster will be used to deploy the PostgreSQL server and the **public1** and **public2** clusters will be used to enable client communications to the server on the **private1** cluster.

1. In the terminal for the **public1** cluster, deploy the following:

   ```bash
   kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   ```

2. In the terminal for the **public2** cluster where the PostgreSQL server will be created, deploy the following:

   ```bash
   kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   ```

3. In the terminal for the **private1** cluster where the PostgreSQL server will be created, deploy the following:

   ```bash
   kubectl apply -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-a.yaml
   ```

## Step 4: Annotate PostgreSQL service to join to the Virtual Application Network

1. In the terminal for the **private1** cluster, annotate the postgresql-svc service:

   ```bash
   kubectl annotate service postgresql-svc skupper.io/proxy=tcp
   ```

## Step 5: Create interactive pod with PostgreSQL client utilities

1. From each cluster terminial, create a pod that contains the PostgreSQL client utilities:

   ```bash
   kubectl run --generator=run-pod/v1 pg-shell -i --tty --image quay.io/skupper/simple-pg \
   --env="PGUSER=postgres" \
   --env="PGPASSWORD=skupper" \
   --env="PGHOST=$(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}')" \
   -- bash
   ```

2. Note that if the session is ended, it can be resumed with the following:

   ```bash
   kubectl attach pg-shell -c pg-shell -i -t
   ```

## Step 6: Create a Database, Create a Table, Insert Values

Using the 'pg-shell' pod running on each cluster, operate on the database:

1. Create a database called 'markets' from the **private1** cluster

   ```bash
   bash-5.0$ createdb -e markets
   ```

2. Create a table called 'product' in the 'markets' database from the **public1** cluster

   ```bash
   bash-5.0$ psql -d markets
   markets# create table if not exists product (
              id              SERIAL,
              name            VARCHAR(100) NOT NULL,
              sku             CHAR(8)
              );
   ```

3. Insert values into the `product` table in the `markets` database from the **public2** cluster:

   ```bash
   bash-5.0$ psql -d markets
   markets# INSERT INTO product VALUES(DEFAULT, 'Apple, Fuji', '4131');
   markets# INSERT INTO product VALUES(DEFAULT, 'Banana', '4011');
   markets# INSERT INTO product VALUES(DEFAULT, 'Pear, Bartlett', '4214');
   markets# INSERT INTO product VALUES(DEFAULT, 'Orange', '4056');
   ```

4. From any cluster, access the `product` tables in the `markets` database to view contents

   ```bash
   bash-5.0$ psql -d markets
   markets# SELECT * FROM product;
   ```

## Cleaning Up

Restore your cluster environment by returning the resources created in the demonstration. On each cluster, delete the demo resources and the virtual application network:

1. In the terminal for the **public1** cluster, delete the resources:

   ```bash
   $ kubectl delete pod pg-shell
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   $ skupper delete
   ```

2. In the terminal for the **public2** cluster, delete the resources:

   ```bash
   $ kubectl delete pod pg-shell
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   $ skupper delete
   ```

3. In the terminal for the **private1** cluster, delete the resources:

   ```bash
   $ kubectl delete pod pg-shell
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-a.yaml
   $ skupper delete
   ```

## Next steps

 - [Try the example for multi-cluster MongoDB replica set deployment](https://github.com/skupperproject/skupper-example-mongodb-replica-set)
 - [Find more examples](https://skupper.io/examples/)
