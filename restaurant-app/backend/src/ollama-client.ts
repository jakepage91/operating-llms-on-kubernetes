import axios, { AxiosInstance } from 'axios';
import type { OllamaGenerateRequest, OllamaGenerateResponse } from './types';

export class OllamaClient {
  private client: AxiosInstance;
  private baseUrl: string;

  constructor(baseUrl: string = 'http://ollama:11434') {
    this.baseUrl = baseUrl;
    this.client = axios.create({
      baseURL: baseUrl,
      timeout: 120000, // 2 minutes for LLM responses
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Generate a completion from Ollama
   */
  async generate(request: OllamaGenerateRequest): Promise<OllamaGenerateResponse> {
    try {
      const response = await this.client.post<OllamaGenerateResponse>(
        '/api/generate',
        {
          ...request,
          stream: false, // We want the full response at once
        }
      );
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(
          `Ollama API error: ${error.response?.status} - ${error.response?.data?.error || error.message}`
        );
      }
      throw error;
    }
  }

  /**
   * List available models
   */
  async listModels(): Promise<{ models: Array<{ name: string; size: number }> }> {
    try {
      const response = await this.client.get('/api/tags');
      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Failed to list models: ${error.message}`);
      }
      throw error;
    }
  }

  /**
   * Check if Ollama is healthy
   */
  async healthCheck(): Promise<boolean> {
    try {
      await this.client.get('/');
      return true;
    } catch {
      return false;
    }
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }
}
