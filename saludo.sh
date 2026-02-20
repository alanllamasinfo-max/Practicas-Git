
pipeline {
    // 'any' le dice a Jenkins que corra directamente en la máquina donde está instalado
    agent any 
    
    parameters {
        string(name: 'schema', defaultValue: 'pruebas', description: 'Specify the schema to use')
    }
    
    options {
        buildDiscarder logRotator(numToKeepStr: '5')
        disableConcurrentBuilds()
    }

    environment {
        LOG_FILE = 'dev.log'
        ENV_NAME = 'dev'
        // Usamos una carpeta dentro de tu proyecto local en lugar del /tmp del sistema
        TEMP_DIR = "${WORKSPACE}/tmp_files_to_upload" 
    }

    stages {
        stage("Setup & Prepare Files Locally") {
            steps {
                sh '''#!/bin/bash
                    # 1. Limpiamos o creamos la carpeta temporal local
                    mkdir -p $TEMP_DIR && rm -rf $TEMP_DIR/*
                    
                    # 2. Aseguramos que la carpeta del esquema y el log existan para que no dé error la primera vez
                    mkdir -p schemas/$schema
                    touch schemas/$schema/$LOG_FILE
                    
                    # 3. Buscamos archivos nuevos que no estén en el log de dev
                    for file in schemas/$schema/*.sql; do
                        # Evita errores si no hay archivos .sql en la carpeta
                        [ -e "$file" ] || continue 
                        
                        if ! grep -q "$file executed in $ENV_NAME" schemas/$schema/$LOG_FILE; then
                            cp "$file" $TEMP_DIR/
                        fi
                    done
                    
                    echo "Archivos pendientes de ejecutar localmente:"
                    ls -l $TEMP_DIR
                '''
            }
        }

        stage('Ask confirmation') {
            steps {
                input message: 'Apply changes locally?', id: 'Confirm'
            }
        }

        stage("Execute Local Tests") {
            steps {
                sh '''#!/bin/bash
                    # Aquí es donde simulas o ejecutas el script en tu base de datos local
                    echo "Iniciando ejecución de scripts locales..."
                    
                    for file in $TEMP_DIR/*.sql; do
                        [ -e "$file" ] || continue
                        
                        echo "Ejecutando $file..."
                        # AQUI IRÍA TU COMANDO REAL. Por ejemplo:
                        # mysql -u mi_usuario -p'mi_password' mi_bd_local < "$file"
                        
                        sleep 1 # Simulamos que toma un segundo en ejecutarse
                    done
                    
                    # Simulamos la validación de código exitosa de tu script original
                    echo "ok" > result_code.txt
                    
                    if [ "$(cat result_code.txt | tr -d '[:space:]')" != "ok" ]; then
                        echo "EXITING due to errors in local sql operations"
                        exit 1
                    fi
                '''
            }
        }

        stage('Update Git Logs') {
            steps {
                // Mantenemos tus credenciales para poder hacer el push a GitHub
                withCredentials([usernamePassword(credentialsId: 'github-equifax-prod', usernameVariable: 'GITHUB_APP', passwordVariable: 'GITHUB_ACCESS_TOKEN')]) {
                    sh '''#!/bin/bash
                        git config user.email "JenkinsLocal@tusistema.com"
                        git config user.name "Jenkins Local"
                        
                        # Actualizamos el log localmente solo para los archivos que procesamos
                        for file in $TEMP_DIR/*.sql; do
                            [ -f "$file" ] || continue
                            # Recuperamos la ruta original para que quede bien en el log
                            original_file="schemas/$schema/$(basename "$file")"
                            
                            echo "" >> schemas/$schema/$LOG_FILE
                            echo "$original_file executed in $ENV_NAME in $(date)" >> schemas/$schema/$LOG_FILE
                        done

                        # Limpiamos nuestra basura local
                        rm -rf $TEMP_DIR result_code.txt

                        # Añadimos y comiteamos
                        git add -A
                        git commit -m "Local Test: Files for schema $schema executed in $ENV_NAME" || echo "No changes to commit"
                        
                        # Hacemos push explícitamente apuntando a la rama 'dev' de tu repositorio remoto
                        git push https://$GITHUB_APP:$GITHUB_ACCESS_TOKEN@github.com/Equifax/7362_ES_GCP_DB_SCHEMAS_IIT.git HEAD:dev
                    '''
                }
            }
        }
    }
}
