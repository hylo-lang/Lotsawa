import LotsawaFrontend

import XCTest

class BisonTests: XCTestCase {

  func testYEAP() throws {
    let g = try BisonGrammar<Int16>(yeapGrammarSource)
    _ = g
  }

  func testANSIc() throws {
    let g = try BisonGrammar<Int16>(ansiCGrammarSource)
    _ = g
  }

  func testYEAPtest() throws {
    let g = try BisonGrammar<Int16>(yeapTestSource)
    _ = g
  }

}


let yeapGrammarSource =
#"""
/*
   YAEP (Yet Another Earley Parser)

   Copyright (c) 1997-2018  Vladimir Makarov <vmakarov@gcc.gnu.org>

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

/* This is interface file of the code which transforms grammar
   description given by string into representation which can be used
   by YAEP.  So the code implements functions read_terminal
   and read_rule imported by YAEP.  */

%{

#include <ctype.h>

#include <assert.h>

/* The following is necessary if we use YAEP with byacc/bison/msta
   parser. */

#define yylval yaep_yylval
#define yylex yaep_yylex
#define yyerror yaep_yyerror
#define yyparse yaep_yyparse
#define yychar yaep_yychar
#define yynerrs yaep_yynerrs
#define yydebug yaep_yydebug
#define yyerrflag yaep_yyerrflag
#define yyssp yaep_yyssp
#define yyval yaep_yyval
#define yyvsp yaep_yyvsp
#define yylhs yaep_yylhs
#define yylen yaep_yylen
#define yydefred yaep_yydefred
#define yydgoto yaep_yydgoto
#define yysindex yaep_yysindex
#define yyrindex yaep_yyrindex
#define yygindex yaep_yygindex
#define yytable yaep_yytable
#define yycheck yaep_yycheck
#define yyss yaep_yyss
#define yyvs yaep_yyvs

/* The following structure describes syntax grammar terminal. */
struct sterm
{
  char *repr; /* terminal representation. */
  int code;   /* terminal code. */
  int num;    /* order number. */
};

/* The following structure describes syntax grammar rule. */
struct srule
{
  /* The following members are left hand side nonterminal
     representation and abstract node name (if any) for the rule. */
  char *lhs, *anode;
  /* The following is the cost of given anode if it is defined.
     Otherwise, the value is zero. */
  int anode_cost;
  /* The following is length of right hand side of the rule. */
  int rhs_len;
  /* Terminal/nonterminal representations in RHS of the rule.  The
     array end marker is NULL. */
  char **rhs;
  /* The translations numbers. */
  int *trans;
};

/* The following vlos contain all syntax terminal and syntax rule
   structures. */
#ifndef __cplusplus
static vlo_t sterms, srules;
#else
static vlo_t *sterms, *srules;
#endif

/* The following contain all right hand sides and translations arrays.
   See members rhs, trans in structure `rule'. */
#ifndef __cplusplus
static os_t srhs, strans;
#else
static os_t *srhs, *strans;
#endif

/* The following is cost of the last translation which contains an
   abstract node. */
static int anode_cost;

/* This variable is used in yacc action to process alternatives. */
static char *slhs;

/* Forward declarations. */
extern int yyerror (const char *str);
extern int yylex (void);
extern int yyparse (void);

%}

%union
  {
    void *ref;
    int num;
  }

%token <ref> IDENT SEM_IDENT CHAR
%token <num> NUMBER
%token TERM

%type <ref> trans
%type <num> number

%%

file : file terms opt_sem
     | file rule
     | terms opt_sem
     | rule
     ;

opt_sem :
        | ';'
        ;

terms : terms IDENT number
        {
	  struct sterm term;

	  term.repr = (char *) $2;
	  term.code = $3;
          term.num = VLO_LENGTH (sterms) / sizeof (term);
	  VLO_ADD_MEMORY (sterms, &term, sizeof (term));
	}
      | TERM
      ;

number :            {$$ = -1;}
       | '=' NUMBER {$$ = $2;}
       ;

rule : SEM_IDENT {slhs = (char *) $1;} rhs opt_sem
     ;

rhs : rhs '|' alt
    | alt
    ;

alt : seq trans
      {
	struct srule rule;
	int end_marker = -1;

	OS_TOP_ADD_MEMORY (strans, &end_marker, sizeof (int));
	rule.lhs = slhs;
	rule.anode = (char *) $2;
	rule.anode_cost = (rule.anode == NULL ? 0 : anode_cost);
	rule.rhs_len = OS_TOP_LENGTH (srhs) / sizeof (char *);
	OS_TOP_EXPAND (srhs, sizeof (char *));
	rule.rhs = (char **) OS_TOP_BEGIN (srhs);
	rule.rhs [rule.rhs_len] = NULL;
	OS_TOP_FINISH (srhs);
	rule.trans = (int *) OS_TOP_BEGIN (strans);
	OS_TOP_FINISH (strans);
        VLO_ADD_MEMORY (srules, &rule, sizeof (rule));
      }
    ;

seq : seq IDENT
       {
	 char *repr = (char *) $2;

	 OS_TOP_ADD_MEMORY (srhs, &repr, sizeof (repr));
       }
    | seq CHAR
       {
	  struct sterm term;

	  term.repr = (char *) $2;
	  term.code = term.repr [1];
          term.num = VLO_LENGTH (sterms) / sizeof (term);
	  VLO_ADD_MEMORY (sterms, &term, sizeof (term));
	  OS_TOP_ADD_MEMORY (srhs, &term.repr, sizeof (term.repr));
       }
    |
    ;

trans :     {$$ = NULL;}
      | '#' {$$ = NULL;}
      | '#' NUMBER
        {
	  int symb_num = $2;

  	  $$ = NULL;
	  OS_TOP_ADD_MEMORY (strans, &symb_num, sizeof (int));
        }
      | '#' '-'
        {
	  int symb_num = YAEP_NIL_TRANSLATION_NUMBER;

  	  $$ = NULL;
	  OS_TOP_ADD_MEMORY (strans, &symb_num, sizeof (int));
        }
      | '#' IDENT cost '(' numbers ')'
        {
	  $$ = $2;
	}
      | '#' IDENT cost
        {
	  $$ = $2;
	}
      ;

numbers :
        | numbers NUMBER
          {
	    int symb_num = $2;

	    OS_TOP_ADD_MEMORY (strans, &symb_num, sizeof (int));
          }
        | numbers '-'
          {
	    int symb_num = YAEP_NIL_TRANSLATION_NUMBER;

	    OS_TOP_ADD_MEMORY (strans, &symb_num, sizeof (int));
          }
        ;

cost :         { anode_cost = 1;}
     | NUMBER  { anode_cost = $1; }
     ;
%%
/* The following is current input character of the grammar
   description. */
static const char *curr_ch;

/* The following is current line number of the grammar description. */
static int ln;

/* The following contains all representation of the syntax tokens. */
#ifndef __cplusplus
static os_t stoks;
#else
static os_t *stoks;
#endif

/* The following is number of syntax terminal and syntax rules being
   read. */
static int nsterm, nsrule;

/* The following implements lexical analyzer for yacc code. */
int
yylex (void)
{
  int c;
  int n_errs = 0;

  for (;;)
    {
      c = *curr_ch++;
      switch (c)
	{
	case '\0':
	  return 0;
	case '\n':
	  ln++;
	case '\t':
	case ' ':
	  break;
	case '/':
	  c = *curr_ch++;
	  if (c != '*' && n_errs == 0)
	    {
	      n_errs++;
	      curr_ch--;
	      yyerror ("invalid input character /");
	    }
	  for (;;)
	    {
	      c = *curr_ch++;
	      if (c == '\0')
		yyerror ("unfinished comment");
	      if (c == '\n')
		ln++;
	      if (c == '*')
		{
		  c = *curr_ch++;
		  if (c == '/')
		    break;
		  curr_ch--;
		}
	    }
	  break;
	case '=':
	case '#':
	case '|':
	case ';':
	case '-':
	case '(':
	case ')':
	  return c;
	case '\'':
	  OS_TOP_ADD_BYTE (stoks, '\'');
	  yylval.num = *curr_ch++;
	  OS_TOP_ADD_BYTE (stoks, yylval.num);
	  if (*curr_ch++ != '\'')
	    yyerror ("invalid character");
	  OS_TOP_ADD_BYTE (stoks, '\'');
	  OS_TOP_ADD_BYTE (stoks, '\0');
	  yylval.ref = OS_TOP_BEGIN (stoks);
	  OS_TOP_FINISH (stoks);
	  return CHAR;
	default:
	  if (isalpha (c) || c == '_')
	    {
	      OS_TOP_ADD_BYTE (stoks, c);
	      while ((c = *curr_ch++) != '\0' && (isalnum (c) || c == '_'))
		OS_TOP_ADD_BYTE (stoks, c);
	      curr_ch--;
	      OS_TOP_ADD_BYTE (stoks, '\0');
	      yylval.ref = OS_TOP_BEGIN (stoks);
	      if (strcmp ((char *) yylval.ref, "TERM") == 0)
		{
		  OS_TOP_NULLIFY (stoks);
		  return TERM;
		}
	      OS_TOP_FINISH (stoks);
	      while ((c = *curr_ch++) != '\0')
		if (c == '\n')
		  ln++;
		else if (c != '\t' && c != ' ')
		  break;
	      if (c != ':')
		curr_ch--;
	      return (c == ':' ? SEM_IDENT : IDENT);
	    }
	  else if (isdigit (c))
	    {
	      yylval.num = c - '0';
	      while ((c = *curr_ch++) != '\0' && isdigit (c))
		yylval.num = yylval.num * 10 + (c - '0');
	      curr_ch--;
	      return NUMBER;
	    }
	  else
	    {
	      n_errs++;
	      if (n_errs == 1)
		{
		  char str[100];

		  if (isprint (c))
		    {
		      sprintf (str, "invalid input character '%c'", c);
		      yyerror (str);
		    }
		  else
		    yyerror ("invalid input character");
		}
	    }
	}
    }
}


