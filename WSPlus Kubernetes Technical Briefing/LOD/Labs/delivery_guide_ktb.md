# Delivery Guide: Workshop Plus Kubernetes Tech Briefing

This guide will provides details and instructions to help you deliver the **Workshop Plan** for your customer. This engagement must accomplish the following objectives:  

## Objectives

- Identify the customers goals for AKS and what areas to upskilling
- Establish a skilling plan around the apps being run on AKS
- Create a project plan with the customer to identify goals after skilling

## Deliverable Standards

Education sessions for selected workshops containing instructor sessions with slides, demos, and hands-on labs.

## Customer Participants

Having the right customer participants in the  workshop is essential to completing a successful engagement. Ensure the customer roles outlined below are available and able to participate in the workshop.

|Customer Role | Description | Required or Optional|
|----|----|----|
|Maker | Anybody interested in development | Optional|
|Developer| People with experience in coding or advanced makers | Optional|
|Architect| People with experience in designing and architecting solutions | Required|
|Lead Developer| Responsible for delivering and reviewing PoC, Code and Design | Required|
|DevOps/DevSecOps | Team responsible for deploying application to production| Required*|
|Security Lead | Team responsible for security across all aspects of the application | Optional*|
|IT Professionals| These are the people responsible for provisioning and managing IT resources like databases, networking, compute, IAM, Security, etc.  | Optional*|

> [!NOTE]
> One of these key resources maybe required. It is recommended to have at least one of them included in the conversation. For example, security and DevOps integration are integral part of modernizing any application development. So the people responsible for implementation should be included in the conversation to accelerate and facilitate the application modernization efforts.

## Customer Prereqs

- Customers should have a general knowledge of containers before attending the workshop. This workshop should *NOT* be used as a substitue for container upskilling. Dispatch a custom engagement for that or consult the microservices workshop for that material.
- Customers should have a general understanding of Azure. 

## Delivery Guidance

This section includes all non-technical delivery guidance and supporting artifacts for workshop plan. You are free to adapt each step to meet your customers needs as long as you are able to meet the objectives and deliverable standards for next phase.

### Step 1: Preparing for the delivery

- Ensure you have good understanding of workshop material, especially demos and labs.  
  They are critical for good student experience.
