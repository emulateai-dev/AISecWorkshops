### PyRIT Docker Setup Guide

**Step 1: Clone the Repository**
Pull the source code and navigate into the root directory. (Crucial: Do not go into the `docker/` folder yet!)

```bash
git clone https://github.com/jitendra-eai/PyRIT.git
cd PyRIT

```

**Step 2: Build the Base Devcontainer Image**
Because of how the context is structured, you must build the base image from the root of the repository to prevent the `path ".devcontainer" not found` error.

```bash
docker build -f .devcontainer/Dockerfile -t pyrit-devcontainer .devcontainer

```

**Step 3: Configure Your Environment (.env and .env.local)**
PyRIT securely mounts your local `~/.pyrit/` directory to pass credentials into the containers. Set up the folder and create your environment files:

```bash
mkdir -p ~/.pyrit
touch ~/.pyrit/.env ~/.pyrit/.env.local

```

Choose **one** of the following configurations depending on your backend:

* **Option A: Standard OpenAI Configuration**
If you are using standard OpenAI, you only need to populate the base `.env` file.
*Add to `~/.pyrit/.env`:*
```text
OPENAI_API_KEY="sk-proj-your-openai-key-here"

```


* **Option B: Groq (OpenAI-Compatible) Configuration**
Use this to route PyRIT's default OpenAI calls through Groq for ultra-fast generation. Set your base platform variables in `.env`, and then use `.env.local` to override PyRIT's default target mapping.
*1. Add to `~/.pyrit/.env`:*
```text
PLATFORM_OPENAI_CHAT_ENDPOINT="https://api.groq.com/openai/v1"
PLATFORM_OPENAI_CHAT_API_KEY="gsk_eU11D06**"
PLATFORM_OPENAI_CHAT_GPT4O_MODEL="openai/gpt-oss-120b"

```


*2. Add to `~/.pyrit/.env.local`:*
```text
# This will override the .env value for your default OpenAIChatTarget
OPENAI_CHAT_ENDPOINT=${PLATFORM_OPENAI_CHAT_ENDPOINT}
OPENAI_CHAT_KEY=${PLATFORM_OPENAI_CHAT_API_KEY}
OPENAI_CHAT_MODEL="openai/gpt-oss-120b"

```



**Step 4: Start the Containers with Profiles**
To avoid the `no service selected` error, explicitly tell Docker Compose which profiles to start, and point it to the YAML file in the `docker` subdirectory while remaining in the repository root:

```bash
docker compose -f docker/docker-compose.yaml --profile jupyter --profile gui up -d

```

*(Optional: Verify everything started successfully and is healthy by checking the logs)*:

```bash
docker compose -f docker/docker-compose.yaml logs -f

```

**Step 5: Access PyRIT**
Your local environment is now fully running and authenticated with your overrides in place! You can access the interfaces in your browser:

* **PyRIT GUI:** [http://localhost:8000](https://www.google.com/search?q=http://localhost:8000)
* **Jupyter Notebooks:** [http://localhost:8888](https://www.google.com/search?q=http://localhost:8888)

---




