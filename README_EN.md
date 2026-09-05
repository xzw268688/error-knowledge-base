# Error Knowledge Base (error-knowledge-base)

> Manage personal/project error-resolution experience: search historical solutions for similar errors, record newly resolved issues.

## Features

- **When encountering an error**: Automatically search the knowledge base and return solution steps for similar errors
- **After solving an error**: Automatically detect "error resolved" signals and suggest recording it to the knowledge base
- **Semantic matching**: Understands errors that are essentially the same but described differently
- **Structured records**: Error information is stored as markdown files in a consistent format

## Installation (Claude Code)

Clone this repository, then copy the `error-knowledge-base/` directory to one of the following locations:

| Installation | Location | Scope |
|--------------|----------|-------|
| **Global** | `~/.claude/skills/` | All projects |
| **Project** | `项目/.claude/skills/` | Current project only |

> **Note**: On first use, the skill will ask you to configure your knowledge base location. It's recommended to set it to another drive (e.g., D: drive) to reduce C drive pressure and enable portability and cross-project reuse. Defaults to `~/.claude/knowledge-base/`.

## Usage (Claude Code)

### Query historical errors

When you describe an error in a conversation (e.g., "Got an ERESOLVE error during npm install"), the Skill automatically searches the knowledge base and returns similar resolution records.

### Record new errors

When the conversation contains error-resolved signals (e.g., "Fixed it", "Problem resolved"), the Skill will prompt: "Would you like to record this error to the knowledge base?"

## Knowledge Base Format

Each time an error is saved, the skill displays the full storage path (default: `~/.claude/knowledge-base/`), with one markdown file per error:

```
~/.claude/knowledge-base/
├── 2026-09-05-npm-eresolve.md
├── 2026-09-03-python-oom.md
└── ...
```

Each record automatically generates a structured markdown file:

```yaml
---
title: npm Dependency Conflict
error_type: ERESOLVE
tags: [npm, dependency-conflict]
files: [package.json]
---
## Solution Steps
...
```

## Contributing

Feel free to submit your error records to help others avoid common pitfalls.

## License

See [LICENSE](LICENSE).
