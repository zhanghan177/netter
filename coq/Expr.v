Require Import Coq.Strings.String.
Require Import Coq.Unicode.Utf8.

From mathcomp Require Import ssreflect ssrfun ssrbool eqtype ssrnat choice 
  seq ssrint rat ssralg ssrnum.

From extructures Require Import ord fset.

From deriving Require Import deriving.

From RandC Require Import Extra.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope fset_scope.

Inductive var := Var {vname : string; vnum : nat}.

Definition var_indMixin := Eval simpl in [indMixin for var_rect].
Canonical var_indType := IndType _ var var_indMixin.
Definition var_eqMixin := Eval simpl in [derive eqMixin for var].
Canonical var_eqType := EqType var var_eqMixin.
Definition var_choiceMixin := [derive choiceMixin for var].
Canonical var_choiceType := Eval hnf in ChoiceType var var_choiceMixin.
Definition var_ordMixin := Eval simpl in [derive ordMixin for var].
Canonical var_ordType := OrdType var var_ordMixin.

Inductive symbol :=
| SVar of var
| SFor of nat.

Coercion SVar : var >-> symbol.

Definition var_of_sym (s : symbol) : option var :=
  if s is SVar v then Some v else None.

Lemma SVarK : pcancel SVar var_of_sym.
Proof. by case. Qed.

Definition symbol_indMixin := [indMixin for symbol_rect].
Canonical symbol_indType := Eval hnf in IndType _ symbol symbol_indMixin.
Definition symbol_eqMixin := [derive eqMixin for symbol].
Canonical symbol_eqType := Eval hnf in EqType symbol symbol_eqMixin.
Definition symbol_choiceMixin := [derive choiceMixin for symbol].
Canonical symbol_choiceType := Eval hnf in ChoiceType symbol symbol_choiceMixin.
Definition symbol_ordMixin := [derive ordMixin for symbol].
Canonical symbol_ordType := Eval hnf in OrdType symbol symbol_ordMixin.

Inductive comp_op :=
| Leq
| Ltq.

Inductive log_op :=
| And
| Or.

Inductive arith_op :=
| Plus
| Times
| Minus.

Inductive trunc_op :=
| Ceil
| Floor.

Unset Elimination Schemes.
Inductive bexpr :=
| BConst of bool
| BEqB   of bexpr & bexpr
| BEqZ   of zexpr & zexpr
| BEqQ   of qexpr & qexpr
| BTest  of bexpr & bexpr & bexpr
| BCompZ of comp_op & zexpr & zexpr
| BCompQ of comp_op & qexpr & qexpr
| BLogOp of log_op & bexpr & bexpr
| BNot   of bexpr

with zexpr :=
| ZSym   of symbol
| ZConst of int
| ZTest  of bexpr & zexpr & zexpr
| ZArith of arith_op & zexpr & zexpr
| ZTrunc of trunc_op & qexpr

with qexpr :=
| QConst of rat
| QTest  of bexpr & qexpr & qexpr
| QArith of arith_op & qexpr & qexpr
| QOfZ   of zexpr.
Set Elimination Schemes.

Scheme bexpr_rect := Induction for bexpr Sort Type
with   zexpr_rect := Induction for zexpr Sort Type
with   qexpr_rect := Induction for qexpr Sort Type.

Combined Scheme expr_rect from bexpr_rect, zexpr_rect, qexpr_rect.

Scheme bexpr_ind := Induction for bexpr Sort Prop
with   zexpr_ind := Induction for zexpr Sort Prop
with   qexpr_ind := Induction for qexpr Sort Prop.

Combined Scheme expr_ind from bexpr_ind, zexpr_ind, qexpr_ind.

Section Eval.

Implicit Types (be : bexpr) (ze : zexpr) (qe : qexpr).

Fixpoint eval_bexpr f be : bool :=
  match be with
  | BConst b => b
  | BEqB be1 be2 => eval_bexpr f be1 == eval_bexpr f be2
  | BEqZ ze1 ze2 => eval_zexpr f ze1 == eval_zexpr f ze2
  | BEqQ qe1 qe2 => eval_qexpr f qe1 == eval_qexpr f qe2
  | BTest be be1 be2 => if eval_bexpr f be then eval_bexpr f be1
                        else eval_bexpr f be2
  | BCompZ Leq ze1 ze2 => (eval_zexpr f ze1 <= eval_zexpr f ze2)%R
  | BCompZ Ltq ze1 ze2 => (eval_zexpr f ze1 <  eval_zexpr f ze2)%R
  | BCompQ Leq qe1 qe2 => (eval_qexpr f qe1 <= eval_qexpr f qe2)%R
  | BCompQ Ltq qe1 qe2 => (eval_qexpr f qe1 <  eval_qexpr f qe2)%R
  | BLogOp And be1 be2 => eval_bexpr f be1 && eval_bexpr f be2
  | BLogOp Or  be1 be2 => eval_bexpr f be1 || eval_bexpr f be2
  | BNot be => ~~ eval_bexpr f be
  end