/* The following implements syntactic error diagnostic function yacc
   code. */
int
yyerror (const char *str)
{
  yaep_error (YAEP_DESCRIPTION_SYNTAX_ERROR_CODE,
	      "description syntax error on ln %d", ln);
  return 0;
}

/* The following function is used to sort array of syntax terminals by
   names. */
static int
sterm_name_cmp (const void *t1, const void *t2)
{
  return strcmp (((struct sterm *) t1)->repr, ((struct sterm *) t2)->repr);
}

/* The following function is used to sort array of syntax terminals by
   order number. */
static int
sterm_num_cmp (const void *t1, const void *t2)
{
  return ((struct sterm *) t1)->num - ((struct sterm *) t2)->num;
}

static void free_sgrammar (void);

/* The following is major function which parses the description and
   transforms it into IR. */
static int
set_sgrammar (struct grammar *g, const char *grammar)
{
  int i, j, num;
  struct sterm *term, *prev, *arr;
  int code = 256;

  ln = 1;
  if ((code = setjmp (error_longjump_buff)) != 0)
    {
      free_sgrammar ();
      return code;
    }
  OS_CREATE (stoks, g->alloc, 0);
  VLO_CREATE (sterms, g->alloc, 0);
  VLO_CREATE (srules, g->alloc, 0);
  OS_CREATE (srhs, g->alloc, 0);
  OS_CREATE (strans, g->alloc, 0);
  curr_ch = grammar;
  yyparse ();
  /* sort array of syntax terminals by names. */
  num = VLO_LENGTH (sterms) / sizeof (struct sterm);
  arr = (struct sterm *) VLO_BEGIN (sterms);
  qsort (arr, num, sizeof (struct sterm), sterm_name_cmp);
  /* Check different codes for the same syntax terminal and remove
     duplicates. */
  for (i = j = 0, prev = NULL; i < num; i++)
    {
      term = arr + i;
      if (prev == NULL || strcmp (prev->repr, term->repr) != 0)
	{
	  prev = term;
	  arr[j++] = *term;
	}
      else if (term->code != -1 && prev->code != -1
	       && prev->code != term->code)
	{
	  char str[YAEP_MAX_ERROR_MESSAGE_LENGTH / 2];

	  strncpy (str, prev->repr, sizeof (str));
	  str[sizeof (str) - 1] = '\0';
	  yaep_error (YAEP_REPEATED_TERM_CODE,
		      "term %s described repeatedly with different code",
		      str);
	}
      else if (prev->code != -1)
	prev->code = term->code;
    }
  VLO_SHORTEN (sterms, (num - j) * sizeof (struct sterm));
  num = j;
  /* sort array of syntax terminals by order number. */
  qsort (arr, num, sizeof (struct sterm), sterm_num_cmp);
  /* Assign codes. */
  for (i = 0; i < num; i++)
    {
      term = (struct sterm *) VLO_BEGIN (sterms) + i;
      if (term->code < 0)
	term->code = code++;
    }
  nsterm = nsrule = 0;
  return 0;
}

/* The following frees IR. */
static void
free_sgrammar (void)
{
  OS_DELETE (strans);
  OS_DELETE (srhs);
  VLO_DELETE (srules);
  VLO_DELETE (sterms);
  OS_DELETE (stoks);
}

/* The following two functions implements functions used by YAEP. */
static const char *
sread_terminal (int *code)
{
  struct sterm *term;
  const char *name;

  term = &((struct sterm *) VLO_BEGIN (sterms))[nsterm];
  if ((char *) term >= (char *) VLO_BOUND (sterms))
    return NULL;
  *code = term->code;
  name = term->repr;
  nsterm++;
  return name;
}

static const char *
sread_rule (const char ***rhs, const char **abs_node, int *anode_cost,
	    int **transl)
{
  struct srule *rule;
  const char *lhs;

  rule = &((struct srule *) VLO_BEGIN (srules))[nsrule];
  if ((char *) rule >= (char *) VLO_BOUND (srules))
    return NULL;
  lhs = rule->lhs;
  *rhs = (const char **) rule->rhs;
  *abs_node = rule->anode;
  *anode_cost = rule->anode_cost;
  *transl = rule->trans;
  nsrule++;
  return lhs;
}

/* The following function parses grammar desrciption. */
#ifdef __cplusplus
static
#endif
  int
