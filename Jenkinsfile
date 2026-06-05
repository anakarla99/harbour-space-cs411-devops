pipeline {
    agent any
    tools {
        nodejs 'NodeJS24'    // ← ESTA LÍNEA es la que falta
    }
    environment {
        IMAGE_NAME = "ttl.sh/anakarla99-harbour:2h"
    }
    
    stages {
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }
        stage('Unit Test') {
            steps {
                sh 'node --test'
            }
        }
        stage('Build and Push Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
                sh "docker push ${IMAGE_NAME}"
            }
        }
        stage('Deploy to Target') {
            steps {
                sh 'ansible-playbook -i hosts.ini playbook.yml'
            }
        }
        stage('Deploy to Docker') {
            steps {
                sh "ssh -o StrictHostKeyChecking=no laborant@docker 'docker pull ${IMAGE_NAME} && docker rm -f myapp || true && docker run -d --name myapp -p 4444:4444 ${IMAGE_NAME}'"
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([string(credentialsId: 'kubernetes-token', variable: 'TOKEN')]) {
                    sh 'kubectl --server=https://kubernetes:6443 --insecure-skip-tls-verify=true --token=$TOKEN apply -f pod.yaml -f svc.yaml'
                }
            }
        }
    }
}
