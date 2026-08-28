# Claude Code Standing Orders

## Prose

Write ASD-STE100 Simplified Technical English in all prose. That covers code
comments, Markdown, commit messages, issue text, `pull request` text, and
the GitHub repository description.

- Use the active voice.
- Use simple tenses only. Do not use the present perfect.
- Do not use an `-ing` word as a verb.
- Keep an instruction to 20 words. Keep descriptive text to 25 words.
- Give one instruction per sentence. Do not join two with "and".
- Stack a maximum of 3 words as a modifier.
- Use one term for one concept. Do not rotate synonyms.
- Prefer the short common word to the formal word.

Never rewrite code, quoted output, an exact identifier, or a command. The exact
wording carries the meaning there.

To check a file:

```sh
vale --config=$HOME/darwin-nix-config/.vale.ini README.md
```

## Comments

Write a comment only for a reason the code cannot show. A measurement, a
decision, or a trap earns a comment. A restatement of the code does not.

Delete a comment when its reason expires.

## Commits

Use Conventional Commits: `type: description`.

Keep the subject under 60 characters. Write a body only for a reason that the
subject cannot hold. Most commits here need no body.

Do not add a `Co-Authored-By` line for Claude.

## Repo rules

- The `sprite` binary is unfree, and nobody grants a redistribution right.
  Never push this package to a public binary cache.
- `scripts/update-version.sh` must read `client/latest`. The addresses
  `client/release.txt` and `client/rc.txt` are dead. They froze nixpkgs.