yaep_parse_grammar (struct grammar *g, int strict_p, const char *description)
{
  int code;

  assert (g != NULL);
  if ((code = set_sgrammar (g, description)) != 0)
    return code;
  code = yaep_read_grammar (g, strict_p, sread_terminal, sread_rule);
  free_sgrammar ();
  return code;
}
"""#

let ansiCGrammarSource = #"""
/*
   YAEP (Yet Another Earley Parser)

   Copyright (c) 1997-2018  Vladimir Makarov <vmakarov@gcc.gnu.org>

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

%{
#define YYSTYPE string_t
%}

%token IDENTIFIER CONSTANT STRING_LITERAL SIZEOF
%token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token XOR_ASSIGN OR_ASSIGN TYPE_NAME INLINE

%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
%token STRUCT UNION ENUM ELIPSIS

%token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%start file
%%

primary_expr
	: identifier
	| CONSTANT
	| STRING_LITERAL
	| '(' expr ')'
	;

postfix_expr
	: primary_expr
	| postfix_expr '[' expr ']'
	| postfix_expr '(' ')'
	| postfix_expr '(' argument_expr_list ')'
	| postfix_expr '.' identifier
	| postfix_expr PTR_OP identifier
	| postfix_expr INC_OP
	| postfix_expr DEC_OP
	;

argument_expr_list
	: assignment_expr
	| argument_expr_list ',' assignment_expr
	;

unary_expr
	: postfix_expr
	| INC_OP unary_expr
	| DEC_OP unary_expr
	| unary_operator cast_expr
	| SIZEOF unary_expr
	| SIZEOF '(' type_name ')'
	;

unary_operator
	: '&'
	| '*'
	| '+'
	| '-'
	| '~'
	| '!'
	;

cast_expr
	: unary_expr
	| '(' type_name ')' cast_expr
	;

multiplicative_expr
	: cast_expr
	| multiplicative_expr '*' cast_expr
	| multiplicative_expr '/' cast_expr
	| multiplicative_expr '%' cast_expr
	;

additive_expr
	: multiplicative_expr
	| additive_expr '+' multiplicative_expr
	| additive_expr '-' multiplicative_expr
	;

shift_expr
	: additive_expr
	| shift_expr LEFT_OP additive_expr
	| shift_expr RIGHT_OP additive_expr
	;

relational_expr
	: shift_expr
	| relational_expr '<' shift_expr
	| relational_expr '>' shift_expr
	| relational_expr LE_OP shift_expr
	| relational_expr GE_OP shift_expr
	;

equality_expr
	: relational_expr
	| equality_expr EQ_OP relational_expr
	| equality_expr NE_OP relational_expr
	;

and_expr
	: equality_expr
	| and_expr '&' equality_expr
	;

exclusive_or_expr
	: and_expr
	| exclusive_or_expr '^' and_expr
	;

inclusive_or_expr
	: exclusive_or_expr
	| inclusive_or_expr '|' exclusive_or_expr
	;

logical_and_expr
	: inclusive_or_expr
	| logical_and_expr AND_OP inclusive_or_expr
	;

logical_or_expr
	: logical_and_expr
	| logical_or_expr OR_OP logical_and_expr
	;

conditional_expr
	: logical_or_expr
	| logical_or_expr '?' logical_or_expr ':' conditional_expr
	;

assignment_expr
	: conditional_expr
	| unary_expr assignment_operator assignment_expr
	;

assignment_operator
	: '='
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN
	;

expr
	: assignment_expr
	| expr ',' assignment_expr
	;

constant_expr
	: conditional_expr
	;

declaration
	: declaration_specifiers ';'
            {typedef_flag = NULL;}
	| declaration_specifiers init_declarator_list ';'
            {typedef_flag = NULL;}
	;


declaration_specifiers
	: storage_class_specifier
	| storage_class_specifier declaration_specifiers
	| type_specifier
	| type_specifier declaration_specifiers
	;

init_declarator_list
	: init_declarator
	| init_declarator_list ',' init_declarator
	;

init_declarator
	: declarator
	| declarator '=' initializer
	;

storage_class_specifier
	: TYPEDEF         {typedef_flag = (string_t) 64;}
	| EXTERN
	| STATIC
	| AUTO
	| REGISTER
        | INLINE
	;

type_specifier
	: CHAR
	| SHORT
	| INT
	| LONG
	| SIGNED
	| UNSIGNED
	| FLOAT
	| DOUBLE
	| CONST
	| VOLATILE
	| VOID
	| struct_or_union_specifier
	| enum_specifier
	| TYPE_NAME
	;

struct_or_union_specifier
	: struct_or_union after_struct identifier  {after_struct_flag = 0;}
             '{' {$$ = typedef_flag;level++;typedef_flag = NULL;}
             struct_declaration_list {typedef_flag = $6;level--;} '}'
	| struct_or_union after_struct  {after_struct_flag = 0;}
             '{' {$$ = typedef_flag;level++;typedef_flag = NULL;}
                              struct_declaration_list
                              {typedef_flag = $5;level--;} '}'
	| struct_or_union after_struct identifier  {after_struct_flag = 0;}
	;

after_struct : {after_struct_flag = 1;}
             ;

struct_or_union
	: STRUCT
	| UNION
	;

struct_declaration_list
	: struct_declaration
	| struct_declaration_list struct_declaration
	;

struct_declaration
	: type_specifier_list struct_declarator_list ';'
	;

struct_declarator_list
	: struct_declarator
	| struct_declarator_list ',' struct_declarator
	;

struct_declarator
	: declarator
	| ':' constant_expr
	| declarator ':' constant_expr
	;

enum_specifier
	: ENUM '{' enumerator_list '}'
	| ENUM identifier '{' enumerator_list '}'
	| ENUM identifier
	;

enumerator_list
	: enumerator
	| enumerator_list ',' enumerator
	;

enumerator
	: identifier
	| identifier '=' constant_expr
	;

declarator
	: declarator2
	| pointer declarator2
	;

declarator2
	: identifier                  {if (typedef_flag != NULL)
                                         add_typedef ((char *) $1, level);}
	| '(' declarator ')'
	| declarator2 '[' ']'
	| declarator2 '[' constant_expr ']'
	| declarator2 '(' ')'
	| declarator2 '(' parameter_type_list ')'
	| declarator2 '(' parameter_identifier_list ')'
	;

pointer
	: '*'
	| '*' type_specifier_list
	| '*' pointer
	| '*' type_specifier_list pointer
	;

type_specifier_list
	: type_specifier
	| type_specifier_list type_specifier
	;

parameter_identifier_list
	: identifier_list
	| identifier_list ',' ELIPSIS
	;

identifier_list
	: identifier
	| identifier_list ',' identifier
	;

parameter_type_list
	: parameter_list
	| parameter_list ',' ELIPSIS
	;

parameter_list
	: parameter_declaration
	| parameter_list ',' parameter_declaration
	;

parameter_declaration
	: type_specifier_list declarator
	| type_name
	;

type_name
	: type_specifier_list
	| type_specifier_list abstract_declarator
	;

abstract_declarator
	: pointer
	| abstract_declarator2
	| pointer abstract_declarator2
	;

abstract_declarator2
	: '(' abstract_declarator ')'
	| '[' ']'
	| '[' constant_expr ']'
	| abstract_declarator2 '[' ']'
	| abstract_declarator2 '[' constant_expr ']'
	| '(' ')'
	| '(' parameter_type_list ')'
	| abstract_declarator2 '(' ')'
	| abstract_declarator2 '(' parameter_type_list ')'
	;

initializer
	: assignment_expr
	| '{' initializer_list '}'
	| '{' initializer_list ',' '}'
	;

initializer_list
	: initializer
	| initializer_list ',' initializer
	;

statement
	: labeled_statement
	| compound_statement
	| expression_statement
	| selection_statement
	| iteration_statement
	| jump_statement
	;

labeled_statement
	: identifier ':' statement
	| CASE constant_expr ':' statement
	| DEFAULT ':' statement
	;

compound_statement
	: '{' '}'
	| '{' incr_level statement_list {level--;} '}'
	| '{' incr_level declaration_list {level--;} '}'
	| '{' incr_level declaration_list statement_list {level--;} '}'
	;

/* mine */
incr_level : {level++;}
           ;

declaration_list
	: declaration
	| declaration_list declaration
	;

statement_list
	: statement
	| statement_list statement
	;

expression_statement
	: ';'
	| expr ';'
	;

selection_statement
	: IF '(' expr ')' statement
	| IF '(' expr ')' statement ELSE statement
	| SWITCH '(' expr ')' statement
	;

iteration_statement
	: WHILE '(' expr ')' statement
	| DO statement WHILE '(' expr ')' ';'
	| FOR '(' ';' ';' ')' statement
	| FOR '(' ';' ';' expr ')' statement
	| FOR '(' ';' expr ';' ')' statement
	| FOR '(' ';' expr ';' expr ')' statement
	| FOR '(' expr ';' ';' ')' statement
	| FOR '(' expr ';' ';' expr ')' statement
	| FOR '(' expr ';' expr ';' ')' statement
	| FOR '(' expr ';' expr ';' expr ')' statement
	;

jump_statement
	: GOTO identifier ';'
	| CONTINUE ';'
	| BREAK ';'
	| RETURN ';'
	| RETURN expr ';'
	;

file
	: external_definition
	| file external_definition
	;

external_definition
	: function_definition
	| declaration
	;

function_definition
	: declarator function_body
	| declaration_specifiers declarator function_body
	;

function_body
	: compound_statement
	| declaration_list compound_statement
	;

identifier
	: IDENTIFIER  {$$ = $1;}
	;
%%

#include <stdio.h>

extern int column;
extern int line;

yyerror(s)
char *s;
{
   fprintf (stderr, "syntax error line - %d, column - %d\n", line, column + 1);
}
"""#


let yeapTestSource = #"""
/*
   YAEP (Yet Another Earley Parser)

   Copyright (c) 1997-2018  Vladimir Makarov <vmakarov@gcc.gnu.org>

   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

/* This file contains a code which transforms grammar
   description given by string into Marpa grammar.  Then the parsing
   is done without building an abstract tree. */

%{

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include "allocate.h"
#include "vlobject.h"
#include "objstack.h"
#include "hashtab.h"
#include "ticker.h"
#include "marpa.h"


#include <assert.h>

/* The following structure describes syntax grammar terminal. */
struct sym
{
  const char *repr; /* terminal representation. */
  Marpa_Symbol_ID id;   /* terminal id. */
  int num;    /* order number. */
};

/* The following structure describes syntax grammar rule. */
struct srule
{
  /* The following members are left hand side nonterminal
     representation. */
  char *lhs;
  /* The following is length of right hand side of the rule. */
  int rhs_len;
  /* Terminal/nonterminal representations in RHS of the rule.  The
     array end marker is NULL. */
  char **rhs;
};

/* The following vlos contain all syntax terminal and syntax rule
   structures. */
static vlo_t sterms, srules;

/* The following contain all right hand sides arrays.
   See members rhs in structure `rule'. */
static os_t srhs;

/* This variable is used in yacc action to process alternatives. */
static char *slhs;

#undef yylex
#define yylex marpa_yylex

/* Forward declarations. */
extern int yyerror (const char *str);
extern int yylex (void);
extern int yyparse (void);

%}

