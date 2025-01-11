typedef struct LotsawaGrammar {
  struct LotsawaGrammar_* value_;
} LotsawaGrammar;

struct LotsawaRule { int id; };

extern LotsawaGrammar lotsawa_grammar_new (int);
