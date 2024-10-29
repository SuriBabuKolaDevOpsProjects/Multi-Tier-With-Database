# Multi-Tier with Database
## Launch Instances
* First create Security Group with Ports `22, 25, 80, 443, 465, 6443 & 2000-11000`.
* Then Launch Instances
  * One Instance with `Ubuntu Server`, Instance Type `t2.medium` and Volume `20Gb` for Server.
  * One Instance with `Ubuntu Server`, Instance Type `t2.large` and Volume `25Gb` for Jenkins.
  * Two Instances with `Ubuntu Server`, Instance Type `t2.medium` and Volume `20Gb` for SonarQube and Nexus3.

## SonarQube
* Connect to SonarQube Instance.
* Update Packages and install Docker.
* Search for `SonarQube Image`, take `lts-community⁠` Image and Run the Container.
```
docker container run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
```
* Access SonarQube
    * Log in to SonarQube using default Login Name & Password `admin`.
      * Update New Password
    * Generate Token and store in safe place.
      * Go to `Administration --> Security --> Users --> Click on Tokens`.
      * Give `Name` and click `Generate`.
      * Copy and Store in safe place.

## Nexus3
* Connect to Nexus3 Instance.
* Update Packages and install Docker.
* Search for `Sonatype Nexus Image`, take that Image and Run the Container.
```
docker container run -d --name nexus3 -p 8081:8081 sonatype/nexus3:latest
```
* Access Nexus3
    * Click `Sign in`
      * Username: `admin`
      * Password: Password is available in `sonatype-work/nexus3/admin.password`
      * Provide New Password and Enable/Disable anonymous access based on requirement.

## Server
### SetUp EKS Cluster using Terraform
* Connect Server
  * Install and Configure `AWS CLI`
  * Install `Terraform`
* `Write Terraform Template for EKS Cluster`.
  * Apply the Template
* Install `Kubectl` to interact with K8s Cluster
  * Get `Kubeconfig file`
    ```
    aws eks --region <Provide-Region> update-kubeconfig --name <Cluster-Name>
    ```
