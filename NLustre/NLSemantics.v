Require Import List.
Import List.ListNotations.
Open Scope list_scope.
Require Import Coq.Sorting.Permutation.

Require Import Coq.FSets.FMapPositive.
Require Import Velus.Common.
Require Import Velus.Operators.
Require Import Velus.Clocks.
Require Import Velus.NLustre.NLSyntax.
Require Import Velus.NLustre.Ordered.
Require Import Velus.NLustre.Stream.

(** * The NLustre semantics *)

(**

  We provide a "standard" dataflow semantics relating an environment
  of streams to a stream of outputs.

 *)

Module Type NLSEMANTICS
       (Import Ids   : IDS)
       (Import Op    : OPERATORS)
       (Import OpAux : OPERATORS_AUX Op)
       (Import Clks  : CLOCKS    Ids)
       (Import Syn   : NLSYNTAX  Ids Op Clks)
       (Import Str   : STREAM        Op OpAux)
       (Import Ord   : ORDERED   Ids Op Clks Syn).

  (** ** Environment and history *)

  (**

An history maps variables to streams of values (the variables'
histories). Taking a snapshot of the history at a given time yields an
environment.

   *)

  (* XXX: naming the environment type *and* its inhabitant [R] is
        probably not a good idea *)
  Definition R := PM.t value.
  Definition history := PM.t (stream value).

  Implicit Type R: R.
  Implicit Type H: history.

  (** ** Instantaneous semantics *)

  Section InstantSemantics.

    Variable base : bool.
    Variable R: R.

    Inductive sem_var_instant (x: ident) v: Prop :=
    | Sv:
        PM.find x R = Some v ->
        sem_var_instant x v.

    Inductive sem_clock_instant: clock -> bool -> Prop :=
    | Sbase:
        sem_clock_instant Cbase base
    | Son:
        forall ck x c b,
          sem_clock_instant ck true ->
          sem_var_instant x (present c) ->
          val_to_bool c = Some b ->
          sem_clock_instant (Con ck x b) true
    | Son_abs1:
        forall ck x c,
          sem_clock_instant ck false ->
          sem_clock_instant (Con ck x c) false
    | Son_abs2:
        forall ck x c b,
          sem_clock_instant ck true ->
          sem_var_instant x (present c) ->
          val_to_bool c = Some b ->
          sem_clock_instant (Con ck x (negb b)) false.

    Inductive sem_lexp_instant: lexp -> value -> Prop:=
    | Sconst:
        forall c v,
          v = (if base then present (sem_const c) else absent) ->
          sem_lexp_instant (Econst c) v
    | Svar:
        forall x v ty,
          sem_var_instant x v ->
          sem_lexp_instant (Evar x ty) v
    | Swhen_eq:
        forall s x sc xc b,
          sem_var_instant x (present xc) ->
          sem_lexp_instant s (present sc) ->
          val_to_bool xc = Some b ->
          sem_lexp_instant (Ewhen s x b) (present sc)
    | Swhen_abs1:
        forall s x sc xc b,
          sem_var_instant x (present xc) ->
          val_to_bool xc = Some b ->
          sem_lexp_instant s (present sc) ->
          sem_lexp_instant (Ewhen s x (negb b)) absent
    | Swhen_abs:
        forall s x b,
          sem_var_instant x absent ->
          sem_lexp_instant s absent ->
          sem_lexp_instant (Ewhen s x b) absent
    | Sunop_eq:
        forall le op c c' ty,
          sem_lexp_instant le (present c) ->
          sem_unop op c (typeof le) = Some c' ->
          sem_lexp_instant (Eunop op le ty) (present c')
    | Sunop_abs:
        forall le op ty,
          sem_lexp_instant le absent ->
          sem_lexp_instant (Eunop op le ty) absent
    | Sbinop_eq:
        forall le1 le2 op c1 c2 c' ty,
          sem_lexp_instant le1 (present c1) ->
          sem_lexp_instant le2 (present c2) ->
          sem_binop op c1 (typeof le1) c2 (typeof le2) = Some c' ->
          sem_lexp_instant (Ebinop op le1 le2 ty) (present c')
    | Sbinop_abs:
        forall le1 le2 op ty,
          sem_lexp_instant le1 absent ->
          sem_lexp_instant le2 absent ->
          sem_lexp_instant (Ebinop op le1 le2 ty) absent.

    Definition sem_lexps_instant (les: list lexp)(vs: list value) :=
      Forall2 sem_lexp_instant les vs.

    Inductive sem_laexp_instant: clock -> lexp -> value -> Prop:=
    | SLtick:
        forall ck le c,
          sem_lexp_instant le (present c) ->
          sem_clock_instant ck true ->
          sem_laexp_instant ck le (present c)
    | SLabs:
        forall ck le,
          sem_clock_instant ck false ->
          sem_laexp_instant ck le absent.

    Inductive sem_laexps_instant: clock -> lexps -> list value -> Prop:=
    | SLticks:
        forall ck ces cs vs,
          vs = map present cs ->
          sem_lexps_instant ces vs ->
          sem_clock_instant ck true ->
          sem_laexps_instant ck ces vs
    | SLabss:
        forall ck ces vs,
          vs = map (fun _ => absent) ces ->
          sem_clock_instant ck false ->
          sem_laexps_instant ck ces vs.

    Inductive sem_cexp_instant: cexp -> value -> Prop :=
    | Smerge_true:
        forall x t f c,
          sem_var_instant x (present true_val) ->
          sem_cexp_instant t (present c) ->
          sem_cexp_instant f absent ->
          sem_cexp_instant (Emerge x t f) (present c)
    | Smerge_false:
        forall x t f c,
          sem_var_instant x (present false_val) ->
          sem_cexp_instant t absent ->
          sem_cexp_instant f (present c) ->
          sem_cexp_instant (Emerge x t f) (present c)
    | Smerge_abs:
        forall x t f,
          sem_var_instant x absent ->
          sem_cexp_instant t absent ->
          sem_cexp_instant f absent ->
          sem_cexp_instant (Emerge x t f) absent
    | Site_eq:
        forall x t f c b ct cf,
          sem_lexp_instant x (present c) ->
          sem_cexp_instant t (present ct) ->
          sem_cexp_instant f (present cf) ->
          val_to_bool c = Some b ->
          sem_cexp_instant (Eite x t f) (if b then present ct else present cf)
    | Site_abs:
        forall b t f,
          sem_lexp_instant b absent ->
          sem_cexp_instant t absent ->
          sem_cexp_instant f absent ->
          sem_cexp_instant (Eite b t f) absent
    | Sexp:
        forall e v,
          sem_lexp_instant e v ->
          sem_cexp_instant (Eexp e) v.

    Inductive sem_caexp_instant: clock -> cexp -> value -> Prop :=
    | SCtick:
        forall ck ce c,
          sem_cexp_instant ce (present c) ->
          sem_clock_instant ck true ->
          sem_caexp_instant ck ce (present c)
    | SCabs:
        forall ck ce,
          sem_clock_instant ck false ->
          sem_caexp_instant ck ce absent.

    Inductive rhs_absent_instant: equation -> Prop :=
    | AEqDef:
        forall x ck cae,
          sem_caexp_instant ck cae absent ->
          rhs_absent_instant (EqDef x ck cae)
    | AEqApp:
        forall x f ck laes vs r,
          sem_laexps_instant ck laes vs ->
          Forall (fun c => c = absent) vs ->
          rhs_absent_instant (EqApp x ck f laes r)
    | AEqFby:
        forall x ck v0 lae,
          sem_laexp_instant ck lae absent ->
          rhs_absent_instant (EqFby x ck v0 lae).

  End InstantSemantics.

  (** ** Liftings of instantaneous semantics *)

  Section LiftSemantics.

    Variable bk : stream bool.

    Definition restr H (n: nat): R :=
      PM.map (fun xs => xs n) H.
    Hint Unfold restr.

    Definition lift1 {A B} (f : A -> B) (s : stream A) : stream B
        := fun n => f (s n).
    Hint Unfold lift1.

    Definition lift {A B}
        (sem: bool -> R -> A -> B -> Prop) H x (ys: stream B): Prop :=
      forall n, sem (bk n) (restr H n) x (ys n).
    Hint Unfold lift.

    Definition sem_clock H (ck: clock)(xs: stream bool): Prop :=
      lift sem_clock_instant H ck xs.

    Definition sem_var H (x: ident)(xs: stream value): Prop :=
      lift (fun base => sem_var_instant) H x xs.

    Definition sem_vars H (x: idents)(xs: stream (list value)): Prop :=
      lift (fun base R => Forall2 (sem_var_instant R)) H x xs.

    Definition sem_laexp H ck (e: lexp)(xs: stream value): Prop :=
      lift (fun base R => sem_laexp_instant base R ck) H e xs.

    Definition sem_laexps
        H (ck: clock)(e: lexps)(xs: stream (list value)): Prop :=
      lift (fun base R => sem_laexps_instant base R ck) H e xs.

    Definition sem_lexp H (e: lexp)(xs: stream value): Prop :=
      lift sem_lexp_instant H e xs.

    Definition sem_lexps H (e: lexps)(xs: stream (list value)): Prop :=
      lift sem_lexps_instant H e xs.

    Definition sem_caexp H ck (c: cexp)(xs: stream value): Prop :=
      lift (fun base R => sem_caexp_instant base R ck) H c xs.

    Definition sem_cexp H (c: cexp)(xs: stream value): Prop :=
      lift sem_cexp_instant H c xs.

  End LiftSemantics.

  (** ** Time-dependent semantics *)

  Definition absent_list (xs: list value): Prop :=
    Forall (fun v => v = absent) xs.

  Definition present_list (xs: list value): Prop :=
    Forall (fun v => v <> absent) xs.

  Definition instant_same_clock (l : list value) : Prop :=
    absent_list l \/ present_list l.

  Definition same_clock (l_s : stream (list value)) : Prop :=
    forall n, instant_same_clock (l_s n).

  Definition clock_of (xss: stream (list value))(bs: stream bool): Prop :=
    forall n,
      present_list (xss n) <-> bs n = true.

  Definition clock_of' (xss: stream (list value)) : stream bool :=
    fun n => forallb (fun v => negb (v ==b absent)) (xss n).

  Lemma clock_of_equiv:
    forall xss, clock_of xss (clock_of' xss).
  Proof.
    split; intros H.
    - unfold clock_of'.
      rewrite forallb_forall.
      intros; rewrite Bool.negb_true_iff.
      rewrite not_equiv_decb_equiv.
      eapply In_Forall in H; eauto.
    - unfold clock_of' in H.
      rewrite forallb_forall in H.
      apply all_In_Forall; intros ** Hin E.
      specialize (H _ Hin).
      rewrite Bool.negb_true_iff, not_equiv_decb_equiv in H.
      apply H; eauto.
  Qed.

  Definition reset_of (xs: stream value) : stream bool :=
    fun n =>
      match xs n with
      | present x => x ==b true_val
      | _ => false
      end.

  Definition reset_of' (xs: stream value) (bs: stream bool) : Prop :=
    forall n,
      xs n = present true_val <-> bs n = true.

  Lemma reset_of_equiv:
    forall xs, reset_of' xs (reset_of xs).
  Proof.
    split; intros H.
    - unfold reset_of; now rewrite H, equiv_decb_refl.
    - unfold reset_of in H.
      destruct (xs n); try discriminate.
      rewrite equiv_decb_equiv in H.
      now rewrite H.
  Qed.

  (* Definition merge_reset (rs rs': stream bool) : stream bool := *)
  (*   fun n => rs n || rs' n. *)

  Section NodeSemantics.

    Variable G: global.

    Inductive sem_equation: stream bool -> history -> equation -> Prop :=
    | SEqDef:
        forall bk H x xs ck ce,
          sem_var bk H x xs ->
          sem_caexp bk H ck ce xs ->
          sem_equation bk H (EqDef x ck ce)
    | SEqApp:
        forall bk H x ck f arg ls xs,
          sem_laexps bk H ck arg ls ->
          sem_vars bk H x xs ->
          sem_node f ls xs ->
          sem_equation bk H (EqApp x ck f arg None)
    | SEqReset:
        forall bk H x ck f arg y ys ls xs,
          sem_laexps bk H ck arg ls ->
          sem_vars bk H x xs ->
          sem_var bk H y ys ->
          sem_reset f (reset_of ys) (map (fun _ => absent) arg) ls (map (fun _ => absent) x) xs ->
          sem_equation bk H (EqApp x ck f arg (Some y))
    | SEqFby:
        forall bk H x ls xs c0 ck le,
          sem_laexp bk H ck le ls ->
          sem_var bk H x xs ->
          xs = fby (sem_const c0) ls ->
          sem_equation bk H (EqFby x ck c0 le)

    with sem_reset: ident -> stream bool -> list value -> stream (list value) -> list value -> stream (list value) -> Prop :=
         | SReset:
             forall f r opaque_x xss opaque_y yss,
               (forall n, sem_node f (mask opaque_x n r xss) (mask opaque_y n r yss)) ->
               sem_reset f r opaque_x xss opaque_y yss

    with sem_node: ident -> stream (list value) -> stream (list value) -> Prop :=
         | SNode:
             forall bk H f xss yss n, (* i o v eqs ingt0 outgt0 defd vout nodup good, *)
               clock_of xss bk ->
               find_node f G = Some n ->
                                    (* (mk_node f i o v eqs *)
                                    (*          ingt0 outgt0 defd vout nodup good) -> *)
               sem_vars bk H (map fst n.(n_in)) xss ->
               sem_vars bk H (map fst n.(n_out)) yss ->
               (* XXX: This should be obtained through well-clocking: *)
               (*  * tuples are synchronised: *)
               same_clock xss ->
               same_clock yss ->
               (*  * output clock matches input clock *)
               (forall n, absent_list (xss n) <-> absent_list (yss n)) ->
               (* XXX: END *)
               Forall (sem_equation bk H) n.(n_eqs) ->
               sem_node f xss yss.

    Definition sem_nodes : Prop :=
      Forall (fun no => exists xs ys, sem_node no.(n_name) xs ys) G.

  End NodeSemantics.

  (** ** Induction principle for [sem_node] and [sem_equation] *)

  (** The automagically-generated induction principle is not strong
enough: it does not support the internal fixpoint introduced by
[Forall] *)

  Section sem_node_mult.
    Variable G: global.

    Variable P_equation: stream bool -> history -> equation -> Prop.
    Variable P_reset: ident -> stream bool -> list value -> stream (list value) -> list value -> stream (list value) -> Prop.
    Variable P_node: ident -> stream (list value) -> stream (list value) -> Prop.

    Hypothesis EqDefCase:
      forall bk H x xs ck ce,
        sem_var bk H x xs ->
        sem_caexp bk H ck ce xs ->
        P_equation bk H (EqDef x ck ce).

    Hypothesis EqAppCase:
      forall bk H x ck f arg ls xs,
        sem_laexps bk H ck arg ls ->
        sem_vars bk H x xs ->
        sem_node G f ls xs ->
        P_node f ls xs ->
        P_equation bk H (EqApp x ck f arg None).

    Hypothesis EqResetCase:
      forall bk H x ck f arg y ys ls xs,
        sem_laexps bk H ck arg ls ->
        sem_vars bk H x xs ->
        sem_var bk H y ys ->
        sem_reset G f (reset_of ys) (map (fun _ => absent) arg) ls (map (fun _ => absent) x) xs ->
        P_reset f (reset_of ys) (map (fun _ => absent) arg) ls (map (fun _ => absent) x) xs ->
        P_equation bk H (EqApp x ck f arg (Some y)).

    Hypothesis EqFbyCase:
      forall bk H x ls xs c0 ck le,
        sem_laexp bk H ck le ls ->
        sem_var bk H x xs ->
        xs = fby (sem_const c0) ls ->
        P_equation bk H (EqFby x ck c0 le).

    Hypothesis ResetCase:
      forall f r opaque_x xss opaque_y yss,
        (forall n, sem_node G f (mask opaque_x n r xss) (mask opaque_y n r yss)) ->
        (forall n, P_node f (mask opaque_x n r xss) (mask opaque_y n r yss)) ->
        P_reset f r opaque_x xss opaque_y yss.

    Hypothesis NodeCase:
      forall bk H f xss yss n, (* i o v eqs ingt0 outgt0 defd vout nodup good, *)
        clock_of xss bk ->
        find_node f G = Some n ->
                             (* (mk_node f i o v eqs *)
                             (*          ingt0 outgt0 defd vout nodup good) -> *)
        sem_vars bk H (map fst n.(n_in)) xss ->
        sem_vars bk H (map fst n.(n_out)) yss ->
        (* XXX: This should be obtained through well-clocking: *)
        (*  * tuples are synchronised: *)
        same_clock xss ->
        same_clock yss ->
        (*  * output clock matches input clock *)
        (forall n, absent_list (xss n) <-> absent_list (yss n)) ->
        (* XXX: END *)
        Forall (sem_equation G bk H) n.(n_eqs) ->
        Forall (P_equation bk H) n.(n_eqs) ->
        P_node f xss yss.

    Fixpoint sem_equation_mult
            (b: stream bool) (H: history) (e: equation)
            (Sem: sem_equation G b H e) {struct Sem}
      : P_equation b H e
    with sem_reset_mult
           (f: ident) (r: stream bool)
           (opaque_x: list value) (xss: stream (list value))
           (opaque_o: list value) (oss: stream (list value))
           (Sem: sem_reset G f r opaque_x xss opaque_o oss) {struct Sem}
         : P_reset f r opaque_x xss opaque_o oss
    with sem_node_mult
           (f: ident) (xss oss: stream (list value))
           (Sem: sem_node G f xss oss) {struct Sem}
         : P_node f xss oss.
    Proof.
      - destruct Sem; eauto.
      - destruct Sem; eauto.
      - destruct Sem; eauto.
        eapply NodeCase; eauto.
        (* clear H1 defd vout good. *)
        induction H7; auto.
    Qed.

    Combined Scheme sem_equation_node_ind from sem_equation_mult, sem_node_mult, sem_reset_mult.

  End sem_node_mult.


  (** ** Determinism of the semantics *)

  (** *** Instantaneous semantics *)

  Section InstantDeterminism.

    Variable base: bool.
    Variable R: R.

    Lemma sem_var_instant_det:
      forall x v1 v2,
        sem_var_instant R x v1
        -> sem_var_instant R x v2
        -> v1 = v2.
    Proof.
      intros x v1 v2 H1 H2.
      inversion_clear H1 as [Hf1];
        inversion_clear H2 as [Hf2];
        congruence.
    Qed.

    Lemma sem_clock_instant_det:
      forall ck v1 v2,
        sem_clock_instant base R ck v1
        -> sem_clock_instant base R ck v2
        -> v1 = v2.
    Proof.
      induction ck; repeat inversion 1; subst; intuition;
      try repeat progress match goal with
          | H1: sem_clock_instant ?bk ?R ?ck ?l,
                H2: sem_clock_instant ?bk ?R ?ck ?r |- _ =>
            apply IHck with (1:=H1) in H2; discriminate
          | H1: sem_var_instant ?R ?i (present ?l),
                H2: sem_var_instant ?R ?i (present ?r) |- _ =>
            apply sem_var_instant_det with (1:=H1) in H2;
              injection H2; intro; subst
          | H1: val_to_bool _ = Some ?b, H2: val_to_bool _ = _ |- _ =>
            rewrite H1 in H2; destruct b; discriminate
          end.
    Qed.

    Lemma sem_lexp_instant_det:
      forall e v1 v2,
        sem_lexp_instant base R e v1
        -> sem_lexp_instant base R e v2
        -> v1 = v2.
    Proof.
      induction e (* using lexp_ind2 *);
        try now (do 2 inversion_clear 1);
        match goal with
        | H1:sem_var_instant ?R ?e (present ?b1),
          H2:sem_var_instant ?R ?e (present ?b2),
          H3: ?b1 <> ?b2 |- _ =>
          exfalso; apply H3;
          cut (present (Vbool b1) = present (Vbool b2)); [now injection 1|];
          eapply sem_var_instant_det; eassumption
        | H1:sem_var_instant ?R ?e ?v1,
          H2:sem_var_instant ?R ?e ?v2 |- ?v1 = ?v2 =>
          eapply sem_var_instant_det; eassumption
        | H1:sem_var_instant ?R ?e (present _),
          H2:sem_var_instant ?R ?e absent |- _ =>
          apply (sem_var_instant_det _ _ _ _ H1) in H2;
          discriminate
        | _ => auto
        end.
      - (* Econst *)
        do 2 inversion_clear 1; destruct base; congruence.
      - (* Ewhen *)
        intros v1 v2 Hsem1 Hsem2.
        inversion Hsem1; inversion Hsem2; subst;
          repeat progress match goal with
          | H1:sem_lexp_instant ?b ?R ?e ?v1,
            H2:sem_lexp_instant ?b ?R ?e ?v2 |- _ =>
            apply IHe with (1:=H1) in H2
          | H1:sem_var_instant ?R ?i ?v1,
            H2:sem_var_instant ?R ?i ?v2 |- _ =>
            apply sem_var_instant_det with (1:=H1) in H2
          | H1:sem_unop _ _ _ = Some ?v1,
            H2:sem_unop _ _ _ = Some ?v2 |- _ =>
            rewrite H1 in H2; injection H2; intro; subst
          | Hp:present _ = present _ |- _ =>
            injection Hp; intro; subst
          | H1:val_to_bool _ = Some _,
            H2:val_to_bool _ = Some (negb _) |- _ =>
            rewrite H2 in H1; exfalso; injection H1;
            now apply Bool.no_fixpoint_negb
          end; subst; try easy.
      - (* Eunop *)
        intros v1 v2 Hsem1 Hsem2.
        inversion_clear Hsem1; inversion_clear Hsem2;
        repeat progress match goal with
        | H1:sem_lexp_instant _ _ e _, H2:sem_lexp_instant _ _ e _ |- _ =>
          apply IHe with (1:=H1) in H2; inversion H2; subst
        | H1:sem_unop _ _ _ = _, H2:sem_unop _ _ _ = _ |- _ =>
          rewrite H1 in H2; injection H2; intro; subst
        | H1:sem_lexp_instant _ _ _ (present _),
          H2:sem_lexp_instant _ _ _ absent |- _ =>
          apply IHe with (1:=H1) in H2
        end; try easy.
      - (* Ebinop *)
        intros v1 v2 Hsem1 Hsem2.
        inversion_clear Hsem1; inversion_clear Hsem2;
        repeat progress match goal with
        | H1:sem_lexp_instant _ _ e1 _, H2:sem_lexp_instant _ _ e1 _ |- _ =>
          apply IHe1 with (1:=H1) in H2
        | H1:sem_lexp_instant _ _ e2 _, H2:sem_lexp_instant _ _ e2 _ |- _ =>
          apply IHe2 with (1:=H1) in H2
        | H1:sem_binop _ _ _ _ _ = Some ?v1,
          H2:sem_binop _ _ _ _ _ = Some ?v2 |- _ =>
          rewrite H1 in H2; injection H2; intro; subst
        | H:present _ = present _ |- _ => injection H; intro; subst
        end; subst; try easy.
    Qed.

    Lemma sem_laexp_instant_det:
      forall ck e v1 v2,
        sem_laexp_instant base R ck e v1
        -> sem_laexp_instant base R ck e v2
        -> v1 = v2.
    Proof.
      intros ck e v1 v2.
      do 2 inversion_clear 1;
        match goal with
        | H1:sem_lexp_instant _ _ _ _, H2:sem_lexp_instant _ _ _ _ |- _ =>
          eapply sem_lexp_instant_det; eassumption
        | H1:sem_clock_instant _ _ _ ?T, H2:sem_clock_instant _ _ _ ?F |- _ =>
          assert (T = F) by (eapply sem_clock_instant_det; eassumption);
            try discriminate
        end; auto.
    Qed.

    Lemma sem_lexps_instant_det:
      forall les cs1 cs2,
        sem_lexps_instant base R les cs1 ->
        sem_lexps_instant base R les cs2 ->
        cs1 = cs2.
    Proof.
      intros les cs1 cs2. apply Forall2_det. apply sem_lexp_instant_det.
    Qed.

    Lemma sem_laexps_instant_det:
      forall ck e v1 v2,
        sem_laexps_instant base R ck e v1
        -> sem_laexps_instant base R ck e v2
        -> v1 = v2.
    Proof.
      intros until v2.
      do 2 inversion_clear 1;
        match goal with
        | H1: sem_lexps_instant _ _ _ _, H2: sem_lexps_instant _ _ _ _ |- _ =>
          eapply sem_lexps_instant_det; eauto
        | H1:sem_clock_instant _ _ _ ?T, H2:sem_clock_instant _ _ _ ?F |- _ =>
          let H := fresh in
          assert (H: T = F) by (eapply sem_clock_instant_det; eassumption);
            try discriminate H
        end; congruence.
    Qed.

    Lemma sem_cexp_instant_det:
      forall e v1 v2,
        sem_cexp_instant base R e v1
        -> sem_cexp_instant base R e v2
        -> v1 = v2.
    Proof.
      induction e;
        do 2 inversion_clear 1;
        try repeat progress match goal with
            | H1: sem_cexp_instant ?bk ?R ?e ?l,
                  H2: sem_cexp_instant ?bk ?R ?e ?r |- _ =>
              apply IHe1 with (1:=H1) in H2
              || apply IHe2 with (1:=H1) in H2;
                injection H2; intro; subst
            | H1: sem_var_instant ?R ?i (present true_val),
                  H2: sem_var_instant ?R ?i (present false_val) |- _ =>
              apply sem_var_instant_det with (1:=H1) in H2;
                exfalso; injection H2; now apply true_not_false_val
            | H1: sem_lexp_instant ?bk ?R ?l ?v1,
                  H2: sem_lexp_instant ?bk ?R ?l ?v2 |- _ =>
              apply sem_lexp_instant_det with (1:=H1) in H2;
                discriminate || injection H2; intro; subst
            | H1: sem_var_instant ?R ?i (present _),
                  H2: sem_var_instant ?R ?i absent |- _ =>
              apply sem_var_instant_det with (1:=H1) in H2; discriminate
            | H1: val_to_bool _ = Some _,
                  H2:val_to_bool _ = Some _ |- _ =>
              rewrite H1 in H2; injection H2; intro; subst
                            end; auto.
      eapply sem_lexp_instant_det; eassumption.
    Qed.

    Lemma sem_caexp_instant_det:
      forall ck e v1 v2,
        sem_caexp_instant base R ck e v1
        -> sem_caexp_instant base R ck e v2
        -> v1 = v2.
    Proof.
      intros until v2.
      do 2 inversion_clear 1;
        match goal with
        | H1: sem_cexp_instant _ _ _ _,
              H2: sem_cexp_instant _ _ _ _ |- _ =>
          eapply sem_cexp_instant_det; eassumption
        | H1:sem_clock_instant _ _ _ ?T,
             H2:sem_clock_instant _ _ _ ?F |- _ =>
          let H := fresh in
          assert (H: T = F) by (eapply sem_clock_instant_det; eassumption);
            try discriminate H
        end; congruence.
    Qed.

  End InstantDeterminism.

  (** *** Lifted semantics *)

  Section LiftDeterminism.

    Variable bk : stream bool.

    Require Import Logic.FunctionalExtensionality.

    Lemma lift_det:
      forall {A B} (P: bool -> R -> A -> B -> Prop) (bk: stream bool)
                   H x (xs1 xs2 : stream B),
        (forall b R v1 v2, P b R x v1 -> P b R x v2 -> v1 = v2) ->
        lift bk P H x xs1 -> lift bk P H x xs2 -> xs1 = xs2.
    Proof.
      intros ** Hpoint H1 H2.
      extensionality n. specialize (H1 n). specialize (H2 n).
      eapply Hpoint; eassumption.
    Qed.

    Ltac apply_lift sem_det :=
      intros; eapply lift_det; try eassumption;
      compute; intros; eapply sem_det; eauto.

    Lemma sem_var_det:
      forall H x xs1 xs2,
        sem_var bk H x xs1 -> sem_var bk H x xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_var_instant_det.
    Qed.

    Lemma sem_clock_det : forall H ck bs1 bs2,
        sem_clock bk H ck bs1 -> sem_clock bk H ck bs2 -> bs1 = bs2.
    Proof.
      apply_lift sem_clock_instant_det.
    Qed.

    Lemma sem_lexp_det:
      forall H e xs1 xs2,
        sem_lexp bk H e xs1 -> sem_lexp bk H e xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_lexp_instant_det.
    Qed.

    Lemma sem_lexps_det:
      forall H les cs1 cs2,
        sem_lexps bk H les cs1 ->
        sem_lexps bk H les cs2 ->
        cs1 = cs2.
    Proof.
      apply_lift sem_lexps_instant_det.
    Qed.

    Lemma sem_laexp_det:
      forall H ck e xs1 xs2,
        sem_laexp bk H ck e xs1 -> sem_laexp bk H ck e xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_laexp_instant_det.
    Qed.

    Lemma sem_laexps_det:
      forall H ck e xs1 xs2,
        sem_laexps bk H ck e xs1 -> sem_laexps bk H ck e xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_laexps_instant_det.
    Qed.

    Lemma sem_cexp_det:
      forall H c xs1 xs2,
        sem_cexp bk H c xs1 -> sem_cexp bk H c xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_cexp_instant_det.
    Qed.

    Lemma sem_caexp_det:
      forall H ck c xs1 xs2,
        sem_caexp bk H ck c xs1 -> sem_caexp bk H ck c xs2 -> xs1 = xs2.
    Proof.
      apply_lift sem_caexp_instant_det.
    Qed.

  (* XXX: every semantics definition, including [sem_var] which doesn't
need it, takes a base clock value or base clock stream, except
[sem_var_instant]. For uniformity, we may want to pass a (useless)
clock to [sem_var_instant] too. *)

  End LiftDeterminism.

  Ltac sem_det :=
    match goal with
    | H1: sem_cexp_instant ?bk ?H ?C ?X,
          H2: sem_cexp_instant ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_cexp_instant_det; eexact H1 || eexact H2
    | H1: sem_cexp ?bk ?H ?C ?X,
          H2: sem_cexp ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_cexp_det; eexact H1 || eexact H2
    | H1: sem_lexps_instant ?bk ?H ?C ?X,
          H2: sem_lexps_instant ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_lexps_instant_det; eexact H1 || eexact H2
    | H1: sem_lexps ?bk ?H ?C ?X,
          H2: sem_lexps ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_lexps_det; eexact H1 || eexact H2
    | H1: sem_laexps_instant ?bk ?H ?ck ?C ?X,
          H2: sem_laexps_instant ?bk ?H ?ck ?C ?Y |- ?X = ?Y =>
      eapply sem_laexps_instant_det; eexact H1 || eexact H2
    | H1: sem_laexps ?bk ?H ?ck ?C ?X,
          H2: sem_laexps ?bk ?H ?ck ?C ?Y |- ?X = ?Y =>
      eapply sem_laexps_det; eexact H1 || eexact H2
    | H1: sem_lexp_instant ?bk ?H ?C ?X,
          H2: sem_lexp_instant ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_lexp_instant_det; eexact H1 || eexact H2
    | H1: sem_lexp ?bk ?H ?C ?X,
          H2: sem_lexp ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_lexp_det; eexact H1 || eexact H2
    | H1: sem_laexp_instant ?bk ?H ?CK ?C ?X,
          H2: sem_laexp_instant ?bk ?H ?CK ?C ?Y |- ?X = ?Y =>
      eapply sem_laexp_instant_det; eexact H1 || eexact H2
    | H1: sem_laexp ?bk ?H ?CK ?C ?X,
          H2: sem_laexp ?bk ?H ?CK ?C ?Y |- ?X = ?Y =>
      eapply sem_laexp_det; eexact H1 || eexact H2
    | H1: sem_var_instant ?H ?C ?X,
          H2: sem_var_instant ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_var_instant_det; eexact H1 || eexact H2
    | H1: sem_var ?bk ?H ?C ?X,
          H2: sem_var ?bk ?H ?C ?Y |- ?X = ?Y =>
      eapply sem_var_det; eexact H1 || eexact H2
    end.

  (** ** Properties of the [global] environment *)

  Lemma find_node_other:
    forall f node G node',
      node.(n_name) <> f
      -> (find_node f (node::G) = Some node'
         <-> find_node f G = Some node').
  Proof.
    intros f node G node' Hnf.
    apply BinPos.Pos.eqb_neq in Hnf.
    simpl.
    unfold ident_eqb.
    rewrite Hnf.
    reflexivity.
  Qed.

  Lemma sem_node_cons:
    forall node G f xs ys,
      Ordered_nodes (node::G)
      -> sem_node (node::G) f xs ys
      -> node.(n_name) <> f
      -> sem_node G f xs ys.
  Proof.
    intros node G f xs ys Hord Hsem Hnf.
    revert Hnf.
    induction Hsem as [
                     | bk H x ck f lae ls xs Hlae Hvars Hnode IH
                     | bk H x ck f lae y ys ls xs Hlae Hvars Hvar Hnode IH
                     |
                     |
                     | bk H f xs ys n (* i o v eqs ingt0 outgt0 defd vout nodup good *) Hbk Hf ? ? ? ? ? Heqs IH ]
                        using sem_node_mult
      with (P_equation := fun bk H eq => ~Is_node_in_eq node.(n_name) eq
                                      -> sem_equation G bk H eq)
           (P_reset := fun f r opaque_x xss opaque_y yss => node.(n_name) <> f ->
                                                         sem_reset G f r opaque_x xss opaque_y yss).
    - econstructor; eassumption.
    - intro Hnin.
      eapply @SEqApp with (1:=Hlae) (2:=Hvars).
      apply IH. intro Hnf. apply Hnin. rewrite Hnf. constructor.
    - intro Hnin.
      eapply SEqReset; eauto.
      apply IH. intro Hnf. apply Hnin. rewrite Hnf. constructor.
    - intro; eapply SEqFby; eassumption.
    - constructor; intro. auto.
    - intro.
      rewrite find_node_tl with (1:=Hnf) in Hf.
      eapply SNode; eauto.
      (* clear Heqs. *)
      (* destruct IH as (H & Hxs & Hys & Hout & Hsamexs & Hsameys & Heqs). *)
      (* exists H. *)
      (* repeat (split; eauto). *)
      (* set (cnode := {| n_name  := f; *)
      (*                  n_in    := i; *)
      (*                  n_out   := o; *)
      (*                  n_vars  := v; *)
      (*                  n_eqs   := eqs; *)
      (*                  n_ingt0 := ingt0; *)
      (*                  n_outgt0 := outgt0; *)
      (*                  n_defd  := defd; *)
      (*                  n_vout  := vout; *)
      (*                  n_nodup := nodup; *)
      (*                  n_good  := good *)
      (*               |}). *)
      assert (Forall (fun eq => ~ Is_node_in_eq (n_name node) eq) (n_eqs n))
        by (eapply Is_node_in_Forall; try eassumption;
            eapply find_node_later_not_Is_node_in; try eassumption).
      clear Heqs (* cnode Hf defd good vout *);
        induction n.(n_eqs); inv IH; inv H5; eauto.
  Qed.

  Lemma find_node_find_again:
    forall G f n (* i o v eqs ingt0 outgt0 defd vout nodup good *) g,
      Ordered_nodes G
      -> find_node f G = Some n
         (* Some {| n_name := f; n_in := i; n_out := o; *)
         (*         n_vars := v; n_eqs := eqs; *)
         (*         n_ingt0 := ingt0; n_outgt0 := outgt0; n_defd := defd; n_vout := vout; *)
         (*         n_nodup := nodup; n_good := good |} *)
      -> Is_node_in g n.(n_eqs)
      -> Exists (fun nd => g = nd.(n_name)) G.
  Proof.
    intros G f n (* i o v eqs ingt0 outgt0 defd vout nodup good *) g Hord Hfind Hini.
    apply find_node_split in Hfind.
    destruct Hfind as [bG [aG Hfind]].
    rewrite Hfind in *.
    clear Hfind.
    apply Ordered_nodes_append in Hord.
    apply Exists_app.
    constructor 2.
    inversion_clear Hord as [|? ? ? HH H0]; clear H0.
    apply HH in Hini; clear HH.
    intuition.
  Qed.

  Lemma sem_node_cons2:
    forall nd G f xs ys,
      Ordered_nodes G
      -> sem_node G f xs ys
      -> Forall (fun nd' : node => n_name nd <> n_name nd') G
      -> sem_node (nd::G) f xs ys.
  Proof.
    Hint Constructors sem_equation.
    intros nd G f xs ys Hord Hsem Hnin.
    assert (Hnin':=Hnin).
    revert Hnin'.
    induction Hsem as [
       | bk H x ? f lae ls xs Hlae Hvars Hnode IH
       | bk H x f lae y ys ls xs Hlae Hvars Hvar Hnode IH
       |
       |
       | bk H f xs ys n (* i o v eqs ingt0 outgt0 defd vout nodup good *) Hbk Hfind Hxs Hys ? ? ? Heqs IH]
          using sem_node_mult
        with (P_equation := fun bk H eq =>
                     ~Is_node_in_eq nd.(n_name) eq
                     -> sem_equation (nd::G) bk H eq)
             (P_reset := fun f r xss yss => sem_reset (nd::G) f r xss yss);
      try eauto; try intro HH.
    - econstructor; eauto.
    - clear HH.
      assert (nd.(n_name) <> f) as Hnf.
      { intro Hnf.
        rewrite Hnf in *.
        pose proof Hfind as Hfind'.
        apply find_node_split in Hfind.
        destruct Hfind as [bG [aG Hge]].
        rewrite Hge in Hnin.
        apply Forall_app in Hnin.
        destruct Hnin as [? Hfg].
        inversion_clear Hfg.
        match goal with H:f<>_ |- False => apply H end.
        erewrite find_node_name; eauto.
      }
      apply find_node_other with (2:=Hfind) in Hnf.
      econstructor; eauto.
      clear Heqs Hxs Hys.
      rename IH into Heqs.
      (* destruct IH as (H & Hxs & Hys & Hout & Hsamexs & Hsameys & Heqs). *)
      (* exists H. *)
      (* clear Hxs Hys. *)
      assert (forall g, Is_node_in g n.(n_eqs)
                   -> Exists (fun nd=> g = nd.(n_name)) G)
        as Hniex by
            (intros g Hini;
             eapply find_node_find_again with (1:=Hord) (2:=Hfind) in Hini; eauto).
      assert (Forall
                (fun eq=> forall g,
                     Is_node_in_eq g eq
                     -> Exists (fun nd=> g = nd.(n_name)) G) n.(n_eqs)) as HH.
      {
        clear (* defd vout nodup good  *)Hfind Heqs Hnf.
        induction n.(n_eqs) as [|eq eqs IH]; [now constructor|].
        constructor.
        - intros g Hini.
          apply Hniex.
          constructor 1; apply Hini.
        - apply IH.
          intros g Hini; apply Hniex.
          constructor 2; apply Hini.
      }
      apply Forall_Forall with (1:=HH) in Heqs.
      apply Forall_impl with (2:=Heqs).
      intros eq IH.
      destruct IH as [Hsem IH1].
      apply IH1.
      intro Hini.
      apply Hsem in Hini.
      apply Forall_Exists with (1:=Hnin) in Hini.
      apply Exists_exists in Hini.
      destruct Hini as [nd' [Hin [Hneq Heq]]].
      intuition.
  Qed.


  Lemma Forall_sem_equation_global_tl:
    forall bk nd G H eqs,
      Ordered_nodes (nd::G)
      -> ~ Is_node_in nd.(n_name) eqs
      -> Forall (sem_equation (nd::G) bk H) eqs
      -> Forall (sem_equation G bk H) eqs.
  Proof.
    intros bk nd G H eqs Hord.
    induction eqs as [|eq eqs IH]; [trivial|].
    intros Hnini Hsem.
    apply Forall_cons2 in Hsem; destruct Hsem as [Hseq Hseqs].
    apply IH in Hseqs.
    2:(apply not_Is_node_in_cons in Hnini;
        destruct Hnini; assumption).
    apply Forall_cons with (2:=Hseqs).
    inversion Hseq as [|? ? ? ? ? ? ? Hsem Hvars Hnode
                          |? ? ? ? ? ? ? ? ? Hsem Hvars Hvar Hnode|]; subst.
    - econstructor; eassumption.
    - apply not_Is_node_in_cons in Hnini.
      destruct Hnini as [Hninieq Hnini].
      assert (nd.(n_name) <> f) as Hnf
          by (intro HH; apply Hninieq; rewrite HH; constructor).
      econstructor; eauto.
      eapply sem_node_cons; eauto.
    - apply not_Is_node_in_cons in Hnini.
      destruct Hnini as [Hninieq Hnini].
      assert (nd.(n_name) <> f) as Hnf
          by (intro HH; apply Hninieq; rewrite HH; constructor).
      econstructor; eauto.
      inv H1.
      constructor; intro.
      eapply sem_node_cons; eauto.
    - econstructor; eauto.
  Qed.

  (** ** Clocking property *)

  Lemma subrate_clock:
    forall R ck,
      sem_clock_instant false R ck false.
  Proof.
    Hint Constructors sem_clock_instant.
    intros R ck.
    induction ck; eauto.
  Qed.

  (* XXX: Similarly, instead of [rhs_absent_instant] and friends, we
should prove that all the semantic rules taken at [base = false] yield
an absent value *)

  (** ** Presence and absence in non-empty lists *)

  Lemma not_absent_present_list:
    forall xs,
      0 < length xs ->
      present_list xs ->
      ~ absent_list xs.
  Proof.
  intros * Hnz Hpres Habs.
  unfold present_list in Hpres.
  unfold absent_list in Habs.
  destruct xs; [now inversion Hnz|].
  now inv Hpres; inv Habs; auto.
  Qed.

  Lemma present_not_absent_list:
    forall xs (vs: list val),
      instant_same_clock xs ->
      ~ absent_list xs ->
      present_list xs.
  Proof.
  intros ** Hsamexs Hnabs.
  now destruct Hsamexs.
  Qed.

  Lemma absent_list_spec:
    forall xs,
      absent_list xs <-> xs = map (fun _ => absent) xs.
  Proof.
  induction xs; simpl; split; intro; try constructor(auto).
  - inv H. apply f_equal. now apply IHxs.
  - now inversion H.
  - inversion H. rewrite <- H2. now apply IHxs.
  Qed.


  Lemma present_list_spec:
    forall xs,
      present_list xs <-> exists vs, xs = map present vs.
  Proof.
  induction xs as [| x xs IHxs].
  - split; intro H.
    + exists []; eauto.
    + constructor.
  - split; intro H.
    + inversion H as [| ? ? Hx Hxs]; subst.
      apply not_absent_present in Hx as [v Hv].
      apply IHxs in Hxs as [vs Hvs].
      exists (v :: vs). simpl.
      congruence.
    + destruct H as [vs Hvs].
      destruct vs; simpl; try discriminate.
      apply Forall_cons.
      * intro. subst x; discriminate.
      * eapply IHxs.
        exists vs. now inv Hvs.
  Qed.

  Lemma sem_vars_gt0:
    forall bk H (xs: list (ident * type)) ls,
      0 < length xs ->
      sem_vars bk H (map fst xs) ls ->
      forall n, 0 < length (ls n).
  Proof.
    intros ** Hgt0 Hsem n.
    unfold sem_vars, lift in Hsem.
    specialize Hsem with n.
    apply Forall2_length in Hsem.
    rewrite map_length in Hsem.
    now rewrite Hsem in Hgt0.
  Qed.

  Lemma sem_equations_permutation:
    forall eqs eqs' G bk H,
      Forall (sem_equation G bk H) eqs ->
      Permutation eqs eqs' ->
      Forall (sem_equation G bk H) eqs'.
  Proof.
    intros eqs eqs' G bk H Hsem Hperm.
    induction Hperm as [|eq eqs eqs' Hperm IH|eq0 eq1 eqs|]; auto.
    - inv Hsem; auto.
    - inversion_clear Hsem as [|? ? ? Heqs'].
      inv Heqs'; auto.
  Qed.

  (** Morphisms properties *)

  Lemma clock_of_compat:
    forall xs xs' bk,
      (forall n, xs n = xs' n) ->
      clock_of xs bk ->
      clock_of xs' bk.
  Proof.
    unfold clock_of. intros ** E Pres n.
    split; intros H.
    - apply Pres.
      specialize (E n).
      induction H; rewrite E; constructor; auto.
    - apply Pres in H.
      specialize (E n).
      induction H; rewrite <-E; constructor; auto.
  Qed.

  Lemma sem_vars_compat:
    forall H bk x xs xs',
      (forall n, xs n = xs' n) ->
      sem_vars bk H x xs ->
      sem_vars bk H x xs'.
  Proof.
    unfold sem_vars, lift; intros ** E Sem n.
    specialize (E n); specialize (Sem n).
    induction Sem; rewrite <-E; constructor; auto.
  Qed.

  Lemma same_clock_compat:
    forall xs xs',
      (forall n, xs n = xs' n) ->
      same_clock xs ->
      same_clock xs'.
  Proof.
    unfold same_clock; intros ** E ? ?; rewrite <-E; auto.
  Qed.

 Lemma sem_node_compat:
    forall G f xss xss' yss yss',
      (forall n, xss n = xss' n) ->
      (forall n, yss n = yss' n) ->
      sem_node G f xss yss ->
      sem_node G f xss' yss'.
  Proof.
    intros ** Exss Eyss Node.
    inv Node.
    econstructor; eauto.
    - eapply clock_of_compat; eauto.
    - eapply sem_vars_compat; eauto.
    - eapply sem_vars_compat; eauto.
    - eapply same_clock_compat; eauto.
    - eapply same_clock_compat; eauto.
    - intro; rewrite <-Exss, <-Eyss; auto.
  Qed.

  Corollary sem_reset_compat:
    forall G f r r' opaque_x xss opaque_o oss,
      (forall n, r n = r' n) ->
      sem_reset G f r opaque_x xss opaque_o oss ->
      sem_reset G f r' opaque_x xss opaque_o oss.
  Proof.
    intros ** E Res.
    inversion_clear Res as [? ? ? ? Node].
    constructor; intro n.
    pose proof (mask_compat _ _ n opaque_x xss E).
    pose proof (mask_compat _ _ n opaque_o oss E).
    eapply sem_node_compat; eauto.
  Qed.

End NLSEMANTICS.

Module NLSemanticsFun
       (Ids   : IDS)
       (Op    : OPERATORS)
       (OpAux : OPERATORS_AUX Op)
       (Clks  : CLOCKS    Ids)
       (Syn   : NLSYNTAX  Ids Op Clks)
       (Str   : STREAM        Op OpAux)
       (Ord   : ORDERED   Ids Op Clks Syn)
       <: NLSEMANTICS Ids Op OpAux Clks Syn Str Ord.
  Include NLSEMANTICS Ids Op OpAux Clks Syn Str Ord.
End NLSemanticsFun.
