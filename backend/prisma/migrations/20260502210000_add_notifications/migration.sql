-- Phase 4.18 — in-app notifications.

CREATE TABLE "Notification" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "userId" INTEGER NOT NULL,
  "kind" TEXT NOT NULL DEFAULT 'system',
  "title" TEXT NOT NULL,
  "body" TEXT,
  "link" TEXT,
  "readAt" DATETIME,
  "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "Notification_userId_readAt_idx" ON "Notification"("userId", "readAt");
CREATE INDEX "Notification_userId_createdAt_idx" ON "Notification"("userId", "createdAt");