with eval_zexpr f ze : int :=
  match ze with
  | ZSym v => f v
  | ZConst n => n
  | ZTest be ze1 ze2 => if eval_bexpr f be then eval_zexpr f ze1
                        else eval_zexpr f ze2
  | ZArith Plus ze1 ze2 => eval_zexpr f ze1 + eval_zexpr f ze2
  | ZArith Times ze1 ze2 => eval_zexpr f ze1 * eval_zexpr f ze2
  | ZArith Minus ze1 ze2 => eval_zexpr f ze1 - eval_zexpr f ze2
  | ZTrunc _ _ => 0 (* FIXME *)
  end

with eval_qexpr f qe : rat :=
  match qe with
  | QConst x => x
  | QTest be qe1 qe2 => if eval_bexpr f be then eval_qexpr f qe1
                        else eval_qexpr f qe2
  | QArith Plus qe1 qe2 => eval_qexpr f qe1 + eval_qexpr f qe2
  | QArith Times qe1 qe2 => eval_qexpr f qe1 * eval_qexpr f qe2
  | QArith Minus qe1 qe2 => eval_qexpr f qe1 - eval_qexpr f qe2
  | QOfZ ze => ratz (eval_zexpr f ze)
  end.

Fixpoint subst_bexpr f be : bexpr :=
  match be with
  | BConst _ => be
  | BEqB be1 be2 => BEqB (subst_bexpr f be1) (subst_bexpr f be2)
  | BEqZ ze1 ze2 => BEqZ (subst_zexpr f ze1) (subst_zexpr f ze2)
  | BEqQ qe1 qe2 => BEqQ (subst_qexpr f qe1) (subst_qexpr f qe2)
  | BTest be be1 be2 =>
    BTest (subst_bexpr f be) (subst_bexpr f be1) (subst_bexpr f be2)
  | BCompZ o ze1 ze2 => BCompZ o (subst_zexpr f ze1) (subst_zexpr f ze2)
  | BCompQ o qe1 qe2 => BCompQ o (subst_qexpr f qe1) (subst_qexpr f qe2)
  | BLogOp o be1 be2 => BLogOp o (subst_bexpr f be1) (subst_bexpr f be2)
  | BNot be => BNot (subst_bexpr f be)
  end

with subst_zexpr f ze : zexpr :=
  match ze with
  | ZSym v => f v
  | ZConst _ => ze
  | ZTest be ze1 ze2 =>
    ZTest (subst_bexpr f be) (subst_zexpr f ze1) (subst_zexpr f ze2)
  | ZArith o ze1 ze2 =>
    ZArith o (subst_zexpr f ze1) (subst_zexpr f ze2)
  | ZTrunc o qe =>
    ZTrunc o (subst_qexpr f qe)
  end

with subst_qexpr f qe : qexpr :=
  match qe with
  | QConst _ => qe
  | QTest be qe1 qe2 =>
    QTest (subst_bexpr f be) (subst_qexpr f qe1) (subst_qexpr f qe2)
  | QArith o qe1 qe2 => QArith o (subst_qexpr f qe1) (subst_qexpr f qe2)
  | QOfZ ze => QOfZ (subst_zexpr f ze)
  end.

Ltac solve_subst_exprP :=
  match goal with
  | [e : ?x = ?y |- context[?x]] =>
    rewrite {}e
  end.

Lemma subst_exprP f g :
  (forall e,
      eval_bexpr f (subst_bexpr g e) =
      eval_bexpr (fun v => eval_zexpr f (g v)) e) /\
  (forall e,
      eval_zexpr f (subst_zexpr g e) =
      eval_zexpr (fun v => eval_zexpr f (g v)) e) /\
  (forall e,
      eval_qexpr f (subst_qexpr g e) =
      eval_qexpr (fun v => eval_zexpr f (g v)) e).
Proof.
apply: expr_ind=> //=; try by (move=> *; repeat solve_subst_exprP).
Qed.

Lemma subst_bexprP f g e :
  eval_bexpr f (subst_bexpr g e) =
  eval_bexpr (fun v => eval_zexpr f (g v)) e.
