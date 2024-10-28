pipeline {
    agent any
    tools {
        maven 'maven3' 
    }
    environment { 
        SonarQube_Home= tool 'sonarqube'
    }

    stages {
        stage('Git_CheckOut') {
            // Checkou Source Code
            steps {
                git url: 'https://github.com/SuriBabuKolaDevOpsProjects/Multi-Tier-With-Database.git',
                    branch: 'project1'
            }
        }
        
        stage('Compile') {
            // Checks for Compilation issues
            steps {
                sh "mvn compile"
            }
        }
        
        stage('Test') {
            // Verifies functionality by running Unit Tests
            steps {
                sh "mvn test -DskipTests=true"
            }
        }
        
        stage('Trivy_FS_Scan') {
            // Scans local filesystems for Vulnerabilities
            steps {
                sh "trivy fs --format table -o fs-report.html ."
            }
        }
        
        stage('SonarQube_Analysis') {
            // Inspect Code Quality and Security
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "$SonarQube_Home/bin/sonar-scanner -Dsonar.projectName=BankApp -Dsonar.projectKey=BanckApp -Dsonar.java.binaries=target"
                }
            }
        }
        
        stage('Build') {
            // Build the Artifact
            steps {
                sh "mvn package -DskipTests=true"
            }
        }
        
        stage('Publish_Artifact_to_Nexus') {
            // Store Artifacts and Dependencies
            steps {
                withMaven(globalMavenSettingsConfig: 'Nexus_Artifact_Store', jdk: '', maven: 'maven3', mavenSettingsConfig: '', traceability: true) {
                    sh "mvn deploy -DskipTests=true"
                }
            }
        }
        
        stage('Build_Docker_Image') {
            // Build the Docker Image
            steps {
                script {
                    withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                        sh "docker image build -t nagasuribabukola/bankapp:${BUILD_NUMBER} -t nagasuribabukola/bankapp:latest ."
                    }
                }
            }
        }
        
        stage('Trivy_Image_Scan') {
            // Scans Docker Image
            steps {
                sh "trivy image --format table -o fs-report.html nagasuribabukola/bankapp:${BUILD_NUMBER}"
            }
        }
        
        stage('Push_Docker_Image') {
            // Push the Image to DockerHub
            steps {
                script {
                    withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                        sh "docker image push nagasuribabukola/bankapp:${BUILD_NUMBER}"
                        sh "docker image push nagasuribabukola/bankapp:latest"
                    }
                }
            }
        }
        
        stage('Deploy') {
            // Deploy Docker Container
            steps {
                script {
                    // Stop existing containers to ensure a fresh start
                    sh "docker-compose down"
                    // Start containers in detached mode
                    sh "docker-compose up -d"
                }
            }
        }
    }
}