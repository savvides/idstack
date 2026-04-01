# Roadmap

What's coming next for idstack. Priorities are shaped by user feedback. [Tell us what matters to you.](https://forms.gle/6LDgDD1M6WWyYvME8)

## Coming soon

### More skills
Four new skills based on the research synthesis:

- **Model selector** — recommends the right instructional design framework for your context (ADDIE, SAM, backward design, etc.) instead of defaulting to one
- **Content sequencing** — organizes your modules and lessons to manage cognitive load, applying spacing, interleaving, and scaffolding principles
- **Media selection** — flags multimedia principle violations (redundancy, split attention, coherence) and recommends when to use video, text, diagrams, or interactive elements
- **Evaluation design** — plans how to measure whether your course actually worked, using Kirkpatrick's four levels and beyond

### Standardized skill transitions
Smoother handoffs between skills. Right now, different skills say "Next step:" in slightly different ways. We're making the whole pipeline feel like one cohesive experience.

## Exploring

These depend on user demand. If any of these would change your workflow, [let us know](https://forms.gle/6LDgDD1M6WWyYvME8).

### Multi-platform support
Run idstack skills in Gemini CLI and Codex CLI, not just Claude Code. All three platforms use the same skill format. We're waiting for feedback before investing here.

### More LMS integrations
Direct API connections to Blackboard, Moodle, and D2L (beyond the IMS Common Cartridge format that already works). This would unlock richer data like rubrics, analytics, and student engagement metrics.

### Template system
As the skill count grows, a template system to share common patterns across skills. This is internal infrastructure, invisible to users, but it keeps the skills consistent and maintainable.

## The big vision

### Push changes back to your LMS
After `/course-quality-review` identifies issues and `/learning-objectives` generates better objectives, push the improvements directly back to Canvas (and eventually other LMS platforms). No more copy-pasting between a design document and your LMS. The output IS the course.

This is the 10x goal. It depends on stable import/export, Canvas API write support, conflict handling, and institutional partnerships. It's a ways out, but it's where we're headed.

## Shipped

See [CHANGELOG.md](CHANGELOG.md) for the full version history.
