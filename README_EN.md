# Error Knowledge Base Skill (error-knowledge-base)

English | [简体中文](README.md)

> Manage your error-resolution experience: search historical solutions for similar errors, record newly solved problems.

💡 **Tip**: Just say "fixed it" after solving an error and the Skill will ask whether to record it. You can also type `/error-knowledge-base` to trigger it manually.

**Key Features**:
- **Zero-config migration** — Stateless indexing, dynamic scan on each retrieval
- **Keyword weighting + LLM semantic reranking** — Keywords only affect ordering, never block recall
- **Duplicate detection** — Auto-prompt on suspected duplicates during recording
- **Status flag** — Records can be marked verified / deprecated

---

## What Problem It Solves

Errors in development tend to repeat:

- The npm ERESOLVE conflict you fixed today shows up again next week in a different project
- The same Docker port conflicts, database connection pool exhaustion, memory leaks
- Every time you need to search Stack Overflow or dig through chat history
- Agents keep exploring the same errors from scratch

This Skill turns your error-resolution experience into a searchable knowledge base:

- **When encountering an error**: Auto-search historical solutions to avoid repeating mistakes
- **After solving**: Proactively asks whether to record, forming a closed loop
- **Agent self-discovery**: When Agent solves a new error independently, proactively prompts to record

---

## Core Principles

1. **On-demand trigger**: Skill only acts when you mention errors, doesn't run in background
2. **Zero-input record**: Just say "fixed it" after solving — the Skill extracts the details and asks whether to record (or invoke `/error-knowledge-base` directly)
3. **Agent collaboration**: Agent can discover and solve new errors independently, then record
4. **Privacy protection**: By default doesn't read local data unless user explicitly requests

---

## Installation