* **Setup RBAC (Role-Based Access Control) in Kubernetes for Jenkins:**
  * Create Namespace.
    ```
    kubectl create namespace webapps
    ```
  * Creating Service Account
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: jenkins
      namespace: webapps
    ```
  * Create Role
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: app-role
      namespace: webapps
    rules:
      - apiGroups:
            - ""
            - apps
            - autoscaling
            - batch
            - extensions
            - policy
            - rbac.authorization.k8s.io
        resources:
          - pods
          - componentstatuses
          - configmaps
          - daemonsets
          - deployments
          - events
          - endpoints
          - horizontalpodautoscalers
          - ingress
          - jobs
          - limitranges
          - namespaces
          - nodes
          - secrets
          - pods
          - persistentvolumes
          - persistentvolumeclaims
          - resourcequotas
          - replicasets
          - replicationcontrollers
          - serviceaccounts
          - services
        verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    ```
  * Bind the Role to Service Account
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: app-rolebinding
      namespace: webapps 
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: app-role 
    subjects:
    - namespace: webapps 
      kind: ServiceAccount
      name: jenkins 
    ```
  * Create Cluster Role & Bind to Service Account
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: jenkins-cluster-role
    rules:
    - apiGroups: [""]
      resources: ["persistentvolumes"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

    ---

    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: jenkins-cluster-role-binding
    subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: webapps
    roleRef:
      kind: ClusterRole
      name: jenkins-cluster-role
      apiGroup: rbac.authorization.k8s.io
    ```
  * Generate Token using Service Account in the Namespace
    * [Refer Here](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#:~:text=To%20create%20a%20non%2Dexpiring,with%20that%20generated%20token%20data.) for Official docs.
    * In Example `mysecretname.yaml`, change Service Account Name (Provide Your Service Account Name)
      ```yaml
      apiVersion: v1
      kind: Secret
      type: kubernetes.io/service-account-token
      metadata:
        name: mysecretname
        annotations:
          kubernetes.io/service-account.name: jenkins
      ```
    * Apply with Namespace, it gives Secret.
      ```
      kubectl apply -f <yaml_filename> -n <namespace>
      ```
    * Next describe the Secret, then it gives Token.
      ```
      kubectl describe secret <secret_name> -n <namespace>
      ```
    * Copy and Store in safe place.

## Jenkins
* Connect to Jenkins Instance.
* Install & Configure Jenkins.
* Access Jenkins
  * Install Plugins
    * SonarQube Scanner
    * Config File Provider
    * Maven Integration
    * Pipeline Maven Integration
    * Docker
    * Docker Pipeline
    * Kubernetes
    * Kubernetes CLI
    * Kubernetes Credentials
    * Kubernetes Client API
    * Pipeline: Stage View
  * Configure Tools
    * Configure `SonarQube Scanner`
      * Give Name
      * Install automatically with New Version
    * Configure `Maven`
      * Give Name
      * Install automatically with New Version
    * Configure `Docker`
      * Give Name
      * Install automatically using `Download from docker.com` with New Version
### Jenkins Pipeline
* **Stage-1** `Git_CheckOut`  
  * Provide Git URL and Branch.
    ```
    stage('Git_CheckOut') {
        steps {
            git url: 'https://github.com/SuriBabuKolaDevOpsProjects/Multi-Tier-With-Database.git',
                branch: 'project2'
        }
    }
    ```
* **Stage-2** `Compile`
  * Checks for Compilation issues in the Main Code.
    ```
    stage('Compile') {
        steps {
            sh "mvn compile"
        }
    }
    ```
  * To run Maven related Steps, we need to provide Configured Maven Tool Name.
    ```
    tools {
        maven 'maven' 
    }
    ```
* **Stage-3** `Test`
  * Verifies functionality by running Unit Tests and even if the Test Cases are fail, Success the Build.
    ```
    stage('Test') {
        steps {
            sh "mvn test -DskipTests=true"
        }
    }
    ```
* **Stage-4** `Trivy_FS_Scan`
  * Security scanner for Vulnerability.
    * In Jenkins, there is no proper Plugin for `Trivy`.
    * Install directly in Jenkins Server.
    * [Refer Here](https://aquasecurity.github.io/trivy/v0.18.3/installation/) for Installation Script.
    * After installation check version `trivy --version`.
      ```
      stage('Trivy_FS_Scan') {
          steps {
              sh "trivy fs --format table -o fs-report.html ."
          }
      }
      ```
* **Stage-5** `SonarQube_Analysis`
  * Configure SonarQube
    * Go to `Manage Jenkins --> System`
    * Navigate to `SonarQube servers` and click `Add SonarQube`
    * Give `Name` and `Server URL`
    * Add and select Credentials (Use Secret text & Provide SonarQube Token)
  * SonarQube is a 3rd Party Plugin, for that we add Tool in Environment
    ```
    environment { 
        SonarQube_Home= tool 'sonarqube'
    }
    ```
  * Click on `Pipeline Syntax` and select `withSonarQubeEnv`
    * Select Credentials and click `Generate Pipeline Script`
    * In generated Script remove CredentialsId and use Name provided in Configure SonarQube
    ```
    stage('SonarQube_Analysis') {
        steps {
            withSonarQubeEnv('SonarQube') {
                sh "$SonarQube_Home/bin/sonar-scanner -Dsonar.projectName=BankApp -Dsonar.projectKey=BankApp -Dsonar.java.binaries=target"
            }
        }
    }
    ```
* **Stage-6** `Build`
  * Build the Source Code
    ```
    stage('Build') {
        steps {
            sh "mvn package -DskipTests=true"
        }
    }
    ```
* **Stage-7** `Publis_to_Nexus`
  * Update the Nexus Repositories `Name & URL` in `pom.xml` file `distributionManagement` block.
    * Go to Nexus3, click `Settings --> Repositories`
    * Copy the Name and URL of `maven-releases` and `maven-shapshots`
    * Provide in pom.xml file.
    ```
    <distributionManagement>
	      <repository>
	          <id>maven-releases</id>
	          <url>http://34.236.152.21:8081/repository/maven-releases/</url>
	      </repository>
	      <snapshotRepository>
	          <id>maven-snapshots</id>
	          <url>http://34.236.152.21:8081/repository/maven-snapshots/</url>
	      </snapshotRepository>
	  </distributionManagement> 
    ```
  * Next Add a New Config file
    * Go to `Manage Jenkins --> Managed files`
    * Click `Add a new Config`
    * Select `Global Maven settings.xml` in Type
    * Give ID
    * Give Name
    * In Content,
      * Navigate to `server`
      * Remove `-->` and Paste it above Server block
      * Add Two Server blocks, One for Releases and Second One for Snapshots.
      * Provide Id: `Repo-Name`, username and password.
      * Click Submit.
    ```
        -->
        <server>
          <id>maven-releases</id>
          <username>admin</username>
          <password>Suresh@3697</password>
        </server>
        
        <server>
          <id>maven-snapshots</id>
          <username>admin</username>
          <password>Suresh@3697</password>
        </server>
    ```
  * Click on `Pipeline Syntax` and select `withMaven`
    * Select `Maven` and `Global Maven Settings Config`
    * Click `Generate Pipeline Script` and use in Pipeline Script.
    ```
    stage('Build') {
        steps {
            withMaven(globalMavenSettingsConfig: 'Nexus', jdk: '', maven: 'maven', mavenSettingsConfig: '', traceability: true) {
                sh "mvn deploy -DskipTests=true"
            }
        }
    }
    ```
  * In Nexus, go to `Browse --> maven-snapshots`
    * I that, the Jar file is Stored.
* **Stage-8** `Docker_Image_Build`
  * Install Docker on Jenkins Server and provide Permissions for all Users.
    ```
    sudo chmod 666 /var/run/docker.sock
    ```
  * Add Dockerfile in Git Repo.
    ```
    FROM amazoncorretto:17-alpine-jdk
    ENV App_Home=/usr/src/app
    WORKDIR ${App_Home}
    COPY target/*.jar app.jar
    EXPOSE 8080
    ENTRYPOINT [ "java", "-jar", "app.jar" ]
    ```
  * Click on `Pipeline Syntax` and select `withDockerRegistry`
    * Add and Select DockerHub Credentials
    * Select Docker installation
    * Click `Generate Pipeline Script` and use in Pipeline Script.
    ```
    stage('Docker_Image_Build') {
        steps {
            script {
                withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                    sh "docker image build -t nagasuribabukola/bankapp:${BUILD_NUMBER} -t nagasuribabukola/bankapp:latest ."
                }
            }
        }
    }
    ```
* **Stage-9** `Trivy_Image_Scan`
  * Scans the Docker Image.
    ```
    stage('Trivy_Image_Scan') {
        steps {
            sh "trivy image --format table -o fs-report.html nagasuribabukola/bankapp:${BUILD_NUMBER}"
        }
    }
    ```
* **Stage-10** `Docker_Image_Push`
  * Push the Images to DockerHub
    ```
    stage('Docker_Image_Push') {
        steps {
            script {
                withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                    sh "docker image push nagasuribabukola/bankapp:${BUILD_NUMBER}"
                    sh "docker image push nagasuribabukola/bankapp:latest"
                }
            }
        }
    }
    ```
* **Stage-11** `Deplo_to_K8s`
  * Install `kubectl` on Jenkins Server.
  * Write `deployment.yaml` file for the Application.
    ```yaml
    ---
    # Volume for Storage
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: bankdb-pv
    spec:
      capacity:
        storage: 2Gi
      accessModes:
        - ReadWriteOnce
      hostPath: 
        path: /mountdata/bankdb
    ---
    # Request Storage
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: bankdb-pvc
      namespace: webapps
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi
    ---
    # MySQL Deployment
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: bankdb
    spec:
      selector:
        matchLabels:
          app: bankdb
      strategy:
        type: Recreate
      template:
        metadata:
          labels:
            app: bankdb
        spec:
          containers:
          - image: mysql:8
            name: bankdb
            env:
            - name: MYSQL_ROOT_PASSWORD
              value: "Suresh@1997"
            - name: MYSQL_DATABASE
              value: "bankappdb"
            ports:
            - containerPort: 3306
              name: mysql
            volumeMounts:
            - name: bankdb-storage
              mountPath: /var/lib/mysql
          volumes:
          - name: bankdb-storage
            persistentVolumeClaim:
              claimName: bankdb-pvc
    ---
    # MySQL Service
    apiVersion: v1
    kind: Service
    metadata:
      name: bankdb-service
    spec:
      ports:
      - port: 3306
      selector:
        app: bankdb
    ---
    # Java Application Deployment
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: bankapp
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: bankapp
      template:
        metadata:
          labels:
            app: bankapp
        spec:
          containers:
          - name: bankapp
            image: nagasuribabukola/bankapp:latest
            ports:
            - containerPort: 8080
            env:
            - name: SPRING_DATASOURCE_URL
              value: jdbc:mysql://bankdb-service:3306/bankappdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
            - name: SPRING_DATASOURCE_USERNAME
              value: root
            - name: SPRING_DATASOURCE_PASSWORD
              value: "Suresh@1997"
    ---
    # Bank Application Service
    apiVersion: v1
    kind: Service
    metadata:
      name: bankapp-service
    spec:
      type: LoadBalancer
      ports:
      - port: 80
        targetPort: 8080
      selector:
        app: bankapp
    ```
  * Click on `Pipeline Syntax` and select `withKubeConfig`
    * Add and Select `Credentials` (Select Secret text and provide K8s Token)
    * Give `Kubernetes server endpoint` (Provide Cluster `API server endpoint`)
    * Give `Cluster name` and `Namespace`
    * Click `Generate Pipeline Script` and use in Pipeline Script.
      ```
      stage('Deploy_to_K8s') {
          steps {
              script {
                  withKubeConfig(caCertificate: '', clusterName: 'cluster', contextName: '', credentialsId: 'K8s_Cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://C11C91E1E51C56F3016885380A04999B.gr7.us-east-1.eks.amazonaws.com') {
                      // Run `kubectl apply` only if the deployment does not exist
                      sh "kubectl apply -f deployment.yaml -n webapps || true"
                      // Always run `kubectl set image` to update the image for existing deployment
                      sh "kubectl set image deployment/bankapp bankapp=nagasuribabukola/bankapp:${BUILD_NUMBER} -n webapps"
                      sh "sleep 30"
                  }
              }
          }
      }
      ```
* **Stage-12** `Verify_Deployment`
  * Run the K8s Commands
    ```
    stage('Verify_Deployment') {
        steps {
            script {
                withKubeConfig(caCertificate: '', clusterName: 'cluster', contextName: '', credentialsId: 'K8s_Cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://C11C91E1E51C56F3016885380A04999B.gr7.us-east-1.eks.amazonaws.com') {
                    sh "kubectl get pods -n webapps"
                    sh "kubectl get svc -n webapps"
                }
            }
        }
    }
    ```

## Add SSL Certificate
* Create Certificate in AWS Certificate Manager (ACM)
  * Go to Domain provider and add DNS Record
    * Type: `CNAME`
    * Name: `CNAME name` (Remove Domain Name)
    * Value: `CNAME value` (Remove .)
* Go to Cluster created Load Balancer (Classic Load Balancer)
  * In `Listeners`, click `Manage listeners`
  * Notedown `Instance port` and remove all Listeners.
  * Add Two Listeners
    * `HTTP:80 --> HTTPS:443`
    * `HTTPS:443 --> HTTP:<Give-Previous-Instance-Port>` and select SSL Certificate from ACM.
* Go to Domain provider and add DNS Record
  * Type: `CNAME`
  * Name: `Sub Domain Name`
  * Value: `Load Balancer DNS Name`