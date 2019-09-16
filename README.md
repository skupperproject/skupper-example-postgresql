# Sharing a PostgreSQL database across clusters

This tutorial demonstrates how to share a PostgreSQL database across multiple Kubernetes clusters that are located in different public and private cloud providers.

In this tutorial, you will deploy a PostgreSQL database instance to a private cluster. You will also create and application router network, which will enable clients on different public clusters to transparently access the database without the need for additional networking setup (e.g. no vpn or sdn required).

To complete this tutorial, do the following:

* [Prerequisites](#prerequisites)
* [Step 1: Set up the demo](#step-1-set-up-the-demo)
* [Step 2: Deploy the Skupper Network](#step-2-deploy-the-skupper-network)
* [Step 3: Deploy the PostgreSQL service](#step-3-deploy-the-postgresql-service)
* [Step 4: Annotate PostgreSQL service to join the Skupper Network](#step-4-annotate-postgresql-service-to-join-the-skupper-network)
* [Step 5: Access the database from client clusters](#step-5-access-the-database-from-client-clusters)
* [Next steps](#next-steps)

## Prerequisites

The basis for the demonstration is to depict the operation of a PostgreSQL database in a private cluster and the ability to access the database from clients resident on other public clusters. As an example, the cluster deployment might be comprised of:

* A "private cloud" cluster running on your local machine
* Two public cloud clusters running in public cloud providers

While the detailed steps are not included here, this demonstration can alternatively be performed with three separate namespaces on a single cluster.

## Step 1: Set up the demo

1. On your local machine, make a directory for this tutorial, clone the example repo, and download the skupper-cli tool:

   ```bash
   mkdir pg-demo
   cd pg-demo
   git clone https://github.com:skupperproject/skupper-example-postgresql.git
   curl -fL https://github.com/skupperproject/skupper-cli/releases/download/0.0.1-beta/linux.tgz -o skupper.tgz
   mkdir -p $HOME/bin
   tar -xf skupper.tgz --directory $HOME/bin
   export PATH=$PATH:$HOME/bin
   ```

   To test your installation, run the 'skupper' command with no arguments. It will print a usage summary.

   ```bash
   $ skupper
   usage: skupper <command> <args>
   [...]
   ```

3. Prepare the target clusters.

   1. On your local machine, log in to each cluster in a separate terminal session.
   2. In each cluster, create a namespace to use for the demo.
   3. In each cluster, set the kubectl config context to use the demo namespace [(see kubectl cheat sheet)](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Step 2: Deploy the Skupper Network

On each cluster, define the Skupper network and the connectivity for the peer clusters.

1. In the terminal for the first public cluster, deploy the **public1** application router. Create two connection tokens for connections from the **public2** cluster and the **private1** cluster:

   ```bash
   skupper init --id public1
   skupper connection-token private1-to-public1-token.yaml
   skupper connection-token public2-to-public1-token.yaml
   ```

2. In the terminal for the second public cluster, deploy the **public2** application router, and connect to the **public1** cluster:

   ```bash
   skupper init --id public2
   skupper connect public2-to-public1-token.yaml
   ```

3. In the terminal for the private cluster, deploy the **private1** application router and define its connections to the **public1** cluster

   ```bash
   skupper init --edge --id private1
   skupper connect private1-to-public1-token.yaml
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

## Step 4: Annotate PostgreSQL service to join to the Skupper Network

1. In the terminal for the **private1** cluster, annotate the postgresql-svc service:

   ```bash
   kubectl annotate service postgresql-svc skupper.io/proxy=tcp
   ```

## Step 5: Access the database

After the PostgresSQL service is deployed to the Skupper Network from the private cluster, access the database from the public clusters.

1. Create a database call 'markets' on the **private1** cluster

   ```bash
   export PGPASSWORD=skupper && \
   createdb -h $(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -e markets

   kubectl run --generator=run-pod/v1 pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGPASSWORD=skupper" -- createdb -h $(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -e markets
   ```

2. Create a table called 'product' in the 'markets' database on the **public1** cluster

Create an interactive pod with PostgreSQL client utilities to access the database on the **private1** cluster:

   ```bash
   kubectl run --generator=run-pod/v1 pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGPASSWORD=skupper" -- psql -h $(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -d markets
   ```
And create a table in the database:

   ```bash
   markets# create table if not exists product (
              id              SERIAL,
              name            VARCHAR(100) NOT NULL,
              sku             CHAR(8)
              );
   ```

3. Insert values into the `product` table in the `markets` database on the **public2** cluster:

Create an interactive pod with PostgreSQL client utilities to access the database on the **private1** cluster:

   ```bash
   kubectl run --generator=run-pod/v1 pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGPASSWORD=skupper" -- psql -h $(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -d markets
   ```

And insert values into the table in the database:

   ```bash
   markets# INSERT INTO product VALUES(DEFAULT, 'Apple, Fuji', '4131');
   markets# INSERT INTO product VALUES(DEFAULT, 'Banana', '4011');
   markets# INSERT INTO product VALUES(DEFAULT, 'Pear, Bartlett', '4214');
   markets# INSERT INTO product VALUES(DEFAULT, 'Orange', '4056');
   ```

4. From any cluster, access the `product` tables in the `markets` database to view contents

Create an interactive pod with PostgreSQL client utilities (or use active one from above):

   ```bash
   kubectl run --generator=run-pod/v1 pg-shell -i --tty --image quay.io/skupper/simple-pg --env="PGPASSWORD=skupper" -- psql -h $(kubectl get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -d markets
   ```

And view the table contents:

   ```bash
   markets# SELECT * FROM product;
   ```
## Next steps

Restore your cluster environment by returning the resources created in the demonstration. On each cluster, delete the demo resources and the skupper network:

1. In the terminal for the **public1** cluster, delete the resources:

   ```bash
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   $ skupper delete
   ```

2. In the terminal for the **public2** cluster, delete the resources:

   ```bash
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   $ skupper delete
   ```

3. In the terminal for the **private1** cluster, delete the resources:

   ```bash
   $ kubectl delete -f ~/pg-demo/skupper-example-postgresql/deployment-postgresql-svc-a.yaml
   $ skupper delete
   ```
