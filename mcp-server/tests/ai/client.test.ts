import { describe, it, expect, beforeEach } from 'vitest';
import { AIClient } from '../../src/ai/client.js';

describe('AIClient', () => {
  const mockApiKey = 'sk-test-key';

  describe('constructor', () => {
    it('should throw error if API key is missing', () => {
      expect(() => new AIClient({ apiKey: '' })).toThrow('OpenAI API key is required');
    });

    it('should create client with valid API key', () => {
      const client = new AIClient({ apiKey: mockApiKey });
      expect(client).toBeDefined();
    });

    it('should use default model if not specified', () => {
      const client = new AIClient({ apiKey: mockApiKey });
      expect(client).toBeDefined();
    });

    it('should use custom model if specified', () => {
      const client = new AIClient({ apiKey: mockApiKey, model: 'gpt-4' });
      expect(client).toBeDefined();
    });
  });

  describe('parseRequirement', () => {
    it('should have parseRequirement method', () => {
      const client = new AIClient({ apiKey: mockApiKey });
      expect(typeof client.parseRequirement).toBe('function');
    });
  });

  describe('estimateComplexity', () => {
    it('should have estimateComplexity method', () => {
      const client = new AIClient({ apiKey: mockApiKey });
      expect(typeof client.estimateComplexity).toBe('function');
    });
  });

  describe('detectDependencies', () => {
    it('should have detectDependencies method', () => {
      const client = new AIClient({ apiKey: mockApiKey });
      expect(typeof client.detectDependencies).toBe('function');
    });
  });
});
