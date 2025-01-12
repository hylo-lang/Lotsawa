import Lotsawa

typealias RawSymbol = Int16

protocol ExposedViaOpaquePointer {
  associatedtype Wrapped
  var opaque: OpaquePointer? { get set }
  init()
}

extension ExposedViaOpaquePointer {

  var value: Wrapped {
    _read {
      yield pointer().pointee
    }
    _modify {
      yield &pointer().pointee
    }
  }

  func mutate<R>(_ mutation: (inout Wrapped)->R) -> R {
    mutation(&pointer().pointee)
  }

  func pointer() -> UnsafeMutablePointer<Wrapped> {
    UnsafeMutableRawPointer(opaque!).assumingMemoryBound(to: Wrapped.self)
  }

  static func create(_ value: Wrapped) -> Self {
    let x = UnsafeMutablePointer<Wrapped>.allocate(capacity: 1)
    x.initialize(to: value)
    var y = Self()
    y.opaque = OpaquePointer(x)
    return y
  }

  func destroy() {
    let p = UnsafeMutableRawPointer(opaque!)
    let x = p.assumingMemoryBound(to: Wrapped.self)
    x.deinitialize(count: 1)
    x.deallocate()
  }

  func copy() -> Self {
    Self.create(value)
  }

}

extension LotsawaGrammar: ExposedViaOpaquePointer {
  typealias Wrapped = Grammar<RawSymbol>

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_grammar_create")
func lotsawa_grammar_new(recognizing s: CInt) -> LotsawaGrammar {
  LotsawaGrammar.create(.init(recognizing: Symbol(id: .init(s))))
}

@_cdecl("lotsawa_grammar_destroy")
func lotsawa_grammar_destroy(_ g: LotsawaGrammar)  {
  g.destroy()
}

@_cdecl("lotsawa_grammar_copy")
func lotsawa_grammar_copy(_ g: LotsawaGrammar) -> LotsawaGrammar {
  g.copy()
}

@_cdecl("lotsawa_grammar_add_rule")
func lotsawa_grammar_add_rule(
  g: LotsawaGrammar, lhs: LotsawaSymbol,
  rhsCount: CInt, rhsBase: UnsafePointer<LotsawaSymbol>
) -> LotsawaRule {
  let rhs = UnsafeBufferPointer(start: rhsBase, count: Int(rhsCount)).lazy.map(Symbol.init(id:))
  return g.mutate { $0.addRule(lhs: Symbol(id: lhs), rhs: rhs).ordinal }
}

extension LotsawaPreprocessedGrammar: ExposedViaOpaquePointer {
  typealias Wrapped = PreprocessedGrammar<RawSymbol>

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_preprocessed_grammar_create")
func lotsawa_preprocessed_grammar_new(g: LotsawaPreprocessedGrammar) -> LotsawaPreprocessedGrammar {
  LotsawaPreprocessedGrammar.create(g.value)
}

@_cdecl("lotsawa_preprocessed_grammar_destroy")
func lotsawa_preprocessed_grammar_destroy(_ g: LotsawaPreprocessedGrammar)  {
  g.destroy()
}

@_cdecl("lotsawa_preprocessed_grammar_copy")
func lotsawa_preprocessed_grammar_copy(_ g: LotsawaPreprocessedGrammar) -> LotsawaPreprocessedGrammar {
  g.copy()
}

extension LotsawaRecognizer: ExposedViaOpaquePointer {
  typealias Wrapped = Recognizer<RawSymbol>

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_recognizer_create")
func lotsawa_recognizer_new(_ g: LotsawaPreprocessedGrammar) -> LotsawaRecognizer {
  LotsawaRecognizer.create(Recognizer(g.value))
}

@_cdecl("lotsawa_recognizer_destroy")
func lotsawa_recognizer_destroy(_ r: LotsawaRecognizer)  {
  r.destroy()
}

@_cdecl("lotsawa_recognizer_copy")
func lotsawa_recognizer_copy(_ r: LotsawaRecognizer) -> LotsawaRecognizer {
  r.copy()
}

@_cdecl("lotsawa_recognizer_initialize")
func lotsawa_recognizer_initialize(_ r: LotsawaRecognizer) {
  r.mutate { $0.initialize() }
}

@_cdecl("lotsawa_recognizer_discover")
func lotsawa_recognizer_discover(_ r: LotsawaRecognizer, symbol: LotsawaSymbol, startingAt start: LotsawaSourcePosition) {
  r.mutate { $0.discover(Symbol(id: symbol), startingAt: start) }
}

@_cdecl("lotsawa_recognizer_finish_earleme")
func lotsawa_recognizer_finish_earleme(_ r: LotsawaRecognizer) -> Bool {
  r.mutate { $0.finishEarleme() }
}

@_cdecl("lotsawa_recognizer_has_complete_parse")
func lotsawa_recognizer_has_complete_parse(_ r: LotsawaRecognizer) -> Bool {
  r.value.hasCompleteParse()
}

/*
static void marpa_set_grammar( YaepAllocator * alloc, Marpa_Config * marpa_configuration, Marpa_Grammar * g, const char * description) {
  int i;
  Marpa_Error_Code mcode;
  struct sym *sym, *tab_sym, *lhs_sym;
  const char *lhs, **rhs;
  const char *error_string;
  Marpa_Symbol_ID first, rhs_ids[100]; /* enough for the longest rule */

