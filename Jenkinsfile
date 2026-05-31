pipeline {
    agent any

    tools {
       go "1.24.1"
    }

    stages {
        stage('Build') {
            steps {
                dir('app') {
                    sh "CGO_ENABLED=0 go build -o main main.go"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sshagent(['target-ssh-key']) {
                    sh 'scp -o StrictHostKeyChecking=no app/myapp.service laborant@target:/tmp/myapp.service'
                    sh 'scp -o StrictHostKeyChecking=no app/main laborant@target:/tmp/main'
                    sh '''ssh -o StrictHostKeyChecking=no laborant@target "
                        sudo cp /tmp/main /usr/local/bin/myapp
                        sudo chmod +x /usr/local/bin/myapp
                        sudo cp /tmp/myapp.service /etc/systemd/system/myapp.service
                        sudo systemctl stop myapp || true
                        sudo systemctl daemon-reload
                        sudo systemctl enable myapp
                        sudo systemctl start myapp
                    "'''
                }
            }
        }
    }
}