Proof.
by case: (subst_exprP f g)=> [?[??]].
Qed.

Lemma subst_zexprP f g e :
  eval_zexpr f (subst_zexpr g e) =
  eval_zexpr (fun v => eval_zexpr f (g v)) e.
Proof.
by case: (subst_exprP f g)=> [?[??]].
Qed.

Lemma subst_qexprP f g e :
  eval_qexpr f (subst_qexpr g e) =
  eval_qexpr (fun v => eval_zexpr f (g v)) e.
Proof.
by case: (subst_exprP f g)=> [?[??]].
Qed.

End Eval.

Axiom bexpr_eqMixin : Equality.mixin_of bexpr.
Canonical bexpr_eqType := EqType bexpr bexpr_eqMixin.
Axiom bexpr_choiceMixin : Choice.mixin_of bexpr.
Canonical bexpr_choiceType := Eval hnf in ChoiceType bexpr bexpr_choiceMixin.
Axiom bexpr_ordMixin : Ord.mixin_of bexpr.
Canonical bexpr_ordType := Eval hnf in OrdType bexpr bexpr_ordMixin.
Axiom zexpr_eqMixin : Equality.mixin_of zexpr.
Canonical zexpr_eqType := EqType zexpr zexpr_eqMixin.
Axiom zexpr_choiceMixin : Choice.mixin_of zexpr.
Canonical zexpr_choiceType := Eval hnf in ChoiceType zexpr zexpr_choiceMixin.
Axiom zexpr_ordMixin : Ord.mixin_of zexpr.
Canonical zexpr_ordType := Eval hnf in OrdType zexpr zexpr_ordMixin.

Fixpoint bexpr_syms be :=
  match be with
  | BConst _         => fset0
  | BEqB be1 be2     => bexpr_syms be1 :|: bexpr_syms be2
  | BEqZ ze1 ze2     => zexpr_syms ze1 :|: zexpr_syms ze2
  | BEqQ qe1 qe2     => qexpr_syms qe1 :|: qexpr_syms qe2
  | BTest be be1 be2 => bexpr_syms be  :|: bexpr_syms be1 :|: bexpr_syms be2
  | BCompZ _ ze1 ze2 => zexpr_syms ze1 :|: zexpr_syms ze2
  | BCompQ _ qe1 qe2 => qexpr_syms qe1 :|: qexpr_syms qe2
  | BLogOp _ be1 be2 => bexpr_syms be1 :|: bexpr_syms be2
  | BNot be          => bexpr_syms be
  end

with zexpr_syms ze :=
  match ze with
  | ZSym v           => fset1 v
  | ZConst _         => fset0
  | ZTest be ze1 ze2 => bexpr_syms be  :|: zexpr_syms ze1 :|: zexpr_syms ze2
  | ZArith _ ze1 ze2 => zexpr_syms ze1 :|: zexpr_syms ze2
  | ZTrunc _ qe      => qexpr_syms qe
  end

with qexpr_syms qe :=
  match qe with
  | QConst _         => fset0
  | QTest be qe1 qe2 => bexpr_syms be  :|: qexpr_syms qe1 :|: qexpr_syms qe2
  | QArith _ qe1 qe2 => qexpr_syms qe1 :|: qexpr_syms qe2
  | QOfZ ze          => zexpr_syms ze
  end.

Ltac solve_eq_in_eval_exprP :=
  move=> *;
  repeat match goal with
         | [H : is_true (fsubset (_ :|: _) _) |- _] =>
           rewrite fsubUset in H
         | [H : is_true (_ && _) |- _] =>
           case/andP: H=> ??
         | [IH : ?P -> _, H : ?P |- _] =>
           move/(_ H) in IH
         | [H : ?x = _ |- context[?x]] => rewrite {}H
         | [x : _ |- _] =>
           match goal with
           | [ |- context[match x with _ => _ end]] =>
             case: x=> * /=
           end
         end.

Implicit Types V : {fset symbol}.

Lemma eq_in_eval_expr V f g :
  {in V, f =1 g} ->
  (forall be, fsubset (bexpr_syms be) V ->
              eval_bexpr f be = eval_bexpr g be) /\
  (forall ze, fsubset (zexpr_syms ze) V ->
              eval_zexpr f ze = eval_zexpr g ze) /\
  (forall qe, fsubset (qexpr_syms qe) V ->
              eval_qexpr f qe = eval_qexpr g qe).
Proof.
move=> efg; apply: expr_ind=> //=; try by solve_eq_in_eval_exprP.
move=> v; rewrite fsub1set; exact: efg.
Qed.

