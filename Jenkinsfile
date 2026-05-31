pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    stages {
        stage('Build') {
            steps {
                dir('app') {
                    sh "CGO_ENABLED=0 go build -o main ."
                }
            }
        }
    }
}
