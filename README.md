# Deployment Steps: Paperless-ngx on Unraid (Hybrid Setup)

Follow these steps to deploy the stack on Unraid and bridge it to the pre-existing PostgreSQL database.

## Step 1: Copy Configuration Files
Copy `docker-compose.yml` and your configured `.env` file into your Unraid appdata directory:
```bash
/mnt/user/appdata/paperless-ngx/

Step 2: Start the Container Stack
Navigate to your appdata directory and spin up the Docker containers in detached mode:

cd /mnt/user/appdata/paperless-ngx/
docker compose up -d

Step 3: Connect PostgreSQL to the Paperless Network (Multi-Home)
Since the existing postgresql17 container runs outside this compose file, link it to the newly created paperless-net virtual network:

docker network connect paperless-net postgresql17

Verification: You can inspect the network mapping using:

docker network inspect paperless-net

Step 4: Create Paperless Superuser
Initialize your admin account for the Paperless-ngx web interface:

docker exec -it paperless-ngx-webserver-1 python3 manage.py createsuperuser

Follow the terminal prompts to configure your username, email, and password.
Step 5: Post-Deployment Steps

    Open your browser and navigate to http://<your-unraid-ip>:8000.
    Go to Settings -> API Tokens and generate an API Token.
    Update your .env file with this token at PAPERLESS_API_TOKEN.
    Re-run docker compose up -d to restart the middleware with the correct credentials.