Lemma eq_in_eval_bexpr V f g :
  {in V, f =1 g} ->
  forall e, fsubset (bexpr_syms e) V ->
  eval_bexpr f e = eval_bexpr g e.
Proof. by move=> /eq_in_eval_expr [? [? ?]]. Qed.

Lemma eq_in_eval_zexpr V f g :
  {in V, f =1 g} ->
  forall e, fsubset (zexpr_syms e) V ->
  eval_zexpr f e = eval_zexpr g e.
Proof. by move=> /eq_in_eval_expr [? [? ?]]. Qed.

Lemma eq_eval_bexpr f g :
  f =1 g ->
  forall e, eval_bexpr f e = eval_bexpr g e.
Proof.
move=> fg ?; apply: eq_in_eval_bexpr (fsubsetxx _).
move=> ??; exact: fg.
Qed.

Lemma eq_eval_zexpr f g :
  f =1 g ->
  forall e, eval_zexpr f e = eval_zexpr g e.
Proof.
move=> fg ?; apply: eq_in_eval_zexpr (fsubsetxx _).
move=> ??; exact: fg.
Qed.

Definition formulas := seq (nat * zexpr).

Fixpoint feval_forms (defs : formulas) st (f : nat) : int :=
  if defs is (f', e) :: fs then
    if f' == f then
      let eval s := match s with
                    | SVar v => st v
                    | SFor f => feval_forms fs st f
                    end in
      eval_zexpr eval e
    else feval_forms fs st f
  else 0.

Definition feval_sym defs st s : int :=
  match s with
  | SVar v => st v
  | SFor f => feval_forms defs st f
  end.

Fixpoint formula_vars (defs : formulas) (f : nat) : {fset var} :=
  if defs is (f', e) :: defs then
    if f' == f then
      \bigcup_(s <- zexpr_syms e)
         match s with
         | SVar v   => fset1 v
         | SFor f'' => formula_vars defs f''
         end
    else formula_vars defs f
  else fset0.

Definition sym_vars defs s : {fset var} :=
  match s with
  | SVar v => fset1 v
  | SFor f => formula_vars defs f
  end.

Lemma eq_in_feval_sym defs st1 st2 s :
  {in sym_vars defs s, st1 =1 st2} ->
  feval_sym defs st1 s = feval_sym defs st2 s.
Proof.
case: s=> [v|f] /= est; first by apply: est; exact/fset1P.
elim: defs f est=> [|[f e] defs IH] //= f'.
case: (altP (f =P f'))=> [{f'} _|ne] est; last exact: IH.
apply/eq_in_eval_zexpr; last exact/fsubsetxx.
move=> [v|f'] in_e.
  by apply: est; apply/bigcupP; exists (SVar v); rewrite // in_fset1 eqxx.
by apply: IH=> // v in_f'; apply: est; apply/bigcupP; exists (SFor f').
Qed.

Definition feval_bexpr defs st e :=
  eval_bexpr (feval_sym defs st) e.

Definition feval_zexpr defs st e :=
  eval_zexpr (feval_sym defs st) e.

Definition feval_qexpr defs st e :=
  eval_qexpr (feval_sym defs st) e.

Definition bexpr_vars defs e :=
  \bigcup_(s <- bexpr_syms e) sym_vars defs s.

Definition zexpr_vars defs e :=
  \bigcup_(s <- zexpr_syms e) sym_vars defs s.

Definition qexpr_vars defs e :=
  \bigcup_(s <- qexpr_syms e) sym_vars defs s.

Lemma eq_in_feval_bexpr defs st1 st2 e :
  {in bexpr_vars defs e, st1 =1 st2} ->
  feval_bexpr defs st1 e = feval_bexpr defs st2 e.
Proof.
move=> est; rewrite /feval_bexpr /bexpr_vars.
apply/eq_in_eval_bexpr; last exact: fsubsetxx.
move=> s s_e; apply: eq_in_feval_sym=> v v_s.
by apply: est; apply/bigcupP; exists s.
Qed.

Lemma eq_in_feval_zexpr defs st1 st2 e :
  {in zexpr_vars defs e, st1 =1 st2} ->
  feval_zexpr defs st1 e = feval_zexpr defs st2 e.
Proof.
move=> est; rewrite /feval_zexpr /zexpr_vars.
apply/eq_in_eval_zexpr; last exact: fsubsetxx.
move=> s s_e; apply: eq_in_feval_sym=> v v_s.
by apply: est; apply/bigcupP; exists s.
Qed.
