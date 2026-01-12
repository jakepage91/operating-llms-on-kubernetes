export interface Order {
  id: string;
  table: number;
  items: string[];
  specialRequests?: string;
  timestamp: string;
}

export interface RecommendationRequest {
  orders: Order[];
  temperature?: number;
  top_p?: number;
  model?: string;
}

export interface RecommendationResponse {
  summary: string;
  recommendations: string;
  staff_notifications: string;
  metadata: {
    model: string;
    temperature: number;
    top_p: number;
    timestamp: string;
  };
}

export interface OllamaGenerateRequest {
  model: string;
  prompt: string;
  system?: string;
  temperature?: number;
  top_p?: number;
  stream?: boolean;
}

export interface OllamaGenerateResponse {
  model: string;
  created_at: string;
  response: string;
  done: boolean;
  context?: number[];
  total_duration?: number;
  load_duration?: number;
  prompt_eval_count?: number;
  prompt_eval_duration?: number;
  eval_count?: number;
  eval_duration?: number;
}