%union
  {
    void *ref;
    int num;
  }

%token <ref> IDENT SEMICOLON_IDENT CHAR_TERM
%token TERM

%%

file : file terms opt_sem
     | file rule
     | terms opt_sem
     | rule
     ;

opt_sem :
        | ';'
        ;

terms : terms IDENT
        {
	  struct sym term;

	  term.repr = (char *) $2;
          term.num = VLO_LENGTH (sterms) / sizeof (term);
	  VLO_ADD_MEMORY (sterms, &term, sizeof (term));
	}
      | TERM
      ;

rule : SEMICOLON_IDENT {slhs = (char *) $1;} rhs opt_sem
     ;

rhs : rhs '|' alt
    | alt
    ;

alt : seq
      {
	struct srule rule;
	int end_marker = -1;

	rule.lhs = slhs;
	rule.rhs_len = OS_TOP_LENGTH (srhs) / sizeof (char *);
	OS_TOP_EXPAND (srhs, sizeof (char *));
	rule.rhs = (char **) OS_TOP_BEGIN (srhs);
	rule.rhs [rule.rhs_len] = NULL;
	OS_TOP_FINISH (srhs);
        VLO_ADD_MEMORY (srules, &rule, sizeof (rule));
      }
    ;

seq : seq IDENT
       {
	 char *repr = (char *) $2;

	 OS_TOP_ADD_MEMORY (srhs, &repr, sizeof (repr));
       }
    | seq CHAR_TERM
       {
	  struct sym term;

	  term.repr = (char *) $2;
          term.num = VLO_LENGTH (sterms) / sizeof (term);
	  VLO_ADD_MEMORY (sterms, &term, sizeof (term));
	  OS_TOP_ADD_MEMORY (srhs, &term.repr, sizeof (term.repr));
       }
    |
    ;

%%


/* The following is current input character of the grammar
   description. */
static const char *curr_ch;

/* The following is current line number of the grammar description. */
static int ln;

/* The following contains all representation of the syntax tokens. */
static os_t stoks;

/* The following is number of syntax terminal and syntax rules being
   read. */
static int nsterm, nsrule;

/* The following is necessary if we use marpa parser with byacc/bison/msta
   parser. */

/* The following implements lexical analyzer for yacc code. */
int
yylex (void)
{
  int c;
  int n_errs = 0;

  for (;;)
    {
      c = *curr_ch++;
      switch (c)
	{
	case '\0':
	  return 0;
	case '\n':
	  ln++;
	case '\t':
	case ' ':
	  break;
	case '/':
	  c = *curr_ch++;
	  if (c != '*' && n_errs == 0)
	    {
	      n_errs++;
	      curr_ch--;
	      yyerror ("invalid input character /");
	    }
	  for (;;)
	    {
	      c = *curr_ch++;
	      if (c == '\0')
		  yyerror ("unfinished comment");
              if (c == '\n')
                ln++;
	      if (c == '*')
		{
		  c = *curr_ch++;
		  if (c == '/')
		    break;
		  curr_ch--;
		}
	    }
	  break;
	case '=':
	case '#':
	case '|':
	case ';':
	case '-':
	case '(':
	case ')':
	  return c;
	case '\'':
	  OS_TOP_ADD_BYTE (stoks, '\'');
	  yylval.num = *curr_ch++;
	  OS_TOP_ADD_BYTE (stoks, yylval.num);
	  if (*curr_ch++ != '\'')
	    yyerror ("invalid character");
	  OS_TOP_ADD_BYTE (stoks, '\'');
	  OS_TOP_ADD_BYTE (stoks, '\0');
	  yylval.ref = OS_TOP_BEGIN (stoks);
	  OS_TOP_FINISH (stoks);
	  return CHAR_TERM;
	default:
	  if (isalpha (c) || c == '_')
	    {
	      OS_TOP_ADD_BYTE (stoks, c);
	      while ((c = *curr_ch++) != '\0' && (isalnum (c) || c == '_'))
		OS_TOP_ADD_BYTE (stoks, c);
	      curr_ch--;
	      OS_TOP_ADD_BYTE (stoks, '\0');
	      yylval.ref = OS_TOP_BEGIN (stoks);
	      if (strcmp ((char *) yylval.ref, "TERM") == 0)
		{
		  OS_TOP_NULLIFY (stoks);
		  return TERM;
		}
	      OS_TOP_FINISH (stoks);
	      while ((c = *curr_ch++) != '\0')
		if (c == '\n')
		  ln++;
	        else if (c != '\t' && c != ' ')
		  break;
	      if (c != ':')
		curr_ch--;
	      return (c == ':' ? SEMICOLON_IDENT : IDENT);
	    }
          else
            {
              n_errs++;
              if (n_errs == 1)
                {
		  char str [100];

                  if (isprint (c))
		    {
		      sprintf (str, "invalid input character '%c'", c);
		      yyerror (str);
		    }
                  else
                    yyerror ("invalid input character");
                }
	    }
	}
    }
}


/* The following implements syntactic error diagnostic function yacc
   code. */
int
yyerror (const char *str)
{
  fprintf (stderr, "description syntax error on ln %d", ln);
  return 0;
}

/* The following function is used to sort array of syntax terminals by
   names. */
static int
sterm_name_cmp (const void *t1, const void *t2)
{
  return strcmp (((struct sym *) t1)->repr, ((struct sym *) t2)->repr);
}

static void free_sgrammar (void);

/* The following is major function which parses the description and
   transforms it into IR. */
static int set_sgrammar( YaepAllocator * alloc, const char * grammar ) {
  int i, j, num;
  struct sym *term, *prev, *arr;

  ln = 1;
  OS_CREATE( stoks, alloc, 0 );
  VLO_CREATE( sterms, alloc, 0 );
  VLO_CREATE( srules, alloc, 0 );
  OS_CREATE( srhs, alloc, 0 );
  curr_ch = grammar;
  yyparse ();
  /* sort array of syntax terminals by names. */
  num = VLO_LENGTH (sterms) / sizeof (struct sym);
  arr = (struct sym *) VLO_BEGIN (sterms);
  qsort (arr, num, sizeof (struct sym), sterm_name_cmp);
  /* Check different codes for the same syntax terminal and remove
     duplicates. */
  for (i = j = 0, prev = NULL; i < num; i++)
    {
      term = arr + i;
      if (prev == NULL || strcmp (prev->repr, term->repr) != 0)
	{
	  prev = term;
	  arr [j++] = *term;
	}
    }
  VLO_SHORTEN (sterms, (num - j) * sizeof (struct sym));
  nsterm = nsrule = 0;
  return 0;
}

/* The following frees IR. */
static void
free_sgrammar (void)
{
  OS_DELETE (srhs);
  VLO_DELETE (srules);
  VLO_DELETE (sterms);
  OS_DELETE (stoks);
}

static struct sym *
sread_terminal (void)
{
  struct sym *term;
  const char *name;

  term = &((struct sym *) VLO_BEGIN (sterms)) [nsterm];
  if ((char *) term >= (char *) VLO_BOUND (sterms))
    return NULL;
  nsterm++;
  return term;
}

static const char *
sread_rule (const char ***rhs)
{
  struct srule *rule;
  const char *lhs;

  rule = &((struct srule *) VLO_BEGIN (srules)) [nsrule];
  if ((char *) rule >= (char *) VLO_BOUND (srules))
    return NULL;
  lhs = rule->lhs;
  *rhs = (const char **) rule->rhs;
  nsrule++;
  return lhs;
}

static hash_table_t sym_table;

static unsigned
sym_hash (hash_table_entry_t el)
{
  const struct sym *sym = (struct sym *) el;
  const char *id = sym->repr;
  unsigned result, i;

  for (result = i = 0; *id++ != '\0'; i++)
    result += ((unsigned char) *id << (i % CHAR_BIT));
  return result;
}

static int
sym_eq (hash_table_entry_t el1, hash_table_entry_t el2)
{
  return strcmp (((struct sym *) el1)->repr, ((struct sym *) el2)->repr) == 0;
}

static struct sym *
insert_symbol (const char *name, struct sym *sym)
{
  struct sym tsym;
  hash_table_entry_t *entry_ptr;

  tsym.repr = name;
  entry_ptr = find_hash_table_entry (sym_table, &tsym, 1);
  if (*entry_ptr == NULL)
    *entry_ptr = (hash_table_entry_t) sym;
  else
    assert (strcmp (name, ((struct sym *) *entry_ptr)->repr) == 0);
  return (struct sym *) *entry_ptr;
}

