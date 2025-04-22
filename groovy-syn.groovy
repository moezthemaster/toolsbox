pipeline {
    agent any

    parameters {
        choice(
            name: 'JOB_TYPE',
            choices: ['job_1', 'job_2', 'job_3'],
            description: 'Sélectionnez le type de job'
        )
    }

    stages {
        stage('Paramétrage') {
            steps {
                script {
                    // Capture de tous les paramètres
                    def userInput = input(
                        id: 'fullConfig',
                        message: 'Configuration complète du build',
                        parameters: [
                            text(
                                name: 'DESCRIPTION',
                                defaultValue: '',
                                description: 'Description du build'
                            ),
                            choice(
                                name: 'COMPONENT',
                                choices: ['webapp', 'sql'],
                                description: 'Composant à construire'
                            ),
                            choice(
                                name: 'PACKAGE_TYPE',
                                choices: ['snapshot', 'release'],
                                description: 'Type de package'
                            ),
                            string(
                                name: 'VERSION',
                                defaultValue: '1.0.0',
                                description: 'Version (ex: 1.0.0)'
                            ),
                            booleanParam(
                                name: 'DEPLOY',
                                defaultValue: false,
                                description: 'Déployer le build ?'
                            ),
                            extendedChoice(
                                type: 'CHECK_BOX',
                                name: 'ENVIRONMENTS',
                                description: 'Environnements cibles',
                                multiSelectDelimiter: ',',
                                value: 'dev,int,prod',
                                visibleItemCount: 5,
                                quoteValue: false
                            )
                        ]
                    )

                    // Stockage dans des variables d'environnement
                    env.BUILD_DESC    = userInput.DESCRIPTION
                    env.COMPONENT    = userInput.COMPONENT
                    env.PACKAGE_TYPE = userInput.PACKAGE_TYPE
                    env.VERSION      = userInput.VERSION
                    env.DEPLOY_FLAG  = userInput.DEPLOY.toString()
                    env.TARGET_ENVS  = userInput.ENVIRONMENTS.replaceAll(' ', '')

                    echo """
                    [CONFIGURATION VALIDÉE]
                    Job: ${params.JOB_TYPE}
                    Description: ${env.BUILD_DESC}
                    Composant: ${env.COMPONENT}
                    Package: ${env.PACKAGE_TYPE}
                    Version: ${env.VERSION}
                    Déploiement: ${env.DEPLOY_FLAG}
                    Environnements: ${env.TARGET_ENVS}
                    """
                }
            }
        }

        stage('Exécution') {
            steps {
                script {
                    if (env.DEPLOY_FLAG.toBoolean()) {
                        def envList = env.TARGET_ENVS.split(',')
                        envList.each { envName ->
                            echo "🚀 Déploiement sur [${envName.toUpperCase()}]"
                            // Ajoutez ici vos étapes spécifiques
                        }
                    } else {
                        echo "Déploiement désactivé (skip)"
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Nettoyage des ressources..."
            // Actions post-build
        }
        success {
            echo "Build réalisé avec succès !"
        }
        failure {
            echo "Échec du build !"
        }
    }
}
