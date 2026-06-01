pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    environment {
        IMAGE = "ttl.sh/anakarla99-harbour:2h"
    }

    stages {
        stage('Build') {
            steps {
                dir('app') {
                    sh "CGO_ENABLED=0 go build -o main main.go"
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE} ."
            }
        }

        stage('Docker Push') {
            steps {
                sh "docker push ${IMAGE}"
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([string(credentialsId: 'k8s-token', variable: 'K8S_TOKEN')]) {
                    sh """
                        kubectl apply -f pod.yaml \
                        --validate=false \
                        --server=https://kubernetes:6443 \
                        --token=\$K8S_TOKEN \
                        --insecure-skip-tls-verify=true
                    """
                }
            }
        }
        stage('Verify') {
            steps {
                withCredentials([string(credentialsId: 'k8s-token', variable: 'K8S_TOKEN')]) {
                    sh """
                        kubectl config use-context lab-ctx
                        kubectl wait --for=condition=Ready pod/myapp --timeout=90s
                        kubectl get pod myapp -o wide
                    """
                }
            }
        }
    }
}
