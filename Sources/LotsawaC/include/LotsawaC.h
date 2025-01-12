#include <stdint.h>
#include <stdbool.h>

typedef int LotsawaInt;

typedef struct LotsawaPreprocessedGrammar {
  struct LotsawaOpaque* opaque_;
} LotsawaPreprocessedGrammar;

typedef struct LotsawaGrammar {
  struct LotsawaOpaque* opaque_;
} LotsawaGrammar;

typedef struct LotsawaRecognizer {
  struct LotsawaOpaque* opaque_;
} LotsawaRecognizer;

typedef int16_t LotsawaSymbol;
typedef uint16_t LotsawaRule;
typedef uint16_t LotsawaGrammarPosition;
typedef uint16_t LotsawaGrammarSize;
typedef uint32_t LotsawaSourcePosition;

extern LotsawaGrammar lotsawa_grammar_create (int);
extern LotsawaGrammar lotsawa_grammar_copy (LotsawaGrammar);
extern void lotsawa_grammar_destroy (LotsawaGrammar);
//extern uint16_t lotsawa_grammar_size(LotsawaGrammar);
//extern LotsawaRule lotsawa_grammar_nth_rule(int);
extern LotsawaRule lotsawa_grammar_add_rule(LotsawaGrammar, LotsawaSymbol, int, LotsawaSymbol*);

extern LotsawaPreprocessedGrammar lotsawa_preprocessed_grammar_create (LotsawaGrammar);
extern LotsawaPreprocessedGrammar lotsawa_preprocessed_grammar_copy (LotsawaPreprocessedGrammar);
extern void lotsawa_preprocessed_grammar_destroy (LotsawaPreprocessedGrammar);

extern LotsawaRecognizer lotsawa_recognizer_create (LotsawaPreprocessedGrammar);
extern LotsawaRecognizer lotsawa_recognizer_copy (LotsawaRecognizer);
extern void lotsawa_recognizer_destroy (LotsawaRecognizer);
extern void lotsawa_recognizer_initialize (LotsawaRecognizer);
extern void lotsawa_recognizer_discover (LotsawaRecognizer, LotsawaSymbol, LotsawaSourcePosition);
extern bool lotsawa_recognizer_finish_earleme (LotsawaRecognizer);
extern bool lotsawa_recognizer_has_complete_parse (LotsawaRecognizer);
