# PentAGI Setup and Usage

## Prerequisites
Before running PentAGI, ensure you have the following ready:
- **Docker & Docker Compose**: Must be installed on your system.
- **OpenAI API Key**: The installation script requires your OpenAI API key to be saved in a specific file. Create the file and add your key:
  ```bash
  mkdir -p ~/.secrets
  echo "YOUR_OPENAI_API_KEY" > ~/.secrets/OPENAI_API_KEY.txt
  ```

## Installation
The provided setup script `install-pentagi.sh` automatically handles the installation:
1. Clones the PentAGI repository to `~/labs/pentagi`.
2. Copies the environment template and automatically injects the OpenAI API key into the `.env` file.
3. Modifies `docker-compose.yml` to ensure the service listens on `0.0.0.0` instead of `127.0.0.1`.
4. Pre-fetches the required Docker images.

## Running the Server
To start the PentAGI server:

1. Navigate to the project directory:
   ```bash
   cd ~/labs/pentagi
   ```
2. Start the Docker containers:
   ```bash
   docker compose up -d
   ```
3. Access the web interface at:
   **https://localhost:8443** (Note: Ensure you are using `https://` as it serves over SSL).

To stop the server, run:
```bash
docker compose down
```

## Cloud User Port Forwarding
If you are running the lab on a remote cloud Virtual Machine, you will need to port forward to access the UI locally. 

Use the following SSH command from your local machine terminal:
```bash
ssh -L 8443:localhost:8443 <username>@<cloud_vm_ip>
```
*Replace `<username>` with your SSH username (e.g., `ubuntu` or `kali`) and `<cloud_vm_ip>` with the actual IP address of your VM.*

Once the SSH tunnel is established, you can safely navigate to **https://localhost:8443** in your local browser to access the PentAGI interface.
