import express, { Request, Response } from 'express';
import cors from 'cors';
import { OllamaClient } from './ollama-client';
import type { RecommendationRequest, RecommendationResponse, Order } from './types';

const app = express();
const PORT = process.env.PORT || 3001;
const OLLAMA_HOST = process.env.OLLAMA_HOST || 'http://ollama:11434';

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Ollama client
const ollama = new OllamaClient(OLLAMA_HOST);

// Restaurant operations system prompt
const SYSTEM_PROMPT = `You are a restaurant operations assistant. Your role is to analyze tonight's orders and provide actionable recommendations.

Response format (use this exact structure):
**SUMMARY:**
[2-3 bullet points about order volume, trends, popular items]

**RECOMMENDATIONS:**
[3-4 specific actions for kitchen prep, inventory, or service]

**STAFF NOTIFICATIONS:**
[1-2 urgent items to communicate to staff]

Keep responses concise. Use bullet points. No pleasantries. Kitchen language only.`;

// Sample orders for testing
const SAMPLE_ORDERS: Order[] = [
  {
    id: 'ord-001',
    table: 5,
    items: ['Caesar Salad', 'Grilled Salmon', 'House Wine'],
    specialRequests: 'No croutons, extra dressing',
    timestamp: new Date().toISOString(),
  },
  {
    id: 'ord-002',
    table: 3,
    items: ['Margherita Pizza', 'Caprese Salad'],
    timestamp: new Date().toISOString(),
  },
  {
    id: 'ord-003',
    table: 8,
    items: ['Ribeye Steak', 'Mashed Potatoes', 'Seasonal Vegetables', 'Red Wine'],
    specialRequests: 'Steak medium-rare',
    timestamp: new Date().toISOString(),
  },
  {
    id: 'ord-004',
    table: 2,
    items: ['Pasta Carbonara', 'Garlic Bread'],
    timestamp: new Date().toISOString(),
  },
  {
    id: 'ord-005',
    table: 12,
    items: ['Caesar Salad', 'Grilled Chicken', 'Tiramisu'],
    timestamp: new Date().toISOString(),
  },
];

/**
 * Health check endpoint
 */
app.get('/health', async (req: Request, res: Response) => {
  const ollamaHealthy = await ollama.healthCheck();
  res.json({
    status: 'ok',
    ollama: {
      connected: ollamaHealthy,
      host: ollama.getBaseUrl(),
    },
    timestamp: new Date().toISOString(),
  });
});

/**
 * Get sample orders for testing
 */
app.get('/api/sample-orders', (req: Request, res: Response) => {
  res.json({ orders: SAMPLE_ORDERS });
});

/**
 * Get available models
 */
app.get('/api/models', async (req: Request, res: Response) => {
  try {
    const models = await ollama.listModels();
    res.json(models);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to fetch models',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * Generate restaurant recommendations based on orders
 */
app.post('/api/recommendations', async (req: Request, res: Response) => {
  try {
    const {
      orders = SAMPLE_ORDERS,
      temperature = 0.2,
      top_p = 0.9,
      model = 'llama3.2',
    }: RecommendationRequest = req.body;

    // Validate inputs
    if (temperature < 0 || temperature > 2) {
      return res.status(400).json({ error: 'Temperature must be between 0 and 2' });
    }
    if (top_p < 0 || top_p > 1) {
      return res.status(400).json({ error: 'top_p must be between 0 and 1' });
    }

    // Build the prompt from orders
    const ordersText = orders
      .map((order) => {
        const items = order.items.join(', ');
        const special = order.specialRequests ? ` (${order.specialRequests})` : '';
        return `Table ${order.table}: ${items}${special}`;
      })
      .join('\n');

    const prompt = `Tonight's orders:
${ordersText}

Analyze these orders and provide your operations summary, recommendations, and staff notifications.`;

    console.log(`[${new Date().toISOString()}] Calling Ollama with model: ${model}`);
    console.log(`Parameters: temperature=${temperature}, top_p=${top_p}`);

    // Call Ollama
    const response = await ollama.generate({
      model,
      prompt,
      system: SYSTEM_PROMPT,
      temperature,
      top_p,
    });

    // Parse the response
    const text = response.response;
    const summaryMatch = text.match(/\*\*SUMMARY:\*\*([\s\S]*?)(?=\*\*RECOMMENDATIONS:|\*\*STAFF|$)/i);
    const recommendationsMatch = text.match(/\*\*RECOMMENDATIONS:\*\*([\s\S]*?)(?=\*\*STAFF|$)/i);
    const staffMatch = text.match(/\*\*STAFF NOTIFICATIONS:\*\*([\s\S]*?)$/i);

    const result: RecommendationResponse = {
      summary: summaryMatch ? summaryMatch[1].trim() : text,
      recommendations: recommendationsMatch ? recommendationsMatch[1].trim() : '',
      staff_notifications: staffMatch ? staffMatch[1].trim() : '',
      metadata: {
        model,
        temperature,
        top_p,
        timestamp: new Date().toISOString(),
      },
    };

    console.log(`[${new Date().toISOString()}] Response generated successfully`);
    res.json(result);
  } catch (error) {
    console.error('Error generating recommendations:', error);
    res.status(500).json({
      error: 'Failed to generate recommendations',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🍽️  Restaurant LLM Backend running on port ${PORT}`);
  console.log(`📡 Ollama host: ${OLLAMA_HOST}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`🔗 API docs: http://localhost:${PORT}/api/recommendations`);
});
