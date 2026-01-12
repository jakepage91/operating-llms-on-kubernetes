# Open WebUI (Vendored)

This directory should contain the full Open WebUI source code, vendored via `git subtree`.

## How to Vendor Open WebUI

Run this command from the repository root:

```bash
git subtree add --prefix open-webui https://github.com/open-webui/open-webui.git main --squash
```

This will:
1. Clone the Open WebUI repository
2. Copy all files into this `open-webui/` directory
3. Preserve the MIT license and commit history
4. Make the code available for local iteration

## Why Vendor?

- ✅ Full source code is present (no external dependency)
- ✅ Can modify and customize locally
- ✅ Easy to update: `git subtree pull --prefix open-webui https://github.com/open-webui/open-webui.git main --squash`
- ✅ License preserved automatically

## Running Open WebUI Locally

Once vendored, you can run Open WebUI in dev mode:

### Backend (Python)
```bash
cd open-webui/backend
pip install -r requirements.txt
mirrord exec --config ../../mirrord/config.json -- python main.py
```

### Frontend (Svelte)
```bash
cd open-webui
npm install
npm run dev
```

Open WebUI will be available at `http://localhost:8080` (or the configured port).

## Configuration

Open WebUI can be configured to use your in-cluster Ollama:

**Option 1: Environment variable**
```bash
export OLLAMA_API_BASE_URL=http://ollama:11434
```

**Option 2: UI settings**
Navigate to Settings → Connections → Ollama API URL and set to `http://ollama:11434` (when running with mirrord).

## Documentation

Full Open WebUI documentation: https://docs.openwebui.com

## License

Open WebUI is licensed under the MIT License. See the `LICENSE` file in this directory after vendoring.

## Note

This directory is currently a placeholder. Run the vendoring command above to populate it with the actual Open WebUI source code.
