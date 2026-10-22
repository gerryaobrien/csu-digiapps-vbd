# Modules List

[Module 1: Kubernetes Fundamentals](#module-1-kubernetes-fundamentals)

[Module 2: What is AKS?](#module-2-what-is-aks)

[Module 3: AKS Networking](#module-3-aks-networking)

[Module 3.b: AKS Ingress with Application Gateway for Containers](#module-3b-aks-ingress-with-application-gateway-for-containers)

[Module 4: AKS Scaling](#module-4-aks-scaling)

[Module 5: Application Deployment](#module-5-application-deployment)

[Module 6: Storage on AKS](#module-6-storage-on-aks)

[Module 7: Monitoring](#module-7-monitoring)

[Module 8: Core Security Concepts](#module-8-core-security-concepts)

## Lab VM and command conventions

Run the workstation commands in **Windows PowerShell** on the Skillable VM.
The assets are already uploaded to `C:\k8s\labs`

```powershell
Set-Location C:\k8s\labs
Get-ChildItem -Directory
```

The preloaded module folders are `Module1`, `Module3`, `Module5`, `Module6`, and `Module8`. Modules without a preloaded folder use CLI commands, create files during the exercise, or explicitly download external samples. `Archive` is not used by these exercises.

Paths such as `Module8/spc.yaml` are relative to `C:\k8s\labs`. Return to this directory when starting a module. In particular, do not run those paths from inside a module folder or Module 7's generated working directory.

Keep using the same PowerShell window for variables defined in each exercise.
When a command runs continuously, open a second PowerShell window for the next step and stop the first command with **Ctrl+C** when finished. Commands entered after `kubectl exec ... -- bash` run inside a Linux container, not PowerShell.

# Module 1: Kubernetes Fundamentals

This module covers Kubernetes core building blocks — Pods, Labels, Deployments, Services, Volumes, ConfigMaps, and Secrets — running on a basic AKS cluster. You will create the cluster you will reuse for **Module 2** as well.

Reference: [Kubernetes Concepts](https://kubernetes.io/docs/concepts/), [AKS quickstart](https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-cli).

[Exercise: Create a Basic Azure Kubernetes Service Cluster](#exercise-create-a-basic-azure-kubernetes-service-cluster)

[Exercise: Creating a Pod Declaratively](#exercise-creating-a-pod-declaratively)

[Exercise: Working with Labels](#exercise-working-with-labels)

[Exercise: Working with Deployments](#exercise-working-with-deployments)

[Exercise: Working with Services](#exercise-working-with-services)

[Exercise: Working with Ephemeral Volumes, Secrets and ConfigMaps](#exercise-working-ephemeral-volumes-secrets-and-configmaps)

[Exercise: Cleanup Resources](#shutdown-or-delete-the-cluster)

## Exercise: Create a Basic Azure Kubernetes Service Cluster

In this exercise you will create a simple AKS cluster. **You will reuse this same cluster in Module 2**, so do not delete it until you have finished both modules.

### Task 1 - Login into your subscription and register providers

1. Open a Windows Terminal window using PowerShell.

![Windows Terminal icon in taskbar](content/windows-terminal.png)

> Windows Terminal allows you to open tabbed command terminals.

2. Login to Azure.

```powershell
az login
```

!IMAGE[azlogin.jpg](./images/azlogin.jpg)
!IMAGE[azlogin.jpg](../images/azlogin.jpg)
Choose Work or school Account
Click on Username and password to Autofill and Authenticate.

3. Set the current subscription.

Post Authentication, below screen shows up with the pre-defined Subscription to choose.
Select 1 and enter.

!IMAGE[subchoose.jpg](instructions287320/subchoose.jpg)

4. Register needed providers.

```powershell
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Kubernetes
```

5. Open a browser and navigate to the Azure Portal: **_portal.azure.com_**

6. Search for and open the **Subscriptions** blade. Select your **Azure** subscription.

7. Scroll down and select **Resource providers**.


!IMAGE[azure-resources.jpg](instructions287320/azure-resources.jpg)
8. Confirm the following required providers are registered. Select **Register** for any provider whose status is **NotRegistered**, then select **Refresh** until its status is **Registered**: **Microsoft.Storage**, **Microsoft.Compute**, **Microsoft.Network**, **Microsoft.Monitor**, **Microsoft.Insights**, **Microsoft.ManagedIdentity**, **Microsoft.OperationalInsights**, **Microsoft.OperationsManagement**, **Microsoft.KeyVault**, **Microsoft.ContainerRegistry**, **Microsoft.ContainerService**, and **Microsoft.Kubernetes**.

### Task 2 - Define variables and create resource group

[!Alert] Get region information from the instructor!!

1. Select the region closest to your location.  Ask your instructor for region options: @lab.textbox(region)

2. Define global variables.

**WARNING**: When using Azure regions you could run into deployment issues in high demand regions. Consult your delivering CSA for guidance if you run into issues. Available regions: Central US, East US 2, Sweden Central, West US

```powershell
$RESOURCE_GROUP = "azure-rg"

$LOCATION = "eastus2"

echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
```

3. Set the VM SKU to one of the available values or use the default below.

**WARNING**: VM SKU availability depends on both the region and the subscription. Start with the default, then validate it before creating the cluster. Available SKUs to try: Standard_D2as_v5, Standard_A2m_v2, Standard_D2s_v5, Standard_D2ads_v5

```powershell
$VM_SKU = "Standard_D2as_v5"
```

4. Check whether the selected VM SKU has any restrictions for your subscription in the selected region.

```powershell
az vm list-skus --location $LOCATION --size $VM_SKU --all `
  --query "[?name=='$VM_SKU'].{Name:name,Restrictions:restrictions}" `
  --output table
```

If the result shows `NotAvailableForSubscription`, set `$VM_SKU` to another SKU from the list and run the check again. Continue when the selected SKU has no subscription restriction. Ask your instructor for guidance if none of the listed SKUs are available.

### Task 3 - Create a basic cluster using Azure CLI

1. Define variables for AKS cluster.

```powershell
$AKS_NAME = "aks-@lab.LabInstance.Id"
echo "AKS Cluster Name: $AKS_NAME"
```

2. Create the resource group and AKS cluster.

```powershell
az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create --node-count 2 --generate-ssh-keys --node-vm-size $VM_SKU --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

> The creation process will take about 5-10 minutes.

3. Once complete, connect the cluster to your local client machine.

```powershell
az aks get-credentials --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

> [!NOTE]
> The command merges the cluster credentials into `C:\Users\LabUser\.kube\config`. No additional copy command is required in PowerShell.

4. Confirm the connection to the cluster.

```powershell
kubectl get nodes
```

This should return a list of nodes similar to the one below:

![kubectl get nodes output showing cluster nodes](content/node-list.png)

[Module 1: Kubernetes Fundamentals](#module-1-kubernetes-fundamentals)

[List of Modules](#modules-list)

## Exercise: Creating a Pod Declaratively

This Exercise demonstrates the use of a YAML file to create a pod declaratively.

### Task 1 - Create a Pod declaratively

1. Change to the lab directory.

```powershell
Set-Location C:\K8s\Labs
```

2. Use the YAML file provided to create a Pod. You may want to open the **Module1/simple-pod.yaml** file and review its contents.

The pod definition contains the **Nginx** container that listens to port 80.

```powershell
kubectl apply -f Module1/simple-pod.yaml
```

3. Now, make sure pod is up and running.

```powershell
kubectl get pods
```

You should see a pod named **nginx-pod**

![kubectl get pods output showing nginx-pod](content/simple-pod.png)

4. Add a second pod, then check the list again.

```powershell
kubectl apply -f Module1/simple-pod2.yaml
kubectl get pods
```

### Task 2 - Filter pods based on a label

1. Show all the labels in the pods

```powershell
kubectl get pods --show-labels
```

![kubectl get pods --show-labels output](content/pod-list-labels.png)

2. Let's say you want to list pods that have a label named **kind=web** associated with them. You can use **-l** switch to apply filter based on labels.

```powershell
kubectl get pod -l kind=web
```

3. To prove that this works as expected, run the command again but change the value of label **kind** to **db**. Notice, this time _kubectl_ doesn't return any pods because there are no pods that match the label **kind** and a value of **db**.

```powershell
kubectl get pod -l kind=db
```

### Task 3 - View complete definition of the Pod

1. Query Kubernetes to return the complete definition of a Pod from its internal database by exporting the output (**-o**) to **YAML**. Then pipe the result to a file.

```powershell
kubectl get pods nginx-pod -o yaml > mypod.yaml
```

> To view the JSON version, use the **-o json** flag instead.

2.  View the contents of the generated file in VS Code (or an editor of your choice).

```powershell
code mypod.yaml
```

![kubectl get pods -o yaml output in VS Code](content/pod-details.png)

**NOTE:** Observe all the properties that Kubernetes populated with default values when it saved the Pod definition to its database.

[Module 1: Kubernetes Fundamentals](#module-1-kubernetes-fundamentals)

[List of Modules](#modules-list)

## Exercise: Working with labels

In this Exercise, you will create a pod that has labels associated with it. Labels make it easy to filter the pods later. Labels play a vital role in the Kubernetes ecosystem, so it's important to understand their proper usage.

### Task 1 - Assign a new label to a running Pod

1. Assign a new label (key=value) pair to a running pod. This comes in handy when you are troubleshooting an issue and would like to distinguish between different pod(s). Assign a new label **health=fair** to the pod **nginx-pod**, which is already running.

```powershell
kubectl label pod nginx-pod health=fair
```

2. Run the command below to show the pod labels. Notice that now an additional label is shown with the pod.

```powershell
kubectl get pods nginx-pod --show-labels
```

### Task 2 - Update an existing label that is assigned to a running pod

1. Update the value of an existing label that is assigned to a running pod. Change the value of the label **kind=web** to **kind=db** of the **nginx-pod** pod.

```powershell
kubectl label pod nginx-pod kind=db --overwrite
```

**--overwrite** is needed because the pod is running and won't accept changes otherwise.

2. Show the pod labels again. Notice that _kind_ has changed from **web** to **db**.

```powershell
kubectl get pods --show-labels
```

### Task 3 - Delete a label that is assigned to a running Pod

1. Delete the label **health** from the **nginx-pod** pod.

```powershell
kubectl label pod nginx-pod health-
```

**NOTE:** Notice the minus (**-**) sign at the end of the command. You can also remove a label from all running pods by using the **--all** flag.

```powershell
kubectl label pod --all health-
```

2. Run the command below to show the pod labels again. Notice that _health_ is not part of the list of labels.

```powershell
kubectl get pods --show-labels
```

### Task 4 - Delete Pods based on their labels

1. Delete all the Pods that match a specific label.

```powershell
kubectl delete pod -l target=dev
```

[Module 1: Kubernetes Fundamentals](#module-1-kubernetes-fundamentals)

[List of Modules](#modules-list)

## Exercise: Working with Deployments

In this Exercise, you will create a Deployment and rollout an application update. Deployments provide a consistent mechanism to upgrade an application to a new version, while keeping the downtime to a minimum. Note that internally, Deployments use _ReplicaSets_ for managing Pods. However, you never work directly with _ReplicaSets_ since Deployments abstract out that interaction.

### Task 1 - Create a new Deployment

The **ng-dep.yaml** file contains a Deployment manifest. The Pod in the _template_ contains an _nginx_ container with a tag **1.0**. The **1.0** represents the version of this container and hence of the application running inside it.

1. Create a Deployment and a Service to access the Pods of the deployment.

```powershell
kubectl apply -f Module1/ng-dep.yaml
kubectl apply -f Module1/ng-svc.yaml
```

2. Run the following command to see the Pods, ReplicaSets, Deployments and Services that were created.

```powershell
kubectl get all --show-labels
```

![kubectl get all --show-labels output](content/get-all.png)

### Task 2 - Access version 1.0 of application

1. Wait about 3-4 minutes to allow Azure to create a Public IP address for the service. Check to see if an address has been assigned by getting the list of services.

```powershell
kubectl get svc
```

![kubectl get svc output with EXTERNAL-IP column](content/services.png)

2. When you see an **EXTERNAL-IP** assigned, open a browser with that address. Example: **http://20.81.24.216**

![nginx version 1.0 sample webpage](content/kube1.png)

### Task 3 - Update the Deployment to version 2.0

You are now going to update the Deployment to use version **2.0** of the container instead of **1.0**. This can be done in one of two ways. One approach is to use _imperative_ syntax, which is faster and is often used during the development/testing stage of an application. The alternate method is to update the YAML file and then to reapply it to the cluster.

1. To start rolling out the new update, change the container image tag from **1.0** to **2.0** by running this command:

```powershell
kubectl set image deployment ng-dep nginx=k8slab/nginx:2.0
```

2. In the command above, **ng-dep** is the name of Deployment and **nginx** is the name of the container within the Pod template. The change will force the Deployment to create a new ReplicaSet with an image tagged **2.0**.

3. List all the pods and notice that old pods are terminating and that new Pods have been created.

```powershell
kubectl get pods
```

4. Run the following command to review the Deployment definition with the updated value of container image:

```powershell
kubectl describe deployment ng-dep
```

![kubectl describe deployment ng-dep output showing image 2.0](content/kube-describe.png)

> Notice the Image section (under Containers) shows the value of container image as **2.0**.

5. Run the command to view the Pods, ReplicaSets and Deployments again.

```powershell
kubectl get all
```

![kubectl get all output showing v2 ReplicaSet](content/get-all-2.png)

> Notice that the old replica set still exists, even though it has 0 Desired Pods.

6. List the ReplicaSets and identify the earlier ReplicaSet that has `0` in the `DESIRED`, `CURRENT`, and `READY` columns.

```powershell
kubectl get rs
```

7. Run the _describe_ command on that old ReplicaSet.

```powershell
$OLD_REPLICASET = Read-Host "Enter the old ReplicaSet name from the previous output"
kubectl describe rs $OLD_REPLICASET
Or
kubectl describe rs <old-replicaset-name>
```

![kubectl describe replicaset showing previous version](content/old-rs.png)

> Notice that the old definition still has the previous version number. This is maintained so you can roll back the change to that version if you wish.

8. Access the 2.0 version of application by refreshing the browser at the same address as above.

![nginx version 2.0 sample webpage](content/kube2.png)

### Task 4 - Rollback the Deployment

The purpose of maintaining the previous **ReplicaSet** is to be able to rollback changes to any previous version.

1. Review the deployment history.

```powershell
kubectl rollout history deploy/ng-dep
```

2. Rollback the Deployment to the previous version.

```powershell
kubectl rollout undo deploy/ng-dep
```

3. Wait a few seconds and refresh the browser again.

![nginx version 1.0 sample webpage after rollback](content/kube1.png)

> Notice the site is back to the previous version.

### Task 5 - Delete the Deployment and Service

1. Delete the Deployment and Service.

```powershell
kubectl delete deployment ng-dep
kubectl delete service ng-svc
```

**NOTE:** It may take a few minutes to delete the service because has to delete the Public IP resource in Azure.

[Module 1: Kubernetes Fundamentals](#module-1-kubernetes-fundamentals)

[List of Modules](#modules-list)

## Exercise: Working with Services

In this Exercise you will create a simple Service. Services help you expose Pods externally using label selectors.

### Task 1 - Create a new Service

1. Create a deployment.

```powershell
kubectl apply -f Module1/sample-dep.yaml
```

2. The **sample-svc.yaml** file contains a Service manifest. Services use label selectors to determine which Pods it needs to track and forward the traffic to.

3. Review running Pods and their labels.

```powershell
kubectl get pods --show-labels
```

> Notice the label **sample=color** that is associated with the Pods.

4. Open the **sample-svc.yaml** file and examine the **selector** attribute. Notice the **sample: color** selector. This Service will track all Pods that have a label **sample=color** and load balance traffic between them.

5. Create the Service.

```powershell
kubectl apply -f Module1/sample-svc.yaml
```

6. Check the details of the newly created service.

```powershell
kubectl get svc -o wide
```

The command above will display the details of all available services along with their label selectors. You should see the **sample-svc** Service with **PORTS 80:30101/TCP** and **SELECTOR sample=color**.

#### Optional fallback if the original image cannot be pulled

Skip this section if the original Pods are running. If they remain in
`ErrImagePull` or `ImagePullBackOff`, inspect the Events before continuing:

```powershell
kubectl get pods -l app=sample-dep
kubectl describe pods -l app=sample-dep
```

Use this fallback when the Events show that `k8slab/podip:1.0` is unavailable
or access is denied. It does not resolve cluster networking, DNS or registry
rate-limit failures.

The backup manifests is preloaded on the Skillable VM as `C:\k8s\labs\module1\app\deployment.yaml` and `C:\k8s\labs\module1\app\service.yaml`.
If they are missing, contact your instructor before continuing. Learners do not need Docker or a Docker Hub login to deploy the published public image.

Run these commands in PowerShell. They use absolute manifest paths, so you
can remain in `C:\k8s\labs`:

```powershell
$APP = "C:\k8s\labs\module1\app"
$IMAGE = "docker.io/oreakinodidi/podinfo:1.0.0"
$NAMESPACE = "default"

kubectl config current-context

kubectl set image --local -f "$APP\deployment.yaml" "sample=$IMAGE" -o yaml |
    kubectl apply -n $NAMESPACE -f -

kubectl apply -n $NAMESPACE -f "$APP\service.yaml"
kubectl rollout status deployment/sample-dep -n $NAMESPACE --timeout=180s
kubectl get pods -n $NAMESPACE -l app=sample-dep -o wide
```

Confirm the current context is your lab cluster before applying the manifests.
Continue only after the rollout succeeds. The fallback updates the existing `sample-dep` Deployment and `sample-svc` Service; it does not create a separate exercise. Both manifests are required because the backup app needs Downward API environment variables and listens on container port `8080`, not `80`.

Do not reapply `Module1/sample-svc.yaml` after switching to the backup.

Continue with Task 2 to start port-forwarding and open the page. The backup
page has a different design from the screenshot below, but displays the same
Pod/node information. Task 3 cleans up either version using the same names.

### Task 2 - Access the sample-svc Service

1. The uploaded `sample-svc.yaml` defines a `NodePort` Service on port `30101`,
   not a `LoadBalancer` Service with an external IP. Forward its HTTP port to
   the lab VM:

```powershell
kubectl port-forward service/sample-svc 8080:80
```

Open <http://localhost:8080> in the VM's browser. Keep port-forwarding running
until you finish this task, then press **Ctrl+C**.

![sample service webpage showing pod IP address](content/sample-svc.png)

2. The website displays the selected Pod's IP information. A port-forward
   session targets one Pod, so refreshing this URL does not demonstrate load
   balancing across replicas. Inspect the Service's backing endpoints in a
   second PowerShell window:

```powershell
kubectl get endpointslices -l kubernetes.io/service-name=sample-svc
```

### Task 3 - Delete the Deployment and Service

Deleting any Pod will simply tell Kubernetes that the Deployment is not in its _desired_ state and it will create a replacement. You can only delete Pods by deleting the Deployment.

1. Delete the Deployment.

```powershell
kubectl delete deployment sample-dep
```

2. The Service is independent of the Pods it services, so it's not affected when the Deployment is deleted. Anyone trying to access the service's address will simply get a 404 error. If the Deployment is ever re-created, the Service will automatically start sending traffic to the new Pods.
3. Delete the Service.

```powershell
kubectl delete service sample-svc
```

## Exercise: Working Ephemeral Volumes, secrets and ConfigMaps

This exercise shows how multiple containers within the same pod can use volumes to communicate with each other and how you can use _ConfigMaps_ to mount settings files into containers.

The example Deployment below configures a MySQL instance to write its activities to a log file. Another container reads that log file, and in a production setting, would send the contents to an external log aggregator. In this example, the 2nd container just outputs the _tail_ of the log file to the console.

### Task 1 - Review and deploy ConfigMaps 

1. Open a Windows Terminal window (defaults to PowerShell).

![Windows Terminal icon in taskbar](content/windows-terminal.png)

2. Review the **Module1/mysql-initdb-cm.yaml** file.

```powershell
Get-Content Module1/mysql-initdb-cm.yaml
```

This sql script will be used to initialize the database, no need to edit the file.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-initdb-cm
data:
  initdb.sql: |
    CREATE DATABASE sample;
    USE sample;
    CREATE TABLE friends (id INT, name VARCHAR(256), age INT, gender VARCHAR(3));
    INSERT INTO friends VALUES (1, 'John Smith', 32, 'm');
    INSERT INTO friends VALUES (2, 'Lilian Worksmith', 29, 'f');
    INSERT INTO friends VALUES (3, 'Michael Rupert', 27, 'm');
```

When the ConfigMap is mounted in a container, it will create a file called **initdb.sql**.

4. Deploy the ConfigMap.

```powershell
kubectl apply -f Module1/mysql-initdb-cm.yaml
```

5. Configure MySql to generate activity logs and save them to a file. Review the contents of **mysql-cnf-cm.yaml**. This file will replace the default **my.cnf** config file in the container.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-cnf-cm
data:
  my.cnf: |
    !includedir /etc/mysql/conf.d/
    !includedir /etc/mysql/mysql.conf.d/

    [mysqld]
    #Set General Log
    general_log = on
    general_log_file=/usr/log/general.log
```

6. Deploy the ConfigMap.

```powershell
kubectl apply -f Module1/mysql-cnf-cm.yaml
```

### Task 2 - Review and deploy multi-container Deployment

1. Review the Volumes section of **mysql-dep.yaml**.

```yaml
volumes:
  - name: mysql-initdb
    configMap:
      name: mysql-initdb-cm
  - name: mysql-cnf
    configMap:
      name: mysql-cnf-cm
  - name: mysql-log
    emptyDir: {}
```

> Notice that both ConfigMaps are being mapped to volumes and an empty directory is being created for the logs.

2. Review the volumeMounts section of **mysql-dep.yaml**.

```yaml
volumeMounts:
  - name: mysql-initdb
    mountPath: /docker-entrypoint-initdb.d
  - name: mysql-cnf
    mountPath: /etc/mysql/my.cnf
    subPath: my.cnf
  - name: mysql-log
    mountPath: /usr/log/
```

The init file is mapped to the known MySql folder. Anything placed in that folder is executed by MySql during startup.

The config file is mapped to the MySql config folder. However, there are other config files already in that folder that MySql needs to access. As a result, replacing the entire folder with the contents of the ConfigMap will prevent MySql from working, because the other config files won't be there.

That's where the _subPath_ property comes into play. It allow you to mount only a subset of your volume (in this case only a single file), leaving the existing content in place at the destination.

The final mount points to the empty directory created to hold the logs.

3. Review the second container definition.

```yaml
- name: logreader
  image: busybox
  command:
    - "/bin/sh"
  args:
    - "-c"
    - "tail -f /usr/log/general.log;"
  volumeMounts:
    - name: mysql-log
      mountPath: /usr/log/
```

> Notice that the same empty directory is mounted to this container and that the container simply executes a _tail_ command, outputting the last line in the file.

4. Apply the deployment.

```powershell
kubectl apply -f Module1/mysql-dep.yaml
```

### Task 3 - Confirm communications between containers

1. Get list of Pods.

```powershell
kubectl get pods
```

2. Once the Pod is running, look at the log of the second container.

```powershell
kubectl logs -c logreader -f "name of mysql-dep-xxxxx pod"
```

3. Open another shell window and execute into the first container

```powershell
kubectl exec -it -c mysql "name of mysql-dep-xxxxx pod" -- bash
```

4. In the shell, type **mysql** to enter the MySql console.

```bash
mysql
```

5. Type the following commands in the **_mysql>_** prompt:

```sql
use sample;
select * from friends;
```

6. Switch to the other window and verify that the second container is showing the log.

![MySQL activity log tail output in container](content/sqllog.png)

7. Exit out of the **MySql** console.

```sql
exit;
```

8. Exit out of the container.

```bash
exit
```

> **Note:** Cluster ingress (exposing HTTP services through a controller) is covered in **Module 3.b — AKS Ingress with Application Gateway for Containers**.

[List of Modules](#modules-list)

## Shutdown or Delete the Cluster

> **Reminder:** Module 2 reuses this same cluster. Skip this section until you have completed Module 2 — or, if you plan to do Module 2 right after Module 1, just continue.

When you're done for the day, you can shutdown your cluster to avoid incurring charges when you're not using it. This will delete all your nodes, but keep your configuration in tact.

```powershell
az aks stop --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

Or you can choose to delete the entire resource group instead. You can create a new one prior to the next lab.

```powershell
az group delete --resource-group $RESOURCE_GROUP
```


# Module 2: What is AKS?

This module covers AKS-specific extras that build on the basic Kubernetes cluster from Module 1: enabling **Azure Policy** for governance, **KEDA** for event-driven autoscaling, and the **Dapr** cluster extension for distributed application building blocks. You will then deploy the AKS Store demo app.

References:
- [Azure Policy for AKS](https://learn.microsoft.com/azure/aks/use-azure-policy)
- [KEDA on AKS](https://learn.microsoft.com/azure/aks/keda-about)
- [Dapr extension for AKS](https://learn.microsoft.com/azure/aks/dapr)

## Reusing the Module 1 Cluster

> **You can reuse the AKS cluster you created in Module 1.** If `$AKS_NAME` and `$RESOURCE_GROUP` are still set in your shell and `kubectl get nodes` works, **skip ahead to [Enabling Add-ons and extensions](#enabling-add-ons-and-extensions)**.
>
> The next two sections (login + create cluster) are only needed if you skipped Module 1 or want to start from a fresh cluster.

## Deploying a Cluster (only if needed)

### Task 1 - Login into your subscription and register providers

1. Open a Windows Terminal window using PowerShell.

![Windows Terminal icon in taskbar](content/windows-terminal.png)

> Windows Terminal allows you to open tabbed command terminals.

2. Login to Azure.

```powershell
az login
```

!IMAGE[azlogin.jpg](instructions285565/azlogin.jpg)
Choose Work or school Account
Click on Username and password to Autofill and Authenticate.

3. Set the current subscription.

Post Authentication, below screen shows up with the pre-defined Subscription to choose.
Select 1 and enter.

!IMAGE[subchoose.jpg](instructions287320/subchoose.jpg)

4. Register needed providers.

```powershell
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Kubernetes
```

5. Open a browser and navigate to the Azure Portal: **_portal.azure.com_**

6. Search for and open the **Subscriptions** blade. Select your **Azure** subscription.

7. Scroll down and select **Resource providers**.


!IMAGE[azure-resources.jpg](instructions287320/azure-resources.jpg)
8. Confirm the following required providers are registered. Select **Register** for any provider whose status is **NotRegistered**, then select **Refresh** until its status is **Registered**: **Microsoft.Storage**, **Microsoft.Compute**, **Microsoft.Network**, **Microsoft.Monitor**, **Microsoft.Insights**, **Microsoft.ManagedIdentity**, **Microsoft.OperationalInsights**, **Microsoft.OperationsManagement**, **Microsoft.KeyVault**, **Microsoft.ContainerRegistry**, **Microsoft.ContainerService**, and **Microsoft.Kubernetes**.

### Task 2 - Define variables and create resource group

1. Define global variables.

**WARNING**: When using Azure regions you could run into deployment issues in high demand regions. Consult your delivering CSA for guidance if you run into issues. Available regions: Central US, East US 2, Sweden Central, West US

```powershell
$RESOURCE_GROUP = "azure-rg"
$LOCATION = "eastus2"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
```

2. Set the VM SKU to the default below.

**WARNING**: VM SKUs can change per region use the default first then fall back to other available SKUS. Consult your CSA for guidance. Available SKUS: Standard_D2as_v5, Standard_A2m_v2, Standard_D2s_v5, Standard_D2ads_v5

```powershell
$VM_SKU = "Standard_D2as_v5"
```

### Task 3 - Create a basic cluster using Azure CLI

1. Define variables for AKS cluster.

```powershell
$AKS_NAME = "aks-@lab.LabInstance.Id"
echo "AKS Cluster Name: $AKS_NAME"
```

2. Create the resource group and AKS cluster.

```powershell
az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create --node-count 2 --generate-ssh-keys --node-vm-size $VM_SKU --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

> The creation process will take about 5-10 minutes.

3. Once complete, connect the cluster to your local client machine.

```powershell
az aks get-credentials --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

> [!NOTE]
> The command merges the cluster credentials into `C:\Users\LabUser\.kube\config`. No additional copy command is required in PowerShell.

4. Confirm the connection to the cluster.

```powershell
kubectl get nodes
```

This should return a list of nodes similar to the one below:

![kubectl get nodes output showing cluster nodes](content/node-list.png)


## Enabling Add-ons and extensions

### Enabling Add-ons

#### Installing Azure Policy

**Azure Policy for AKS** evaluates Kubernetes resources against built-in or custom policy definitions enforced through Gatekeeper / OPA. Use it to require specific labels, restrict images to approved registries, block privileged Pods, etc.

In the Azure Portal, open your subscription's **Resource providers** page and confirm that **Microsoft.PolicyInsights** is registered. Select **Register** if needed, then select **Refresh** until its status is **Registered**.

Enable the Azure Policy add-on.

```powershell
az aks enable-addons --addons azure-policy --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

Check for the Azure Policy addon pod (installed in `kube-system`).

```powershell
kubectl get pods -n kube-system
```

Check for the Gatekeeper pods (installed in `gatekeeper-system`).

```powershell
kubectl get pods -n gatekeeper-system
```

Finally, query the cluster to confirm the addon is enabled.

```powershell
az aks show --query addonProfiles.azurepolicy -g $RESOURCE_GROUP -n $AKS_NAME
```

You can now apply Azure Policy assignments at the subscription / resource-group / cluster scope to audit or enforce desired configurations.

#### Installing KEDA

**KEDA (Kubernetes Event-driven Autoscaling)** scales workloads based on external event sources (queue length, Prometheus metrics, Service Bus, etc.) — extending HPA beyond CPU/memory.

Install the KEDA addon.

```powershell
az aks update --resource-group $RESOURCE_GROUP --name $AKS_NAME --enable-keda
```

Verify the installation.

```powershell
az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "workloadAutoScalerProfile.keda.enabled"
```

KEDA is now available in the cluster.

### Enabling Extensions

**Dapr (Distributed Application Runtime)** provides building blocks (state, pub/sub, secret store, service invocation) as sidecars. The AKS cluster extension installs and manages Dapr for you.

Install the `k8s-extension` Azure CLI extension.

```powershell
az extension add --name k8s-extension
```

Update the extension.

```powershell
az extension update --name k8s-extension
```

Check if the `Microsoft.KubernetesConfiguration` provider is registered.

```powershell
az provider list --query "[?contains(namespace,'Microsoft.KubernetesConfiguration')]" -o table
```

If it is not registered, open your subscription's **Resource providers** page in the Azure Portal. Select **Microsoft.KubernetesConfiguration**, select **Register**, and then select **Refresh** until its status is **Registered**.

Install the Dapr extension on the cluster (latest stable; this command may take a few minutes).

```powershell
az k8s-extension create --cluster-type managedClusters --cluster-name $AKS_NAME --resource-group $RESOURCE_GROUP --name dapr --extension-type Microsoft.Dapr --auto-upgrade-minor-version false
```

> If the CLI prompts asking whether Dapr is already installed (only relevant if you have an existing OSS Dapr install on the cluster), answer **N** and press Enter. On a fresh cluster this prompt will not appear.

> [!NOTE]
> If Azure Policy denies the Dapr extension, use the policy assignment and definition IDs in the error to identify the exact blocking rule in **Azure Policy** > **Compliance**. Ask your Azure Policy administrator to allow the Dapr extension or, when governance permits, create a narrowly scoped exemption for this AKS cluster. Do not exempt unrelated policies or a broader scope.

These exercises demonstrate how to provision an AKS cluster, enable add-ons, and install cluster extensions.

## Deploying workloads to nodes

### Deploying the AKS Store Demo app

Download the YAML manifest.

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -OutFile aks-store-all-in-one.yaml
```
or 

```sh
wget https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -O aks-store-all-in-one.yaml
```

Create a namespace for the sample app.

```powershell
kubectl create namespace pets
```

Apply the manifest.

```powershell
kubectl apply -f aks-store-all-in-one.yaml -n pets
```

Wait until `store-front` receives an external IP, then open it in your browser.

```powershell
kubectl get services -n pets
```

## Deleting the cluster

When you are done with **both Module 1 and Module 2**, delete the cluster.

```powershell
az aks list -o table
```

```powershell
az aks delete --name $AKS_NAME --resource-group $RESOURCE_GROUP --yes --no-wait
```

[List of Modules](#modules-list)

# Module 3: AKS Networking

```powershell
Set-Location C:\k8s\labs
```

This module is hands-on. It contains two labs that walk through the main networking concerns on AKS: **ingress** (Lab 1, Application Gateway for Containers) and **in-cluster network policy & observability** (Lab 2, Advanced Container Networking Services with Cilium).

## Lab 1: Ingress with Application Gateway for Containers

Lab 1 of this module is the existing AGC walkthrough. Jump to [Module 3.b: AKS Ingress with Application Gateway for Containers](#module-3b-aks-ingress-with-application-gateway-for-containers) and return here when done.

## Lab 2: Advanced Container Networking Services (Optional)

In this optional lab you will enable **Advanced Container Networking Services (ACNS)** on a new AKS cluster, observe network flows with **Hubble**, restrict egress with an **FQDN-based** Cilium policy, and lock down a service to a single HTTP method with an **L7** Cilium policy.

Reference: [Advanced Container Networking Services overview](https://learn.microsoft.com/azure/aks/advanced-container-networking-services-overview), [Apply FQDN filtering policies](https://learn.microsoft.com/azure/aks/how-to-apply-fqdn-filtering-policies), [Apply L7 policies](https://learn.microsoft.com/azure/aks/how-to-apply-l7-policies).

> **This lab requires a fresh cluster.** ACNS with the Cilium dataplane (`--network-dataplane cilium`) cannot be enabled on an existing non-Cilium cluster — the dataplane is set at create time only. If you already have an AKS cluster from a previous module under the same name, delete it first:
>
> ```powershell
> az aks delete -g azure-rg -n aks-@lab.LabInstance.Id --yes
> ```

### Task 1 – Create an AKS cluster with ACNS + Cilium + L7

Specify the node pool name and an approved VM size explicitly. The workshop
policy rejects unapproved pool/size combinations, so do not rely on the Azure
CLI's default VM size. If `Standard_D2as_v5` is unavailable, use another approved
size (`Standard_D2s_v5`, `Standard_D2ads_v5` or `Standard_A2m_v2`) after checking
regional availability and subscription quota.

```powershell
$RESOURCE_GROUP = "azure-rg"
$LOCATION = "eastus2"
$AKS_NAME = "aks-@lab.LabInstance.Id"
$VM_SKU = "Standard_D2s_v5"

az group create --name $RESOURCE_GROUP --location $LOCATION

az aks create `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --location $LOCATION `
  --node-count 2 `
  --nodepool-name nodepool1 `
  --node-vm-size $VM_SKU `
  --network-plugin azure `
  --network-plugin-mode overlay `
  --network-dataplane cilium `
  --enable-acns `
  --acns-advanced-networkpolicies L7 `
  --generate-ssh-keys

az aks get-credentials -g $RESOURCE_GROUP -n $AKS_NAME
kubectl get nodes
```

> `--enable-acns` turns on Container Network Observability and FQDN filtering. `--acns-advanced-networkpolicies L7` additionally enables Layer 7 policies (HTTP / gRPC / Kafka). L7 is Cilium-only.

### Task 2 – Deploy the demo application

```powershell
kubectl apply -f Module3/networking-demo-app.yaml
kubectl -n acns-demo get pods
```

Validate baseline connectivity (no policies yet, everything is allowed):

```powershell
kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "server: %{http_code}\n" http://http-server
kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "example: %{http_code}\n" https://example.com
```

### Task 3 – Restrict egress with an FQDN policy

```powershell
kubectl apply -f Module3/networking-fqdn-policy.yaml
```

Retest:

```powershell
# Allowed FQDN
kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "example: %{http_code}\n" https://example.com

# Different FQDN – should fail (timeout / connection refused)
kubectl -n acns-demo exec deploy/http-client -- curl -sS --max-time 5 -o /dev/null -w "bing: %{http_code}\n" https://www.bing.com
if ($LASTEXITCODE -ne 0) { Write-Host "Blocked as expected; compare with the allowed request above." }
```

> The policy in `C:\k8s\labs\Module3\networking-fqdn-policy.yaml` allows DNS to `kube-dns` and HTTPS only to `example.com`. Cilium learns the IPs of `example.com` from the DNS responses and programs eBPF rules on the fly.

### Task 4 – Apply a Layer 7 policy to the server

```powershell
kubectl apply -f Module3/networking-l7-policy.yaml
```

```powershell
# Allowed: GET /
kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "GET /: %{http_code}\n" http://http-server/

# Denied: GET /index.html (path doesn't match the policy)
kubectl -n acns-demo exec deploy/http-client -- curl -sS -o /dev/null -w "GET /index.html: %{http_code}\n" http://http-server/index.html

# Denied: POST / (method doesn't match the policy)
kubectl -n acns-demo exec deploy/http-client -- curl -sS -X POST -o /dev/null -w "POST /: %{http_code}\n" http://http-server/
```

> Requests not matching the L7 rule are rejected by the in-node Envoy proxy with HTTP 403 – the connection succeeds at L4 but the application response is denied.

### Task 5 – Observe flows with Hubble

```powershell
New-Item -ItemType Directory -Path C:\k8s\tools\hubble -Force
curl.exe -fL -o "$env:TEMP\hubble-windows-amd64.tar.gz" https://github.com/cilium/hubble/releases/latest/download/hubble-windows-amd64.tar.gz
if ($LASTEXITCODE -ne 0) { throw "Hubble download failed." }
tar.exe -xzf "$env:TEMP\hubble-windows-amd64.tar.gz" -C C:\k8s\tools\hubble
if ($LASTEXITCODE -ne 0) { throw "Hubble extraction failed." }
kubectl port-forward -n kube-system svc/hubble-relay 4245:443
```

Leave the port-forward running. In a second PowerShell window, observe flows:

```powershell
$env:HUBBLE_SERVER = "localhost:4245"
$env:HUBBLE_TLS_DISABLE = "true"
& C:\k8s\tools\hubble\hubble.exe observe --namespace acns-demo --type l7 --follow
```

In another terminal generate traffic with the curl commands from Task 4 and watch the L7 verdicts (`FORWARDED`, `DROPPED` with reason) appear in real time.

For a managed dashboard view, attach an Azure Managed Grafana workspace to the cluster and use the **Cilium Hubble – L7 Flows** dashboard.

### Task 6 – Cleanup

```powershell
kubectl delete -f Module3/networking-l7-policy.yaml --ignore-not-found
kubectl delete -f Module3/networking-fqdn-policy.yaml --ignore-not-found
kubectl delete -f Module3/networking-demo-app.yaml --ignore-not-found

# Or simply delete the lab resource group
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

[List of Modules](#modules-list)

# Module 3.b: AKS Ingress with Application Gateway for Containers

In this lab you will integrate AKS with **Application Gateway for Containers (AGC)** to expose containerized workloads through a managed L7 load balancer driven by the Kubernetes **Gateway API**. AGC replaces the older Application Gateway Ingress Controller (AGIC) and is the recommended Azure ingress option for new clusters.

We install the ALB Controller as an **AKS add-on** (`--enable-application-load-balancer`). The add-on automatically provisions the controller's managed identity, federated credential, role assignments, and a delegated subnet for AGC — no manual Helm chart, identity, or RBAC steps required.

References:
- [Application Gateway for Containers overview](https://learn.microsoft.com/azure/application-gateway/for-containers/overview)
- [Quickstart: Deploy ALB Controller using AKS Add-on](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon)
- [Quickstart: Create AGC managed by ALB Controller](https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller?tabs=new-subnet-aks-vnet)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

## AKS Setup

Prepare your Azure subscription and your `az` CLI.

```powershell
az login

# Display the Azure CLI core version before installing preview extensions
az version

# Register required resource providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking

# Install the CLI extensions used by the add-on
az extension add --name aks-preview --upgrade
az extension add --name alb         --upgrade

# Register the preview features for the Gateway API + ALB add-ons
az feature register --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview
az feature register --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview

# Wait until both features report Registered
az feature show --namespace Microsoft.ContainerService --name ManagedGatewayAPIPreview        --query properties.state
az feature show --namespace Microsoft.ContainerService --name ApplicationLoadBalancerPreview  --query properties.state

```

> [!IMPORTANT]
> If either extension command fails or the add-on flags are unavailable, update the Azure CLI core and rerun both extension commands. Updating an extension does not update the Azure CLI core. The AGC add-on quickstart does not publish a fixed minimum CLI version, so use a currently supported Azure CLI instead of relying on a hard-coded version threshold.

If `az aks create` or `az aks update` fails with `ValueError: too many values to unpack (expected 3)`, the traceback can indicate a compatibility issue between the Azure CLI core and `aks-preview`, rather than an Azure Policy denial. In an Administrator PowerShell window on the lab VM, upgrade the CLI and its installed extensions:

```powershell
az upgrade --yes
```

After the upgrade completes successfully, close and reopen PowerShell, then run `az version` to confirm the updated versions. Set the cluster variables again before retrying the appropriate command below. If the cluster already exists, use `az aks update`, not `az aks create`. If the same error persists, capture the new `az version` output and traceback for the lab administrator; do not delete the cluster or change the policy to resolve this CLI error.

In the Azure Portal, open your subscription's **Resource providers** page and confirm that **Microsoft.ContainerService**, **Microsoft.Network**, **Microsoft.NetworkFunction**, and **Microsoft.ServiceNetworking** are registered. Select **Register** for any provider that is not registered, then select **Refresh** until its status is **Registered**. After both preview features report `Registered`, select **Microsoft.ContainerService**, select **Register**, and refresh its status.

> Feature registration is **subscription-scoped** and one-time. Once both features show `Registered`, you don't need to repeat these steps in subsequent lab runs on the same subscription.

### Create or reuse the AKS Cluster

Set the cluster variables. We use the same cluster name across all modules — if a previous module already created this cluster you'll reuse it; otherwise you'll create it fresh.

```powershell
$AKS_NAME = 'aks-@lab.LabInstance.Id'
$RESOURCE_GROUP = 'azure-rg'
$LOCATION = 'eastus2' # AGC must be available in this region — see the regions list in the AGC overview doc
$VM_SIZE = 'standard_d2s_v5'
```

If the cluster already exists, simply enable the Gateway API + Application Load Balancer add-ons via `az aks update`:

```powershell
az aks update `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --enable-oidc-issuer `
  --enable-workload-identity `
  --enable-gateway-api `
  --enable-application-load-balancer
```

Otherwise, create a new AKS cluster with Azure CNI, OIDC issuer, workload identity, and both add-ons enabled at create time:

```powershell
az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --location $LOCATION `
  --node-vm-size $VM_SIZE `
  --network-plugin azure `
  --enable-oidc-issuer `
  --enable-workload-identity `
  --enable-gateway-api `
  --enable-application-load-balancer `
  --generate-ssh-key
```

> The add-on requires Azure CNI (or Azure CNI Overlay), workload identity, and a region where AGC is available. Enabling the add-on also enables the Gateway API add-on, which is required.

Get cluster credentials:

```powershell
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing
```

## Application Gateway for Containers

### Verify the ALB Controller add-on

The add-on installs the ALB Controller pods in the `kube-system` namespace and registers the `azure-alb-external` GatewayClass. It also creates:

- A user-assigned managed identity named `applicationloadbalancer-<cluster-name>` in the cluster's MC resource group, with `Network Contributor`, `AppGw for Containers Configuration Manager`, and `Reader` role assignments scoped to the MC RG.
- A federated credential `aksfic` bound to the `kube-system/alb-controller-sa` service account.
- A delegated subnet `aks-appgateway` in the cluster's VNet (delegation: `Microsoft.ServiceNetworking/trafficControllers`).

Verify the controller pods are running:

```powershell
kubectl get pods -n kube-system -l app=alb-controller
```

You should see two `alb-controller-*` pods in `Running` state.

Verify the `azure-alb-external` GatewayClass is installed and reports `Valid GatewayClass`:

```powershell
kubectl get gatewayclass azure-alb-external -o yaml
```

You can now provision the AGC data-plane resources in Azure.

### Provision a (Managed) Application Gateway for Containers

In this strategy the ALB Controller manages the lifecycle of the AGC resource and its sub-resources, driven by an `ApplicationLoadBalancer` custom resource on the cluster.

#### Locate the add-on's delegated subnet

The add-on already created a delegated subnet (`aks-appgateway`) in the AKS-managed VNet. Discover its resource ID:

```powershell
$MC_RESOURCE_GROUP = $(az aks show --name $AKS_NAME --resource-group $RESOURCE_GROUP --query nodeResourceGroup -o tsv)
$VNET_NAME = $(az network vnet list -g $MC_RESOURCE_GROUP --query '[0].name' -o tsv)
$ALB_SUBNET_ID = $(az network vnet subnet list `
  -g $MC_RESOURCE_GROUP --vnet-name $VNET_NAME `
  --query "[?delegations[?serviceName=='Microsoft.ServiceNetworking/trafficControllers']].id | [0]" -o tsv)
echo "AGC subnet: $ALB_SUBNET_ID"
```

> No manual subnet creation, no role assignments — the add-on already configured all of that.

Create a namespace for the AGC infra resources:

```powershell
kubectl create ns alb-test-infra
```

#### Create an Application Gateway for Containers (`ApplicationLoadBalancer` CR)

```powershell
@"
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb-test
  namespace: alb-test-infra
spec:
  associations:
  - $ALB_SUBNET_ID
"@ | kubectl apply -f -
```

The ALB Controller now provisions the AGC resource in Azure. Watch its status:

```powershell
kubectl get applicationloadbalancer alb-test -n alb-test-infra -o yaml -w
```

> **Provisioning takes 5-10 minutes.** The `Deployment` condition will report `Reason: InProgress` while Azure creates the `Microsoft.ServiceNetworking/trafficControllers` resource and binds it to the `aks-appgateway` subnet. Wait until `Deployment` flips to `Reason: Succeeded` before creating the Gateway.

You can also visualize the managed AGC instance in the Azure Portal.

![Application Gateway for Containers resource](../images/agwc-in-portal.jpg)

#### Create a Gateway

When you create a `Gateway` resource that references the `ApplicationLoadBalancer`, ALB Controller provisions a new AGC Frontend tied to the lifecycle of the Gateway.

```powershell
@"
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: default
  annotations:
    alb.networking.azure.io/alb-namespace: alb-test-infra
    alb.networking.azure.io/alb-name: alb-test
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http-listener
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
"@ | kubectl apply -f -
```

> **The Gateway typically takes 1-2 minutes to be Programmed** after the underlying `ApplicationLoadBalancer` has finished deploying. Watch with `kubectl get gateway gateway-01 -n default -w` until `PROGRAMMED=True` and an `ADDRESS` (FQDN) appears.

Visualize the Frontend in the Azure Portal:

![Application Gateway for Containers frontend](../images/agwc-frontend.jpg)

#### Deploy an example web server and expose it as `HTTPRoute`

Once the AGC infrastructure has been deployed and the Gateway is **Programmed**, deploy a sample app and route traffic to it.

```powershell
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
"@ | kubectl apply -f -
```

Get the Gateway frontend FQDN that AGC assigned:

```powershell
$FRONTEND_FQDN = $(kubectl get gateway gateway-01 -n default -o jsonpath='{.status.addresses[0].value}')
echo "Frontend FQDN: $FRONTEND_FQDN"
```

Expose the application as an `HTTPRoute` (note the `parentRefs.name` matches the Gateway name `gateway-01`):

```powershell
@"
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
  namespace: default
spec:
  parentRefs:
  - name: gateway-01
  hostnames:
  - "$FRONTEND_FQDN"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-app
      port: 80
"@ | kubectl apply -f -
```

#### Test the route

It can take a minute or two for the AGC data plane to pick up the new route.

```powershell
curl.exe -i "http://$FRONTEND_FQDN/"
```

You should get an HTTP 200 with the default NGINX welcome page.

### Cleanup

You have two options depending on whether you plan to continue with later modules on the same cluster:

**Option A — Keep the cluster, drop only the AGC resources** (recommended if you are continuing to Module 4 or later):

```powershell
kubectl delete httproute my-app-route -n default --ignore-not-found
kubectl delete deploy,svc my-app -n default --ignore-not-found
kubectl delete gateway gateway-01 -n default --ignore-not-found
kubectl delete applicationloadbalancer alb-test -n alb-test-infra --ignore-not-found
kubectl delete ns alb-test-infra --ignore-not-found

# Optional: disable the ALB add-on (Gateway API add-on can stay enabled — it has no cost)
az aks update -g $RESOURCE_GROUP -n $AKS_NAME --disable-application-load-balancer
```

**Option B — Done with the workshop, tear everything down**:

```powershell
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

Deleting the resource group removes AKS, the MC resource group (which contains the add-on's managed identity, federated credential, role assignments, and the `aks-appgateway` subnet), and the managed AGC resource in one shot.

[List of Modules](#modules-list)



# Module 4: AKS Scaling

This module contains two hands-on labs that show the **node-level** scalers AKS supports:

- **Lab 1 – Node Auto-Provisioning (NAP)**: AKS-managed Karpenter. The cluster picks the right VM SKU and size for each pending pod, provisions the node, and removes it when no longer needed. Best for spiky/unpredictable workloads.
- **Lab 2 – Cluster Autoscaler**: classic VM Scale Set–based scaler. Adds/removes nodes from a node pool between a fixed `min-count` and `max-count`. Best when you want a single, predictable SKU per node pool.

Both work alongside the **Horizontal Pod Autoscaler (HPA)**, which scales *pods*. In these labs we focus on what happens at the node layer when pending pods can't be scheduled.

References: [Node autoprovisioning (NAP)](https://learn.microsoft.com/azure/aks/node-autoprovision), [Use the cluster autoscaler in AKS](https://learn.microsoft.com/azure/aks/cluster-autoscaler).

## Lab 1: Node Auto-Provisioning (Karpenter on AKS)

NAP brings the upstream [Karpenter](https://karpenter.sh) project to AKS as a managed feature. Instead of you defining a node pool with a fixed VM SKU, you declare a `NodePool` CR with a list of acceptable SKUs/zones/architectures, and Karpenter chooses the cheapest one that fits the pending pod. Reference: [Node autoprovisioning](https://learn.microsoft.com/azure/aks/node-autoprovision).

### Task 1 – Prerequisites

NAP is **generally available** — no preview feature flag or `aks-preview` extension is required. Just confirm your Azure CLI is recent enough (the `--node-provisioning-mode` flag is included in the standard CLI):

```powershell
az --version       # requires 2.76.0 or later
```

If needed, upgrade with `az upgrade` in PowerShell.

### Task 2 – Deploy an AKS cluster with NAP enabled

NAP requires the **Cilium dataplane** with **Azure CNI Overlay**. Set the variables once so the next commands are reusable:

```powershell
$CLUSTER_NAME = "aks-@lab.LabInstance.Id"
$RESOURCE_GROUP_NAME = "azure-rg"
```

> **This lab requires a fresh cluster.** `--node-provisioning-mode Auto` and the Cilium dataplane are set at cluster create only — they cannot be added to an existing cluster via `az aks update`. If a cluster from a prior module already exists under the same name, delete it first:
>
> ```powershell
> az aks delete -g $RESOURCE_GROUP_NAME -n $CLUSTER_NAME --yes
> ```

Create the cluster with `--node-provisioning-mode Auto`. The initial system node pool is small; everything else will be provisioned on-demand by NAP.

```powershell
az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME `
  --node-vm-size 'Standard_D2as_v5' `
  --node-provisioning-mode Auto `
  --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium `
  --generate-ssh-keys
```

> The Karpenter controller runs in the `kube-system` namespace as part of the managed control plane — you don't install it yourself.

Once the cluster is ready, fetch the kubeconfig credentials so `kubectl` can talk to it:

```powershell
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
```

### Task 3 – Define a NodePool that constrains which SKUs NAP can pick

The `NodePool` CR is how you tell Karpenter what kind of nodes it is *allowed* to create. The `requirements` block is a list of label selectors — Karpenter will only choose VM SKUs that satisfy all of them. Reference: [NAP node pool configuration](https://learn.microsoft.com/azure/aks/node-autoprovision#node-pools).

Key fields below:

- `disruption.consolidationPolicy: WhenEmpty` – delete a node as soon as it has no pods.
- `expireAfter: Never` – never recreate nodes just because they're old.
- `karpenter.sh/capacity-type: on-demand` – no spot VMs in this lab.
- `karpenter.azure.com/sku-name` – list of permitted SKUs; Karpenter picks the cheapest one that fits the pending pod.

```powershell
@"
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose On-Demand NodePool"
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1s
    budgets:
      - nodes: "100%"
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      expireAfter: Never
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.azure.com/sku-name
          operator: In
          values:
          - Standard_D2s_v5
          - Standard_A2m_v2
          - Standard_D2as_v5
          - Standard_D2ads_v5
"@ | Set-Content -LiteralPath karp.yaml -Encoding utf8
```

or

```yaml
cat <<EOF > karp.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
  annotations:
    kubernetes.io/description: "General purpose On-Demand NodePool"
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1s
    budgets:
      - nodes: "100%"
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      expireAfter: Never
      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.azure.com/sku-name
          operator: In
          values:
          - Standard_D2s_v5
          - Standard_A2m_v2
          - Standard_D2as_v5
          - Standard_D2ads_v5
EOF
```

Apply the NodePool. From this point on, any pending pod that cannot be scheduled on the existing system node will trigger NAP:

```powershell
kubectl apply -f karp.yaml
```

### Task 4 – Trigger node provisioning with a "pause" deployment

The `inflate` deployment uses the `pause` image (a tiny do-nothing container) and requests **1 CPU per replica**. Starting at `replicas: 0` means no nodes are provisioned yet — they'll be created on the next step when we scale up.

```powershell
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: mcr.microsoft.com/oss/kubernetes/pause:3.6
          resources:
            requests:
              cpu: 1
"@ | Set-Content -LiteralPath deploy.yaml -Encoding utf8
```

or

```bash
cat <<EOF > deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: mcr.microsoft.com/oss/kubernetes/pause:3.6
          resources:
            requests:
              cpu: 1
EOF
```

```powershell
kubectl apply -f deploy.yaml
```

Scale up. The 5 new pods can't fit on the existing system node, so they go `Pending`, and Karpenter creates a new node within ~30 seconds:

```powershell
kubectl scale deployment inflate --replicas 5
```

In another terminal, tail the Karpenter controller logs to watch the provisioning decision (which SKU it chose and why):

```powershell
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
```

You can also watch the new node appear:

```powershell
kubectl get nodes -w
```

### Task 5 – Scale down and observe consolidation

Drop the deployment back to zero. Because `consolidationPolicy: WhenEmpty` was set, Karpenter will tear down the empty node almost immediately:

```powershell
kubectl scale deployment inflate --replicas 0
```

Watch the same Karpenter logs to see the deletion event:

```powershell
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller
```

```powershell
kubectl get nodes
```

### Task 6 – Cleanup

```powershell
az aks delete --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --yes --no-wait
```

[List of Modules](#modules-list)

## Lab 2: Cluster Autoscaler

The cluster autoscaler is the long-standing, GA scaler for AKS. Each node pool gets a fixed VM SKU and a `min`/`max` node count. When the scheduler reports unschedulable pods, the autoscaler adds nodes; when nodes are underutilised for ~10 minutes, it removes them. Reference: [Use the cluster autoscaler on AKS](https://learn.microsoft.com/azure/aks/cluster-autoscaler).

### Task 1 – Create a cluster with the autoscaler enabled

Set variables for this lab's cluster:

```powershell
$CLUSTER_NAME = "aks-@lab.LabInstance.Id"
$RESOURCE_GROUP_NAME = "azure-rg"
```

> **This lab requires a fresh cluster.** The previous lab's cluster ran NAP (`--node-provisioning-mode Auto`); the cluster autoscaler is incompatible with NAP-managed node pools. Delete the prior cluster before continuing:
>
> ```powershell
> az aks delete -g $RESOURCE_GROUP_NAME -n $CLUSTER_NAME --yes
> ```

The flags below enable the autoscaler on the default node pool with a hard ceiling of 5 nodes. `--cluster-autoscaler-profile scan-interval=30s` makes scaling decisions evaluate every 30 seconds (default is 10 s), making the lab easier to follow without flooding logs. Reference: [Cluster autoscaler profile settings](https://learn.microsoft.com/azure/aks/cluster-autoscaler#use-the-cluster-autoscaler-profile).

```powershell
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME `
  --node-count 1 --node-vm-size 'Standard_D2ads_v5' `
  --load-balancer-sku standard `
  --enable-cluster-autoscaler --min-count 1 --max-count 5 `
  --cluster-autoscaler-profile scan-interval=30s `
  --generate-ssh-keys
```

Get credentials:

```powershell
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
```

### Task 2 – Deploy a workload that will force scale-up

Same `inflate` deployment as Lab 1 — `pause` containers requesting 1 CPU each:

```powershell
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: mcr.microsoft.com/oss/kubernetes/pause:3.6
          resources:
            requests:
              cpu: 1
"@ | Set-Content -LiteralPath deploy.yaml -Encoding utf8
```

```powershell
kubectl apply -f deploy.yaml
```

Ask for **15** replicas. With `Standard_D2ads_v5` (2 vCPU per node) and 1 CPU requested per pod, this far exceeds what 1 node can hold. The autoscaler will provision additional nodes — but only up to `--max-count 5`, so some pods will stay `Pending`. That capping behaviour is the whole point of the lab:

```powershell
kubectl scale deployment inflate --replicas 15
```

Wait ~1–2 minutes, then verify nodes are being added:

```powershell
kubectl get nodes
kubectl get pods -o wide
```

> Pods that stay in `Pending` after the cluster reaches `max-count` are an expected signal — production deployments should size `max-count` based on cost ceilings, not just current load.

### Task 3 – Scale down and observe node removal

Delete the deployment:

```powershell
kubectl delete deployment inflate
```

The autoscaler waits **`scale-down-unneeded-time`** (default 10 minutes) before evicting an empty node, so don't expect the count to drop instantly. Reference: [Cluster autoscaler profile defaults](https://learn.microsoft.com/azure/aks/cluster-autoscaler#use-the-cluster-autoscaler-profile).

```powershell
kubectl get nodes
```

### Task 4 – Cleanup

```powershell
az aks delete --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP_NAME --yes --no-wait
```

[List of Modules](#modules-list)

# Module 5: Application Deployment

```powershell
Set-Location C:\k8s\labs
```

This module covers two complementary approaches for deploying applications to AKS:

- **Lab 1 – Helm**: package and roll out an application as a versioned chart (the *Push* model). Helm is the de-facto package manager for Kubernetes and is what most CI/CD pipelines call to upgrade workloads.
- **Lab 2 – GitOps with Flux v2 (Optional)**: have the cluster pull and reconcile manifests directly from a Git repository (the *Pull* model). Useful when Git must remain the single source of truth and you want continuous drift correction.

The two models are not mutually exclusive — Flux can deploy Helm charts via `HelmRelease` resources.

## Lab 1: Deploy an application with Helm

In this lab you will install Helm, deploy the **AKS Store Demo** sample app from its Helm chart, perform an in-place upgrade with overridden values, roll back to the previous revision, and clean up.

References: [Quickstart: Develop and deploy applications on AKS using Helm](https://learn.microsoft.com/azure/aks/quickstart-helm), [AKS Store Demo on GitHub](https://github.com/Azure-Samples/aks-store-demo).

### Task 1 – Install the Helm CLI

```powershell
Get-Command helm -ErrorAction Stop
helm version
```

The VM needs the Windows Helm CLI. If it is missing, ask your instructor to
install Helm using the [Windows installation instructions](https://helm.sh/docs/intro/install/).
Do not run the Linux `get-helm-3` script in PowerShell.

### Task 2 – Get cluster credentials

Reuse one of the AKS clusters from a previous module (any standard cluster works).

```powershell
$RESOURCE_GROUP = "azure-rg"
$AKS_NAME = "aks-@lab.LabInstance.Id"

az aks get-credentials --name $AKS_NAME --resource-group $RESOURCE_GROUP
kubectl get nodes
```

### Task 3 – Clone the AKS Store Demo and inspect the chart

```powershell
git clone https://github.com/Azure-Samples/aks-store-demo.git
cd aks-store-demo

# Look at the chart structure
ls charts/aks-store-demo
Get-ChildItem charts/aks-store-demo
Get-Content charts/aks-store-demo/Chart.yaml
helm show values charts/aks-store-demo | Select-Object -First 40
```

> The chart contains the full microservice topology: `store-front` (UI), `order-service`, `product-service`, `rabbitmq` (message broker) and `mongodb` (state). This is exactly the kind of *complex* multi-microservice application Helm is designed to manage as a single unit.

### Task 4 – Install the chart

```powershell
kubectl create namespace pets
helm install aks-store charts/aks-store-demo --namespace pets
```

Watch the workloads come up:

```powershell
kubectl -n pets get pods -w
```

List Helm releases on the cluster:

```powershell
helm list -n pets
```

Grab the external IP of the storefront once the LoadBalancer is ready, then open it in a browser:

```powershell
kubectl -n pets get svc store-front
```

### Task 5 – Upgrade with `--set` value overrides

The whole point of Helm is that values drive the deployment. Use `--set` to scale up the storefront and switch to a newer image tag without editing any YAML:

```powershell
helm upgrade aks-store charts/aks-store-demo --namespace pets `
  --reset-then-reuse-values `
  --set storeFront.replicas=3

kubectl -n pets get deploy store-front
helm history aks-store -n pets
```

> `helm history` shows every revision — critical for the next task. In a real pipeline, the `--set` values would be supplied from a generated `values.yaml`, e.g. `helm upgrade myrelease mychart --install -f updatedvalues.yaml`, exactly as shown on slide 20 of the *Application Deployment* deck.

### Task 6 – Roll back to the previous revision

If an upgrade goes wrong, Helm can revert to any previous revision in seconds:

```powershell
helm rollback aks-store 1 -n pets
kubectl -n pets get deploy store-front
helm history aks-store -n pets
```

### Task 7 – Inspect templated manifests (without installing)

A useful diagnostic command — render the chart locally without touching the cluster:

```powershell
helm template aks-store charts/aks-store-demo --namespace pets `
  --set storeFront.replicas=2 | Select-Object -First 50
```

### Task 8 – Cleanup

```powershell
helm uninstall aks-store -n pets
kubectl delete namespace pets
cd ..
```

[List of Modules](#modules-list)

## Lab 2: GitOps with Flux v2 (Optional)

In this lab you will use **GitOps with Flux v2** to deploy applications to AKS. Instead of running `kubectl apply` (or `helm install`) by hand, the cluster continuously **reconciles** its state from a Git repository — making Git the single source of truth for what runs in the cluster.

Reference: [Tutorial: Deploy applications by using GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)

## Objectives

- Install the `microsoft.flux` cluster extension on AKS.
- Create a Flux configuration that watches a Git repository and reconciles two kustomizations (`infra` + `apps`).
- Inspect the Flux controllers and the workloads they deploy.
- Demonstrate drift detection and reconciliation by editing the cluster directly.
- Clean up.

## Prerequisites

- An MSI-based AKS cluster running and reachable via `kubectl`. Either reuse the cluster created in the *What is AKS* module or create a new one.
- Azure CLI 2.15+ with the `k8s-configuration` and `k8s-extension` extensions installed.
- Read/write permissions on `Microsoft.KubernetesConfiguration/extensions` and `Microsoft.KubernetesConfiguration/fluxConfigurations` in the subscription.

### Task 1 - Register providers and install CLI extensions

1. Register the resource providers required by GitOps:

```powershell
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.KubernetesConfiguration
```

2. Confirm the `KubernetesConfiguration` provider is registered (it can take a few minutes):

```powershell
az provider show -n Microsoft.KubernetesConfiguration -o table
```

3. Add or update the Azure CLI extensions:

```powershell
az extension add -n k8s-configuration
az extension add -n k8s-extension
az extension update -n k8s-configuration
az extension update -n k8s-extension
```

### Task 2 - Define environment variables

Reuse the cluster from the previous modules.

```powershell
$RESOURCE_GROUP = "azure-rg"
$AKS_NAME = "aks-@lab.LabInstance.Id"
$FLUX_CONFIG_NAME = "cluster-config"
$FLUX_NAMESPACE = "cluster-config"
$GIT_REPO_URL = "https://github.com/Azure/gitops-flux2-kustomize-helm-mt"

az aks get-credentials --name $AKS_NAME --resource-group $RESOURCE_GROUP
kubectl get nodes
```

> The sample repo `gitops-flux2-kustomize-helm-mt` is the official Microsoft demo repository. It contains an `./infrastructure` folder (NGINX, Redis via Helm) and an `./apps/staging` folder (a `podinfo` app), perfect for showcasing a multi-kustomization setup with dependencies.

## Apply a Flux configuration

### Task 3 - Create the Flux configuration

The command below installs the `microsoft.flux` cluster extension automatically (if it isn't already installed) and creates a Flux configuration with two kustomizations:

- `infra` reconciles `./infrastructure` (must finish first).
- `apps` reconciles `./apps/staging` and `dependsOn=infra`.

Both use `prune=true` so that resources removed from Git are also removed from the cluster.

```powershell
az k8s-configuration flux create `
  --resource-group $RESOURCE_GROUP `
  --cluster-name $AKS_NAME `
  --cluster-type managedClusters `
  --name $FLUX_CONFIG_NAME `
  --namespace $FLUX_NAMESPACE `
  --scope cluster `
  --url $GIT_REPO_URL `
  --branch main `
  --kustomization name=infra path=./infrastructure prune=true `
  --kustomization name=apps  path=./apps/staging  prune=true dependsOn=["infra"]
```

> Initial compliance state may show `Pending` or `Non-compliant` while reconciliation is in progress. Re-run the show command after a minute or two.

### Task 4 - Inspect the configuration

1. Show the configuration from Azure:

```powershell
az k8s-configuration flux show `
  -g $RESOURCE_GROUP -c $AKS_NAME -t managedClusters -n $FLUX_CONFIG_NAME
```

2. Verify the new namespaces created by Flux:

```powershell
kubectl get namespaces
```

> Expect to see `flux-system` (Flux controllers), `cluster-config` (Flux config objects), and the workload namespaces `nginx`, `podinfo`, `redis`.

3. Confirm the Flux controllers are running:

```powershell
kubectl get pods -n flux-system
```

> The Microsoft-managed agents (`fluxconfig-agent`, `fluxconfig-controller`) and the upstream Flux controllers (`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`) should all be in `Running` state.

4. Inspect the Flux custom resources:

```powershell
kubectl get fluxconfigs -A
kubectl get gitrepositories -A
kubectl get kustomizations -A
kubectl get helmreleases -A
```

> `gitrepositories` should report `Fetched revision: main/<sha>` and `helmreleases` (`nginx`, `podinfo`, `redis`) should be `Release reconciliation succeeded`.

### Task 5 - Verify the deployed workload

1. Look at the `podinfo` app deployed by the `apps` kustomization:

```powershell
kubectl get all -n podinfo
```

2. Port-forward to test it locally:

```powershell
kubectl -n podinfo port-forward svc/podinfo 9898:9898
```

Leave that command running and use a second PowerShell window:

```powershell
curl.exe -s http://localhost:9898 | Select-Object -First 20
```

Return to the first window and press **Ctrl+C** when finished.

## Demonstrate reconciliation (drift detection)

### Task 6 - Try to break the desired state

1. Manually scale the `podinfo` deployment outside of Git:

```powershell
kubectl -n podinfo scale deployment podinfo --replicas=5
kubectl -n podinfo get deploy podinfo
```

2. Wait up to the configured sync interval (default 10 minutes; you can force a reconcile):

```powershell
kubectl annotate kustomization apps -n cluster-config `
  reconcile.fluxcd.io/requestedAt="$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" --overwrite
```

3. Check the replica count again:

```powershell
kubectl -n podinfo get deploy podinfo
```

> Flux reverts the deployment back to the replica count declared in Git. **Git is the source of truth** — out-of-band changes are reconciled away.

### Task 7 - (Optional) Add your own workload via GitOps

If you have a personal GitHub account, you can fork the sample repo and add the resources from `Module5/`:

1. Fork `https://github.com/Azure/gitops-flux2-kustomize-helm-mt`.
2. Copy `Module5/sample-app.yaml` and `Module5/kustomization.yaml` into `apps/staging/podinfo-extra/` in your fork (and reference the folder from `apps/staging/kustomization.yaml`).
3. Recreate the Flux configuration pointing at **your** fork's URL.
4. Commit and push — within a minute or two, `kubectl get all -n gitops-demo` will show the new app reconciled by Flux.

## Cleanup

### Task 8 - Delete the Flux configuration and extension

1. Delete the Flux configuration. Because `prune=true` was set, all the workloads it deployed are removed too:

```powershell
az k8s-configuration flux delete `
  -g $RESOURCE_GROUP -c $AKS_NAME -t managedClusters -n $FLUX_CONFIG_NAME --yes
```

2. Delete the `microsoft.flux` cluster extension:

```powershell
az k8s-extension delete `
  -g $RESOURCE_GROUP -c $AKS_NAME -t managedClusters -n flux --yes
```

> Always delete Flux configurations **before** deleting the extension, otherwise the cluster can be left in an inconsistent state.

# Module 6: Storage on AKS

```powershell
Set-Location C:\k8s\labs
```

## Objectives

In this workshop you will learn about the advanced storage concepts in Azure Kubernetes Service (AKS). You will learn about the different storage options available in Azure, i.e. Azure Disks, Azure File & Azure Container Storage.

## Storage Options

Azure offers a set of storage options that can be categorized into two buckets: Block Storage and Shared File Storage (aka File Shares). You can choose the best match option based on the workload requirements.

The following guidance might help your evaluation:

- Select storage category based on the attach mode.
- Block Storage can be attached to a single node one time (RWO: Read Write Once), while Shared File Storage can be attached to different nodes one time (RWX: Read Write Many). If you need to access the same file from different nodes, you would need Shared File Storage.
- Select a storage option in each category based on characteristics and user cases.

  **Block storage category:**

  | Storage option | Characteristics | User Cases |
  | :-------------------------------------------------------------------------------------------: | :----------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------: |
  | [Azure Disks](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview) | Rich SKUs from low-cost HDD disks to high performance Ultra Disks. | Generic option for all user cases from Backup to database to SAP Hana. |
  | [Elastic SAN](https://learn.microsoft.com/azure/storage/elastic-san/elastic-san-introduction) | Scalability up to millions of IOPS, Cost efficiency at scale | Tier 1 & 2 workloads, Databases, VDI hosted on any Compute options (VM, Containers, AVS) |
  | [Local Disks](https://learn.microsoft.com/azure/virtual-machines/nvme-overview) | Priced in VM, High IOPS/Throughput and extremely low latency. | Applications with no data durability requirement or with built-in data replication support (e.g., Cassandra), AI training |

  **Shared File Storage category:**

  | Storage option | Characteristics | User Cases |
  | :--------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------: |
  | [Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction) | Fully managed, multiple redundancy options. | General purpose file shares, LOB apps, shared app or config data for CI/CD, AI/ML. |
  | [Azure NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) | Fully managed ONTAP with high performance and low latency. | Analytics, HPC, CMS, CI/CD, custom apps currently using NetApp. |
  | [Azure Blobs](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction) | Unlimited amounts of unstructured data, data lifecycle management, rich redundancy options. | Large scale of object data handling, backup |

- Select performance tier, redundancy type on the storage option.
  See the product page from above table for further evaluation of performance tier, redundancy type or other requirements.

## Orchestration Options

Besides invoking service REST API to ingest remote storage resources, there are two major ways to use storage options in AKS workloads: CSI (Container Storage Interface) drivers and Azure Container Storage.

### CSI Drivers

Container Storage Interface is industry standard that enables storage vendors (SP) to develop a plugin once and have it work across a number of container orchestration systems. It's widely adopted by both the open source community and major cloud storage vendors. If you already build storage management and operation with CSI drivers, or you plan to build cloud independent k8s cluster setup, it's the preferred option.

## Creating a cluster to run the lab excersises.
For the first exercise in this module you'll only need a simple AKS cluster, but for the second task on Azure Container storage you will need a new cluster with some advanced options enabled. To keep things easy you'll build a single AKS cluster that has settings for both labs.

## Deploying a Cluster

### Task 1 - Login into your subscription and register providers

1. Open a Windows Terminal window using PowerShell.

![Windows Terminal icon in taskbar](content/windows-terminal.png)

> Windows Terminal allows you to open tabbed command terminals.

2. Login to Azure.

```powershell
az login
```

!IMAGE[azlogin.jpg](instructions285565/azlogin.jpg)
Choose Work or school Account
Click on Username and password to Autofill and Authenticate.

3. Set the current subscription.

Post Authentication, below screen shows up with the pre-defined Subscription to choose.
Select 1 and enter.

!IMAGE[subchoose.jpg](instructions287320/subchoose.jpg)

4. Register needed providers.

```powershell
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Kubernetes
```

5. Open a browser and navigate to the Azure Portal: **_portal.azure.com_**

6. Search for and open the **Subscriptions** blade. Select your **Azure** subscription.

7. Scroll down and select **Resource providers**.


!IMAGE[azure-resources.jpg](instructions287320/azure-resources.jpg)
8. Confirm the following required providers are registered. Select **Register** for any provider whose status is **NotRegistered**, then select **Refresh** until its status is **Registered**: **Microsoft.Storage**, **Microsoft.Compute**, **Microsoft.Network**, **Microsoft.Monitor**, **Microsoft.Insights**, **Microsoft.ManagedIdentity**, **Microsoft.OperationalInsights**, **Microsoft.OperationsManagement**, **Microsoft.KeyVault**, **Microsoft.ContainerRegistry**, **Microsoft.ContainerService**, and **Microsoft.Kubernetes**.

### Task 2 - Define variables and create resource group

1. Define global variables

**WARNING**: When using Azure regions you could run into deployment issues in high demand regions. Consult your delivering CSA for guidance if you run into issues. Available regions: Central US, East US 2, Sweden Central, West US

```powershell
$RESOURCE_GROUP = "azure-rg"
$LOCATION = "eastus2"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
```

2. Set the VM SKU to the default below.

**WARNING**: VM SKUs can change per region use the default first then fall back to other available SKUS. Consult your CSA for guidance. Available SKUS: Standard_D2as_v5, Standard_A2m_v2, Standard_D2s_v5, Standard_D2ads_v5

```powershell
$VM_SKU = "Standard_D2as_v5"
```

### Task 3 - Create a basic cluster using Azure CLI

1. Define variables for AKS cluster.

```powershell
$AKS_NAME = "aks-@lab.LabInstance.Id"
echo "AKS Cluster Name: $AKS_NAME"
```

2. Create a simple AKS cluster.

```powershell
az group create --name $RESOURCE_GROUP --location $LOCATION
az aks create --node-count 2 --generate-ssh-keys --node-vm-size $VM_SKU --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

> The creation process will take about 5-10 minutes.

3. Once complete, connect the cluster to your local client machine.

```powershell
az aks get-credentials --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

4. Confirm the connection to the cluster.

```powershell
kubectl get nodes
```

## Storage using Azure Disks and File Shares

In this lab you will use Persistent Volums (PV), Persistent Volume Claims (PVC) and StorageClasses (SC) to read & write data stored outside of the AKS cluster. You will use the two native disk based storage mechanisms provided by Azure: Azure Disks & Azure Files.

By the end of the lab, you will understand how to do the following:

* Manually create an Azure Disk for backend data storage. This can only be mounted to one node at a time.
* Manually create backing storage using Azure File Shares and mount it to Pods running inside the AKS cluster. This can be mounted to multiple pods running on multiple nodes at the same time.
* Use PersistentVolume Claims and StorageClasses to automatically create backing storage based on Auzre Disks or File Shares.

### Exercise 1 - Azure Disk Storage

In this section, you will **manually** create an Azure Disk for backend data storage and mount it to a pod on a node in the cluster.

In the real world it would be unusual to create disks manually like this as it requires the copying/hardcoding of Azure resource Ids into config files. Whilst this is not optimal, it does provide a much better understanding of what is happening *under the covers*. In a later section you will have Kubernetes create the disk automatically. This is more representative of the real world.

#### Task 1 - Create an Azure Disk
Creating an Azure Disk using the CLI is a pretty straight forward task, however WHERE the disk is created is important. Theoretically the Disk could be in any resource group, even in another subscription but to do so would mean having to setup specific permissions to allow AKS to access Azure in order to read/write to the disk.

The answer is therefore to create the disk inside the *MC_* resource group which is instantiated when an AKS cluster is setup. This group contains all the infrstructure related cluster objects (including the Virtual Machine Scale Set which produces the nodes in the cluster). Importantly it already has the correct permissions setup so that AKS will be allowed to access any Disk you place inside it.


1. Create a variable which contains the name of the AKS MC_ resource group:
```powershell
$INFRA_MC_RG = $(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query nodeResourceGroup -o tsv)

echo $INFRA_MC_RG
```

2. Create an Azure Disk. This is a standard Disk which could be connected to any virtual machine (remember that AKS nodes are really just virtual machines). Notice is is being created in the MC_ resource group so that it inherits the correct permissions.
```powershell
az disk create --resource-group $INFRA_MC_RG --name MyManagedDisk --size-gb 128 --sku Premium_LRS --location $LOCATION --os-type Linux
```

> Creating the disk with the *--os-type Linux* option will ensure it is pre-formatted with the *ext4* filesystem. 

3. Confirm the disk is currently "unattached" (i.e. not connected to any virtual machine) by querying it's *diskState* property.
```powershell
az disk show --resource-group $INFRA_MC_RG --name MyManagedDisk --query "diskState" --output table
```

4. Make a copy of the ResourceID of the new disk.
```powershell
az disk show --resource-group $INFRA_MC_RG --name MyManagedDisk --query "id" --output tsv
```

#### Task 2 - Create a Namespace.
All the objects related to this lab will be self-contained in a Namespace. When you're done, you could delete the Namespace and all the objects it contains will also be deleted. The Persistent Volume, which is scoped across the entire cluster, will remain.

5. Create a new Namespace.
```powershell
kubectl create ns storagelab
```

6. Set the context of the new Namespace as the current namespace, so it doesn't have to be specified in future commands.
```powershell
kubectl config set-context --current --namespace storagelab
```

#### Task 3 - Deploy the PV & PVC configurations

7. Open and review `C:\k8s\labs\Module6\disk-pv.yaml`, which defines the PV that connects to the Azure Disk.

> Line 11 states this is using the newer CSI driver type, with line 12+ defining the required parameters for the driver.

> Notice the *AccessMode* in line 9 is *ReadWriteOnce*. This means the Pods will be able to read/write from this PV but that it can only be connected to a single AKS node at a time. This is limited for application that need to be distributed across several nodes at once, but might be used when only a single Pod runs an application (e.g. when running a database such as MySQL).

8. Replace the placeholder in `spec.csi.volumeHandle` with the ResourceID obtained previously. The result should look similar to this:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: azure-disk-pv
spec:
  capacity:
    storage: 128Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: azure-disk-csi
  csi:
    driver: disk.csi.azure.com
    volumeHandle: /subscriptions/96ee4e57-ffd1-40f0-8fb0-e46c394e0fc2/resourceGroups/azure-rg/providers/Microsoft.Compute/disks/MyManagedDisk
    fsType: ext4
    readOnly: false
```

9. Deploy the PV configuration.
```powershell
kubectl apply -f Module6/disk-pv.yaml
```

Review the results by running:
```text
$ kubectl get pv

NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                      STORAGECLASS     VOLUMEATTRIBUTESCLASS   REASON   AGE
azure-disk-pv   128Gi      RWO            Retain           Available                              azure-disk-csi   <unset>                          8s
```

> Notice the **STATUS** is *Available* meaning this PV is currently not in use and free to be attached to a node.

10. Deploy a PVC that references this PV:
```powershell
kubectl apply -f Module6/disk-pvc.yaml
```

11. Now confirm it is deployed:
```powershell
kubectl get pvc
```

Results should be similar to the following:
```text
NAME             STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS     VOLUMEATTRIBUTESCLASS   AGE
azure-disk-pvc   Bound    azure-disk-pv   128Gi      RWO            azure-disk-csi   <unset>                 18s
```

>  Notice that the **STATUS** is *Bound*. This means the connection to the backing Azure Disk has succeeded.

#### Task 4 - Deploy an application that uses the storage

12. Finally, open to review `disk-pod.yaml`, then deploy a single Pod that uses the PV:
```powershell
kubectl apply -f Module6/disk-pod.yaml
```

> Notice from line 12 of the `disk-pod.yaml` file that the external storage will be mounted at `/sharedfolder`.

13. Get STATUS of the Pod and notice that it is currently *ContainerCreating*. 
```powershell
kubectl get pod/nginx-pod
```

```text
NAME        READY   STATUS              RESTARTS   AGE
nginx-pod   0/1     ContainerCreating   0          40s
```

> The STATUS is set to *ContainerCreating* because it takes time for the Azure Disk to be mounted to the node running the Pod. Until the mount is completed, the Pod is not considered READY (i.e. 0 of 1 steps are completed).

14. Wait 30 seconds or so then run the command again, along with a previous command to view the status of the Azure Disk.
```powershell
kubectl get pod/nginx-pod

az disk show --resource-group $INFRA_MC_RG --name MyManagedDisk --query "diskState" --output table
```

> This time the status will have changed to *Running* which means the Pod is up and the disk is attached correctly.
> The second command confirms the Disk is now attached to a node in the cluster.

15. Once the Pod is running, shell into it.
```powershell
kubectl exec -it nginx-pod -- bash
```

16. Change into the shared folder, create a file and confirm it's there.
```bash
cd /sharedfolder
touch abc123.txt
ls -l
```

17. Exit from the shell:
```bash
exit
```

18. Now delete the Pod.
```powershell
kubectl delete pod/nginx-pod
```

19. Wait 30 seconds or so, then check the status of the Azure Disk:
```powershell
az disk show --resource-group $INFRA_MC_RG --name MyManagedDisk --query "diskState" --output table
```

> Notice that it's status should now be *Unattached*. This means it's free and can be attached to a new node.

20. Deploy the Pod again. It's possible it it may get scheduled on either node in the cluster.
```powershell
kubectl apply -f Module6/disk-pod.yaml
```

21. Shell into the Pod again and check the file created from inside the previous Pod still exists:
```powershell
kubectl exec -it nginx-pod -- bash
```

Inside the container:

```bash
cd /sharedfolder
ls -l
```

22. Exit from the shell:
```bash
exit
```






### Exercise 2 - Azure File Share Storage

In this section, you will manually create backing storage using an Azure File Share and mount it to a Pod running inside the AKS cluster. If required, it can be mounted to multiple pods running on multiple nodes at the same time. As this is being configured manually, you will also setup some connection strings from AKS to the storage. In a later section you will configure creation & authentication to happen automatically.

#### Task 1 - Manually create an Azure Storage Account and an Azure File Share

1. Define additional variables to set the name of the storage account. Ensure you update the "xyz" to your initials.

```powershell
$YOUR_INITIALS = "xyz"
$STORAGE_ACCOUNT_NAME = "sa${YOUR_INITIALS}$(Get-Random -Minimum 10000 -Maximum 99999)"
$SHARE_NAME = "share${YOUR_INITIALS}"
```

2. Create the Azure Storage Account.
 
```powershell
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --sku Standard_LRS
```

3. Create the Azure File Share.
```powershell
az storage share create --name $SHARE_NAME --connection-string $(az storage account show-connection-string --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP -o tsv)
```

4. Save the Account Name and Account Key for use later.
```powershell
$STORAGE_KEY = $(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
```

#### Task 3 - Store the connection credentials

5. The Account Name and Account Key used to access the file share must be accessible to Kubernetes. In this case you will use a Secret object, however this is not a good practice as Secret objects can be read by anyone with the correct permissions. *We will address this problem in a later section*.

Create a YAML file which contains the secret connection details:
```powershell
kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY --dry-run=client --namespace storagelab -o yaml |
    Set-Content -LiteralPath azure-secret.yaml -Encoding utf8
```

6. A YAML file is generated with all the information needed to create the secret. Review the new file.
```powershell
Get-Content azure-secret.yaml
```
> It's best to create the file first and then apply it so you can repeat the process if needed.

7. Apply the secret in the storagelab namespace.

```powershell
kubectl apply -f azure-secret.yaml -n storagelab
```

#### Task 4 - Create a Persistent Volume and a Persistent Volume Claim

The first step to accessing an Azure File Share is creating a PersistentVolume object that creates the connection between Kubernetes and the share.

8. Review the value of SHARE_NAME created in Task 1 above.
```powershell
echo $SHARE_NAME
```
 
9. Open `C:\k8s\labs\Module6\azurefile-pv.yaml`. Set
   `spec.csi.volumeAttributes.shareName` to the value of `$SHARE_NAME` and
   `spec.csi.volumeAttributes.resourceGroup` to the value of `$RESOURCE_GROUP`.
   Replace `spec.csi.volumeHandle` with a unique value in the format
   `<resource-group>#<storage-account-name>#<share-name>`, using the values of
   `$RESOURCE_GROUP`, `$STORAGE_ACCOUNT_NAME`, and `$SHARE_NAME`.
   Set `spec.csi.nodeStageSecretRef.namespace` to `storagelab`, where you created
   `azure-secret`. Do not leave the uploaded `default` namespace or placeholders.

> Notice this is using the more modern CSI driver as referenced by the Storage Class on line 12.

10. Also notice there is a label called *storage-provider* associated with the persistent volume. This is a reference name that the Persisent Volume Claim will reference shortly.

```yaml
 apiVersion:v1
 kind: PersistentVolume
 metadata:
 name: azurefile-pv
 labels: 
   storage-provider: azurefile-pvc
```

11. When the file is ready, apply it
```powershell
kubectl apply -f Module6/azurefile-pv.yaml
```

12. Now view the results
```powershell
kubectl get pv
```

```text
NAME           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    VOLUMEATTRIBUTESCLASS   REASON   AGE
azurefile-pv   5Gi        RWX            Retain           Available           azurefile-csi   <unset>                          33s
```

> Notice that the **RECLAIM POLICY** is set to *Retain* - this means the PV will not be deleted (i.e. it will be retained) when not being used by or connected to any Pod. 

> The **CLAIM** is currently blank which means that nothing has "claimed" the PV, i.e. it's not currently being used. 

> The **STATUS** is *Available* which means the backend storage has been created and is ready to access. This is expected as you created it manually earlier, but in later sections when backend storage is provisioned automatically this could show a different status whilst the underlying storage is being created.

13. Review `C:\k8s\labs\Module6\azurefile-pvc.yaml`. Its selector matches the PV
    label `storage-provider: azurefile-pvc`. Pods that reference this PVC
    indirectly use the PV and the Azure File Share.

14. Apply the Persistent Volume Claim.
```powershell
kubectl apply -f Module6/azurefile-pvc.yaml
```

15. Now view the results
```powershell
kubectl get pvc
```

```text
NAME            STATUS   VOLUME         CAPACITY   ACCESS MODES   STORAGECLASS    VOLUMEATTRIBUTESCLASS   AGE
azurefile-pvc   Bound    azurefile-pv   5Gi        RWX            azurefile-csi   <unset>                 13s
```

> Notice the **STATUS** is *Bound*. This indicates the PVC is connected to the PV which is connected to the backend storage.

#### Task 5 - Use the Persistent Volume Claim in a Pod
Now that the PVC is configured to the PV which is configured to use an Azure File Share, you must create a Pod which uses the PVC.

16. Review the contents of `pvc-pod.yaml`. This deploys a single pod which references the **persistentVolumeClaim** called *azurefile-pvc* and mounts it inside the Pod at */sharedfolder*.

17. Apply the Pod.
```powershell
kubectl apply -f Module6/pvc-pod.yaml
```

18. Confirm the Pod is running. It might take a few minutes for the Pod to connect to the PVC.
```powershell
kubectl get pod pvc-pod
```

19. Once the Pod is running, shell into the Pod.
```powershell
kubectl exec -it pvc-pod -- bash
```
20. Change into the shared folder, create a file and confirm it's there.
```bash
cd /sharedfolder
touch abc123.txt
ls -l
```

21. Open the Azure Portal in a browser.

22. Navigate to the storage account created earlier (as defined in STORAGE_ACCOUNT_NAME).

23. From the *Storage Browser* in the main side menu, click on the File shares selection, then on the name of the share (as defined in the SHARE_NAME environment variable).

24. You should see the file you created in the container. Click the Upload button and upload a file from your hard drive to the share

25. Get a list of files in the shared folder again.
```bash
ls -l
```
Both files should be in the shared folder:

This confirms that the sharedfolder is mapped to the Azure File Share.

26. Exit the container.
```exit```

27. Review `deployment.yaml` then deploy it:
```powershell
kubectl apply -f Module6/deployment.yaml
```

28. Get a list of the Pods and which node each is running on:
```powershell
kubectl get pods -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
```
Output looks similar to this:
```text
$ kubectl get pods -o=custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
NAME                               NODE
nginx-deployment-8956c6ffb-8h5fq   aks-nodepool1-18435022-vmss000001
nginx-deployment-8956c6ffb-bnk9n   aks-nodepool1-18435022-vmss000000
nginx-deployment-8956c6ffb-fnrl6   aks-nodepool1-18435022-vmss000001
nginx-deployment-8956c6ffb-gltdl   aks-nodepool1-18435022-vmss000000
nginx-deployment-8956c6ffb-s2m5h   aks-nodepool1-18435022-vmss000001
pvc-pod                            aks-nodepool1-18435022-vmss000000
```

29. Choose one of the new Pods at random (i.e. not the `pvc-pod`) and connect to it.
```powershell
kubectl exec -it nginx-deployment-8956c6ffb-8h5fq -- bash
```
> Don't just copy the command above verbatim as your deployment Pods won't have the same names.

30. Confirm the PV is connected into your Pod by viewing the contents of the `/sharedfolder` as done previously.

31. OPTIONAL: Connect to any of the other Pods runnin on either node in the cluster to confirm connectivity.



### Exercise 3 - Dynamically provisioned storage using Azure Disks

In this exercise you will provision one or more persistent volumes that use Azure Disk storage. Unlike a previous exercise where this was all done manually, this time you will use a Persistent Volume (PV) in conjunction with a Storage Class (SC) object to dynamically provision the Azure Disk.

Administrators often prefer to keep tight control over an environment and manually create resources as was done in an earlier exercise, however this can become an administration chore if lots of new disks are required for new applications. Allowing application developers to request the storage type and size they need in the PV object can eliminate this overhead. In order to allow the administrator to retain some level of control, a Storage Class (SC) object can be defined to declare the types and size of dynamic storage which can be requested created automatically.
 
Each AKS cluster includes a number of precreated storage classes, some will create Azure Disk storage, some Azure File Share storage. There are also options for standard or SSD disks, using legacy or modern CSI drivers.

#### Task 1 - View the built-in Storage Classes on AKS

1. Look at the options available out of the box to create external storage
```powershell
kubectl get sc
```
Results similar to the following are available:
```text
NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azurefile               file.csi.azure.com   Delete          Immediate              true                   120m
azurefile-csi           file.csi.azure.com   Delete          Immediate              true                   120m
azurefile-csi-premium   file.csi.azure.com   Delete          Immediate              true                   120m
azurefile-premium       file.csi.azure.com   Delete          Immediate              true                   120m
default (default)       disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   120m
managed                 disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   120m
managed-csi             disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   120m
managed-csi-premium     disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   120m
managed-premium         disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   120m
```
2. Examine one specific SC:
```powershell
kubectl describe sc/managed-csi
```

See that evertime this SC is referenced, it will create Stadard SSD disks which are locally redundant (StandardSSD_LRS) and that the *ReclaimPolicy* is **Delete**. This means the disk will be automatically deleted when it's nolonger being used.

> WARNING: Don't use the wrong SC or Disks (and therefore your data) could be deleted automatically if you delete any Pods that use them. You may need to define your own SC in that scenario.

```text
Name:                  managed-csi
IsDefaultClass:        No
Annotations:           <none>
Provisioner:           disk.csi.azure.com
Parameters:            skuname=StandardSSD_LRS
AllowVolumeExpansion:  True
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     WaitForFirstConsumer
Events:                <none>
```

3. Review the PVC definition file `azure-pvc.yaml`. Line 8 is referencing the *managed-csi* SC. Remember that a PVC points to a PV but in this case we are referencing a SC, not a PV. In this case, Kubernetes will contact Azure and request a Disk is created automatically using all provided information (e.g. Disk type from the SC, and disk size (line 11) from the PVC).

Deploy the file:
```powershell
kubectl apply -f Module6/azure-pvc.yaml
```
> Note from step 1 above, the **VOLUMEBINDINDMODE** of this SC is *WaitForFirstConsumer*. This means the Azure Disk won't be actually created until a Pod tries to use the PVC. You can confirm this by running the `kubectl describe pvc azure-managed-disk` command.

4. Review the `azure-pod.yaml` file which deploys a Pod that references the PVC (line 23).

Deploy the Pod, then view the status of the PV
```powershell
kubectl apply -f Module6/azure-pod.yaml

kubectl describe pvc azure-managed-disk
```

You should see the PV is being provisioned:
```text
Name:          azure-managed-disk
Namespace:     storagelab
StorageClass:  managed-csi
Status:        Bound
Volume:        pvc-a5a66727-a33c-4121-ad49-416be690233c
Labels:        <none>
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: disk.csi.azure.com
               volume.kubernetes.io/selected-node: aks-nodepool1-32493338-vmss000000
               volume.kubernetes.io/storage-provisioner: disk.csi.azure.com
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      5Gi
Access Modes:  RWO
VolumeMode:    Filesystem
Used By:       mypod
Events:
  Type    Reason                 Age                   From                                                                                               Message
  ----    ------                 ----                  ----                                                                                               -------
  Normal  WaitForFirstConsumer   49s (x24 over 6m20s)  persistentvolume-controller                                                                        waiting for first consumer to be created before binding
  Normal  Provisioning           43s                   disk.csi.azure.com_csi-azuredisk-controller-6954dd7485-twhf8_aa5f3b43-bf7f-4190-9c04-fa9716bca502  External provisioner is provisioning volume for claim "storagelab/azure-managed-disk"
  Normal  ExternalProvisioning   43s                   persistentvolume-controller                                                                        Waiting for a volume to be created either by the external provisioner 'disk.csi.azure.com' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
  Normal  ProvisioningSucceeded  42s                   disk.csi.azure.com_csi-azuredisk-controller-6954dd7485-twhf8_aa5f3b43-bf7f-4190-9c04-fa9716bca502  Successfully provisioned volume pvc-a5a66727-a33c-4121-ad49-416be690233c
```

5. Open the Azure Portal, locate the MC_ resource group that contains the infrastructure components for your AKS Cluster. Notice there is a new Azure Disk which has been created with a name that begins with  `pvc_`, e.g. pvc-a5a66727-a33c-4121-ad49-416be690233c.

6. Shell into the new Pod, create a file in the /sharedfolder, then exit the shell:
```powershell
kubectl exec -it mypod -- bash
```

Inside the container:

```bash
cd /sharedfolder
date > now
exit
```

7. Delete and recreate the Pod.
```powershell
kubectl delete -f Module6/azure-pod.yaml
```

> This does NOT delete the PV (i.e. the Azure Disk) automatically. As a result you can recreate the pod by running `apply` again and this will reconnect the new Pod to the previously created PV, thus retaining the data.

```powershell
kubectl apply -f Module6/azure-pod.yaml

kubectl exec -it mypod -- bash
```

Inside the container:

```bash
cd /sharedfolder

ls -l

exit
```

8. Now delete the Pod AND the PVC:
```powershell
kubectl delete -f Module6/azure-pod.yaml
kubectl delete -f Module6/azure-pvc.yaml
```

Check the status of the Disk PV that was created by the PVC (name begins *pvc_*). Running this several times will confirm that it is eventually deleted.
```powershell
kubectl get pv
```

> Check the MC_ resource group in the Azure Portal, the Disk will be gone from there a well.

### Exercise 4 - OPTIONAL - Dynamically provisioned storage using Azure Files

The process for automatically creating Azure File shares (for when you need shared storage across all Pod/Nodes in your cluster) is very similar to exercise 3, the main difference is you simply reference a different Storage Class (SC) to create the share for you, e.g. *azurefile-csi*.

If however none of the out-of-the-box StorageClass providers meet your need, you can always define a custom one. This allows more control over the types, sizes and retention policies of newly created storage.

1. Follow the online tutorial on how to [Setup Azure File storage in AKS with a custom Storage Class](https://learn.microsoft.com/en-us/azure/aks/azure-csi-files-storage-provision#dynamically-provision-a-volume).


### Additional Labs

If you have time and would like to try some additional labs, take a look at the following

* [Create and use a volume with Azure Disks in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/azure-csi-disk-storage-provision)



### Azure Container Storage

Azure Container Storage further automates the process of creating storage disks for external data on AKS clusters. It is built on the modern CSI driver interface to support greater scaling capability with storage pools and standardized management user interface across local & remote storage. If you want to simplify the use of local NVMe disks, or achieve higher pod scaling target,​ it's the preferred option.

Under the covers, Azure Container Storage still uses either Azure Disks or Azure Files to store data, but it also enables the use of other external data storage locations such as Azure Blob storage.

|                                               Storage option                                               |                                        CSI drivers                                         | Azure Container Storage |
| :--------------------------------------------------------------------------------------------------------: | :----------------------------------------------------------------------------------------: | :---------------------: |
|          [Azure Disks](https://learn.microsoft.com/azure/virtual-machines/managed-disks-overview)          |     Support([CSI disks driver](https://learn.microsoft.com/azure/aks/azure-disk-csi))      |         Support         |
|       [Elastic SAN](https://learn.microsoft.com/azure/storage/elastic-san/elastic-san-introduction)        |                                            N/A                                             |         Support         |
|              [Local Disks](https://learn.microsoft.com/azure/virtual-machines/nvme-overview)               |                            N/A (Host Path + Static Provisioner)                            |         Support         |
|         [Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-introduction)          |     Support([CSI files driver](https://learn.microsoft.com/azure/aks/azure-files-csi))     |           N/A           |
| [Azure NetApp Files](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-introduction) | Support([CSI NetApp driver](https://learn.microsoft.com/azure/aks/azure-netapp-files-nfs)) |           N/A           |
|         [Azure Blobs](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-introduction)          | Support([CSI Blobs driver](https://learn.microsoft.com/azure/aks/azure-blob-csi?tabs=NFS)) |           N/A           |

### Exercise 5 - Azure Container Storage for Replicated Ephemeral NVMe Disk
In this exercise, you will deploy a MySQL Server and mount volumes using local NVMe storage via Azure Container Storage and demonstrate replication and failover of replicated local NVMe storage in Azure Container Storage.

### Task 1 - Setup Azure Container Storage

Follow the below steps to enable Azure Container Storage in an existing AKS cluster

0. Install the AKS CLI Extension. This includes commands for working with Azure Container Storage. 
```powershell
az extension add -n k8s-extension
```

1. Run the following command to set the new node pool name.

```powershell
$ACSTOR_NODEPOOL_NAME = "acstorpool"
```

2. Run the following command to create a new node pool with **Standard_L8s_v3** VMs. Only Pods running on nodes in this pool will be able to use Azure Container Storage.

```powershell
az aks nodepool add --cluster-name $AKS_NAME --resource-group $RESOURCE_GROUP --name $ACSTOR_NODEPOOL_NAME --node-vm-size Standard_L8s_v3 --node-count 3
```

> The **L** series of Virtual Machines are optimised for storage. By adding 3 nodes with large disks into the cluster, you will be storing your data directly onto these machines. See https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/storage-optimized/l-family for more details.

> The workshop policy permits `Standard_L8s_v3` only in the `acstorpool` node pool.
> If this size is unavailable in your region or subscription, or you have insufficient quota, contact your instructor. Other L-family sizes require an approved policy update before you can use them.
> If you encounter an error, please try with a different VM size within the [L-family](https://learn.microsoft.com/azure/virtual-machines/sizes/storage-optimized/lsv2-series?tabs=sizebasic).


3. Update the cluster to enable Azure Container Storage. As well as making configuration changes to the cluster, it also deploys and application that helps manage the storage pool. This will be seen as new Pods added to the `acstor` namespace.

```powershell
az aks update --resource-group $RESOURCE_GROUP --name $AKS_NAME --enable-azure-container-storage ephemeralDisk --azure-container-storage-nodepools $ACSTOR_NODEPOOL_NAME --storage-pool-option NVMe --ephemeral-disk-volume-type PersistentVolumeWithAnnotation
```

> This command can take up to 20 minutes to complete.


4. Run the following command and wait until all the pods reaches **Running** state.

```powershell
kubectl get pods -n acstor --watch
```

You will see a lot of activity with pods being created, completed, and terminated. This is expected as the Azure Container Storage is being enabled.

Delete the default storage pool created.

```powershell
kubectl delete sp -n acstor ephemeraldisk-nvme
```

### Create a replicated ephemeral storage pool

With Azure Container Storage enabled, storage pools can also be created using Kubernetes CRDs. Run the following command to deploy a new StoragePool custom resource. This will create a new storage class using the storage pool name prefixed with **acstor-**.

```powershell
@"
apiVersion: containerstorage.azure.com/v1
kind: StoragePool
metadata:
  name: ephemeraldisk-nvme
  namespace: acstor
spec:
  poolType:
    ephemeralDisk:
      diskType: nvme
      replicas: 3
"@ | kubectl apply -f -
```

Now you should see the new storage class called **acstor-ephemeraldisk-nvme** has been created.

```powershell
kubectl get sc
```

### Deploy a MySQL server using new storage class

This setup is a modified version of [this guide](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/).

Run the following command to download the MySQL manifest file.

```powershell
curl.exe -o acstor-mysql-config-services.yaml https://gist.githubusercontent.com/pauldotyu/f459c834558fd83a6254fae0eb23b1e6/raw/ad1b5db804060b18b3ea123db9189f1a2d56414b/acstor-mysql-config-services.yaml
```

Optionally, run the following command to take a look at the MySQL manifest file.

```powershell
Get-Content acstor-mysql-config-services.yaml
```

Run the following command to deploy the config map and services for the MySQL server.

```powershell
kubectl apply -f acstor-mysql-config-services.yaml
```

Next, we'll deploy the MySQL server using the new storage class.

Run the following command to download the MySQL statefulset manifest file.

```powershell
curl.exe -o acstor-mysql-statefulset.yaml https://gist.githubusercontent.com/pauldotyu/f7539f4fc991cf5fc3ecb22383cb227c/raw/274b0747f1094db53869bcb0eb25faccf0f37a6a/acstor-mysql-statefulset.yaml
```

Optionally, run the following command to take a look at the MySQL statefulset manifest file.

```powershell
Get-Content acstor-mysql-statefulset.yaml
```

Run the following command to deploy the statefulset for MySQL server.

```powershell
kubectl apply -f acstor-mysql-statefulset.yaml
```

### Verify that all the MySQL server's components are available

Run the following command to verify that both mysql services were created (headless one for the statefulset and mysql-read for the reads).

```powershell
kubectl get svc -l app=mysql
```

You should see output similar to the following:

```text
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
mysql        ClusterIP   None           <none>        3306/TCP   5h43m
mysql-read   ClusterIP   10.0.205.191   <none>        3306/TCP   5h43m
```

Run the following command to verify that MySql server pod is running. Add the **--watch** to wait and watch until the pod goes from Init to **Running** state.

```powershell
kubectl get pods -l app=mysql -o wide --watch
```

You should see output similar to the following:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          1m34s  10.244.3.16   aks-nodepool1-28567125-vmss000003   <none>           <none>
```

:::note

Keep a note of the node on which the **mysql-0** pod is running.

:::

### Inject data to the MySql database

Run the following command to run and exec into a mysql client pod to the create a database named **school** and a table **students**. Also, make a few entries in the table to verify persistence.

```powershell
@'
CREATE DATABASE school;
CREATE TABLE school.students (RollNumber INT, Name VARCHAR(250));
INSERT INTO school.students VALUES (1, 'Student1');
INSERT INTO school.students VALUES (2, 'Student2');
'@ | kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql
```

### Verify the entries in the MySQL server

Run the following command to verify the creation of database, table, and entries.

```powershell
kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- `
mysql -h mysql-read -e "SELECT * FROM school.students"
```

You should see output similar to the following:

```text
+------------+----------+
| RollNumber | Name     |
+------------+----------+
|          1 | Student1 |
+------------+----------+
|          2 | Student2 |
+------------+----------+
```

### Initiate the node failover

Now we will simulate a failover scenario by deleting the node on which the `mysql-0` pod is running.

Run the following command to get the current node count in the Azure Container Storage node pool.

```powershell
$NODE_COUNT = $(az aks nodepool show `
--resource-group ${RESOURCE_GROUP} `
--cluster-name ${AKS_NAME} `
--name ${ACSTOR_NODEPOOL_NAME} `
--query count `
--output tsv)
```

Run the following command to scale up the Azure Container Storage node pool by 1 node.

```powershell
az aks nodepool scale `
--resource-group ${RESOURCE_GROUP} `
--cluster-name ${AKS_NAME} `
--name ${ACSTOR_NODEPOOL_NAME} `
--node-count ([int]$NODE_COUNT + 1) `
--no-wait
```

Now we want to force the failover by deleting the node on which the **mysql-0** pod is running.

Run the following commands to get the name of the node on which the **mysql-0** pod is running.

```powershell
$POD_NAME = $(kubectl get pods -l app=mysql -o custom-columns=":metadata.name" --no-headers)
$NODE_NAME = $(kubectl get pods $POD_NAME -o jsonpath='{.spec.nodeName}')
```

Run the following command to delete the node on which the **mysql-0** pod is running.

```powershell
kubectl delete node $NODE_NAME
```

### Observe that the mysql pods are running

Run the following command to get the pods and observe that the **mysql-0** pod is running on a different node.

```powershell
kubectl get pods -l app=mysql -o wide --watch
```

Eventually you should see output similar to the following:

```text
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE                                NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          3m25s  10.244.3.16   aks-nodepool1-28567125-vmss000002   <none>           <none>
```

:::note

You should see that the **mysql-0** pod is now running on a different node than you noted before the failover.

:::

### Verify successful data replication and persistence for MySQL Server

Run the following command to verify the mount volume by injecting new data by running the following command.

```powershell
@'
INSERT INTO school.students VALUES (3, 'Student3');
INSERT INTO school.students VALUES (4, 'Student4');
'@ | kubectl run mysql-client --image=mysql:5.7 -i --rm --restart=Never -- mysql -h mysql-0.mysql
```

Run the command to fetch the entries previously inserted into the database.

```powershell
kubectl run mysql-client --image=mysql:5.7 -i -t --rm --restart=Never -- `
mysql -h mysql-read -e "SELECT * FROM school.students"
```

You should see output similar to the following:

```text
+------------+----------+
| RollNumber | Name     |
+------------+----------+
|          1 | Student1 |
+------------+----------+
|          2 | Student2 |
+------------+----------+
|          3 | Student3 |
+------------+----------+
|          4 | Student4 |
+------------+----------+
```

The output obtained contains the values entered before the failover. This shows that the database and table entries in the MySQL Server were replicated and persisted across the failover of **mysql-0** pod. The output also demonstrates that, newer entries were successfully appended on the newly spawned mysql server application.

Congratulations! You successfully created a replicated local NVMe storage pool using Azure Container Storage. You deployed a MySQL server with the storage pool's storage class and added entries to the database. You then triggered a failover by deleting the node hosting the workload pod and scaled up the cluster by one node to maintain three active nodes. Finally, you verified that the pre-failover data were successfully replicated and persisted, with new data added on top of the replicated data.

---

## Summary

In this workshop, you explored advanced storage options in Azure Kubernetes Service (AKS), covering both Block Storage (Azure Disks, Elastic SAN, Local Disks) and Shared File Storage solutions (Azure Files, NetApp Files, Blobs). You learned how different orchestration methods like CSI drivers and Azure Container Storage can be leveraged depending on your requirements.

Through hands-on exercises, you successfully deployed a MySQL database using replicated local NVMe storage via Azure Container Storage. You demonstrated real-world resilience by simulating node failure and verifying data persistence across failover events - a critical capability for production workloads.

For more information, check out these resources:

- [Azure Container Storage Introduction](https://learn.microsoft.com/azure/storage/container-storage/container-storage-introduction)
- [Azure Storage Introduction](https://learn.microsoft.com/azure/storage/common/storage-introduction)
- [AKS Storage Best Practices](https://learn.microsoft.com/azure/aks/operator-best-practices-storage)

# Module 7: Monitoring

---
title: Advanced Observability Concepts
sidebar_label: Advanced Observability & Monitoring
sidebar_position: 1
---

## Advanced Observability Concepts

### Overview

As a Kubernetes practitioner, you're probably familiar with managing your own Prometheus and Grafana stack for observability. With **Azure Managed Prometheus** and **Azure Managed Grafana**, you can now leverage those same cloud-native tools—without the operational burden of deploying, scaling, and securing them yourself. These managed services integrate natively with AKS and support standard Prometheus APIs and Grafana dashboards, making adoption seamless.

---

### Objectives

* Enable and Visualize Control Plane Metrics: Gain hands-on experience enabling AKS control plane metrics (e.g., kube-apiserver, etcd) and visualizing them using pre-built dashboards in **Azure Managed Grafana**.

* Customize Metric Collection: Learn how to extend observability by customizing metric collection through `ConfigMaps` and enabling additional Prometheus metrics.

* Implement Custom Scrape Jobs: Deploy and configure custom scrape jobs using `PodMonitor` and `ServiceMonitor` CRDs to collect application-specific metrics in **Azure Managed Prometheus**.

---

### Prerequisites

- An Azure Subscription
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) version 2.60.0 or later
- `aks-preview` - see note below
- [kubectl](https://kubernetes.io/docs/tasks/tools/) version 1.28.9 or later
- A terminal with `bash` (e.g.: [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com/)

:::note Note on aks-preview
To install or update the `aks-preview` extension you can use the following commands:

```powershell
# Install the aks-preview extension
az extension add --name aks-preview

# Update the aks-preview extension
az extension update --name aks-preview
```
:::

---

## AKS control plane metrics

As you may know, Kubernetes control plane components are managed by Azure and there are metrics that Kubernetes administrators would like to monitor such as `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, and `etcd`. These are metrics that typically were not exposed to AKS users... until now. 

AKS now offers a **preview feature** that allows you to access these metrics and visualize them in **Azure Managed Grafana**. More on this preview feature can be found [here](https://learn.microsoft.com/azure/aks/monitor-aks#monitor-aks-control-plane-metrics-preview). 


:::info
Before enabling this preview, review the [prerequisites and limitations](https://learn.microsoft.com/azure/aks/monitor-aks#prerequisites-and-limitations) of this feature while it is in preview.
:::

To enable the feature:

1. Register the `AzureMonitorMetricsControlPlanePreview` feature flag using the az feature register command.

```powershell
az feature register `
--namespace "Microsoft.ContainerService" `
--name "AzureMonitorMetricsControlPlanePreview"
```

2. Once the feature is registered, refresh resource provider.

```powershell
az provider register --namespace Microsoft.ContainerService
```
Once registered, you’ll be able to surface these metrics using prebuilt Grafana dashboards or your own visualizations—without managing your own Prometheus stack.

## Setup your environment
### Step 1: Define your environment variables and placeholders

In these next steps, we will setup a new AKS cluster, an **Azure Managed Grafana** instance and a Azure Monitor Workspace.

1. Create a placeholder directory

Before we begin lets create a new directory that can be a placeholder for all of our files created during this lab:

```powershell
New-Item -ItemType Directory -Path C:\k8s\labs\aks-labs\operations\advanced-observability -Force
Set-Location C:\k8s\labs\aks-labs\operations\advanced-observability
```

2. Next, proceed by declaring the following environment variables:

```powershell
@'
$RESOURCE_GROUP = "azure-rg"
$LOCATION = "eastus2"

# Azure Kubernetes Service Cluster
$AKS_NAME = "aks-@lab.LabInstance.Id"

# Azure Managed Grafana
$GRAFANA_NAME = "grafana-@lab.LabInstance.Id"

# Azure Monitor Workspace
$AZ_MONITOR_WORKSPACE_NAME = "amw-@lab.LabInstance.Id"
'@ | Set-Content -LiteralPath .\lab-env.ps1 -Encoding utf8
```
Load the environment variables:

```powershell
. .\lab-env.ps1
```

:::tip
You can reload the variables later by running `. .\lab-env.ps1` in this directory.
:::

### Step 2: Create the Azure Monitor Workspace

1. Create the resource group

```powershell
# Create resource group
az group create --name ${RESOURCE_GROUP} --location ${LOCATION}
```

2. Create an Azure Monitor Workspace

```powershell
az monitor account create `
  --resource-group ${RESOURCE_GROUP} `
  --location ${LOCATION} `
  --name ${AZ_MONITOR_WORKSPACE_NAME}
```

:::info
The resource provider `Microsoft.Monitor` is required by this operation. If not already registered, by running this command, we will register this resource for you.
:::

Retrieve the Azure Monitor Workspace ID

```powershell
$AZ_MONITOR_WORKSPACE_ID = $(az monitor account show `
  --resource-group ${RESOURCE_GROUP} `
  --name ${AZ_MONITOR_WORKSPACE_NAME} `
  --query id -o tsv)
```

### Step 3: Create an Azure Managed Grafana instance

In this step, we will do the following:

* Add the Azure Managed Grafana extension to `az cli`.

* Create an Azure Managed Grafana instance.

* Save the Azure Manage Grafana Resource identity which will later be attached to the AKS cluster.

:::info
The Azure CLI extension for Azure Managed Grafana (`amg`) allows us to create, edit, delete the Azure Managed Grafana instance from the cli. If you can't add this extension, you can still perform these actions using the Azure Portal.
:::

1. Add the Azure Manage Grafana extension to `az cli`:

```powershell
az extension add --name amg
```

2. Create an Azure Managed Grafana instance:

You can now proceed with the creation of the Managed Grafana instance:

```powershell
az grafana create `
  --name ${GRAFANA_NAME} `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION
```

3. Once created, save the Grafana resource ID

```powershell
$GRAFANA_RESOURCE_ID = $(az grafana show `
  --name ${GRAFANA_NAME} `
  --resource-group ${RESOURCE_GROUP} `
  --query id -o tsv)
```

### Step 4: Create a new AKS cluster

1. Create a new AKS cluster and attach the Grafana instance to it

```powershell
az aks create `
  --name ${AKS_NAME}  `
  --resource-group ${RESOURCE_GROUP} `
  --node-count 1 `
  --enable-managed-identity  `
  --enable-azure-monitor-metrics `
  --enable-cost-analysis `
  --grafana-resource-id ${GRAFANA_RESOURCE_ID} `
  --azure-monitor-workspace-resource-id ${AZ_MONITOR_WORKSPACE_ID} `
  --tier Standard `
  --ssh-access disabled `
  --generate-ssh-keys
```

2. Get the credentials to access the cluster:

```powershell
az aks get-credentials `
  --name ${AKS_NAME} `
  --resource-group ${RESOURCE_GROUP} `
  --file aks-labs.config
```

3. Use the retrieved aks-labs.config file as your KUBECONFIG and add it to your environment

```powershell
$env:KUBECONFIG = Join-Path $PWD "aks-labs.config"
Add-Content -LiteralPath .\lab-env.ps1 -Value '$env:KUBECONFIG = Join-Path $PSScriptRoot "aks-labs.config"'
```

In every additional PowerShell window used for Module 7, load the same settings
before running `kubectl`:

```powershell
. C:\k8s\labs\aks-labs\operations\advanced-observability\lab-env.ps1
```

:::info
PowerShell dot-sourcing (`. .\lab-env.ps1`) loads the saved variables into your
current terminal. `$env:KUBECONFIG` selects the kubeconfig file for `kubectl`.
:::

4. Check that the credentials are working:

```powershell
kubectl cluster-info
kubectl get nodes
```
---

## Working on Grafana

With Azure Managed Grafana integrated with Azure Managed Prometheus, you can import [kube-apiserver](https://grafana.com/grafana/dashboards/20331-kubernetes-api-server/) and [etcd](https://grafana.com/grafana/dashboards/20330-kubernetes-etcd/) metrics dashboards.

:::info
Out of the box, only the `etcd` and `kube-apiserver` metrics data is being collected as part of the [minimal ingestion profile](https://learn.microsoft.com/azure/aks/monitor-aks-reference#minimal-ingestion-profile-for-control-plane-metrics-in-managed-prometheus) for control plane metrics. This profile is designed to provide a balance between the cost of monitoring and the value of the data collected. 

More on the minimal ingestion profile can be found [here](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal).
:::

1. Create a folder in Grafana to host our new dashboards:

```powershell
az grafana folder create `
  --name ${GRAFANA_NAME} `
  --title AKS-Labs `
  --resource-group ${RESOURCE_GROUP}
```

2. Import the `kube-apiserver` and `etcd` dashboards into the new Grafana folder:

```powershell
# import kube-apiserver dashboard
az grafana dashboard import `
  --name ${GRAFANA_NAME} `
  --resource-group ${RESOURCE_GROUP} `
  --folder 'AKS-Labs' `
  --definition 20331

# import etcd dashboard
az grafana dashboard import `
  --name ${GRAFANA_NAME} `
  --resource-group ${RESOURCE_GROUP} `
  --folder 'AKS-Labs' `
  --definition 20330
```

3. To access the Grafana Dashboard

```powershell
$GRAFANA_UI = $(az grafana show `
  --name ${GRAFANA_NAME} `
  --resource-group ${RESOURCE_GROUP} `
  --query "properties.endpoint" -o tsv)

echo "Your Azure Managed Grafana is accessible at: $GRAFANA_UI"
```

Expected output:

```text
https://aks-labs-test-ase8bmffcgbqhjej.wus3.grafana.azure.com
```

![aks-labs-dashboards](assets/aks-labs-dashboards.png)
Now you, should be able to browse to your Azure Managed Grafana instance and see the `kube-apiserver` and `etcd` metrics dashboards in the AKS-Labs folder.

![aks-labs-dashboards](assets/dashboard-api-server.png)
The new `kube-apiserver` metrics dashboard in Grafana.

:::info
It might take up to 5 minutes for data to start showing up in your Grafana dashboard. You can refresh this page or set it to auto-refresh every few seconds

![dashboard-refresh](assets/dashboard-refresh.png)
:::

###  Example: Customizing the collection of metrics

At this point we already have the `kube-apiserver` and the `etcd` metrics being collected by Prometheus and displayed on Grafana. If you want to collect a different set of metrics, you can do so by manually enabling them and this can be done by deploying a ConfigMap named [ama-metrics-settings-configmap](https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml) in the `kube-system` namespace.

Here are some options:

* [Ingest only minimal metrics from default targets](https://learn.microsoft.com/en-us/azure/aks/control-plane-metrics-monitor#ingest-only-minimal-metrics-from-default-targets)

* [Ingest all metrics from all targets
](https://learn.microsoft.com/en-us/azure/aks/control-plane-metrics-monitor#ingest-all-metrics-from-all-targets)
 
* [Ingest a few other metrics in addition to minimal metrics](https://learn.microsoft.com/en-us/azure/aks/control-plane-metrics-monitor#ingest-a-few-other-metrics-in-addition-to-minimal-metrics)

* [Ingest only specific metrics from some targets](https://learn.microsoft.com/en-us/azure/aks/control-plane-metrics-monitor#ingest-only-specific-metrics-from-some-targets) - we are covering this example in the next section


#### Ingesting a new metric: apiserver_longrunning_requests

To illustrate the ingestion of a specific metric from some targets, lets edit the `ama-metrics-settings-configmap` to include a metric that is not a part of the [minimal ingestion profile](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal): `apiserver_longrunning_requests`. This metric will be collected from the `controlplane-apiserver` target.

![apiserver_longrunning_requests](assets/apiserver_longrunning_requests.png.png)
A description of the `apiserver_longrunning_requests` from the [Kubernetes Metrics Reference](https://kubernetes.io/docs/reference/instrumentation/metrics/)

:::tip
A full list of the available metrics is available at the [Kubernetes Metrics Reference](https://kubernetes.io/docs/reference/instrumentation/metrics/).
:::

Steps to customize the collection of a new metric:

1. Run the following command to deploy the **ama-metrics-settings-configmap** in the **kube-system** namespace.

```powershell
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml
```

2. Edit the **ama-metrics-settings-configmap** to enable the metrics you want to collect. Run the following command to edit the **ama-metrics-settings-configmap**.

```powershell
kubectl edit cm ama-metrics-settings-configmap -n kube-system
```

3. Under the `default-targets-metrics-keep-list`, add `apiserver_longrunning_requests` and then save the `ConfigMap`.

![adding apiserver_longrunning_requests](assets/customizing-the-collection.png)

It might take 1 minute for the new metric to start showing up. We can check it in the Azure Monitor Workspace and then on Grafana. 

1. Navigate to the **Azure Monitor Workspace** attached to the AKS cluster. You can find that information in the Azure Portal by navigating to the AKS Cluster created for this lab, then to **Monitor**, **Monitor Settings**. The information for the `Azure Monitor workspace` will be showed on this page.

![Azure Monitor Workspace](assets/azure-monitor-workspace.png)

Once in the `Azure Monitor workspace`, navigate to the `Prometheus Explorer` and enter the `apiserver_longrunning_requests` in the `PromQL` searching box:

![prometheus-explorer](assets/prometheus-explorer.png)

#### Create a dashboard in Grafana to visualize the new metric

Navigate to your Manage Grafana Instance, click on `Dashboards`->`AKS-Labs`->`API Server` 

![aks-labs-dashboards](assets/aks-labs-dashboards.png)

Click on `Add`  and then `Visualization`

![Add new visualization](assets/add-new-dashboard.png)

Verify that your selected Data Source is `${prom_ds}`

![ds_prom is selected](assets/ds_prom.png)

To customize the visualization, we need to first toggle the `Code` button in the `Query` part of the panel:

![enable code](assets/enable-code.png)

Next, we will do the following steps on this panel:

![custom grafana dashboard](assets/custom-grafana-dashboard.png)

1. Create a new `Time series` dashboard (should be the default visualization).
2. Add a `Title` (e.g.: apiserver_longrunning_requests)
3. Add a `Description` (e.g.: Gauge of all active long-running apiserver requests broken out by verb, group, version, resource, scope and component.).
4. Make sure the Managed Prometheus (`${prom_ds}`) is selected in the Data source. 
5. In the metrics browser, add this query:

```text
sum(rate(apiserver_longrunning_requests{cluster="$cluster"}[$__rate_interval]))
```
6. Click on Save

![click on save](assets/click-save.png)

7. Finally, click on Save Dashboard

![save the dashboard](assets/save-dashboard.png)

After close to 5 minutes, you should start seeing the `apiserver_longrunning_requests` metrics showing up in your new dashboard

![apiserver_longrunning_requests dasboard](assets/apiserver_longrunning_requests-dashboard.png)

Congratulations, you have managed to add a specific metric from the `controlplane-apiserver`! 

:::note
The Azure team does not offer a [pre-built dashboard](https://grafana.com/orgs/azure/dashboards) for some of these metrics, but you can reference the doc on [supported metrics for Azure Managed Prometheus](https://learn.microsoft.com/azure/aks/monitor-aks-reference#supported-metrics-for-microsoftcontainerservicemanagedclusters) and create your own dashboards in Azure Managed Grafana or search for community dashboards on [Grafana.com](https://grafana.com/grafana/dashboards) and import them into Azure Managed Grafana. Just be sure to use the Azure Managed Prometheus data source.
:::

---

## Custom scrape jobs for Azure Managed Prometheus

Typically, when you want to scrape metrics from a target, you would create a scrape job in Prometheus. With **Azure Managed Prometheus**, you can define custom scrape jobs for your AKS cluster using the `PodMonitor` and `ServiceMonitor` **Custom Resource Definitions (CRDs)**, which are automatically created when you enable Azure Managed Prometheus.

These CRDs are nearly identical to their open-source Prometheus counterparts, with the main difference being the `apiVersion`.

:::note  
When using Azure Managed Prometheus, specify the `apiVersion` as:  
`azmonitoring.coreos.com/v1` instead of the OSS version: `monitoring.coreos.com/v1`
:::

### What are `PodMonitor` and `ServiceMonitor`?

| CRD Type         | Targets               | Use Case                                                      | Requires Service? |
|------------------|-----------------------|----------------------------------------------------------------|-------------------|
| `PodMonitor`     | Pods (via labels)     | Scrape metrics directly from pods (e.g., sidecar exporters)    | no                |
| `ServiceMonitor` | Services (via labels) | Scrape metrics through stable service endpoints (e.g., API svc)| yes                |

This separation allows you to control how Prometheus discovers and scrapes metrics based on how your application is exposed in the cluster.

### Deploying a `PodMonitor` and a Sample Application

Let’s walk through deploying a reference app and a `PodMonitor` to collect metrics.

#### 1. Deploy a reference app

```powershell
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/internal/referenceapp/prometheus-reference-app.yaml
```

Verify it's running:

```powershell
kubectl get pods,svc -l app=prometheus-reference-app
```

Expected output:

```text
NAME                                            READY   STATUS    RESTARTS   AGE
pod/prometheus-reference-app-xxxxxxxxxx-xxxxx   2/2     Running   0          77s

NAME                                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
service/prometheus-reference-service   ClusterIP   10.0.69.176   <none>        2112/TCP,2113/TCP,2114/TCP   77s
```

#### 2. Deploy a `PodMonitor`

```powershell
kubectl apply -f https://raw.githubusercontent.com/Azure/prometheus-collector/refs/heads/main/otelcollector/deploy/example-custom-resources/pod-monitor/pod-monitor-reference-app.yaml
```

:::note
Custom metrics targets are scraped by pods with names like ama-metrics-*. The Prometheus Agent UI is exposed on port 9090, allowing inspection of scrape jobs.
:::

#### 3. Get the AMA Prometheus pod name

```powershell
$AMA_METRICS_POD_NAME = "$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[0].metadata.name}')"
```

#### 4. Port-forward Prometheus locally

```powershell
kubectl port-forward ${AMA_METRICS_POD_NAME} -n kube-system 9090
```

Open your browser at: http://localhost:9090

![prometheus-agent](assets/prometheus-agent.png)

* Under **Status > Targets**, you'll find the target:
`podMonitor/default/prometheus-reference-app-job/0`

* Under **Status > Service Discovery**, you'll see label-discovered targets for the same.

![metrics endpoints](assets/metrics-ep.png)

When you're done, stop port-forwarding by pressing `Ctrl+C`.

### Inspecting the Raw Metrics from the Reference Application

In addition to viewing metrics in Prometheus or Grafana, you can directly access the raw metrics exposed by the reference app on port **2112** using a simple port-forward.

#### 1. Port-forward to the reference app pod

```powershell
kubectl port-forward svc/prometheus-reference-service 2112:2112
```

#### 2. Open your browser or use curl
Now you can navigate to http://localhost:2112/metrics in your browser, or run:

```powershell
curl.exe http://localhost:2112/metrics
```

Example output:

```text
max_dimension_rainfall{city="chennai",location="midwest"} 0.24
max_dimension_rainfall{city="chicago",location="midwest"} 0.07
max_dimension_rainfall{city="dc",location="east"} 0.137
max_dimension_rainfall{city="dc",location="midwest"} 0.18700000000000003
max_dimension_rainfall{city="delhi",location="midwest"} 0.05
max_dimension_rainfall{city="hyderabad",location="midwest"} 0.09300000000000001
max_dimension_rainfall{city="indianapolis",location="midwest"} 0.10300000000000001
max_dimension_rainfall{city="indore",location="midwest"} 0.10700000000000001
max_dimension_rainfall{city="jaipur",location="midwest"} 0.11
max_dimension_rainfall{city="kanpur",location="midwest"} 0.19
max_dimension_rainfall{city="kolkata",location="midwest"} 0.23
max_dimension_rainfall{city="lucknow",location="midwest"} 0.147
max_dimension_rainfall{city="milwaukee",location="midwest"} 0.1
max_dimension_rainfall{city="minneapolis",location="midwest"} 0.11
max_dimension_rainfall{city="mumbai",location="midwest"} 0.14
max_dimension_rainfall{city="nagpur",location="midwest"} 0.183
max_dimension_rainfall{city="new york",location="east"} 0.18
max_dimension_rainfall{city="new york",location="midwest"} 0.11
max_dimension_rainfall{city="orlando",location="midwest"} 0.14
max_dimension_rainfall{city="orlando",location="south"} 0.16
max_dimension_rainfall{city="portland",location="midwest"} 0.21
```

These are standard Prometheus metrics types (counter, gauge, histogram, summary) designed for testing.

:::info 
This is helpful for verifying what metrics are exposed by your application before defining scrape jobs or visualizations.
:::

Once finished, press Ctrl+C to stop the port-forward session.

### Explore the Metrics in Grafana

Once metrics have been scraped for a few moments we can now use the **Explore** capability in Grafana to visualize the new metrics.

1. Open **Azure Managed Grafana**, go to the **Explore** tab

2. Change the Data Source from `Azure Monitor` to `Managed_Prometheus_azmon-adk-labs`.
![grafana-explore-data-source-picker](assets/grafana-explore-data-source-picker.png)

3. For example, we can try to query for the `max_dimension_rainfall_histogram_bucket` metric

![podMonitor Metric](assets/podMonitor.png)

We can now see the new `PodMonmitor` metrics showing up in Grafana ! From there, you can create your own dashboard using the same principles we saw earlier when we [created a dashboard in Grafana to visualize a new metric](#create-a-dashboard-in-grafana-to-visualize-the-new-metric)

---

## Summary

In this lab, we accomplished the following:

- Enabled the preview feature for AKS control plane metrics using Azure CLI.

- Deployed a new AKS cluster integrated with Azure Managed Prometheus and Azure Managed Grafana.

- Imported pre-built dashboards to visualize control plane metrics (`kube-apiserver` and `etcd`) in Grafana.

- Customized metric ingestion by editing the `ama-metrics-settings-configmap` to include specific metrics like `apiserver_longrunning_requests`.

- Deployed a reference application and configured a custom PodMonitor to scrape application metrics using Azure Managed Prometheus.

- Verified custom metrics collection using both the Prometheus UI and Azure Managed Grafana.

### Additional Resources

* [Custom CRDs for scraping](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-crd)

* [Prometheus interface in AMA](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-troubleshoot#prometheus-interface)

# Module 8: Core Security Concepts

Return to the preloaded lab folder after Module 7's generated working directory:

```powershell
Set-Location C:\k8s\labs
kubectl config set-context --current --namespace=default
```

The uploaded `Module8\spc.yaml` and `Module8\pod-kv.yaml` already contain
secret-sync settings. Task 4 replaces them with the initial volume-only
manifests; Task 5 then adds Kubernetes Secret synchronization.

This module walks through two core AKS security workflows: pulling secrets from **Azure Key Vault** into Pods via the Secrets Store CSI driver, and keeping container images patched at the **registry layer** using **ACR Continuous Patching** (Trivy + Copa).

References:
- [Azure Key Vault Provider for Secrets Store CSI Driver](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver)
- [ACR Continuous Patching](https://aka.ms/acr/patching)

## Security — Table of Contents

[Azure Key Vault](#exercise-using-secrets-stored-in-azure-key-vault)

[ACR Continuous Patching](#securing-aks-applications-with-acr-continuous-patching)

# Exercise: Using Secrets Stored in Azure Key Vault

In this Azure Key Vault exercise, you'll perform the following actions:

1. Enable Key Vault Addon in AKS - Azure installs all the components needed to integrate Key Vault with AKS
2. Create an Azure Key Vault - This will contain all the secrets you'll use
3. Grant _administrator_ permissions you your account - This will allow you to create secrets in the Key Vault.
4. Create a secret in Azure Key Vault - This will represent the sensitive data you should keep outside the cluster.
5. Grant _reader_ permissions to the AKS cluster - This will allow the cluster to read the external secret
6. Create custom resources in your cluster to establish the connection to Key Vault - This will specify the AKS identity, Key Vault and secret that will be injected into your Pod.
7. Mount a CSI secrets volume in your Pod - This will use the information in custom to resource retrieve and mount your secret.

### Task 1 - Enable Key Vault Addon in AKS and create a Key Vault

1. Define variables.

```powershell
$RESOURCE_GROUP = "azure-rg"
$KV_NAME = "kv-@lab.LabInstance.Id"
$AKS_NAME = "aks-@lab.LabInstance.Id"
$LOCATION = "eastus2"
```

> If you already have an AKS cluster from an earlier module, set `RESOURCE_GROUP` and `AKS_NAME` to that cluster's values instead.


2. Enable Key Vault Addon in AKS

```powershell
az aks addon enable --addon azure-keyvault-secrets-provider --name $AKS_NAME --resource-group $RESOURCE_GROUP
```

3. Verify addon has been enabled

```powershell
az aks addon list --name $AKS_NAME --resource-group $RESOURCE_GROUP -o table
```

![AKS addons list showing azure-keyvault-secrets-provider enabled](content/key-vault-addon.png)

4. Create Key Vault. Notice the **--enable-rbac-authorization** option. This will allow AKS to use its managed identity to access the Key Vault.

```powershell
az keyvault create --name $KV_NAME --resource-group $RESOURCE_GROUP --enable-rbac-authorization
```

### Task 2 - Assign Permissions for you to create Secrets from Key Vault

1. List the secrets in the Key vault.

```powershell
az keyvault secret list --vault-name $KV_NAME
```

![Key Vault not authorized error message](content/key-vault-not-auth.png)

Even though you created the Key Vault, you don't automatically have access to the Data Plane of the vault. You must give yourself additional permissions first.

You can assign yourself as the **Key Vault Secrets Officer**, which will allow you to maintain secrets. You may wish to use **Key Vault Administrator** instead, which will allow you create Keys and Certificates as well.

2. Get the _object id_ of the Key Vault:


```powershell
$KV_ID = $(az keyvault list --query "[? name=='${KV_NAME}'].{id:id}" -o tsv)
```


3. Get **_your_** object id:

```powershell
$CURRENT_USER_ID = $(az ad signed-in-user show --query "{id:id}" -o tsv)
```

4. Assign yourself the Key Vault Secrets Officer/Administrator role:

```powershell
az role assignment create --role "Key Vault Secrets Officer" --assignee-object-id $CURRENT_USER_ID --scope $KV_ID
```

5. List the secrets in the Key Vault again. This time you should get an empty list instead of "not authorized" error.

```powershell
az keyvault secret list --vault-name $KV_NAME
```

6. Create a sample secret for testing

```powershell
az keyvault secret set --vault-name $KV_NAME --name SampleSecret --value "Highly sensitive information: <place data here>"
```

7. Verify the secret is in the Key Vault

```powershell
az keyvault secret list --vault-name $KV_NAME -o table
```

You should now see the secret listed.

### Task 3 - Assign Permissions to AKS to read Secrets from Key Vault

You'll need to assign AKS the **Key Vault Secrets User** role so it's able to read the secrets you created.

1. List all available identities. Find the managed identity created for accessing the Key Vault from AKS when the addon was enabled.

```powershell
az identity list --query "[].{name:name,ClientId:clientId}" -o table
```

![az identity list output showing azurekeyvaultsecretsprovider identity](content/aks-kv-identity.png)

2. Get the object id of that managed identity AKS is using

```powershell
$KV_IDENTITY = $(az identity list --query "[? contains(name,'azurekeyvaultsecretsprovider')].{principalId:principalId}" -o tsv)
$KV_CLIENT_ID = $(az identity list --query "[? contains(name,'azurekeyvaultsecretsprovider')].{clientId:clientId}" -o tsv)
```

3. Assign the AKS identity permission to read secrets from the Key Vault.

```powershell
az role assignment create --role "Key Vault Secrets User" --assignee-object-id $KV_IDENTITY --scope $KV_ID
```

### Task 4 - Create Kubernetes resources and read secret from Key Vault

1. Gather the needed values

```powershell
$TENANT_ID = $(az aks show --name $AKS_NAME --resource-group $RESOURCE_GROUP --query "{tenantId:identity.tenantId}" -o tsv)

echo $KV_CLIENT_ID
echo $KV_NAME
echo $TENANT_ID
```


2. Change to the lab assets folder:


```powershell
Set-Location C:\k8s\labs
```


3. Open `Module8\spc.yaml`. Replace its entire contents with the manifest below,
   then fill in the placeholders. This removes the uploaded secret-sync settings
   and configures the add-on's VM managed identity.

```powershell
code Module8/spc.yaml
```

4. Replace the placeholders with the values listed above.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-secret
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: <client-id>
    keyvaultName: <key-vault-name>
    cloudName: ""
    objects: |
      array:
        - |
          objectName: SampleSecret
          objectType: secret 
          objectVersion: ""
    tenantId: <tenant-id>
```

5. Apply the manifest.

```powershell
kubectl apply -f Module8/spc.yaml
```

6. Open `Module8\pod-kv.yaml` and replace its entire contents with the manifest
   below. Do not retain the uploaded `env` reference to `k8s-secret`: Task 5
   creates that Secret later.

```powershell
code Module8/pod-kv.yaml
```

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: pod-kv
spec:
  containers:
    - name: busybox
      image: registry.k8s.io/e2e-test-images/busybox:1.29-1
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
        - name: secrets-store01
          mountPath: "/mnt/secrets-store"
          readOnly: true
  volumes:
    - name: secrets-store01
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kv-secret"
```

7. Apply the manifest.

```powershell
kubectl apply -f Module8/pod-kv.yaml
```

8. View secret value in Pod

```powershell
kubectl exec -it pod-kv -- cat /mnt/secrets-store/SampleSecret
```

You should now be able to see the content of the Key Vault secret you created earlier.

### Task 5 - Create a Kubernetes Secret from a secret in Key Vault

Many Kubernetes resources use _Secret_ resources (Ingress, Persistent Volumes, etc.). You can extend the SecretProviderClass to also create a Kubernetes Secret object when you mount the Pod.

1. Edit the **SecretProviderClass** you created earlier.

```powershell
code Module8/spc.yaml
```

Add the indicated section.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-secret
spec:
  provider: azure

  ########## Add this section #########
  secretObjects:
  - data:
    - key: MySecret
      objectName: SampleSecret
    secretName: k8s-secret
    type: Opaque
  ########## End of section #########

  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
  ...
```

2. Update the object.

```powershell
kubectl apply -f Module8/spc.yaml
```

3. Edit the Pod manifest. Notice the **_env_** section setting the environment variable.

```powershell
code Module8/pod-kv.yaml
```

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: pod-kv
spec:
  containers:
    - name: busybox
      image: registry.k8s.io/e2e-test-images/busybox:1.29-1
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
        - name: secrets-store01
          mountPath: "/mnt/secrets-store"
          readOnly: true

      ########## Add this section #########
      env:
        - name: SECRET_VALUE
          valueFrom:
            secretKeyRef:
              name: k8s-secret
              key: MySecret
      ########## End of section #########

  volumes:
    - name: secrets-store01
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kv-secret"
```

4. Since Pods are immutable, you'll have to delete it and then reapply the manifest.

```powershell
kubectl delete pod pod-kv
kubectl apply -f Module8/pod-kv.yaml
```

5. View the secret in the Pod.

```powershell
kubectl exec -it pod-kv -- printenv
```

![kubectl exec printenv output showing SECRET_VALUE](content/key-vault-env1.png)

6. Verify the Secret object has been created and is available for other Pods to use.

```powershell
kubectl get secret
```

![kubectl get secret output showing k8s-secret](content/key-vault-secret.png)

7. Delete the Pod and the Kubernetes Secret object will also be deleted. Once an injected Secret is no longer referenced by any Pods, it's automatically deleted.

```powershell
kubectl delete pod pod-kv
```

```powershell
kubectl get secret
```

Once an injected Secret is no longer referenced by any Pods, it's automatically deleted.

[Module 8: Core Security Concepts](#module-8-core-security-concepts)

[List of Modules](#modules-list)

## Securing AKS Applications with ACR Continuous Patching

Azure Kubernetes Service (AKS) provides a powerful platform to build, deploy, and manage secure cloud-native applications effortlessly. With [**Azure Container Registry (ACR) Continuous Patching**](https://aka.ms/acr/patching), you can enhance the security of your AKS workloads by addressing operating system (OS)-level vulnerabilities in container images directly within the registry, without needing to rebuild the images from source code.

ACR Continuous Patching utilizes the open-source [Trivy](https://trivy.dev/) scanner to detect vulnerabilities and [Copa (Copacetic)](https://project-copacetic.github.io/copacetic/website/) to apply security updates, ensuring that your container images remain patched, up-to-date, and secure within the registry. This approach seamlessly integrates with AKS best practices for secure deployments, providing a robust security solution for deployed containerized workloads. This includes remediating vulnerabilities for various types of container images, including those you do not have source code access to perform a rebuild, such as vendor-supplied or open-source images.

By the end of this lab, you will understand how ACR Continuous Patching secures vulnerable container images, empowering you to maintain a more secure and reliable cloud-native environment within your AKS cluster.

## Objectives

By the end of this lab, you will be able to:

- Understand how to import a container image into Azure Container Registry (ACR) from an upstream registry.
- Deploy the imported image to an Azure Kubernetes Service (AKS) cluster.
- Run Trivy scans against container images in ACR to detect patchable OS-level vulnerabilities.
- Configure and run ACR Continuous Patching Workflows to generate a patched version of the vulnerable image within the registry on a specified schedule.
- Inspect and scan the newly generated patched image within the registry to observe the effects of ACR Continuous Patching.
- Update and apply your Kubernetes deployment to reference the newly patched image.

## Scenario Overview

1. **Infrastructure Setup**
   - Create a resource group.
   - Create an ACR registry and an AKS cluster in the same resource group.
   - Attach the ACR to the AKS cluster so that AKS can pull images from it.

2. **Image Import & Deployment**
   - Import the publicly available `nginx` image into ACR.
   - Deploy this image to AKS as a Kubernetes Deployment.

3. **Vulnerability Detection**
   - Use Trivy to scan the imported `nginx` image in ACR for OS-level vulnerabilities.

4. **ACR Continuous Patching**
   - Enable ACR Continuous Patching by creating a workflow and pointing it to our `nginx` repository/tag.
   - Use the `--run-immediately` flag to generate a patched version of the image on demand instead of waiting for the specified Continuous Patching schedule to kick in.

5. **Inspecting New Patched Image**
   - Use Trivy to scan the newly generated patched image in ACR to see the effects of ACR Continuous Patching.

6. **Redeploy with Patched Image**
   - Update the Kubernetes deployment to reference the newly patched image.
   - Verify that the vulnerabilities are either mitigated or substantially reduced.

Create a new resource group, ACR registry, and AKS cluster. Afterwards, authenticate `trivy` and `kubectl` with the resources.

> **This lab requires a fresh cluster.** It needs `--attach-acr` set at create time so AKS can pull from the new registry without manual role assignments. If a cluster from a prior module already exists under the same name, delete it first:
>
> ```powershell
> az aks delete -g azure-rg -n aks-@lab.LabInstance.Id --yes
> ```

1. Set Environment Variables (optional, for convenience):

    ```powershell
    $RESOURCE_GROUP = "azure-rg"
    $LOCATION = "eastus2"
    $ACR_NAME = "acr@lab.LabInstance.Id"
    $AKS_NAME = "aks-@lab.LabInstance.Id"
    $IMAGE_VERSION = "1.25"
    ```

2. Create the Resource Group:

    ```powershell
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

3. Register for the Azure Container Registry Resource Provider:

    ```powershell
    az provider register --namespace Microsoft.ContainerRegistry
    ```

    Confirm that the registration is successful:

    ```powershell
    az provider show --namespace Microsoft.ContainerRegistry --query "registrationState"
    ```

    It should show output like the following:

    ```text
    "Registered"
    ```

4. Create an ACR Registry:

    ```powershell
    az acr create `
      --name $ACR_NAME `
      --resource-group $RESOURCE_GROUP `
      --sku Premium `
      --location $LOCATION
    ```

5. Authenticate `trivy` from the VM's PowerShell window:

    ```powershell
    az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken `
        | trivy registry login `
            --username 00000000-0000-0000-0000-000000000000 `
            --password-stdin ${ACR_NAME}.azurecr.io
    ```

6. Register for the Azure Kubernetes Service Resource Provider:

    ```powershell
    az provider register --namespace Microsoft.ContainerService
    ```

    Confirm that the registration is successful:

    ```powershell
    az provider show --namespace Microsoft.ContainerService --query "registrationState"
    ```

    It should show output like the following:

    ```text
    "Registered"
    ```

7. Create an AKS Cluster:

    ```powershell
    az aks create `
      --name $AKS_NAME `
      --resource-group $RESOURCE_GROUP `
      --attach-acr $ACR_NAME `
      --no-ssh-key `
      --location $LOCATION
    ```

8. Authenticate with the AKS cluster by getting its AKS Credentials:

    ```powershell
    az aks get-credentials `
      --name $AKS_NAME `
      --resource-group $RESOURCE_GROUP
    ```

## Step 2: Import & Deploy the Vulnerable Image

1. Import the container image into the ACR registry:

    ```powershell
    az acr import `
      --name $ACR_NAME `
      --resource-group $RESOURCE_GROUP `
      --source mcr.microsoft.com/mirror/docker/library/nginx:$IMAGE_VERSION `
      --image nginx:$IMAGE_VERSION
    ```

2. Confirm the image is now in your ACR:

    ```powershell
    az acr repository show-tags `
      --name $ACR_NAME `
      --repository nginx
    ```

    You should see output similar to:

    ```text
    [
      "1.25"
    ]
    ```

3. Deploy the image to the AKS cluster by using a Kubernetes deployment manifest pointing to this newly imported image:

    ```powershell
    @"
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: ${ACR_NAME}.azurecr.io/nginx:$IMAGE_VERSION
            ports:
            - containerPort: 80
    "@ | Set-Content -LiteralPath nginx-deployment.yaml -Encoding utf8

    kubectl apply -f nginx-deployment.yaml
    kubectl rollout status deployment/nginx-deployment
    ```

4. Verify that the deployment is running:

    ```powershell
    kubectl get pods
    ```

## Step 3: Scan the Image for Vulnerabilities

Before we enable continuous patching, let's inspect the imported image to see whether it has patchable OS-level vulnerabilities.

1. **Install `trivy`** (if not already installed). See [Trivy Installation](https://trivy.dev/latest/getting-started/installation/).

2. **Scan the Imported Image**: We must reference the image from our ACR, including its fully qualified domain name:

    ```powershell
    trivy image --pkg-types os --ignore-unfixed ${ACR_NAME}.azurecr.io/nginx:$IMAGE_VERSION
    ```

    You should see a list of OS-related vulnerabilities. Example output might look like:

    ```text
    ...
    Total: 17 (UNKNOWN: 0, LOW: 2, MEDIUM: 12, HIGH: 3, CRITICAL: 0)
    ...
    ```

    This confirms we have vulnerabilities in the imported image that can potentially be patched by ACR Continuous Patching, directly within the registry.

## Step 4: Enable ACR Continuous Patching

1. Install the Preview ACR Extension for ACR Continuous Patching. When prompted for confirmation, confirm the installation by typing in `y` and pressing Enter.

    ```powershell
    az extension add -n acrcssc
    ```

2. Create the ACR Continuous Patching configuration file:

    ```powershell
    @"
    {
      "version": "v1",
      "tag-convention": "incremental",
      "repositories": [
        {
          "repository": "nginx",
          "tags": ["$IMAGE_VERSION"],
          "enabled": true
        }
      ]
    }
    "@ | Set-Content -LiteralPath continuouspatching.json -Encoding utf8
    ```

    Key fields:
    - **version**: Use `"v1"` to specify the schema version of the Continuous Patching configuration file.
    - **tag-convention**: Supported values are either `"incremental"` or `"floating"`.
      - When `"incremental"` is chosen, each new Continuous Patch increments a numerical suffix (e.g., `-1`, `-2`, etc.) on the original tag. For instance, if the vulnerable image is `nginx:1.25`, the first run of ACR Continuous Patching creates `nginx:1.25-1` within the registry, and a second run on that same tag creates `nginx:1.25-2`.
      - When `"floating"` is chosen, a single mutable tag, `-patched`, will always reference the latest patched version of your image. For instance, if the vulnerable image is `nginx:1.25`, the first patch creates `nginx:1.25-patched`. With each subsequent ACR Continuous Patch run, the `-patched` tag will automatically update to point to the most recent patched image generated within your registry.
    - **repositories**: Points to the repository of the vulnerable container image.
    - **tags**  is an array of tags separated by commas. The wildcard  `*`  can be used to signify all tags within that repository.

3. Validate a dry run of ACR Continuous Patching:

    You can see what images would be patched by running a dry run. The `--schedule 1d` means the workflow repeats every day.

    ```powershell
    az acr supply-chain workflow create `
      --registry $ACR_NAME `
      --resource-group $RESOURCE_GROUP `
      --type continuouspatchv1 `
      --config ./continuouspatching.json `
      --schedule 1d `
      --dry-run
    ```

    The output shows which images match your config. If everything looks correct, proceed.

4. Enable the ACR Continuous Patching schedule. Simultaneously, using the `--run-immediately` flag, we instruct ACR Continuous Patching to immediately scan and patch the image instead of waiting for the specified schedule to kick in.

    ```powershell
    az acr supply-chain workflow create `
      --registry $ACR_NAME `
      --resource-group $RESOURCE_GROUP `
      --type continuouspatchv1 `
      --config ./continuouspatching.json `
      --schedule 1d `
      --run-immediately
    ```

    Key fields:
    - **`--schedule 1d`**: This means that, after today, the next patch cycle will run once every day (aligning with the day multiples for the month).
    - **`--run-immediately`**: Forces a patch run now (instead of waiting for the scheduled day).

5. Observe the Patching Workflow (Optional):

    You can observe the newly created tasks in the Azure Portal:

    - Navigate to your container registry.
    - Under **Services**, click on **Tasks**.
    - You should see Tasks named `cssc-trigger-workflow`, `cssc-scan-image`, and `cssc-patch-image`.
    - Click on these Tasks to view the scanning and patching logs for ACR Continuous Patching.

    You can also check the logs using the CLI:

    ```powershell
    az acr supply-chain workflow show `
      --registry $ACR_NAME `
      --resource-group $RESOURCE_GROUP `
      --type continuouspatchv1
    ```

    Alternatively, you can also check logs with:

    ```powershell
    az acr task list-runs -r $ACR_NAME -n cssc-scan-image
    az acr task list-runs -r $ACR_NAME -n cssc-patch-image
    ```

## Step 5: Inspect and Scan the New Patched Image

1. Confirm a new patched image is generated within the registry by looking for the incremental patch tag:

    After a few minutes, the patching workflow completes. List tags in your `nginx` repository:

    ```powershell
    az acr repository show-tags `
      --name $ACR_NAME `
      --repository nginx
    ```

    Expected output:

    ```text
    [
      "1.25",
      "1.25-1"
    ]
    ```

    The tag `1.25-1` refers to the newly patched image within the registry.

2. Scan the new patched image in the registry with `trivy` to see the security benefits of ACR Continuous Patching:

    ```powershell
    trivy image --pkg-types os --ignore-unfixed ${ACR_NAME}.azurecr.io/nginx:$IMAGE_VERSION-1
    ```

    You should see output confirming that the new patched image has 0 fixable OS-level vulnerabilities, indicating that ACR Continuous Patching successfully remediated them.

## Step 6: Update Your Kubernetes Deployment

1. Deploy the Patched Image:

    Update the Kubernetes deployment to reference the `-1` incremental patch image:

    ```powershell
    $MANIFEST_PATH = Join-Path $PWD "nginx-deployment.yaml"
    $MANIFEST = Get-Content -LiteralPath $MANIFEST_PATH -Raw
    $MANIFEST.Replace("nginx:${IMAGE_VERSION}", "nginx:${IMAGE_VERSION}-1") |
        Set-Content -LiteralPath $MANIFEST_PATH -Encoding utf8

    kubectl apply -f nginx-deployment.yaml
    kubectl rollout status deployment/nginx-deployment
    ```

    Check that the relevant pods have been deployed and are running:

    ```powershell
    kubectl get pods -l app=nginx -o wide
    ```

    You can use `kubectl describe` to describe one of the pods to confirm the pod is indeed running the incremental patch image.

    ```powershell
    kubectl describe pod $(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
    ```

## Summary

Congratulations! You have successfully:

- **Created** a resource group, ACR, and AKS cluster.
- **Imported** a vulnerable `nginx` image into ACR.
- **Deployed** the image to AKS and confirmed there are patchable OS-level vulnerabilities via **Trivy** scans.
- **Enabled** ACR Continuous Patching to automatically detect and patch OS-level vulnerabilities.
- **Inspected** the newly patched container image within the registry to see the security benefits of ACR Continuous Patching.
- **Redeployed** your Kubernetes workload to use the newly patched image.

### Key Takeaways

1. **OS-Level Vulnerabilities**: Trivy scanned your container images to detect patchable vulnerabilities in OS packages.
2. **Automated Remediation**: ACR Continuous Patching automatically creates new patched images, saving you from rebuilding images from the ground up.
3. **Incremental Tagging**: Our patching approach used `-1` suffix tags to preserve version history. Additional patches would yield `-2`, `-3`, etc.
4. **Scheduling**: You can choose how frequently ACR runs its patch cycle (e.g., `1d`, `7d`).
5. **Rolling Updates**: By updating your Kubernetes Deployment’s image tag, you can seamlessly roll out patched images without downtime.

### Documentation

- For more info on ACR Continuous Patching, see the [ACR Continuous Patching Documentation](https://aka.ms/acr/patching).

### Next Steps

- Integrate these steps into a CI/CD pipeline for fully automated vulnerability detection and remediation.
- Explore advanced scheduling or [floating tag-convention](https://project-copacetic.github.io/copacetic/website/) if you prefer a single always-updated `-patched` tag instead of incremental tags.

## Cleanup

If you no longer need the resources:

```powershell
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

[Module 8: Core Security Concepts](#module-8-core-security-concepts)

[List of Modules](#modules-list)
