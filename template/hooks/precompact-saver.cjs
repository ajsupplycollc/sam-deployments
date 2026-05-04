#!/usr/bin/env node
// SAM Client — Pre-compaction state saver
// Snapshots current state before context compaction so nothing is lost
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const home = process.env.HOME || process.env.USERPROFILE;
const snapshotDir = path.join(home, '.sam', 'snapshots');
const latestPath = path.join(snapshotDir, 'LATEST.md');

try {
  fs.mkdirSync(snapshotDir, { recursive: true });

  const now = new Date();
  const timestamp = now.toISOString().replace(/[:.]/g, '-');
  const dateStr = now.toLocaleDateString('en-US', {
    timeZone: 'America/New_York',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit'
  });

  let gitState = 'No git repo';
  try {
    const branch = execSync('git branch --show-current 2>/dev/null', { encoding: 'utf8' }).trim();
    const status = execSync('git status --short 2>/dev/null', { encoding: 'utf8' }).trim();
    gitState = `Branch: ${branch}\n${status || '(clean)'}`;
  } catch (e) {}

  const snapshot = `# Pre-Compaction Snapshot — ${dateStr}

## State at compaction
${gitState}

## Working directory
${process.cwd()}

## Note
This snapshot was auto-saved before context compaction. Read this file to restore context after compaction.
`;

  fs.writeFileSync(latestPath, snapshot);
  fs.writeFileSync(path.join(snapshotDir, `${timestamp}.md`), snapshot);

  // Keep only last 10 snapshots
  const files = fs.readdirSync(snapshotDir)
    .filter(f => f !== 'LATEST.md' && f.endsWith('.md'))
    .sort()
    .reverse();

  files.slice(10).forEach(f => {
    try { fs.unlinkSync(path.join(snapshotDir, f)); } catch (e) {}
  });

} catch (err) {
  // Silent fail — never block compaction
}
