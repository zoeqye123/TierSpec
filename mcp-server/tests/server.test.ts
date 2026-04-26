import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';

import { createTierSpecServer, ALL_TOOL_NAMES } from '../src/server.js';
import { ItemType } from '../src/db/types.js';
import { createTestDatabase, insertItem, insertUser } from './db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('MCP server integration', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb.cleanup();
  });

  it('creates a server runtime with all tools registered', () => {
    const runtime = createTierSpecServer({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    expect(runtime.server).toBeTruthy();
    expect(runtime.toolNames).toEqual(ALL_TOOL_NAMES);

    void runtime.close();
  });

  it('registers all 14 tools over the MCP protocol', async () => {
    const runtime = createTierSpecServer({
      database: testDb.database,
      actorUserId: 'user-1',
    });
    const client = new Client({ name: 'tierspec-test-client', version: '0.1.0' });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

    await Promise.all([runtime.server.connect(serverTransport), client.connect(clientTransport)]);

    const listed = await client.listTools();

    expect(listed.tools).toHaveLength(14);
    expect(listed.tools.map((tool) => tool.name).sort()).toEqual([...ALL_TOOL_NAMES].sort());

    await Promise.all([client.close(), runtime.close()]);
  });

  it('executes registered tools through MCP messages', async () => {
    insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Platform',
      created_by: 'user-1',
      updated_by: 'user-1',
    });

    const runtime = createTierSpecServer({
      database: testDb.database,
      actorUserId: 'user-1',
    });
    const client = new Client({ name: 'tierspec-test-client', version: '0.1.0' });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

    await Promise.all([runtime.server.connect(serverTransport), client.connect(clientTransport)]);

    await client.ping();

    const created = await client.callTool({
      name: 'create_item',
      arguments: {
        type: ItemType.Feature,
        title: 'Authentication',
        parent_id: 'cap-1',
      },
    });
    const listed = await client.callTool({
      name: 'list_items',
      arguments: { type: ItemType.Feature },
    });

    expect(created.structuredContent).toMatchObject({
      id: expect.any(String),
      type: ItemType.Feature,
      parent_id: 'cap-1',
      title: 'Authentication',
    });
    expect(listed.structuredContent).toMatchObject({
      items: [
        expect.objectContaining({
          type: ItemType.Feature,
          title: 'Authentication',
        }),
      ],
    });

    await Promise.all([client.close(), runtime.close()]);
  });

  it('defaults workflow actor_id to the configured runtime actor for external databases', async () => {
    insertItem(testDb.database, {
      id: 'cap-review',
      type: ItemType.Capability,
      title: 'Review capability',
      created_by: 'user-1',
      updated_by: 'user-1',
    });
    testDb.database
      .prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?')
      .run('requirement_input', 'user-1', 'cap-review');

    const runtime = createTierSpecServer({
      database: testDb.database,
      actorUserId: 'workflow-actor',
      actorName: 'Workflow Actor',
      actorEmail: 'workflow-actor@example.com',
    });
    const client = new Client({ name: 'tierspec-test-client', version: '0.1.0' });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

    await Promise.all([runtime.server.connect(serverTransport), client.connect(clientTransport)]);

    const updated = await client.callTool({
      name: 'transition_state',
      arguments: {
        item_id: 'cap-review',
        new_state: 'requirement_review',
      },
    });

    const auditEvent = testDb.database
      .prepare('SELECT actor_id FROM audit_events WHERE entity_id = ?')
      .get('cap-review') as { actor_id: string };
    const actorUser = testDb.database
      .prepare('SELECT id FROM users WHERE id = ?')
      .get('workflow-actor') as { id: string } | undefined;

    expect(updated.structuredContent).toMatchObject({
      item: {
        id: 'cap-review',
        status: 'requirement_review',
      },
    });
    expect(auditEvent.actor_id).toBe('workflow-actor');
    expect(actorUser?.id).toBe('workflow-actor');

    await Promise.all([client.close(), runtime.close()]);
  });
});
