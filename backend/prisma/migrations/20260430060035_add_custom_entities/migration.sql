-- CreateTable
CREATE TABLE "CustomEntity" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "code" TEXT NOT NULL,
    "tableName" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "singular" TEXT NOT NULL,
    "icon" TEXT,
    "category" TEXT NOT NULL DEFAULT 'custom',
    "permissionPrefix" TEXT NOT NULL,
    "config" TEXT NOT NULL,
    "isSystem" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "SavedQuery" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "sql" TEXT NOT NULL,
    "isReadOnly" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateIndex
CREATE UNIQUE INDEX "CustomEntity_code_key" ON "CustomEntity"("code");

-- CreateIndex
CREATE UNIQUE INDEX "CustomEntity_tableName_key" ON "CustomEntity"("tableName");

-- CreateIndex
CREATE INDEX "CustomEntity_category_idx" ON "CustomEntity"("category");
