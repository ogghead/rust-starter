---
name: team
description: Spin up an agent team with specialized software engineering roles to work on a task in parallel. Use when the user wants collaborative multi-agent work.
disable-model-invocation: false
user-invocable: true
argument-hint: [task description]
---

# Agent Team Skill

You MUST create an agent team and spawn teammates to work on the given task. Follow these phases exactly.

## Phase 0: Gather Context

Before creating the team, gather the project context that all teammates will need:

1. Read CLAUDE.md (project root and any subdirectories) for conventions, build commands, and architecture notes.
2. Identify the language, framework, and key patterns in the affected area.
3. Note the build command, test command, and lint command.
4. Summarize this as a **project brief** (10-20 lines max) that will be included in every teammate's prompt.

## Phase 1: Create the Team

Use the `TeamCreate` tool to create a team:
- `team_name`: derive a short kebab-case name from the task (e.g., "person-model-migration")
- `description`: the user's task description
- `agent_type`: "team-lead"

## Phase 2: Analyze and Plan

Before spawning teammates, determine:
- Which roles are needed — **spawn the minimum needed, typically 2-5 agents**. Not every task needs all roles.
- What files/areas each role will own (no two agents edit the same file).
- A phased execution plan with dependencies.

Use `TaskCreate` to break the work into discrete tasks. Include:
- Clear acceptance criteria in each task description
- Dependencies between tasks (use `addBlockedBy` via `TaskUpdate`)
- Task owner set to the teammate name that will do the work

## Phase 3: Research & Architecture (parallel)

Spawn research and architecture agents first. Wait for their results before spawning implementation agents.

These agents **gather context and produce plans** — they do not edit production code.

| Role | `subagent_type` | Purpose |
|---|---|---|
| researcher | `feature-dev:code-explorer` | Explore codebase, trace execution paths, map dependencies, find patterns |
| architect | `feature-dev:code-architect` | Design the approach, produce an implementation blueprint with specific files/changes |

Once these agents report back, update the task list with their findings and refine the implementation plan.

## Phase 4: Implementation (parallel)

Spawn implementation agents with the research/architecture findings included in their prompts. Use `isolation: "worktree"` when multiple agents edit files to prevent conflicts.

| Role | `subagent_type` | Purpose |
|---|---|---|
| backend | `general-purpose` | Server-side code: models, APIs, database logic, server functions |
| frontend | `general-purpose` | UI components, client-side logic, styling, user interactions |
| devops | `general-purpose` | Build config, CI/CD, dependency management, deployment |

## Phase 5: Verification (after implementation completes)

Spawn verification agents to validate the combined output.

| Role | `subagent_type` | Purpose |
|---|---|---|
| tester | `general-purpose` | Write tests, run build/lint/test, validate end-to-end |
| reviewer | `feature-dev:code-reviewer` | Review for bugs, security issues, adherence to conventions |

## Phase 6: Integration & Cleanup

As team lead, you handle integration yourself:

1. **Merge worktrees**: If agents used worktree isolation, review and merge their branches.
2. **Wire things together**: Update imports, module registrations, route definitions — anything that connects the pieces.
3. **Run full verification**: Execute the project's build, lint, and test commands to confirm everything works together.
4. **Resolve conflicts**: If agent outputs conflict, fix them based on the architect's plan.
5. **Report to user**: Summarize what changed, what was verified, and any open items.
6. **Shutdown teammates**: Send `{type: "shutdown_request"}` to all teammates via `SendMessage`.
7. **Delete team**: Use `TeamDelete` to clean up team and task directories.

## Writing Teammate Prompts

Every teammate prompt MUST include:

1. **Project brief** (from Phase 0): language, framework, conventions, build/test commands.
2. **Task description**: What specifically to do, with acceptance criteria.
3. **File ownership**: Exact files this agent may edit. Files not listed are read-only.
4. **Relevant context**: Findings from research/architect agents (for implementation agents), or file paths to review (for verification agents).
5. **Team coordination**: The team name (so they can access the shared task list) and instructions to mark tasks complete via `TaskUpdate` when done.

Do NOT assume teammates have any context from your conversation. Brief them like a colleague who just joined the project.

## Model Selection

**Always use `model: "opus"` for all teammates.** Every agent — whether researching, implementing, or reviewing — must run on Opus or better. Do not downgrade agents to cheaper models.

## Error Recovery

When a teammate fails or gets stuck:

1. **Read their output** — understand what went wrong before acting.
2. **If the task is partially done**: spawn a new agent to complete the remaining work, including what was already accomplished in the prompt.
3. **If the task produced bad output**: mark the task as failed, update the plan, and reassign to a new agent with corrected instructions.
4. **If a worktree has conflicts**: resolve them yourself as team lead rather than spawning another agent.
5. **If blocked on a dependency**: check if the blocking task is actually done but not marked complete, or if the dependency can be removed.

## Rules

- **Minimize team size**: Spawn only the roles the task actually needs. A 2-agent team that finishes cleanly beats a 6-agent team with coordination overhead.
- **Avoid file conflicts**: Never assign two teammates to edit the same file. Use `isolation: "worktree"` when agents work on overlapping areas. If two roles must touch the same file, make one depend on the other.
- **Phased execution**: Always run research/architecture before implementation, and implementation before verification. Do not spawn all agents at once.
- **Provide full context**: Teammates don't inherit your conversation. Every prompt must be self-contained with all relevant context.
- **Keep the user informed**: Provide brief status updates at phase transitions. Don't narrate every message.
- **Clean up**: Always use `TeamDelete` when work is complete. Don't leave stale team directories.

## Task Description

$ARGUMENTS
