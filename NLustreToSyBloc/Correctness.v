Require Import Coq.FSets.FMapPositive.
Require Import PArith.
Require Import Logic.FunctionalExtensionality.

Require Import Velus.Common.
Require Import Velus.Operators.
Require Import Velus.Clocks.
Require Import Velus.NLustre.NLSyntax.
Require Import Velus.NLustre.Memories.
Require Import Velus.SyBloc.SBSyntax.
Require Import Velus.NLustre.Ordered.
Require Import Velus.NLustre.Stream.
Require Import Velus.NLustre.NLSemantics.
Require Import Velus.SyBloc.SBSemantics.
Require Import Velus.NLustreToSyBloc.Translation.
Require Import Velus.RMemory.
Require Import Velus.SyBloc.SBInterpretor.

Require Import List.
Import List.ListNotations.
Require Import Coq.Sorting.Permutation.
Require Import Morphisms.

Open Scope list.
Open Scope nat.

Module Type CORRECTNESS
       (Import Ids   : IDS)
       (Import Op    : OPERATORS)
       (Import OpAux : OPERATORS_AUX Op)
       (Import Clks  : CLOCKS      Ids)
       (Import SynNL : NLSYNTAX    Ids Op       Clks)
       (SynSB        : SBSYNTAX    Ids Op       Clks)
       (Import Str   : STREAM          Op OpAux)
       (Import Ord   : ORDERED     Ids Op       Clks SynNL)
       (Import SemNL : NLSEMANTICS Ids Op OpAux Clks SynNL       Str Ord)
       (SemSB        : SBSEMANTICS Ids Op OpAux Clks       SynSB Str)
       (Import Mem   : MEMORIES    Ids Op       Clks SynNL)
       (Import Trans : TRANSLATION Ids Op       Clks SynNL SynSB Mem)

       (Import Interp: SBINTERPRETOR Ids Op OpAux Clks SynSB Str SemSB).

  (* Fixpoint memvar_lexp (x: ident) (e: SynSB.lexp) := *)
  (*   match e with *)
  (*   | SynSB.Ereg y _ => x = y *)
  (*   | SynSB.Ewhen e _ _ => memvar_lexp x e *)
  (*   | SynSB.Eunop _ e _ => memvar_lexp x e *)
  (*   | SynSB.Ebinop _ e1 e2 _ => memvar_lexp x e1 \/ memvar_lexp x e2 *)
  (*   | _ => False *)
  (*   end. *)

  (* Fixpoint memvar_cexp (x: ident) (ce: SynSB.cexp) := *)
  (*   match ce with *)
  (*   | SynSB.Emerge _ e1 e2 => memvar_cexp x e1 \/ memvar_cexp x e2 *)
  (*   | SynSB.Eite e t f => memvar_lexp x e \/ memvar_cexp x t \/ memvar_cexp x f *)
  (*   | SynSB.Eexp e => memvar_lexp x e *)
  (*   end. *)

  (* Definition memory_spec (m: SemSB.memory) (memids: PS.t) (R: env) := *)
  (*   forall x v, *)
  (*     PM.find x R = Some v -> *)
  (*     PS.mem x memids = true -> *)
  (*     SemSB.get_reg x m = Some v. *)

  (* Definition memories_spec (M: SemSB.memories) (memids: PS.t) (H: history) := *)
  (*   forall n, memory_spec (SemSB.restr_mem M n) memids (SemSB.restr_hist H n). *)

  Section Global.

    Variable G: SynNL.global.
    Let P := translate G.

    Section SemInstant.

      Variable base: bool.
      Variable R: env.

      Lemma var_instant_correctness:
        forall x v,
          sem_var_instant R x v ->
          SemSB.sem_var_instant R x v.
      Proof.
        induction 1; constructor; auto.
      Qed.
      Hint Resolve var_instant_correctness.

      Lemma clock_instant_correctness:
        forall ck b,
          sem_clock_instant base R ck b ->
          SemSB.sem_clock_instant base R ck b.
      Proof.
        induction 1; eauto using SemSB.sem_clock_instant.
      Qed.

      Lemma typeof_correctness:
        forall e,
          SynSB.typeof (translate_lexp e) = typeof e.
      Proof.
        induction e; intros; simpl; auto.
      Qed.
      (* Hint Resolve typeof_correctness. *)


      Lemma lexp_instant_correctness:
        forall e v,
          sem_lexp_instant base R e v ->
          SemSB.sem_lexp_instant base R (translate_lexp e) v.
      Proof.
        induction 1; simpl; eauto using SemSB.sem_lexp_instant.
        - econstructor; eauto.
          now rewrite typeof_correctness.
        - econstructor; eauto.
          now rewrite 2 typeof_correctness.
      Qed.
      Hint Resolve lexp_instant_correctness.

      Lemma lexps_instant_correctness:
        forall es vs,
          sem_lexps_instant base R es vs ->
          SemSB.sem_lexps_instant base R (map translate_lexp es) vs.
      Proof.
        induction 1; constructor; auto.
      Qed.

      Lemma cexp_instant_correctness:
        forall ce v,
          sem_cexp_instant base R ce v ->
          SemSB.sem_cexp_instant base R (translate_cexp ce) v.
      Proof.
        induction 1; simpl; eauto using SemSB.sem_cexp_instant.
      Qed.


    End SemInstant.
    Hint Resolve var_instant_correctness clock_instant_correctness
         lexp_instant_correctness lexps_instant_correctness
         cexp_instant_correctness.

    Section Sem.

      Variable bk: stream bool.
      Variable H: history.

      Lemma var_correctness:
        forall x xs,
          sem_var bk H x xs ->
          SemSB.sem_var H x xs.
      Proof.
        intros ** Sem n; specialize (Sem n); auto.
      Qed.
      Hint Resolve var_correctness.

      Lemma vars_correctness:
        forall xs xss,
          sem_vars bk H xs xss ->
          SemSB.sem_vars H xs xss.
      Proof.
        intros ** Sem n; specialize (Sem n);
          induction Sem; constructor; auto.
      Qed.

      Lemma laexp_correctness:
        forall ck e xs,
          sem_laexp bk H ck e xs ->
          SemSB.sem_laexp bk H ck (translate_lexp e) xs.
      Proof.
        intros ** Sem n; specialize (Sem n); simpl in Sem.
        induction Sem; constructor; auto.
      Qed.

      Lemma caexp_correctness:
        forall ck ce xs,
          sem_caexp bk H ck ce xs ->
          SemSB.sem_caexp bk H ck (translate_cexp ce) xs.
      Proof.
        intros ** Sem n; specialize (Sem n); simpl in Sem.
        induction Sem; constructor; auto.
      Qed.

      Lemma laexps_correctness:
        forall ck es vs,
          sem_laexps bk H ck es vs ->
          SemSB.sem_laexps bk H ck (map translate_lexp es) vs.
      Proof.
        intros ** Sem n; specialize (Sem n); inv Sem.
        - econstructor 1; eauto.
        - constructor; auto.
          now rewrite all_absent_map.
      Qed.

      Inductive inst_in_eq: ident -> SynSB.equation -> Prop :=
      | InstInEqReset:
          forall x ck m r,
            inst_in_eq x (SynSB.EqReset ck m x r)
      | InstInEqCall:
          forall x xs ck m es,
            inst_in_eq x (SynSB.EqCall xs ck m x es).

      Definition inst_in_eqs (x: ident) (eqs: list SynSB.equation) : Prop :=
        List.Exists (inst_in_eq x) eqs.

      Lemma not_inst_in_eqs_cons:
        forall x eq eqs,
          ~ inst_in_eqs x (eq :: eqs)
          <-> ~ inst_in_eq x eq /\ ~ inst_in_eqs x eqs.
      Proof.
        split.
        - intro Hndef; split; intro;
            eapply Hndef; constructor (assumption).
        - intros [? ?] Hdef_all.
          inv Hdef_all; eauto.
      Qed.

      Lemma mfby_add_inst:
        forall i v0 ls M xs x M',
          SemSB.mfby i v0 ls M xs ->
          SemSB.mfby i v0 ls (add_inst x M' M) xs.
      Proof.
        inversion_clear 1.
        econstructor; eauto.
      Qed.
      Hint Resolve mfby_add_inst.

      Lemma mfby_add_val:
        forall i v0 ls M xs x mv,
          i <> x ->
          SemSB.mfby i v0 ls M xs ->
          SemSB.mfby i v0 ls (add_val x mv M) xs.
      Proof.
        inversion_clear 2.
        econstructor; eauto.
        rewrite find_val_gso; auto.
      Qed.

      Inductive defined_in_eq: ident -> SynSB.equation -> Prop :=
      | DefEqDef:
          forall x ck e,
            defined_in_eq x (SynSB.EqDef x ck e)
      | DefEqFby:
          forall x ck v e,
            defined_in_eq x (SynSB.EqFby x ck v e)
      | DefEqCall:
          forall x xs ck b o es,
            In x xs ->
            defined_in_eq x (SynSB.EqCall xs ck b o es).

      Definition defined_in_eqs (x: ident) (eqs: list SynSB.equation) : Prop :=
        List.Exists (defined_in_eq x) eqs.

      Lemma not_defined_in_eqs_cons:
        forall x eq eqs,
          ~ defined_in_eqs x (eq :: eqs)
          <-> ~ defined_in_eq x eq /\ ~ defined_in_eqs x eqs.
      Proof.
        split.
        - intro Hndef; split; intro;
            eapply Hndef; constructor(assumption).
        - intros [? ?] Hdef_all; inv Hdef_all; eauto.
      Qed.

      Lemma sem_equation_add_inst:
        forall M M' x eqs,
          ~ inst_in_eqs x eqs ->
          Forall (SemSB.sem_equation P bk H M) eqs ->
          Forall (SemSB.sem_equation P bk H (add_inst x M' M)) eqs.
      Proof.
        intros * Hnd Hsem.
        induction eqs as [|eq eqs IH]; [now constructor|].
        apply not_inst_in_eqs_cons in Hnd as [Hnd].
        apply Forall_cons2 in Hsem as [Hsem Hsems].
        constructor; auto.
        induction eq; inv Hsem; eauto using SemSB.sem_equation.
        - econstructor; eauto.
          unfold sub_inst.
          unfold sub_inst; rewrite find_inst_gso; auto.
          intro; apply Hnd; subst; constructor.
        - econstructor; eauto.
          unfold sub_inst; rewrite find_inst_gso; auto.
          intro; apply Hnd; subst; constructor.
      Qed.

      Lemma sem_equation_add_val:
        forall M mv x eqs,
          ~ defined_in_eqs x eqs ->
          Forall (SemSB.sem_equation P bk H M) eqs ->
          Forall (SemSB.sem_equation P bk H (add_val x mv M)) eqs.
      Proof.
        intros * Hnd Hsem.
        induction eqs as [|eq eqs IH]; [now constructor|].
        apply not_defined_in_eqs_cons in Hnd as [Hnd].
        apply Forall_cons2 in Hsem as [Hsem Hsems].
        constructor; auto.
        induction eq; inv Hsem; eauto using SemSB.sem_equation.
        econstructor; eauto.
        apply mfby_add_val; auto.
        intro; subst; apply Hnd; constructor.
      Qed.

    End Sem.
    Hint Resolve var_correctness vars_correctness
         laexp_correctness caexp_correctness laexps_correctness.

    Fixpoint well_formed_eqs (eqs: list SynSB.equation) : Prop :=
        match eqs with
        | [] => True
        | SynSB.EqReset _ _ x _ :: eqs =>
          ~ inst_in_eqs x eqs /\ well_formed_eqs eqs
        | SynSB.EqCall xs _ _ x _ :: eqs =>
          ~ inst_in_eqs x eqs /\ Forall (fun x => ~ defined_in_eqs x eqs) xs /\ well_formed_eqs eqs
        | SynSB.EqDef x _ _ :: eqs =>
          ~ defined_in_eqs x eqs /\well_formed_eqs eqs
        | SynSB.EqFby x _ _ _ :: eqs =>
          ~ defined_in_eqs x eqs /\well_formed_eqs eqs
        end.

    Lemma Exists_app_l:
      forall (A : Type) (P : A -> Prop) (ll rr : list A),
        Exists P ll ->
        Exists P (ll ++ rr).
    Proof.
      induction 1.
      - now constructor.
      - now constructor 2.
    Qed.

    Lemma not_defined_in_eqs_app:
      forall eqs eqs' x,
        ~ defined_in_eqs x (eqs ++ eqs') ->
        ~ defined_in_eqs x eqs /\ ~ defined_in_eqs x eqs'.
    Proof.
      unfold defined_in_eqs.
      intros * Nd.
      split; intro; apply Nd.
      - now apply Exists_app_l.
      - now apply Exists_app.
    Qed.

    Lemma not_inst_in_eqs_app:
      forall eqs eqs' x,
        ~ inst_in_eqs x (eqs ++ eqs') ->
        ~ inst_in_eqs x eqs /\ ~ inst_in_eqs x eqs'.
    Proof.
      unfold inst_in_eqs.
      intros * Nd.
      split; intro; apply Nd.
      - now apply Exists_app_l.
      - now apply Exists_app.
    Qed.

    Lemma well_formed_eqs_app:
      forall eqs eqs',
        well_formed_eqs (eqs ++ eqs') ->
        well_formed_eqs eqs /\ well_formed_eqs eqs'.
    Proof.
      induction eqs as [|e]; simpl; auto.
      destruct e; intros ** [? H]; edestruct IHeqs; eauto;
        repeat match goal with
               | H: ~ defined_in_eqs _ (_ ++ _) |- _ => apply not_defined_in_eqs_app in H as (?&?)
               | H: ~ inst_in_eqs _ (_ ++ _) |- _ => apply not_inst_in_eqs_app in H as (?&?)
               end; auto.
      - destruct H; eauto.
      - destruct H; auto.
        repeat split; auto.
        eapply Forall_impl with (1:=not_defined_in_eqs_app eqs eqs') in H.
        now rewrite <-Forall_Forall' in H.
    Qed.


    (* Lemma memories_spec_add_inst: *)
    (*   forall M memids H x M', *)
    (*     memories_spec M memids H -> *)
    (*     memories_spec (add_inst x M' M) memids H. *)
    (* Proof. *)
    (*   intros ** Spec n x' v Find Mem. *)
    (*   specialize (Spec n x' v Find Mem). *)
    (*   unfold SemSB.get_reg in *. *)
    (*   now rewrite restr_mem_add_inst, mfind_mem_add_inst. *)
    (* Qed. *)
    (* Hint Resolve memories_spec_add_inst. *)

  End Global.
  Hint Resolve var_correctness vars_correctness
       laexp_correctness caexp_correctness laexps_correctness.

  Inductive compat_eq: equation -> list SynSB.equation -> Prop :=
  | CompatEqDef:
      forall x ck e eqs,
        (* ~ defined_in_eqs x eqs -> *)
        compat_eq (EqDef x ck e) eqs
  | CompatEqFby:
      forall x ck c0 e eqs,
        ~ defined_in_eqs x eqs ->
        compat_eq (EqFby x ck c0 e) eqs
  | CompatEqApp:
      forall xs ck f es r eqs,
        ~ inst_in_eqs (hd default xs) eqs ->
        compat_eq (EqApp xs ck f es r) eqs.

  Inductive compat_eqs: list equation -> Prop :=
  | CompatNil:
      compat_eqs []
  | CompatCons:
      forall eq eqs,
        compat_eqs eqs ->
        compat_eq eq (translate_eqns eqs) ->
        compat_eqs (eq :: eqs).

  Lemma equation_correctness:
    forall G bk H eqs M eq,
      (forall f xss oss,
          sem_node G f xss oss ->
          exists M, SemSB.sem_block (translate G) f M xss oss) ->
      (forall f r xss oss,
          sem_reset G f r xss oss ->
          exists M, SemSB.sem_block (translate G) f M xss oss
               /\ SemSB.reset_regs r M) ->
      sem_equation G bk H eq ->
      (* well_formed_eqs (translate_eqn eq ++ eqs) -> *)
      compat_eq eq eqs ->
      Forall (SemSB.sem_equation (translate G) bk H M) eqs ->
      exists M', Forall (SemSB.sem_equation (translate G) bk H M') (translate_eqn eq ++ eqs).
  Proof.
    intros ** IHnode IHreset Heq WF Heqs.
    inv Heq; simpl; inv WF.
    - repeat (econstructor; eauto).
    - edestruct IHnode as (M' & Block); eauto.
      exists (add_inst (hd default x) M' M).
      constructor.
      + econstructor; eauto.
        apply find_inst_gss.
      + apply sem_equation_add_inst; auto.
    - edestruct IHreset as (M' & Block & Reset); eauto.
      exists (add_inst (hd default x) M' M).
      constructor.
      + econstructor; eauto.
        apply find_inst_gss.
      + constructor.
        * econstructor; eauto.
          apply find_inst_gss.
        * apply sem_equation_add_inst; auto.
    - exists (add_val x {| SemSB.content := hold (sem_const c0) ls; SemSB.reset := fun _ => false |} M).
      constructor.
      + econstructor; eauto.
        econstructor.
        * apply find_val_gss.
        * reflexivity.
        * intro; unfold fby; simpl.
          destruct (ls n); auto.
      + apply sem_equation_add_val; auto.
  Qed.

  Corollary equations_correctness:
    forall G bk H eqs,
      (forall f xss oss,
          sem_node G f xss oss ->
          exists M, SemSB.sem_block (translate G) f M xss oss) ->
      (forall f r xss oss,
          sem_reset G f r xss oss ->
          exists M, SemSB.sem_block (translate G) f M xss oss
               /\ SemSB.reset_regs r M) ->
      (* well_formed_eqs (translate_eqns eqs) -> *)
      compat_eqs eqs ->
      Forall (sem_equation G bk H) eqs ->
      exists M', Forall (SemSB.sem_equation (translate G) bk H M') (translate_eqns eqs).
  Proof.
    intros ** IHnode IHreset WF Heqs.
    induction eqs as [|eq eqs IHeqs]; [exists (@empty_memory SemSB.mvalues); now constructor|].
    apply Forall_cons2 in Heqs as [Heq Heqs].
    inv WF.
    eapply IHeqs in Heqs as [M Heqs]; eauto.
    unfold translate_eqns; rewrite concatMap_cons.
    eapply equation_correctness; eauto.
  Qed.

  Lemma sem_block_cons:
    forall n G f xs M ys,
      SemSB.sem_block (translate G) f xs M ys ->
      Forall (fun n' => n_name n <> n_name n') G ->
      SemSB.sem_block (translate (n :: G)) f xs M ys.
  Proof.
    intros ** Hsem Hnin.
    induction Hsem
      as [| | | |????????? Hfind]
                        using SemSB.sem_block_mult
      with (P_equation := fun bk H M eq =>
                            SemSB.sem_equation (translate (n :: G)) bk H M eq);
      eauto using SemSB.sem_equation.
    econstructor; eauto.
    simpl.
    assert (n.(n_name) <> b) as Hnf.
    { intro Hnf.
      rewrite Hnf in *.
      pose proof (SynSB.find_block_name _ _ _ _ Hfind) as Hb.
      apply find_block_translate in Hfind as (n' & Hfind' & ?).
      apply find_node_split in Hfind' as [G' [aG Hge]].
      rewrite Hge in Hnin.
      apply Forall_app in Hnin.
      destruct Hnin as [H' Hfg]; clear H'.
      inversion_clear Hfg.
      match goal with H:b<>_ |- False => apply H end.
      rewrite <-Hb; subst bl; auto.
    }
    apply ident_eqb_neq in Hnf; rewrite Hnf.
    eauto.
  Qed.

  Lemma sem_equation_cons:
    forall G bk H M eqs n,
      Ordered_nodes (n :: G) ->
      Forall (SemSB.sem_equation (translate G) bk H M) (translate_eqns eqs) ->
      ~Is_node_in n.(n_name) eqs ->
      Forall (SemSB.sem_equation (translate (n :: G)) bk H M) (translate_eqns eqs).
  Proof.
    intros ** Hord Hsem Hnini.
    induction eqs as [|eq eqs IH]; [now constructor|].
    unfold translate_eqns in *; rewrite concatMap_cons in Hsem.
    apply Forall_app in Hsem as [Heq Heqs].
    apply not_Is_node_in_cons in Hnini.
    destruct Hnini as [Hnini Hninis].
    apply IH with (2:=Hninis) in Heqs.
    rewrite concatMap_cons.
    apply Forall_app; split; auto.
    inv Hord.
    induction eq; simpl in *.
    - constructor; auto.
      inversion_clear Heq as [|?? Hsem].
      inv Hsem; eauto using SemSB.sem_equation.
    - destruct o as [(r, ckr)|]; inversion_clear Heq as [|?? Hsem Heq'];
        constructor; inv Hsem; econstructor; eauto.
      + inversion_clear Heq' as [|?? Hsem'].
        inv Hsem'; econstructor; eauto.
        apply sem_block_cons; auto.
      + apply sem_block_cons; auto.
    - constructor; auto.
      inversion_clear Heq as [|?? Hsem].
      inv Hsem; eauto using SemSB.sem_equation.
  Qed.

  Fixpoint path_inst (p: list ident) (M: SemSB.memories) : option SemSB.memories :=
    match p with
    | [] => Some M
    | x :: p =>
      match find_inst x M with
      | Some M => path_inst p M
      | None => None
      end
    end.

  Section Choices.

    Variable Fm: nat -> SemSB.memories.
    Variable Fh: nat -> history.
    Variable Fmvs: nat -> SemSB.mvalues.
    Variable r: stream bool.

    Definition reset_content (x: ident) (p: list ident) : stream val :=
      fun n => match path_inst p (Fm (count r n)) with
            | Some M =>
              match find_val x M with
              | Some mv => mv.(SemSB.content) n
              | None => false_val
              end
            | None => false_val
            end.

    Definition reset_reset (x: ident) (p: list ident) : stream bool :=
      fun n => match path_inst p (Fm (count r n)) with
            | Some M =>
              match find_val x M with
              | Some mv => r n || mv.(SemSB.reset) n
              | None => r n
              end
            | None => r n
            end.

    Lemma reset_reset_spec:
      forall n x p,
        r n = true ->
        reset_reset x p n = true.
    Proof.
      unfold reset_reset; intros ** ->.
      destruct (path_inst p (Fm (count r n))); auto.
      destruct (find_val x m); auto.
    Qed.

    Lemma reset_reset_spec':
      forall n x p M mv,
        path_inst p (Fm (count r n)) = Some M ->
        find_val x M = Some mv ->
        mv.(SemSB.reset) n = true ->
        reset_reset x p n = true.
    Proof.
      unfold reset_reset; intros ** ->; intros ->; intros ->.
      apply Bool.orb_true_r.
    Qed.

    Definition reset_memories_path (p: list ident) (M0: SemSB.memories) : SemSB.memories :=
      mmapi (fun p x mv =>
               {| SemSB.content := reset_content x p;
                  SemSB.reset := reset_reset x p |})
            p M0.

    Definition reset_memories := reset_memories_path [].

    Lemma sub_inst_reset_memories:
      forall x M M' p,
        sub_inst x M M' ->
        sub_inst x (reset_memories_path p M) (reset_memories_path (p ++ [x]) M').
    Proof.
      intros ** Find; unfold sub_inst, reset_memories, reset_memories_path.
      rewrite find_inst_mmapi, Find; auto.
    Qed.

    Lemma reset_memories_path_spec:
      forall k p r',
        (forall n,
            r' n = true ->
            r n = true) ->
        SemSB.reset_regs r' (reset_memories_path p (Fm k)).
    Proof.
      intros ** Spec; unfold reset_memories_path.
      revert p.
      induction (Fm k) as [?? IH] using memory_ind'.
      constructor.
      - intros x mvs.
        unfold find_val.
        simpl; rewrite Env.find_mapi.
        intro Find.
        destruct (Env.find x xvs); inv Find; auto.
        intros; simpl; apply reset_reset_spec; auto.
      - induction xms as [|[y]].
        + intros; discriminate.
        + simpl in IH; inv IH.
          intros x M'.
          unfold sub_inst, find_inst.
          simpl.
          destruct (Env.POTB.compare x y); simpl;
            intro Find; inv Find; eauto.
    Qed.

    Corollary reset_memories_path_sub_spec:
      forall k p r' x M,
        sub_inst x (Fm k) M ->
        (forall n, r' n = true -> r n = true) ->
        SemSB.reset_regs r' (reset_memories_path (p ++ [x]) M).
    Proof.
      intros ** Sub Spec; eapply reset_memories_path_spec with (k := k) in Spec.
      inversion_clear Spec as [??? Inst]; eapply Inst, sub_inst_reset_memories; eauto.
    Qed.

    Corollary reset_memories_spec:
      forall k r',
        (forall n, r' n = true -> r n = true) ->
        SemSB.reset_regs r (reset_memories (Fm k)).
    Proof.
      intros; now apply reset_memories_path_spec.
    Qed.

    Definition reset_history (H0: history) : history :=
      PM.mapi (fun x _ => fun n => match PM.find x (Fh (count r n)) with
                             | Some xs => xs n
                             | None => absent
                             end) H0.

    Definition reset_mvalues: SemSB.mvalues :=
    {| SemSB.content := fun n => (Fmvs (count r n)).(SemSB.content) n;
       SemSB.reset := fun n => r n || (Fmvs (count r n)).(SemSB.reset) n |}.

    Lemma reset_mvalues_spec:
      forall x e c0 ck xss,
        (forall k,
            exists bk : stream bool,
              find_val x (Fm k) = Some (Fmvs k) /\
              SemSB.content (Fmvs k) 0 = sem_const c0 /\
              (forall n : nat,
                  let v := interp_var_instant (SemSB.restr_hist (Fh k) n) x in
                  let v' := interp_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) ck e in
                  SemSB.sem_var_instant (SemSB.restr_hist (Fh k) n) x v /\
                  SemSB.sem_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) ck e v' /\
                  match v' with
                  | absent =>
                    SemSB.content (Fmvs k) (S n) =
                    (if SemSB.reset (Fmvs k) (S n) then sem_const c0 else SemSB.content (Fmvs k) n) /\
                    v = absent
                  | present v'0 =>
                    SemSB.content (Fmvs k) (S n) = (if SemSB.reset (Fmvs k) (S n) then sem_const c0 else v'0) /\
                    v = present (SemSB.content (Fmvs k) n)
                  end) /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk) ->
        forall n, r n = true ->
             SemSB.content reset_mvalues n = sem_const c0.
    Proof.
      intros ** Spec n E.
      unfold reset_mvalues; simpl.
      induction n; simpl; rewrite E.
      - destruct (Spec 1); intuition.
      - specialize (Spec (S (count r n))); destruct Spec as (bk &?& Init & Heq & Clock).
        assert (forall n',
                   n' <= n ->
                   interp_laexp_instant (bk n') (SemSB.restr_hist (Fh (S (count r n))) n') ck e = absent)
          as Absent.
        { assert (forall n',
                     n' <= n ->
                     bk n' = false) as Hbk.
          { clear - Clock.
            intros ** Lte.
            specialize (Clock n').
            rewrite mask_opaque in Clock; auto.
            - apply Bool.not_true_is_false; intro Ebk.
              apply Clock in Ebk.
              clear - Ebk; induction Ebk; auto.
              admit.
            - apply Lt.le_lt_or_eq in Lte as [Lt|]; subst; auto.
              apply (count_le' r) in Lt; omega.
          }
          intros.
          destruct (Heq n') as (?& Hexp &?).
          destruct (interp_laexp_instant (bk n') (SemSB.restr_hist (Fh (S (count r n))) n') ck e); auto.
          inversion_clear Hexp as [???? HClock|].
          rewrite Hbk in HClock; auto; contradict HClock.
          apply SemSB.not_subrate_clock.
        }
        assert (forall n', n' <= n -> SemSB.content (Fmvs (S (count r n))) n' = sem_const c0) as Spec.
        { intros ** Lte.
          induction n'; auto.
          destruct (Heq n') as (?&? & Hfby).
          rewrite Absent in Hfby; try omega; destruct Hfby as (->).
          destruct (SemSB.reset (Fmvs (S (count r n))) (S n')); auto.
          apply IHn'; omega.
        }
        destruct (Heq n) as (?&?& Hfby);
          rewrite Absent in Hfby; auto; destruct Hfby as (->).
        destruct (SemSB.reset (Fmvs (S (count r n))) (S n)); auto.
    Qed.

    Lemma find_val_reset_memories:
      forall x,
        (forall k, find_val x (Fm k) = Some (Fmvs k)) ->
        find_val x (reset_memories (Fm 0)) = Some reset_mvalues.
    Proof.
      intros ** Spec.
      unfold reset_mvalues, reset_memories, reset_memories_path.
      rewrite find_val_mmapi.
      destruct (find_val x (Fm 0)) eqn: E; simpl.
      - do 3 f_equal.
        + unfold reset_content; simpl.
          extensionality n.
          rewrite Spec; auto.
        + unfold reset_reset.
          extensionality n.
          simpl; rewrite Spec; auto.
      - rewrite Spec in E; discriminate.
    Qed.

    Section InterpReset.

      Variable n: nat.

      Lemma interp_var_instant_reset:
        forall x,
          (forall k, PM.find x (Fh k) <> None) ->
          interp_var_instant (SemSB.restr_hist (Fh (count r n)) n) x =
          interp_var_instant (SemSB.restr_hist (reset_history (Fh 0)) n) x.
      Proof.
        intros ** Spec.
        unfold interp_var_instant, reset_history, SemSB.restr_hist, PM.map.
        repeat rewrite PM.gmapi; rewrite option_map_map.
        destruct (PM.find x (Fh (count r n))) eqn: E.
        - destruct (PM.find x (Fh 0)) eqn: E'; auto.
          exfalso; eapply Spec; eauto.
        - exfalso; eapply Spec; eauto.
      Qed.

      Lemma sem_var_instant_reset:
        forall x v,
          (forall k, PM.find x (Fh k) <> None) ->
          SemSB.sem_var_instant (SemSB.restr_hist (Fh (count r n)) n) x v ->
          SemSB.sem_var_instant (SemSB.restr_hist (reset_history (Fh 0)) n) x v.
      Proof.
        intros ** Spec Sem.
        induction Sem; constructor.
        unfold reset_history, SemSB.restr_hist, PM.map in *.
        repeat rewrite PM.gmapi in *; rewrite option_map_map.
        destruct (PM.find x (Fh (count r n))) eqn: E.
        - destruct (PM.find x (Fh 0)) eqn: E'; auto.
          exfalso; eapply Spec; eauto.
        - exfalso; eapply Spec; eauto.
      Qed.

      Variable bk: stream bool.
      Variable xss: stream (list value).
      Hypothesis Clk: SemSB.clock_of (mask (all_absent (xss 0)) (count r n) r xss) bk.
      Let bk' := SemSB.clock_of' xss.

      Lemma interp_clock_instant_reset:
        forall ck,
          interp_clock_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck =
          interp_clock_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck.
      Proof.
        induction ck; intros; simpl.
        - apply SemSB.clock_of_equiv' in Clk; rewrite Clk.
          unfold SemSB.clock_of'.
          rewrite mask_transparent; auto.
        - rewrite interp_var_instant_reset; [|admit].
          rewrite IHck; auto.
      Qed.

      Lemma sem_clock_instant_reset:
        forall ck b,
          SemSB.sem_clock_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck b ->
          SemSB.sem_clock_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck b.
      Proof.
        induction 1.
        - apply SemSB.clock_of_equiv' in Clk; rewrite Clk.
          subst bk'.
          unfold SemSB.clock_of'.
          rewrite mask_transparent; constructor.
        - econstructor; eauto.
          apply sem_var_instant_reset; eauto.
          admit.
        - constructor; auto.
          apply sem_var_instant_reset; eauto.
          admit.
        - eapply SemSB.Son_abs2; eauto.
          apply sem_var_instant_reset; eauto.
          admit.
      Qed.
      Hint Resolve sem_clock_instant_reset.

      Lemma interp_lexp_instant_reset:
        forall e,
          interp_lexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) e =
          interp_lexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) e.
      Proof.
        induction e; intros; simpl.
        - apply SemSB.clock_of_equiv' in Clk; rewrite Clk.
          unfold SemSB.clock_of'.
          rewrite mask_transparent; auto.
        - apply interp_var_instant_reset.
          admit.
        - rewrite interp_var_instant_reset, IHe; auto.
          admit.
        - rewrite IHe; auto.
        - rewrite IHe1, IHe2; auto.
      Qed.

      Lemma sem_lexp_instant_reset:
        forall e v,
          SemSB.sem_lexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) e v ->
          SemSB.sem_lexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) e v.
      Proof.
        induction 1; eauto using SemSB.sem_lexp_instant.
        - constructor; subst.
          apply SemSB.clock_of_equiv' in Clk; rewrite Clk.
          unfold SemSB.clock_of'.
          rewrite mask_transparent; auto.
        - constructor.
          apply sem_var_instant_reset; auto.
          admit.
        - econstructor; eauto.
          apply sem_var_instant_reset; auto.
          admit.
        - eapply SemSB.Swhen_abs1; eauto.
          apply sem_var_instant_reset; auto.
          admit.
        - constructor; auto.
          apply sem_var_instant_reset; auto.
          admit.
      Qed.
      Hint Resolve sem_lexp_instant_reset.

      Lemma interp_laexp_instant_reset:
        forall ck e,
          interp_laexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck e =
          interp_laexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck e.
      Proof.
        intros.
        unfold interp_laexp_instant, interp_annotated_instant.
        erewrite interp_clock_instant_reset, interp_lexp_instant_reset; eauto.
      Qed.

      Lemma sem_laexp_instant_reset:
        forall ck e v,
          SemSB.sem_laexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck e v ->
          SemSB.sem_laexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck e v.
      Proof.
        induction 1; constructor; auto.
      Qed.

      Lemma interp_cexp_instant_reset:
        forall e,
          interp_cexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) e =
          interp_cexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) e.
      Proof.
        induction e; simpl.
        - rewrite interp_var_instant_reset, IHe1, IHe2; auto.
          admit.
        - rewrite interp_lexp_instant_reset, IHe1, IHe2; auto.
        - apply interp_lexp_instant_reset.
      Qed.

      Lemma sem_cexp_instant_reset:
        forall e v,
          SemSB.sem_cexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) e v ->
          SemSB.sem_cexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) e v.
      Proof.
        induction 1; eauto using SemSB.sem_cexp_instant.
        - econstructor; eauto.
          apply sem_var_instant_reset; auto.
          admit.
        - eapply SemSB.Smerge_false; eauto.
          apply sem_var_instant_reset; auto.
          admit.
        - econstructor; eauto.
          apply sem_var_instant_reset; auto.
          admit.
      Qed.
      Hint Resolve sem_cexp_instant_reset.

      Lemma interp_caexp_instant_reset:
        forall ck e,
          interp_caexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck e =
          interp_caexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck e.
      Proof.
        intros.
        unfold interp_caexp_instant, interp_annotated_instant.
        erewrite interp_clock_instant_reset, interp_cexp_instant_reset; eauto.
      Qed.

      Lemma sem_caexp_instant_reset:
        forall ck e v,
          SemSB.sem_caexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) ck e v ->
          SemSB.sem_caexp_instant (bk' n) (SemSB.restr_hist (reset_history (Fh 0)) n) ck e v.
      Proof.
        induction 1; constructor; auto.
      Qed.

    End InterpReset.

  End Choices.
  Hint Resolve reset_memories_spec sub_inst_reset_memories.

  Lemma Forall2_In_l:
    forall {A B: Type} (l: list A) (l': list B) P x,
      Forall2 P l l' ->
      In x l ->
      exists x', P x x'.
  Proof.
    intros ** F2 Hin.
    induction F2.
    - contradiction.
    - inv Hin; eauto.
  Qed.

  Lemma spec_EqDef:
    forall P bk H M x ck e,
      (forall n,
          let v := interp_caexp_instant (bk n) (SemSB.restr_hist H n) ck e in
          SemSB.sem_var_instant (SemSB.restr_hist H n) x v
          /\ SemSB.sem_caexp_instant (bk n) (SemSB.restr_hist H n) ck e v) <->
      SemSB.sem_equation P bk H M (SynSB.EqDef x ck e).
  Proof.
    split.
    - intros ** Spec.
      apply SemSB.SEqDef with (xs := interp_caexp bk H ck e);
        intro; destruct (Spec n); auto.
    - inversion_clear 1 as [???????  Hvar Hexp| | |];
        intro; specialize (Hvar n); specialize (Hexp n); simpl in *.
      erewrite <-interp_caexp_instant_sound; eauto.
  Qed.

  Lemma spec_EqFby:
    forall P bk H M x ck c0 e,
      (exists mvs,
          find_val x M = Some mvs
          /\ mvs.(SemSB.content) 0 = sem_const c0
          /\ (forall n,
                let v := interp_var_instant (SemSB.restr_hist H n) x in
                let v' := interp_laexp_instant (bk n) (SemSB.restr_hist H n) ck e in
                SemSB.sem_var_instant (SemSB.restr_hist H n) x v
                /\ SemSB.sem_laexp_instant (bk n) (SemSB.restr_hist H n) ck e v'
                /\ match v' with
                  | absent =>
                    mvs.(SemSB.content) (S n) =
                    (if mvs.(SemSB.reset) (S n) then sem_const c0 else mvs.(SemSB.content) n)
                    /\ v = absent
                  | present v' =>
                    mvs.(SemSB.content) (S n) =
                    (if mvs.(SemSB.reset) (S n) then sem_const c0 else v')
                    /\ v = present (mvs.(SemSB.content) n)
                  end)) <->
      SemSB.sem_equation P bk H M (SynSB.EqFby x ck c0 e).
  Proof.
    split.
    - intros ** (? & ? & ? & Spec).
      apply SemSB.SEqFby with (xs := interp_var H x) (ls := interp_laexp bk H ck e).
      + intro; destruct (Spec n); auto.
      + intro; destruct (Spec n) as (?&?&?); auto.
      + econstructor; eauto.
        intro; destruct (Spec n) as (?&?&?); auto.
    - inversion_clear 1 as [|????????? Hvar Hexp Fby| |];
        inversion_clear Fby as [???????? Spec].
      econstructor; intuition; eauto.
      specialize (Hvar n); specialize (Hexp n); simpl in *.
      erewrite <-interp_laexp_instant_sound, <-interp_var_instant_sound; eauto; intuition.
      specialize (Spec n); auto.
  Qed.

  Inductive reset_regs_instant (n: nat): bool -> SemSB.memories -> Prop :=
    reset_regs_instant_intro:
      forall M b,
        (forall x mvs,
            find_val x M = Some mvs ->
            b = true -> mvs.(SemSB.reset) n = true) ->
        (forall x M',
            sub_inst x M M' ->
            reset_regs_instant n b M') ->
        reset_regs_instant n b M.

  Lemma sub_inst_reset_regs_instant:
    forall bs M x M',
      (forall n : nat, reset_regs_instant n (bs n) M) ->
      sub_inst x M M' ->
      forall n : nat, reset_regs_instant n (bs n) M'.
  Proof.
    intros ** Rst Sub n.
    revert dependent M'; revert x.
    specialize (Rst n); induction Rst as [??? Inst IH].
    constructor.
    - intros; apply Inst in Sub.
      inv Sub; eauto.
    - intros; eapply IH; eauto.
  Qed.

  Lemma reset_regs_instant_spec:
    forall bs M,
      SemSB.reset_regs bs M <->
      forall n, reset_regs_instant n (bs n) M.
  Proof.
    split.
    - induction 1 as [?? Val ? IH]; intro; constructor.
      + intros; eapply Val; eauto.
      + intros; eapply IH; eauto.
    - induction M as [?? IH] using memory_ind'; intros Rst; constructor.
      + intros; specialize (Rst n); inv Rst; eauto.
      + intros ** Sub; pose proof Sub as Sub'.
        unfold sub_inst, find_inst in Sub.
        eapply Env.find_in, in_map with (f := snd) in Sub; simpl in Sub.
        eapply In_Forall in IH; eauto.
        apply IH.
        eapply sub_inst_reset_regs_instant; eauto.
  Qed.

  Corollary reset_regs_instant_spec':
    forall bs M n,
      SemSB.reset_regs bs M ->
      reset_regs_instant n (bs n) M.
  Proof.
    intros ** Rst.
    rewrite reset_regs_instant_spec in Rst; auto.
  Qed.

  Lemma reset_memories_path_spec_instant:
    forall k p r' Fm r n,
      (r' n = true -> r n = true) ->
      reset_regs_instant n (r' n) (reset_memories_path Fm r p (Fm k)).
  Proof.
    intros ** Spec; unfold reset_memories_path.
    revert dependent p.
    induction (Fm k) as [?? IH] using memory_ind'; intros.
    constructor.
    - intros x mvs.
      unfold reset_memories_path, find_val.
      simpl; rewrite Env.find_mapi.
      intro Find.
      destruct (Env.find x xvs); inv Find; auto.
      simpl; intro; apply reset_reset_spec; auto.
    - induction xms as [|[y]].
      + intros; discriminate.
      + simpl in IH; inv IH.
        intros x M'.
        unfold sub_inst, find_inst.
        simpl.
        destruct (Env.POTB.compare x y); simpl;
          intro Find; inv Find; eauto.
  Qed.

  Corollary reset_memories_path_sub_spec_instant:
      forall p r' x M Fm r k n,
        sub_inst x (Fm k) M ->
        (r' n = true -> r n = true) ->
        reset_regs_instant n (r' n) (reset_memories_path Fm r (p ++ [x]) M).
  Proof.
    intros ** Sub Spec; eapply reset_memories_path_spec_instant with (k := k) in Spec.
    inversion_clear Spec as [??? Inst]; eapply Inst, sub_inst_reset_memories; eauto.
  Qed.

  Lemma sub_inst_reset_memories':
    forall x M0 Fm r r',
      sub_inst x (Fm 0) M0 ->
      (forall n, r n = true -> r' n = true) ->
      sub_inst x (reset_memories Fm r (Fm 0)) (reset_memories_path Fm r' [x] M0).
  Proof.
    intros ** Sub Spec; unfold sub_inst, reset_memories, reset_memories_path.
    rewrite find_inst_mmapi, Sub.
    simpl. auto.
    admit.
  Qed.

  Lemma spec_EqReset:
    forall P bk H M ck b i r,
      (exists M',
          sub_inst i M M'
          /\ (forall n,
                let v := interp_var_instant (SemSB.restr_hist H n) r in
                SemSB.sem_var_instant (SemSB.restr_hist H n) r v
                /\ reset_regs_instant n (SemSB.reset_of_value v) M')) <->
      SemSB.sem_equation P bk H M (SynSB.EqReset ck b i r).
  Proof.
    split.
    - intros ** (M' & Sub & Spec).
      apply SemSB.SEqReset with (M' := M') (rs := interp_var H r); auto.
      + intro; destruct (Spec n); auto.
      + clear Sub.
        induction M' as [?? IH] using memory_ind'.
        constructor.
        * intros; destruct (Spec n) as (? & RstRegs); inv RstRegs; eauto.
        * (* intros ** Find. *)
          intros ** Find; pose proof Find as Find'; unfold sub_inst, find_inst in Find.
          apply Env.find_in, in_map with (f := snd) in Find; simpl in Find.
          eapply In_Forall in IH; eauto.
          apply IH.
          intro; destruct (Spec n) as (? & IHSpec); split; auto.
          inv IHSpec; eauto.
    - inversion_clear 1 as [| |????????? Hvar Sub Rst|].
      econstructor; split; eauto.
      intro; specialize (Hvar n); simpl in *.
      erewrite <-interp_var_instant_sound; eauto; split; auto.
      assert (forall n, SemSB.reset_of rs n = SemSB.reset_of_value (rs n)); auto.
      clear Sub.
      induction Rst as [?? Rst' Rst''].
      constructor; eauto.
  Qed.

  (* Lemma spec_EqCall: *)
  (*   forall P bk H M ys ck b i es, *)
  (*     (exists M', *)
  (*         sub_inst i M M' *)
  (*         /\ (forall n, *)
  (*               let vs := interp_laexps_instant (SemSB.restr_hist H n) es in *)
  (*               let vs := interp_vars_instant (SemSB.restr_hist H n) es in *)
  (*               SemSB.sem_var_instant (SemSB.restr_hist H n) r v *)
  (*               /\ reset_regs_instant n (SemSB.reset_of_value v) M')) <-> *)
  (*     SemSB.sem_equation P bk H M (SynSB.EqReset ck b i r). *)
  (* Proof. *)
  (*   split. *)
  (*   - intros ** (M' & Sub & Spec). *)
  (*     apply SemSB.SEqReset with (M' := M') (rs := interp_var bk H r); auto. *)
  (*     + intro; destruct (Spec n); auto. *)
  (*     + clear Sub. *)
  (*       induction M' as [?? IH] using memory_ind'. *)
  (*       constructor. *)
  (*       * intros; destruct (Spec n) as (? & RstRegs); inv RstRegs; eauto. *)
  (*       * (* intros ** Find. *) *)
  (*         intros ** Find; pose proof Find as Find'; unfold sub_inst, find_inst in Find. *)
  (*         apply Env.find_in, in_map with (f := snd) in Find; simpl in Find. *)
  (*         eapply In_Forall in IH; eauto. *)
  (*         apply IH. *)
  (*         intro; destruct (Spec n) as (? & IHSpec); split; auto. *)
  (*         inv IHSpec; eauto. *)
  (*   - inversion_clear 1 as [| |????????? Hvar Sub Rst|]. *)
  (*     econstructor; split; eauto. *)
  (*     intro; specialize (Hvar n); simpl in *. *)
  (*     erewrite <-interp_var_instant_sound; eauto; split; auto. *)
  (*     assert (forall n, SemSB.reset_of rs n = SemSB.reset_of_value (rs n)); auto. *)
  (*     clear Sub. *)
  (*     induction Rst as [?? Rst' Rst'']. *)
  (*     constructor; eauto. *)
  (* Qed. *)

          (* sem_laexps bk H ck es ess -> *)
          (* sub_inst i M M' -> *)
          (* sem_block b M' ess oss -> *)
          (* sem_vars H ys oss -> *)
          (* sem_equation bk H M (EqCall ys ck b i es) *)

  Lemma sem_var_instant_bl_vars:
    forall xs xs' xss Fh r n,
      (forall x k n,
          In x xs' ->
          exists v, PM.find x (SemSB.restr_hist (Fh k) n) = Some v) ->
      incl xs xs' ->
      SemSB.sem_vars (Fh (count r n)) xs (mask (all_absent (xss 0)) (count r n) r xss) ->
      Forall2 (SemSB.sem_var_instant (SemSB.restr_hist (reset_history Fh r (Fh 0)) n)) xs (xss n).
  Proof.
    intros ** SameDomFh Incl Sem.
    unfold mask in Sem; specialize (Sem n); simpl in *.
    rewrite <-EqNat.beq_nat_refl in Sem.
    induction Sem as [|x ??? Sem]; constructor; auto.
    - clear IHSem.
      inversion_clear Sem as [?? Find]; constructor.
      assert (exists v, PM.find x (SemSB.restr_hist (Fh 0) n) = Some v)
        as (? & Find') by (apply SameDomFh, Incl; constructor; auto).
      unfold SemSB.restr_hist, reset_history, PM.map in *.
      repeat rewrite PM.gmapi in *; rewrite option_map_map.
      destruct (PM.find x (Fh (count r n))); try discriminate.
      destruct (PM.find x (Fh 0)); try discriminate; auto.
    - apply IHSem; intros x' **.
      apply Incl; right; auto.
  Qed.

  Require Import Coq.Logic.ClassicalChoice.
  Require Import Coq.Logic.ConstructiveEpsilon.
  Require Import Coq.Logic.Epsilon.
  Require Import Coq.Logic.IndefiniteDescription.

  Theorem correctness:
    forall G f xss oss,
      (* Welldef_global G -> *)
      Ordered_nodes G ->
      sem_node G f xss oss ->
      exists M, SemSB.sem_block (translate G) f M xss oss.
  Proof.
    induction G as [|node].
    inversion 2;
      match goal with Hf: find_node _ [] = _ |- _ => inversion Hf end.
    intros ** Hord Hsem.
    assert (Hsem' := Hsem).
    inversion_clear Hsem' as [??????? Hfind ????? Heqs].
    (* pose proof (Welldef_global_Ordered_nodes _ Hwdef) as Hord. *)
    (* pose proof (Welldef_global_cons _ _ Hwdef) as HwdefG. *)
    pose proof (find_node_not_Is_node_in _ _ _ Hord Hfind) as Hnini.
    simpl in Hfind.
    destruct (ident_eqb node.(n_name) f) eqn:Hnf.
    - assert (Hord':=Hord).
      inversion_clear Hord as [|? ? Hord'' Hnneqs Hnn].
      injection Hfind; intro HR; rewrite HR in *; clear HR; simpl in *.
      eapply Forall_sem_equation_global_tl in Heqs; eauto.
      assert (forall f xss oss,
                 sem_node G f xss oss ->
                 exists M, SemSB.sem_block (translate G) f M xss oss)
        as IHG' by auto.
      assert (forall f r xss oss,
                 sem_reset G f r xss oss ->
                 exists M, SemSB.sem_block (translate G) f M xss oss
                      /\ SemSB.reset_regs r M).
      { clear - IHG'.
        intros ** Sem.
        inversion_clear Sem as [???? Sem'].
        assert (exists F, forall k, SemSB.sem_block (translate G) f (F k) (mask (all_absent (xss 0)) k r xss)
                                          (mask (all_absent (oss 0)) k r oss))
          as (Fm & SBsem').
        {
          assert (forall k, exists M', SemSB.sem_block (translate G) f M' (mask (all_absent (xss 0)) k r xss)
                                             (mask (all_absent (oss 0)) k r oss)) as SBsem
              by (intro; specialize (Sem' k); apply IHG' in Sem'; auto).

          (** Infinite Description  *)
          now apply functional_choice in SBsem.

          (** Epsilon  *)
          (* assert (inhabited memories) as I *)
          (*     by (constructor; exact (fun n => @empty_memory val)). *)
          (* exists (fun n => epsilon *)
            (*            I (fun M => msem_node G f (mask (all_absent (xs 0)) n r xs) M *)
          (*                               (mask (all_absent (ys 0)) n r ys))). *)
          (* intro; now apply epsilon_spec.  *)

          (** Constructive Epsilon  *)
          (* pose proof (constructive_ground_epsilon memories) as F. *)

          (** Classical Choice  *)
          (* now apply choice in Msem'.   *)
        }

        assert (exists bl P', SynSB.find_block f (translate G) = Some (bl, P'))
          as (bl & P' & Find)
          by (specialize (SBsem' 0); inv SBsem'; eauto).

        assert (exists F, forall k, exists bk,
                       SemSB.sem_vars (F k) (map fst (SynSB.b_in bl)) (mask (all_absent (xss 0)) k r xss)
                       /\ SemSB.sem_vars (F k) (map fst (SynSB.b_out bl)) (mask (all_absent (oss 0)) k r oss)
                       /\ Forall (SemSB.sem_equation (translate G) bk (F k) (Fm k)) (SynSB.b_eqs bl)
                       /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk)
        as (Fh & Spec).
        { assert (forall k, exists H bk,
                       SemSB.sem_vars H (map fst (SynSB.b_in bl)) (mask (all_absent (xss 0)) k r xss)
                       /\ SemSB.sem_vars H (map fst (SynSB.b_out bl)) (mask (all_absent (oss 0)) k r oss)
                       /\ Forall (SemSB.sem_equation (translate G) bk H (Fm k)) (SynSB.b_eqs bl)
                       /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk)
          as Spec.
          { intro; specialize (SBsem' k); inv SBsem'.
            match goal with
              H: SynSB.find_block _ _ = _ |- _ => rewrite Find in H; inv H end.
            eauto 6.
          }
          now apply functional_choice in Spec.
        }

        assert (forall x k n,
                   In x (map fst (SynSB.bl_vars bl)) ->
                   exists v, PM.find x (SemSB.restr_hist (Fh k) n) = Some v)
          as SameDomFh.
        { clear - Spec.
          intros ** Hin; unfold SynSB.bl_vars in Hin; do 2 rewrite map_app in Hin.
          apply in_app in Hin as [Hin|Hin]; [|apply in_app in Hin as [Hin|Hin]].
          - destruct (Spec k) as (?& In & ?).
            specialize (In n); simpl in *.
            eapply Forall2_In_l in In as (?& Sem); eauto.
            inv Sem; eauto.
          - destruct (Spec k) as (?&?& Out &?).
            specialize (Out n); simpl in *.
            eapply Forall2_In_l in Out as (?& Sem); eauto.
            inv Sem; eauto.
          - admit.
        }

        exists (reset_memories Fm r (Fm 0)).
        assert (SemSB.reset_regs r (reset_memories Fm r (Fm 0))) as RstRegs by eauto.

        split; eauto.
        eapply SemSB.SBlock with (H := reset_history Fh r (Fh 0)); eauto.
        + apply SemSB.clock_of_equiv.
        + intro; destruct (Spec (count r n)) as (?& In & ?).
          eapply sem_var_instant_bl_vars; eauto.
          intros ? Hin.
          unfold SynSB.bl_vars; rewrite map_app, in_app; auto.
        + intro; destruct (Spec (count r n)) as (?&?& Out &?).
          eapply sem_var_instant_bl_vars; eauto.
          intros ? Hin.
          unfold SynSB.bl_vars; rewrite 2 map_app, 2 in_app; auto.
        + intro; specialize (SBsem' (count r n)); inversion_clear SBsem' as [???????????? Same].
          specialize (Same n); rewrite mask_transparent in Same; auto.
        + intro; specialize (SBsem' (count r n)); inversion_clear SBsem' as [????????????? Same].
          specialize (Same n); rewrite mask_transparent in Same; auto.
        + intro; specialize (SBsem' (count r n)); inversion_clear SBsem' as [?????????????? AbsAbs].
          specialize (AbsAbs n); rewrite 2 mask_transparent in AbsAbs; auto.
        + induction (SynSB.b_eqs bl) as [|eq ? IHeqs]; constructor; auto.
          *{ clear IHeqs.
             assert (forall k, exists bk, SemSB.sem_equation (translate G) bk (Fh k) (Fm k) eq
                                /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk)
               as Spec'
                 by (intros; destruct (Spec k) as (?&?&?& Heq &?); inv Heq; eauto).
             clear Spec.
             destruct eq.

             - apply spec_EqDef.
               intro; destruct (Spec' (count r n)) as (bk & Heq & Hbk).
               rewrite <-spec_EqDef in Heq; destruct (Heq n) as (Hvar & Hexp).
               erewrite <-interp_caexp_instant_reset; eauto.
               split.
               + apply sem_var_instant_reset; auto.
                 admit.
               + eapply sem_caexp_instant_reset; eauto.

             - assert (exists F, forall k, exists bk,
                              find_val i (Fm k) = Some (F k)
                              /\ (F k).(SemSB.content) 0 = sem_const c0
                              /\ (forall n,
                                    let v := interp_var_instant (SemSB.restr_hist (Fh k) n) i in
                                    let v' := interp_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) c l0 in
                                    SemSB.sem_var_instant (SemSB.restr_hist (Fh k) n) i v
                                    /\ SemSB.sem_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) c l0 v'
                                    /\ match v' with
                                      | absent =>
                                        (F k).(SemSB.content) (S n) =
                                        (if (F k).(SemSB.reset) (S n) then sem_const c0 else (F k).(SemSB.content) n)
                                        /\ v = absent
                                      | present v' =>
                                        (F k).(SemSB.content) (S n) =
                                        (if (F k).(SemSB.reset) (S n) then sem_const c0 else v')
                                        /\ v = present ((F k).(SemSB.content) n)
                                      end)
                              /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk)
               as (Fmvs & Spec).
               { assert (forall k, exists mvs bk,
                              find_val i (Fm k) = Some mvs
                              /\ mvs.(SemSB.content) 0 = sem_const c0
                              /\ (forall n,
                                    let v := interp_var_instant (SemSB.restr_hist (Fh k) n) i in
                                    let v' := interp_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) c l0 in
                                    SemSB.sem_var_instant (SemSB.restr_hist (Fh k) n) i v
                                    /\ SemSB.sem_laexp_instant (bk n) (SemSB.restr_hist (Fh k) n) c l0 v'
                                    /\ match v' with
                                      | absent =>
                                      mvs.(SemSB.content) (S n) =
                                      (if mvs.(SemSB.reset) (S n) then sem_const c0 else mvs.(SemSB.content) n)
                                      /\ v = absent
                                      | present v' =>
                                        mvs.(SemSB.content) (S n) =
                                        (if mvs.(SemSB.reset) (S n) then sem_const c0 else v')
                                        /\ v = present (mvs.(SemSB.content) n)
                                      end)
                              /\ SemSB.clock_of (mask (all_absent (xss 0)) k r xss) bk) as Spec.
                 { intro; destruct (Spec' k) as (?& Heq &?);
                     rewrite <-spec_EqFby in Heq; destruct Heq as (?&?&?&?).
                   eauto 6.
                 }
                 now apply functional_choice in Spec.
               }

               apply spec_EqFby.
               exists (reset_mvalues Fmvs r).
               split; [|split]; eauto.
               + apply find_val_reset_memories.
                 intro; destruct (Spec k); intuition.
               + simpl; destruct (r 0).
                 * destruct (Spec 1) as (?&?&?&?); auto.
                 * destruct (Spec 0) as (?&?&?&?); auto.
               + clear - Spec.
                 intro; destruct (Spec (count r n)) as (bk & Find & Init & Heq & Clock).
                 pose proof (reset_mvalues_spec _ _ _ _ _ _ _ _ _ Spec (S n)) as Spec'.
                 clear Spec.
                 erewrite <-interp_var_instant_reset, <-interp_laexp_instant_reset; eauto.
                 *{ destruct (Heq n) as (Hvar & Hexp & Hfby).
                    split; [|split].
                    - apply sem_var_instant_reset; auto.
                      admit.
                    - eapply sem_laexp_instant_reset; eauto.
                    - destruct (r (S n)) eqn: E; [rewrite Spec'; auto|];
                        simpl; rewrite E; simpl; auto.
                      destruct (interp_laexp_instant (bk n) (SemSB.restr_hist (Fh (count r n)) n) c l0);
                        intuition.
                  }
                  * admit.

             - apply spec_EqReset.
               assert (exists M0, sub_inst i0 (Fm 0) M0) as (M0 & Find0)
                   by (destruct (Spec' 0) as (?& Heq & ?); inv Heq; eauto).
               (* exists (reset_memories_path Fm (fun n => r n || SemSB.reset_of_value (interp_var_instant (SemSB.restr_hist (Fh (count r n)) n) i1)) [i0] M0). *)
               exists (reset_memories_path Fm r [i0] M0).
               split.
               + unfold sub_inst, reset_memories, reset_memories_path.
                 rewrite find_inst_mmapi, Find0.
                 simpl. auto.
                 (* admit. *)
                 (* apply sub_inst_reset_memories'; auto. *)
                 (* intros ** ->; auto. *)
               + intro; destruct (Spec' (count r n)) as (?& Heq &?);
                   apply spec_EqReset in Heq as (?&? & Spec); destruct (Spec n).
                 erewrite <-interp_var_instant_reset.
                 *{ split.
                    - apply sem_var_instant_reset; auto.
                      admit.
                    - constructor.
                      + unfold reset_memories_path. intros ** Find' Rst.
                        rewrite find_val_mmapi in Find'.
                        destruct (find_val x1 M0) eqn: E; inv Find'.
                        simpl. unfold reset_reset. simpl.
                        rewrite H0.
                        eapply reset_reset_spec'.


                      replace (SemSB.reset_of_value (interp_var_instant (SemSB.restr_hist (Fh (count r n)) n) i1))
                        with (SemSB.reset_of (interp_var (Fh (count r n)) i1) n); auto.
                      eapply (reset_memories_path_sub_spec_instant []); eauto 1.
                      unfold SemSB.reset_of, interp_var, lift'; intros ** ->; simpl.
                      apply Bool.orb_true_r.
                  }
                 * admit.

             - admit.
           }
          * apply IHeqs.
            intro; destruct (Spec k) as (?&?&?& Heqs &?); inv Heqs; eauto.
      }

      assert (exists M', Forall (SemSB.sem_equation (translate G) bk H M') (translate_eqns n.(n_eqs)))
        as (M & Hmsem).
      { eapply equations_correctness; eauto.
        admit.
      }
      exists M.
      econstructor; eauto.
      + simpl; now rewrite Hnf.
      + simpl; rewrite map_fst_idty; eauto.
      + simpl; rewrite map_fst_idty; eauto.
      + eapply sem_equation_cons; eauto.
    - apply ident_eqb_neq in Hnf.
      apply sem_node_cons with (1:=Hord) (3:=Hnf) in Hsem.
      inv Hord.
      eapply IHG in Hsem as [M]; eauto.
      exists M.
      now eapply sem_block_cons; eauto.
  Qed.
