export type ToolResult = {
  content: Array<{ type: 'text'; text: string }>;
  structuredContent?: unknown;
};

export type ToolRegistrar = {
  registerTool<TArgs = unknown>(
    name: string,
    config: {
      title?: string;
      description?: string;
      inputSchema?: unknown;
      annotations?: {
        title?: string;
        readOnlyHint?: boolean;
        destructiveHint?: boolean;
        idempotentHint?: boolean;
        openWorldHint?: boolean;
      };
    },
    cb: (args: TArgs) => Promise<ToolResult> | ToolResult,
  ): unknown;
};
