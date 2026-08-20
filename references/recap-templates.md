# Recap templates

Two shapes. Pick by how the recap reaches Slack (SKILL.md step 6). No bold in either one.

---

## A. SUMMARY.txt — pasted into a Slack message (default)

Zero markdown: no `#`, no `*`, no backticks, no links, no bold. Everything below is literal.

```
<Team> demo, <Mon D>

<N> demos and a release note. Timestamps point into the recording.


1. <Title> (<m:ss>)
<~60-70 words: what it is, what it does, where it stands. One paragraph.>
<Status line when it matters: not merged yet / in the nightly since yesterday / ships in the next release / design only.>
Open: <question a reader can answer in the thread>
Open: <question>
pic: 01_<topic>.jpg, 01_<topic>.gif


2. <Title> (<m:ss>)
...


<Closing line: a release note, or an invitation to reply under any section.>
```

Notes on the plain-text shape:
- Numbered sections, timestamp in parentheses. Two blank lines between sections so Slack breathes.
- `Open:` prefixes every unresolved item, one line each, phrased as a question.
- `pic:` names the visuals for that section on its own line, so the poster knows what to attach where.
- Write `Agreed: <what>` on its own line only for decisions the transcript states outright.
- When the team supplies a decision table, paste the table as aligned plain text rather than describing it.

---

## B. SUMMARY.md — posted as a file or kept as a doc

Same content, markdown structure, still no bold.

```markdown
# <Team> demo — <Mon D>

<Two lines: what this is, and that the open questions are where outside input helps.>

*(New here? <one plain sentence on what the project is>.)*

Jump to:
- 1 — <title> · ~<m:ss>
- 2 — <title> · ~<m:ss>

---

## 1. <Title>
*<status: mockups | working prototype | in the nightly | ships in X>.*

📎 `01_<topic>.jpg` · 🎞️ `01_<topic>.gif`

<One paragraph for someone outside the team. Fold the agreed decisions into the prose.>

Open questions:
- <question>

---

<Closing invitation to reply in the thread.>
```

Both variants: audience is outsiders, acronyms expanded on first use, a timestamp on every section, maturity stated honestly, and every undecided item phrased as a question.
