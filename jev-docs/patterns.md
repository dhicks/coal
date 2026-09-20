# Design patterns and cookbooks

Sources: /concepts/how-to-build-with-system-one.md, /patterns/*.md, /agent-skill.md, /cookbooks/* (retrieved 2026-09-20). Cookbooks not summarized in detail here are listed at the end; fetch the `.md` URL when one applies.

## Architecture principle

Code owns control flow, deterministic rules, arithmetic, and side effects. Jev supplies narrow, typed judgments over unstructured input. It is not an agent and does not choose next actions. Workflow:

1. Use code when code can decide (status checks, date arithmetic, counting).
2. Decompose state: send only what the questions need.
3. Decompose questions: atomic, one judgment each.
4. Ask many questions in one request; ignore irrelevant answers.
5. Combine answers in code (weights, thresholds), or feed probabilities as features to a classical model (autoresearch cookbook).
6. Route on uncertainty using confidence.

## Speculative fan-out

Ask all questions any branch might need in one call; branch in code. Example: ticket triage asks `category` (Choice), `bug_severity` (Score), `has_reproducible_steps` (Noul), `refund_requested` (Noul), `frustration` (Score) together, then uses severity only if category is `bug_report`.

## Confidence-gated routing

Gate each action on its own confidence threshold according to the cost of error. See `confidence-and-thresholds.md`.

## Composite scoring

Split a broad judgment into one Score per dimension, normalize each by `n_levels - 1`, and combine with weights in code. Different roles reuse the same answers with different weights (senior IC vs. engineering manager). Weights are inspectable and adjustable without rewriting prompts.

## Intent routing

One Choice for intent plus a Score for complexity. Route: simple intents to deterministic code, others to specialist LLMs, complaints with high complexity or low confidence to a human. Low confidence on classification goes to a human first.

## Hierarchical classification

One Choice per taxonomy level; walk the tree in code with each option's value as its subtree (trim large subtrees to children plus sample leaves). Beam search keeps the best K paths using Choice probabilities when the top option is not clear. Cookbook: /cookbooks/hierarchical_classification.md.

## Structured data extraction

Extraction is a Choice over enumerated or regex-extracted candidates, not generation. Dates: Choices for month, day, year, each with a "not stated" option; assemble in code. Pre-parsed values: regex finds candidates, Jev selects the span. Cookbooks: date_extraction_cookbook, pre_parsed_value_extraction_cookbook, sde_cascade.

## Cookbook index (base URL https://docs.typesafe.ai/cookbooks/, append `.md`)

| Slug | What it shows |
| ---- | ------------- |
| `consistency_noul_cookbook` | Route uncertain Noul values to human review; stability across runs |
| `consistency_choice_cookbook` | Add an "uncertain" outcome to moderation Choices |
| `parallel_questions` | 13-question briefing in one call: 12.2× cheaper, 10.0× faster |
| `rerank_typesafe` | One Noul per query-candidate pair to re-rank BM25 shortlists |
| `semantic_find` | Line-by-line search: Choice finds the line, Noul checks an answer exists |
| `autoformat` | Recover Markdown structure from plain text in two requests |
| `function_calling` | Map requests to typed function calls with confidence |
| `skill_suggestion` | Rank 182 skills in one request, then re-read the top three |
| `entity_alignment` | Score with levels merge / unlinked / curator; round to nearest level |
| `classifying_rag_passages` | Score retrieved passages; drop injected instructions, flag contradictions |
| `citation_check` | Choice on whether a quote's context supports a claim; confidence flags review |
| `llm_guardrails` | Hazard Nouls and severity Scores on LLM inputs and outputs |
| `sde_cascade` | Two-stage extraction: small model, verify, then reasoning model |
| `date_extraction_cookbook` | Extract date parts with Choices; resolve in code |
| `pre_parsed_value_extraction_cookbook` | Regex candidates, Jev selects |
| `hierarchical_classification` | Beam search over Choice probabilities for deep taxonomies |
| `autoresearch_feature_discovery` | Turn free text into numeric features for a CatBoost regressor |
| `classification_using_confidence` | 75 industry groups; fall back to broader division on low confidence |

Cookbooks use Python. Other pages worth fetching directly: `/patterns/*`, `/demos/smart-home`, `/concepts/use-case-map`, `/introduction/machine-learning-primer` (RLCD training explanation), `/legal`.
