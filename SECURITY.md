# Security Policy

Knackpack is a set of instructions for Claude Code: skills and agents written in Markdown. It contains no executable code, but its instructions decide what Claude does on your machine, so a flaw in them can still be a security problem.

## Reporting a vulnerability

Please report security problems privately, with the **Report a vulnerability** button on this repository's [Security tab](https://github.com/bezmoradi/knackpack/security), not in a public issue. Include:

- the skill or agent involved, and your Claude Code version;
- the steps, or the change under review, that trigger the problem;
- what happened, and what should have happened.

## What counts

A security problem is a way to make a knackpack skill or agent act against the person using it. For example:

- a reviewer changes files, commits, pushes or otherwise alters git state despite being report-only;
- an agent runs code it should have treated as untrusted, or gets tools it shouldn't have;
- an agent leaks secrets or private code, or follows instructions planted in the content it reviews.

Review advice that is wrong or out of date isn't a security problem; please open a normal issue for it.

## Supported versions

Only the latest release gets fixes.
