import { z } from 'zod';
import { AIClient } from '../ai/client.js';
import type { ToolRegistrar } from '../types/tool-registrar.js';
import type { Database } from '../db/client.js';

const parseRequirementSchema = z.object({
  requirement: z.string().min(10).describe('Natural language requirement text'),
  apiKey: z.string().optional().describe('OpenAI API key (optional if set in config)'),
});

const estimateComplexitySchema = z.object({
  storyDescription: z.string().describe('User story description'),
  apiKey: z.string().optional(),
});

const detectDependenciesSchema = z.object({
  storyDescription: z.string().describe('User story description'),
  existingStoryIds: z.array(z.string()).describe('IDs of existing stories to check against'),
  apiKey: z.string().optional(),
});

type AIToolsOptions = {
  database: Database;
  defaultApiKey?: string;
};

export function createAITools({ database, defaultApiKey }: AIToolsOptions) {
  const getAIClient = (providedKey?: string): AIClient => {
    const apiKey = providedKey || defaultApiKey || process.env.OPENAI_API_KEY;
    if (!apiKey) {
      throw new Error(
        'OpenAI API key required. Provide via parameter, config file, or OPENAI_API_KEY environment variable.',
      );
    }
    return new AIClient({ apiKey });
  };

  return {
    parse_requirement: {
      description:
        'Parse natural language requirement into structured hierarchy (Capability → Feature → User Story → Test Case) with confidence scores',
      inputSchema: parseRequirementSchema,
      annotations: {
        title: 'Parse Requirement',
        openWorldHint: true,
      },
      handler: async (input: z.infer<typeof parseRequirementSchema>) => {
        try {
          const client = getAIClient(input.apiKey);
          const suggestion = await client.parseRequirement(input.requirement);

          return {
            content: [
              {
                type: 'text' as const,
                text: JSON.stringify(suggestion, null, 2),
              },
            ],
            structuredContent: suggestion,
          };
        } catch (error) {
          return {
            content: [
              {
                type: 'text' as const,
                text: `AI parsing failed: ${error instanceof Error ? error.message : String(error)}`,
              },
            ],
            isError: true,
          };
        }
      },
    },

    estimate_complexity: {
      description:
        'Estimate story points (1-8 Fibonacci scale) for a user story using AI analysis',
      inputSchema: estimateComplexitySchema,
      annotations: {
        title: 'Estimate Complexity',
        openWorldHint: true,
      },
      handler: async (input: z.infer<typeof estimateComplexitySchema>) => {
        try {
          const client = getAIClient(input.apiKey);
          const estimate = await client.estimateComplexity(input.storyDescription);

          return {
            content: [
              {
                type: 'text' as const,
                text: JSON.stringify(estimate, null, 2),
              },
            ],
            structuredContent: estimate,
          };
        } catch (error) {
          return {
            content: [
              {
                type: 'text' as const,
                text: `Complexity estimation failed: ${error instanceof Error ? error.message : String(error)}`,
              },
            ],
            isError: true,
          };
        }
      },
    },

    detect_dependencies: {
      description:
        'Detect dependencies between a new user story and existing stories using AI analysis',
      inputSchema: detectDependenciesSchema,
      annotations: {
        title: 'Detect Dependencies',
        openWorldHint: true,
      },
      handler: async (input: z.infer<typeof detectDependenciesSchema>) => {
        try {
          const getItemById = database.prepare<unknown[], { title: string }>(
            'SELECT title FROM items WHERE id = ? AND deleted_at IS NULL',
          );

          const existingStories = input.existingStoryIds
            .map((id) => getItemById.get(id)?.title)
            .filter((title): title is string => title !== undefined);

          const client = getAIClient(input.apiKey);
          const dependencies = await client.detectDependencies(
            input.storyDescription,
            existingStories,
          );

          return {
            content: [
              {
                type: 'text' as const,
                text: JSON.stringify(dependencies, null, 2),
              },
            ],
            structuredContent: dependencies,
          };
        } catch (error) {
          return {
            content: [
              {
                type: 'text' as const,
                text: `Dependency detection failed: ${error instanceof Error ? error.message : String(error)}`,
              },
            ],
            isError: true,
          };
        }
      },
    },
  };
}

export function registerAITools(registrar: ToolRegistrar, options: AIToolsOptions) {
  const tools = createAITools(options);

  registrar.registerTool(
    'parse_requirement',
    {
      title: 'Parse Requirement',
      description: tools.parse_requirement.description,
      inputSchema: tools.parse_requirement.inputSchema,
      annotations: tools.parse_requirement.annotations,
    },
    tools.parse_requirement.handler,
  );

  registrar.registerTool(
    'estimate_complexity',
    {
      title: 'Estimate Complexity',
      description: tools.estimate_complexity.description,
      inputSchema: tools.estimate_complexity.inputSchema,
      annotations: tools.estimate_complexity.annotations,
    },
    tools.estimate_complexity.handler,
  );

  registrar.registerTool(
    'detect_dependencies',
    {
      title: 'Detect Dependencies',
      description: tools.detect_dependencies.description,
      inputSchema: tools.detect_dependencies.inputSchema,
      annotations: tools.detect_dependencies.annotations,
    },
    tools.detect_dependencies.handler,
  );
}