static struct sym *
find_symbol (const char *name)
{
  struct sym tsym;
  hash_table_entry_t *entry_ptr;

  tsym.repr = name;
  entry_ptr = find_hash_table_entry (sym_table, &tsym, 0);
  return (struct sym *) *entry_ptr;
}

static int
fail (const char *s, Marpa_Grammar g)
{
  const char *error_string;
  Marpa_Error_Code errcode = marpa_g_error (g, &error_string);
  printf ("%s returned %d: %s", s, errcode, error_string);
  exit (1);
}

/* The following function parses grammar desrciption. */
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

static void
marpa_free_grammar (Marpa_Grammar *g)
{
  delete_hash_table (sym_table);
  free_sgrammar ();
}

static Marpa_Symbol_ID IDENTIFIER;
static Marpa_Symbol_ID SIGNED;
static Marpa_Symbol_ID CONST;
static Marpa_Symbol_ID INLINE;
static Marpa_Symbol_ID AUTO;
static Marpa_Symbol_ID BREAK;
static Marpa_Symbol_ID CASE;
static Marpa_Symbol_ID CHAR;
static Marpa_Symbol_ID CONTINUE;
static Marpa_Symbol_ID DEFAULT;
static Marpa_Symbol_ID DO;
static Marpa_Symbol_ID DOUBLE;
static Marpa_Symbol_ID ELSE;
static Marpa_Symbol_ID ENUM;
static Marpa_Symbol_ID EXTERN;
static Marpa_Symbol_ID FLOAT;
static Marpa_Symbol_ID FOR;
static Marpa_Symbol_ID GOTO;
static Marpa_Symbol_ID IF;
static Marpa_Symbol_ID INT;
static Marpa_Symbol_ID LONG;
static Marpa_Symbol_ID REGISTER;
static Marpa_Symbol_ID RETURN;
static Marpa_Symbol_ID SHORT;
static Marpa_Symbol_ID SIZEOF;
static Marpa_Symbol_ID STATIC;
static Marpa_Symbol_ID STRUCT;
static Marpa_Symbol_ID SWITCH;
static Marpa_Symbol_ID TYPEDEF;
static Marpa_Symbol_ID UNION;
static Marpa_Symbol_ID UNSIGNED;
static Marpa_Symbol_ID VOID;
static Marpa_Symbol_ID VOLATILE;
static Marpa_Symbol_ID WHILE;
static Marpa_Symbol_ID CONSTANT;
static Marpa_Symbol_ID STRING_LITERAL;
static Marpa_Symbol_ID RIGHT_ASSIGN;
static Marpa_Symbol_ID LEFT_ASSIGN;
static Marpa_Symbol_ID ADD_ASSIGN;
static Marpa_Symbol_ID SUB_ASSIGN;
static Marpa_Symbol_ID MUL_ASSIGN;
static Marpa_Symbol_ID DIV_ASSIGN;
static Marpa_Symbol_ID MOD_ASSIGN;
static Marpa_Symbol_ID AND_ASSIGN;
static Marpa_Symbol_ID XOR_ASSIGN;
static Marpa_Symbol_ID OR_ASSIGN;
static Marpa_Symbol_ID RIGHT_OP;
static Marpa_Symbol_ID LEFT_OP;
static Marpa_Symbol_ID INC_OP;
static Marpa_Symbol_ID DEC_OP;
static Marpa_Symbol_ID PTR_OP;
static Marpa_Symbol_ID AND_OP;
static Marpa_Symbol_ID OR_OP;
static Marpa_Symbol_ID LE_OP;
static Marpa_Symbol_ID GE_OP;
static Marpa_Symbol_ID EQ_OP;
static Marpa_Symbol_ID NE_OP;
static Marpa_Symbol_ID ELIPSIS;
static Marpa_Symbol_ID RESTRICT;
static Marpa_Symbol_ID _BOOL;
static Marpa_Symbol_ID _COMPLEX;
static Marpa_Symbol_ID _IMAGINARY;

struct code_name
{
  Marpa_Symbol_ID *id;
  const char *name;
};

static struct code_name table_code_name[] =
  {{&IDENTIFIER, "IDENTIFIER" },
   {&SIGNED, "SIGNED" },
   {&CONST, "CONST" },
   {&INLINE, "INLINE" },
   {&AUTO, "AUTO" },
   {&BREAK, "BREAK" },
   {&CASE, "CASE" },
   {&CHAR, "CHAR" },
   {&CONTINUE, "CONTINUE" },
   {&DEFAULT, "DEFAULT" },
   {&DO, "DO" },
   {&DOUBLE, "DOUBLE" },
   {&ELSE, "ELSE" },
   {&ENUM, "ENUM" },
   {&EXTERN, "EXTERN" },
   {&FLOAT, "FLOAT" },
   {&FOR, "FOR" },
   {&GOTO, "GOTO" },
   {&IF, "IF" },
   {&INT, "INT" },
   {&LONG, "LONG" },
   {&REGISTER, "REGISTER" },
   {&RETURN, "RETURN" },
   {&SHORT, "SHORT" },
   {&SIZEOF, "SIZEOF" },
   {&STATIC, "STATIC" },
   {&STRUCT, "STRUCT" },
   {&SWITCH, "SWITCH" },
   {&TYPEDEF, "TYPEDEF" },
   {&UNION, "UNION" },
   {&UNSIGNED, "UNSIGNED" },
   {&VOID, "VOID" },
   {&VOLATILE, "VOLATILE" },
   {&WHILE, "WHILE" },
   {&CONSTANT, "CONSTANT" },
   {&STRING_LITERAL, "STRING_LITERAL" },
   {&RIGHT_ASSIGN, "RIGHT_ASSIGN" },
   {&LEFT_ASSIGN, "LEFT_ASSIGN" },
   {&ADD_ASSIGN, "ADD_ASSIGN" },
   {&SUB_ASSIGN, "SUB_ASSIGN" },
   {&MUL_ASSIGN, "MUL_ASSIGN" },
   {&DIV_ASSIGN, "DIV_ASSIGN" },
   {&MOD_ASSIGN, "MOD_ASSIGN" },
   {&AND_ASSIGN, "AND_ASSIGN" },
   {&XOR_ASSIGN, "XOR_ASSIGN" },
   {&OR_ASSIGN, "OR_ASSIGN" },
   {&RIGHT_OP, "RIGHT_OP" },
   {&LEFT_OP, "LEFT_OP" },
   {&INC_OP, "INC_OP" },
   {&DEC_OP, "DEC_OP" },
   {&PTR_OP, "PTR_OP" },
   {&AND_OP, "AND_OP" },
   {&OR_OP, "OR_OP" },
   {&LE_OP, "LE_OP" },
   {&GE_OP, "GE_OP" },
   {&EQ_OP, "EQ_OP" },
   {&NE_OP, "NE_OP" },
   {&ELIPSIS, "ELIPSIS" },
   {&RESTRICT, "RESTRICT" },
   {&_BOOL, "_BOOL" },
   {&_COMPLEX, "_COMPLEX" },
   {&_IMAGINARY, "_IMAGINARY" },
  };

static int single_char_code[256];

static void
setup_tokens (void)
{
  struct sym *sym;
  int i, size = sizeof (table_code_name) / sizeof (struct code_name);
  char ch_repr [] = {'\'', ' ', '\'', 0};

  for (i = 0; i < size; i++)
    {
      sym = find_symbol (table_code_name[i].name);
      if (sym == NULL)
        {
          printf ("%s is not described in grammar for MARPA\n",
                  table_code_name[i].name);
          exit (1);
        }
      *table_code_name[i].id = sym->id + 256;
    }
  for (i = 0; i < 255; i++)
    {
      single_char_code[i] = 0;
      ch_repr[1] = i;
      sym = find_symbol (ch_repr);
      if (sym == NULL)
	continue;
      single_char_code[i] = sym->id;
    }
}

#include "test_common.c"

int
get_lex (void)
{
  if (curr == NULL)
    curr = list;
  else
    curr = curr->next;
  if (curr == NULL)
    return -1;
  line = curr->line;
  column = curr->column;
  return curr->code;
}

#undef yylex
#define yylex yylex1

#include "ansic.c"

