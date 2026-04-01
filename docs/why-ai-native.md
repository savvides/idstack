# Why idstack is AI-native

Most "AI-powered" education tools bolt a chatbot onto an existing product. idstack is different. The AI isn't a feature. It's the entire product.

## The difference matters

Bolted-on AI products:
- Add an AI button with sparkle icons to an existing interface
- Include a chat pane where you can "ask the AI questions"
- Have no memory or personalization beyond one conversation
- Users try the AI feature once and go back to using the app the "normal" way
- The product works fine without AI. The AI is optional.

AI-native products:
- Users spend real money on AI compute as they use the product ($10, $100, $1000 in tokens)
- The product gets substantially better every 6 months as base models improve, without any code changes
- The core workflow is impossible without AI, not just enhanced by it
- Using the product creates genuine behavior change

idstack is AI-native on all four counts.

## How idstack scores

**Core workflow is impossible without AI.** idstack skills are structured instructions for an AI agent. Without Claude Code (or Gemini CLI, or Codex CLI), the SKILL.md files are just Markdown. There is no "normal way" to use idstack without AI. The AI IS the product.

**It gets better as models improve.** When Claude gets better at following complex multi-step instructions, at understanding educational research, at generating course content... every idstack skill gets better for free. No code changes needed. You're riding the model improvement curve automatically.

**Real token spend.** Running the full pipeline (import, objectives, assessment, build, quality review, accessibility, red team, export) on a 20-module course is a real AI workload. The more you use it, the more value you get, and the more tokens you consume. This is AI creating genuine value, not performing the appearance of intelligence.

**Behavior change.** When an instructional designer sees that their T1 evidence says elaborated feedback outperforms correctness-only feedback, and their course has no elaborated feedback... that changes how they design the next course. When the red team audit shows a Bloom's level mismatch between objectives and assessments, that changes how they write objectives. The evidence tiers aren't decoration. They're decision-making tools.

## Where skills sit in the AI tool hierarchy

Andrej Karpathy's hierarchy for connecting tools to AI agents: CLI at the top, API in the middle, MCP at the bottom. The distinction is context efficiency.

- **CLI tools** use zero context until the moment you call them. The AI invokes `gh pr create` and the context cost is one tool call.
- **API integrations** have moderate overhead. Connection setup, authentication, response parsing.
- **MCP servers** eat context the moment they connect. Every MCP you load sits in your context window doing nothing until you call it. Five MCPs can burn 15-20% of usable context before you've typed a message.

Skills are a fourth category. They load on-demand (like CLIs, zero cost until invoked) but execute inside the agent's context (like MCPs). The key difference: a skill loads, runs, and then its context can be reclaimed. An MCP stays connected.

This matters for idstack because the skills are large (400-900 lines of structured instructions). They consume context while running, but they don't sit idle. When `/course-quality-review` finishes, that context is available for the next skill.

## What this means for contributors

When you build an idstack skill, you're not building a feature that gets bolted onto something else. You're building an AI workflow that wouldn't exist without the AI runtime. The skill IS the product.

Design accordingly:
- The AI should be doing work that would take a human expert hours. Not summarizing, not reformatting, not searching. Analyzing, synthesizing, challenging, evaluating.
- Every recommendation should cite its evidence so the user can verify the AI's judgment. Trust but verify.
- The skill should get better automatically as models improve. Don't hardcode workarounds for model limitations that will be fixed in 6 months.
