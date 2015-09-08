Require Import Coq.FSets.FMapPositive.
Require Import Rustre.Common.
Require Import Rustre.DataflowSyntax.
Require Import SynchronousNat.

Definition history := PM.t stream.
Definition global := PM.t node.

Inductive sem_var (H: history)(x: ident)(n: nat)(v: value): Prop :=
| Sv:
    forall xs,
      PM.find x H = Some xs ->
      xs n = v ->
      sem_var H x n v.

Inductive sem_clock (H: history): clock -> nat -> bool -> Prop :=
| Sbase:
    forall n,
      sem_clock H Cbase n true
| Son_tick:
    forall ck x c n,
      sem_clock H ck n true ->
      sem_var H x n (present (Cbool c)) ->
      sem_clock H (Con ck x c) n true
| Son_abs1:
    forall ck x c n,
      sem_clock H ck n false ->
      sem_clock H (Con ck x c) n false
| Son_abs2:
    forall ck x c c' n,
      sem_clock H ck n true ->
      sem_var H x n (present (Cbool c')) ->
      ~ (c = c') ->
      sem_clock H (Con ck x c) n false.

Inductive sem_laexp (H: history): laexp -> nat -> value -> Prop:=
| SLtick:
    forall ck ce n c,
      sem_lexp H ce n (present c) ->
      sem_clock H ck n true ->
      sem_laexp H (LAexp ck ce) n (present c)
| SLabs:
    forall ck ce n,
      sem_lexp H ce n absent ->
      sem_clock H ck n false ->
      sem_laexp H (LAexp ck ce) n absent
with sem_lexp (H: history): lexp -> nat -> value -> Prop :=
| Sconst:
    forall c n,
      sem_lexp H (Econst c) n (present c)
| Svar:
    forall x v n,
      sem_var H x n v ->
      sem_lexp H (Evar x) n v
| Swhen_eq:
    forall s x b n v,
      sem_var H x n (present (Cbool b)) ->
      sem_laexp H s n v ->
      sem_lexp H (Ewhen s x b) n v
| Swhen_abs:
    forall s x b b' n,
      sem_var H x n (present (Cbool b')) ->
      ~ (b = b') ->
      sem_lexp H (Ewhen s x b) n absent.


Inductive sem_caexp (H: history): caexp -> nat -> value -> Prop :=
| SCtick:
    forall ck ce n c,
      sem_cexp H ce n (present c) ->
      sem_clock H ck n true ->
      sem_caexp H (CAexp ck ce) n (present c)
| SCabs:
    forall ck ce n,
      sem_cexp H ce n absent ->
      sem_clock H ck n false ->
      sem_caexp H (CAexp ck ce) n absent
with sem_cexp (H: history): cexp -> nat -> value -> Prop :=
| Smerge_true:
    forall x t f n v,
      sem_var H x n (present (Cbool true)) ->
      sem_caexp H t n v ->
      sem_cexp H (Emerge x t f) n v
| Smerge_false:
    forall x t f n v,
      sem_var H x n (present (Cbool false)) ->
      sem_caexp H f n v ->
      sem_cexp H (Emerge x t f) n v
| Sexp:
    forall e n v,
      sem_lexp H e n v ->
      sem_cexp H (Eexp e) n v.


Inductive sem_equation (G: global) (H: history) : equation -> Prop :=
| SEqDef:
    forall x cae,
      (forall n,
       exists v, sem_var H x n v
              /\ sem_caexp H cae n v) ->
      sem_equation G H (EqDef x cae)
| SEqApp:
    forall x f arg input output eqs,
      PM.find f G = Some (mk_node f input output eqs) ->
      (exists H' vi vo,
         forall n, sem_laexp H arg n vi
                /\ sem_var H x n vo
		/\ sem_var H' input.(v_name) n vi
		/\ sem_var H' output.(v_name) n vo
                /\ List.Forall (sem_equation G H') eqs) ->
      sem_equation G H (EqApp x f arg)
| SEqFby:
    forall x xs v0 lae,
      (forall n v, xs n = v <-> sem_laexp H lae n v) ->
      (forall n v, sem_var H x n v <-> fbyR v0 xs n v) ->
      sem_equation G H (EqFby x v0 lae).

Definition sem_equations (G: global) (H: history) (eqs: list equation) : Prop :=
  List.Forall (sem_equation G H) eqs.




Lemma sem_equations_tl:
  forall G H eq eqs,
    sem_equations G H (eq :: eqs) -> sem_equations G H eqs.
Proof. inversion 1; auto. Qed.

Lemma sem_equations_cons:
  forall G H eq eqs,
    sem_equations G H (eq :: eqs)
    <-> sem_equation G H eq /\ sem_equations G H eqs.
Proof.
  split; intro Hs.
  apply Forall_cons2 in Hs; auto.
  apply Forall_cons2; auto.
Qed.

Lemma sem_var_det:
  forall H x n v1 v2,
    sem_var H x n v1
    -> sem_var H x n v2
    -> v1 = v2.
Proof.
  intros H x n v1 v2 H1 H2.
  inversion_clear H1 as [xs1 Hf1];
    inversion_clear H2 as [xs2 Hf2];
    rewrite Hf1 in Hf2; injection Hf2;
    intro Heq; rewrite <- Heq in *;
    rewrite <- H0, <- H1; reflexivity.
Qed.

Lemma sem_var_gso:
  forall x y xs n v H,
    x <> y
    -> (sem_var (PM.add x xs H) y n v <-> sem_var H y n v).
Proof.
  split; inversion_clear 1;
  repeat progress match goal with
                  | H:?xs _ = _ |- _ => apply Sv with xs
                  | H:PM.find _ _ = Some _ |- _ => rewrite <- H
                  | |- context [PM.find _ (PM.add _ _ _)] => rewrite PM.gso
                  end; intuition.
Qed.

Lemma sem_clock_det:
  forall H ck n v1 v2,
    sem_clock H ck n v1
    -> sem_clock H ck n v2
    -> v1 = v2.
Proof.
  induction ck; repeat inversion_clear 1; intuition;
  match goal with
  | H1:sem_clock _ _ _ _, H2:sem_clock _ _ _ _ |- _
    => apply (IHck _ _ _ H1) in H2; discriminate
  | H1:sem_var _ _ _ _, H2: sem_var _ _ _ _ |- _
    => apply (sem_var_det _ _ _ _ _ H1) in H2; now injection H2
  end.
Qed.

Lemma sem_lexp_det:
  forall H n e v1 v2,
    sem_lexp H e n v1
    -> sem_lexp H e n v2
    -> v1 = v2.
Proof.
  intros H n.
  induction e using lexp_mult
  with (P:=fun e=> forall v1 v2, sem_laexp H e n v1
                                 -> sem_laexp H e n v2
                                 -> v1 = v2);
    do 2 inversion_clear 1;
    match goal with
    | H1:sem_clock _ _ _ true, H2:sem_clock _ _ _ false |- _ =>
      pose proof (sem_clock_det _ _ _ _ _ H1 H2); discriminate
    | H1:sem_var _ _ _ _, H2:sem_var _ _ _ _ |- _ =>
      solve [ apply sem_var_det with (1:=H1) (2:=H2)
            | pose proof (sem_var_det _ _ _ _ _ H1 H2) as Hcc;
              injection Hcc; contradiction ]
    | _ => auto
    end.
Qed.

Lemma sem_laexp_det:
  forall v1 v2 H n e,
    sem_laexp H e n v1
    -> sem_laexp H e n v2
    -> v1 = v2.
Proof.
  intros v1 v2 H n e.
  do 2 inversion_clear 1;
  match goal with
  | H1:sem_lexp _ _ _ _, H2:sem_lexp _ _ _ _ |- _ =>
    pose proof (sem_lexp_det _ _ _ _ _ H1 H2) as Heq
  end; auto.
Qed.



Inductive sem_held_equation (H: history) (H': history) : equation -> Prop :=
| SHEqDef:
    forall x cae,
      (forall n c, sem_var H x n (present c) -> sem_var H' x n (present c))
      -> sem_held_equation H H' (EqDef x cae)
| SHEqApp:
    forall x f lae,
      (forall n c, sem_var H x n (present c) -> sem_var H' x n (present c))
      -> sem_held_equation H H' (EqApp x f lae)
| SHEqFby:
    forall x v0 lae ys,
      (forall n, sem_laexp H lae n (ys n))
      -> (forall n c, sem_var H' x n (present c) <-> holdR v0 ys n c)
      -> sem_held_equation H H' (EqFby x v0 lae).

Definition sem_held_equations
           (H: history) (H': history) (eqs: list equation) : Prop :=
  List.Forall (sem_held_equation H H') eqs.

Lemma sem_held_equations_tl:
  forall H H' eq eqs,
    sem_held_equations H H' (eq::eqs) -> sem_held_equations H H' eqs.
Proof.
  intros H H' eq eqs Hsem.
  apply Forall_cons2 in Hsem.
  intuition.
Qed.

Lemma sem_held_equations_corres:
  forall G H H' eqs,
    sem_equations G H eqs
    -> sem_held_equations H H' eqs
    -> (forall x n c,
           Is_defined_in x eqs
           -> sem_var H x n (present c)
           -> sem_var H' x n (present c)).
Proof.
  induction eqs as [|eq]; [inversion 3|].
  intros Hs Hsh x n c Hdef Hsv.
  apply Forall_cons2 in Hs; destruct Hs as [Hseq Hseqs];
  apply Forall_cons2 in Hsh; destruct Hsh as [Hsheq Hsheqs];
  apply Is_defined_in_cons in Hdef; destruct Hdef as [Hdef|Hdef];
  [ | destruct Hdef as [Hndef Hdef];
      apply (IHeqs Hseqs Hsheqs _ _ _ Hdef Hsv) ].
  destruct eq as [| |y v0 lae]; inversion Hdef; subst;
  inversion_clear Hsheq as [? ? HH|? ? ? HH|? ? ? ys Hys HH];
  apply HH; try apply Hsv.

  inversion_clear Hseq as [| |? xs ? ? Hxs Hfby].
  assert (forall n, xs n = ys n) as Hxsys by
        (intro n0;
         specialize Hys with n0;
         specialize Hxs with n0 (xs n0);
         apply sem_laexp_det with H n0 lae;
         (apply Hxs; reflexivity) || apply Hys).
  apply Hfby in Hsv.
  rewrite <- (holdR_ext _ _ Hxsys).
  apply fbyR_holdR with (1:=Hsv).
Qed.

Section StreamGenerators.

  Variable H: history.
  Variable arbitrary : stream.

  Definition const_eqb (c1: const) (c2: const) : bool :=
    match (c1, c2) with
    | (Cint z1, Cint z2) => BinInt.Z.eqb z1 z2
    | (Cbool b1, Cbool b2) => Bool.eqb b1 b2
    | _ => false
    end.

  Definition value_eqb (v1: value) (v2: value) : bool :=
    match (v1, v2) with
    | (present c1, present c2) => const_eqb c1 c2
    | (absent, absent) => true
    | _ => false
    end.

  Fixpoint str_clock (ck: clock) (n: nat) : bool :=
    match ck with
    | Cbase => true
    | Con ck' x c => match PM.find x H with
                     | None => false
                     | Some xs => andb (str_clock ck' n)
                                       (value_eqb (xs n) (present (Cbool c)))
                     end
    end.

  Fixpoint str_lexp (e: lexp) (n: nat) : value :=
    match e with
    | Econst c => present c
    | Evar x => match PM.find x H with
                | Some xs => xs n
                | None => absent
                end
    | Ewhen e' x c => match PM.find x H with
                      | Some xs => match xs n with
                                   | present (Cbool b) =>
                                     if Bool.eqb b c
                                     then str_laexp e' n
                                     else absent
                                   | _ => absent
                                   end
                      | None => absent
                      end
    end
  with str_laexp (e: laexp) (n: nat) : value :=
    match e with
    | LAexp ck e => if str_clock ck n then str_lexp e n else absent
    end.

  Lemma str_clock_spec:
    forall ck n c,
      sem_clock H ck n c
      -> str_clock ck n = c.
  Proof.
    induction ck.
    inversion 1; intuition.
    intros n c.
    inversion_clear 1;
      repeat progress (simpl;
         match goal with
         | H:sem_var _ _ _ _ |- _ => inversion_clear H
         | H: PM.find _ _ = _ |- _ => rewrite H
         | H: _ = present (Cbool ?b) |- _ => (rewrite H; destruct b)
         | H: sem_clock _ _ _ _ |- _ => (apply IHck in H; rewrite H)
         | H: b <> _ |- _ => (apply Bool.not_true_is_false in H
                              || apply Bool.not_false_is_true in H;
                              rewrite H)
         | _ => (cbv; reflexivity)
         end).
    destruct (PM.find i H); cbv; reflexivity.
  Qed.

  Lemma str_lexp_spec:
    forall e n v,
      sem_lexp H e n v
      -> str_lexp e n = v.
  Proof.
    induction e using lexp_mult
    with (P:=fun e => forall n v, sem_laexp H e n v -> str_laexp e n = v);
    inversion 1;
    repeat progress (simpl;
           match goal with
           | H:sem_lexp _ _ _ _ |- _ => (apply IHe in H; rewrite H)
           | H:sem_laexp _ _ _ _ |- _ => (apply IHe in H; rewrite H)
           | H:sem_clock _ _ _ _ |- _ => (apply str_clock_spec in H; rewrite H)
           | H:sem_var _ _ _ _ |- _ => (inversion_clear H as [xs Hfind Hxsn];
                                        rewrite Hfind; rewrite Hxsn)
           | |- (if Bool.eqb ?b1 ?b2 then _ else _) = _ =>
             try destruct b1; try destruct b2; simpl; intuition
           | _ => intuition
           end).
  Qed.

  Lemma str_laexp_spec:
    forall e n v,
      sem_laexp H e n v
      -> str_laexp e n = v.
  Proof.
    inversion_clear 1; simpl;
    repeat progress
           match goal with
           | H:sem_clock _ _ _ _ |- _ => (apply str_clock_spec in H; rewrite H)
           | H:sem_lexp _ _ _ _ |- _ => (apply str_lexp_spec in H; rewrite H)
           | _ => intuition
           end.
  Qed.

End StreamGenerators.

Definition hold_history (H: history) : history -> list equation -> history :=
  List.fold_right
    (fun eq H' =>
       match eq with
       | EqFby x v0 e => PM.add x (fun n=>present (hold v0 (str_laexp H e) n)) H'
       | EqApp x _ _ => H'
       | EqDef x _ => H'
       end).

Lemma hold_injection:
  forall xs ys c n,
    (forall n, xs n = ys n)
    -> hold c xs n = hold c ys n.
Proof.
  intros xs ys c n Heq.
  induction n.
  auto.
  case_eq (xs n).
  intro Habs.
  assert (ys n = absent) as Habs' by (rewrite Heq in Habs; intuition).
  unfold hold.
  rewrite Habs. rewrite Habs'.
  fold hold.
  apply IHn.

  intros v Habs.
  assert (ys n = present v) as Habs' by (rewrite Heq in Habs; intuition).
  unfold hold.
  rewrite Habs. rewrite Habs'.
  reflexivity.
Qed.

(* An alternative lemma would be:
   sem_held_equations H H' (filter_dup_defs eqs) -> sem_held_equations H H' eqs
   which should hold since the H in sem_equations/sem_held_equations requires
   that multiple definitions of the same variable be coherent. But proving
   this stronger result is much harder than just assuming something that
   should anyway be true: there are no duplicate definitions in eqs.

   Note, however, that this requires a stronger definition of Is_well_sch. *)
Lemma not_in_add_to_sem_held_equations:
  forall x xs eqs H H',
    ~Is_defined_in x eqs
    -> sem_held_equations H H' eqs
    -> sem_held_equations H (PM.add x xs H') eqs.
Proof.
  induction eqs as [|eq].
  intuition (apply List.Forall_nil).
  intros H H' Hndef Hsem.
  apply not_Is_defined_in_cons in Hndef; destruct Hndef as [Hndef0 Hndef1].
  unfold sem_held_equations in Hsem.
  apply Forall_cons2 in Hsem; destruct Hsem as [Hsem0 Hsem1].
  apply (IHeqs _ _ Hndef1) in Hsem1.
  destruct eq; [ apply not_Is_defined_in_eq_EqDef in Hndef0
               | apply not_Is_defined_in_eq_EqApp in Hndef0
               | apply not_Is_defined_in_eq_EqFby in Hndef0 ];
  apply List.Forall_cons; try apply Hsem1;
  inversion_clear Hsem0 as [? ? Hsv|? ? ? Hsv|? ? ? ys Hlae Hsv];
  try constructor;
  intros;
  try (apply sem_var_gso with (1:=Hndef0); apply Hsv; assumption).
  apply SHEqFby with (1:=Hlae).
  intros; rewrite <- Hsv; split; intro HH.
  apply sem_var_gso with (1:=Hndef0) in HH; assumption.
  apply sem_var_gso with (1:=Hndef0); assumption.
Qed.


(*
   eqs = [ EqDef x y; EqFby y (Cint 0) (Econst (Cint 1)) ]
   eqs' = eqFby x (Cint 0) (Econst (Cint 1)) :: eqs

   Both eqs and eqs' have a coherent semantics (sem_equations G H _),
   but their respective hold semantics differ (for eqs', x is always present).
*)
Lemma sem_held_equations_existence:
  forall G H eqs,
    sem_equations G H eqs
    -> no_dup_defs eqs
    -> sem_held_equations H (hold_history H H eqs) eqs
       /\ (forall y n c,
              sem_var H y n (present c)
              -> sem_var (hold_history H H eqs) y n (present c)).
Proof.
  intros G H eqs Hsem Hndups.
  induction eqs as [|eq].
  - intuition constructor.
  - apply Forall_cons2 in Hsem; destruct Hsem as [Hsem Hsems].
    apply IHeqs in Hsems; [clear IHeqs
                          | inversion_clear Hndups; assumption ].
    destruct Hsems as [Hsems Hvars].
    destruct eq.

    split; [apply Forall_cons2|intuition];
    split; [constructor; apply Hvars|intuition].

    split; [apply Forall_cons2|intuition];
    split; [constructor; apply Hvars|intuition].

    split.

    (* show: sem_var -> sem_var *)
    Focus 2.
    intros y n c0 Hvar.
    pose proof (Hvars _ _ _ Hvar) as Hvar'.
    destruct (ident_eq_dec i y) as [Hiy|Hniy]; [rewrite Hiy|].
    2:(inversion_clear Hvar'; apply Sv with xs; simpl; try rewrite PM.gso; auto).
    simpl.
    eapply Sv.
    rewrite PM.gss.
    rewrite <-Some_injection.
    reflexivity.
    simpl.
    apply present_injection.
    inversion_clear Hsem.
    rewrite Hiy in *.
    apply H1 in Hvar.
    rewrite hold_injection with _ xs _ _.
    apply hold_rel.
    apply fbyR_holdR.
    exact Hvar.
    intro n0.
    specialize H0 with n0 (xs n0).
    assert (sem_laexp H l n0 (xs n0)) as Hsl by (apply H0; reflexivity).
    apply str_laexp_spec in Hsl.
    exact Hsl.

    (* show sem_held_equations *)

    simpl.
    apply Forall_cons2.
    split.
    inversion_clear Hsem.
    apply SHEqFby with xs.
    intro n; apply H0 with (v:=xs n); reflexivity.
    intros n c0.
    split.
    inversion_clear 1.
    rewrite PM.gss in H3.
    injection H3.
    intro.
    rewrite <-H2 in H4.
    injection H4.
    intro.
    apply hold_rel.
    rewrite <-H5.
    apply hold_injection.
    intro n0.
    specialize H0 with n0 (xs n0).
    assert (xs n0 = xs n0) as Hlae by reflexivity.
    apply H0 in Hlae.
    apply str_laexp_spec in Hlae.
    rewrite Hlae.
    reflexivity.
    intro Hhold.
    apply hold_rel in Hhold.
    eapply Sv.
    rewrite PM.gss.
    rewrite <-Some_injection.
    reflexivity.
    simpl.
    apply present_injection.
    rewrite hold_injection with _ xs _ _.
    apply Hhold.
    intro n0.
    specialize H0 with n0 (xs n0).
    assert (sem_laexp H l n0 (xs n0)) as Hsl by (apply H0; reflexivity).
    apply str_laexp_spec in Hsl.
    exact Hsl.

    apply not_in_add_to_sem_held_equations.
    inversion_clear Hndups as [|? ? Hndups'].
    apply Hndups'.
    constructor.
    apply Hsems.
Qed.

Lemma sem_held_equations_exist:
  forall G H eqs,
    sem_equations G H eqs
    -> no_dup_defs eqs
    -> exists H', sem_held_equations H H' eqs.
Proof.
  intros H H' eqs Hsems Hndups.
  apply sem_held_equations_existence in Hsems.
  destruct Hsems as [Hsems].
  now (eexists; apply Hsems).
  assumption.
Qed.

Lemma sem_equations_app2:
  forall G H oeqs eqs,
    sem_equations G H (oeqs ++ eqs)
    -> sem_equations G H eqs.
Proof.
  intros G H oeqs eqs H0.
  apply Forall_app in H0; intuition.
Qed.

Lemma sem_held_equations_app2:
  forall H H' oeqs eqs,
    sem_held_equations H H' (oeqs ++ eqs)
    -> sem_held_equations H H' eqs.
Proof.
  intros H H' oeqs eqs H0.
  apply Forall_app in H0; intuition.
Qed.

Lemma sem_held_equations_cons:
  forall H H' eq eqs,
    sem_held_equations H H' (eq :: eqs)
    <-> sem_held_equation H H' eq /\ sem_held_equations H H' eqs.
Proof.
  split; intro Hs.
  apply Forall_cons2 in Hs; auto.
  apply Forall_cons2; auto.
Qed.

Lemma Is_memory_in_EqFby:
  forall y v0 lae eqs,
    Is_memory_in y (EqFby y v0 lae :: eqs).
Proof.
  intros. repeat constructor.
Qed.



