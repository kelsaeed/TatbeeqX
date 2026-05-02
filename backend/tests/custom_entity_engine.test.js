import { describe, it, expect } from 'vitest';
import { prisma } from '../src/lib/prisma.js';
import {
  applyColumnDiff,
  buildCreateTableSQL,
  buildJoinTableSQL,
  canEditCol,
  canViewCol,
  deleteRow,
  diffColumns,
  ensureJoinTables,
  ensureTable,
  filterExistingTargetIds,
  FORMULA_TYPE,
  getRow,
  insertRow,
  isRelationsCol,
  joinTableName,
  listRows,
  nullifyDanglingSingleRelations,
  RELATIONS_TYPE,
  reverseCascadeRelations,
  updateRow,
} from '../src/lib/custom_entity_engine.js';

describe('diffColumns', () => {
  it('returns empty diff when columns are identical', () => {
    const cols = [{ name: 'sku', type: 'text' }, { name: 'price', type: 'number' }];
    const out = diffColumns(cols, cols);
    expect(out.added).toEqual([]);
    expect(out.removed).toEqual([]);
    expect(out.changed).toEqual([]);
  });

  it('detects added columns', () => {
    const oldCols = [{ name: 'sku', type: 'text' }];
    const newCols = [{ name: 'sku', type: 'text' }, { name: 'price', type: 'number' }];
    const out = diffColumns(oldCols, newCols);
    expect(out.added).toHaveLength(1);
    expect(out.added[0].name).toBe('price');
    expect(out.removed).toEqual([]);
    expect(out.changed).toEqual([]);
  });

  it('detects removed columns', () => {
    const oldCols = [{ name: 'sku', type: 'text' }, { name: 'old', type: 'integer' }];
    const newCols = [{ name: 'sku', type: 'text' }];
    const out = diffColumns(oldCols, newCols);
    expect(out.added).toEqual([]);
    expect(out.removed).toHaveLength(1);
    expect(out.removed[0].name).toBe('old');
  });

  it('flags type changes as changed (not as add+remove)', () => {
    const oldCols = [{ name: 'price', type: 'integer' }];
    const newCols = [{ name: 'price', type: 'number' }];
    const out = diffColumns(oldCols, newCols);
    expect(out.added).toEqual([]);
    expect(out.removed).toEqual([]);
    expect(out.changed).toEqual([{ name: 'price', from: 'integer', to: 'number' }]);
  });

  it('handles all three changes at once', () => {
    const oldCols = [
      { name: 'sku',   type: 'text' },
      { name: 'old',   type: 'integer' },
      { name: 'price', type: 'integer' },
    ];
    const newCols = [
      { name: 'sku',   type: 'text' },
      { name: 'new',   type: 'text' },
      { name: 'price', type: 'number' },
    ];
    const out = diffColumns(oldCols, newCols);
    expect(out.added.map((c) => c.name)).toEqual(['new']);
    expect(out.removed.map((c) => c.name)).toEqual(['old']);
    expect(out.changed).toEqual([{ name: 'price', from: 'integer', to: 'number' }]);
  });

  it('treats null/undefined as empty', () => {
    expect(diffColumns(null, undefined)).toEqual({ added: [], removed: [], changed: [] });
    expect(diffColumns([], [])).toEqual({ added: [], removed: [], changed: [] });
  });
});

