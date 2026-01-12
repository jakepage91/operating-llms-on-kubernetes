export interface Order {
  id: string;
  table: number;
  items: string[];
  specialRequests?: string;
  timestamp: string;
}

export interface RecommendationRequest {
  orders?: Order[];
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

export interface HealthResponse {
  status: string;
  ollama: {
    connected: boolean;
    host: string;
  };
  timestamp: string;
}
