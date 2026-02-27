# Vulhub Setup and Usage

## Prerequisites
Before running Vulhub environments, ensure you have the following ready:
- **Docker & Docker Compose**: Must be installed on your system.
- No specific API keys are required for the base Vulhub installation.

## Installation
The provided setup script `install-vulnhub-lab.sh` automatically handles the installation:
1. Clones the official Vulhub repository to `~/labs/vulhub` (using a shallow clone `--depth 1` for faster download and smaller size).
2. Prints a quick list of some example available vulnerable environments.

## Running the Servers (Environments)
Unlike a single application, Vulhub consists of many isolated, containerized vulnerable environments. You must navigate to and run each environment individually.

1. Navigate to the main Vulhub directory:
   ```bash
   cd ~/labs/vulhub
   ```
2. Navigate to the specific vulnerability environment you want to test (for example, a specific Apache vulnerability):
   ```bash
   cd apache/CVE-2021-41773
   ```
3. Start the Docker containers for that specific environment:
   ```bash
   docker compose up -d
   ```
4. Find the Access Port:
   The specific port depends on the environment you just started. You can check which port is exposed by either opening the `docker-compose.yml` file in that directory or by running:
   ```bash
   docker ps
   ```

To stop the environment and clean up resources when you are done, run:
```bash
docker compose down
```

## Cloud User Port Forwarding
If you are running these vulnerable labs on a remote cloud Virtual Machine, you will need to map the ports to your local machine via SSH to access web interfaces or send payloads.

First, determine the port the specific environment is using (e.g., `8080`, `80`, `443`, `8000`).

Use the following SSH command from your local machine terminal:
```bash
ssh -L <target_port>:localhost:<target_port> <username>@<cloud_vm_ip>
```
*Example for an environment running on port 8080:*
```bash
ssh -L 8080:localhost:8080 dtx@1.1.1.1
```
*Replace `<target_port>` with the actual port, `<username>` with your SSH username (e.g., `ubuntu` or `kali`), and `<cloud_vm_ip>` with your VM's IP address.*

Once the SSH tunnel is active, you can interact with the vulnerable application by navigating to **http://localhost:<target_port>** in your local browser or attacking that local port with your tools.
