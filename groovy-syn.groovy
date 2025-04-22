properties([
    parameters([
        choice(
            name: 'SELECTED_JOB',
            choices: ['job_1', 'job_2', 'job_3'],
            description: 'Sélectionnez le job à exécuter'
        )
    ])
])

node {
    stage('Paramétrage complet') {
        // Tous les paramètres en un seul input
        def allParams = input(
            id: 'AllParameters',
            message: 'Paramètres complets pour le job',
            parameters: [
                text(
                    name: 'DESCRIPTION',
                    defaultValue: '',
                    description: 'Description du build'
                ),
                choice(
                    name: 'COMPONENT',
                    choices: ['webapp', 'sql'],
                    description: 'Type de composant'
                ),
                choice(
                    name: 'PACKAGE_TYPE',
                    choices: ['snapshot', 'release'],
                    description: 'Type de package'
                ),
                string(
                    name: 'VERSION',
                    defaultValue: '1.0.0',
                    description: 'Numéro de version (requis même pour snapshot)'
                ),
                booleanParam(
                    name: 'DEPLOY',
                    defaultValue: false,
                    description: 'Déployer le package ?'
                ),
                extendedChoice(
                    name: 'ENVIRONMENTS',
                    type: 'CHECK_BOX', 
                    description: 'Environnements cibles',
                    multiSelectDelimiter: ',',
                    value: 'dev,int,prod',
                    visibleItemCount: 3,
                    quoteValue: false
                )
            ]
        )
        
        // Conversion des environnements en liste
        def envList = allParams.ENVIRONMENTS.split(',') as List
        
        // Affichage récapitulatif
        echo """
        ========== RÉCAPITULATIF ==========
        Job sélectionné: ${params.SELECTED_JOB}
        Description: ${allParams.DESCRIPTION}
        Composant: ${allParams.COMPONENT}
        Type de package: ${allParams.PACKAGE_TYPE}
        Version: ${allParams.VERSION}
        Déploiement: ${allParams.DEPLOY ? 'Oui' : 'Non'}
        Environnements: ${envList.join(', ')}
        ==================================
        """
        
        // Stockage dans les variables d'environnement
        env.DESCRIPTION = allParams.DESCRIPTION
        env.COMPONENT = allParams.COMPONENT
        env.PACKAGE_TYPE = allParams.PACKAGE_TYPE
        env.VERSION = allParams.VERSION
        env.DEPLOY = allParams.DEPLOY.toString()
        env.ENVIRONMENTS = allParams.ENVIRONMENTS
    }
    
    stage('Exécution') {
        echo "Construction du composant ${env.COMPONENT}"
        echo "Type de package: ${env.PACKAGE_TYPE}"
        echo "Version: ${env.VERSION}"
        
        if (env.DEPLOY.toBoolean()) {
            env.ENVIRONMENTS.split(',').each { envName ->
                echo "Déploiement sur ${envName}"
                // Ajoutez ici la logique de déploiement
            }
        }
    }
}
