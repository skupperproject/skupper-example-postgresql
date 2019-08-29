# Sharing a PostgreSQL database across clusters

This tutorial demonstrates how to share a PostgreSQL database across multiple Kubernetes clusters that are located in different public and private cloud providers.

In this tutorial, you will deploy a PostgreSQL database instance in a private cluster. You will also create and application router network, which will enable clients on different clusters to transparently access the database without the need for additional networking setup (e.g. no vpn or sdn required).

To complete this tutorial, do the following:

* [Prerequisites](#prerequisites)
* [Step 1: Set up the demo](#step-1-set-up-the-demo)
* [Step 2: Deploy Application Router Network](#step-2-deploy-application-router-network)
* [Step 3: Deploy the PostgreSQL service](#step-3-deploy-the-postgresql-service)
* [Step 4: Access the database from client clusters](#step-4-access-the-database-from-client-clusters)
* [Next steps](#next-steps)

## Prerequisites

You must have access to two OpenShift clusters:
* A "private cloud" cluster running on your local machine
* A public cloud cluster running on  a public cloud provider

## Step 1: Set up the demo

1. On your local machine, make a directory for this tutorial, clone the example repo, and download the skupper-cli tool:

   ```bash
   $ mkdir postgresql-demo
   $ cd postgresql-demo
   $ git clone git@github.com:skupperproject/skupper-example-postgresql.git # for deploying the PostgreSQL service
   $ wget https://github.com/skupperproject/skupper-cli/releases/download/dummy/linux.tgz -O - | tar -xzf - # cli for application router network
   ```

3. Prepare the OpenShift clusters.

   1. Log in to each OpenShift cluster in a separate terminal session. You should have one local cluster running (e.g. on your machine) and one clusters running in a public cloud provider.
   2. In each cluster, create a namespace for this demo.
  
      ```bash
      $ oc new-project postgresql-demo
      ```

## Step 2: Deploy Application Router Network

On each cluster, define the application router role and connectivity to peer clusters.

1. In the terminal for the public cluster, deploy the *public1* application router, and create its secrets:

   ```bash
   $ ~/postgresql-demo/skupper init --hub --name public1
   $ ~/postgresql-demo/skupper secret --file ~/postgresql-demo/private1-to-public1-secret.yaml --subject private1
   ```

2. In the terminal for the private cluster, deploy the *private1* application router and define its connections to the public cluster

   ```bash
   $ ~/postgresql-demo/skupper init --name private1
   $ ~/postgresql-demo/skupper connect --secret ~/postgresql-demo/private1-to-public1-secret.yaml --name public1
   ```
   
## Step 3: Deploy the PostgreSQL service

After creating the application router network, deploy the PostgreSQL service. The private1 cluster will be used to deploy the PostgreSQL server and the public1 clusters will be used to enable client communications to the server on the private1 cluster.

The `~/postgresql-demo/skupper-example-postgresql` directory contains the YAML files that you will use to create the service.

1. In the terminal for the *private1* cluster, deploy the following:

   ```bash
   $ oc apply -f ~/postgresql-demo/skupper-example-postgresql/deployment-postgresql-svc-a.yaml
   ```

2. In the terminal for the *public1* cluster where the PostgreSQL server will be created, deploy the following:

   ```bash
   $ oc apply -f ~/postgresql-demo/skupper-example-postgresql/deployment-postgresql-svc-b.yaml
   ```

## Step 4: Access the database

After deploying the postgresql services into the private and public cloud clusters, access the database...

- createdb -h $(oc get service postgresql-svc -o=jsonpath='{.spec.clusterIP}') -U postgres -e markets
- psql -h $(oc get service mongo-svc-a -o=jsonpath='{.spec.clusterIP}') -U postgres
- 
#\c markets
create table if not exists product (
  id              SERIAL,
  name            VARCHAR(100) NOT NULL,
  sku             CHAR(8)
);
INSERT INTO product VALUES(DEFAULT, 'Apple, Fuji', '4131');
INSERT INTO product VALUES(DEFAULT, 'Banana', '4011');
SELECT * FROM product;

- Web front end??

## Next steps

TODO: describe what the user should do after completing this tutorial