static void store_lexs( YaepAllocator * alloc ) {
  struct lex lex, *prev;
  int code;
#ifdef DEBUG
  int nt = 0;
#endif

  OS_CREATE( lexs, alloc, 0 );
  list = NULL;
  prev = NULL;
  while ((code = yylex ()) > 0) {
#ifdef DEBUG
    nt++;
#endif
    if (code == IDENTIFIER)
      {
        OS_TOP_ADD_MEMORY (lexs, yytext, strlen (yytext) + 1);
        lex.id = OS_TOP_BEGIN (lexs);
        OS_TOP_FINISH (lexs);
      }
    else
      lex.id = NULL;
    lex.code = code;
    lex.line = line;
    lex.column = column;
    lex.next = NULL;
    OS_TOP_ADD_MEMORY (lexs, &lex, sizeof (lex));
    if (prev == NULL)
      prev = list = OS_TOP_BEGIN (lexs);
    else {
      prev = prev->next = OS_TOP_BEGIN (lexs);
    }
    OS_TOP_FINISH (lexs);
  }
#ifdef DEBUG
  fprintf (stderr, "%d tokens\n", nt);
#endif
}

/* All parse_alloc memory is contained here. */
static os_t mem_os;

static void *
test_parse_alloc (int size)
{
  void *result;

  OS_TOP_EXPAND (mem_os, size);
  result = OS_TOP_BEGIN (mem_os);
  OS_TOP_FINISH (mem_os);
  return result;
}

/* Printing syntax error. */
static void
test_syntax_error (int err_tok_num, void *err_tok_attr,
		   int start_ignored_tok_num, void *start_ignored_tok_attr,
		   int start_recovered_tok_num, void *start_recovered_tok_attr)
{
  if (start_ignored_tok_num < 0)
    fprintf (stderr, "Syntax error on token %d\n", err_tok_num);
  else
    fprintf
      (stderr,
       "Syntax error on token %d(ln %d):ignore %d tokens starting with token = %d\n",
       err_tok_num, (int) (ptrdiff_t) err_tok_attr,
       start_recovered_tok_num - start_ignored_tok_num, start_ignored_tok_num);
}

static Marpa_Symbol_ID
test_read_token (void **attr)
{
  Marpa_Symbol_ID code;

  *attr = (void *) (ptrdiff_t) line;
  code = get_lex ();
  if (code < 0)
    return -1;
  if (code < 256)
    return single_char_code[code];
  else
    return code - 256;
}

