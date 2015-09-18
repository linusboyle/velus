Require Import Morphisms.
Require Import Coq.FSets.FMapPositive.
Require Import List.
Require Import Rustre.Common.
Require Import Rustre.DataflowSyntax.
Require Import Rustre.DataflowListSemantics.


Set Implicit Arguments.


Ltac inv H := inversion H; subst; clear H.


Lemma Some_inj : forall A (x y : A), Some x = Some y -> x = y.
Proof. intros * H. now injection H. Qed.

Lemma nth_nil : forall {A} (d : A) n, nth n nil d = d.
Proof. intros A d [| n]; reflexivity. Qed.

Lemma nth_hd : forall {A} (d : A) l, nth 0 l d = hd d l.
Proof. intros A d l. now destruct l. Qed.

Lemma nth_last : forall {A} (d : A) l, nth (length l - 1) l d = last l d.
Proof.
intros A d l. induction l.
- simpl. reflexivity.
- destruct l; trivial. simpl in *. rewrite <- IHl, <- Minus.minus_n_O. reflexivity.
Qed.

Lemma nth_not_default_lt_length : forall {A} (d : A) n l, nth n l d <> d -> n < length l.
Proof.
intros A d n l Heq. destruct (Compare_dec.le_lt_dec (length l) n).
- elim Heq. now apply nth_overflow.
- assumption.
Qed.

Lemma Forall_compat {A} : Proper ((eq ==> iff) ==> eq ==> iff) (@Forall A).
Proof.
intros P Q HPQ ? l ?. subst. induction l as [| e l].
* intuition.
* split; intro He.
  + inversion_clear He. constructor.
    - now apply (HPQ _ _ (reflexivity e)).
    - now rewrite <- IHl.
  + inversion_clear He. constructor.
    - now apply <- (HPQ _ _ (reflexivity e)).
    - now rewrite IHl.
Qed.

Lemma find_None_not_In : forall (x : ident) (env : venv), PositiveMap.find x env = None <-> ~PositiveMap.In x env.
Proof.
intros x env. split; intro Habs.
+ intros [v Hin]. apply PositiveMap.find_1 in Hin. rewrite Hin in Habs. discriminate.
+ destruct (PositiveMap.find x env) eqn:Hin; trivial. elim Habs. exists v. now apply PositiveMap.find_2.
Qed.

Lemma for_all2_nth : forall A (d : A) l1 l2 P, for_all2 P l1 l2 ->
  forall n, n < length l1 -> P (nth n l1 d) (nth n l2 d).
Proof.
intros A d l1 l2 P Hall n Hn.
revert l1 l2 Hall Hn. induction n; intros l1 l2 Hall Hn.
- assert (Hlen : length l1 = length l2) by apply (for_all2_length _ _ _ Hall).
  destruct l1 as [| e1 l1]; simpl in Hn; try omega; [].
  destruct l2 as [| e2 l2]; simpl in Hlen; try omega; [].
  simpl. now inversion Hall.
- assert (Hlen : length l1 = length l2) by apply (for_all2_length _ _ _ Hall).
  destruct l1 as [| e1 l1]; simpl in Hn; try omega; [].
  destruct l2 as [| e2 l2]; simpl in Hlen; try omega; [].
  simpl. apply IHn; try omega. now inversion Hall.
Qed.

(** Some general properties of [sem_var]. *)
Lemma sem_var_length : forall h x vl, sem_var h x vl -> length vl = length h.
Proof. unfold sem_var. intros h x vl Hvar. now rewrite <- (map_length (@Some value)), <- Hvar, map_length. Qed.

Lemma sem_var_cons : forall env h x v vl, sem_var (env :: h) x (v :: vl) -> sem_var h x vl.
Proof. unfold sem_var. intros * Hsem. now inversion Hsem. Qed.

Lemma sem_var_nth : forall n h x vl, sem_var h x vl -> n < length h ->
  PositiveMap.find x (nth n h (PositiveMap.empty _)) = Some (nth n vl abs).
Proof.
intros n h x vl Hsem.
assert (Hlen := sem_var_length Hsem).
revert h x vl Hsem Hlen. induction n; intros h x vl Hsem Hlen Hn.
+ destruct vl as [| v vl], h as [| env h]; try discriminate.
  - simpl in Hn. omega.
  - unfold sem_var in *. simpl in *. now inversion Hsem.
+ destruct vl as [| v vl], h as [| env h]; try discriminate.
  - simpl in Hn. omega.
  - simpl in *. apply IHn; try omega. apply (sem_var_cons Hsem).
Qed.

(** **  The [hold] operator in histories that removes [abs] by keeping the last value **)

Definition update_binding (x : ident) v1 (env : venv) : value :=
  match v1 with
    | here _ => v1
    | abs => 
        match PositiveMap.find x env with
          | None => abs
          | Some v2 => v2
        end
  end.

Definition hold_env (curr prev : venv) : venv :=
  PositiveMap.mapi (fun x v => update_binding x v prev) curr.

(** Hold operator on reverse lists: the first element is the latest (time-wise). *)

Definition hold (h : history) : history :=
  List.fold_right (fun e l => hold_env e (hd (PositiveMap.empty _) l) :: l) nil h.

(** ***  Lemmas about [update_binding]  **)

