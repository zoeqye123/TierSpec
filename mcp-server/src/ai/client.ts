import OpenAI from 'openai';
import type { AIConfig, HierarchySuggestion } from './types.js';

export class AIClient {
  private openai: OpenAI;
  private model: string;
  private temperature: number;
  private maxTokens: number;

  constructor(config: AIConfig) {
    if (!config.apiKey) {
      throw new Error('OpenAI API key is required');
    }

    this.openai = new OpenAI({
      apiKey: config.apiKey,
    });

    this.model = config.model || 'gpt-4o-mini';
    this.temperature = config.temperature ?? 0.7;
    this.maxTokens = config.maxTokens || 4000;
  }

  async parseRequirement(requirementText: string): Promise<HierarchySuggestion> {
    const systemPrompt = `You are a requirements analyst for TierSpec, a project management tool.
Your task is to parse natural language requirements into a structured hierarchy:
- Capabilities (high-level business/technical domains)
- Features (specific functionality within a capability)
- User Stories (atomic, testable units of work)
- Test Cases (verification steps with test data)

Guidelines:
1. Keep descriptions concise and business-focused
2. User Stories should be small (1-3 days of work)
3. Provide confidence scores (0.0-1.0) for each suggestion
4. Include reasoning for your decomposition
5. Generate realistic test cases with actual test data
6. Prioritize user stories (high/medium/low)

Output must be valid JSON matching this schema:
{
  "capabilities": [{
    "title": "string",
    "description": "string",
    "confidence": 0.0-1.0,
    "features": [{
      "title": "string",
      "description": "string",
      "confidence": 0.0-1.0,
      "userStories": [{
        "title": "string",
        "description": "string",
        "acceptanceCriteria": ["string"],
        "confidence": 0.0-1.0,
        "priority": "high|medium|low",
        "storyPoints": 1-8,
        "testCases": [{
          "title": "string",
          "steps": ["string"],
          "expectedResult": "string",
          "testData": "string"
        }]
      }]
    }]
  }],
  "confidence": 0.0-1.0,
  "reasoning": "string"
}`;

    try {
      const completion = await this.openai.chat.completions.create({
        model: this.model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: requirementText },
        ],
        temperature: this.temperature,
        max_tokens: this.maxTokens,
        response_format: { type: 'json_object' },
      });

      const content = completion.choices[0]?.message?.content;
      if (!content) {
        throw new Error('No response from OpenAI');
      }

      const parsed = JSON.parse(content) as HierarchySuggestion;

      return parsed;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`AI parsing failed: ${error.message}`);
      }
      throw new Error('AI parsing failed with unknown error');
    }
  }

  async estimateComplexity(storyDescription: string): Promise<{
    storyPoints: number;
    confidence: number;
    reasoning: string;
  }> {
    const systemPrompt = `You are a story point estimator. Analyze the user story and estimate complexity using Fibonacci scale (1, 2, 3, 5, 8).
Consider: scope, technical complexity, unknowns, dependencies.
Output JSON: {"storyPoints": number, "confidence": 0.0-1.0, "reasoning": "string"}`;

    try {
      const completion = await this.openai.chat.completions.create({
        model: this.model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: storyDescription },
        ],
        temperature: 0.3,
        max_tokens: 500,
        response_format: { type: 'json_object' },
      });

      const content = completion.choices[0]?.message?.content;
      if (!content) {
        throw new Error('No response from OpenAI');
      }

      return JSON.parse(content);
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Complexity estimation failed: ${error.message}`);
      }
      throw new Error('Complexity estimation failed with unknown error');
    }
  }

  async detectDependencies(storyDescription: string, existingStories: string[]): Promise<{
    dependencies: string[];
    confidence: number;
    reasoning: string;
  }> {
    const systemPrompt = `You are a dependency analyzer. Given a user story and a list of existing stories, identify which existing stories this new story depends on.
Output JSON: {"dependencies": ["story titles"], "confidence": 0.0-1.0, "reasoning": "string"}`;

    const userPrompt = `New story: ${storyDescription}\n\nExisting stories:\n${existingStories.join('\n')}`;

    try {
      const completion = await this.openai.chat.completions.create({
        model: this.model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: 'json_object' },
      });

      const content = completion.choices[0]?.message?.content;
      if (!content) {
        throw new Error('No response from OpenAI');
      }

      return JSON.parse(content);
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Dependency detection failed: ${error.message}`);
      }
      throw new Error('Dependency detection failed with unknown error');
    }
  }
}
