---
description: Document codebase as-is with comprehensive research
model: opus
---

# Research Codebase

You are tasked with conducting comprehensive research across the codebase to answer user questions by spawning parallel sub-agents and synthesizing their findings.

## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN THE CODEBASE AS IT EXISTS TODAY

- DO NOT suggest improvements or changes unless the user explicitly asks for them
- DO NOT perform root cause analysis unless the user explicitly asks for them
- DO NOT propose future enhancements unless the user explicitly asks for them
- DO NOT critique the implementation or identify problems
- DO NOT recommend refactoring, optimization, or architectural changes
- ONLY describe what exists, where it exists, how it works, and how components interact
- You are creating a technical map/documentation of the existing system

## Initial Setup:

When this command is invoked, respond with:

```
I'm ready to research the codebase. Please provide your research question or area of interest, and I'll analyze it thoroughly by exploring relevant components and connections.
```

Then wait for the user's research query.

## Steps to follow after receiving the research query:

1. **Read any directly mentioned files first:**
   - If the user mentions specific files (docs, configs, TOML, JSON), read them FULLY first
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: Read these files yourself in the main context before spawning any sub-tasks
   - This ensures you have full context before decomposing the research

2. **Analyze and decompose the research question:**
   - Break down the user's query into composable research areas
   - Take time to ultrathink about the underlying patterns, connections, and architectural implications the user might be seeking
   - Identify specific components, patterns, or concepts to investigate
   - Create a research plan using TodoWrite to track all subtasks
   - Consider which directories, files, or architectural patterns are relevant
   - Pay special attention to Rust-specific structures: crates, modules, traits, impls, derive macros, feature flags

3. **Spawn parallel sub-agent tasks for comprehensive research:**
   - Create multiple Task agents to research different aspects concurrently
   - We now have specialized agents that know how to do specific research tasks:

   **For codebase research:**
   - Use the **codebase-locator** agent to find WHERE files and components live
     - Look for `Cargo.toml`, `lib.rs`, `main.rs`, `mod.rs` files to understand crate/module structure
     - Search `*.rs` files, `build.rs`, `.cargo/config.toml`
   - Use the **codebase-analyzer** agent to understand HOW specific code works (without critiquing it)
     - Focus on trait definitions, impl blocks, type aliases, error types, and module hierarchies
   - Use the **codebase-pattern-finder** agent to find examples of existing patterns (without evaluating them)
     - Look for common Rust patterns: builder pattern, newtype pattern, From/Into impls, error handling patterns, async patterns

   **IMPORTANT**: All agents are documentarians, not critics. They will describe what exists without suggesting improvements or identifying issues.

   **For web research (use when external context would help):**
   - Use the **web-search-researcher** agent for external documentation, crate docs, RFCs, blog posts, and resources
   - Spawn web research agents proactively when the topic involves external crates, Rust language features, or ecosystem patterns
   - Instruct them to return LINKS with their findings, and please INCLUDE those links in your final report

   The key is to use these agents intelligently:
   - Start with locator agents to find what exists
   - Then use analyzer agents on the most promising findings to document how they work
   - Run multiple agents in parallel when they're searching for different things
   - Each agent knows its job - just tell it what you're looking for
   - Don't write detailed prompts about HOW to search - the agents already know
   - Remind agents they are documenting, not evaluating or improving

4. **Wait for all sub-agents to complete and synthesize findings:**
   - IMPORTANT: Wait for ALL sub-agent tasks to complete before proceeding
   - Compile all sub-agent results
   - Connect findings across different crates, modules, and components
   - Include specific file paths and line numbers for reference
   - Highlight patterns, connections, and architectural decisions
   - Answer the user's specific questions with concrete evidence
   - Document trait relationships, generic type parameters, and lifetime annotations where relevant

5. **Generate research document:**
   - Structure the document with content:

     ```markdown
     # Research: [User's Question/Topic]

     **Date**: [Current date and time]
     **Git Commit**: [Current commit hash]
     **Branch**: [Current branch name]

     ## Research Question

     [Original user query]

     ## Summary

     [High-level documentation of what was found, answering the user's question by describing what exists]

     ## Crate & Module Structure

     [Workspace layout, crate dependencies, module tree relevant to the research]

     ## Detailed Findings

     ### [Component/Area 1]

     - Description of what exists (file.rs:line)
     - How it connects to other components
     - Current implementation details (without evaluation)
     - Key traits, types, and impls involved

     ### [Component/Area 2]

     ...

     ## Code References

     - `path/to/file.rs:123` - Description of what's there
     - `another/module/mod.rs:45-67` - Description of the code block

     ## Architecture Documentation

     [Current patterns, conventions, and design implementations found in the codebase]

     - Error handling approach (thiserror, anyhow, custom Result types)
     - Async runtime usage (tokio, async-std, etc.)
     - Serialization patterns (serde derives, custom impls)
     - Feature flag organization

     ## Open Questions

     [Any areas that need further investigation]
     ```

6. **Add GitHub permalinks (if applicable):**
   - Check if on main branch or if commit is pushed: `git branch --show-current` and `git status`
   - If on main/master or pushed, generate GitHub permalinks:
     - Get repo info: `gh repo view --json owner,name`
     - Create permalinks: `https://github.com/{owner}/{repo}/blob/{commit}/{file}#L{line}`
   - Replace local file references with permalinks in the document

7. **Present findings:**
   - Present a concise summary of findings to the user
   - Include key file references for easy navigation
   - Ask if they have follow-up questions or need clarification

8. **Handle follow-up questions:**
   - If the user has follow-up questions, append to the same research document
   - Add a new section: `## Follow-up Research [timestamp]`
   - Spawn new sub-agents as needed for additional investigation

## Important notes:

- Always use parallel Task agents to maximize efficiency and minimize context usage
- Always run fresh codebase research - never rely solely on existing research documents
- Focus on finding concrete file paths and line numbers for developer reference
- Research documents should be self-contained with all necessary context
- Each sub-agent prompt should be specific and focused on read-only documentation operations
- Document cross-component connections and how systems interact
- Link to GitHub when possible for permanent references
- Keep the main agent focused on synthesis, not deep file reading
- Have sub-agents document examples and usage patterns as they exist
- **CRITICAL**: You and all sub-agents are documentarians, not evaluators
- **REMEMBER**: Document what IS, not what SHOULD BE
- **NO RECOMMENDATIONS**: Only describe the current state of the codebase
- **File reading**: Always read mentioned files FULLY (no limit/offset) before spawning sub-tasks
- **Rust-specific guidance**:
  - Explore `Cargo.toml` and `Cargo.lock` for dependency graphs
  - Map out workspace members when in a workspace
  - Document `pub` visibility boundaries between modules
  - Note `#[cfg(...)]` conditional compilation and feature gates
  - Track `use` imports to understand module dependency flow
  - Identify key derive macros and proc macros in use
  - Document unsafe blocks and their safety invariants
  - Note any FFI boundaries (`extern "C"`, `#[no_mangle]`)
- **Critical ordering**: Follow the numbered steps exactly
  - ALWAYS read mentioned files first before spawning sub-tasks (step 1)
  - ALWAYS wait for all sub-agents to complete before synthesizing (step 4)
  - NEVER write the research document with placeholder values
