# Multi-Tier with Database
## Launch Instances
* First create Security Group with Ports `22, 25, 80, 443, 465, 6443 & 2000-11000`.
* Then Launch Instances
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
                branch: 'project1'
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
        maven 'maven3' 
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
* **Stage-7** `Publis_Artifacts_to_Nexus`
  * Update the Nexus Repositories `Name & URL` in `pom.xml` file `distributionManagement` block.
    * Go to Nexus3, click `Settings --> Repositories`
    * Copy the Name and URL of `maven-releases` and `maven-shapshots`
    * Provide in pom.xml file.
    ```
    <distributionManagement>
	      <repository>
	          <id>maven-releases</id>
	          <url>http://3.94.102.128:8081/repository/maven-releases/</url>
	      </repository>
	      <snapshotRepository>
	          <id>maven-snapshots</id>
	          <url>http://3.94.102.128:8081/repository/maven-snapshots/</url>
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
    stage('Publish_Artifacts_to_Nexus') {
        steps {
            withMaven(globalMavenSettingsConfig: 'Nexus_Artifact_Store', jdk: '', maven: 'maven3', mavenSettingsConfig: '', traceability: true) {
                sh "mvn deploy -DskipTests=true"
            }
        }
    }
    ```
  * In Nexus, go to `Browse --> maven-snapshots`
    * I that, the Jar file is Stored.
* **Stage-8** `Build_Docker_Image`
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
    stage('Build_Docker_Image') {
        steps {
            script  {
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
* **Stage-10** `Push_Docker_Image`
  * Push the Images to DockerHub
    ```
    stage('Push_Docker_Image') {
        steps {
            script  {
                withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                    sh "docker image push nagasuribabukola/bankapp:${BUILD_NUMBER}"
                    sh "docker image push nagasuribabukola/bankapp:latest"
                }
            }
        }
    }
    ```
* **Stage-11** `Deploy`
  * Write the `docker-compose` file.
    ```yaml
    ---
    version: '3.8'

    services:
      bankdb:
        image: mysql:8
        container_name: bankdb
        environment:
          - MYSQL_ROOT_PASSWORD=Suresh@1997
          - MYSQL_DATABASE=bankappdb
        ports:
          - "3306:3306"
        volumes:
          - bankdb-data:/var/lib/mysql
        networks:
          - bankapp-network

      bankapp:
        image: nagasuribabukola/bankapp:latest
        container_name: bankapp
        environment:
          - SPRING_DATASOURCE_URL=jdbc:mysql://bankdb:3306/bankappdb?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
          - SPRING_DATASOURCE_USERNAME=root
          - SPRING_DATASOURCE_PASSWORD=Suresh@1997
        ports:
          - "80:8080"
        networks:
          - bankapp-network
        depends_on:
          - bankdb

    networks:
      bankapp-network:
        driver: bridge

    volumes:
      bankdb-data:
    ```
  * Install Docker Compose on Jenkins Server.
  * Add Deploy Script in Pipeline
    ```
    stage('Deploy') {
        steps {
            script {
                // Stop existing containers to ensure a fresh start
                sh "docker-compose down"
                // Start containers in detached mode
                sh "docker-compose up -d"
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
* Create a Load Balancer
  * Create Target Group with Server Instance
  * Remove all Listeners and add Two Listeners
    1. `HTTP:80 --> Redirect to URL --> HTTPS:443`
    2. `HTTPS:443 --> Forward to target groups --> Select Target Group --> Select ACM Certificate`
* Go to Domain provider and add DNS Record
  * Type: `CNAME`
  * Name: `Sub Domain Name`
  * Value: `Load Balancer DNS Name`