static const char *description =
"TERM\n"
"IDENTIFIER\n"
"SIGNED\n"
"CONST\n"
"INLINE\n"
"AUTO\n"
"BREAK\n"
"CASE\n"
"CHAR\n"
"CONTINUE\n"
"DEFAULT\n"
"DO\n"
"DOUBLE\n"
"ELSE\n"
"ENUM\n"
"EXTERN\n"
"FLOAT\n"
"FOR\n"
"GOTO\n"
"IF\n"
"INT\n"
"LONG\n"
"REGISTER\n"
"RETURN\n"
"SHORT\n"
"SIZEOF\n"
"STATIC\n"
"STRUCT\n"
"SWITCH\n"
"TYPEDEF\n"
"UNION\n"
"UNSIGNED\n"
"VOID\n"
"VOLATILE\n"
"WHILE\n"
"CONSTANT\n"
"STRING_LITERAL\n"
"RIGHT_ASSIGN\n"
"LEFT_ASSIGN\n"
"ADD_ASSIGN\n"
"SUB_ASSIGN\n"
"MUL_ASSIGN\n"
"DIV_ASSIGN\n"
"MOD_ASSIGN\n"
"AND_ASSIGN\n"
"XOR_ASSIGN\n"
"OR_ASSIGN\n"
"RIGHT_OP\n"
"LEFT_OP\n"
"INC_OP\n"
"DEC_OP\n"
"PTR_OP\n"
"AND_OP\n"
"OR_OP\n"
"LE_OP\n"
"GE_OP\n"
"EQ_OP\n"
"NE_OP\n"
"ELIPSIS\n"
"RESTRICT\n"
"_BOOL\n"
"_COMPLEX\n"
"_IMAGINARY;\n"
"\n"
"/* Additional rules: */\n"
"\n"
"start : translation_unit\n"
"      ;\n"
"\n"
"identifier : IDENTIFIER\n"
"           ;\n"
"\n"
"constant : CONSTANT\n"
"         ;\n"
"\n"
"string_literal : STRING_LITERAL\n"
"               ;\n"
"\n"
"/* A.2  Phrase structure grammar: */\n"
"/* A.2.1  Expressions: */\n"
"/* (6.5.1): */\n"
"primary_expression : identifier\n"
"                   | constant\n"
"                   | string_literal\n"
"                   | '(' expression ')'\n"
"                   ;\n"
"/* (6.5.2): */\n"
"/* postfix_expression : primary_expression\n"
"                   | postfix_expression '[' expression ']'\n"
"                   | postfix_expression '(' [argument_expression_list] ')'\n"
"                   | postfix_expression '.' identifier\n"
"                   | postfix_expression PTR_OP identifier\n"
"                   | postfix_expression INC_OP\n"
"                   | postfix_expression DEC_OP\n"
"                   | '(' type_name ')' '{' initializer_list '}'\n"
"                   | '(' type_name ')' '{' initializer_list ',' '}' */\n"
"\n"
"postfix_expression : primary_expression\n"
"                   | postfix_expression '[' expression ']'\n"
"                   | postfix_expression '(' argument_expression_list_opt ')'\n"
"                   | postfix_expression '.' identifier\n"
"                   | postfix_expression PTR_OP identifier\n"
"                   | postfix_expression INC_OP\n"
"                   | postfix_expression DEC_OP\n"
"                   | '(' type_name ')' '{' initializer_list '}'\n"
"                   | '(' type_name ')' '{' initializer_list ',' '}'\n"
"                   ;\n"
"\n"
"argument_expression_list_opt :\n"
"                             | argument_expression_list\n"
"                             ;\n"
"/* (6.5.2): */\n"
"argument_expression_list : assignment_expression\n"
"                         | argument_expression_list ',' assignment_expression\n"
"                         ;\n"
"\n"
"/* (6.5.3): */\n"
"unary_expression : postfix_expression\n"
"                 | INC_OP unary_expression\n"
"                 | DEC_OP unary_expression\n"
"                 | unary_operator  cast_expression\n"
"                 | SIZEOF unary_expression\n"
"                 | SIZEOF '(' type_name ')'\n"
"                 ;\n"
"\n"
"/* (6.5.3): */\n"
"unary_operator : '&'\n"
"               | '*'\n"
"               | '+'\n"
"               | '-'\n"
"               | '~'\n"
"               | '!'\n"
"               ;\n"
"\n"
"/* (6.5.4): */\n"
"cast_expression : unary_expression\n"
"                | '(' type_name ')' cast_expression\n"
"                ;\n"
"\n"
"/* (6.5.5): */\n"
"multiplicative_expression : cast_expression\n"
"                          | multiplicative_expression '*' cast_expression\n"
"                          | multiplicative_expression '/' cast_expression\n"
"                          | multiplicative_expression '%' cast_expression\n"
"                          ;\n"
"\n"
"/* (6.5.6): */\n"
"additive_expression : multiplicative_expression\n"
"                    | additive_expression '+' multiplicative_expression\n"
"                    | additive_expression '-' multiplicative_expression\n"
"                    ;\n"
"\n"
"/* (6.5.7): */\n"
"shift_expression : additive_expression\n"
"                 | shift_expression LEFT_OP additive_expression\n"
"                 | shift_expression RIGHT_OP additive_expression\n"
"                 ;\n"
"\n"
"/* (6.5.8): */\n"
"relational_expression : shift_expression\n"
"                      | relational_expression '<' shift_expression\n"
"                      | relational_expression '>' shift_expression\n"
"                      | relational_expression LE_OP shift_expression\n"
"                      | relational_expression GE_OP shift_expression\n"
"                      ;\n"
"\n"
"/* (6.5.9): */\n"
"equality_expression : relational_expression\n"
"                    | equality_expression EQ_OP relational_expression\n"
"                    | equality_expression NE_OP relational_expression\n"
"                    ;\n"
"\n"
"/* (6.5.10): */\n"
"AND_expression : equality_expression\n"
"               | AND_expression '&' equality_expression\n"
"               ;\n"
"\n"
"/* (6.5.11): */\n"
"exclusive_OR_expression : AND_expression\n"
"                        | exclusive_OR_expression '^' AND_expression\n"
"                        ;\n"
"\n"
"/* (6.5.12): */\n"
"inclusive_OR_expression : exclusive_OR_expression\n"
"                        | inclusive_OR_expression '|' exclusive_OR_expression\n"
"                        ;\n"
"\n"
"/* (6.5.13): */\n"
"logical_AND_expression : inclusive_OR_expression\n"
"                       | logical_AND_expression AND_OP inclusive_OR_expression\n"
"                       ;\n"
"\n"
"/* (6.5.14): */\n"
"logical_OR_expression : logical_AND_expression\n"
"                      | logical_OR_expression OR_OP logical_AND_expression\n"
"                      ;\n"
"\n"
"/* (6.5.15): */\n"
"conditional_expression : logical_OR_expression\n"
"                       | logical_OR_expression '?' expression ':' conditional_expression\n"
"                       ;\n"
"\n"
"/* (6.5.16): */\n"
"assignment_expression : conditional_expression\n"
"                      | unary_expression  assignment_operator  assignment_expression\n"
"                      ;\n"
"\n"
"/* (6.5.16): */\n"
"assignment_operator :  '='\n"
"                    |  MUL_ASSIGN\n"
"                    |  DIV_ASSIGN\n"
"                    |  MOD_ASSIGN\n"
"                    |  ADD_ASSIGN\n"
"                    |  SUB_ASSIGN\n"
"                    |  LEFT_ASSIGN\n"
"                    |  RIGHT_ASSIGN\n"
"                    |  AND_ASSIGN\n"
"                    |  XOR_ASSIGN\n"
"                    |  OR_ASSIGN\n"
"                    ;\n"
"\n"
"/* (6.5.17): */\n"
"expression : assignment_expression\n"
"           | expression ',' assignment_expression\n"
"           | error\n"
"           ;\n"
"\n"
"/* (6.6): */\n"
"constant_expression : conditional_expression\n"
"                    ;\n"
"\n"
"/* A.2.2  Declarations: */\n"
"/* (6.7): */\n"
"/* declaration : declaration_specifiers [init_declarator_list] ';' */\n"
"               \n"
"declaration : declaration_specifiers init_declarator_list_opt ';'\n"
"            | error\n"
"            ;\n"
"\n"
"init_declarator_list_opt :\n"
"                         | init_declarator_list\n"
"                         ;\n"
"\n"
"/* (6.7): */\n"
"/* declaration_specifiers : storage_class_specifier  [declaration_specifiers]\n"
"   	               | type_specifier  [declaration_specifiers]\n"
"                       | type_qualifier  [declaration_specifiers]\n"
"                       | function_specifier  [declaration_specifiers] */\n"
"\n"
"declaration_specifiers : storage_class_specifier  declaration_specifiers_opt\n"
"   	               | type_specifier  declaration_specifiers_opt\n"
"                       | type_qualifier  declaration_specifiers_opt\n"
"                       | function_specifier  declaration_specifiers_opt\n"
"                       ;\n"
"\n"
"declaration_specifiers_opt :\n"
"                           | declaration_specifiers\n"
"                           ;\n"
"\n"
"/* (6.7): */\n"
"init_declarator_list : init_declarator\n"
"                     | init_declarator_list ',' init_declarator\n"
"                     ;\n"
"\n"
"/* (6.7): */\n"
"init_declarator : declarator\n"
"                | declarator '=' initializer\n"
"                ;\n"
"/* (6.7.1): */\n"
"storage_class_specifier : TYPEDEF\n"
"                        | EXTERN\n"
"                        | STATIC\n"
"                        | AUTO\n"
"	                | REGISTER\n"
"                        ;\n"
"\n"
"/* (6.7.2): */\n"
"type_specifier : VOID\n"
"               | CHAR\n"
"               | SHORT\n"
"               | INT\n"
"               | LONG\n"
"               | FLOAT\n"
"               | DOUBLE\n"
"               | SIGNED\n"
"               | UNSIGNED\n"
"               | _BOOL\n"
"               | _COMPLEX\n"
"               | _IMAGINARY\n"
"               | struct_or_union_specifier\n"
"               | enum_specifier\n"
"               | typedef_name\n"
"               ;\n"
"\n"
"/* (6.7.2.1): */\n"
"/* struct_or_union_specifier : struct_or_union  [identifier]\n"
"                                 '{' struct_declaration_list '}'\n"
"                          | struct_or_union  identifier */\n"
"\n"
"struct_or_union_specifier : struct_or_union  identifier_opt\n"
"                                 '{' struct_declaration_list '}'\n"
"                          | struct_or_union  identifier\n"
"                          ;\n"
"\n"
"identifier_opt :\n"
"               | identifier\n"
"               ;\n"
"\n"
"/* (6.7.2.1): */\n"
"struct_or_union : STRUCT\n"
"                | UNION\n"
"                ;\n"
"\n"
"/* (6.7.2.1): */\n"
"struct_declaration_list : struct_declaration\n"
"                        | struct_declaration_list  struct_declaration\n"
"                        ;\n"
"\n"
"/* (6.7.2.1): */\n"
"struct_declaration : specifier_qualifier_list  struct_declarator_list ';'\n"
"                   ;\n"
"\n"
"/* (6.7.2.1): */\n"
"/* specifier_qualifier_list : type_specifier  [specifier_qualifier_list]\n"
"                         | type_qualifier  [specifier_qualifier_list] */\n"
"\n"
"specifier_qualifier_list : type_specifier  specifier_qualifier_list_opt\n"
"                         | type_qualifier  specifier_qualifier_list_opt\n"
"                         ;\n"
"\n"
"specifier_qualifier_list_opt : \n"
"                             | specifier_qualifier_list\n"
"                             ;\n"
"\n"
"/* (6.7.2.1): */\n"
"struct_declarator_list : struct_declarator\n"
"                       | struct_declarator_list ',' struct_declarator\n"
"                       ;\n"
"\n"
"/* (6.7.2.1): */\n"
"/* struct_declarator : declarator\n"
"                  | [declarator] ':' constant_expression */\n"
"\n"
"struct_declarator : declarator\n"
"                  | declarator_opt ':' constant_expression\n"
"                  ;\n"
"\n"
"declarator_opt :\n"
"               | declarator\n"
"               ;\n"
"\n"
"/* (6.7.2.2): */\n"
"enum_specifier : ENUM identifier_opt '{' enumerator_list '}'\n"
"               | ENUM identifier_opt '{' enumerator_list ',' '}'\n"
"               | ENUM identifier\n"
"               ;\n"
"\n"
"/* (6.7.2.2): */\n"
"enumerator_list : enumerator\n"
"                | enumerator_list ',' enumerator\n"
"                ;\n"
"\n"
"/* (6.7.2.2): */\n"
"enumerator : enumeration_constant\n"
"           | enumeration_constant '=' constant_expression\n"
"           ;\n"
"\n"
"/* (6.7.3): */\n"
"type_qualifier : CONST\n"
"               | RESTRICT\n"
"               | VOLATILE\n"
"               ;\n"
"\n"
"/* (6.7.4): */\n"
"function_specifier : INLINE\n"
"                   ;\n"
"\n"
"/* (6.7.5): */\n"
"/* declarator : [pointer] direct_declarator */\n"
"\n"
"declarator : pointer_opt direct_declarator\n"
"           ;\n"
"\n"
"pointer_opt :\n"
"            | pointer\n"
"            ;\n"
"/* (6.7.5): */\n"
"/* direct_declarator : identifier\n"
"                  | '(' declarator ')'\n"
"                  | direct_declarator '[' [type_qualifier_list] [assignment_expression] ']'\n"
"                  | direct_declarator '[' STATIC [type_qualifier_list] assignment_expression ']'\n"
"                  | direct_declarator '[' type_qualifier_list STATIC assignment_expression ']'\n"
"                  | direct_declarator '[' [type_qualifier_list] '*' ']'\n"
"                  | direct_declarator '(' parameter_type_list ')'\n"
"                  | direct_declarator '(' [identifier_list] ')' */\n"
"\n"
"direct_declarator : identifier\n"
"                  | '(' declarator ')'\n"
"                  | direct_declarator '[' type_qualifier_list_opt assignment_expression_opt ']'\n"
"                  | direct_declarator '[' STATIC type_qualifier_list_opt assignment_expression ']'\n"
"                  | direct_declarator '[' type_qualifier_list STATIC assignment_expression ']'\n"
"                  | direct_declarator '[' type_qualifier_list_opt '*' ']'\n"
"                  | direct_declarator '(' parameter_type_list ')'\n"
"                  | direct_declarator '(' identifier_list_opt ')'\n"
"                  ;\n"
"\n"
"type_qualifier_list_opt :\n"
"                        | type_qualifier_list\n"
"                        ;\n"
"\n"
"identifier_list_opt :\n"
"                    | identifier_list\n"
"                    ;\n"
"\n"
"/* (6.7.5): */\n"
"pointer : '*' type_qualifier_list_opt\n"
"        | '*' type_qualifier_list_opt pointer\n"
"        ;\n"
"\n"
"/* (6.7.5): */\n"
"type_qualifier_list : type_qualifier\n"
"                    | type_qualifier_list  type_qualifier\n"
"                    ;\n"
"\n"
"/* (6.7.5): */\n"
"parameter_type_list : parameter_list\n"
"                    | parameter_list ',' ELIPSIS\n"
"                    ;\n"
"\n"
"/* (6.7.5): */\n"
"parameter_list : parameter_declaration\n"
"               | parameter_list ',' parameter_declaration\n"
"               ;\n"
"\n"
"/* (6.7.5): */\n"
"/* parameter_declaration : declaration_specifiers declarator\n"
"                      | declaration_specifiers [abstract_declarator] */\n"
"\n"
"parameter_declaration : declaration_specifiers declarator\n"
"                      | declaration_specifiers abstract_declarator_opt\n"
"                      ;\n"
"\n"
"abstract_declarator_opt :\n"
"                        | abstract_declarator\n"
"                        ;\n"
"\n"
"/* (6.7.5): */\n"
"identifier_list : identifier\n"
"                | identifier_list ',' identifier\n"
"                ;\n"
"\n"
"/* (6.7.6): */\n"
"type_name: specifier_qualifier_list  abstract_declarator_opt\n"
"         ;\n"
"\n"
"/* (6.7.6): */\n"
"abstract_declarator : pointer\n"
"                    | pointer_opt direct_abstract_declarator\n"
"                     ;\n"
"\n"
"/* (6.7.6): */\n"
"/* direct_abstract_declarator : '(' abstract_declarator ')'\n"
"                           | [direct_abstract_declarator] '[' [assignment_expression] ']'\n"
"                           | [direct_abstract_declarator] '[' '*' ']'\n"
"                           | [direct_abstract_declarator] '(' [parameter_type_list] ')' */\n"
"\n"
"direct_abstract_declarator : '(' abstract_declarator ')'\n"
"                           | direct_abstract_declarator_opt '[' assignment_expression_opt ']'\n"
"                           | direct_abstract_declarator_opt '[' '*' ']'\n"
"                           | direct_abstract_declarator_opt '(' parameter_type_list_opt ')'\n"
"                           ;\n"
"\n"
"direct_abstract_declarator_opt :\n"
"                               | direct_abstract_declarator\n"
"                               ;\n"
"\n"
"assignment_expression_opt :\n"
"                          | assignment_expression\n"
"                          ;\n"
"\n"
"parameter_type_list_opt :\n"
"                        | parameter_type_list\n"
"                        ;\n"
"\n"
"/* (6.7.7): */\n"
"typedef_name : identifier\n"
"             ;\n"
"\n"
"/* (6.7.8): */\n"
"initializer : assignment_expression\n"
"            | '{' initializer_list '}'\n"
"            | '{' initializer_list ',' '}'\n"
"            ;\n"
"\n"
"/* (6.7.8): */\n"
"/* initializer_list : [designation] initializer\n"
"                 | initializer_list ',' [designation] initializer */\n"
"\n"
"initializer_list : designation_opt initializer\n"
"                 | initializer_list ',' designation_opt initializer\n"
"                 ;\n"
"\n"
"designation_opt :\n"
"                | designation\n"
"                ;\n"
"\n"
"/* (6.7.8): */\n"
"designation : designator_list '='\n"
"            ;\n"
"\n"
"/* (6.7.8): */\n"
"designator_list : designator\n"
"                | designator_list  designator\n"
"                ;\n"
"\n"
"/* (6.7.8): */\n"
"designator : '[' constant_expression ']'\n"
"           | '.' identifier\n"
"           ;\n"
"\n"
"/* A.2.3  Statements: */\n"
"/* (6.8): */\n"
"statement : labeled_statement\n"
"          | compound_statement\n"
"          | expression_statement\n"
"          | selection_statement\n"
"          | iteration_statement\n"
"          | jump_statement\n"
"          | error\n"
"          ;\n"
"\n"
"/* (6.8.1): */\n"
"labeled_statement : identifier ':' statement\n"
"                  | CASE constant_expression ':' statement\n"
"                  | DEFAULT ':' statement\n"
"                  ;\n"
"\n"
"/* (6.8.2): */\n"
"/* compound_statement : '{' [block_item_list] '}' */\n"
"\n"
"compound_statement : '{' block_item_list_opt '}'\n"
"                   ;\n"
"\n"
"block_item_list_opt :\n"
"                    | block_item_list\n"
"                    ;\n"
"\n"
"/* (6.8.2): */\n"
"block_item_list : block_item\n"
"                | block_item_list  block_item\n"
"                ;\n"
"\n"
"/* (6.8.2): */\n"
"block_item : declaration\n"
"           | statement\n"
"           ;\n"
"\n"
"/* (6.8.3): */\n"
"/* expression_statement : [expression] ';' */\n"
"\n"
"expression_statement : expression_opt ';'\n"
"                     ;\n"
"expression_opt :\n"
"               | expression\n"
"               ;\n"
"\n"
"/* (6.8.4): */\n"
"selection_statement : IF '(' expression ')' statement\n"
"                    | IF '(' expression ')' statement ELSE statement\n"
"                    | SWITCH '(' expression ')' statement\n"
"                    ;\n"
"\n"
"/* (6.8.5): */\n"
"iteration_statement : WHILE '(' expression ')' statement\n"
"                    | DO statement WHILE '(' expression ')' ';'\n"
"                    | FOR '(' expression_opt ';' expression_opt ';' expression_opt ')' statement\n"
"                    | FOR '(' declaration  expression_opt ';' expression_opt ')' statement\n"
"                    ;\n"
"\n"
"/* (6.8.6): */\n"
"jump_statement : GOTO identifier ';'\n"
"               | CONTINUE ';'\n"
"               | BREAK ';'\n"
"               | RETURN expression_opt ';'\n"
"               ;\n"
"\n"
"/* A.2.4  External definitions: */\n"
"/* (6.9): */\n"
"translation_unit : external_declaration\n"
"                 | translation_unit external_declaration\n"
"                 ;\n"
"\n"
"/* (6.9): */\n"
"external_declaration : function_definition\n"
"                     | declaration\n"
"                     ;\n"
"\n"
"/* (6.9.1): */\n"
"/* function_definition : declaration_specifiers declarator  [declaration_list] compound_statement */\n"
"\n"
"function_definition : declaration_specifiers declarator  declaration_list_opt compound_statement\n"
"                   ;\n"
"\n"
"declaration_list_opt :\n"
"                     | declaration_list\n"
"                     ;\n"
"\n"
"/* (6.9.1): */\n"
"declaration_list : declaration\n"
"                 | declaration_list  declaration\n"
"                 ;\n"
"\n"
"/* A.1.5  Constants: */\n"
"/* (6.4.4.3): */\n"
"enumeration_constant : identifier\n"
"                     ;\n"
  ;

