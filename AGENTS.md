# Agent guidelines

Use R, SQL, and native DuckDB code for runtime work. Reuse related provider projects.
Keep functions small and data operations relational. Add focused tests for changed behavior.
Add a NEWS entry for exported behavior changes. Do not commit data files or credentials.

For documentation, read `.agents/skills/technical-explanations/SKILL.md`.
Use Rmd/Qmd sources, Mermaid diagrams, and rendered outputs. Do not edit generated
Markdown directly. Separate proposed behavior from executed results.
