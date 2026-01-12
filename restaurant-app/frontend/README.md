# Restaurant App Frontend

Vite + React + TypeScript frontend for the restaurant operations dashboard.

## Features

- **Live parameter tuning**: Adjust temperature and top_p sliders in real-time
- **Model selection**: Choose which Ollama model to use
- **Instant feedback**: See how LLM responses change with different parameters
- **Health monitoring**: Visual indicator of backend/Ollama connectivity

## Quick Start

### Install Dependencies
```bash
npm install
```

### Run Development Server
```bash
npm run dev
```

The frontend will be available at **http://localhost:5173**

The backend API proxy is configured in `vite.config.ts` to forward `/api/*` requests to `http://localhost:3001`.

## Project Structure

```
frontend/
├── src/
│   ├── main.tsx           # Entry point
│   ├── App.tsx            # Main component
│   ├── App.css            # Styles
│   └── types.ts           # TypeScript interfaces
├── index.html             # HTML template
├── vite.config.ts         # Vite configuration
├── package.json           # Dependencies
└── tsconfig.json          # TypeScript config
```

## Development Workflow

1. **Start the backend first:**
   ```bash
   cd ../backend
   mirrord exec --config ../../mirrord/config.json -- npm run dev
   ```

2. **Start the frontend (in another terminal):**
   ```bash
   cd ../frontend
   npm run dev
   ```

3. **Open browser:**
   ```
   http://localhost:5173
   ```

4. **Experiment:**
   - Adjust temperature slider (0.0 = deterministic, 2.0 = very creative)
   - Adjust top-p slider (controls diversity)
   - Click "Generate Recommendations"
   - Compare outputs with different parameters

## Understanding the Parameters

### Temperature
- **0.0-0.3**: Focused, deterministic, consistent (good for operations)
- **0.4-0.7**: Balanced creativity and consistency
- **0.8-1.5**: Creative, varied, less predictable
- **1.6-2.0**: Very creative, potentially chaotic

**For restaurant ops, we recommend 0.2-0.4** for consistent, actionable advice.

### Top-p (Nucleus Sampling)
- **0.5-0.7**: More focused, fewer options considered
- **0.8-0.95**: Balanced (recommended)
- **0.95-1.0**: Maximum diversity

**For restaurant ops, we recommend 0.85-0.95** for varied but sensible recommendations.

### Model
The model name must match what's available in Ollama. Common options:
- `llama3.2` - General purpose, 3B params (fast)
- `mistral` - Strong reasoning, 7B params
- `codellama` - Code-focused (not ideal for this use case)
- `restaurant-chef` - Your custom frozen model (after creating it)

Check available models:
```bash
kubectl exec -n llm deployment/ollama -- ollama list
```

## Building for Production

```bash
npm run build
```

Output will be in `dist/`. Serve with any static file server:
```bash
npm run preview
```

## Customization

### Change Colors
Edit `src/App.css`. The gradient is defined in:
```css
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
```

### Add More Controls
Edit `src/App.tsx` to add more knobs (e.g., `num_ctx`, `repeat_penalty`).

Example:
```tsx
const [numCtx, setNumCtx] = useState(2048);

// In the JSX:
<div className="knob">
  <label htmlFor="numCtx">Context Length: <strong>{numCtx}</strong></label>
  <input
    id="numCtx"
    type="range"
    min="512"
    max="8192"
    step="512"
    value={numCtx}
    onChange={(e) => setNumCtx(parseInt(e.target.value))}
  />
</div>

// In the API call:
body: JSON.stringify({
  temperature,
  top_p: topP,
  model,
  num_ctx: numCtx,
}),
```

### Change System Prompt
The system prompt is defined in the **backend** (`backend/src/index.ts`). Edit it there, not in the frontend.

## Troubleshooting

### "Failed to generate recommendations"
- Check that the backend is running on port 3001
- Check that the backend can reach Ollama (mirrord or port-forward)
- Check browser console for detailed errors

### Health badge shows "Disconnected"
- Backend is not running or not reachable
- Ollama is not running in the cluster
- Port-forward or mirrord is not configured correctly

### Changes not reflecting
- Hard refresh: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows/Linux)
- Clear cache: `Cmd+Option+E` (Mac) or `Ctrl+Shift+Delete` (Windows/Linux)

## Linting and Formatting

```bash
npm run lint
npm run format
```

## License

MIT
