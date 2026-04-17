pipeline {
    agent none

    environment {
        GITHUB_TOKEN = credentials('github-token') // Tu credencial "Username with password" o "Secret text"
        REPO_OWNER = 'Penguin424'             // <-- CAMBIA ESTO
        REPO_NAME = 'eupeel_expo'
        APP_VERSION = "1.0.${env.BUILD_NUMBER}"
    }

    stages {
        stage('Test') {
            agent { label 'windows' }
            tools {
                git 'windows-git'
            }
            steps {
                bat 'flutter pub get'
                bat 'flutter test --reporter compact'
            }
        }
        stage('Crear Release en GitHub') {
            agent { label 'built-in' }
            steps {
                script {
                    // 1. Creamos el archivo JSON de forma segura
                    def jsonPayload = """
                    {
                      "tag_name": "v${APP_VERSION}",
                      "name": "Release v${APP_VERSION}",
                      "body": "Build automático multi-plataforma"
                    }
                    """
                    writeFile file: 'release_data.json', text: jsonPayload

                    // 2. Ejecutamos curl usando comillas simples (''') para seguridad
                    // Usamos @release_data.json para que lea el archivo en lugar de pelear con las comillas
                    def response = sh(script: '''
                        curl -s -X POST \
                        -H "Authorization: token $GITHUB_TOKEN_PSW" \
                        -H "Accept: application/vnd.github.v3+json" \
                        https://api.github.com/repos/'''+REPO_OWNER+'''/'''+REPO_NAME+'''/releases \
                        -d @release_data.json
                    ''', returnStdout: true)
                    
                    // 3. Imprimimos la respuesta para depurar y extraemos el ID
                    echo "Respuesta de GitHub: ${response}"
                    env.RELEASE_ID = sh(script: "echo '${response}' | grep -oE '\"id\": [0-9]+' | head -1 | cut -d':' -f2 | xargs", returnStdout: true).trim()
                }
            }
        }
        stage('Builds Multi-plataforma') {
            parallel {
                stage('Build windows') {
                    agent { label 'windows' }
                    
                    // AÑADE ESTAS TRES LÍNEAS AQUÍ:
                    tools {
                        git 'windows-git'
                    }

                    steps {
                        bat 'flutter clean'
                        bat 'flutter pub get'
                        bat 'flutter build windows --release'

                        // Creación del instalador .msix con versión automática
                        bat "dart run msix:create --version ${APP_VERSION}.0"

                        // comprimir el ejecutable de Windows
                        bat 'powershell Compress-Archive -path build\\windows\\x64\\runner\\Release\\* -DestinationPath build_windows.zip -Force'

                        // Subida del instalador .msix a GitHub Assets
                        bat """
                        curl -X POST ^
                        --ssl-no-revoke ^
                        -H "Authorization: token ${GITHUB_TOKEN_PSW}" ^
                        -H "Content-Type: application/octet-stream" ^
                        --data-binary "@build\\windows\\x64\\runner\\Release\\eupeel_laboratorio.msix" ^
                        "https://uploads.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/${RELEASE_ID}/assets?name=Instalador_Windows_v${APP_VERSION}.msix"
                        """

                    }
                }
            }
        }
    }

    post {
        success {
            echo "¡Felicidades! La versión v${APP_VERSION} ya está disponible en GitHub con instaladores para Windows y macOS."
        }
        failure {
            echo "Hubo un error en el pipeline. Revisa los logs de las etapas individuales."
        }
    }
}