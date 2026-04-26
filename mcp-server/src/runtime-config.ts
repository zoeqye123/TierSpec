import { homedir } from 'node:os';
import { join } from 'node:path';

export type RuntimeEnvironment = Partial<
  Record<'TSPEC_MCP_DB' | 'TSPEC_MCP_ACTOR' | 'TIERSPEC_MCP_DB_PATH' | 'TIERSPEC_MCP_ACTOR_ID', string | undefined>
>;

const defaultDatabasePath = join(homedir(), '.tierspec', 'tierspec.db');

export function resolveRuntimeOptions(env: RuntimeEnvironment) {
  return {
    databasePath: env.TSPEC_MCP_DB ?? env.TIERSPEC_MCP_DB_PATH ?? defaultDatabasePath,
    actorUserId: env.TSPEC_MCP_ACTOR ?? env.TIERSPEC_MCP_ACTOR_ID ?? 'system',
  };
}
