// Runs the Omarchy marketplace's Automated Security Baseline against a local checkout, before
// submitting, by serving the scanner the GitHub API and raw-file responses it expects from `git`.
//
//   git clone --depth 1 https://github.com/omacom/omarchy-plugin-marketplace /tmp/marketplace
//   node tests/marketplace-baseline.mjs /tmp/marketplace [repo-dir] [owner/name]
//
// Scans HEAD of the repository (default: the parent of this file) under the given GitHub name
// (default: dreamsgarage/OmarCraft). Prints the bot's report, then a machine summary. Node >= 24.
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const MARKETPLACE = process.argv[2];
if (!MARKETPLACE) {
  console.error("usage: node tests/marketplace-baseline.mjs <marketplace-checkout> [repo-dir] [owner/name]");
  process.exit(2);
}
const { runSecurityBaseline, verifiedPublicationDisposition, buildSecurityBaselineReport } =
  await import(pathToFileURL(resolve(MARKETPLACE, "scripts/security-baseline.mjs")).href);

const REPO = process.argv[3] || resolve(dirname(fileURLToPath(import.meta.url)), "..");
const [owner, name] = (process.argv[4] || "dreamsgarage/OmarCraft").split("/");
const sha = execFileSync("git", ["-C", REPO, "rev-parse", "HEAD"]).toString().trim();
const treeSha = execFileSync("git", ["-C", REPO, "rev-parse", "HEAD^{tree}"]).toString().trim();
const tree = execFileSync("git", ["-C", REPO, "ls-tree", "-r", "-l", "HEAD"]).toString().trim().split("\n").map((line) => {
  const m = line.match(/^(\d{6}) (\w+) ([0-9a-f]{40}) +(\d+|-)\t(.*)$/);
  return { mode: m[1], type: m[2], sha: m[3], size: m[4] === "-" ? 0 : Number(m[4]), path: m[5] };
});
const blob = (path) => execFileSync("git", ["-C", REPO, "show", `HEAD:${path}`], { maxBuffer: 64 * 1024 * 1024 });

async function fetchImpl(url, options = {}) {
  const u = new URL(url);
  const json = (obj) => new Response(JSON.stringify(obj), { status: 200, headers: { "content-type": "application/json" } });
  if (u.hostname === "api.github.com") {
    if (u.pathname === `/repos/${owner}/${name}`) return json({ private: false, disabled: false, archived: false, default_branch: "main" });
    if (u.pathname === `/repos/${owner}/${name}/commits/${sha}`) return json({ sha, commit: { tree: { sha: treeSha } } });
    if (u.pathname === `/repos/${owner}/${name}/git/trees/${treeSha}`) return json({ truncated: false, tree });
    return new Response("not found", { status: 404 });
  }
  if (u.hostname === "raw.githubusercontent.com") {
    const prefix = `/${owner}/${name}/${sha}/`;
    if (!u.pathname.startsWith(prefix)) return new Response("nf", { status: 404 });
    const path = decodeURIComponent(u.pathname.slice(prefix.length));
    const data = blob(path);
    const range = options.headers?.Range;
    if (range) {
      const m = range.match(/^bytes=0-(\d+)$/);
      const end = Math.min(Number(m[1]), data.length - 1);
      return new Response(data.subarray(0, end + 1), { status: 206, headers: { "content-range": `bytes 0-${end}/${data.length}` } });
    }
    return new Response(data, { status: 200 });
  }
  return new Response("blocked", { status: 500 });
}

const result = await runSecurityBaseline(`https://github.com/${owner}/${name}`, sha, {
  fetchImpl,
  requiredPaths: Object.values(JSON.parse(blob("manifest.json")).entryPoints || {}),
  listedPlugins: [{ pluginId: JSON.parse(blob("manifest.json")).id, manifestPathHint: "manifest.json" }],
});
process.stdout.write(buildSecurityBaselineReport(result, { context: "submission" }));
console.log("\n=== machine summary");
console.log(JSON.stringify({
  commit: sha, outcome: result.outcome, enforcement: result.enforcementMode ?? result.enforcement,
  findings: (result.findings || []).map((f) => f.ruleId || f.id),
  capabilities: (result.capabilities || []).map((c) => ({ id: c.id, evidence: (c.evidence || []).map((e) => `${e.path}:${e.line} ${e.snippet}`) })),
  scannedFiles: result.scannedFiles ?? result.files?.length ?? result.scope?.files,
  disposition: verifiedPublicationDisposition(result),
}, null, 2));
