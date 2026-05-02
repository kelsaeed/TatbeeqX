-- Phase 4.16 follow-up — admin-token password reset (no SMTP).
CREATE TABLE "PasswordResetToken" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "userId" INTEGER NOT NULL,
  "tokenHash" TEXT NOT NULL,
  "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expiresAt" DATETIME NOT NULL,
  "usedAt" DATETIME,
  "createdBy" INTEGER,
  "ip" TEXT,
  CONSTRAINT "PasswordResetToken_userId_fkey"    FOREIGN KEY ("userId")    REFERENCES "User" ("id") ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT "PasswordResetToken_createdBy_fkey" FOREIGN KEY ("createdBy") REFERENCES "User" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "PasswordResetToken_tokenHash_key" ON "PasswordResetToken"("tokenHash");
CREATE INDEX "PasswordResetToken_userId_idx" ON "PasswordResetToken"("userId");
CREATE INDEX "PasswordResetToken_expiresAt_idx" ON "PasswordResetToken"("expiresAt");
