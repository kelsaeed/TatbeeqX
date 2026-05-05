// Phase 4.20 — extracted because /api/pages/sidebar AND the /auth/me
// boot bundle now both serialize Page rows. Same pattern as theme_parse
// and menu_payload.

export function parsePage(p) {
  let data = {};
  let titles = {};
  try { data = p.data ? JSON.parse(p.data) : {}; } catch { data = {}; }
  try { titles = p.titles ? JSON.parse(p.titles) : {}; } catch { titles = {}; }
  return { ...p, data, titles };
}
