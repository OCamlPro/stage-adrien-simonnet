type kvar = K of int

type named =
  | Prim of Ast.prim * Ast.var list
  | Fun of Ast.var * expr * kvar
  | Var of Ast.var

and expr =
  | Let of Ast.var * named * expr
  | Let_cont of kvar * Ast.var list * expr * expr
  | Apply_cont of kvar * Ast.var list
  | If of Ast.var * (kvar * Ast.var list) * (kvar * Ast.var list)
  | Apply of Ast.var * Ast.var * kvar

let vars = ref 0
let conts = ref 0

let inc vars =
  vars := !vars + 1;
  string_of_int !vars

let inc_conts () =
  conts := !conts + 1;
  !conts

let rec replace_var var new_var (ast : Ast.expr) : Ast.expr =
  match ast with
  | Fun (x, e) when x = var -> Fun (x, e)
  | Fun (x, e) -> Fun (x, replace_var var new_var e)
  | Var x when x = var -> Var new_var
  | Var x -> Var x
  | Prim (prim, args) ->
      Prim (prim, List.map (fun arg -> replace_var var new_var arg) args)
  | Let (var', e1, e2) when var' = var ->
      Let (var', replace_var var new_var e1, e2)
  | Let (var', e1, e2) ->
      Let (var', replace_var var new_var e1, replace_var var new_var e2)
  | If (cond, t, f) ->
      If
        ( replace_var var new_var cond,
          replace_var var new_var t,
          replace_var var new_var f )
  | App (e1, e2) -> App (replace_var var new_var e1, replace_var var new_var e2)

let rec from_ast (ast : Ast.expr) var (expr : expr) : expr =
  match ast with
  | Fun (x, e) ->
      let k1 = inc_conts () in
      let v1 = inc vars in
      let v2 = inc vars in
      Let
        ( var,
          Fun
            ( v1,
              from_ast (replace_var x v1 e) v2 (Apply_cont (K k1, [ v2 ])),
              K k1 ),
          expr )
  | Var x -> Let (var, Var x, expr)
  | Prim (prim, args) ->
      let vars = List.map (fun arg -> (inc vars, arg)) args in
      List.fold_left
        (fun expr (var, e) -> from_ast e var expr)
        (Let (var, Prim (prim, List.map (fun (var, _) -> var) vars), expr))
        vars
  | Let (x1, Let (x2, e2, e2'), e1') ->
      from_ast (Ast.Let (x2, e2, Ast.Let (x1, e2', e1'))) var expr
  | Let (x, Var x', e) -> from_ast (replace_var x x' e) var expr
  | Let (x, App (e1, e2), suite) ->
      let v = inc vars in
      let v1 = inc vars in
      let v2 = inc vars in
      let k1 = inc_conts () in
      Let_cont
        ( K k1,
          [ v ],
          from_ast (replace_var x v suite) var
            (from_ast e1 v1 (from_ast e2 v2 (Apply (v1, v2, K k1)))),
          expr )
  | Let (var', If (cond, t, f), e) ->
      let v1 = inc vars in
      from_ast (If (cond, t, f)) v1 (from_ast (replace_var var' v1 e) var expr)
  | Let (var', e1, e2) ->
      let v1 = inc vars in
      from_ast e1 v1 (from_ast (replace_var var' v1 e2) var expr)
  | If (cond, t, f) ->
      let v1 = inc vars in
      let k1 = inc_conts () in
      let k2 = inc_conts () in
      from_ast cond v1
        (Let_cont
           ( K k1,
             [],
             from_ast t var expr,
             Let_cont
               (K k2, [], from_ast f var expr, If (v1, (K k1, []), (K k2, [])))
           ))
  | App (e1, e2) ->
      let k = inc_conts () in
      let v1 = inc vars in
      let v2 = inc vars in
      Let_cont
        ( K k,
          [ var ],
          expr,
          from_ast e1 v1 (from_ast e2 v2 (Apply (v1, v2, K k))) )

let rec sprintf_named named =
  match named with
  | Prim (prim, args) -> sprintf_prim prim args
  | Fun (arg, expr, K k) ->
      Printf.sprintf "(fun k%d x%s -> %s)" k arg (sprintf expr)
  | Var x -> "x" ^ x

and sprintf_prim (prim : Ast.prim) args =
  match (prim, args) with
  | Const x, _ -> string_of_int x
  | Add, x1 :: x2 :: _ -> Printf.sprintf "(x%s + x%s)" x1 x2
  | Print, x1 :: _ -> Printf.sprintf "(print x%s)" x1
  | _ -> failwith "invalid args"

and sprintf (cps : expr) : string =
  match cps with
  | Let (var, named, expr) ->
      Printf.sprintf "let x%s = %s in\n%s" var (sprintf_named named)
        (sprintf expr)
  | Let_cont (K k, args, e1, e2) ->
      Printf.sprintf "let k%d%s = %s in\n%s" k
        (List.fold_left (fun acc s -> acc ^ " x" ^ s) "" args)
        (sprintf e1) (sprintf e2)
  | Apply_cont (K k, args) ->
      Printf.sprintf "(k%d%s)" k
        (List.fold_left (fun acc s -> acc ^ " x" ^ s) "" args)
  | If (var, (K kt, argst), (K kf, argsf)) ->
      Printf.sprintf "If (x%s) (k%d%s) (k%d%s)" var kt
        (List.fold_left (fun acc s -> acc ^ " " ^ s) "" argst)
        kf
        (List.fold_left (fun acc s -> acc ^ " x" ^ s) "" argsf)
  | Apply (x, arg, K k) -> Printf.sprintf "(x%s x%s) -> k%d" x arg k
