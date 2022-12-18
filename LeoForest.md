# Reconstructing Parse Trees in Leo-Optimized Charts

## Definitions

- A **prediction** is an Earley item with the dot at the extreme left of its rule's RHS
- A **completion** is an Earley item with the dot at the extreme right of its rule's RHS
- A **penultimate** is an Earley item whose dot is just before the last symbol of its rule's RHS.

- An Earley item D in Earley set I is a **predecessor of** another Earley item E in Earley set J
  iff: D and E have the same origin and rule, E's dot is one position further along in the rule's
  RHS than D's dot, and there exists a completion C for D's postdot symbol with origin I in set J.

- A **derivation path** is a sequence of Earley items, starting with a prediction, where each item
  is the predecessor of the next item in the path, ending with a penultimate D.  
  
  This sequence is called a **derivation path of**:
  - its items' LHS symbol and 
  - any completion E whose predecessor is D

- The recognizer works by **discovering** Earley items; the first time each item in an Earley set is
  discovered, it is added to that set.
  
  - Discovery of an Earley item E in set J is always the combination of a completion C in set J having
    origin I and LHS X (or a discovered token X covering I-J), with another item in set I, which is
    either:

    - a predecessor of E having postdot symbol X
    - a Leo item L with transition symbol X, memoizing E. In this case L is called a **Leo source** of
      E, and E is called a **Leo product** of L.
    
  - These origins I become part of E's set of **predot origins**.
  
- Given a penultimate M in set J with origin I, its **Leo predecessor**, if any, is the Leo item in
  set I whose transition symbol is E's LHS.
  
- Given a Leo item L in set I with transition symbol T

  - L has a (unique) related Earley item M in set I, with postdot symbol T, called the **penultimate
    of** L.
  - L is called the **Leo item of** M.
  - The sole **predot origin of** L is that of M's Leo predecessor, if any, or else it is I.
  - The presence of L causes any completions with predecessor M to be omitted from the chart. 
  - M is  the tail of all derivation paths for completions omitted due to L.

## Parse Trees and Derivation Paths

The set of parse trees for a completion (stored or omitted) is its set of derivation paths

Given a 

- When D is an Earley item
  - its postdot symbol is the LHS of C's rule and the predot symbol of E
  - D is the tail of (some) derivation paths for E ending in set P.
  
- When D is a Leo item L
  - its transition symbol T is the LHS of C's rule.
  - The completion in set J of L's derivation tail was omitted from the chart and notionally
    participated in producing E, either directly or indirectly.
  - Derivation paths for E associated with D can be discovered as follows:
  
- When D is a Leo item, E has a 
  
- The predot origin produced when L's is used is I 
-
- Every Leo item in a set I has a **tail**.  The tail is the item that, were it not for the presence
  of the Leo item, would be combined with a recognition of the Leo item's transition symbol to produce
