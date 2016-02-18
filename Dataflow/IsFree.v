Require Import Rustre.Common.
Require Import Rustre.Dataflow.Syntax.

(** 

The predicate [Is_free x t : Prop] states that the variable [x] is
used in the term [t]. If [t] is an equation, this collects the
variables in the right-hand side of the equation. In particular, if
[t] is [x = v0 fby x], [x] will (perhaps confusingly) be free.

 *)

Inductive Is_free_in_clock : ident -> clock -> Prop :=
| FreeCon1:
    forall x ck' xc,
      Is_free_in_clock x (Con ck' x xc)
| FreeCon2:
    forall x y ck' xc,
      Is_free_in_clock x ck'
      -> Is_free_in_clock x (Con ck' y xc).

Inductive Is_free_in_lexp : ident -> lexp -> Prop :=
| FreeEvar: forall x, Is_free_in_lexp x (Evar x)
| FreeEwhen1: forall e c cv x,
    Is_free_in_lexp x e ->
    Is_free_in_lexp x (Ewhen e c cv)
| FreeEwhen2: forall e c cv,
    Is_free_in_lexp c (Ewhen e c cv).

Inductive Is_free_in_laexp : ident -> clock -> lexp -> Prop :=
| freeLAexp1: forall ck e x,
    Is_free_in_lexp x e  ->
    Is_free_in_laexp x ck e
| freeLAexp2: forall ck e x,
    Is_free_in_clock x ck ->
    Is_free_in_laexp x ck e.

Inductive Is_free_in_laexps : ident -> clock -> lexps -> Prop :=
| freeLAexps1: forall ck les x,
    Nelist.Exists (Is_free_in_lexp x) les ->
    Is_free_in_laexps x ck les
| freeLAexps2: forall ck les x,
    Is_free_in_clock x ck ->
    Is_free_in_laexps x ck les.

Inductive Is_free_in_cexp : ident -> cexp -> Prop :=
| FreeEmerge_cond: forall i t f,
    Is_free_in_cexp i (Emerge i t f)
| FreeEmerge_true: forall i t f x,
    Is_free_in_cexp x t ->
    Is_free_in_cexp x (Emerge i t f)
| FreeEmerge_false: forall i t f x,
    Is_free_in_cexp x f ->
    Is_free_in_cexp x (Emerge i t f)
| FreeEexp: forall e x,
    Is_free_in_lexp x e ->
    Is_free_in_cexp x (Eexp e).

Inductive Is_free_in_caexp : ident -> clock -> cexp -> Prop :=
| FreeCAexp1: forall ck ce x,
    Is_free_in_cexp x ce ->
    Is_free_in_caexp x ck ce
| FreeCAexp2: forall ck ce x,
    Is_free_in_clock x ck ->
    Is_free_in_caexp x ck ce.

Inductive Is_free_in_eq : ident -> equation -> Prop :=
| FreeEqDef:
    forall x ck ce i,
      Is_free_in_caexp i ck ce ->
      Is_free_in_eq i (EqDef x ck ce)
| FreeEqApp:
    forall x f ck les i,
      Is_free_in_laexps i ck les ->
      Is_free_in_eq i (EqApp x ck f les)
| FreeEqFby:
    forall x v ck le i,
      Is_free_in_laexp i ck le ->
      Is_free_in_eq i (EqFby x ck v le).

Hint Constructors Is_free_in_clock Is_free_in_lexp
     Is_free_in_laexp Is_free_in_laexps Is_free_in_cexp 
     Is_free_in_caexp Is_free_in_eq.
