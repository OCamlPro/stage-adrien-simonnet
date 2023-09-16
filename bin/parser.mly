%{

%}

%token PARENTHESE_OUVRANTE PARENTHESE_FERMANTE
%token CROCHET_OUVRANT CROCHET_FERMANT
//%token ACCOLADE_OUVRANTE ACCOLADE_FERMANTE

%token<int> NAT
%token PLUS MOINS

%token PRINT

%token DEUX_POINTS_DEUX_POINTS POINT_VIRGULE

%token IF THEN ELSE WHILE

%token<string> IDENT
%token<string> CONSTRUCTOR_NAME

%token FUN FLECHE

%token LET REC AND IN EGAL

%token MATCH WITH

%token JOKER

%token TYPE OF

%token ASTERISQUE

%token BARRE

//%token REF EXCLAMATION DEUX_POINTS_EGAL

%token DEUX_POINTS VIRGULE POINT

%token EOF

%nonassoc PARENTHESE_OUVRANTE
%nonassoc LET
%nonassoc IN
%nonassoc IFZERO
%nonassoc ELSE
%nonassoc WHILE
%nonassoc FUN
%nonassoc FLECHE
%nonassoc NAT
%nonassoc IDENT
%left MOINS
%left PLUS
%left app
%left PRINT

%start <Ast.expr> programme

%type <Ast.expr> terme

%%

programme : terme EOF { $1 } ;

terme :
/*| PARENTHESE_OUVRANTE PARENTHESE_FERMANTE { Ast.Unit }*/
| PARENTHESE_OUVRANTE e = terme PARENTHESE_FERMANTE { e }

| i = NAT { Ast.Int i }
| e1 = terme bop = binary_operator e2 = terme { Ast.Binary (bop, e1, e2) }


| hd = terme DEUX_POINTS_DEUX_POINTS tl = terme { Ast.Constructor ("Cons", [hd; tl]) }

| IF cond = terme THEN iftrue = terme ELSE iffalse = terme { Ast.If (cond, iftrue, iffalse) }

| i = IDENT { Ast.Var i }
| constructor_name = CONSTRUCTOR_NAME { Ast.Constructor (constructor_name, []) }
| constructor_name = CONSTRUCTOR_NAME expr = terme { Ast.Constructor (constructor_name, [expr]) }
| constructor_name = CONSTRUCTOR_NAME PARENTHESE_OUVRANTE payload = payload_expr PARENTHESE_FERMANTE { Ast.Constructor (constructor_name, payload) }

| FUN args = arguments { args }

| e1 = terme e2 = terme %prec app { Ast.App (e1, e2) }

| TYPE i = IDENT EGAL constructors = constructors expr = terme { Ast.Type (i, constructors, expr) }

| LET REC bindings = bindings IN e2 = terme { Ast.Let_rec (bindings, e2) }
| LET i = IDENT EGAL e1 = terme IN e2 = terme { Ast.Let (i, e1, e2) }

| MATCH e = terme WITH ps = patterns { Ast.Match (e, ps) }

| CROCHET_OUVRANT l = liste { l }

binary_operator:
| PLUS { Ast.Add }
| MOINS { Ast.Sub }

constructors :
| BARRE constructor_name = CONSTRUCTOR_NAME { [constructor_name, ""] }
| BARRE constructor_name = CONSTRUCTOR_NAME OF constructor_type = constructor_type { [constructor_name, constructor_type] }
| BARRE constructor_name = CONSTRUCTOR_NAME constructors = constructors { (constructor_name, "")::constructors }
| BARRE constructor_name = CONSTRUCTOR_NAME OF constructor_type = constructor_type constructors = constructors { (constructor_name, constructor_type)::constructors }

constructor_type :
| t = ttype { t }
| t = ttype ASTERISQUE constructor_type = constructor_type { t ^ "*" ^ constructor_type }

ttype :
| ident = IDENT { ident }

patterns :
| BARRE p = pattern FLECHE e = terme { [p, e] }
| BARRE p = pattern FLECHE e = terme ps = patterns { (p, e)::ps }

pattern :
| i = IDENT { Ast.Joker i }
| constructor_name = CONSTRUCTOR_NAME { Ast.Deconstructor (constructor_name, []) }
| constructor_name = CONSTRUCTOR_NAME ident = IDENT { Ast.Deconstructor (constructor_name, [ident]) }
| constructor_name = CONSTRUCTOR_NAME PARENTHESE_OUVRANTE payload = payload PARENTHESE_FERMANTE { Ast.Deconstructor (constructor_name, payload) }
| JOKER { Ast.Joker "_" }

payload :
| ident = IDENT { [ident] }
| ident = IDENT VIRGULE payload = payload { ident::payload }

payload_expr :
| expr = terme { [expr] }
| expr = terme VIRGULE payload = payload_expr { expr::payload }

bindings :
| i = IDENT EGAL e1 = terme { [i, e1] }
| i = IDENT EGAL e1 = terme AND bindings = bindings { (i, e1)::bindings }

/*| REF terme { Ast.Ref $2 }
| EXCLAMATION terme { Ast.Deref $2 }
| terme DEUX_POINTS_EGAL terme { Ast.Assign ($1, $3) }*/



/*| ACCOLADE_OUVRANTE enregistrement { $2 }
| terme POINT IDENT { Ast.Field ($1, $3) }*/

arguments :
| i = IDENT FLECHE e = terme { Ast.Fun ([i], e) }
| i = IDENT args = arguments { Ast.Fun ([i], args) }

liste :
| CROCHET_FERMANT { Ast.Constructor ("Empty", []) }
| e = terme CROCHET_FERMANT { Ast.Constructor ("Cons", [e; Ast.Constructor ("Empty", [])]) }
| hd = terme POINT_VIRGULE tl = liste { Ast.Constructor ("Cons", [hd; tl]) }

/*enregistrement :
| terme ACCOLADE_FERMANTE { $1 }
| IDENT DEUX_POINTS terme VIRGULE enregistrement { Ast.Record (($1, $3), $5) }*/

%%
