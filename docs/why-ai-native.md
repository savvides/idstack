# Why idstack is AI-native

Most education tools add conversational chat interfaces to existing software. idstack is designed as an agentic workflow where skills, context management, and CLI pipelines run in Claude Code.

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

**Agentic workflows require Claude Code or Cowork.** idstack skills are structured markdown specifications executed by Claude Code or Cowork. Without one of them, the files function as passive documentation. Claude Code executes the analytical steps, evaluates alignment, and generates structured deliverables.

**Model capabilities enhance skill output.** As foundation models improve in instruction following, pedagogical reasoning, and domain analysis, idstack skill execution improves without code changes.

**Substantial computational workloads.** Running the pipeline (needs analysis, learning objectives, assessment design, content construction, quality review, accessibility audit, red team analysis, and export) across a multi-week course represents a focused computational workload that automates detailed instructional audits.

**Practical instructional design impact.** When an audit indicates that empirical T1 evidence favors elaborated feedback over simple correctness indicators, designers can adjust assessment structures accordingly. When an adversarial audit highlights cognitive process mismatches across Bloom's levels, designers can refine learning objectives. Evidence tiers provide objective decision criteria for course revisions.

## Tool Integration and Context Efficiency

Context management is critical when orchestrating agent tools:

- **CLI tools** require minimal upfront context. The agent invokes a shell command and consumes context only for the tool call and output.
- **API integrations** involve connection setup, authentication, and structured payload exchange.
- **MCP servers** expose tool schemas that persist in the active context window throughout a session.

Skills represent an on-demand category. A skill loads into the agent's context only when it is invoked. It then runs its analytical instructions and writes structured reports and manifest updates. A session uses context only for the skills it runs.

This matters for idstack because each skill's instructions, with the shared preamble, range from about 600 to 1,900 lines of structured rules. A skill's text stays in context after it finishes. In a `/idstack:pipeline` run, each skill runs in the same conversation, so its text adds to the context of the skills before it. The pipeline saves progress after each skill. You can stop and later continue in a new session with `/idstack:pipeline`, and it skips the skills that are already complete.

## Contributor Guidelines

Building an idstack skill means defining a Claude Code workflow:

- Target complex analytical tasks that require domain synthesis, rubric alignment, and pedagogical evaluation rather than simple text transformations.
- Reference empirical citations for every analytical recommendation so users can verify underlying research.
- Design prompts around fundamental reasoning principles rather than fragile workarounds for transient model behaviors.