// Phase 4.11 — auto-heal missing SQL tables.
//
// Reproduces the bug from the user's report: a custom entity is
// registered but the underlying table doesn't exist. The CRUD ops
// should recreate it from the registered config rather than 500ing.
describe('ensureTable — auto-heal missing custom-entity tables', () => {
  // Use a unique table name per test run so the same DB doesn't
  // accumulate auto-healed tables across runs.
  function uniqueName() {
    return `test_autoheal_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }

  async function dropIfExists(tableName) {
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${tableName}"`);
  }

  function fakeEntity({ tableName, code = 'autoheal_test' } = {}) {
    return {
      code,
      tableName,
      config: JSON.stringify({
        columns: [
          { name: 'name', type: 'text', required: true, searchable: true },
          { name: 'qty', type: 'integer' },
        ],
      }),
    };
  }

  it('creates the table when missing and reports it', async () => {
    const tableName = uniqueName();
    await dropIfExists(tableName);
    const entity = fakeEntity({ tableName });
    try {
      const created = await ensureTable(entity);
      expect(created).toBe(true);
      const result = await listRows(entity, { page: 1, pageSize: 10, search: '' });
      expect(result.items).toEqual([]);
      expect(result.total).toBe(0);
    } finally {
      await dropIfExists(tableName);
    }
  });

  it('is a no-op when the table already exists', async () => {
    const tableName = uniqueName();
    const entity = fakeEntity({ tableName });
    try {
      await ensureTable(entity); // first call creates
      const second = await ensureTable(entity); // should be no-op
      expect(second).toBe(false);
    } finally {
      await dropIfExists(tableName);
    }
  });

  it('listRows auto-heals a dropped table without throwing', async () => {
    const tableName = uniqueName();
    const entity = fakeEntity({ tableName });
    try {
      await ensureTable(entity);
      await insertRow(entity, { name: 'alpha', qty: 1 });

      // Simulate the user-reported "no such table" scenario.
      await dropIfExists(tableName);

      const result = await listRows(entity, { page: 1, pageSize: 10, search: '' });
      expect(result.total).toBe(0); // table was recreated empty
    } finally {
      await dropIfExists(tableName);
    }
  });

  it('rejects healing when the stored config has no columns', async () => {
    const tableName = uniqueName();
    const broken = {
      code: 'autoheal_broken',
      tableName,
      config: JSON.stringify({ columns: [] }),
    };
    await dropIfExists(tableName);
    try {
      await expect(ensureTable(broken)).rejects.toThrow(/no columns/);
    } finally {
      await dropIfExists(tableName);
    }
  });
});

