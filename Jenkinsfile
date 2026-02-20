pipeline {
    agent any 
    
    parameters {
        string(name: 'schema', defaultValue: 'pruebas', description: 'Specify the schema to use')
    }
    
    options {
        buildDiscarder logRotator(numToKeepStr: '5')
        disableConcurrentBuilds()
    }

    environment {
        LOG_FILE = 'pre.log'
        ENV_NAME = 'pre'
        TEMP_DIR = "${WORKSPACE}/tmp_files_to_upload" 
        
        // --- CONEXIÓN DOCKER A DOCKER (A través del host) ---
        // 172.17.0.1 es la IP estándar del host de Docker en Linux
        // Si no funciona, pon la IP real de tu red local (ej: 192.168.1.X) de 'alexis@server'
        DB_HOST = '172.17.0.1' 
        DB_PORT = '5432'
        DB_NAME = 'pre'
    }

    stages {
        stage("Setup & Prepare Files Locally") {
            steps {
                sh '''#!/bin/bash
                    mkdir -p $TEMP_DIR && rm -rf $TEMP_DIR/*
                    mkdir -p schemas/$schema
                    touch schemas/$schema/$LOG_FILE
                    
                    for file in schemas/$schema/*.sql; do
                        [ -e "$file" ] || continue 
                        
                        if ! grep -q "$file executed in $ENV_NAME" schemas/$schema/$LOG_FILE; then
                            cp "$file" $TEMP_DIR/
                        fi
                    done
                    
                    echo "Archivos pendientes de ejecutar:"
                    ls -l $TEMP_DIR
                '''
            }
        }

        stage('Ask confirmation') {
            steps {
                input message: 'Apply changes to pre?', id: 'Confirm'
            }
        }

        stage("Execute Local Tests") {
            steps {
                withCredentials([usernamePassword(credentialsId: 'postgres-local-creds', usernameVariable: 'DB_USER', passwordVariable: 'DB_PASSWORD')]) {
                    sh '''#!/bin/bash
                        echo "Iniciando ejecución de scripts en PostgreSQL (pre)..."
                        
                        # Comprobamos si psql está instalado en el contenedor de Jenkins
                        if ! command -v psql &> /dev/null; then
                            echo "ERROR: El cliente 'psql' no está instalado en el contenedor de Jenkins."
                            exit 1
                        fi
                        
                        ERROR_COUNT=0
                        
                        for file in $TEMP_DIR/*.sql; do
                            [ -e "$file" ] || continue
                            
                            echo "Ejecutando $file..."
                            
                            export PGPASSWORD=$DB_PASSWORD
                            
                            # Ejecución remota hacia el otro contenedor
                            psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 -f "$file"
                            
                            EXIT_CODE=$?
                            
                            if [ $EXIT_CODE -ne 0 ]; then
                                echo "ERROR ejecutando $file"
                                ERROR_COUNT=$((ERROR_COUNT + 1))
                            else
                                echo "ÉXITO ejecutando $file"
                            fi
                        done
                        
                        if [ $ERROR_COUNT -gt 0 ]; then
                            echo "EXITING: Fallaron $ERROR_COUNT scripts SQL."
                            exit 1
                        else
                             echo "ok" > result_code.txt
                        fi
                    '''
                }
            }
        }

        stage('Update Git Logs') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-alexis', usernameVariable: 'GITHUB_APP', passwordVariable: 'GITHUB_ACCESS_TOKEN')]) {
                    sh '''#!/bin/bash
                        git config user.email "alexis@ejemplo.com"
                        git config user.name "alexis Llamas"
                        
                        for file in $TEMP_DIR/*.sql; do
                            [ -f "$file" ] || continue
                            original_file="schemas/$schema/$(basename "$file")"
                            echo "" >> schemas/$schema/$LOG_FILE
                            echo "$original_file executed in $ENV_NAME in $(date)" >> schemas/$schema/$LOG_FILE
                        done

                        rm -rf $TEMP_DIR result_code.txt

                        git add -A
                        git commit -m "Local Test: Files for schema $schema executed in $ENV_NAME" || echo "No changes to commit"
                        git push https://$GITHUB_APP:$GITHUB_ACCESS_TOKEN@github.com/alanllamasinfo-max/Practicas-Git.git HEAD:dev
                    '''
                }
            }
        }
    }
}
