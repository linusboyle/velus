Require Import List.
Import List.ListNotations.
Open Scope list_scope.
Require Import Coq.Sorting.Permutation.
Require Import Morphisms.
Require Import Coq.Program.Tactics.

Require Import Coq.FSets.FMapPositive.
Require Import Velus.Common.
Require Import Velus.Operators.
Require Import Velus.Clocks.
Require Import Velus.NLustre.NLExprSyntax.
Require Import Velus.NLustre.NLSyntax.
Require Import Velus.NLustre.Ordered.
Require Import Velus.NLustre.Stream.
Require Import Velus.NLustre.Streams.

Require Import Velus.NLustre.NLExprSemantics.
Require Import Velus.NLustre.NLSemantics.
Require Import Velus.NLustre.NLSemanticsCoInd.

Require Import Setoid.
Module Type COINDTOINDEXED
       (Import Ids     : IDS)
       (Import Op      : OPERATORS)
       (Import OpAux   : OPERATORS_AUX        Op)
       (Import Clks    : CLOCKS           Ids)
       (Import ExprSyn : NLEXPRSYNTAX        Op)
       (Import Syn     : NLSYNTAX        Ids Op       Clks ExprSyn)
       (Import Str     : STREAM               Op OpAux)
       (Import Ord     : ORDERED          Ids Op       Clks ExprSyn Syn)
       (ExprIdx        : NLEXPRSEMANTICS  Ids Op OpAux Clks ExprSyn     Str)
       (Indexed        : NLSEMANTICS      Ids Op OpAux Clks ExprSyn Syn Str Ord ExprIdx)
       (CoInd          : NLSEMANTICSCOIND Ids Op OpAux Clks ExprSyn Syn).

  Section Global.

    Variable G : global.

    (** * BASIC CORRESPONDENCES *)

    (** ** Definitions  *)

    (** Translate a coinductive Stream into an indexed stream.
        The result stream is the function which associates the [n]th element of
        the input Stream to each [n].
     *)
    Definition tr_Stream {A} (xs: Stream A) : stream A :=
      fun n => Str_nth n xs.

    (** Translate a list of Streams into a stream of list.
        - if the input list is void, the result is the constantly void stream
        - else, the result is the function associating to each [n] the list
          built by the translated stream of the head of the input list indexed
          at [n] consed to the result of the recursive call, also indexed at [n].
     *)
    Fixpoint tr_Streams {A} (xss: list (Stream A)) : stream (list A) :=
      match xss with
      | [] => fun n => []
      | xs :: xss => fun n => tr_Stream xs n :: tr_Streams xss n
      end.

    (** Translate an history from coinductive to indexed world.
        Every element of the history is translated.
     *)
    Definition tr_History (H: CoInd.History) : ExprIdx.history :=
      Env.map tr_Stream H.

    (** ** Properties  *)

    (** Indexing a translated Stream at [0] is taking the head of the source
        Stream. *)
    Lemma tr_Stream_0:
      forall {A} (xs: Stream A) x,
        tr_Stream (x ::: xs) 0 = x.
    Proof. reflexivity. Qed.

    (** Indexing a translated Stream at [S n] is indexing the tail of the source
        Stream at [n]. *)
    Lemma tr_Stream_S:
      forall {A} (xs: Stream A) x n,
        tr_Stream (x ::: xs) (S n) = tr_Stream xs n.
    Proof. reflexivity. Qed.

    (** Another version of the previous lemma.  *)
    Lemma tr_Stream_tl:
      forall {A} (xs: Stream A) n,
        tr_Stream (tl xs) n = tr_Stream xs (S n).
    Proof. reflexivity. Qed.

    (** A generalized version *)
    Lemma tr_Stream_nth:
      forall {A} n (xs: Stream A),
        tr_Stream xs n = Str_nth n xs.
    Proof. reflexivity. Qed.

    Lemma tr_Stream_const:
      forall {A} (c: A) n,
        tr_Stream (Streams.const c) n = c.
    Proof.
      induction n; rewrite unfold_Stream at 1; simpl.
      - now rewrite tr_Stream_0.
      - now rewrite tr_Stream_S.
    Qed.

    (** [tr_Stream] is compatible wrt to [EqSt]. *)
    Add Parametric Morphism A : (@tr_Stream A)
        with signature @EqSt A ==> eq ==> eq
          as tr_Stream_morph.
    Proof.
      intros xs ys Exs n.
      revert xs ys Exs; induction n; intros; destruct xs, ys; inv Exs.
      - rewrite 2 tr_Stream_0; auto.
      - rewrite 2 tr_Stream_S; auto.
    Qed.

    Fact tr_Streams_app:
      forall A (xss yss: list (Stream A)) n,
        tr_Streams (xss ++ yss) n = tr_Streams xss n ++ tr_Streams yss n.
    Proof.
      intros; induction xss; simpl; auto.
      f_equal; auto.
    Qed.

    (** The counterpart of [tr_Stream_tl] for lists of Streams. *)
    Lemma tr_Streams_tl:
      forall xss n,
        tr_Streams (List.map (tl (A:=value)) xss) n = tr_Streams xss (S n).
    Proof.
      intros; induction xss; simpl; auto.
      f_equal; auto.
    Qed.

    (** The counterpart of [tr_Stream_tl] for histories. *)
    Lemma tr_History_tl:
      forall n H,
        ExprIdx.restr_hist (tr_History H) (S n)
        = ExprIdx.restr_hist (tr_History (CoInd.History_tl H)) n.
    Proof.
      now repeat setoid_rewrite Env.map_map.
    Qed.

    (** * SEMANTICS CORRESPONDENCE *)

    (** ** Variables *)

    Lemma sem_var_impl:
      forall H x xs,
      CoInd.sem_var H x xs ->
      ExprIdx.sem_var (tr_History H) x (tr_Stream xs).
    Proof.
      intros ** Find n.
      unfold ExprIdx.sem_var_instant.
      inversion_clear Find as [???? Find' E].
      unfold ExprIdx.restr_hist, tr_History.
      unfold Env.map.
      rewrite 2 Env.gmapi, Find', E; simpl; auto.
    Qed.
    Hint Resolve sem_var_impl.

    Corollary sem_vars_impl:
      forall H xs xss,
      Forall2 (CoInd.sem_var H) xs xss ->
      ExprIdx.sem_vars (tr_History H) xs (tr_Streams xss).
    Proof.
      unfold ExprIdx.sem_vars, ExprIdx.lift'.
      induction 1 as [|? ? ? ? Find];
        simpl; intro; constructor; auto.
      - apply sem_var_impl; auto.
      - apply IHForall2.
    Qed.
    Hint Resolve sem_vars_impl.

    (** ** Synchronization *)

    Lemma same_clock_impl:
      forall xss,
        CoInd.same_clock xss ->
        ExprIdx.same_clock (tr_Streams xss).
    Proof.
      unfold ExprIdx.same_clock, ExprIdx.instant_same_clock.
      intros.
      destruct (H n) as [E|Ne].
      - left; induction xss; simpl; constructor; inv E; auto.
        apply IHxss; auto.
        eapply CoInd.same_clock_cons; eauto.
      - right; induction xss; simpl; constructor; inv Ne; auto.
        apply IHxss; eauto using CoInd.same_clock_cons.
    Qed.
    Hint Resolve same_clock_impl.

    Lemma same_clock_app_impl:
      forall xss yss,
        xss <> [] ->
        yss <> [] ->
        CoInd.same_clock (xss ++ yss) ->
        forall n, absent_list (tr_Streams xss n)
             <-> absent_list (tr_Streams yss n).
    Proof.
      intros ** Hxss Hyss Same n.
      apply same_clock_impl in Same.
      unfold ExprIdx.same_clock, ExprIdx.instant_same_clock in Same;
        specialize (Same n).
      split; intros Indexed.
      - destruct Same as [E|Ne].
        + rewrite tr_Streams_app in E; apply Forall_app in E; tauto.
        + rewrite tr_Streams_app in Ne; apply Forall_app in Ne as [NIndexed].
          induction xss; simpl in *; inv NIndexed; try now inv Indexed.
          now contradict Hxss.
      - destruct Same as [E|Ne].
        + rewrite tr_Streams_app in E; apply Forall_app in E; tauto.
        + rewrite tr_Streams_app in Ne; apply Forall_app in Ne as [? NIndexed].
          induction yss; simpl in *; inv NIndexed; try now inv Indexed.
          now contradict Hyss.
    Qed.
    Hint Resolve same_clock_app_impl.

    (** ** lexp level synchronous operators specifications

        To ease the use of coinductive hypotheses to prove non-coinductive
        goals, we give for each coinductive predicate an indexed specification,
        reflecting the shapes of the involved streams pointwise speaking.
        In general this specification is a disjunction with a factor for each
        case of the predicate.
        The corresponding lemmas simply go by induction on [n] and by inversion
        of the coinductive hypothesis.
     *)

    Lemma const_index:
      forall n xs c b,
        xs ≡ CoInd.const c b ->
        tr_Stream xs n = if tr_Stream b n then present (sem_const c) else absent.
    Proof.
      induction n; intros ** E;
        unfold_Stv b; unfold_Stv xs; inv E; simpl in *; try discriminate;
          repeat rewrite tr_Stream_0; repeat rewrite tr_Stream_S; auto.
    Qed.

    Lemma when_index:
      forall n k xs cs rs,
        CoInd.when k xs cs rs ->
        (tr_Stream xs n = absent
         /\ tr_Stream cs n = absent
         /\ tr_Stream rs n = absent)
        \/
        (exists x c,
            tr_Stream xs n = present x
            /\ tr_Stream cs n = present c
            /\ val_to_bool c = Some (negb k)
            /\ tr_Stream rs n = absent)
        \/
        (exists x c,
            tr_Stream xs n = present x
            /\ tr_Stream cs n = present c
            /\ val_to_bool c = Some k
            /\ tr_Stream rs n = present x).
    Proof.
      induction n; intros ** When.
      - inv When; repeat rewrite tr_Stream_0; intuition.
        + right; left. do 2 eexists; intuition.
        + right; right. do 2 eexists; intuition.
      - inv When; repeat rewrite tr_Stream_S; auto.
    Qed.

    Lemma lift1_index:
      forall n op t xs ys,
        CoInd.lift1 op t xs ys ->
        (tr_Stream xs n = absent /\ tr_Stream ys n = absent)
        \/
        (exists x y,
            tr_Stream xs n = present x
            /\ sem_unop op x t = Some y
            /\ tr_Stream ys n = present y).
    Proof.
      induction n; intros ** Lift1.
      - inv Lift1; repeat rewrite tr_Stream_0; intuition.
        right. do 2 eexists; intuition; auto.
      - inv Lift1; repeat rewrite tr_Stream_S; auto.
    Qed.

    Lemma lift2_index:
      forall n op t1 t2 xs ys zs,
        CoInd.lift2 op t1 t2 xs ys zs ->
        (tr_Stream xs n = absent
         /\ tr_Stream ys n = absent
         /\ tr_Stream zs n = absent)
        \/
        (exists x y z,
            tr_Stream xs n = present x
            /\ tr_Stream ys n = present y
            /\ sem_binop op x t1 y t2 = Some z
            /\ tr_Stream zs n = present z).
    Proof.
      induction n; intros ** Lift2.
      - inv Lift2; repeat rewrite tr_Stream_0; intuition.
        right. do 3 eexists; intuition; auto.
      - inv Lift2; repeat rewrite tr_Stream_S; auto.
    Qed.

    (** ** Semantics of clocks *)

    (** Give an indexed specification for [sem_clock] in the previous style,
        with added complexity as [sem_clock] depends on [H] and [b].
        We go by induction on the clock [ck] then by induction on [n] and
        inversion of the coinductive hypothesis as before. *)
    Hint Constructors ExprIdx.sem_clock_instant.
    Lemma sem_clock_index:
      forall n H b ck bs,
        CoInd.sem_clock H b ck bs ->
        (ck = Cbase
         /\ tr_Stream b n = tr_Stream bs n)
        \/
        (exists ck' x k c,
            ck = Con ck' x k
            /\ ExprIdx.sem_clock_instant
                (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) ck' true
            /\ ExprIdx.sem_var_instant (ExprIdx.restr_hist (tr_History H) n) x
                                      (present c)
            /\ val_to_bool c = Some k
            /\ tr_Stream bs n = true)
        \/
        (exists ck' x k,
            ck = Con ck' x k
            /\ ExprIdx.sem_clock_instant
                (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) ck' false
            /\ ExprIdx.sem_var_instant (ExprIdx.restr_hist (tr_History H) n) x absent
            /\ tr_Stream bs n = false)
        \/
        (exists ck' x k c,
            ck = Con ck' x (negb k)
            /\ ExprIdx.sem_clock_instant
                (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) ck' true
            /\ ExprIdx.sem_var_instant (ExprIdx.restr_hist (tr_History H) n) x
                                      (present c)
            /\ val_to_bool c = Some k
            /\ tr_Stream bs n = false).
    Proof.
      Local Ltac rew_0 :=
        try match goal with
              H: tr_Stream _ _ = _ |- _ => now rewrite tr_Stream_0 in H
            end.
      intros n H b ck; revert n H b; induction ck as [|ck ? x k].
      - inversion_clear 1 as [? ? ? Eb| | |].
        left; intuition.
        now rewrite Eb.
      - intro n; revert x k; induction n; intros x k H bk bk' Indexed.
        + inversion_clear Indexed as [|? ? ? ? ? ? ? ? ? IndexedCk Hvar
                                     |? ? ? ? ? ? ? ? IndexedCk Hvar
                                     |? ? ? ? ? ? ? ? ? IndexedCk Hvar].
          * right; left.
            apply sem_var_impl in Hvar;
              unfold ExprIdx.sem_var, ExprIdx.lift in Hvar ; specialize (Hvar 0);
                rewrite tr_Stream_0 in Hvar.
            do 4 eexists; intuition; eauto.
            apply (IHck 0) in IndexedCk as [(? & E)|[|[]]]; destruct_conjs;
              subst; eauto; rew_0.
            rewrite E, tr_Stream_0; constructor.
          * right; right; left.
            apply sem_var_impl in Hvar;
              unfold ExprIdx.sem_var, ExprIdx.lift in Hvar ; specialize (Hvar 0);
                rewrite tr_Stream_0 in Hvar.
            do 3 eexists; intuition.
            apply (IHck 0) in IndexedCk as [(? & E)|[|[]]]; destruct_conjs;
              subst; eauto; rew_0.
            rewrite E, tr_Stream_0; constructor.
          * right; right; right.
            apply sem_var_impl in Hvar;
              unfold ExprIdx.sem_var, ExprIdx.lift in Hvar; specialize (Hvar 0);
                rewrite tr_Stream_0 in Hvar.
            do 4 eexists; intuition; eauto.
            apply (IHck 0) in IndexedCk as [(? & E)|[|[]]]; destruct_conjs;
              subst; eauto; rew_0.
            rewrite E, tr_Stream_0; constructor.
        + inversion_clear Indexed; rewrite <-tr_Stream_tl, tr_History_tl; eauto.
    Qed.

    (** We can then deduce the correspondence lemma for [sem_clock]. *)
    Corollary sem_clock_impl:
      forall n H b ck bs,
        CoInd.sem_clock H b ck bs ->
        ExprIdx.sem_clock_instant (tr_Stream b n)
                                  (ExprIdx.restr_hist (tr_History H) n) ck
                                  (tr_Stream bs n).
    Proof.
      intros ** Indexed.
      apply (sem_clock_index n) in Indexed as [|[|[|]]]; destruct_conjs;
        match goal with H: tr_Stream _ _ = _ |- _ => rewrite H end;
        subst; eauto.
    Qed.
    Hint Resolve sem_clock_impl.

    (* (** Give an indexed specification for annotated [var]. *) *)
    (* Lemma sem_avar_index: *)
    (*   forall n H b ck x vs, *)
    (*     CoInd.sem_avar H b ck x vs -> *)
    (*     (ExprIdx.sem_clock_instant (tr_Stream b n) *)
    (*                                (ExprIdx.restr_hist (tr_History H) n) ck false *)
    (*      /\ ExprIdx.sem_var_instant (ExprIdx.restr_hist (tr_History H) n) x absent *)
    (*      /\ tr_Stream vs n = absent) *)
    (*     \/ *)
    (*     (exists v, *)
    (*         ExprIdx.sem_clock_instant (tr_Stream b n) *)
    (*                                   (ExprIdx.restr_hist (tr_History H) n) ck true *)
    (*         /\ ExprIdx.sem_var_instant (ExprIdx.restr_hist (tr_History H) n) x (present v) *)
    (*         /\ tr_Stream vs n = present v). *)
    (* Proof. *)
    (*   induction n; intros ** Indexed. *)
    (*   - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed' Hck *)
    (*                                   |? ? ? ? ? ? Indexed' Hck]; *)
    (*       apply sem_var_impl with (b:=tr_Stream b) in Indexed'; specialize (Indexed' 0); *)
    (*         repeat rewrite tr_Stream_0; repeat rewrite tr_Stream_0 in Indexed'; *)
    (*           apply (sem_clock_impl 0) in Hck; rewrite tr_Stream_0 in Hck. *)
    (*     + right. eexists; intuition; auto. *)
    (*     + left; intuition. *)
    (*   - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed'|? ? ? ? ? ? Indexed']; *)
    (*       apply sem_var_impl with (b:=tr_Stream b) in Indexed'; *)
    (*       rewrite tr_Stream_S, tr_History_tl; eauto. *)
    (* Qed. *)

    (* (** We deduce from the previous lemma the correspondence for annotated *)
    (*     [var]. *) *)
    (* Hint Constructors Indexed.sem_avar_instant. *)
    (* Corollary sem_avar_impl: *)
    (*   forall H b x vs ck, *)
    (*     CoInd.sem_avar H b ck x vs -> *)
    (*     Indexed.sem_avar (tr_Stream b) (tr_History H) ck x (tr_Stream vs). *)
    (* Proof. *)
    (*   intros ** Indexed n. *)
    (*   apply (sem_avar_index n) in Indexed as [(? & ? & Hes)|(? & ? & ? & Hes)]; *)
    (*     rewrite Hes; auto. *)
    (* Qed. *)
    (* Hint Resolve sem_avar_impl. *)

    (** ** Semantics of lexps *)

    (** State the correspondence for [lexp].
        Goes by induction on the coinductive semantics of [lexp]. *)
    Hint Constructors ExprIdx.sem_lexp_instant.
    Lemma sem_lexp_impl:
      forall H b e es,
        CoInd.sem_lexp H b e es ->
        ExprIdx.sem_lexp (tr_Stream b) (tr_History H) e (tr_Stream es).
    Proof.
      induction 1 as [? ? ? ? Hconst
                            |? ? ? ? ? Hvar
                            |? ? ? ? ? ? ? ? ? ? Hvar Hwhen
                            |? ? ? ? ? ? ? ? ? Hlift1
                            |? ? ? ? ? ? ? ? ? ? ? ? ? Hlift2]; intro n.
      - apply (const_index n) in Hconst; rewrite Hconst.
        destruct (tr_Stream b n); eauto.
      - apply sem_var_impl in Hvar; eauto.
      - specialize (IHsem_lexp n).
        apply sem_var_impl in Hvar.
        unfold ExprIdx.sem_var, ExprIdx.lift in Hvar.
        specialize (Hvar n).
        apply (when_index n) in Hwhen
          as [(Hes & Hxs & Hos)
             |[(? & ? & Hes & Hxs & ? & Hos)
              |(? & ? & Hes & Hxs & ? & Hos)]];
          rewrite Hos; rewrite Hes in IHsem_lexp; rewrite Hxs in Hvar;
            eauto.
        rewrite <-(Bool.negb_involutive k); eauto.
      - specialize (IHsem_lexp n).
        apply (lift1_index n) in Hlift1
          as [(Hes & Hos)|(? & ? & Hes & ? & Hos)];
          rewrite Hos; rewrite Hes in IHsem_lexp; eauto.
      - specialize (IHsem_lexp1 n).
        specialize (IHsem_lexp2 n).
        apply (lift2_index n) in Hlift2
          as [(Hes1 & Hes2 & Hos)|(? & ? & ? & Hes1 & Hes2 & ? & Hos)];
          rewrite Hos; rewrite Hes1 in IHsem_lexp1; rewrite Hes2 in IHsem_lexp2;
            eauto.
    Qed.
    Hint Resolve sem_lexp_impl.

    Lemma tl_const:
      forall c b bs,
        tl (CoInd.const c (b ::: bs)) = CoInd.const c bs.
    Proof.
      destruct b; auto.
    Qed.

    (** Give an indexed specification for annotated [lexp], using the previous
        lemma. *)
    Lemma sem_laexp_index:
      forall n H b ck le es,
        CoInd.sem_laexp H b ck le es ->
        (ExprIdx.sem_clock_instant (tr_Stream b n)
                                   (ExprIdx.restr_hist (tr_History H) n) ck false
         /\ ExprIdx.sem_lexp_instant
             (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) le absent
         /\ tr_Stream es n = absent)
        \/
        (exists e,
            ExprIdx.sem_clock_instant (tr_Stream b n)
                                      (ExprIdx.restr_hist (tr_History H) n) ck true
            /\ ExprIdx.sem_lexp_instant
                (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) le (present e)
            /\ tr_Stream es n = present e).
    Proof.
      induction n; intros ** Indexed.
      - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed' Hck
                                      |? ? ? ? ? ? Indexed' Hck];
          apply sem_lexp_impl in Indexed'; specialize (Indexed' 0);
            repeat rewrite tr_Stream_0; repeat rewrite tr_Stream_0 in Indexed';
              apply (sem_clock_impl 0) in Hck; rewrite tr_Stream_0 in Hck.
        + right. eexists; intuition; auto.
        + left; intuition.
      - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed'|? ? ? ? ? ? Indexed'];
          apply sem_lexp_impl in Indexed';
          rewrite tr_Stream_S, tr_History_tl; eauto.
    Qed.

    (** We deduce from the previous lemma the correspondence for annotated
        [lexp]. *)
    (* Hint Constructors ExprIdx.sem_laexp_instant. *)
    Corollary sem_laexp_impl:
      forall H b e es ck,
        CoInd.sem_laexp H b ck e es ->
        ExprIdx.sem_laexp (tr_Stream b) (tr_History H) ck e (tr_Stream es).
    Proof.
      intros ** Indexed n.
      apply (sem_laexp_index n) in Indexed as [(? & ? & Hes)|(? & ? & ? & Hes)];
        rewrite Hes; constructor; auto.
    Qed.
    Hint Resolve sem_laexp_impl.

    (** Specification for lists of annotated [lexp] (on the same clock). *)
    Lemma sem_laexps_index:
      forall n H b ck les ess,
        CoInd.sem_laexps H b ck les ess ->
        (ExprIdx.sem_clock_instant (tr_Stream b n)
                                   (ExprIdx.restr_hist (tr_History H) n) ck false
         /\ ExprIdx.sem_lexps_instant (tr_Stream b n)
                                     (ExprIdx.restr_hist (tr_History H) n) les
                                     (tr_Streams ess n)
         /\ tr_Streams ess n = List.map (fun _ => absent) les)
        \/
        (ExprIdx.sem_clock_instant (tr_Stream b n)
                                   (ExprIdx.restr_hist (tr_History H) n) ck true
         /\ ExprIdx.sem_lexps_instant (tr_Stream b n)
                                     (ExprIdx.restr_hist (tr_History H) n) les
                                     (tr_Streams ess n)
         /\ Forall (fun e => e <> absent) (tr_Streams ess n)).
    Proof.
      induction n; intros ** Indexed.
      - inversion_clear Indexed as [? ? ? ? ? ? Indexed' Hess Hck
                                      |? ? ? ? ? ? Indexed' Hess Hck];
          apply (sem_clock_impl 0) in Hck; rewrite tr_Stream_0 in Hck;
            assert (ExprIdx.sem_lexps_instant (tr_Stream b 0)
                                              (ExprIdx.restr_hist (tr_History H) 0)
                                              les (tr_Streams ess 0))
            by (clear Hess; induction Indexed' as [|? ? ? ? Indexed]; simpl;
                constructor; [now apply sem_lexp_impl in Indexed
                             | eapply IHIndexed', CoInd.sem_laexps_cons; eauto]).
        + right. intuition; auto.
          clear - Hess.
          induction ess; inv Hess; constructor; auto.
        + left. intuition; auto.
          clear - Indexed' Hess.
          induction Indexed'; inv Hess; simpl; auto.
          f_equal; auto.
      - destruct b; inversion_clear Indexed;
          rewrite tr_Stream_S, tr_History_tl, <-tr_Streams_tl; auto.
    Qed.

    (** Generalization for lists of annotated [lexp] (on the same clock). *)
    Corollary sem_laexps_impl:
      forall H b ck es ess,
        CoInd.sem_laexps H b ck es ess ->
        ExprIdx.sem_laexps (tr_Stream b) (tr_History H) ck es (tr_Streams ess).
    Proof.
      intros ** Indexed n.
      apply (sem_laexps_index n) in Indexed as [(? & ? & Hes)|(? & ? & Hes)].
      - eright; eauto.
      - assert (exists vs, tr_Streams ess n = List.map present vs) as (vs & ?).
        { clear - Hes.
          induction ess as [|es].
          - exists nil; auto.
          - simpl in *; inversion_clear Hes as [|? ? E].
            destruct (tr_Stream es n) as [|v]; try now contradict E.
            apply IHess in H as (vs & ?).
            exists (v :: vs); simpl.
            f_equal; auto.
        }
        left with (cs := vs); eauto.
    Qed.
    Hint Resolve sem_laexps_impl.

    (** ** cexp level synchronous operators specifications *)

    Lemma merge_index:
      forall n xs ts fs rs,
        CoInd.merge xs ts fs rs ->
        (tr_Stream xs n = absent
         /\ tr_Stream ts n = absent
         /\ tr_Stream fs n = absent
         /\ tr_Stream rs n = absent)
        \/
        (exists t,
            tr_Stream xs n = present true_val
            /\ tr_Stream ts n = present t
            /\ tr_Stream fs n = absent
            /\ tr_Stream rs n = present t)
        \/
        (exists f,
            tr_Stream xs n = present false_val
            /\ tr_Stream ts n = absent
            /\ tr_Stream fs n = present f
            /\ tr_Stream rs n = present f).
    Proof.
      induction n; intros ** Merge.
      - inv Merge; repeat rewrite tr_Stream_0; intuition.
        + right; left. eexists; intuition.
        + right; right. eexists; intuition.
      - inv Merge; repeat rewrite tr_Stream_S; auto.
    Qed.

    Lemma ite_index:
      forall n xs ts fs rs,
        CoInd.ite xs ts fs rs ->
        (tr_Stream xs n = absent
         /\ tr_Stream ts n = absent
         /\ tr_Stream fs n = absent
         /\ tr_Stream rs n = absent)
        \/
        (exists t f,
            tr_Stream xs n = present true_val
            /\ tr_Stream ts n = present t
            /\ tr_Stream fs n = present f
            /\ tr_Stream rs n = present t)
        \/
        (exists t f,
            tr_Stream xs n = present false_val
            /\ tr_Stream ts n = present t
            /\ tr_Stream fs n = present f
            /\ tr_Stream rs n = present f).
    Proof.
      induction n; intros ** Ite.
      - inv Ite; repeat rewrite tr_Stream_0; intuition.
        + right; left. do 2 eexists; now intuition.
        + right; right. do 2 eexists; now intuition.
      - inv Ite; repeat rewrite tr_Stream_S; auto.
    Qed.

    (** [fby] is not a predicate but a function, so we directly state the
        correspondence.  *)
    Lemma fby_impl:
      forall c xs,
      tr_Stream (CoInd.fby c xs) ≈ Indexed.fby c (tr_Stream xs).
    Proof.
      intros ** n; revert c xs.
      induction n; intros.
      - unfold_Stv xs; rewrite unfold_Stream at 1;
          unfold Indexed.fby; simpl; now rewrite tr_Stream_0.
      - unfold_Stv xs; rewrite unfold_Stream at 1;
          unfold Indexed.fby; simpl; repeat rewrite tr_Stream_S;
            rewrite IHn; unfold Indexed.fby;
              destruct (tr_Stream xs n); auto; f_equal;
                clear IHn; induction n; simpl; auto;
                  rewrite tr_Stream_S; destruct (tr_Stream xs n); auto.
    Qed.

    (** ** Semantics of cexps *)

    (** State the correspondence for [cexp].
        Goes by induction on the coinductive semantics of [cexp]. *)
    Hint Constructors ExprIdx.sem_cexp_instant.
    Lemma sem_cexp_impl:
      forall H b e es,
        CoInd.sem_cexp H b e es ->
        ExprIdx.sem_cexp (tr_Stream b) (tr_History H) e (tr_Stream es).
    Proof.
      induction 1 as [? ? ? ? ? ? ? ? ? Hvar Ht ? ? ? Hmerge
                    |? ? ? ? ? ? ? ? ? He Ht ? ? ? Hite
                    |? ? ? ? He]; intro n.
      - specialize (IHsem_cexp1 n).
        specialize (IHsem_cexp2 n).
        apply sem_var_impl in Hvar; eauto.
        unfold ExprIdx.sem_var, ExprIdx.lift in Hvar.
        specialize (Hvar n).
        rename H0_ into Hf.
        apply (merge_index n) in Hmerge
          as [(Hxs & Hts & Hfs & Hos)
             |[(? & Hxs & Hts & Hfs & Hos)
              |(? & Hxs & Hts & Hfs & Hos)]];
          rewrite Hos; rewrite Hts in IHsem_cexp1; rewrite Hfs in IHsem_cexp2;
            rewrite Hxs in Hvar; auto.

      - specialize (IHsem_cexp1 n).
        specialize (IHsem_cexp2 n).
        eapply sem_lexp_impl in He.
        specialize (He n).
        apply (ite_index n) in Hite
          as [(Hes & Hts & Hfs & Hos)
             |[(ct & cf & Hes & Hts & Hfs & Hos)
              |(ct & cf & Hes & Hts & Hfs & Hos)]];
          rewrite Hos; rewrite Hts in IHsem_cexp1; rewrite Hfs in IHsem_cexp2;
            rewrite Hes in He; auto.
        + change (present ct) with (if true then present ct else present cf).
          econstructor; eauto.
          apply val_to_bool_true.
        + change (present cf) with (if false then present ct else present cf).
          econstructor; eauto.
          apply val_to_bool_false.

      - apply sem_lexp_impl in He; auto.
    Qed.
    Hint Resolve sem_cexp_impl.

    (** Give an indexed specification for annotated [cexp], using the previous
        lemma.  *)
    Lemma sem_caexp_index:
      forall n H b ck le es,
        CoInd.sem_caexp H b ck le es ->
        (ExprIdx.sem_clock_instant (tr_Stream b n)
                                   (ExprIdx.restr_hist (tr_History H) n) ck false
         /\ ExprIdx.sem_cexp_instant
             (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) le absent
         /\ tr_Stream es n = absent)
        \/
        (exists e,
            ExprIdx.sem_clock_instant (tr_Stream b n)
                                      (ExprIdx.restr_hist (tr_History H) n) ck true
            /\ ExprIdx.sem_cexp_instant
                (tr_Stream b n) (ExprIdx.restr_hist (tr_History H) n) le (present e)
            /\ tr_Stream es n = present e).
    Proof.
      induction n; intros ** Indexed.
      - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed' Hck
                                      |? ? ? ? ? ? Indexed' Hck];
          apply sem_cexp_impl in Indexed'; specialize (Indexed' 0);
            repeat rewrite tr_Stream_0; repeat rewrite tr_Stream_0 in Indexed';
              apply (sem_clock_impl 0) in Hck; rewrite tr_Stream_0 in Hck.
        + right. eexists; intuition; auto.
        + left; intuition.
      - inversion_clear Indexed as [? ? ? ? ? ? ? Indexed'|? ? ? ? ? ? Indexed'];
          apply sem_cexp_impl in Indexed';
          repeat rewrite tr_Stream_S; rewrite tr_History_tl; eauto.
    Qed.

    (** We deduce from the previous lemma the correspondence for annotated
        [cexp]. *)
    Corollary sem_caexp_impl:
      forall H b e es ck,
        CoInd.sem_caexp H b ck e es ->
        ExprIdx.sem_caexp (tr_Stream b) (tr_History H) ck e (tr_Stream es).
    Proof.
      intros ** Indexed n.
      apply (sem_caexp_index n) in Indexed as [(? & ? & Hes)|(? & ? & ? & Hes)];
        rewrite Hes; constructor; auto.
    Qed.
    Hint Resolve sem_caexp_impl.

    (** * RESET CORRESPONDENCE  *)

    (** We state the correspondence for [reset_of]. *)
    Lemma reset_of_impl:
      forall xs rs,
        CoInd.reset_of xs rs ->
        ExprIdx.reset_of (tr_Stream xs) (tr_Stream rs).
    Proof.
      intros ** n; revert dependent xs; revert rs.
      induction n; intros ** Rst.
      - unfold_Stv xs; unfold_Stv rs; rewrite tr_Stream_0; auto;
          inv Rst; simpl in *; auto.
      - unfold_Stv xs; unfold_Stv rs; rewrite 2 tr_Stream_S;
          inv Rst; simpl in *; auto.
    Qed.

    (** ** Properties about [count] and [mask] *)

    (** When a reset occurs initially, the count at [n] is the count at [n]
        forgetting the first instant, plus one if no reset occurs at [n] when
        shifting. *)
    Lemma count_true_shift:
      forall n r,
        count (tr_Stream (true ::: r)) n
        = if tr_Stream r n
          then count (tr_Stream r) n
          else S (count (tr_Stream r) n).
    Proof.
      induction n; simpl; intros.
      - destruct (tr_Stream r 0); auto.
      - specialize (IHn r).
        rewrite tr_Stream_S.
        destruct (tr_Stream r n) eqn: E';
          destruct (tr_Stream r (S n)); rewrite IHn; auto.
    Qed.

    (** When no reset occurs initially, the count at [n] is the count at [n]
        forgetting the first instant, minus one if a reset occurs at [n] when
        shifting. *)
    Lemma count_false_shift:
      forall n r,
        count (tr_Stream (false ::: r)) n
        = if tr_Stream r n
          then count (tr_Stream r) n - 1
          else count (tr_Stream r) n.
    Proof.
      induction n; simpl; intros.
      - destruct (tr_Stream r 0); auto.
      - specialize (IHn r).
        rewrite tr_Stream_S.
        destruct (tr_Stream r n) eqn: E';
          destruct (tr_Stream r (S n)); rewrite IHn; try omega.
        + apply Minus.minus_Sn_m, count_true_ge_1; auto.
        + rewrite Minus.minus_Sn_m; try omega.
          apply count_true_ge_1; auto.
    Qed.

    (** State the correspondence for [count]. *)
    Lemma count_impl:
      forall r,
        tr_Stream (CoInd.count r) ≈ count (tr_Stream r).
    Proof.
      intros ** n.
      unfold CoInd.count.
      revert r; induction n; intros; simpl.
      - rewrite (unfold_Stream (CoInd.count_acc 0 r)); simpl.
        rewrite tr_Stream_0; auto.
      - rewrite (unfold_Stream (CoInd.count_acc 0 r)); simpl.
        rewrite tr_Stream_S. destruct (hd r) eqn: R.
        + unfold tr_Stream at 1; unfold tr_Stream in IHn; unfold Str_nth in *.
          rewrite CoInd.count_S_nth, IHn.
          destruct r; simpl in *; rewrite R, count_true_shift, tr_Stream_S.
          now destruct (tr_Stream r n).
        + rewrite IHn.
          destruct r; simpl in *; rewrite R, count_false_shift, tr_Stream_S.
          destruct (tr_Stream r n) eqn: R'; auto.
          apply count_true_ge_1 in R'; rewrite Minus.minus_Sn_m; omega.
    Qed.

    (** State the correspondence for [mask]. *)
    Lemma mask_impl:
      forall k r xss,
        tr_Streams (List.map (CoInd.mask_v k r) xss)
        ≈ mask (all_absent xss) k (tr_Stream r) (tr_Streams xss).
    Proof.
      induction xss as [|xs];
        simpl; intros ** n.
      - unfold mask.
        destruct (EqNat.beq_nat k (count (tr_Stream r) n)); auto.
      - unfold CoInd.mask_v; rewrite tr_Stream_nth, CoInd.mask_nth.
        unfold mask in *.
        rewrite IHxss.
        rewrite <-count_impl, NPeano.Nat.eqb_sym.
        unfold tr_Stream; destruct (EqNat.beq_nat k (Str_nth n (CoInd.count r))); auto.
    Qed.


    (** * FINAL LEMMAS *)


    Remark all_absent_tr_Streams:
      forall A n (xss: list (Stream A)),
        all_absent (tr_Streams xss n) = all_absent xss.
    Proof.
      induction xss; simpl; auto; now f_equal.
    Qed.

    (** Correspondence for [clocks_of], used to give a base clock for node
        applications. *)
    Lemma tr_clocks_of:
      forall xss,
        ExprIdx.clock_of (tr_Streams xss) (tr_Stream (CoInd.clocks_of xss)).
    Proof.
      split; intros ** H.
      - revert dependent xss; induction n; intros; induction xss as [|xs];
          rewrite unfold_Stream at 1; simpl in *;
          try rewrite tr_Stream_0; try rewrite tr_Stream_S; auto.
        + inversion_clear H as [|? ? ToMap Forall].
          apply andb_true_intro; split.
          * unfold_St xs; rewrite tr_Stream_0 in ToMap.
            apply Bool.negb_true_iff; rewrite not_equiv_decb_equiv; intro E.
            contradiction.
          * apply IHxss in Forall.
            clear - Forall; induction xss as [|xs]; simpl; auto.
        + inversion_clear H.
          apply IHn. constructor.
          * now rewrite tr_Stream_tl.
          * fold (@tr_Streams value).
            now rewrite tr_Streams_tl.
      - revert dependent xss; induction n; intros; induction xss as [|xs];
          simpl in *; constructor.
        + rewrite unfold_Stream in H at 1; simpl in H;
            rewrite tr_Stream_0 in H; apply andb_prop in H as [].
          unfold_St xs; rewrite tr_Stream_0; simpl in *.
          intro; subst; discriminate.
        + apply IHxss.
          rewrite unfold_Stream in H at 1; simpl in H;
            rewrite tr_Stream_0 in H; apply andb_prop in H as [? Forall].
          clear - Forall; induction xss; rewrite unfold_Stream at 1; simpl;
            now rewrite tr_Stream_0.
        + rewrite unfold_Stream in H at 1; simpl in H; rewrite tr_Stream_S in H.
          apply IHn in H; inv H.
          now rewrite <-tr_Stream_tl.
        + rewrite unfold_Stream in H at 1; simpl in H; rewrite tr_Stream_S in H.
          apply IHn in H; inv H.
          now rewrite <-tr_Streams_tl.
    Qed.
    Hint Resolve tr_clocks_of.

    Lemma sem_clocked_vars_impl:
      forall H b xs,
        CoInd.sem_clocked_vars H b xs ->
        ExprIdx.sem_clocked_vars (tr_Stream b) (tr_History H) xs.
    Proof.
      intros ** Sem n.
      revert dependent H; revert b.
      induction n; intros.
      - induction Sem as [|() ? (Sem & Sem')]; constructor; auto.
        split.
        + simpl. split.
          *{ unfold_Stv b; rewrite tr_Stream_0.
             - inversion 1; subst; simpl in *.
               + edestruct Sem' as (?& Var).
                 * constructor; reflexivity.
                 *{ edestruct Sem as (?& Clock & Synchro); eauto.
                    apply sem_var_impl in Var.
                    specialize (Var 0).
                    inversion_clear Clock as [??? E| | |].
                    inv Synchro.
                    - rewrite tr_Stream_0 in Var; eauto.
                    - inv E; discriminate.
                  }
               + admit.

             - admit.
           }
          * admit.
        + admit.
      - rewrite tr_History_tl, <-tr_Stream_tl.
        apply IHn.
        admit.


    (** The final theorem stating the correspondence for nodes applications.
        We have to use a custom mutually recursive induction scheme [sem_node_mult]. *)
    Hint Constructors Indexed.sem_equation.
    Theorem implies:
      forall f xss oss,
        CoInd.sem_node G f xss oss ->
        Indexed.sem_node G f (tr_Streams xss) (tr_Streams oss).
    Proof.
      induction 1 as [| | | |???? IHNode|???????? Same]
                       using CoInd.sem_node_mult with
          (P_equation := fun H b e =>
                           CoInd.sem_equation G H b e ->
                           Indexed.sem_equation G (tr_Stream b) (tr_History H) e)
          (P_reset := fun f r xss oss =>
                        CoInd.sem_reset G f r xss oss ->
                        Indexed.sem_reset G f (tr_Stream r) (tr_Streams xss) (tr_Streams oss));
        eauto.

      - econstructor; eauto.
        apply reset_of_impl; auto.

      - econstructor; auto; subst; eauto.
        rewrite <-fby_impl; reflexivity.

      - constructor; intro k.
        specialize (IHNode k).
        rewrite 2 all_absent_tr_Streams.
        now rewrite <- 2 mask_impl.

      - pose proof n.(n_ingt0); pose proof n.(n_outgt0).
        Ltac assert_not_nil xss :=
          match goal with
            H: Forall2 _ _ xss |- _ =>
            assert (xss <> []) by
                (intro; subst; apply Forall2_length in H; simpl in *;
                 unfold CoInd.idents in H; rewrite map_length in H; omega)
          end.
        assert_not_nil xss; assert_not_nil oss.
        econstructor; eauto.
        + apply CoInd.same_clock_app_l in Same; auto.
        + apply CoInd.same_clock_app_r in Same; auto.
        + admit.
        + apply Forall_impl_In with (P:=CoInd.sem_equation G H (CoInd.clocks_of xss)); auto.
          intros e ?.
          pattern e; eapply Forall_forall; eauto.
    Qed.

  End Global.

End COINDTOINDEXED.
