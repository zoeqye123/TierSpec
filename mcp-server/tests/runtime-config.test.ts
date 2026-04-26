import { homedir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { resolveRuntimeOptions } from '../src/runtime-config.js';

describe('runtime config', () => {
  it('prefers documented environment variables', () => {
    expect(
      resolveRuntimeOptions({
        TSPEC_MCP_DB: '/tmp/documented.sqlite',
        TSPEC_MCP_ACTOR: 'documented-actor',
        TIERSPEC_MCP_DB_PATH: '/tmp/legacy.sqlite',
        TIERSPEC_MCP_ACTOR_ID: 'legacy-actor',
      }),
    ).toEqual({
      databasePath: '/tmp/documented.sqlite',
      actorUserId: 'documented-actor',
    });
  });

  it('falls back to legacy environment variable names for backwards compatibility', () => {
    expect(
      resolveRuntimeOptions({
        TIERSPEC_MCP_DB_PATH: '/tmp/legacy.sqlite',
        TIERSPEC_MCP_ACTOR_ID: 'legacy-actor',
      }),
    ).toEqual({
      databasePath: '/tmp/legacy.sqlite',
      actorUserId: 'legacy-actor',
    });
  });

  it('uses the documented defaults when env vars are unset', () => {
    expect(resolveRuntimeOptions({})).toEqual({
      databasePath: join(homedir(), '.tierspec', 'tierspec.db'),
      actorUserId: 'system',
    });
  });
});