// Phase 4.15 — many-to-many `relations` columns.
//
// `relations` columns don't get a column on the source table; they live
// in their own join table named `<source>__<col>__rel`. CRUD must
// transparently round-trip arrays of target IDs and cascade-delete
// orphaned join rows when the source row is deleted.
describe('relations (many-to-many) columns', () => {
  function uniqueName(prefix = 'rel_test') {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }
  async function dropIfExists(tableName) {
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${tableName}"`);
  }

  function entityWithRelations({ tableName, relColName = 'tags' }) {
    return {
      code: `${tableName}_e`,
      tableName,
      config: JSON.stringify({
        columns: [
          { name: 'name', type: 'text', required: true, searchable: true },
          { name: relColName, type: RELATIONS_TYPE, targetEntity: 'tag_pool' },
        ],
      }),
    };
  }

  it('isRelationsCol + RELATIONS_TYPE — basic predicate', () => {
    expect(isRelationsCol({ type: RELATIONS_TYPE })).toBe(true);
    expect(isRelationsCol({ type: 'text' })).toBe(false);
    expect(isRelationsCol(null)).toBe(false);
    expect(isRelationsCol(undefined)).toBe(false);
  });

  it('joinTableName follows the documented convention', () => {
    expect(joinTableName('products', 'categories')).toBe('products__categories__rel');
  });

  it('buildCreateTableSQL skips relations columns from the source table', () => {
    const sql = buildCreateTableSQL('products', [
      { name: 'name', type: 'text' },
      { name: 'tags', type: RELATIONS_TYPE, targetEntity: 'tag_pool' },
      { name: 'qty', type: 'integer' },
    ]);
    // Source-table columns:
    expect(sql).toContain('"name" TEXT');
    expect(sql).toContain('"qty" INTEGER');
    // Relations column should NOT have appeared:
    expect(sql).not.toContain('"tags"');
  });

  it('round-trips a relations array via insertRow + getRow', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity); // creates source + join table
      const created = await insertRow(entity, { name: 'widget', tags: [10, 20, 30] });
      expect(created.name).toBe('widget');
      expect(created.tags).toEqual([10, 20, 30]);

      // getRow returns the same shape
      const fetched = await getRow(entity, created.id);
      expect(fetched.tags).toEqual([10, 20, 30]);

      // Verify in the actual join table
      const rows = await prisma.$queryRawUnsafe(
        `SELECT target_id FROM "${joinT}" WHERE source_id = ? ORDER BY target_id`,
        created.id,
      );
      expect(rows.map((r) => Number(r.target_id))).toEqual([10, 20, 30]);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('updateRow diffs relations — adds new, removes dropped, keeps shared', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity);
      const created = await insertRow(entity, { name: 'w', tags: [1, 2, 3] });
      // Replace [1,2,3] → [2,3,4]: 1 dropped, 4 added, 2/3 kept
      const updated = await updateRow(entity, created.id, { tags: [2, 3, 4] });
      expect(updated.tags.sort()).toEqual([2, 3, 4]);
      const rows = await prisma.$queryRawUnsafe(
        `SELECT target_id FROM "${joinT}" WHERE source_id = ? ORDER BY target_id`,
        created.id,
      );
      expect(rows.map((r) => Number(r.target_id))).toEqual([2, 3, 4]);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('updateRow leaves relations untouched when the body omits the field', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity);
      const created = await insertRow(entity, { name: 'w', tags: [1, 2] });
      // Body without `tags` → relations are preserved
      await updateRow(entity, created.id, { name: 'renamed' });
      const fetched = await getRow(entity, created.id);
      expect(fetched.name).toBe('renamed');
      expect(fetched.tags).toEqual([1, 2]);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('deleteRow cascades — purges all join rows for the deleted source', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity);
      const a = await insertRow(entity, { name: 'a', tags: [1, 2] });
      const b = await insertRow(entity, { name: 'b', tags: [1, 3] });
      await deleteRow(entity, a.id);
      const remaining = await prisma.$queryRawUnsafe(
        `SELECT source_id, target_id FROM "${joinT}" ORDER BY source_id, target_id`,
      );
      // Only b's relations should remain
      expect(remaining.length).toBe(2);
      expect(remaining.every((r) => Number(r.source_id) === Number(b.id))).toBe(true);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('listRows batch-fetches relations for the whole page (no N+1)', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity);
      await insertRow(entity, { name: 'a', tags: [1] });
      await insertRow(entity, { name: 'b', tags: [1, 2] });
      await insertRow(entity, { name: 'c', tags: [] });

      const result = await listRows(entity, { page: 1, pageSize: 10, search: '' });
      // Order is DESC by id — c, b, a
      expect(result.items.map((r) => r.name)).toEqual(['c', 'b', 'a']);
      expect(result.items[0].tags).toEqual([]);
      expect(result.items[1].tags.sort()).toEqual([1, 2]);
      expect(result.items[2].tags).toEqual([1]);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('applyColumnDiff handles relations columns via join-table create/drop, not ALTER TABLE', async () => {
    const tableName = uniqueName();
    const initialEntity = {
      tableName,
      config: JSON.stringify({ columns: [{ name: 'name', type: 'text' }] }),
    };
    try {
      await prisma.$executeRawUnsafe(buildCreateTableSQL(tableName, [{ name: 'name', type: 'text' }]));

      // Add a relations column via diff
      const diffAdd = diffColumns(
        [{ name: 'name', type: 'text' }],
        [{ name: 'name', type: 'text' }, { name: 'tags', type: RELATIONS_TYPE }],
      );
      const sumAdd = await applyColumnDiff(tableName, diffAdd);
      expect(sumAdd.ran).toContainEqual({ op: 'addJoinTable', column: 'tags' });
      // Source table must NOT have grown a "tags" column.
      const cols = await prisma.$queryRawUnsafe(`PRAGMA table_info("${tableName}")`);
      expect(cols.map((c) => c.name)).not.toContain('tags');
      // Join table must exist and be writable.
      const jt = joinTableName(tableName, 'tags');
      const probe = await prisma.$queryRawUnsafe(`SELECT name FROM sqlite_master WHERE type='table' AND name='${jt}'`);
      expect(probe.length).toBe(1);

      // Now remove the relations column
      const diffRemove = diffColumns(
        [{ name: 'name', type: 'text' }, { name: 'tags', type: RELATIONS_TYPE }],
        [{ name: 'name', type: 'text' }],
      );
      const sumRemove = await applyColumnDiff(tableName, diffRemove);
      expect(sumRemove.ran).toContainEqual({ op: 'dropJoinTable', column: 'tags' });
      const probe2 = await prisma.$queryRawUnsafe(`SELECT name FROM sqlite_master WHERE type='table' AND name='${jt}'`);
      expect(probe2.length).toBe(0);
      // initialEntity is unused but kept to mirror the production code path
      void initialEntity;
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinTableName(tableName, 'tags')}"`);
      await dropIfExists(tableName);
    }
  });

  it('ensureJoinTables is idempotent + creates the reverse-lookup index', async () => {
    const tableName = uniqueName();
    const joinT = joinTableName(tableName, 'tags');
    const entity = entityWithRelations({ tableName });
    try {
      await ensureTable(entity);
      // Calling again should not throw on the duplicate index/table.
      await ensureJoinTables(entity);
      await ensureJoinTables(entity);
      const idxes = await prisma.$queryRawUnsafe(
        `SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=?`,
        joinT,
      );
      expect(idxes.some((i) => String(i.name).endsWith('_target_idx'))).toBe(true);
    } finally {
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinT}"`);
      await dropIfExists(tableName);
    }
  });

  it('buildJoinTableSQL produces idempotent CREATE TABLE IF NOT EXISTS', () => {
    const sql = buildJoinTableSQL('products', 'categories');
    expect(sql).toContain('CREATE TABLE IF NOT EXISTS "products__categories__rel"');
    expect(sql).toContain('"source_id" INTEGER NOT NULL');
    expect(sql).toContain('"target_id" INTEGER NOT NULL');
    expect(sql).toContain('PRIMARY KEY ("source_id", "target_id")');
  });
});

