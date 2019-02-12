Require Import Velus.Common.
Require Import Velus.Operators.
Require Import Velus.Clocks.
Require Import Velus.RMemory.

Require Import Velus.NLustre.NLExprSyntax.
Require Import Velus.NLustre.Stream.
Require Import Velus.NLustre.NLExprSemantics.
Require Import Velus.SyBloc.SBSyntax.
Require Import Velus.SyBloc.SBSemantics.

Require Import Velus.Obc.ObcSyntax.
Require Import Velus.Obc.ObcSemantics.

Require Import Velus.SyBlocToObc.Translation.

Require Import List.
Import List.ListNotations.
Require Import Setoid.

(* Open Scope positive. *)
Open Scope nat.
Open Scope list.

Module Type CORRECTNESS
       (Import Ids     : IDS)
       (Import Op      : OPERATORS)
       (Import OpAux   : OPERATORS_AUX       Op)
       (Import Clks    : CLOCKS          Ids)
       (Import ExprSyn : NLEXPRSYNTAX        Op)
       (Import SynSB   : SBSYNTAX        Ids Op       Clks ExprSyn)
       (Import Str     : STREAM              Op OpAux)
       (Import ExprSem : NLEXPRSEMANTICS Ids Op OpAux Clks ExprSyn              Str)
       (Import SemSB   : SBSEMANTICS     Ids Op OpAux Clks ExprSyn SynSB        Str ExprSem)
       (Import SynObc  : OBCSYNTAX       Ids Op OpAux)
       (Import SemObc  : OBCSEMANTICS    Ids Op OpAux                    SynObc)
       (Import Trans   : TRANSLATION     Ids Op OpAux Clks ExprSyn SynSB SynObc).

  Definition compat_env (R: env) (mems: PS.t) (me: menv) (ve: venv) :=
    forall x c,
      Env.find x R = Some (present c) ->
      if PS.mem x mems
      then find_val x me = Some c
      else Env.find x ve = Some c.

  Section BuildMemWith.

    Context {A B V: Type}.
    Variable f: A -> V.
    Variable g: B -> memory V.

    Definition build_mem_with (xs: list (ident * A)) (ys: list (ident * B)) (m: memory V): memory V :=
      fold_left (fun m x => add_inst (fst x) (g (snd x)) m) ys
                (fold_left (fun m y => add_val (fst y) (f (snd y)) m) xs m).

    Definition build_mem_with_spec (xs: list (ident * A)) (ys: list (ident * B)) (m: memory V): memory V :=
      let (xs, vs) := split xs in
      let (ys, ws) := split ys in
      Mem (Env.adds xs (map f vs) (values m)) (Env.adds ys (map g ws) (instances m)).

    Lemma build_mem_with_spec_values:
      forall xs ys m,
        values (build_mem_with_spec xs ys m) =
        let (xs, vs) := split xs in
        Env.adds xs (map f vs) (values m).
    Proof.
      intros; unfold build_mem_with_spec; destruct (split xs), (split ys); auto.
    Qed.

    Lemma build_mem_with_spec_instances:
      forall xs ys m,
        instances (build_mem_with_spec xs ys m) =
        let (ys, ws) := split ys in
        Env.adds ys (map g ws) (instances m).
    Proof.
      intros; unfold build_mem_with_spec; destruct (split xs), (split ys); auto.
    Qed.

    Lemma build_mem_with_equal:
      forall ys xs m,
        NoDupMembers ys ->
        NoDupMembers xs ->
        build_mem_with xs ys m ≋ build_mem_with_spec xs ys m.
    Proof.
      unfold build_mem_with, build_mem_with_spec.
      induction ys as [|(y, b)]; intros ** NoDup_ys NoDup_xs; simpl.
      - rewrite Env.adds_nil_nil.
        revert m.
        induction xs as [|(x, a)]; intro; simpl.
        + now rewrite Env.adds_nil_nil.
        + inversion_clear NoDup_xs as [|??? Notin].
          rewrite IHxs; auto.
          destruct (split xs) eqn: E; simpl.
          rewrite Env.adds_cons_cons; try reflexivity.
          replace l with (fst (split xs)); [|now rewrite E].
          intro Hin; apply Notin.
          apply in_split_l' in Hin as (?&?).
          eapply In_InMembers; eauto.
      - destruct (split xs) eqn: Exs, (split ys) as (l') eqn: Eys; simpl in *.
        inversion_clear NoDup_ys as [|??? Notin].
        rewrite Env.adds_cons_cons.
        + set (m' := add_inst y (g b) m).
          change (Env.add y (g b) (instances m)) with (instances m');
            change (values m) with (values m').
          apply (IHys _ m') in NoDup_xs; auto.
          rewrite Exs in NoDup_xs.
          rewrite <-NoDup_xs.
          subst m'; clear; revert m.
          induction xs as [|(x', a')]; intros; simpl; try reflexivity.
          rewrite IHxs.
          now rewrite add_inst_val_comm.
        + replace l' with (fst (split ys)); [|now rewrite Eys].
          intro Hin; apply Notin.
          apply in_split_l' in Hin as (?&?).
          eapply In_InMembers; eauto.
    Qed.

  End BuildMemWith.

  Add Parametric Morphism A B V f xs ys m: (fun g => @build_mem_with_spec A B V f g xs ys m)
      with signature (fun g g' => forall x, g x ≋ g' x) ==> equal_memory
        as build_mem_with_spec_rec_equal_memory.
  Proof.
    intros g g' E.
    unfold build_mem_with_spec.
    induction ys as [|(y, b)]; simpl; try reflexivity.
    destruct (split ys); simpl.
    unfold Env.adds. simpl.
    destruct (split xs); simpl.
    constructor; try reflexivity.
    simpl.
    inversion_clear IHys as [??? Insts].
    unfold Env.adds in Insts; simpl in Insts.
    now rewrite E, Insts.
  Qed.

  Fixpoint reset_state_spec (P: SynSB.program) (b: ident) : state :=
    match P with
    | [] => empty_memory _
    | bl :: P =>
      if ident_eqb (b_name bl) b
      then build_mem_with_spec sem_const (reset_state_spec P) (b_lasts bl) (b_blocks bl) (empty_memory _)
      else reset_state_spec P b
    end.

  Fixpoint reset_state (P: SynSB.program) (b: ident) : state :=
    match P with
    | [] => empty_memory _
    | bl :: P =>
      if ident_eqb (b_name bl) b
      then build_mem_with sem_const (reset_state P) (b_lasts bl) (b_blocks bl) (empty_memory _)
      else reset_state P b
    end.

  Lemma reset_state_equal:
    forall P b,
      reset_state P b ≋ reset_state_spec P b.
  Proof.
    induction P as [|bl]; intros; simpl; try reflexivity.
    destruct (ident_eqb (b_name bl) b); auto.
    rewrite (build_mem_with_spec_rec_equal_memory _ _ _ _ _ _ _ _ (reset_state P)).
    - apply build_mem_with_equal.
      + apply b_nodup_blocks.
      + apply b_nodup_lasts.
    - now setoid_rewrite IHP.
  Qed.

  Lemma reset_state_spec_find_Some:
    forall P b P' bl,
      find_block b P = Some (bl, P') ->
      reset_state_spec P b = build_mem_with_spec sem_const
                                                 (reset_state_spec P')
                                                 (b_lasts bl) (b_blocks bl)
                                                 (empty_memory _).
  Proof.
    intros ** Find.
    induction P as [|bl'].
    - inv Find.
    - simpl in *.
      destruct (ident_eqb (b_name bl') b); auto.
      inv Find; auto.
  Qed.

  Lemma reset_state_spec_find_None:
    forall P b,
      find_block b P = None ->
      reset_state_spec P b = empty_memory _.
  Proof.
    intros ** Find.
    induction P as [|bl']; simpl in *; auto.
    destruct (ident_eqb (b_name bl') b); try discriminate; auto.
  Qed.

  Lemma reset_state_find_Some:
    forall P b P' bl,
      find_block b P = Some (bl, P') ->
      reset_state P b = build_mem_with sem_const
                                       (reset_state P')
                                       (b_lasts bl) (b_blocks bl)
                                       (empty_memory _).
  Proof.
    intros ** Find.
    induction P as [|bl'].
    - inv Find.
    - simpl in *.
      destruct (ident_eqb (b_name bl') b); auto.
      inv Find; auto.
  Qed.

  Lemma reset_state_find_None:
    forall P b,
      find_block b P = None ->
      reset_state P b = empty_memory _.
  Proof.
    intros ** Find.
    induction P as [|bl']; simpl in *; auto.
    destruct (ident_eqb (b_name bl') b); try discriminate; auto.
  Qed.

  Lemma find_val_reset_state_spec:
    forall P b bl P',
      find_block b P = Some (bl, P') ->
      (forall x c,
          In (x, c) (b_lasts bl) ->
          find_val x (reset_state_spec P b) = Some (sem_const c))
      /\
      forall x v,
        find_val x (reset_state_spec P b) = Some v ->
        exists c, v = sem_const c /\ In (x, c) (b_lasts bl).
  Proof.
    intros.
    unfold find_val.
    erewrite reset_state_spec_find_Some; eauto.
    rewrite build_mem_with_spec_values.
    pose proof (b_nodup_lasts_blocks bl) as NoDup.
    apply NoDup_app_weaken in NoDup.
    induction (b_lasts bl) as [|(x', c')]; simpl.
    - rewrite Env.adds_nil_nil; setoid_rewrite Env.gempty.
      split; [contradiction | discriminate].
    - destruct (split l); simpl.
      inversion_clear NoDup as [|?? Notin].
      split; [intros ** [Eq|?]|intros ** Find].
      + inv Eq; apply Env.find_gsss.
      + rewrite Env.find_gsso; auto.
        * now apply IHl.
        * intro; subst; apply Notin.
          apply in_map_iff; exists (x', c); auto.
      + destruct (ident_eq_dec x x').
        * subst; rewrite Env.find_gsss in Find; inv Find; eauto.
        * rewrite Env.find_gsso in Find; auto.
          apply IHl in Find as (?&?&?); eauto.
  Qed.

  Lemma reset_state_spec_other:
    forall P P' b bl,
      find_block b P = None ->
      b <> b_name bl ->
      reset_state_spec (P ++ bl :: P') b = reset_state_spec P' b.
  Proof.
    intros.
    destruct (find_block b P') as [[]|] eqn: Find.
    - symmetry; erewrite reset_state_spec_find_Some; eauto.
      erewrite <-find_block_other_app in Find; eauto.
      erewrite reset_state_spec_find_Some; eauto.
    - symmetry; rewrite reset_state_spec_find_None; auto.
      rewrite <-find_block_other_app with (P := P) (bl := bl) in Find; eauto.
      rewrite reset_state_spec_find_None; auto.
  Qed.

  Lemma initial_reset_state_spec:
    forall P b P' bl,
      Ordered_blocks P ->
      find_block b P = Some (bl, P') ->
      initial_state P b (reset_state_spec P b).
  Proof.
    induction P; try now inversion 1.
    intros ** Ord Find.
    econstructor; eauto.
    - split; eapply find_val_reset_state_spec; eauto.
    - intros.
      unfold sub_inst, find_inst.
      erewrite reset_state_spec_find_Some; eauto.
      rewrite build_mem_with_spec_instances.
      pose proof (b_nodup_lasts_blocks bl) as NoDup.
      apply NoDup_comm, NoDup_app_weaken in NoDup.
      destruct (split (b_blocks bl)) as (l, l') eqn: Eq.
      simpl.
      exists (reset_state_spec P' b'); split.
      + apply Environment.Env.In_find_adds.
        * assert (l = map fst (b_blocks bl)) as -> by (now rewrite <-split_fst_map, Eq); auto.
        * rewrite combine_map_snd.
          apply in_map_iff.
          exists (x, b'); split; auto.
          pose proof (split_combine (b_blocks bl)) as Eq'.
          rewrite Eq in Eq';  setoid_rewrite Eq'; auto.
      + simpl in Find.
        destruct (ident_eqb (b_name a) b) eqn: E.
        * inv Find.
          pose proof Ord as Ord'.
          inversion_clear Ord as [|??? Blocks].
          eapply Forall_forall in Blocks as (?&?&?&Find'); eauto.
          apply IHP in Find'; auto.
          rewrite <-initial_state_tail; auto.
        * pose proof Ord as Ord'.
          inversion_clear Ord as [|?? Ord'' Blocks]; clear Blocks.
          apply find_block_app in Find as (P1 & HP &?).
          rewrite HP in *.
          apply Ordered_blocks_split in Ord''.
          eapply Forall_forall in Ord'' as (?&?&?&?& Find'); eauto.
          simpl in *.
          rewrite <-find_block_other_app with (P := P1) (bl := bl) in Find'; auto.
          pose proof Ord'.
          inversion_clear Ord'.
          pose proof Find' as Find.
          apply IHP in Find'; auto.
          rewrite reset_state_spec_other in Find'; auto.
          rewrite <-initial_state_tail; auto.
          pose proof Find as Find_name; apply find_block_name in Find_name.
          rewrite <-Find_name.
          apply find_block_In in Find.
          eapply Forall_forall in Find; eauto.
          apply Find.
  Qed.

  Corollary initial_reset_state:
    forall P b P' bl,
      Ordered_blocks P ->
      find_block b P = Some (bl, P') ->
      initial_state P b (reset_state P b).
  Proof.
    intros.
    rewrite reset_state_equal.
    eapply initial_reset_state_spec; eauto.
  Qed.


  (* SearchAbout Comp.  *)
  Lemma fuu:
    forall P b P' prog bl,
      find_block b P = Some (bl, P') ->
      stmt_eval prog (empty_memory _) vempty (translate_reset_eqns bl) (reset_state P b, vempty).
  Proof.
    induction P; try now inversion 1.
    intros.
    erewrite reset_state_find_Some; eauto.
    unfold translate_reset_eqns, build_mem_with.
    rewrite stmt_eval_fold_left_shift.
    induction (b_blocks bl) as [|(inst, b')]; simpl.
    - induction (b_lasts bl) as [|(x, c)]; simpl; eauto using stmt_eval.

      destruct l; simpl.
      + econstructor.
    -


    reset_state. reset_method; simpl.



  Lemma call_reset:
    forall P b me bl P',
      find_block b P = Some (bl, P') ->
      exists me',
        stmt_call_eval (translate P) me b reset [] me' []
        /\ initial_state P b me'.
  Proof.
    intros ** Find.
    apply find_block_translate in Find as (?&?&?&?).
    eexists; split.
    - econstructor; eauto.
      + subst; apply exists_reset_method.
      + rewrite Env.adds_nil_nil. SearchAbout Env.adds nil. SearchAbout find_method reset.
  Admitted.

  Section BaseTrue.

    Variable (R: env) (mems: PS.t).
    Variable (me: menv) (ve: venv).

    Lemma typeof_correct:
      forall e, typeof (translate_lexp mems e) = ExprSyn.typeof e.
    Proof.
      induction e; simpl; auto.
      destruct (PS.mem i mems); auto.
    Qed.

    Hypothesis Compat_env: compat_env R mems me ve.

    Lemma lexp_correct:
      forall e c,
        sem_lexp_instant true R e (present c) ->
        exp_eval me ve (translate_lexp mems e) c.
    Proof.
      induction e;
        inversion_clear 1 as [|??? Hvar| | | | | | |]; simpl; auto.
      - constructor; congruence.
      - apply Compat_env in Hvar.
        destruct (PS.mem i mems); eauto using exp_eval.
      - econstructor; eauto.
        now rewrite typeof_correct.
      - econstructor; eauto.
        now rewrite 2 typeof_correct.
    Qed.
    Hint Resolve lexp_correct.

    Corollary lexps_correct:
      forall es cs,
        sem_lexps_instant true R es (map present cs) ->
        Forall2 (exp_eval me ve) (map (translate_lexp mems) es) cs.
    Proof.
      setoid_rewrite Forall2_map_1; setoid_rewrite Forall2_map_2;
        intros; eapply Forall2_impl_In; eauto; auto.
    Qed.
    Hint Resolve lexps_correct.

    Lemma cexp_correct:
      forall e c prog x,
        sem_cexp_instant true R e (present c) ->
        stmt_eval prog me ve (translate_cexp mems x e) (me, Env.add x c ve).
    Proof.
      induction e;
        inversion 1 as [???? Hvar|???? Hvar| | | |];
        subst; simpl; eauto.
      - apply Compat_env in Hvar.
        econstructor; eauto.
        + unfold bool_var, tovar.
          destruct (PS.mem i mems); eauto using exp_eval.
        + apply val_to_bool_true.
        + simpl; auto.
      - apply Compat_env in Hvar.
        econstructor; eauto.
        + unfold bool_var, tovar.
          destruct (PS.mem i mems); eauto using exp_eval.
        + apply val_to_bool_false.
        + simpl; auto.
      - econstructor; eauto.
        destruct b; match goal with H: present _ = present _ |- _ => inv H end; auto.
    Qed.
    Hint Resolve cexp_correct.

    Lemma stmt_eval_Control:
      forall ck prog s,
        (sem_clock_instant true R ck false ->
         stmt_eval prog me ve (Control mems ck s) (me, ve))
        /\
        (forall me' ve',
            sem_clock_instant true R ck true ->
            stmt_eval prog me ve s (me', ve') ->
            stmt_eval prog me ve (Control mems ck s) (me', ve')).
    Proof.
      induction ck; split;
        inversion_clear 1 as [ |????? Hvar| |????? Hvar]; simpl; auto.
      - destruct b; edestruct IHck; eauto.
      - apply Compat_env in Hvar.
        unfold bool_var, tovar.
        destruct b0; simpl;
          destruct (PS.mem i mems); eapply IHck; eauto using stmt_eval, exp_eval.
      - apply Compat_env in Hvar.
        unfold bool_var, tovar.
        intros; destruct b;
          destruct (PS.mem i mems); eapply IHck; eauto using stmt_eval, exp_eval.
    Qed.

    Corollary stmt_eval_Control_absent:
      forall ck prog s,
        sem_clock_instant true R ck false ->
        stmt_eval prog me ve (Control mems ck s) (me, ve).
    Proof. apply stmt_eval_Control. Qed.

    Corollary stmt_eval_Control_present:
      forall ck prog s me' ve',
        sem_clock_instant true R ck true ->
        stmt_eval prog me ve s (me', ve') ->
        stmt_eval prog me ve (Control mems ck s) (me', ve').
    Proof. apply stmt_eval_Control. Qed.

    Lemma foo:
      forall P S I S' eq,
        sem_equation P true R S I S' eq ->
        exists me' ve',
          stmt_eval (translate P) me ve (translate_eqn mems eq) (me', ve').
    Proof.
      destruct eq;
        inversion_clear 1 as [????????? Hexp|
                              ???????????? Hexp|
                              ????????????? Init|
                              ???????????????? Hexps]; simpl.
      - inv Hexp;
          eauto using stmt_eval_Control_absent, stmt_eval_Control_present, cexp_correct.
      - inv Hexp;
          eauto 6 using stmt_eval_Control_absent, stmt_eval_Control_present, stmt_eval.
      - destruct r; eauto using stmt_eval_Control_absent.
        inversion_clear Init as [???? Find Rst].
        apply find_block_translate in Find as (?&?&?&?).
        admit.
        (* do 2 eexists. *)
        (* apply stmt_eval_Control_present; auto. *)
        (* econstructor; eauto. *)

        (* econstructor; eauto. *)
        (* + subst; apply exists_reset_method. *)
      - inv Hexps; eauto using stmt_eval_Control_absent.
        admit.
        (* do 2 eexists. *)
        (* apply stmt_eval_Control_present; auto. *)
        (* econstructor; eauto. *)
    Qed.

  End BaseTrue.

End CORRECTNESS.