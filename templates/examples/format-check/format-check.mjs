// Example format check for .githooks/format-check (see that file). Checks each staged file's
// STAGED content with this repo's own prettier, in one process.
//
// Staged content, not the file on disk: on Windows with core.autocrlf the disk copy is CRLF while
// the commit (and CI's checkout) is LF, and a file fixed on disk but not re-staged would pass here
// and fail CI. One process through prettier's API, not `prettier --stdin-filepath` per file, which
// costs a node start-up per file.
//
// Matches `prettier --check .` as closely as the API allows: the same ignore files (prettier 3
// also reads .gitignore), .editorconfig, and per-path config. Targets npm/pnpm installs; Yarn
// Plug'n'Play has no node_modules, so prettier reads as not installed here.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

let prettier;
try {
  const mod = await import("prettier");
  prettier = mod.default ?? mod;
} catch (e) {
  if (e?.code !== "ERR_MODULE_NOT_FOUND" && e?.code !== "MODULE_NOT_FOUND")
    throw e;
  console.log(
    "WARNING: prettier is not installed (run 'npm install') -- skipping the local format check.",
  );
  console.log("CI's format check still runs against your push.");
  process.exit(0);
}

const major = Number(String(prettier.version).split(".")[0]);
const ignorePath =
  major >= 3 ? [".gitignore", ".prettierignore"] : ".prettierignore";
const paths = readFileSync(0).toString("utf8").split("\0").filter(Boolean);

// Staged blobs for every path in two git calls. git honours GIT_INDEX_FILE, which `commit -a` and
// `commit -- <path>` point at a temporary index, so this reads what is actually being committed.
const maxBuffer = 1024 * 1024 * 1024;
const blobOf = new Map();
const staged = execFileSync("git", ["ls-files", "--stage", "-z"], {
  maxBuffer,
});
for (const rec of staged.toString("utf8").split("\0")) {
  const tab = rec.indexOf("\t");
  if (tab > 0) blobOf.set(rec.slice(tab + 1), rec.slice(0, tab).split(" ")[1]);
}

const toCheck = [];
const unparsable = [];
for (const p of paths) {
  const info = await prettier.getFileInfo(p, {
    ignorePath,
    resolveConfig: true,
  });
  if (info.ignored || !info.inferredParser) continue;
  if (blobOf.has(p)) toCheck.push(p);
  else unparsable.push(`${p}: not found in the index`);
}
const want = toCheck.map((p) => blobOf.get(p));
const batch = want.length
  ? execFileSync("git", ["cat-file", "--batch"], {
      input: want.join("\n") + "\n",
      maxBuffer,
    })
  : Buffer.alloc(0);

// --batch output per object: "<sha> blob <size>\n<content>\n".
const content = new Map();
let at = 0;
for (const p of toCheck) {
  const eol = batch.indexOf(10, at);
  const size = Number(batch.subarray(at, eol).toString().split(" ")[2]);
  content.set(p, batch.subarray(eol + 1, eol + 1 + size).toString("utf8"));
  at = eol + 1 + size + 1;
}

const unformatted = [];
for (const p of toCheck) {
  const options = {
    ...((await prettier.resolveConfig(p, { editorconfig: true })) ?? {}),
    filepath: p,
  };
  try {
    if (!(await prettier.check(content.get(p), options))) unformatted.push(p);
  } catch (e) {
    unparsable.push(`${p}: ${String(e?.message ?? e).split("\n")[0]}`);
  }
}

for (const line of unparsable)
  console.log(`ERROR: prettier could not parse ${line}`);
if (unformatted.length) {
  console.log(
    "ERROR: these staged files are not formatted (checked as staged, not as on disk):",
  );
  for (const p of unformatted) console.log(`    ${p}`);
  console.log(
    "Format them with prettier (e.g. npx prettier --write <file>), re-stage, and commit again.",
  );
}
process.exit(unformatted.length || unparsable.length ? 1 : 0);
