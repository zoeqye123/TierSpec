import process from 'node:process';

import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { resolveRuntimeOptions } from './runtime-config.js';
import { createTierSpecServer } from './server.js';

async function main() {
  const runtime = createTierSpecServer(resolveRuntimeOptions(process.env));
  const transport = new StdioServerTransport();

  let shuttingDown = false;
  const shutdown = async (signal?: string) => {
    if (shuttingDown) {
      return;
    }

    shuttingDown = true;

    if (signal) {
      console.error(`[tierspec-mcp] shutting down on ${signal}`);
    }

    try {
      await runtime.close();
    } finally {
      if (signal) {
        process.exit(0);
      }
    }
  };

  process.once('SIGINT', () => void shutdown('SIGINT'));
  process.once('SIGTERM', () => void shutdown('SIGTERM'));

  await runtime.server.connect(transport);
  console.error(`[tierspec-mcp] server ready with ${runtime.toolNames.length} tools`);
}

main().catch(async (error: unknown) => {
  console.error('[tierspec-mcp] fatal startup error', error);
  process.exit(1);
});
