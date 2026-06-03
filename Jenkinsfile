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
                sshagent(['ec2-key']) {
                    sh 'scp -o StrictHostKeyChecking=no app/myapp.service ubuntu@<16.171.132.48>:/tmp/myapp.service'
                    sh 'scp -o StrictHostKeyChecking=no app/main ubuntu@<16.171.132.48>:/tmp/main'
                    sh '''ssh -o StrictHostKeyChecking=no ubuntu@<16.171.132.48> "
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
