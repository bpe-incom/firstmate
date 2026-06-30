# Universal conventions

- Code is the primary documentation: clear names, small focused functions, obvious structure.
- Do NOT add doc comments (XML `/// <summary>`, JSDoc/TSDoc, docstrings) by default, and never add them routinely to every function, type, or member.
- Add a comment only when it conveys something the code cannot: a non-obvious *why*, a subtle invariant, a workaround (with a reference), or genuinely complex logic. If a comment only restates the code, leave it out.
- Match the surrounding code: its naming, structure, and existing comment density.