```bash
# Clone and install
git clone https://github.com/xzw268688/error-knowledge-base.git
cd error-knowledge-base

# macOS / Linux
bash install.sh

# Windows (PowerShell)
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

Already installed? Add `--force` (sh) or `-Force` (ps1) to reinstall.

---

## Verify Installation

```bash
# Check if skill is installed correctly
ls ~/.claude/skills/error-knowledge-base/
# Should see: SKILL.md
```

### Quick Check (recommended)

The repo ships with 8 sample records. Copy them into your knowledge base path to see the skill work immediately:

```bash
# macOS / Linux
cp examples/knowledge-base/*.md ~/.claude/knowledge-base/

# Windows (PowerShell)
Copy-Item examples\knowledge-base\*.md $env:USERPROFILE\.claude\knowledge-base\
```

Then ask a question phrased **completely differently** from the samples to verify semantic retrieval:

```
memory blew up, what do I do
```

It should hit both the Python `MemoryError` and the JVM `OOMKilled` records —
even though not a single word in your input literally matches their `search_keywords`.

Delete the copied files when you're done.

---

## First Use Configuration

**Step 1: Configure Knowledge Base Path**

On first use of the skill, you'll be prompted for the knowledge base storage location. You can also configure manually in advance:

```json
// ~/.claude/error-knowledge-base-config.json
{
  "knowledge_base_path": "~/.claude/knowledge-base/"
}
```

**Path Priority**:
1. Config file `~/.claude/error-knowledge-base-config.json` (highest priority)
2. Environment variable `ERROR_KB_PATH`
3. Default `~/.claude/knowledge-base/`

**Migration Guide**:
- Simply copy the entire knowledge base folder to any location
- Update `knowledge_base_path` in the config file
- Restart Claude Code
- **No index rebuild needed** — Dynamic scan on each retrieval, stateless design

---

## Usage

### Scenario 1: Search Errors

Just describe the issue:
```
npm install failing with ERESOLVE error
```

The skill will search the knowledge base and return similar records with solutions.

### Scenario 2: Agent Self-Discovery

When Agent encounters unknown errors during task execution and solves them:
```
Agent: I just solved a new error, want to record it?
       [Confirm] [Skip] [Not now]
```

### Scenario 3: Record After Solving

After solving, say:
```
Fixed it, used --legacy-peer-deps
```

The skill will extract information and prompt for confirmation.

### View Records

```
Show my error records
```

### View Stats

```
Knowledge base stats
```

Prints total records, active/deprecated split, records added in the last 30 days, plus breakdowns by month, top 10 tags, and top 10 error types.

---

## Matching Strategy

- **Semantic understanding as primary** + structured fields (tags, error_type) for auxiliary ranking
- Covers fuzzy matching (e.g., "OOM" vs "Out of Memory")
- **Keywords only affect ordering, they never gate recall**: matching on `search_keywords`, `tags`, or `error_type`
  decides a record's **rank**, not whether it can be retrieved at all. A record scoring zero on every keyword
  is still handed to the LLM reranker — an earlier version treated keyword matching as a recall gate,
  which made the semantic layer unreachable. Now fixed
- Records with `status: deprecated` are excluded from retrieval but kept as historical reference

---

## Migration & Portability

**Zero-config migration**:
1. Copy the entire `{knowledge_base_path}` folder to any location
2. Update `knowledge_base_path` in the config file
3. Restart Claude Code

**No index rebuild needed** — Dynamic scan of the knowledge base directory on each retrieval, stateless design.

---

## Troubleshooting

### Issue 1: No configuration wizard on first use

**Possible causes**:
1. Skill not properly installed — Run `ls ~/.claude/skills/error-knowledge-base/` to check
2. Config file already exists — Check if `~/.claude/error-knowledge-base-config.json` exists

### Issue 2: No records found in search

**Possible causes**:
1. Incorrect knowledge base path — Verify the configured path exists
2. Empty knowledge base — Copy `examples/knowledge-base/*.md` into your knowledge base path for a quick check
3. New records missing `search_keywords` — doesn't block recall, but ranks lower
4. All records marked `status: deprecated` — you'll get "no valid records in the knowledge base"

### Issue 3: Not working after migration

**Solution**:
1. Confirm `.md` files exist in new path — `ls {new_path}/`
2. Check if config file path was updated — `cat ~/.claude/error-knowledge-base-config.json`
3. Restart Claude Code to refresh environment

### Issue 4: Suspected duplicate record detected

This is expected behavior. The system will remind you of potential duplicates:
- **[Confirm create]** — It's indeed a new scenario
- **[Cancel]** — Duplicate of existing record
- **[View old record]** — Check if the existing solution works first

---

## File Format

Each record is a markdown file:

```yaml
---
title: "npm dependency conflict"
date: "2026-09-05"
tags: ["npm", "peer-dependencies"]
error_type: "ERESOLVE"
files: ["package.json"]
search_keywords: ["npm install", "eresolve", "peer dependency", "--legacy-peer-deps"]
draft: false
status: "verified"   # verified | draft | deprecated
---

# Error Phenomenon
...

# Solution Steps
...

# Root Cause Analysis (optional)
...
```

File naming rule: `YYYY-MM-DD-error-slug.md` (date + short error description)

---

## Directory Structure

```
Repository/
├── error-knowledge-base/
│   └── SKILL.md                  # skill main file (skill package)
├── examples/
│   └── knowledge-base/           # sample records for a quick check
├── README.md                     # Chinese documentation
├── README_EN.md                  # English documentation
└── CLAUDE.md                     # Requirements doc (for development)

User local/
├── ~/.claude/skills/error-knowledge-base/   # skill installation location
└── {knowledge_base_path}/                   # knowledge base data
    ├── 2026-09-05-npm-eresolve.md
    ├── 2026-09-03-python-oom.md
    └── ...
```

---

## Related Files

- `error-knowledge-base/SKILL.md` - Skill implementation details
- `CLAUDE.md` - Requirements doc
- `README.md` - Chinese documentation
