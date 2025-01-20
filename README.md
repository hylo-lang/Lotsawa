# Lotsawa

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fval-lang%2FLotsawa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/hylo-lang/Lotsawa)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fval-lang%2FLotsawa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/hylo-lang/Lotsawa)

An Earley/Leo parser in pure Swift.

**Don't use this code.**

There are two faster Earley parsers, [Marpa](https://jeffreykegler.github.io/Marpa-web-site/), which inspired this work, and [YAEP](https://github.com/vnmakarov/yaep).  Marpa is faster by about 1.5x but uses 10x more memory. YAEP is much faster than Marpa and uses much *much* less memory than either of the others. 

Most of the code was written in a very principled way, but in January 2025 I made a lot of commits as an experiment without writing comments or tests, and now some of the tests fail.

You've been warned.
