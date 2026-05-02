-- Phase 4.16 follow-up — TOTP 2FA + recovery codes.
ALTER TABLE "User" ADD COLUMN "totpSecret" TEXT;
ALTER TABLE "User" ADD COLUMN "totpEnabledAt" DATETIME;

CREATE TABLE "RecoveryCode" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "userId" INTEGER NOT NULL,
  "codeHash" TEXT NOT NULL,
  "usedAt" DATETIME,
  "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RecoveryCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "RecoveryCode_codeHash_key" ON "RecoveryCode"("codeHash");
CREATE INDEX "RecoveryCode_userId_idx" ON "RecoveryCode"("userId");
