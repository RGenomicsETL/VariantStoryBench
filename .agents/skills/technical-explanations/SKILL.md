---
name: technical-explanations
description: Write and render technical documentation with STE-style prose, Mermaid diagrams, and Rmd or Qmd sources. Use for READMEs, specifications, implementation guides, and PR explanations.
---

# Technical explanations

## Choose the smallest useful format

Start with the reader's question and one clear answer. Show a diagram for
components, file layouts, dependencies, state changes, or data flow.
Use a short table for alternatives. Put details after the overview.

Use practical ASD-STE100-style writing: short sentences, active voice, one
topic per paragraph, and one term per concept. Define necessary technical terms.
Aim for about 20 words per instruction and 25 words per description.
Preserve exact API names and scientific meaning. Do not claim formal STE compliance.

## Keep the source executable and editable

- Author new technical guides in `.qmd` or `.Rmd`.
- Keep existing generated READMEs connected to their `.Rmd` source.
- Use native `{mermaid}` cells in Quarto. Render `gfm` for GitHub and `html` for local reading.
- Execute R/SQL examples when dependencies and inputs are available.
- Otherwise use an ordinary code block and label the example as unexecuted.
- Never type invented outputs or edit generated Markdown to disguise a failed render.
- Commit source and small generated Markdown. Publish larger HTML as a build artifact.

## Make diagrams carry information

Label arrows with the values or operations they carry. Distinguish source data,
stored state, computed output, and optional components. Show success and failure
paths where transactions matter. Explain symbols in nearby text.

Prefer several small diagrams to one crowded diagram. Keep a text explanation
so the document remains useful without JavaScript. Use actual schema and function
names from the implementation; mark proposed functions explicitly.

## Render and inspect

```sh
quarto render docs/implementation.qmd --to gfm
quarto render docs/implementation.qmd --to html
```

Check diagram syntax, links, examples, and narrow-screen readability.
Keep computed results tied to their inputs and implementation version.
State which tests and renders actually ran. Separate plans from implementation.

## Use richer media selectively

Use HTML for navigation, expandable details, and useful interaction.
Use animation or narrated explainers only when helpful or requested.
Do not add a frontend framework, paid narration service, or API-key requirement
for ordinary documentation. Never include credentials in examples or rendered files.

Source supplied by the user:
<https://x.com/karpathy/status/2105819303471976479>.
Rendering reference: <https://quarto.org/docs/authoring/diagrams.html>.