Lemma update_in : forall (x : ident) v env, update_binding x (here v) env = here v.
Proof. reflexivity. Qed.

Lemma update_out : forall (x : ident) v (env : venv),
  PositiveMap.find x env = Some v -> update_binding x abs env = v.
Proof. intros x v env Henv. simpl. now rewrite Henv. Qed.

Lemma update_same_none : forall (x : ident) (env e : venv),
  PositiveMap.find x env = None -> update_binding x abs env = abs.
Proof. intros x env e Henv. simpl. now rewrite Henv. Qed.

(** ***  Lemmas about [hold_env]  **)

Lemma hold_env_in : forall (curr prev : venv) (x : ident) v,
  PositiveMap.find x curr = Some (here v) ->
  PositiveMap.find x (hold_env curr prev) = Some (here v).
Proof. intros curr prev x v Hcurr. unfold hold_env. rewrite PositiveMap.gmapi, Hcurr. simpl. reflexivity. Qed.

Lemma hold_env_out : forall (curr prev : venv) (x : ident) v,
  PositiveMap.find x curr = Some abs ->
  PositiveMap.find x prev = Some v ->
  PositiveMap.find x (hold_env curr prev) = Some v.
Proof.
intros curr prev x v Hcurr Hprev. unfold hold_env.
rewrite PositiveMap.gmapi, Hcurr. simpl. now rewrite Hprev.
Qed.

Lemma hold_env_none : forall (curr prev : venv) (x : ident),
  PositiveMap.find x curr = Some abs ->
  PositiveMap.find x prev = None ->
  PositiveMap.find x (hold_env curr prev) = Some abs.
Proof.
intros curr prev x Hcurr Hprev. unfold hold_env.
rewrite PositiveMap.gmapi, Hcurr. simpl. now rewrite Hprev.
Qed. 

Lemma hold_env_never_None : forall (curr prev : venv) (x : ident),
  PositiveMap.find x (hold_env curr prev) = None <-> PositiveMap.find x curr = None.
Proof.
intros curr prev x. unfold hold_env. rewrite PositiveMap.gmapi.
split; intro Heq.
- destruct (PositiveMap.find x curr); trivial. discriminate.
- now rewrite Heq.
Qed.

Lemma hold_env_abs : forall (curr prev : venv) (x : ident),
  PositiveMap.find x (hold_env curr prev) = Some abs -> PositiveMap.find x curr = Some abs.
Proof.
intros curr prev x Hin. unfold hold_env in Hin. rewrite PositiveMap.gmapi in Hin.
destruct (PositiveMap.find x curr) as [[| v] |]; trivial.
Qed.

Lemma hold_env_abs_spec : forall (curr prev : venv) (x : ident),
  PositiveMap.find x (hold_env curr prev) = Some abs <->
  PositiveMap.find x curr = Some abs /\ (PositiveMap.find x prev = Some abs \/ PositiveMap.find x prev = None).
Proof.
intros curr prev x. split; intro H.
+ split.
  - eapply hold_env_abs. eassumption.
  - destruct (PositiveMap.find x prev) as [[| v] |] eqn:Hin; intuition.
    left. rewrite <- H. symmetry. apply hold_env_out; trivial. now apply hold_env_abs in H.
+ destruct H as [H1 [H2 | H2]].
  - now apply hold_env_out.
  - now apply hold_env_none.
Qed.

(** ***  All environments inside a given history have the same domain  **)

(** First, we need to check that the domain of all environment in the history is the same.
    This property is preversed by hold. *)
Definition same_dom (env1 env2 : venv) := forall x : ident, PositiveMap.In x env1 <-> PositiveMap.In x env2.

Instance same_dom_equiv : Equivalence same_dom.
Proof. unfold same_dom. split.
+ intros ? ?. reflexivity.
+ intros e e' ? ?. symmetry. auto.
+ intros e e' e'' H H' ?. now rewrite H.
Qed.

Definition history_valid (h : history) :=
  match h with
    | nil => True
    | env0 :: h => List.Forall (same_dom env0) h
  end.