- Ensure right audience are present for the workshop.  
  Refer to [Customer Participants](#customer-participants) section for details.
- Ensure the [pre-reqs](#customer-prereqs) for the workshop(s) are met.


### Step 2: Scoping

#### Background

This workshop is designed to assist in learning the about the different features of AKS and kubernetes fundamentals. AKS is the main focus, but there is a track for kubernetes fundamentals for customers that do not have any background in general kubernetes.

While delivering this workshop think about what the customers endgoals are beyond the upskilling component to map out the correct follow up VBDs.

#### Scoping Guidance Agenda

Explain how the delivery will be carried out. What they can expect at each phase, before and after delivery. Request customer that for the successful delivery who would you need. Refer to [Customer Participants](#customer-participants) section for details.

Reference here for a detailed overview of how to hold a [Scoping Call](https://aka.ms/VBDScoping).

Ensure you discuss and understand the customer's requirements and tooling to be used (Azure DevOps or GitHub) is agreed for secure DevOps at a high level and review any customer document that will be used for VBD. Ensure all the stakeholders are on the same page regarding the deliverables - **not only what workshop would cover but also that it will not be a PoC**.

If the customer is planning to use their own subscription(s) for labs then make sure that they have the required access to perform labs.

Use the PowerPoint deck [here](https://microsoft.sharepoint.com/teams/ASDIPRelease/IP%20Release/Forms/AllItems.aspx?OR=Teams%2DHL&CT=1736362961913&clickparams=eyJBcHBOYW1lIjoiVGVhbXMtRGVza3RvcCIsIkFwcFZlcnNpb24iOiI0OS8yNDEyMDEwMDIxMyJ9&FolderCTID=0x012000F569B1CB3A2B2D499B8B6646AC5C92E3&id=%2Fteams%2FASDIPRelease%2FIP%20Release%2FModern%20Apps%2FWorkshopPlus%2FWorkshopPLUS%20%2D%20Kubernetes%20Technical%20Briefing%20with%20Labs) for the Scoping.

Use scoping call to understand what topics you may have to prepare / cover during the engagement, choose from the list below:

## Agenda

The agenda will depend on what modules are scoped for the customer. The delivering CSA can organize this anyway they see fit for the customer, but below are two recommended tracks depending on what the customer needs. Not all modules will be able to be covered in the alloted time. 


### Option 1

This delivery option can include the fundamentals portion which will take at least half a day to deliver.

#### Day 1

- Kubernetes Fundamentals 
- What is AKS
- AKS Security


#### Day 2

- AKS Deployments
- AKS Networking
- AKS Security


Use the IP Kit to deliver and present these concepts to your customers [IP Kit](https://microsoft.sharepoint.com/teams/ASDIPRelease/IP%20Release/Forms/AllItems.aspx?OR=Teams%2DHL&CT=1736362961913&clickparams=eyJBcHBOYW1lIjoiVGVhbXMtRGVza3RvcCIsIkFwcFZlcnNpb24iOiI0OS8yNDEyMDEwMDIxMyJ9&FolderCTID=0x012000F569B1CB3A2B2D499B8B6646AC5C92E3&id=%2Fteams%2FASDIPRelease%2FIP%20Release%2FModern%20Apps%2FWorkshopPlus%2FWorkshopPLUS%20%2D%20Kubernetes%20Technical%20Briefing%20with%20Labs)

### Option 2

This option assumes the customer does not require basic kubernetes fundamentals and just wants to learn about AKS and its features.

#### Day 1

- What is AKS
- AKS Networking
- AKS Deployments

#### Day 2

- AKS Monitoring, Observability and Cost Analysis
- AKS Security
- AKS Scaling
- AKS Storage

#### Modules

| Topic                       | Description                                   | Links                                                                                      |
|-----------------------------|-----------------------------------------------|--------------------------------------------------------------------------------------------|
| Kubernetes Fundamentals Part 1  | Kubernetes basic Objects and Cluster Components | [Part 1](#kubernetes-fundamentals-part-1) |
| Kubernetes Fundamentals Part 2  | Manging Resource Utlization, Workload Placement and Scaling, Common Tools | [Part 2](#kubernetes-fundamentals-part-2) |
| What is AKS?  | | [Module outline](#what-is-aks)|
| AKS Deployments | | [Module outline](#aks-deployments) |
| AKS Monitoring, Observability and Cost Analysis | | [Module outline](#aks-monitoring-observability-and-cost-analysis) |
| AKS Networking  | | [Module outline](#aks-networking) |
| AKS Security | | [Module outline](#aks-security) |
| AKS Storage | | [Module outline](#aks-storage) |
| Node Scaling | | [Module outline](#node-scaling) |

> [!IMPORTANT]
> The topics for the workshop delivery may change as Azure platform is changing everyday. Refer to the respective VBD resources for up-to-date list of contents.

Some example questions you may ask during the scoping are:

- What do you expect from the delivery?
- What technical / business problem are you expecting the workshop to solve?
- What topic areas interest within secure DevOps PoC that is most relevant to the team?
- What are the skill levels of the developers, operation and security teams?

> [!NOTE]
> If you pick more than one VBD IP, the total Workshop duration will increase by 3 days for each additional IP (**Total days = 3 x # IPs**). Most VBD IPs are between 2-4 days. Remember to update the duration as needed.

### Step 3: Kickoff

Reference here for a detailed overview of how to hold a [Kickoff meeting](https://aka.ms/VBDKickoff).

Share details of what workshop(s) would cover and what will not be covered. If a specific topic of interest is not covered, then you should have already thought about handling it during or after scoping.

Use the PowerPoint deck [here](https://microsoft.sharepoint.com/:f:/r/teams/ASDIPRelease/IP%20Release/Modern%20Apps/Value%20Based%20Deliverables/VBD%20-%20Modernize%20Enterprise%20Apps%20with%20Java?csf=1&web=1&e=k6LAVc) for the Kickoff.

### Step 4: Delivery

Ensure you cover modules that are relevant to or identified for the success of VBD.

**When to engage Data & AI CSAs:** As we embark on era of AI, let’s understand as part of the execution how the app will be infused with AI to power innovation. Following are a set of leading questions/conversation starters and links to specific AI VBDs to help the customer on their journey. Work with the CSAM to schedule an engagement with the Data & AI CSA.

- Is your team looking at using LLMs with applications and need better understanding of the AOAI Service?
- Do you want to envision some use cases for AOAI with apps that will bring faster time to value?

The relevant VBD to deliver under Data & AI workload -> [Plan and Execution for Innovating Apps with Azure OpenAI](https://eng.ms/docs/microsoft-customer-partner-solutions-mcaps-core/customer-experience-and-support/customer-success/data-ai/resource-center/vbd-fy24/02-bldmdrnzaiapps/05-innovappaoai/archdesignreview)

### Step 5: Customer Closeout

Reference here for a detailed overview of how to hold a [Closeout meeting](https://aka.ms/VBDCloseOutMeeting).

If needed to send follow-up materials / resources to the attendees. Ensure that the customer understands what the next steps are after the workshop(s). You need to understand basics of VBD and tell them what they can expect next.

Use the PowerPoint deck [here](https://microsoft.sharepoint.com/:f:/r/teams/ASDIPRelease/IP%20Release/Modern%20Apps/Value%20Based%20Deliverables/VBD%20-%20Modernize%20Enterprise%20Apps%20with%20Java?csf=1&web=1&e=k6LAVc) for the Closeout.

## Module overviews, demos, and troubleshooting

### Kubernetes Fundamentals Part 1



#### What is kubernetes

- kubernetes overview 
- CSA should talk about why it was developed, usage among companies and in Azure
- High level main features

#### Cluster Components

- Slide notes go into details here
- talking about what forms the kubernetes stack
- Control plane components
  - talk about the different controllers and how they work
    - api-server, controller-manager, scheduler, etcd
  - Talk about what a controller is and how they are designed

- Worker node components
  - referred to as agent nodes in the slides
  - kubelet, kube-proxy, Runtime
  - talk about the different runtimes available for kubernetes
  - Can even go into detail on how CRI and containerd works depending on the audience

#### Basic Kubernetes Objects

- Pods
- Deployments
- kubectl
- Demo 1
  - Demo the manifests for basic pod deployments showing off how they work and are structured
  - run the demo-basic-deployments.sh or .ps1 ideally this should all be in Linux
- Services
  - all slides are included. 
  - NodePort and External Name are hidden. If relevant include them in your delivery.
- Advanced Deployment Strategies
  - Blue/Green Deployment
  - Canary
- Demo 2
  - run the demo scripts with clusterinfo up.
  - demo-services.sh, demo-blue-green-deployments.sh, demo-canary-deployments.sh
- Pod ENV Variables, ConfigMaps, Secrets
  - Emphasize the importance of not putting sensitive variables into configmaps and pod envs
  - Briefly mention how in AKS AKV is to be used to injection secrets. This is covered in the security module
- Demo 3 
- Emphemeral Volumes and Persistent Volumes
  - Overview of kuberentes volumes types
  - Overview of PVs and PVCs and how they work in kubernetes
  - Brief explaination of how it interacts with Azure Disks and Files. Deep dives should 


#### Demos

Demo scripts exist in the kubernetes_fundamentals_demos section in the IPKit. 
There are scripts for both linux and powershell. Linux is encouraged as the demos for the AKS portion will all be linux based. 



### Kubernetes Fundamentals Part 2

#### Demos

Demo scripts exist in the kubernetes_fundamentals_demos section in the IPKit. 
There are scripts for both linux and powershell. Linux is encouraged as the demos for the AKS portion will all be linux based. 


#### Lab

This lab covers both parts of kubernetes fundamentals

### What is AKS

#### Sections


#### Demos

### AKS Deployments

#### Sections


#### Demos

### AKS Networking

#### Sections


#### Demos

### AKS Monitoring, Observability and Cost Analysis

#### Sections


#### Demos

### AKS Security

#### Sections


#### Demos

### AKS Storage

#### Sections


#### Demos

### Node Scaling 

#### Sections


#### Demos

## Community Support

- {Teams channel}