  if ( set_sgrammar( alloc, description ) ) {
      printf ("error in description");
      exit (1);
    }
  sym_table = create_hash_table( alloc, 50000, sym_hash, sym_eq );
  marpa_c_init (marpa_configuration);
  *g = marpa_g_new (marpa_configuration);
  if (!*g)
    {
      Marpa_Error_Code code = marpa_c_error (marpa_configuration, &error_string);
      printf ("marpa_g_new returned %d: %s", code, error_string);
      exit (1);
    }
  while ((sym = sread_terminal ()) != NULL)
    if (insert_symbol (sym->repr, sym) == sym)
      (sym->id = marpa_g_symbol_new (*g)) >= 0 || fail ("marpa_g_symbol_new", *g);
  first = -1;
  while ((lhs = sread_rule (&rhs)) != NULL)
    {
      lhs_sym = yaep_malloc( alloc, sizeof( struct sym ) );
      lhs_sym->repr = lhs;
      if ((tab_sym = insert_symbol (lhs, lhs_sym)) == lhs_sym)
	(lhs_sym->id = marpa_g_symbol_new (*g)) >= 0 || fail ("marpa_g_symbol_new", *g);
      else
	{
	  yaep_free( alloc, lhs_sym );
	  lhs_sym = tab_sym;
	}
      if (first < 0)
	first = tab_sym->id;
      for (i = 0;; i++)
	{
	  if (rhs[i] == NULL)
	    break;
	  sym = yaep_malloc( alloc, sizeof( struct sym ) );
	  sym->repr = rhs[i];
	  if ((tab_sym = insert_symbol (rhs[i], sym)) == sym)
	    (sym->id = marpa_g_symbol_new (*g)) >= 0 || fail ("marpa_g_symbol_new", *g);
	  else
	    yaep_free( alloc, sym );
	  rhs_ids[i] = tab_sym->id;
	}
      (marpa_g_rule_new (*g, lhs_sym->id, rhs_ids, i) >= 0) || fail ("marpa_g_rule_new", *g);
    }
  (marpa_g_start_symbol_set (*g, first) >= 0) || fail ("marpa_g_start_symbol_set", *g);
  if (marpa_g_precompute (*g) < 0)
    fail ("marpa_g_precompute", *g);
}

main (int argc, char **argv)
{
  ticker_t t;
  Marpa_Config marpa_configuration;
  Marpa_Grammar g;
#ifdef linux
  char *start = sbrk (0);
#endif

  YaepAllocator * alloc = yaep_alloc_new( NULL, NULL, NULL, NULL );
  if ( alloc == NULL ) {
    exit( 1 );
  }
  OS_CREATE( mem_os, alloc, 0 );
  initiate_typedefs( alloc );
  curr = NULL;
  marpa_set_grammar( alloc, &marpa_configuration, &g, description );
  setup_tokens ();
  store_lexs( alloc );
  t = create_ticker ();
  marpa_parse (&g);
  marpa_free_grammar (&g);
#ifdef linux
  printf ("parse time %.2f, memory=%.1fkB\n", active_time (t),
          ((char *) sbrk (0) - start) / 1024.);
#else
  printf ("parse time %.2f\n", active_time (t));
#endif
  OS_DELETE (mem_os);
  yaep_alloc_del( alloc );
  exit (0);
}

 */
