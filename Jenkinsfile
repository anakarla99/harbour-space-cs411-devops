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

        stage('Deploy') {
            agent any
            steps {
                sh """
                    ssh -o StrictHostKeyChecking=no laborant@docker \
                    'docker pull ${IMAGE} && \
                     docker rm -f myapp || true ; \
                     docker run -d --name myapp -p 4444:4444 ${IMAGE}'
                """
            }
        }
    }
}
