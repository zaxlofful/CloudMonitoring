const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function listJsFiles(dir) {
  const out = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listJsFiles(fullPath));
    else if (entry.isFile() && fullPath.endsWith('.js')) out.push(fullPath);
  }
  return out;
}

const repoRoot = path.resolve(__dirname, '..');
const srcDir = path.join(repoRoot, 'src');

for (const filePath of listJsFiles(srcDir)) {
  execFileSync(process.execPath, ['--check', filePath], { stdio: 'inherit' });
}

