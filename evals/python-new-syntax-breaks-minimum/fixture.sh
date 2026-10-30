#!/bin/bash
# A small expression-tokenising library that supports Python 3.9 through 3.13:
# requires-python says >=3.9, the classifiers and the CI matrix list 3.9, and
# ruff targets py39. The uncommitted change adds a parser helper in tokens.py.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p tinyparse tests .github/workflows

cat > pyproject.toml <<'TOML'
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "tinyparse"
version = "0.3.0"
description = "A tiny tokeniser for arithmetic expressions."
requires-python = ">=3.9"
dependencies = []
classifiers = [
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Programming Language :: Python :: 3.13",
]

[tool.ruff]
target-version = "py39"
TOML

cat > tinyparse/__init__.py <<'PY'
"""A tiny tokeniser for arithmetic expressions."""

from tinyparse.tokens import Kind, Token, tokenize

__all__ = ["Kind", "Token", "tokenize"]
PY

cat > tinyparse/tokens.py <<'PY'
"""Tokeniser for a tiny arithmetic expression language."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Kind(Enum):
    NUMBER = "number"
    PLUS = "plus"
    MINUS = "minus"
    STAR = "star"
    SLASH = "slash"
    LPAREN = "lparen"
    RPAREN = "rparen"


@dataclass(frozen=True)
class Token:
    kind: Kind
    text: str


_SYMBOLS = {
    "+": Kind.PLUS,
    "-": Kind.MINUS,
    "*": Kind.STAR,
    "/": Kind.SLASH,
    "(": Kind.LPAREN,
    ")": Kind.RPAREN,
}


def tokenize(source: str) -> list:
    tokens = []
    i = 0
    while i < len(source):
        ch = source[i]
        if ch.isspace():
            i += 1
            continue
        if ch.isdigit():
            start = i
            while i < len(source) and source[i].isdigit():
                i += 1
            tokens.append(Token(Kind.NUMBER, source[start:i]))
            continue
        symbol = _SYMBOLS.get(ch)
        if symbol is None:
            raise ValueError("unexpected character: " + repr(ch))
        tokens.append(Token(symbol, ch))
        i += 1
    return tokens
PY

cat > tests/test_tokens.py <<'PY'
import unittest

from tinyparse.tokens import Kind, tokenize


class TokenizeTest(unittest.TestCase):
    def test_numbers_and_operators(self):
        kinds = [t.kind for t in tokenize("12 + 3 * (4 - 1)")]
        self.assertEqual(
            kinds,
            [
                Kind.NUMBER,
                Kind.PLUS,
                Kind.NUMBER,
                Kind.STAR,
                Kind.LPAREN,
                Kind.NUMBER,
                Kind.MINUS,
                Kind.NUMBER,
                Kind.RPAREN,
            ],
        )

    def test_rejects_unknown_character(self):
        with self.assertRaises(ValueError):
            tokenize("1 % 2")


if __name__ == "__main__":
    unittest.main()
PY

cat > .github/workflows/test.yml <<'YML'
name: test

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.9", "3.10", "3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: python -m pip install .
      - run: python -m unittest discover -s tests
YML

cat > README.md <<'MD'
# tinyparse

A tiny tokeniser for arithmetic expressions. Supports Python 3.9 and newer.
MD

git add -A
git commit -qm "Add the tokeniser, its tests and the CI matrix"

cat >> tinyparse/tokens.py <<'PY'


def precedence(token: Token) -> int:
    """Binding power the expression parser uses to order operators."""
    match token.kind:
        case Kind.PLUS | Kind.MINUS:
            return 1
        case Kind.STAR | Kind.SLASH:
            return 2
        case _:
            return 0
PY
