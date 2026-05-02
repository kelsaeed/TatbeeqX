-- Phase 4.17 — workflow engine.

CREATE TABLE "Workflow" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "triggerType" TEXT NOT NULL,
  "triggerConfig" TEXT NOT NULL DEFAULT '{}',
  "actions" TEXT NOT NULL DEFAULT '[]',
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "nextRunAt" DATETIME,
  "lastRunAt" DATETIME,
  "lockedBy" TEXT,
  "lockedAt" DATETIME,
  "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" DATETIME NOT NULL
);

CREATE UNIQUE INDEX "Workflow_code_key" ON "Workflow"("code");
CREATE INDEX "Workflow_triggerType_idx" ON "Workflow"("triggerType");
CREATE INDEX "Workflow_enabled_idx" ON "Workflow"("enabled");
CREATE INDEX "Workflow_nextRunAt_idx" ON "Workflow"("nextRunAt");
CREATE INDEX "Workflow_lockedAt_idx" ON "Workflow"("lockedAt");

CREATE TABLE "WorkflowRun" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "workflowId" INTEGER NOT NULL,
  "triggerEvent" TEXT NOT NULL,
  "triggerPayload" TEXT,
  "status" TEXT NOT NULL,
  "startedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finishedAt" DATETIME,
  "error" TEXT,
  CONSTRAINT "WorkflowRun_workflowId_fkey" FOREIGN KEY ("workflowId") REFERENCES "Workflow"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "WorkflowRun_workflowId_idx" ON "WorkflowRun"("workflowId");
CREATE INDEX "WorkflowRun_status_idx" ON "WorkflowRun"("status");
CREATE INDEX "WorkflowRun_startedAt_idx" ON "WorkflowRun"("startedAt");

CREATE TABLE "WorkflowRunStep" (
  "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  "runId" INTEGER NOT NULL,
  "index" INTEGER NOT NULL,
  "actionType" TEXT NOT NULL,
  "actionName" TEXT,
  "status" TEXT NOT NULL,
  "result" TEXT,
  "error" TEXT,
  "startedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finishedAt" DATETIME,
  CONSTRAINT "WorkflowRunStep_runId_fkey" FOREIGN KEY ("runId") REFERENCES "WorkflowRun"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "WorkflowRunStep_runId_idx" ON "WorkflowRunStep"("runId");
