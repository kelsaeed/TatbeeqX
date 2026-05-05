// Phase 4.20 — extracted because two routes now serialize Theme rows:
//   - routes/themes.js (per-theme + active-theme endpoints)
//   - routes/boot.js   (pre-auth bundle that includes the active theme)

export function parseTheme(t) {
  let data = {};
  try {
    data = t.data ? JSON.parse(t.data) : {};
  } catch {
    data = {};
  }
  return {
    id: t.id,
    companyId: t.companyId,
    name: t.name,
    isDefault: t.isDefault,
    isActive: t.isActive,
    data,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  };
}
