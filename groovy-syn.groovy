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
    stage('Initialisation') {
        echo "Job sélectionné via paramètre : ${params.SELECTED_JOB}"
        
        // Vérification que c'est bien job_2 (comme dans votre exemple)
        if (params.SELECTED_JOB != 'job_2') {
            error "Ce pipeline est configuré uniquement pour job_2"
        }
    }
    
    stage('Paramétrage') {
        // Premier input - Description et composant
        def firstInput = input(
            id: 'BuildParams',
            message: 'Paramètres de construction pour job_2',
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
                )
            ]
        )
        
        // Initialisation des variables
        def versionInput = ''
        def deployInput = false
        def envInput = ''
        
        // Deuxième input conditionnel - Version si release
        if (firstInput.PACKAGE_TYPE == 'release') {
            versionInput = input(
                id: 'VersionInput',
                message: 'Paramètre de version (release seulement)',
                parameters: [
                    string(
                        name: 'VERSION',
                        defaultValue: '1.0.0',
                        description: 'Numéro de version (format X.Y.Z)'
                    )
                ]
            ).VERSION
        }
        
        // Troisième input - Déploiement
        deployInput = input(
            id: 'DeployQuestion',
            message: 'Paramètres de déploiement',
            parameters: [
                booleanParam(
                    name: 'DEPLOY',
                    defaultValue: false,
                    description: 'Déployer le package ?'
                )
            ]
        ).DEPLOY
        
        // Quatrième input conditionnel - Environnement si déploiement
        if (deployInput) {
            envInput = input(
                id: 'EnvSelection',
                message: 'Sélection environnement de déploiement',
                parameters: [
                    choice(
                        name: 'ENVIRONMENT',
                        choices: ['dev', 'int', 'prod'],
                        description: 'Environnement cible'
                    )
                ]
            ).ENVIRONMENT
        }
        
        // Affichage récapitulatif
        echo """
        ========== RÉCAPITULATIF ==========
        Job sélectionné: ${params.SELECTED_JOB}
        Description: ${firstInput.DESCRIPTION}
        Composant: ${firstInput.COMPONENT}
        Type de package: ${firstInput.PACKAGE_TYPE}
        ${firstInput.PACKAGE_TYPE == 'release' ? "Version: ${versionInput}" : ""}
        Déploiement: ${deployInput ? "Oui (${envInput})" : "Non"}
        ==================================
        """
        
        // Stockage des valeurs pour les étapes suivantes
        env.DESCRIPTION = firstInput.DESCRIPTION
        env.COMPONENT = firstInput.COMPONENT
        env.PACKAGE_TYPE = firstInput.PACKAGE_TYPE
        if (firstInput.PACKAGE_TYPE == 'release') {
            env.VERSION = versionInput
        }
        if (deployInput) {
            env.DEPLOY_ENV = envInput
        }
    }
    
    stage('Exécution') {
        // Exemple d'utilisation des paramètres
        echo "Construction du composant ${env.COMPONENT} en mode ${env.PACKAGE_TYPE}"
        
        if (env.PACKAGE_TYPE == 'release') {
            echo "Génération de la version ${env.VERSION}"
        }
        
        if (params.DEPLOY == 'true') {
            echo "Déploiement sur l'environnement ${env.DEPLOY_ENV}"
            // Ajouter ici la logique de déploiement
        }
    }
}
