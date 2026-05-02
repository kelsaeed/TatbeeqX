# 34 — Page-builder analytics

A tiny endpoint that summarizes how the page builder is being used: how many pages, how many blocks, the type-frequency histogram, and which pages have no blocks yet. Surfaced as an info panel at the top of `/pages`.

- Endpoint: `GET /api/pages/analytics` (gated on `pages.view`)
- Backend: [`backend/src/routes/pages.js`](../backend/src/routes/pages.js)
- UI: panel rendered by `_buildAnalyticsPanel(...)` in [`features/pages/presentation/pages_page.dart`](../frontend/lib/features/pages/presentation/pages_page.dart)

## Response shape

```json
{
  "pageCount": 7,
  "blockCount": 42,
  "blocksPerPage": 6.0,
  "byType": [
    { "type": "card",     "count": 14 },
    { "type": "text",     "count": 9 },
    { "type": "button",   "count": 6 },
    { "type": "report",   "count": 5 },
    { "type": "html",     "count": 3 }
  ],
  "emptyPages": [
    { "id": 12, "code": "drafts_q3", "title": "Q3 drafts", "route": "/drafts" }
  ]
}
```

- `pageCount` / `blockCount` — raw totals.
- `blocksPerPage` — `blockCount / pageCount` (zero when there are no pages).
- `byType` — Prisma `groupBy` over `pageBlock.type`, ordered by count desc.
- `emptyPages` — `Page.findMany({ where: { blocks: { none: {} } } })`.

## What it's good for

- **Spotting unused block types** — if `iframe` and `html` show up zero times across all installs, you can deprecate them.
- **Finding orphan pages** — `emptyPages` lets the user clean up half-finished drafts.
- **Sanity check after an import** — apply a Templates-v2 `pages` snapshot and reload; analytics confirms the count.

## Permissions

The endpoint reuses `pages.view` because anyone allowed to see the page list deserves to see the summary. The UI gracefully degrades (the panel is hidden) if the call fails — so users without `pages.view` don't get a broken page header.

## Performance

`groupBy` on `page_blocks.type` is indexed indirectly via the `pageId` index (every block has a `pageId`); on installs with hundreds of blocks the call is sub-millisecond. If a deployment has ten thousand+ blocks, the call still runs in ~10–20 ms on SQLite — acceptable for a once-per-page-open panel.
