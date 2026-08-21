# Why idstack is AI-native

Most education tools add conversational chat interfaces to existing software. idstack is designed as an agentic workflow where skills, context management, and CLI pipelines require an LLM runtime to execute.

## Architectural Distinctions

Conventional AI interfaces:
- Add a conversational chat pane to an existing user interface
- Maintain no structured memory or course state beyond a single conversation
- Provide optional assistance while core workflows remain unchanged

AI-native workflows:
- Allocate compute directly to analytical tasks across course modules
- Benefit directly from underlying model capability improvements without application code changes
- Structure complex workflows around LLM reasoning rather than fixed heuristics
- Influence how educators design and structure instructional materials

idstack operates on all four criteria.

## idstack Implementation

**Agentic workflows require an LLM runtime.** idstack skills are structured markdown specifications executed by Claude Code. Without an agentic environment, the files function as passive documentation. The runtime executes the analytical steps, evaluates alignment, and generates structured deliverables.

**Model capabilities enhance skill output.** As foundation models improve in instruction following, pedagogical reasoning, and domain analysis, idstack skill execution improves without code changes.

**Substantial computational workloads.** Running the pipeline (import, learning objectives, assessment design, content construction, quality review, accessibility audit, red team analysis, and export) across a multi-week course represents a focused computational workload that automates detailed instructional audits.

**Practical instructional design impact.** When an audit indicates that empirical T1 evidence favors elaborated feedback over simple correctness indicators, designers can adjust assessment structures accordingly. When an adversarial audit highlights cognitive process mismatches across Bloom's levels, designers can refine learning objectives. Evidence tiers provide objective decision criteria for course revisions.

## Tool Integration and Context Efficiency

Context management is critical when orchestrating agent tools:

- **CLI tools** require minimal upfront context. The agent invokes a shell command and consumes context only for the tool call and output.
- **API integrations** involve connection setup, authentication, and structured payload exchange.
- **MCP servers** expose tool schemas that persist in the active context window throughout a session.

Skills represent an on-demand category. They load into the agent's context when invoked, execute their analytical instructions, write structured reports and manifest updates, and allow context to be reclaimed once completed.

This lifecycle is essential for idstack because skill instructions range from 400 to 900 lines of structured rules. On-demand execution prevents context exhaustion across multi-skill pipelines.

## Contributor Guidelines

Building an idstack skill means defining an agentic workflow that leverages the LLM runtime:

- Target complex analytical tasks that require domain synthesis, rubric alignment, and pedagogical evaluation rather than simple text transformations.
- Reference empirical citations for every analytical recommendation so users can verify underlying research.
- Design prompts around fundamental reasoning principles rather than fragile workarounds for transient model behaviors.
