# Lotsawa

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fval-lang%2FLotsawa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/val-lang/Lotsawa)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fval-lang%2FLotsawa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/val-lang/Lotsawa)

A parsing library and tool with the essential features of
[MARPA](https://jeffreykegler.github.io/Marpa-web-site/), encoded in pure Swift.

In particular, like MARPA, Lotsawa:

- Parses any [LR-regular](https://www.sciencedirect.com/science/article/pii/S0022000073800509) grammar in linear time.
- Parses some non-LR-regular grammars in linear time.
- Produces the parse forests for any CFG.

Lotsawa owes almost everything of value to MARPA and its author, Jeffrey Kegler, for uncovering the
[thread of progress in parsing technology](https://jeffreykegler.github.io/personal/timeline_v3),
gathering it together into one group of algorithms, proving important properties about them, and
contributing some key innovations.  This project exists primarily because MARPA is [missing
functionality](https://github.com/jeffreykegler/libmarpa/issues/117) needed by the [Val
language](https://github.com/val-lang/val) implementation.

Secondary reasons Lotsawa might be useful:

- Lotsawa supports high-level usage from a safe, statically-typed language that compiles to efficient
  native code.
- Lotsawa has a simple build/installation process and no dependencies other than Swift.
- Lotsawa encodes the grammar analysis and recognition algorithms with a relatively small amount of
  high-level code; it may serve as a better reference for understanding the technology than either
  the highly theoretical Marpa paper or from libmarpa's C implementation, which must be extracted
  from a CWeb document.
- Lotsawa can be used to precompile a grammar into static tables, eliminating some initial startup
  cost.
- Lotsawa uses pure [Mutable Value
  Semantics](https://www.quora.com/What-is-mutable-value-semantics/answer/Dave-Abrahams), thus
  eliminating many possible sources of bugs, including data races.
