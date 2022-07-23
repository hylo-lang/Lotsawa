# Implementation Notes

Terminology:

**sorted array mapping**
: A sorted array mapping is an array of integer pairs (*s*, *d*), sorted by
  increasing *s*. The *i*th element (*sᵢ*, *dᵢ*) = is interpreted as mapping every
  *x* s.t. *sᵢ* ≤ *x* < *sᵢ₊₁* to *dᵢ* + (*x* - *sᵢ*).

**prediction item**
: An Earley item with its dot preceding its first RHS symbol.

## Grammar Representation

Rule Storage:
- Rules stored end-to-end in a `ruleStore` array.
- Storage format: RHS symbols, then LHS symbol, with a bit used to mark the LHS symbol.  The size of
  the array is is the size of the grammar (per accepted definition of that term).
- **A position in a grammar** is defined to be a position in this array.

- All nullable symbols are eliminated in preprocessing.

- A *sorted array mapping* relates positions in the preprocessed grammar to
  corresponding positions in the un-preprocessed grammar.  That's enough
  information to present a client with information in terms of the original
  grammar.

## Chart Representation

The chart is composed of two arrays:
- an **item array** of Earley items, stored in earleme order
- an **earleme array** of earleme start positions in the first array.

## Earley Item Representation

- Only 3 fields are needed
  - start earleme
  - dot position in the grammar
  - derivation set


## Chart lookups

There are three situations during recognition where we want to quickly search an
Earley set:

- **Lookup 1:** find items with a given postdot symbol in a completed Earley
  set, when that symbol has been recognized starting in the set's earleme. If we
  sort each earley set by postdot symbol when it is completed, *lookup 1* can
  be a binary search.

- **Lookup 2:** to quickly determine whether a given item is already stored in
  the current Earley set, so that it isn't added twice.

- **Lookup 3:** to determine Leo uniqueness in the current Earley set, i.e. is
  this the only item ending in •Y for some symbol Y.

Since completed items will never be found by *lookup 1*, they don't need to be
quickly found once their earleme is complete.  This also suggests they could be
stored separately. For this purpose, we can keep a set of the current earleme's
items (sans derivations) and clear that set when a new earleme is started.

## Derivation links

Recognition can be thought of as a search through the space of partial matches of
the grammar to the input, looking for complete matches. Each earley item
represents a state in that search space.  When the parse is unambiguous, the
states form a binary tree (not a parse tree) with each state being either a
leaf, or reached directly from a pair of other states in one search step. In
general, though, there may be an arbitrary number of state pairs that can be
combined to reach a given state. Regardless of ambiguity, a given state can
participate in multiple pairings.

Let's call these pairs **derivations**.  A derivation of an item X has two parts:
- **predot item:** a completed item in the same earleme as X describing the
  parse(s) of X's predot symbol.
- **prefix item:** an incomplete item in the predot item's start earleme
  describing the parses of the RHS symbols *before* X's predot symbol. The
  postdot symbol of any prefix item of X is always X's predot symbol.

## Derivation set can be represented by the predot earleme

- Earley/Leo item information, aside from derivation set, is small: start earleme, dot position in grammar,
  leo-ness, leo transition/earley postdot symbol.  Probably fits in 2 machine words.
  
- When there are more in the derivation set, we can afford to repeat these two words for each
  derivation pair.  Each Earley item in the pure earley algorithm (each logical Earley item) is
  *potentially* stored multiple times, one for each derivation of that item. It would take a *very*
  ambiguous grammar to make that repetition expensive in memory.
  
- Upon completion of an earley set, its items can be sorted, making it into, effectively a multimap
  from sort key to contiguous sets of derivations.  The sort key can be, in lexicographical order,
  (completeness, symbol, leo-ness, dot position, start position), where symbol is the LHS symbol of
  completed items and otherwise the leo transition/Earley postdot symbol. Finding items with a given
  postdot symbol in a given earley set, during reduction, becomes a binary search in the earley set
  (using start position 0 or ignoring start position).
  
- If we are concerned about the cost of skipping over a long string of derivations for a single
  logical earley item, we can add a slow path where after some constant number of derivations have
  been seen, we'll binary search again for the next start position.
  
- After recognition, the derivations for each logical Earley item X are reconstructed by exploring,
  for each stored item X' corresponding to X, the cross product of:
  - complete items in the same Earley set as X describing the parse of the predot symbol, starting
    in the predot earleme of X'
  - incomplete items in the Earley set of X's start earleme whose postdot symbol is the predot
    symbol of X (this is the same as the reduction lookup).

## Representing Predictions

Many *prediction items* may be generated that never lead anywhere, especially at
the beginning of a parse.  The fact that derivation links to these items never
need to be represented makes it practical to think about storing prediction
items differently from the others.

We can:
- Store each Earley set's predictions as a bitset of rule ordinals.
- Precompute the bitset of rules predicted by each symbol in the grammar
- Union the sets associated with all postdot symbols to get the prediction set.
- For every symbol s, precompute the bitset of initiating rules whose RHS starts
  with s
- When a symbol is s recognized we can intersect its bitset of initiating rules
  with the prediction set to get the rules that will advance.

## Dealing with Leo items

The DRP eliminated by Leo's optimization is always a chain of predot items.

### Representation and lookup

A Leo item is an Earley item plus a transition symbol.  It is looked up by the
the transition symbol rather than by its postdot item.

It would be ideal to keep the Leo items mixed in with the Earley items, sorted
just before any Earley items whose postdot symbol is the Leo item's transition
symbol.

The two problems to be solved are how to represent Leo items and how to 

### Linking

WRITEME

### Reconstruction of missing items.

Leo optimizes away intermediate items on the DRP of right-recursive rules.  
I'd like to avoid creating storage for these items.

## Chart Pruning

What MARPA calls a Bocage is essentially a copy of the recognition chart, but
omitting all items that never participate in a complete parse.  I'm not sure
that's a win for unambiguous/low-ambiguity grammars, so I'd like to at least
have the option to do evaluation directly on the complete chart.
