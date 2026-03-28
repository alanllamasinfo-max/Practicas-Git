# 🛠️ SQL Schema Pipeline — Jenkins CI/CD

> Pipeline de integración continua para aplicar scripts SQL a entornos PostgreSQL de forma controlada, auditada y con trazabilidad en Git.

![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

---

## 📋 Descripción

Este repositorio contiene la infraestructura de un pipeline de Jenkins que automatiza la aplicación de migraciones SQL a bases de datos PostgreSQL. El pipeline:

- Detecta automáticamente qué scripts SQL **aún no han sido ejecutados** en el entorno objetivo
- Solicita **confirmación manual** antes de aplicar cambios (aprobación humana en el gate)
- Ejecuta los scripts en la base de datos PostgreSQL destino
- Mueve los archivos procesados a la carpeta `Applied/` y actualiza el log de auditoría
- Hace **push automático** de todos los cambios al repositorio Git como registro histórico

---

## 🏗️ Arquitectura del Pipeline

```
GitHub Repo (rama: dev)
        │
        ▼
┌──────────────────────────────────────────────────────┐
│                   JENKINS PIPELINE                   │
│                                                      │
│  Stage 1: Setup & Prepare                            │
│  ┌─────────────────────────────────────────────┐     │
│  │ Lee schemas/<schema>/*.sql                  │     │
│  │ Compara contra pre.log (archivos ya vistos) │     │
│  │ Copia pendientes → TEMP_DIR                 │     │
│  └─────────────────────────────────────────────┘     │
│                        │                             │
│  Stage 2: Confirmación (input manual) ◀── GATE       │
│                        │                             │
│  Stage 3: Execute SQL                                │
│  ┌─────────────────────────────────────────────┐     │
│  │ psql -h DB_HOST → PostgreSQL (Docker)       │     │
│  │ ON_ERROR_STOP=1 (falla en el primer error)  │     │
│  └─────────────────────────────────────────────┘     │
│                        │                             │
│  Stage 4: Update Git Logs                            │
│  ┌─────────────────────────────────────────────┐     │
│  │ Mueve .sql → Applied/                       │     │
│  │ Actualiza pre.log con timestamp             │     │
│  │ git commit + push → dev                     │     │
│  └─────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────┘
        │
        ▼
PostgreSQL (pre / prod)
```

---

## 📁 Estructura del Repositorio

```
.
├── Jenkinsfile                        # Pipeline principal (con psql real)
├── primer-jenkinsfile                 # Versión inicial / simulación local
│
└── schemas/
    ├── pruebas/                       # Esquema "pruebas" de PostgreSQL
    │   ├── pre.log                    # Registro de scripts ya ejecutados
    │   ├── 01_create_table.sql        # Scripts pendientes de ejecutar
    │   └── Applied/
    │       └── 01_create_table.sql    # Scripts ya ejecutados y archivados
    │
    └── public/                        # Esquema "public" de PostgreSQL
        ├── pre.log
        └── Applied/
```

> 💡 **Convención de nombres**: Los scripts SQL deben nombrarse con prefijo numérico (`01_`, `02_`, `03_`...) para garantizar el orden de ejecución.

---

## ⚙️ Configuración Requerida

### 1. Credenciales en Jenkins

Navega a **Manage Jenkins → Credentials** y crea los siguientes secretos:

| ID de Credencial         | Tipo                    | Descripción                              |
|--------------------------|-------------------------|------------------------------------------|
| `postgres-local-creds`   | Username with password  | Usuario y contraseña de PostgreSQL       |
| `github-alexis`          | Username with password  | Usuario de GitHub + Personal Access Token|

### 2. Variables de Entorno del Pipeline

Configuradas directamente en el `Jenkinsfile`:

| Variable   | Valor por defecto | Descripción                              |
|------------|-------------------|------------------------------------------|
| `LOG_FILE` | `pre.log`         | Nombre del archivo de auditoría          |
| `ENV_NAME` | `pre`             | Nombre del entorno objetivo              |
| `DB_HOST`  | `172.17.0.1`      | IP del host Docker (gateway por defecto) |
| `DB_PORT`  | `5432`            | Puerto de PostgreSQL                     |
| `DB_NAME`  | `pre`             | Nombre de la base de datos               |

> ⚠️ Si Jenkins y PostgreSQL no están en el mismo host Docker, reemplaza `172.17.0.1` con la IP real de tu servidor.

### 3. Parámetros del Job (en tiempo de ejecución)

Al lanzar el pipeline manualmente, Jenkins te pedirá:

| Parámetro | Valor por defecto | Descripción                                               |
|-----------|-------------------|-----------------------------------------------------------|
| `schema`  | `pruebas`         | Nombre del esquema de PostgreSQL sobre el que se opera    |

---

## 🚀 Cómo Usar

### Añadir un nuevo script SQL

1. Crea tu archivo SQL dentro de la carpeta del esquema correspondiente:
   ```
   schemas/pruebas/02_add_column.sql
   ```

2. El archivo debe apuntar al esquema correcto internamente:
   ```sql
   ALTER TABLE pruebas.empleados ADD COLUMN email VARCHAR(100);
   ```

3. Haz commit y push a la rama `dev`:
   ```bash
   git add schemas/pruebas/02_add_column.sql
   git commit -m "feat: add email column to empleados"
   git push origin dev
   ```

4. Lanza el job en Jenkins → selecciona el `schema` → aprueba en el gate de confirmación.

### Resultado esperado tras la ejecución

- El script se ejecuta en PostgreSQL
- El archivo se mueve a `schemas/pruebas/Applied/`
- El log se actualiza:
  ```
  schemas/pruebas/02_add_column.sql executed in pre in Mon Mar 28 10:30:00 UTC 2026
  ```
- Jenkins hace push automático de estos cambios a `dev`

---

## 🔍 Lógica Anti-Duplicados

El pipeline usa el archivo `pre.log` como fuente de verdad para evitar ejecutar el mismo script dos veces:

```bash
# Solo copia el archivo si su nombre NO aparece ya en el log
if ! grep -q "$file executed in $ENV_NAME" schemas/$schema/$LOG_FILE; then
    cp "$file" $TEMP_DIR/
fi
```

Si un script ya fue ejecutado, simplemente se ignora en la próxima ejecución.

---

## 🛡️ Manejo de Errores

- El flag `-v ON_ERROR_STOP=1` en `psql` hace que el pipeline falle inmediatamente si cualquier sentencia SQL devuelve un error.
- El contador `ERROR_COUNT` acumula fallos por script y causa que el stage falle si `ERROR_COUNT > 0`.
- En caso de fallo en `Execute SQL`, el stage `Update Git Logs` **no se ejecuta**, por lo que el log permanece limpio y el script puede reintentarse.

---

## 🐳 Conectividad Docker → Docker

Este pipeline está diseñado para ejecutarse desde un contenedor Jenkins que conecta a un contenedor PostgreSQL a través del host:

```
[Jenkins Container] → 172.17.0.1:5432 → [PostgreSQL Container]
```

La IP `172.17.0.1` es el gateway estándar de la red `docker0` en Linux. Para verificar la IP correcta en tu entorno:

```bash
docker network inspect bridge | grep Gateway
```

---

## 📌 Requisitos

- Jenkins con el plugin **Pipeline** instalado
- Cliente `psql` instalado **dentro** del contenedor/agente de Jenkins
- PostgreSQL accesible desde el agente de Jenkins
- Acceso de escritura al repositorio GitHub (Personal Access Token con scope `repo`)

---

## 📝 Licencia

Proyecto de prácticas — uso libre para aprendizaje y referencia.
