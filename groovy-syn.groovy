node {
    stage('Sélection du Job') {
        // Liste des jobs disponibles
        def availableJobs = [
            'job_1',
            'job_2', 
            'job_3'
        ]
        
        // Première étape : choisir le job
        def selectedJob = input(
            id: 'JobSelection',
            message: 'Choisissez le job à exécuter',
            parameters: [
                choice(
                    name: 'JOB',
                    choices: availableJobs.join('\n'),
                    description: 'Sélectionnez un job dans la liste'
                )
            ]
        )
        
        echo "Job sélectionné : ${selectedJob}"
        
        // Définir les paramètres spécifiques en fonction du job choisi
        def serverChoices = []
        def branchChoices = ['develop', 'master', 'feature/*']
        
        // Configuration spécifique par job
        switch(selectedJob) {
            case 'job_1':
                serverChoices = ['serveur1_job1', 'serveur2_job1', 'serveur3_job1']
                break
            case 'job_2':
                serverChoices = ['serveurA_job2', 'serveurB_job2']
                branchChoices = ['main', 'release', 'hotfix'] // Exemple de branches différentes pour job2
                break
            case 'job_3':
                serverChoices = ['serveurX', 'serveurY', 'serveurZ']
                break
            default:
                error "Job non reconnu : ${selectedJob}"
        }
        
        // Deuxième étape : paramètres spécifiques au job
        def jobParams = input(
            id: 'JobParameters',
            message: "Paramètres pour ${selectedJob}",
            parameters: [
                choice(
                    name: 'SERVER',
                    choices: serverChoices.join('\n'),
                    description: 'Choisissez le serveur cible'
                ),
                choice(
                    name: 'BRANCH',
                    choices: branchChoices.join('\n'),
                    description: 'Choisissez la branche Git'
                ),
                string(
                    name: 'COMMENT',
                    defaultValue: '',
                    description: 'Commentaire optionnel'
                )
            ]
        )
        
        echo """
        Configuration finale :
        - Job: ${selectedJob}
        - Serveur: ${jobParams.SERVER}
        - Branche: ${jobParams.BRANCH}
        - Commentaire: ${jobParams.COMMENT}
        """
        
        // Exécution du job avec les paramètres
        stage('Exécution') {
            echo "Début de l'exécution du job ${selectedJob}"
            
            // Ici vous pouvez utiliser les paramètres comme :
            // - jobParams.SERVER
            // - jobParams.BRANCH
            // - jobParams.COMMENT
            
            // Exemple conditionnel :
            if (selectedJob == 'job_2') {
                echo "Traitement spécifique pour job_2 sur le serveur ${jobParams.SERVER}"
            }
            
            // Votre logique métier ici...
        }
    }
}