// Phase 4.15 follow-up — reverse cascade + target_id existence filter.
//
// These exercise behaviors that span multiple custom entities: a "source"
// entity with a relations column pointing at a "target" entity (both
// registered in the customEntities table since we walk the registry to
// find pointers).
describe('relations follow-up — reverse cascade + target_id validation', () => {
  function uniqueName(prefix) {
    return `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }

  // Each test sets up a fresh source + target entity REGISTERED in the
  // customEntities table (so reverse cascade and existence filter can
  // discover them). Tracks created codes/tableNames for cleanup.
  async function setupPair() {
    const targetTable = uniqueName('rel_tgt');
    const sourceTable = uniqueName('rel_src');
    const targetCode = `${targetTable}_e`;
    const sourceCode = `${sourceTable}_e`;

    // Create target table + register entity
    await prisma.$executeRawUnsafe(buildCreateTableSQL(targetTable, [
      { name: 'name', type: 'text', required: true },
    ]));
    await prisma.customEntity.create({
      data: {
        code: targetCode, tableName: targetTable,
        label: 'tgt', singular: 'tgt', icon: 'reports', category: 'test',
        permissionPrefix: targetCode,
        config: JSON.stringify({ columns: [{ name: 'name', type: 'text' }] }),
        isActive: true, isSystem: false,
      },
    });

    // Create source table + register entity (with relations col pointing at target)
    const sourceCols = [
      { name: 'name', type: 'text' },
      { name: 'tags', type: RELATIONS_TYPE, targetEntity: targetCode },
    ];
    await prisma.$executeRawUnsafe(buildCreateTableSQL(sourceTable, sourceCols));
    await prisma.$executeRawUnsafe(buildJoinTableSQL(sourceTable, 'tags'));
    await prisma.customEntity.create({
      data: {
        code: sourceCode, tableName: sourceTable,
        label: 'src', singular: 'src', icon: 'reports', category: 'test',
        permissionPrefix: sourceCode,
        config: JSON.stringify({ columns: sourceCols }),
        isActive: true, isSystem: false,
      },
    });

    return {
      target: { code: targetCode, tableName: targetTable, config: JSON.stringify({ columns: [{ name: 'name', type: 'text' }] }) },
      source: { code: sourceCode, tableName: sourceTable, config: JSON.stringify({ columns: sourceCols }) },
      cleanup: async () => {
        await prisma.customEntity.deleteMany({ where: { code: { in: [sourceCode, targetCode] } } }).catch(() => {});
        await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${joinTableName(sourceTable, 'tags')}"`).catch(() => {});
        await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${sourceTable}"`).catch(() => {});
        await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${targetTable}"`).catch(() => {});
      },
    };
  }

  it('filterExistingTargetIds drops IDs that don\'t exist in the target table', async () => {
    const { target, source, cleanup } = await setupPair();
    try {
      // Seed two real targets
      const tgt1 = await prisma.$executeRawUnsafe(`INSERT INTO "${target.tableName}" (name) VALUES ('a')`);
      void tgt1;
      const tgt2 = await prisma.$executeRawUnsafe(`INSERT INTO "${target.tableName}" (name) VALUES ('b')`);
      void tgt2;
      const realRows = await prisma.$queryRawUnsafe(`SELECT id FROM "${target.tableName}" ORDER BY id`);
      const realIds = realRows.map((r) => Number(r.id));
      expect(realIds).toHaveLength(2);

      // Pass real IDs + a fake one (99999) — fake should be dropped
      const filtered = await filterExistingTargetIds(target.code, [...realIds, 99999]);
      expect(filtered.sort()).toEqual(realIds.sort());

      // insertRow on source with same mix → only real ones land in the join table
      const created = await insertRow(source, { name: 'x', tags: [...realIds, 99999] });
      expect(created.tags.sort()).toEqual(realIds.sort());
    } finally {
      await cleanup();
    }
  });

  it('filterExistingTargetIds returns input unchanged when targetEntity is missing or unknown', async () => {
    // No targetEntity → passthrough
    const passthrough = await filterExistingTargetIds(undefined, [1, 2, 3]);
    expect(passthrough).toEqual([1, 2, 3]);
    // Unknown targetEntity → passthrough (don't swallow data on a config typo)
    const unknown = await filterExistingTargetIds('this_entity_does_not_exist_xyz', [1, 2, 3]);
    expect(unknown).toEqual([1, 2, 3]);
  });

  it('deleteRow on a target reverse-cascades — sources lose dangling target_ids', async () => {
    const { target, source, cleanup } = await setupPair();
    try {
      // Seed target + source rows
      await prisma.$executeRawUnsafe(`INSERT INTO "${target.tableName}" (name) VALUES ('a'),('b'),('c')`);
      const tgts = await prisma.$queryRawUnsafe(`SELECT id FROM "${target.tableName}" ORDER BY id`);
      const [t1, t2, t3] = tgts.map((r) => Number(r.id));

      // Two source rows pointing at the targets
      const s1 = await insertRow(source, { name: 's1', tags: [t1, t2] });
      const s2 = await insertRow(source, { name: 's2', tags: [t2, t3] });

      // Delete target t2 — both source rows should lose t2 from their relations
      await deleteRow(target, t2);

      const s1After = await getRow(source, s1.id);
      const s2After = await getRow(source, s2.id);
      expect(s1After.tags).toEqual([t1]);
      expect(s2After.tags).toEqual([t3]);
    } finally {
      await cleanup();
    }
  });

  it('reverseCascadeRelations is a no-op when no entity points at the deleted target', async () => {
    // Use an entity code that no one references
    const result = await reverseCascadeRelations('nobody_points_here_xyz', 1);
    expect(result.cleared).toBe(0);
  });

  it('singular `relation` columns are NULLed when the target row is deleted (symmetric with M2M)', async () => {
    // Set up source entity with a singular `relation` column pointing at target.
    const targetTable = uniqueName('rel1_tgt');
    const sourceTable = uniqueName('rel1_src');
    const targetCode = `${targetTable}_e`;
    const sourceCode = `${sourceTable}_e`;
    await prisma.$executeRawUnsafe(buildCreateTableSQL(targetTable, [{ name: 'name', type: 'text' }]));
    await prisma.customEntity.create({
      data: {
        code: targetCode, tableName: targetTable, label: 'tgt', singular: 'tgt',
        icon: 'reports', category: 'test', permissionPrefix: targetCode,
        config: JSON.stringify({ columns: [{ name: 'name', type: 'text' }] }),
        isActive: true, isSystem: false,
      },
    });
    const sourceCols = [
      { name: 'name', type: 'text' },
      { name: 'assignee', type: 'relation', targetEntity: targetCode },
    ];
    await prisma.$executeRawUnsafe(buildCreateTableSQL(sourceTable, sourceCols));
    await prisma.customEntity.create({
      data: {
        code: sourceCode, tableName: sourceTable, label: 'src', singular: 'src',
        icon: 'reports', category: 'test', permissionPrefix: sourceCode,
        config: JSON.stringify({ columns: sourceCols }),
        isActive: true, isSystem: false,
      },
    });
    const cleanup = async () => {
      await prisma.customEntity.deleteMany({ where: { code: { in: [sourceCode, targetCode] } } }).catch(() => {});
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${sourceTable}"`).catch(() => {});
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${targetTable}"`).catch(() => {});
    };
    try {
      await prisma.$executeRawUnsafe(`INSERT INTO "${targetTable}" (name) VALUES ('a'),('b')`);
      const tgts = await prisma.$queryRawUnsafe(`SELECT id FROM "${targetTable}" ORDER BY id`);
      const [t1, t2] = tgts.map((r) => Number(r.id));
      await prisma.$executeRawUnsafe(`INSERT INTO "${sourceTable}" (name, assignee) VALUES ('s1', ?)`, t1);
      await prisma.$executeRawUnsafe(`INSERT INTO "${sourceTable}" (name, assignee) VALUES ('s2', ?)`, t2);

      // Delete target t1 — s1.assignee should become NULL, s2 untouched.
      const target = await prisma.customEntity.findUnique({ where: { code: targetCode } });
      await deleteRow(target, t1);

      const rows = await prisma.$queryRawUnsafe(`SELECT name, assignee FROM "${sourceTable}" ORDER BY name`);
      expect(rows.find((r) => r.name === 's1').assignee).toBeNull();
      expect(Number(rows.find((r) => r.name === 's2').assignee)).toBe(t2);
    } finally {
      await cleanup();
    }
  });

  it('nullifyDanglingSingleRelations is a no-op when no entity has a singular relation pointing at the deleted target', async () => {
    const result = await nullifyDanglingSingleRelations('nobody_singular_xyz', 1);
    expect(result.nulled).toBe(0);
  });

  // Formula-tests need their own simple cleanup helper (the parent
  // describe's setupPair() is overkill; we just need a temp table).
  const formulaUniq = (p) => `${p}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const formulaDropIfExists = (n) => prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "${n}"`).catch(() => {});

  it('formula columns: evaluated at read time, no SQL column, immune to body writes', async () => {
    const tableName = formulaUniq('formula');
    const cols = [
      { name: 'qty', type: 'integer' },
      { name: 'price', type: 'number' },
      { name: 'subtotal', type: FORMULA_TYPE, formula: 'qty * price' },
      { name: 'with_tax', type: FORMULA_TYPE, formula: '(qty * price) * 1.1' },
    ];
    const entity = {
      code: `${tableName}_e`,
      tableName,
      config: JSON.stringify({ columns: cols }),
    };
    try {
      await ensureTable(entity);
      // Source table should NOT have subtotal/with_tax columns.
      const tableInfo = await prisma.$queryRawUnsafe(`PRAGMA table_info("${tableName}")`);
      const colNames = tableInfo.map((c) => c.name);
      expect(colNames).toContain('qty');
      expect(colNames).toContain('price');
      expect(colNames).not.toContain('subtotal');
      expect(colNames).not.toContain('with_tax');

      // Insert: caller passes formula values too; engine ignores them.
      const created = await insertRow(entity, { qty: 4, price: 2.5, subtotal: 999, with_tax: 999 });
      expect(created.qty).toBe(4);
      expect(created.price).toBe(2.5);
      expect(created.subtotal).toBe(10);
      expect(created.with_tax).toBeCloseTo(11);

      // Update: changing inputs updates the computed columns transparently.
      const updated = await updateRow(entity, created.id, { qty: 6 });
      expect(updated.subtotal).toBe(15);
      expect(updated.with_tax).toBeCloseTo(16.5);

      // listRows applies formulas page-wide.
      await insertRow(entity, { qty: 2, price: 3 });
      await insertRow(entity, { qty: 1, price: null }); // null propagates
      const result = await listRows(entity, { page: 1, pageSize: 10, search: '' });
      const named = Object.fromEntries(result.items.map((r) => [r.qty, r]));
      expect(named[6].subtotal).toBe(15);
      expect(named[2].subtotal).toBe(6);
      expect(named[1].subtotal).toBeNull(); // qty=1, price=null → null
    } finally {
      await formulaDropIfExists(tableName);
    }
  });

  it('formula columns: bad expressions yield null at read (not 500)', async () => {
    const tableName = formulaUniq('formula_bad');
    const entity = {
      code: `${tableName}_e`,
      tableName,
      config: JSON.stringify({
        columns: [
          { name: 'qty', type: 'integer' },
          { name: 'broken', type: FORMULA_TYPE, formula: 'qty * (' }, // unbalanced paren
        ],
      }),
    };
    try {
      await ensureTable(entity);
      const created = await insertRow(entity, { qty: 5 });
      expect(created.qty).toBe(5);
      expect(created.broken).toBeNull();
    } finally {
      await formulaDropIfExists(tableName);
    }
  });

  it('applyColumnDiff routes formula columns through addFormula/dropFormula (no ALTER TABLE)', async () => {
    const tableName = formulaUniq('formula_diff');
    try {
      await prisma.$executeRawUnsafe(buildCreateTableSQL(tableName, [{ name: 'name', type: 'text' }]));
      const diffAdd = diffColumns(
        [{ name: 'name', type: 'text' }],
        [{ name: 'name', type: 'text' }, { name: 'computed', type: FORMULA_TYPE, formula: '1 + 1' }],
      );
      const sumAdd = await applyColumnDiff(tableName, diffAdd);
      expect(sumAdd.ran).toContainEqual({ op: 'addFormula', column: 'computed' });
      // No SQL column was added:
      const cols = await prisma.$queryRawUnsafe(`PRAGMA table_info("${tableName}")`);
      expect(cols.map((c) => c.name)).not.toContain('computed');

      const diffRemove = diffColumns(
        [{ name: 'name', type: 'text' }, { name: 'computed', type: FORMULA_TYPE }],
        [{ name: 'name', type: 'text' }],
      );
      const sumRemove = await applyColumnDiff(tableName, diffRemove);
      expect(sumRemove.ran).toContainEqual({ op: 'dropFormula', column: 'computed' });
    } finally {
      await formulaDropIfExists(tableName);
    }
  });

  // ----- field-level permissions ----------------------------------------

  it('canViewCol / canEditCol — semantics around super-admin + missing ctx', () => {
    const open = { name: 'a', type: 'text' };
    const restrictView = { name: 'salary', type: 'number', viewPermission: 'finance.read' };
    const restrictEditOnly = { name: 'commission', type: 'number', editPermission: 'finance.write' };

    // No ctx (internal callers) → always allowed
    expect(canViewCol(restrictView, undefined)).toBe(true);
    expect(canEditCol(restrictView, undefined)).toBe(true);

    // Super-admin bypasses everything
    const sa = { isSuperAdmin: true, permissions: new Set() };
    expect(canViewCol(restrictView, sa)).toBe(true);
    expect(canEditCol(restrictView, sa)).toBe(true);

    // Non-super-admin: gate by permission set
    const has = { isSuperAdmin: false, permissions: new Set(['finance.read']) };
    const lacks = { isSuperAdmin: false, permissions: new Set([]) };
    expect(canViewCol(restrictView, has)).toBe(true);
    expect(canViewCol(restrictView, lacks)).toBe(false);

    // editPermission defaults to viewPermission when only view is set —
    // you can't edit what you can't read.
    expect(canEditCol(restrictView, lacks)).toBe(false);
    expect(canEditCol(restrictView, has)).toBe(true);

    // editPermission alone (no viewPermission): gate edits, view is open.
    expect(canViewCol(restrictEditOnly, lacks)).toBe(true);
    expect(canEditCol(restrictEditOnly, lacks)).toBe(false);

    // Open columns: always allowed.
    expect(canViewCol(open, lacks)).toBe(true);
    expect(canEditCol(open, lacks)).toBe(true);
  });

  it('listRows + getRow strip restricted columns from response (non-super-admin)', async () => {
    const tableName = formulaUniq('field_perm');
    const entity = {
      code: `${tableName}_e`,
      tableName,
      config: JSON.stringify({
        columns: [
          { name: 'name', type: 'text' },
          { name: 'salary', type: 'number', viewPermission: 'finance.read' },
        ],
      }),
    };
    try {
      await ensureTable(entity);
      const ctxAdmin = { isSuperAdmin: true, permissions: new Set() };
      await insertRow(entity, { name: 'alice', salary: 100000 }, ctxAdmin);

      // Non-super-admin without finance.read: salary stripped
      const ctxLow = { isSuperAdmin: false, permissions: new Set() };
      const fetchedLow = await getRow(entity, 1, ctxLow);
      expect(fetchedLow.name).toBe('alice');
      expect(fetchedLow.salary).toBeUndefined();

      // Non-super-admin WITH finance.read: salary visible
      const ctxFin = { isSuperAdmin: false, permissions: new Set(['finance.read']) };
      const fetchedFin = await getRow(entity, 1, ctxFin);
      expect(fetchedFin.salary).toBe(100000);

      // listRows applies the same filter page-wide.
      const listLow = await listRows(entity, { page: 1, pageSize: 10, search: '' }, ctxLow);
      expect(listLow.items[0].salary).toBeUndefined();
      const listFin = await listRows(entity, { page: 1, pageSize: 10, search: '' }, ctxFin);
      expect(listFin.items[0].salary).toBe(100000);

      // No ctx (internal): no filtering
      const internal = await getRow(entity, 1);
      expect(internal.salary).toBe(100000);
    } finally {
      await formulaDropIfExists(tableName);
    }
  });

  it('insertRow + updateRow drop body fields the caller can\'t edit', async () => {
    const tableName = formulaUniq('field_perm_write');
    const entity = {
      code: `${tableName}_e`,
      tableName,
      config: JSON.stringify({
        columns: [
          { name: 'name', type: 'text' },
          { name: 'salary', type: 'number', viewPermission: 'finance.read', editPermission: 'finance.write' },
        ],
      }),
    };
    try {
      await ensureTable(entity);
      const ctxNoFin = {
        isSuperAdmin: false,
        permissions: new Set(['finance.read']), // read OK, write not OK
      };
      // Non-super-admin tries to set salary on insert — silently dropped.
      // (Then we fetch with super-admin to verify the column truly is null.)
      const created = await insertRow(entity, { name: 'bob', salary: 999999 }, ctxNoFin);
      expect(created.name).toBe('bob');
      // Confirm via super-admin getRow (sees everything):
      const sa = { isSuperAdmin: true, permissions: new Set() };
      const verify = await getRow(entity, created.id, sa);
      expect(verify.salary).toBeNull(); // body field was filtered out

      // updateRow same — caller can't write the field.
      await updateRow(entity, created.id, { name: 'bobby', salary: 888888 }, ctxNoFin);
      const after = await getRow(entity, created.id, sa);
      expect(after.name).toBe('bobby');
      expect(after.salary).toBeNull();

      // Caller WITH write permission goes through.
      const ctxFin = {
        isSuperAdmin: false,
        permissions: new Set(['finance.read', 'finance.write']),
      };
      await updateRow(entity, created.id, { salary: 777 }, ctxFin);
      const final = await getRow(entity, created.id, sa);
      expect(final.salary).toBe(777);
    } finally {
      await formulaDropIfExists(tableName);
    }
  });

  it('reverseCascadeRelations safely handles entities with corrupt JSON config', async () => {
    const { target, cleanup } = await setupPair();
    // Plant an entity with broken config — should be skipped silently.
    const brokenCode = uniqueName('rel_broken') + '_e';
    const brokenTable = uniqueName('rel_broken_t');
    await prisma.customEntity.create({
      data: {
        code: brokenCode, tableName: brokenTable,
        label: 'broken', singular: 'broken', icon: 'reports', category: 'test',
        permissionPrefix: brokenCode,
        config: 'this is not valid json {{{',
        isActive: true, isSystem: false,
      },
    });
    try {
      const result = await reverseCascadeRelations(target.code, 999);
      // Doesn't throw, returns a count (0 since no real refs to delete).
      expect(result.cleared).toBeGreaterThanOrEqual(0);
    } finally {
      await prisma.customEntity.delete({ where: { code: brokenCode } }).catch(() => {});
      await cleanup();
    }
  });
});
