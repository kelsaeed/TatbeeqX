-- Phase 4.16 follow-up — refresh-token rotation with reuse detection.
CREATE TABLE "RefreshToken" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "jti" TEXT NOT NULL,
  "userId" INTEGER NOT NULL,
  "issuedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expiresAt" DATETIME NOT NULL,
  "revokedAt" DATETIME,
  "replacedById" INTEGER,
  "userAgent" TEXT,
  "ip" TEXT,
  CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "RefreshToken_replacedById_fkey" FOREIGN KEY ("replacedById") REFERENCES "RefreshToken" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "RefreshToken_jti_key" ON "RefreshToken"("jti");
CREATE UNIQUE INDEX "RefreshToken_replacedById_key" ON "RefreshToken"("replacedById");
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");
CREATE INDEX "RefreshToken_expiresAt_idx" ON "RefreshToken"("expiresAt");
