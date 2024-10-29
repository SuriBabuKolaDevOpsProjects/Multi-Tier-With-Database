pipeline {
    agent any
    tools {
        maven 'maven' 
    }
    environment { 
        SonarQube_Home= tool 'sonarqube'
    }

    stages {
        stage('Git_CheckOut') {
            steps {
                git url: 'https://github.com/SuriBabuKolaDevOpsProjects/Multi-Tier-With-Database.git',
                    branch: 'project2'
            }
        }
        
        stage('Compile') {
            steps {
                sh "mvn compile"
            }
        }
        
        stage('Test') {
            steps {
                sh "mvn test -DskipTests=true"
            }
        }
        
        stage('Trivy_FS_Scan') {
            steps {
                sh "trivy fs --format table -o fs-report.html ."
            }
        }
        
        stage('SonarQube_Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "$SonarQube_Home/bin/sonar-scanner -Dsonar.projectName=BankApp -Dsonar.projectKey=BankApp -Dsonar.java.binaries=target"
                }
            }
        }
        
        stage('Build') {
            steps {
                sh "mvn package -DskipTests=true"
            }
        }
        
        stage('Publish_to_Nexus') {
            steps {
                withMaven(globalMavenSettingsConfig: 'Nexus', jdk: '', maven: 'maven', mavenSettingsConfig: '', traceability: true) {
                    sh "mvn deploy -DskipTests=true"
                }
            }
        }
        
        stage('Docker_Image_Build') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'Docker_Cred', toolName: 'docker') {
                        sh "docker image build -t nagasuribabukola/bankapp:${BUILD_NUMBER} -t nagasuribabukola/bankapp:latest ."
                    }
                }
            }
        }
        
        stage('Trivy_Image_Scan') {
            steps {
                sh "trivy image --format table -o fs-report.html nagasuribabukola/bankapp:${BUILD_NUMBER}"
            }
        }
        
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
    }
}