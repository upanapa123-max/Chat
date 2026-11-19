#!/usr/bin/env python3
"""
Lightweight structural checker for the LAST SHIFT Luau sources.

This is NOT a replacement for luau-analyze / selene. It exists so the source can be
sanity-checked on machines without the Luau toolchain. It checks:
  1. Tokenization: unterminated strings / long strings / comments.
  2. Block balance: function/if/do/repeat vs end/until, plus (), [], {}.
     Luau if-expressions (`x = if a then b else c`) are recognized and need no `end`.
  3. Instance paths: every `require(...)` / `:WaitForChild("X")` chain rooted at
     `script`, or at ReplicatedStorage's "LastShift" folder, resolves to a real
     file/folder in the Rojo tree described by default.project.json.

Usage:  python tools/check_luau.py            (from the project folder)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

KEYWORDS = {
    "and", "break", "continue", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
# Tokens after which `if` starts an expression rather than a statement.
EXPR_CONTEXT = {
    "=", "(", ",", "{", "[", "return", "and", "or", "not", "..", "+", "-", "*", "/", "//",
    "%", "^", "==", "~=", "<", ">", "<=", ">=", "in", "+=", "-=", "*=", "/=", "..=", "::",
}
SYMBOLS = sorted(
    ["...", "..=", "//=", "==", "~=", "<=", ">=", "..", "::", "->", "+=", "-=", "*=", "/=",
     "%=", "^=", "//", "+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}",
     "[", "]", ";", ":", ",", ".", "?", "|", "&"],
    key=len, reverse=True,
)


class LuauError(Exception):
    pass


def tokenize(src):
    tokens = []  # (kind, value, line)
    i, line, n = 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i + len(m.group(0)))
                if j < 0:
                    raise LuauError(f"line {line}: unterminated long comment")
                line += src.count("\n", i, j)
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i + len(m.group(0)))
            if j < 0:
                raise LuauError(f"line {line}: unterminated long string")
            tokens.append(("string", src[i + len(m.group(0)):j], line))
            line += src.count("\n", i, j)
            i = j + len(close)
            continue
        if c in "\"'`":
            j = i + 1
            buf = []
            while True:
                if j >= n or src[j] == "\n":
                    raise LuauError(f"line {line}: unterminated string")
                if src[j] == "\\":
                    buf.append(src[j:j + 2])
                    j += 2
                    continue
                if src[j] == c:
                    break
                buf.append(src[j])
                j += 1
            tokens.append(("string", "".join(buf), line))
            i = j + 1
            continue
        m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d+)?|\.\d+", src[i:])
        if m and (c.isdigit() or c == "."):
            if m.group(0) != ".":
                tokens.append(("number", m.group(0), line))
                i += len(m.group(0))
                continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
        if m:
            word = m.group(0)
            tokens.append(("keyword" if word in KEYWORDS else "name", word, line))
            i += len(word)
            continue
        for sym in SYMBOLS:
            if src.startswith(sym, i):
                tokens.append(("symbol", sym, line))
                i += len(sym)
                break
        else:
            raise LuauError(f"line {line}: unexpected character {c!r}")
    return tokens


def check_blocks(tokens):
    stack = []  # (opener, line)
    pairs = {")": "(", "]": "[", "}": "{"}
    prev = None
    # `for`/`while` lines own the following `do`; a type `function` in annotations
    # (e.g. `(x) -> ()`) does not use the keyword, so it is always a real block.
    for idx, (kind, val, line) in enumerate(tokens):
        if kind == "symbol" and val in "([{":
            stack.append((val, line))
        elif kind == "symbol" and val in ")]}":
            if not stack or stack[-1][0] != pairs[val]:
                raise LuauError(f"line {line}: unmatched {val!r}" + (f" (open {stack[-1][0]!r} from line {stack[-1][1]})" if stack else ""))
            stack.pop()
        elif kind == "keyword":
            if val == "function":
                stack.append(("function", line))
            elif val == "if":
                pv = prev[1] if prev else None
                expr = pv in EXPR_CONTEXT or (pv == "then" and stack and stack[-1][0] == "if-expr") \
                    or (pv == "else" and stack and stack[-1][0] == "if-expr")
                stack.append(("if-expr" if expr else "if", line))
            elif val == "then":
                if not stack or stack[-1][0] not in ("if", "if-expr"):
                    raise LuauError(f"line {line}: 'then' without 'if'")
            elif val == "elseif":
                if not stack or stack[-1][0] not in ("if", "if-expr"):
                    raise LuauError(f"line {line}: 'elseif' without 'if'")
            elif val == "else":
                if not stack or stack[-1][0] not in ("if", "if-expr"):
                    raise LuauError(f"line {line}: 'else' without 'if'")
                if stack[-1][0] == "if-expr":
                    # the else-branch is a single expression; close the if-expression
                    # once that expression ends. Approximate: pop now — the branch's own
                    # brackets are still tracked independently.
                    stack.pop()
            elif val in ("while", "for"):
                stack.append((val, line))
            elif val == "do":
                if stack and stack[-1][0] in ("while", "for"):
                    stack[-1] = ("do", stack[-1][1])
                else:
                    stack.append(("do", line))
            elif val == "repeat":
                stack.append(("repeat", line))
            elif val == "until":
                if not stack or stack[-1][0] != "repeat":
                    raise LuauError(f"line {line}: 'until' without 'repeat'")
                stack.pop()
            elif val == "end":
                if not stack or stack[-1][0] not in ("function", "if", "do"):
                    top = stack[-1] if stack else None
                    raise LuauError(f"line {line}: unexpected 'end'" + (f" (open {top[0]!r} from line {top[1]})" if top else ""))
                stack.pop()
        prev = (kind, val)
    if stack:
        opener, line = stack[-1]
        raise LuauError(f"unclosed {opener!r} opened on line {line}")


# ---------------------------------------------------------------------------
# Rojo tree resolution


def instance_name(filename):
    for suffix in (".server.luau", ".client.luau", ".luau", ".server.lua", ".client.lua", ".lua"):
        if filename.endswith(suffix):
            return filename[: -len(suffix)]
    return None


def build_fs_node(path):
    """Instance-name tree for a directory or file mapped by Rojo."""
    if os.path.isfile(path):
        return {"__file__": path}
    node = {"__dir__": path}
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            node[entry] = build_fs_node(full)
        else:
            name = instance_name(entry)
            if name and name != "init":
                node[name] = {"__file__": full}
    return node


def build_tree(project_path):
    project = json.load(open(project_path, encoding="utf-8"))

    def walk(node):
        out = {}
        if "$path" in node:
            target = os.path.join(os.path.dirname(project_path), node["$path"])
            if target.endswith(".project.json"):
                out.update(walk(json.load(open(target, encoding="utf-8")).get("tree", {})))
            else:
                out.update(build_fs_node(target))
        for key, child in node.items():
            if not key.startswith("$"):
                out[key] = walk(child)
        return out

    return walk(project["tree"])


def find_file_node(tree, path, trail=()):
    for key, child in tree.items():
        if key.startswith("__"):
            continue
        if child.get("__file__") and os.path.samefile(child["__file__"], path):
            return trail + (key,)
        found = find_file_node(child, path, trail + (key,))
        if found:
            return found
    return None


def lookup(tree, trail):
    node = tree
    for key in trail:
        if key not in node:
            return None
        node = node[key]
    return node


CHAIN = re.compile(r'(?:\.([A-Za-z_]\w*)|:WaitForChild\(\s*"([^"]+)"[^)]*\))')


def check_paths(tree, path, src):
    """Resolve script-relative and LastShift-relative instance chains."""
    problems = []
    me = find_file_node(tree, path)
    if not me:
        return [f"{path}: not mapped by default.project.json"]
    shared_root = ("ReplicatedStorage", "LastShift")
    aliases = {}  # local name -> trail
    for m in re.finditer(r'local\s+(\w+)\s*=\s*(script|ReplicatedStorage|shared|data|services|controllers|views|\w+)((?:\.[A-Za-z_]\w*|:WaitForChild\(\s*"[^"]+"[^)]*\))*)', src):
        name, base, rest = m.groups()
        if base == "script":
            trail = me
        elif base == "ReplicatedStorage":
            trail = ("ReplicatedStorage",)
        elif base == "Workspace" and rest.startswith(":WaitForChild"):
            trail = ("Workspace",)
        elif base in aliases:
            trail = aliases[base]
        else:
            continue
        ok = True
        for part in CHAIN.finditer(rest):
            key = part.group(1) or part.group(2)
            if key == "Parent":
                trail = trail[:-1]
            else:
                trail = trail + (key,)
                if lookup(tree, trail) is None:
                    problems.append(f"{os.path.relpath(path, ROOT)}: {name} -> {'/'.join(trail)} does not exist")
                    ok = False
                    break
        if ok:
            aliases[name] = trail
        if name == "shared" and ok:
            if trail != shared_root:
                problems.append(f"{os.path.relpath(path, ROOT)}: 'shared' resolves to {'/'.join(trail)}")
    # require(<alias>...) chains
    for m in re.finditer(r'require\(\s*(\w+)((?:\.[A-Za-z_]\w*|:WaitForChild\(\s*"[^"]+"[^)]*\))*)\s*\)', src):
        base, rest = m.groups()
        if base == "script":
            trail = me
        elif base in aliases:
            trail = aliases[base]
        else:
            problems.append(f"{os.path.relpath(path, ROOT)}: cannot resolve require base '{base}'")
            continue
        for part in CHAIN.finditer(rest):
            key = part.group(1) or part.group(2)
            trail = trail[:-1] if key == "Parent" else trail + (key,)
        node = lookup(tree, trail)
        if node is None or "__file__" not in node:
            problems.append(f"{os.path.relpath(path, ROOT)}: require -> {'/'.join(trail)} is not a module")
    return problems


def main():
    project = os.path.join(ROOT, "default.project.json")
    tree = build_tree(project)
    files = []
    for base in ("src", "tests"):
        for dirpath, _, names in os.walk(os.path.join(ROOT, base)):
            files += [os.path.join(dirpath, f) for f in names if f.endswith(".luau")]
    errors = 0
    for path in sorted(files):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        try:
            check_blocks(tokenize(src))
        except LuauError as e:
            print(f"SYNTAX  {rel}: {e}")
            errors += 1
            continue
        if rel.startswith("src"):
            for problem in check_paths(tree, path, src):
                print(f"PATH    {problem}")
                errors += 1
    print(f"checked {len(files)} files, {errors} problem(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