Lemma hold_env_dom_valid : forall curr prev, same_dom (hold_env curr prev) curr.
Proof.
intros curr prev x. split; intros [[| v] Hin].
+ exists abs. eapply PositiveMap.find_2, hold_env_abs, PositiveMap.find_1. eassumption.
+ apply PositiveMap.find_1 in Hin.
  destruct (PositiveMap.find x curr) as [v' |] eqn:Hcurr.
  - exists v'. now apply PositiveMap.find_2.
  - rewrite <- hold_env_never_None in Hcurr. rewrite Hcurr in Hin. discriminate.
+ apply PositiveMap.find_1 in Hin.
  destruct (PositiveMap.find x prev) as [v |] eqn:Hprev.
  - exists v. apply PositiveMap.find_2. now apply hold_env_out.
  - exists abs. apply PositiveMap.find_2. now apply hold_env_none.
+ exists v. apply PositiveMap.find_2. now apply hold_env_in.
Qed.

Lemma hold_history_valid : forall h, history_valid (hold h) <-> history_valid h.
Proof.
intros h. destruct h as [| env h]; try now intuition.
simpl.
assert (HP : forall l env e, Forall (same_dom (hold_env env e)) l <-> Forall (same_dom env) l).
{ intros ? ? ?. apply Forall_compat; trivial. repeat intro; subst. now rewrite hold_env_dom_valid. }
rewrite HP.
induction h as [| env1 h]; try now split; constructor.
split; intro Hvalid.
+ simpl. inversion_clear Hvalid. constructor.
  - now rewrite hold_env_dom_valid in H.
  - now rewrite <- IHh.
+ simpl. inversion_clear Hvalid. constructor.
  - now rewrite hold_env_dom_valid.
  - now rewrite IHh.
Qed.

Lemma history_valid_cons : forall env (h : history), history_valid (env :: h) -> history_valid h.
Proof.
intros env h H. destruct h as [| env1 h]; simpl in *; auto.
cut (Forall (same_dom env) h).
- apply Forall_compat; trivial. intros ? e ?; subst. inversion_clear H. now rewrite H0.
- now inversion H.
Qed.

Lemma history_valid_dom : forall d n env h, n < S (length h) -> history_valid (env :: h) ->
  same_dom (nth n (env :: h) d) env.
Proof.
intros d n env h Hn Hvalid. simpl in Hvalid. destruct n.
+ reflexivity.
+ simpl. rewrite Forall_forall in Hvalid. symmetry. apply Hvalid, nth_In. omega.
Qed.

Corollary history_valid_same_dom : forall d n n' (h : history), n < length h -> n' < length h -> history_valid h ->
  same_dom (nth n h d) (nth n' h d).
Proof.
intros d n n' h Hn Hn' Hh. destruct h as [| env h].
- destruct n, n'; reflexivity.
- repeat rewrite history_valid_dom; auto. reflexivity.
Qed.

(** ***  Lemmas about [hold]  **)

Lemma hold_length : forall h, length (hold h) = length h.
Proof. intros h. induction h; simpl; auto. Qed.

Lemma hold_in : forall (d : venv) (x : ident) n (h : history) v, n < length h ->
  PositiveMap.find x (nth n h d) = Some (here v) ->
  PositiveMap.find x (nth n (hold h) d) = Some (here v).
Proof.
intros d x n. induction n; intros h v Hn Hx; simpl.
- destruct h; simpl in *; trivial. now apply hold_env_in.
- destruct h; simpl in *; trivial. apply IHn; trivial. omega.
Qed.

Lemma hold_out_last : forall (d : venv) (x : ident) (h : history),
  PositiveMap.find x (last h d) = Some abs ->
  PositiveMap.find x (last (hold h) d) = Some abs.
Proof.
intros d x h Hx. induction h; trivial. destruct h.
- simpl. apply hold_env_none; trivial. apply PositiveMap.gempty.
- now apply IHh.
Qed.

Lemma hold_out : forall (d : venv) (x : ident) n (h : history), (S n) < length h -> history_valid h ->
  PositiveMap.find x (nth n h d) = Some abs ->
  PositiveMap.find x (nth n (hold h) d) = PositiveMap.find x (nth (S n) (hold h) d).
Proof.
intros d x n. induction n; intros h Hn Hh Hx.
+ induction h as [| env1 [| env2 h]]; trivial; simpl in Hn; try omega; [].
  assert (Hin : PositiveMap.In x env2).
  { inversion_clear Hh. rewrite <- (H x). exists abs. apply PositiveMap.find_2. assumption. }
  destruct Hin as [[| v] Hin]. apply PositiveMap.find_1 in Hin.
  - assert (Hin2 : PositiveMap.In x (hold_env env2 (hd (PositiveMap.empty value) (hold h)))).
    { rewrite (hold_env_dom_valid env2 _ x). exists abs. now apply PositiveMap.find_2. }
    destruct Hin2 as [v Hin2]. apply PositiveMap.find_1 in Hin2.
    simpl in *. rewrite (@hold_env_out _ _ _ v); trivial. now symmetry.
  - clear IHh. simpl nth at 1. rewrite (@hold_env_out _ _ _ v); trivial; [symmetry |];
    apply (@hold_in d x 1 (env1 :: env2 :: h)); auto.
+ destruct h as [| env1 h]; simpl in *; trivial; [].
  apply IHn; trivial.
  - omega.
  - eapply history_valid_cons. eassumption.
Qed.

Lemma hold_never_None : forall d (x : ident) n h,
  PositiveMap.find x (nth n (hold h) d) = None <-> PositiveMap.find x (nth n h d) = None.
Proof.
intros d x n. induction n; intro h.
- destruct h as [| env h]; simpl; try reflexivity. apply hold_env_never_None.
- destruct h as [| env h]; simpl; try reflexivity. apply IHn.
Qed.

Lemma hold_abs_next : forall d (x : ident) n (h : history), S n < length h -> history_valid h ->
  PositiveMap.find x (nth n (hold h) d) = Some abs -> PositiveMap.find x (nth (S n) (hold h) d) = Some abs.
Proof.
intros d x n. induction n; intros h Hn Hvalid Hx.
- destruct h as [| env h]; simpl in Hn; try omega.
  assert (Hnow := hold_env_abs _ _ _ Hx). now rewrite <- hold_out.
- destruct h as [| env h]; simpl in Hn; try omega. simpl.
  apply IHn; trivial; try omega. eapply history_valid_cons. eassumption.
Qed.

Corollary hold_abs_rec : forall d (x : ident) n m (h : history), n + m < length h -> history_valid h ->
  PositiveMap.find x (nth n (hold h) d) = Some abs -> PositiveMap.find x (nth (n + m) (hold h) d) = Some abs.
Proof.
intros d x n m. induction m; intros.
- now rewrite <- plus_n_O.
- rewrite <- plus_n_Sm in *. apply hold_abs_next; trivial. apply IHm; trivial. omega.
Qed.

Lemma hold_abs : forall d (x : ident) n (h : history), n < length h -> history_valid h ->
  PositiveMap.find x (nth n (hold h) d) = Some abs -> PositiveMap.find x (nth n h d) = Some abs.
Proof.
intros d x n. induction n; intros h Hn Hvalid Hx.
- destruct h as [| env h]; simpl in *; try omega.
  now apply hold_env_abs in Hx.
- destruct h as [| env h]; simpl in *; try omega.
  apply IHn; trivial; try omega. eapply history_valid_cons. eassumption.
Qed.

Lemma hold_abs_spec : forall d (x : ident) (h : history) n, n < length h -> history_valid h ->
  (PositiveMap.find x (nth n (hold h) d) = Some abs <->
   forall m, n + m < length h -> PositiveMap.find x (nth (n + m) h d) = Some abs).
Proof.
intros d x h n Hn Hvalid. split; intro H.
* intros. apply hold_abs; trivial. now apply hold_abs_rec.
* revert h Hn Hvalid H. induction n; intros h Hn Hvalid H.
  + simpl in H. induction h as [| env h].
    - simpl in Hn. omega.
    - { assert (Henv : PositiveMap.find x env = Some abs). { apply (H 0). simpl. omega. }
        destruct h as [| env' h]; simpl.
        + apply hold_env_none; trivial. rewrite find_None_not_In.
          intros [v Habs]. revert Habs. apply PositiveMap.empty_1.
        + apply hold_env_out; trivial. apply IHh.
          - simpl. omega.
          - eapply history_valid_cons. eassumption.
          - intros m hm. apply (H (S m)). simpl in *. omega. }
  + destruct h as [| env h]; simpl in Hn; try omega.
    simpl. apply IHn.
    - omega.
    - eapply history_valid_cons. eassumption.
    - intros. apply H. simpl. omega.
Qed.

(** The full specification of [hold] *)
Theorem hold_spec : forall d x n h v, history_valid h -> n < length h ->
  (PositiveMap.find x (nth n (hold h) d) = Some (here v) <->
   exists n', n + n' < length h
           /\ PositiveMap.find x (nth (n + n') h d) = Some (here v)
           /\ forall m, m < n' -> PositiveMap.find x (nth (n + m) h d) = Some abs).
Proof.
intros d x n. induction n; intros h v Hvalid Hn.
* simpl plus. induction h as [| env h]; simpl in Hn; try omega.
  destruct (PositiveMap.find x env) as [[| vx] |] eqn:Henv.
  + (** [x] is [abs] in [env] *)
    destruct h as [| env' h].
    - { simpl. split; intro Habs.
        + exfalso. cut (Some (here v) = Some abs). discriminate.
          rewrite <- Habs. apply hold_env_none; trivial. rewrite find_None_not_In.
          intros [? Hin]. apply (PositiveMap.empty_1 Hin).
        + destruct Habs as [[| ?] [? [Henv' _]]]; try omega.
          rewrite Henv in Henv'. discriminate. }
    - { change env with (nth 0 (env :: env' :: h) d) in Henv.
        assert (Hlen : 1 < length (env :: env' :: h)) by (simpl; omega).
        rewrite (hold_out _ _ _ Hlen Hvalid Henv); trivial; try (simpl; omega); []. simpl.
        rewrite IHh.
        * split; intros [n [Hn' [Hmax Hlt]]].
          + exists (S n). simpl in *. repeat split; trivial; try omega.
            intros [| m] Hm; trivial. apply Hlt. omega.
          + simpl in Henv. destruct n.
            - rewrite Henv in Hmax. discriminate.
            - exists n. simpl. repeat split; trivial; try omega.
              intros m Hm. apply (Hlt (S m)). omega.
        * now apply history_valid_cons in Hvalid.
        * simpl. omega. }
  + (** [x] is [here vx] in [env] *)
    simpl hold. simpl nth at 1. rewrite (hold_env_in _ _ _ Henv).
    split; intro H.
    - inv H. exists 0. simpl. repeat split; trivial. intros. omega.
    - destruct H as [n [Hok [Hmax Hlt]]].
      assert (n = 0).
      { destruct n; trivial. exfalso.
        cut (Some (here vx) = Some abs). discriminate.
        rewrite <- Henv. apply (Hlt 0). omega. }
      subst. simpl in Hmax. now rewrite Henv in Hmax.
  + (** [x] is not present in [h] *)
    rewrite find_None_not_In in Henv.
    split; intro H.
    - elim Henv. erewrite <- (hold_env_dom_valid _ _ x).
      exists (here v). apply PositiveMap.find_2. simpl in *. eassumption.
    - elim Henv. destruct H as [n [Hn' [Hin Hlt]]].
      rewrite (@history_valid_same_dom d 0 n (env :: h) Hn Hn' Hvalid x).
      exists (here v). now apply PositiveMap.find_2.
* destruct h as [| env h]; simpl in Hn |- *; try omega.
  setoid_rewrite <- NPeano.Nat.succ_lt_mono. apply IHn.
  - now apply history_valid_cons in Hvalid.
  - omega.
Qed.

Lemma hold_idempotent : forall x n h d, history_valid h ->
  PositiveMap.find x (nth n (hold (hold h)) d) = PositiveMap.find x (nth n (hold h) d).
Proof.
intros x n. induction n; intro h.
* induction h as [| env h]; intros d Hh.
  + reflexivity.
  + destruct (PositiveMap.find x env) as [[| v] |] eqn:Heq.
    - { destruct h as [| env' h].
        * simpl.
          assert (H : PositiveMap.find x (hold_env env (PositiveMap.empty value)) = Some abs).
          { apply hold_env_none; trivial. apply PositiveMap.gempty. }
          rewrite H. apply hold_env_none; trivial. apply PositiveMap.gempty.
        * destruct (PositiveMap.find x (nth 0 (hold (env :: env' :: h)) d)) as [[| v] |] eqn:Hhold.
          + rewrite hold_abs_spec.
            - intros. apply hold_abs_rec; trivial. now rewrite <- hold_length.
            - rewrite hold_length. simpl. omega.
            - now rewrite hold_history_valid.
          + apply hold_in; trivial. simpl. omega.
          + now rewrite hold_never_None. }
    - { erewrite hold_in.
        + symmetry. apply hold_in; simpl; omega || eassumption.
        + rewrite hold_length. simpl. omega.
        + apply hold_in; simpl; omega || eassumption. }
    - assert (H : PositiveMap.find x (nth 0 (hold (env :: h)) d) = None) by now rewrite hold_never_None.
      rewrite H. now rewrite hold_never_None.
* intros d Hh. destruct h as [| env h]; simpl.
  + reflexivity.
  + apply IHn. now apply history_valid_cons in Hh.
Qed.

Corollary hold_sem_var_idempotent : forall h x vl, history_valid h ->
  (sem_var (hold (hold h)) x vl <-> sem_var (hold h) x vl).
Proof.
intros h x. induction h as [| env h]; intros vl Hh.
* simpl. reflexivity.
* destruct vl as [| e vl].
  + split; intro Hsem; inversion Hsem.
  + specialize (IHh vl (history_valid_cons Hh)).
    unfold sem_var in *. simpl.
    split; (intro Hsem; f_equal; try (now rewrite <- IHh || rewrite IHh; inversion Hsem); []).
    - change (hold_env env (hd (PositiveMap.empty value) (hold h)))
        with (hd (PositiveMap.empty value) (hold (env :: h))).
      rewrite <- nth_hd, <- hold_idempotent, nth_hd; trivial. now inversion Hsem.
    - change (hold_env (hold_env env (hd (PositiveMap.empty value) (hold h)))
               (hd (PositiveMap.empty value) (hold (hold h))))
        with (hd (PositiveMap.empty value) (hold (hold (env :: h)))).
      rewrite <- nth_hd, hold_idempotent, nth_hd; try rewrite hold_history_valid; trivial.
      now inversion Hsem.
Qed.

(** **  The equivalence of [fby] with and without [hold]  **)

(** ***  Specification of [fby_rev]  **)

Lemma fby_aux_snd_spec : forall v0 v vl, snd (fby_aux v0 vl) = v <->
  (exists n, nth n vl abs = here v /\ forall m, m < n -> nth m vl abs = abs)
  \/ v = v0 /\ forall n, nth n vl abs = abs.
Proof.
intros v0 v vl. revert v0. induction vl as [| v1 vl]; intros v0.
* setoid_rewrite nth_nil. simpl. split; intro H.
  + subst. auto.
  + destruct H as [[? [? _]] | [? _]]; discriminate || auto.
* split; intro H.
  + destruct v1 as [| v1]; simpl in H.
    - { destruct (fby_aux v0 vl) eqn:Hfby. simpl in H. subst.
        specialize (IHvl v0). rewrite Hfby in IHvl.
        assert (Hrec : v = v) by reflexivity. rewrite IHvl in Hrec. clear IHvl.
        destruct Hrec as [[n [Hn Hother]] | [Hn Hother]].
        + left. exists (S n). simpl. split; trivial.
          intros [| m] Hlt; trivial. apply Hother. omega.
        + right. split; trivial. intros [| n]; trivial. apply Hother. }
    - destruct (fby_aux v0 vl) eqn:Hfby. simpl in H. subst v.
      specialize (IHvl v1). left. exists 0. split; trivial. intros. omega.
  + destruct v1 as [| v1]; simpl.
    - { destruct (fby_aux v0 vl) eqn:Hfby. change (snd (l, c) = v). rewrite <- Hfby.
        rewrite IHvl. clear IHvl. destruct H as [[[| n] [Hn Hother]] | [Hn Hother]].
        + discriminate.
        + left. exists n. simpl. split; trivial. intros m Hlt. apply (Hother (S m)). omega.
        + right. split; trivial. intro n. apply (Hother (S n)). }
    - { destruct (fby_aux v0 vl) eqn:Hfby. simpl.
        destruct H as [[n [Hn Hother]] | [Hn Hother]].
        + assert (n = 0).
          { destruct n; trivial. exfalso. cut (here v1 = abs). discriminate.
            rewrite <- (Hother 0); trivial. omega. }
          subst. simpl in Hn. now inv Hn.
        + exfalso. cut (here v1 = abs). discriminate.
          now rewrite <- (Hother 0). }
Qed.

Theorem fby_rev_spec : forall n v0 v vl, nth n (fby_rev v0 vl) abs = here v
  <-> nth n vl abs <> abs
   /\ ((exists n', nth (S (n + n')) vl abs = here v /\ forall m, m < n' -> nth (S (n + m)) vl abs = abs)
       \/ v = v0 /\ forall n', nth (S (n + n')) vl abs = abs).
Proof.
intro n. induction n; intros v0 v vl.
* simpl plus. unfold fby_rev. destruct vl as [| [| v1] vl]; simpl.
  + intuition discriminate.
  + destruct (fby_aux v0 vl); simpl. intuition discriminate.
  + destruct (fby_aux v0 vl) eqn:Hfby; simpl.
    assert (Hequiv : here c = here v <-> c = v). { split; intro Heq; subst; trivial. now injection Heq. }
    rewrite Hequiv. change c with (snd (l, c)). rewrite <- Hfby.
    rewrite fby_aux_snd_spec. intuition discriminate.
* destruct vl; simpl.
  + split; intro Habs.
    - discriminate.
    - destruct Habs as [Habs _]. now elim Habs.
  + rewrite fby_rev_next. apply IHn.
Qed.

(** ***  Definition and specification of [fby] on [hold h]  **)

(** With held environments, we insert the base value right from the start even if there are abs values *)

Fixpoint held_fby_aux v0 s :=
  match s with
    | nil => (nil, v0)
    | abs :: s0 => let '(s', v') := held_fby_aux v0 s0 in (here v' :: s', v')
    | here v :: s0 => let '(s', v') := held_fby_aux v0 s0 in (here v' :: s', v)
  end.
Definition held_fby_rev v0 s := fst (held_fby_aux v0 s).

Lemma held_fby_rev_nil : forall v, held_fby_rev v nil = nil.
Proof. reflexivity. Qed.

Lemma held_fby_rev_cons : forall v0 v s,
  held_fby_rev v0 (v :: s) = here (snd (held_fby_aux v0 s)) :: held_fby_rev v0 s.
Proof. intros v0 v s. unfold held_fby_rev. simpl. now destruct v, (held_fby_aux v0 s). Qed.

Lemma held_fby_aux_abs : forall v0 s,
  held_fby_aux v0 (abs :: s) = (here (snd (held_fby_aux v0 s)) :: fst (held_fby_aux v0 s), snd (held_fby_aux v0 s)).
Proof.
induction s as [| [| v] s]; simpl in *.
- reflexivity.
- rewrite IHs; reflexivity.
- destruct (held_fby_aux v0 s); simpl. reflexivity.
Qed.

Lemma held_fby_rev_next : forall d v0 v s n,
  List.nth (S n) (held_fby_rev v0 (v :: s)) d = List.nth n (held_fby_rev v0 s) d.
Proof. unfold held_fby_rev. intros d c [| c'] s n; simpl; destruct (held_fby_aux c s); reflexivity. Qed.

Lemma held_fby_rev_never_abs : forall d v s n, List.nth n (held_fby_rev v s) (here d) <> abs.
Proof.
intros d v s. induction s as [| v' s]; intros n Hn.
+ destruct n; simpl in Hn; discriminate.
+ destruct n; simpl in Hn.
  - destruct v'; simpl in Hn; now rewrite held_fby_rev_cons in Hn.
  - rewrite held_fby_rev_next in Hn. now apply (IHs n Hn).
Qed.

Lemma held_fby_aux_app : forall s1 s2 v s1' s2' v' v'',
  held_fby_aux v s2 = (s2', v') ->
  held_fby_aux v' s1 = (s1', v'') ->
  held_fby_aux v (s1 ++ s2) = (s1' ++ s2', v'').
Proof.
intros s1. induction s1 as [| [| c] s1]; intros s2 v s1' s2' v' v'' Hs2 Hs1.
+ inversion Hs1. subst. simpl. assumption.
+ simpl app. rewrite held_fby_aux_abs in Hs1 |- *. destruct s1' as [| ? s1']; inversion Hs1.
  simpl. apply (IHs1 _ _ s1' _ _ v'') in Hs2.
  - rewrite Hs2. f_equal; subst; auto.
  - subst. apply surjective_pairing.
+ simpl in *. destruct (held_fby_aux v' s1) eqn:Hs1'.
  rewrite (IHs1 _ _ _ _ _ _ Hs2 Hs1'). inversion_clear Hs1. simpl. reflexivity.
Qed.

Corollary held_fby_rev_last_abs : forall v s, held_fby_rev v (s ++ abs :: nil) = held_fby_rev v s ++ here v :: nil.
Proof.
intros. unfold held_fby_rev.
erewrite held_fby_aux_app; simpl; try reflexivity; [].
apply surjective_pairing.
Qed.


(** The specification of [held_fby_rev] *)
Lemma held_fby_aux_snd_spec : forall v0 v vl, snd (held_fby_aux v0 vl) = v <->
  (exists n, nth n vl abs = here v /\ forall m, m < n -> nth m vl abs = abs)
  \/ v = v0 /\ forall n, nth n vl abs = abs.
Proof.
intros v0 v vl. revert v0. induction vl as [| v1 vl]; intros v0.
* setoid_rewrite nth_nil. simpl. split; intro H.
  + subst. auto.
  + destruct H as [[? [? _]] | [? _]]; discriminate || auto.
* split; intro H.
  + destruct v1 as [| v1]; simpl in H.
    - { destruct (held_fby_aux v0 vl) eqn:Hfby. simpl in H. subst.
        specialize (IHvl v0). rewrite Hfby in IHvl.
        assert (Hrec : v = v) by reflexivity. rewrite IHvl in Hrec. clear IHvl.
        destruct Hrec as [[n [Hn Hother]] | [Hn Hother]].
        + left. exists (S n). simpl. split; trivial.
          intros [| m] Hlt; trivial. apply Hother. omega.
        + right. split; trivial. intros [| n]; trivial. apply Hother. }
    - destruct (held_fby_aux v0 vl) eqn:Hfby. simpl in H. subst v.
      specialize (IHvl v1). left. exists 0. split; trivial. intros. omega.
  + destruct v1 as [| v1]; simpl.
    - { destruct (held_fby_aux v0 vl) eqn:Hfby. change (snd (l, c) = v). rewrite <- Hfby.
        rewrite IHvl. clear IHvl. destruct H as [[[| n] [Hn Hother]] | [Hn Hother]].
        + discriminate.
        + left. exists n. simpl. split; trivial. intros m Hlt. apply (Hother (S m)). omega.
        + right. split; trivial. intro n. apply (Hother (S n)). }
    - { destruct (held_fby_aux v0 vl) eqn:Hfby. simpl.
        destruct H as [[n [Hn Hother]] | [Hn Hother]].
        + assert (n = 0).
          { destruct n; trivial. exfalso. cut (here v1 = abs). discriminate.
            rewrite <- (Hother 0); trivial. omega. }
          subst. simpl in Hn. now inv Hn.
        + exfalso. cut (here v1 = abs). discriminate.
          now rewrite <- (Hother 0). }
Qed.

Theorem held_fby_rev_spec : forall n v0 v vl, n < length vl -> 
  (nth n (held_fby_rev v0 vl) abs = here v
   <-> (exists n', nth (S (n + n')) vl abs = here v /\ forall m, m < n' -> nth (S (n + m)) vl abs = abs)
        \/ v = v0 /\ forall n', nth (S (n + n')) vl abs = abs).
Proof.
intro n. induction n; intros v0 v vl Hn.
* simpl plus. unfold held_fby_rev. destruct vl as [| v1 vl]; simpl.
  + simpl in Hn. exfalso. omega.
  + destruct (held_fby_aux v0 vl) eqn:Hfby; simpl.
    assert (Hequiv : here c = here v <-> c = v). { split; intro Heq; subst; trivial. now injection Heq. }
    destruct v1; rewrite Hequiv; change c with (snd (l, c)); rewrite <- Hfby;
    rewrite held_fby_aux_snd_spec; intuition discriminate.
* destruct vl; simpl.
  + simpl in Hn. exfalso. omega.
  + rewrite held_fby_rev_next. apply IHn. simpl in Hn. omega.
Qed.

(** Simulation between these two notions of [fby]. *)
Theorem fby_rev_held_fby_rev : forall n v v0 vl,
  nth n (fby_rev v0 vl) abs = here v -> nth n (held_fby_rev v0 vl) abs = here v.
Proof.
intros n v v0 vl Hfby.
rewrite fby_rev_spec in Hfby. destruct Hfby as [Hlen Hfby].
apply nth_not_default_lt_length in Hlen.
rewrite held_fby_rev_spec; trivial.
Qed.

Lemma fby_rev_hold_held_fby_rev : forall h x v0 vl1 vl2,
  history_valid h -> sem_var h x vl1 -> sem_var (hold h) x vl2 ->
  forall n v, n < length h -> nth n (fby_rev v0 vl1) abs = here v -> nth n (held_fby_rev v0 vl2) abs = here v.
Proof.
intros h x v0 vl1 vl2 Hvalid Husual Hhold n v Hn Hv.
rewrite fby_rev_spec in Hv.
rewrite held_fby_rev_spec.
* destruct Hv as [Hnow [[m [Hmax Hlt]] | [? Hall]]].
  + left. exists 0. split.
    - rewrite <- plus_n_O. admit. (* TODO *)
    - intros. omega.
  + right. split; trivial. intros m. apply Some_inj.
    destruct (Compare_dec.le_lt_dec (length (hold h)) (S (n + m))).
    - rewrite nth_overflow; trivial. now rewrite (sem_var_length Hhold).
    - rewrite <- (sem_var_nth Hhold); trivial.
      rewrite hold_length in *. rewrite hold_abs_spec; trivial.
      intros n' Hn'. rewrite (sem_var_nth Husual); trivial. simpl. rewrite <- Plus.plus_assoc.
      now rewrite Hall.
* now rewrite (sem_var_length Hhold), hold_length.
Qed.

(** ***  The equivalence theorem  **)

(** General equivalence on held histories (except for first [abs] instants). *)
Theorem fby_hold_equiv : forall h x vl, history_valid h -> sem_var (hold h) x vl ->
  forall n v0 v, S n < length h -> ~(forall m, nth (S n + m) vl abs = abs) ->
    nth n (held_fby_rev v0 vl) abs = here v -> nth (S n) vl abs = here v.
Proof.
intros h x vl Hvalid Hh n v0 v Hn Hlast Hv.
apply Some_inj.
assert (Hlen : n < length vl). { rewrite (sem_var_length Hh), hold_length. omega. }
rewrite held_fby_rev_spec in Hv; trivial.
  destruct Hv as [[m [Hmax Hlt]] | [? ?]]; try contradiction; [].
rewrite <- (sem_var_nth Hh).
* rewrite <- hold_idempotent; trivial.
  rewrite <- hold_history_valid in Hvalid. rewrite <- hold_length in Hn.
  rewrite hold_spec; trivial.
  exists m. repeat split.
  + rewrite <- (sem_var_length Hh).
    apply (@nth_not_default_lt_length _ abs). simpl. erewrite Hmax. discriminate.
  + rewrite (sem_var_nth Hh); simpl; try (now rewrite Hmax); [].
    rewrite <- (sem_var_length Hh).
    apply (@nth_not_default_lt_length _ abs _ vl). rewrite Hmax. discriminate.
  + intros m' Hm.
    assert (Hneq : S n + m' < length h).
    { assert (Hneq : here v <> abs) by discriminate. rewrite <- Hmax in Hneq.
      apply nth_not_default_lt_length in Hneq.
      rewrite <- hold_length, <- (sem_var_length Hh). omega. }
    rewrite (sem_var_nth Hh).
    - simpl. now rewrite Hlt.
    - now rewrite hold_length.
* now rewrite hold_length.
Qed.

(* The theorem for the first [abs] instants. *)
Theorem fby_first_equiv : forall h x vl, history_valid h -> sem_var (hold h) x vl ->
  forall n v0, n < length h -> (forall m, nth (S n + m) vl abs = abs) ->
               nth n (held_fby_rev v0 vl) abs = here v0.
Proof.
intros h x vl Hvalid Hh n v0 Hn Hlast.
rewrite held_fby_rev_spec.
- right. now split.
- now rewrite (sem_var_length Hh), hold_length.
Qed.

Theorem fby_equivalence : forall h x vl1 vl2, history_valid h ->
  sem_var h x vl1 -> sem_var (hold h) x vl2 ->
  forall n v0 v, S n < length h -> ~(forall m : nat, nth (S n + m) vl2 abs = abs) ->
    nth n (fby_rev v0 vl1) abs = here v -> nth (S n) vl2 abs = here v.
Proof.
intros h x vl1 vl2 Hvalid Husual Hhold n v0 v Hn Hlast Hv.
eapply fby_hold_equiv; try eassumption.
eapply fby_rev_hold_held_fby_rev; try eassumption. omega.
Qed.

Inductive held_sem_equation_rev (G : global) : history -> equation -> Prop :=
  | HSEqDef_rev : forall H x cae v,
      sem_lexp H (Evar x) v -> sem_caexp H cae v -> held_sem_equation_rev G H (EqDef x cae)
  | HSEqApp_rev : forall H x f arg input output eqs H' vi vo,
      PositiveMap.find f G = Some (mk_node f input output eqs) ->
      sem_laexp H arg vi ->
      sem_lexp H (Evar x) vo ->
      sem_lexp H' (Evar input.(v_name)) vi ->
      sem_lexp H' (Evar output.(v_name)) vo ->
      List.Forall (held_sem_equation_rev G H') eqs ->
      held_sem_equation_rev G H (EqApp x f arg)
  | HSEqFby_rev : forall H x v (y : var_dec) cl,
      sem_var H y cl ->
      sem_lexp H (Evar x) (held_fby_rev v cl) ->
      held_sem_equation_rev G H (EqFby x v y).

(*
Lemma hold_sem_laexp : forall h lae vl1 vl2,
  sem_laexp h lae vl1 -> sem_laexp (hold h) lae vl2 ->
  forall n v, n < length h -> nth n vl1 abs = here v -> nth n vl2 abs = here v.
Proof.
intros h [ck le] vl1 vl2 Husual Hhold n v Hn.
induction le.
+ rewrite sem_laexp_equiv in Husual. hnf in Husual.
 Print for_all2.
Print Implicit for_all2_nth.
  Check (for_all2_nth abs vl1 vl2). in Husual.
SearchAbout for_all2.
Locate for_all2.
 Print sem_laexp'. inv Husual. simpl in Hn. omega.
+ 
+ 
* induction Hsem; simpl; constructor.
  + 
  + 

Theorem hold_equivalence : forall G h eqn,
  sem_equation_rev G h eqn <-> held_sem_equation_rev G (hold h) eqn.
Proof.
intros G h eqn. destruct eqn.
* split; intro H.
  - inversion_clear H. econstructor 1.
+ 
+ 
Qed.
*)