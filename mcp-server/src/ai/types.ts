export interface HierarchySuggestion {
  capabilities: CapabilitySuggestion[];
  confidence: number;
  reasoning: string;
}

export interface CapabilitySuggestion {
  title: string;
  description: string;
  confidence: number;
  features: FeatureSuggestion[];
}

export interface FeatureSuggestion {
  title: string;
  description: string;
  confidence: number;
  userStories: UserStorySuggestion[];
}

export interface UserStorySuggestion {
  title: string;
  description: string;
  acceptanceCriteria: string[];
  confidence: number;
  priority: 'high' | 'medium' | 'low';
  storyPoints?: number;
  testCases: TestCaseSuggestion[];
}

export interface TestCaseSuggestion {
  title: string;
  steps: string[];
  expectedResult: string;
  testData: string;
}

export interface AIConfig {
  apiKey: string;
  model?: string;
  temperature?: number;
  maxTokens?: number;
}
