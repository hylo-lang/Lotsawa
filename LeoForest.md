# Reconstructing Parse Trees in Leo-Optimized Charts

## Definitions

- A **prediction** is an Earley item with the dot at the extreme left of its rule's RHS
- A **completion** is an Earley item with the dot at the extreme right of its rule's RHS
- A **penultimate** is an Earley item whose dot is just before the last symbol of its rule's RHS.

- An Earley item D in Earley set I is a **mainstem of** another Earley item E in Earley set J iff: D
  and E have the same origin and rule, E's dot is one position further along in the rule's RHS than
  D's dot, and there exists a **tributary** completion C for D's postdot symbol with origin I in set
  J.

- A **derivation path** is a sequence of Earley items, starting with a prediction, where each item
  is the mainstem of the next item in the path, ending with a penultimate D.
  
  This sequence is called a **derivation path of** its items' LHS symbol and of any completion E
  whose mainstem is D, whether stored or omitted from the chart.

- The recognizer works by **discovering** Earley items; the first time each item in an Earley set is
  discovered, it is added to that set.
  
  - Discovery of an Earley item E in set J is always the combination of a completion C in set J having
    origin I and LHS X (or a discovered token X covering I-J), with another item in set I, which is
    either:

    - a mainstem of E having postdot symbol X
    - a Leo item L with transition symbol X, memoizing E. In this case L is called a **Leo source** of
      E, and E is called a **Leo product** of L.
    
  - Each such origin I is an element in E's set of **predot origins**.
  
- Given a penultimate M in set J with origin I, its **Leo predecessor**, if any, is the Leo item in
  set I whose transition symbol is E's LHS.
  
- Given a Leo item L in set I with transition symbol T

  - L has a related Earley item M, called the **penultimate of** L, the unique Earley item in set I
    with postdot symbol T.
  - L is called the **Leo item of** M.
  - The sole **predot origin of** L is that of M's Leo predecessor, if any, or else it is I.
  - The presence of L causes any completions with mainstem M to be omitted from the chart. 
  - M is the tail of all derivation paths for completions omitted due to L.
  
## Exploring the Forest

- An exploration is a triple (chart: Chart, C: completion, P: Set of derivation paths

- The start symbol's completion is always present in the chart.

- A completion's derivation paths can all be 

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


## Parse Trees and Derivation Paths

- Given a (stored or omitted) completion C with LHS X with origin I in earleme K,

  - **Trees(X, I, K)** is the set of all parse trees for X over [I, K) (defined recursively below)
  
  - Given a derivation path P=D₀...Dⱼ of C
  
    - Given Dᵤ, an element of P

      - **start(Dᵤ)** is defined to be the earleme of Dᵤ
      - **end(Dᵤ)** is defined to be the earleme of Dᵤ₊₁ if it exists, and K otherwise.
      - **Subtrees(Dᵤ)** is a set of parse trees for Dᵤ's postdot symbol Y.
        - if Y is a terminal, {Y, start(Dᵤ), end(Dᵤ)}
        - otherwise, **Trees(Y, start(Dᵤ), end(Dᵤ))**

    - **ChildTreeTuples(P, K)** is the cross-product of the sets Subtrees(Dᵤ) for u in 0...j
    - **DTrees(P, K)** is defined to be the set of trees having root {X, I, K} and children given by
      an element of ChildTreeTuples(P, K)

  - **Trees(X, I, K)** is defined to be the union of the (disjoint) sets DTrees(P, K) for every
    derivation path P of C
  