#ifdef linux
#include <unistd.h>
#endif

static void
marpa_parse (Marpa_Grammar *g)
{
  int i;
  Marpa_Recognizer r = marpa_r_new (*g);
  const char *error_string;

  if (!r)
    {
      marpa_g_error (*g, &error_string);
      fprintf (stderr, "%s\n", error_string);
      exit (1);
    }

  if (!marpa_r_start_input (r))
    {
      marpa_g_error (*g, &error_string);
      fprintf (stderr, "%s\n", error_string);
      exit (1);
    }

  i = 0;
  for (;;)
    {
      Marpa_Symbol_ID token;
      void *attr;
      int status;

      token = test_read_token (&attr);
      if (token < 0)
	break;
      i++;
      status = marpa_r_alternative (r, token, i, 1);
      if (status != MARPA_ERR_NONE)
	{
	  Marpa_Symbol_ID expected[20];
	  int count_of_expected = marpa_r_terminals_expected (r, expected);
	  int i;

	  for (i = 0; i < count_of_expected; i++)
	    {
	      fprintf (stderr, "expecting symbol %ld, %ld\n",
		       (long) i, (long) expected[i]);
	    }
	  marpa_g_error (*g, &error_string);
	  fprintf (stderr,
		   "marpa_alternative(%p,%ld,%ld,1) returned %d: %s", r,
		   (long) token, (long) i, status, error_string);
	  exit (1);
	}
      status = marpa_r_earleme_complete (r);
      if (status < 0)
	{
	  marpa_g_error (*g, &error_string);
	  fprintf (stderr, "marpa_earleme_complete returned %d: %s", status,
		   error_string);
	  exit (1);
	}
    }
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
"""#
