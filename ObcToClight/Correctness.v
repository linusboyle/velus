Require Import cfrontend.ClightBigstep.
Require Import cfrontend.Clight.
Require Import cfrontend.Ctypes.
Require Import lib.Integers.
Require Import lib.Maps.
Require Import lib.Coqlib.
Require Errors.
Require Import common.Separation.
Require Import common.Values.
Require Import common.Memory.
Require Import common.Events.
Require Import common.Globalenvs.

Require Import Rustre.Common.
Require Import Rustre.RMemory.
Require Import Rustre.Ident.

Require Import Rustre.ObcToClight.MoreSeparation.
Require Import Rustre.ObcToClight.SepInvariant.
Require Import Rustre.ObcToClight.Translation.
Require Import Rustre.ObcToClight.Interface.

Require Import Program.Tactics.
Require Import List.
Import List.ListNotations.
Require Import Coq.ZArith.BinInt.
Require Import Coq.Sorting.Permutation.

Open Scope list_scope.
Open Scope sep_scope.
Open Scope Z.

Hint Constructors Clight.eval_lvalue Clight.eval_expr.
Hint Resolve  Clight.assign_loc_value.

Hint Resolve Z.divide_refl.

Lemma type_eq_refl:
  forall {A} t (T F: A),
    (if type_eq t t then T else F) = T.
Proof.
  intros.
  destruct (type_eq t t) as [|Neq]; auto.
  now contradict Neq.
Qed.

Lemma NoDup_norepet:
  forall {A} (l: list A),
    NoDup l <-> list_norepet l.
Proof.
  induction l; split; constructor.
  - now inversion H.
  - apply IHl; now inversion H.
  - now inversion H.
  - apply IHl; now inversion H.
Qed.

Lemma NoDupMembers_disjoint:
  forall l1 l2,
    NoDupMembers (l1 ++ l2) ->
    list_disjoint (var_names l1) (var_names l2).
Proof.
  unfold list_disjoint, var_names.
  intros l1 l2 H x y Hx Hy.
  apply in_map_iff in Hx; destruct Hx as ((x', tx) & Ex & Hx);
  apply in_map_iff in Hy; destruct Hy as ((y', ty) & Ey & Hy);
  simpl in *; subst.
  intro E; subst.
  apply in_split in Hx; destruct Hx as (lx & lx' & Hx);
  apply in_split in Hy; destruct Hy as (ly & ly' & Hy);
  subst.
  rewrite <-app_assoc in H.
  apply NoDupMembers_app_r in H.
  rewrite <-app_comm_cons, nodupmembers_cons in H.
  destruct H as [Notin]; apply Notin.
  apply InMembers_app; right; apply InMembers_app; right; apply inmembers_eq.
Qed.

Lemma NoDupMembers_rec_instance_methods:
  forall s l,
    NoDupMembers l ->
    NoDupMembers (rec_instance_methods s l).
Proof.
  induction s; simpl; intros ** Nodup;
  try repeat constructor; auto.
  destruct (in_dec dec_pair (i0, i1) (map fst l1)); auto.
  constructor; auto.
  now rewrite fst_InMembers.
Qed.

Lemma NoDupMembers_instance_methods:
  forall m, NoDupMembers (instance_methods m).
Proof.
  intro.
  unfold instance_methods.
  apply NoDupMembers_rec_instance_methods; constructor.
Qed.

Lemma In_rec_instance_methods:
  forall s l o fid cid,
    In (o, fid, cid) (rec_instance_methods s l) <->
    In (o, fid, cid) (rec_instance_methods s []) \/ In (o, fid, cid) l.
Proof.
  induction s; simpl; split; intros ** Hin;
  try now right.
  - destruct Hin; auto; contradiction.
  - destruct Hin; auto; contradiction.
  - rewrite IHs2, IHs1 in Hin.
    rewrite IHs2.
    destruct Hin as [|[|]]; auto.
  - rewrite IHs2 in Hin.
    rewrite IHs2, IHs1.
    destruct Hin as [[|]|]; auto.
  - rewrite IHs2, IHs1 in Hin.
    rewrite IHs2.
    destruct Hin as [|[|]]; auto.
  - rewrite IHs2 in Hin.
    rewrite IHs2, IHs1.
    destruct Hin as [[|]|]; auto.
  - destruct (in_dec dec_pair (i0, i1) (map fst l1)).
    + now right.
    + destruct Hin as [E|Hin].
      * inv E; left; now left.
      * now right.
  - destruct Hin as [[E|]|Hin]; try contradiction.
    + inv E.
      destruct (in_dec dec_pair (o, fid) (map fst l1)) as [E|] eqn: H.
      * admit.
      * apply in_eq.
    + destruct (in_dec dec_pair (i0, i1) (map fst l1)); auto.
      now apply in_cons.
  - destruct Hin; auto; contradiction.
Qed.
 
Lemma NoDupMembers_make_out_vars:
  forall m, NoDupMembers (make_out_vars (instance_methods m)).
Proof.
  intro.
  unfold make_out_vars.
  rewrite fst_NoDupMembers, map_map, NoDup_norepet.
  apply list_map_norepet.
  - rewrite <-NoDup_norepet.
    apply NoDupMembers_NoDup, NoDupMembers_instance_methods.
  - intros ((ox, fx), cx) ((oy, fy), cy) Hx Hy Diff; simpl.
    intro E; apply Diff.
    apply prefix_out_injective in E; destruct E; subst.
    repeat f_equal.
    eapply NoDupMembers_det; eauto.
    apply NoDupMembers_instance_methods.
Qed.

Remark translate_param_fst:
  forall xs, map fst (map translate_param xs) = map fst xs.
Proof.
  intro; rewrite map_map.
  induction xs as [|(x, t)]; simpl; auto.
  now rewrite IHxs.
Qed.

Remark translate_obj_fst:
  forall objs, map fst (map translate_obj objs) = map fst objs.
Proof.
  intro; rewrite map_map.
  induction objs as [|(o, k)]; simpl; auto.
  now rewrite IHobjs.
Qed.

Lemma NoDupMembers_make_members:
  forall c, NoDupMembers (make_members c).
Proof.
  intro; unfold make_members.
  pose proof (c_nodup c) as Nodup.
  rewrite fst_NoDupMembers.
  rewrite map_app.
  now rewrite translate_param_fst, translate_obj_fst.
Qed.

Lemma glob_bind_vardef_fst:
  forall xs init volatile,
    map fst (map (vardef init volatile) (map glob_bind xs)) =
    map (fun xt => glob_id (fst xt)) xs.
Proof.
  induction xs as [|(x, t)]; simpl; intros; auto.
  now rewrite IHxs.
Qed.

Lemma self_not_out: self <> out.
Proof.
  intro Eq.
  pose proof reserved_nodup as Nodup.
  unfold reserved in Nodup.
  inversion Nodup as [|? ? Notin]; subst; clear Nodup.
  rewrite Eq in Notin.
  contradict Notin; apply in_eq.  
Qed.

  
(* SIMULATION *)

Section PRESERVATION.

  Variable main_node : ident.
  Variable prog: program.
  Variable tprog: Clight.program.
   
  Let tge := Clight.globalenv tprog.
  Let gcenv := Clight.genv_cenv tge.
  
  Hypothesis TRANSL: translate prog main_node = Errors.OK tprog.
  Hypothesis WT: wt_program prog.

  Lemma build_ok:
    forall types defs public main p,
      make_program' types defs public main = Errors.OK p ->
      build_composite_env types = Errors.OK p.(prog_comp_env).
  Proof.
    unfold make_program'; intros.
    destruct (build_composite_env' types) as [[ce EQ] | msg].
    - inv H; auto.
    - discriminate.
  Qed.

  Theorem Consistent: composite_env_consistent gcenv.
  Proof.
    unfold translate in TRANSL.
    destruct (find_class main_node prog) as [(c, cls)|]; try discriminate.
    destruct (find_method step (c_methods c)) as [m|]; try discriminate.
    destruct (split (map (translate_class prog) prog)) as (structs, funs).
    apply build_ok in TRANSL.
    apply build_composite_env_consistent in TRANSL; auto.
  Qed.
  Hint Resolve Consistent.
  
  Opaque sepconj.

  Inductive occurs_in: stmt -> stmt -> Prop :=
  | occurs_refl: forall s,
      occurs_in s s
  | occurs_ite: forall s e s1 s2,
      occurs_in s s1 \/ occurs_in s s2 ->
      occurs_in s (Ifte e s1 s2)
  | occurs_comp: forall s s1 s2,
      occurs_in s s1 \/ occurs_in s s2 ->
      occurs_in s (Comp s1 s2).
  Hint Resolve occurs_refl.
  
  Remark occurs_in_ite:
    forall e s1 s2 s,
      occurs_in (Ifte e s1 s2) s ->
      occurs_in s1 s /\ occurs_in s2 s.
  Proof.
    intros ** Occurs.
    induction s; inversion_clear Occurs as [|? ? ? ? [Hs1|Hs2]|? ? ? [Hs1|Hs2]];
    split; constructor; ((left; now apply IHs1) || (right; now apply IHs2) || idtac). 
    - left; auto.
    - right; auto.
  Qed.

  Remark occurs_in_comp:
    forall s1 s2 s,
      occurs_in (Comp s1 s2) s ->
      occurs_in s1 s /\ occurs_in s2 s.
  Proof.
    intros ** Occurs.
    induction s; inversion_clear Occurs as [|? ? ? ? [Hs1|Hs2]|? ? ? [Hs1|Hs2]];
    split; constructor; ((left; now apply IHs1) || (right; now apply IHs2) || idtac). 
    - left; auto.
    - right; auto.
  Qed.
  Hint Resolve occurs_in_ite occurs_in_comp.
  
  Lemma occurs_in_instance_methods:
    forall ys clsid o fid es f,
      occurs_in (Call ys clsid o fid es) (m_body f) ->
      In (o, fid, clsid) (instance_methods f).
  Proof.
    intros ** Occurs.
    unfold instance_methods.
    induction (m_body f); inversion_clear Occurs as [|? ? ? ? [Hs1|Hs2]|? ? ? [Hs1|Hs2]];
    simpl; try (apply In_rec_instance_methods; auto).
    now left.
  Qed.
  
  Section ClassProperties.
    Variables (ownerid: ident) (owner: class) (prog': program).
    Hypothesis Findcl: find_class ownerid prog = Some (owner, prog').
    
    Theorem make_members_co:
      exists co,
        gcenv ! ownerid = Some co
        /\ co_su co = Struct
        /\ co_members co = make_members owner
        /\ attr_alignas (co_attr co) = None
        /\ NoDupMembers (co_members co).
    Proof.
      unfold translate in TRANSL.
      destruct (find_class main_node prog) as [(main, ?)|]; try discriminate.
      destruct (find_method step (c_methods main)) as [m|]; try discriminate.
      destruct (split (map (translate_class prog) prog)) as (structs, funs) eqn: E.
      pose proof (find_class_name _ _ _ _ Findcl); subst.
      apply build_ok in TRANSL.
      assert (In (Composite (c_name owner) Struct (make_members owner) noattr) (concat structs)).
      { unfold translate_class in E.
        apply split_map in E.
        destruct E as [Structs].
        unfold make_struct in Structs.
        apply find_class_In in Findcl.
        apply in_map with (f:=fun c => Composite (c_name c) Struct (make_members c) noattr :: make_out c)
          in Findcl.
        apply in_concat with (Composite (c_name owner) Struct (make_members owner) noattr :: make_out owner). 
        - apply in_eq.
        - now rewrite Structs.
      }
      edestruct build_composite_env_charact as (co & ? & Hmembers & Hattr & ?); eauto.
      exists co; repeat split; auto.
      - rewrite Hattr; auto. 
      - rewrite Hmembers. apply NoDupMembers_make_members. 
    Qed.

    Section MethodProperties.
      Variables (callerid: ident) (caller: method).
      Hypothesis Findmth: find_method callerid owner.(c_methods) = Some caller.

      Theorem global_out_struct:
        exists co,
          gcenv ! (prefix_fun (c_name owner) (m_name caller)) = Some co
          /\ co.(co_su) = Struct 
          /\ co.(co_members) = map translate_param caller.(m_out)
          /\ co.(co_attr) = noattr.
      Proof.
        unfold translate in TRANSL.
        destruct (find_class main_node prog) as [(main, cls)|]; try discriminate.
        destruct (find_method step (c_methods main)) as [m|]; try discriminate.
        destruct (split (map (translate_class prog) prog)) as (structs, funs) eqn: E.
        apply build_ok in TRANSL.
        assert (In (Composite
                      (prefix_fun (c_name owner) (m_name caller))
                      Struct
                      (map translate_param caller.(m_out))
                      noattr) (concat structs)).
        { unfold translate_class in E.
          apply split_map in E.
          destruct E as [Structs].
          unfold make_out in Structs.
          apply find_class_In in Findcl.
          apply in_map with (f:=fun c => make_struct c :: map (translate_out c) (c_methods c))
            in Findcl.
          apply find_method_In in Findmth.
          apply in_map with (f:=translate_out owner) in Findmth.
          unfold translate_out at 1 in Findmth.
          eapply in_concat_cons; eauto.
          rewrite Structs; eauto.
        }
        edestruct build_composite_env_charact as (co & ? & ? & ? & ?); eauto.
      Qed.

      Remark output_match:
        forall outco,
          gcenv ! (prefix_fun (c_name owner) (m_name caller)) = Some outco ->
          map translate_param caller.(m_out) = outco.(co_members).
      Proof.
        intros ** Houtco.
        edestruct global_out_struct as (outco' & Houtco' & Eq); eauto.
        rewrite Houtco in Houtco'; now inv Houtco'.
      Qed.

      Lemma well_formed_instance_methods:
        forall o fid cid,
          In (o, fid, cid) (instance_methods caller) ->
          exists c cls callee,
            find_class cid prog = Some (c, cls)
            /\ find_method fid (c_methods c) = Some callee.
      Proof.
        intros ** Hin.
        pose proof (find_class_name _ _ _ _ Findcl) as Eq.
        pose proof (find_method_name _ _ _ Findmth) as Eq'.
        (* apply find_class_In in Findcl. *)
        (* apply find_method_In in Findmth. *)
        edestruct wt_program_find_class as [WT']; eauto.
        eapply wt_class_find_method in WT'; eauto.
        (* eapply wt_program_find_class in WT; eauto. *)
        (* pose proof well_formed as WF. *)
        (* do 2 eapply In_Forall in WF; eauto. *)
        unfold instance_methods in Hin.
        unfold wt_method in WT'.
        induction (m_body caller); simpl in *; try contradiction; inv WT'.
        - rewrite In_rec_instance_methods in Hin. destruct Hin.
          + apply IHs2; auto.
          + apply IHs1; auto. 
        - rewrite In_rec_instance_methods in Hin. destruct Hin.
          + apply IHs2; auto.
          + apply IHs1; auto. 
        - destruct Hin as [E|]; try contradiction; inv E.
          exists cls, p', fm; split; auto.
          apply find_class_sub in Findcl.
          eapply find_class_sub_same; eauto.
      Qed.

      Theorem methods_corres:
        exists loc_f f,
          Genv.find_symbol tge (prefix_fun ownerid callerid) = Some loc_f
          /\ Genv.find_funct_ptr tge loc_f = Some (Internal f)
          /\ f.(fn_params) = (self, type_of_inst_p owner.(c_name))
                              :: (out, type_of_inst_p (prefix_fun owner.(c_name) caller.(m_name)))
                              :: (map translate_param caller.(m_in))
          /\ f.(fn_return) = Tvoid
          /\ f.(fn_callconv) = AST.cc_default
          /\ f.(fn_vars) = make_out_vars (instance_methods caller)
          /\ f.(fn_temps) = map translate_param caller.(m_vars) 
          /\ list_norepet (var_names f.(fn_params))
          /\ list_norepet (var_names f.(fn_vars))
          /\ list_disjoint (var_names f.(fn_params)) (var_names f.(fn_temps))
          /\ f.(fn_body) = return_none (translate_stmt prog owner caller caller.(m_body)).
      Proof.
        unfold translate in TRANSL.
        destruct (find_class main_node prog) as [(main, cls)|]; try discriminate.
        destruct (find_method step (c_methods main)) as [m|]; try discriminate.
        destruct (split (map (translate_class prog) prog)) as (structs, funs) eqn: E.
        pose proof (find_class_name _ _ _ _ Findcl);
          pose proof (find_method_name _ _ _ Findmth); subst.
        assert ((AST.prog_defmap tprog) ! (prefix_fun owner.(c_name) caller.(m_name)) =
                Some (snd (translate_method prog owner caller))) as Hget. 
        { unfold translate_class in E.
          apply split_map in E.
          destruct E as [? Funs].
          unfold make_methods in Funs.
          apply find_class_In in Findcl.
          apply in_map with (f:=fun c => map (translate_method prog c) (c_methods c))
            in Findcl.
          apply find_method_In in Findmth.
          apply in_map with (f:=translate_method prog owner) in Findmth.
          eapply in_concat in Findmth; eauto.
          rewrite <-Funs in Findmth.
          unfold make_program' in TRANSL.
          destruct (build_composite_env' (concat structs)) as [(ce, P)|]; try discriminate.
          inversion TRANSL as [Htprog]; clear TRANSL.
          unfold AST.prog_defmap; simpl.
          apply PTree_Properties.of_list_norepet.
          - (* rewrite <-NoDup_norepet, <-fst_NoDupMembers. *)
            rewrite map_cons, 3 map_app; simpl.
            repeat rewrite glob_bind_vardef_fst. admit.
          - apply in_cons, in_app; right; apply in_app; right; apply in_app; left.
            unfold translate_method in Findmth; auto.
        }
        apply Genv.find_def_symbol in Hget.
        destruct Hget as (loc_f & Findsym & Finddef).
        simpl in Finddef.
        unfold fundef in Finddef.
        set (f:= {| fn_return := Tvoid;
                    fn_callconv := AST.cc_default;
                    fn_params := (self, type_of_inst_p (c_name owner))
                                   :: (out, type_of_inst_p (prefix_fun (c_name owner) (m_name caller)))
                                   :: map translate_param (m_in caller);
                    fn_vars := make_out_vars (instance_methods caller);
                    fn_temps := map translate_param (m_vars caller);
                    fn_body := return_none (translate_stmt prog owner caller (m_body caller)) |})
          in Finddef.
        exists loc_f, f.
        try repeat split; auto.
        - change (Genv.find_funct_ptr tge loc_f) with (Genv.find_funct_ptr (Genv.globalenv tprog) loc_f).
          unfold Genv.find_funct_ptr.
          unfold Clight.fundef in Finddef.
          now rewrite Finddef.
        - unfold var_names.
          rewrite <-NoDup_norepet, <-fst_NoDupMembers.
          subst f; simpl.
          constructor.
          + intro Hin; simpl in Hin; destruct Hin as [Eq|Hin].
            * now apply self_not_out.
            *{ apply (m_notreserved self caller).
               - apply in_eq.
               - apply InMembers_app; left.
                 rewrite fst_InMembers, translate_param_fst, <-fst_InMembers in Hin; auto.
             }
          + constructor.
            *{ intro Hin.
               apply (m_notreserved out caller).
               - apply in_cons, in_eq.
               - apply InMembers_app; left.
                 rewrite fst_InMembers, translate_param_fst, <-fst_InMembers in Hin; auto.
             }
            * pose proof (m_nodupvars caller) as Nodup.
              apply NoDupMembers_app_l in Nodup.
              rewrite fst_NoDupMembers, translate_param_fst, <-fst_NoDupMembers; auto.
        - unfold var_names.
          rewrite <-NoDup_norepet, <-fst_NoDupMembers.
          subst f; simpl.
          apply NoDupMembers_make_out_vars.
        - subst f; simpl.
          repeat apply list_disjoint_cons_l.
          + apply NoDupMembers_disjoint.
            pose proof (m_nodupvars caller) as Nodup.
            rewrite app_assoc in Nodup.
            apply NoDupMembers_app_l in Nodup.
            rewrite fst_NoDupMembers, map_app, 2translate_param_fst, <-map_app, <-fst_NoDupMembers; auto.
          + unfold var_names; rewrite <-fst_InMembers.
            intro Hin.
            apply (m_notreserved out caller).
            * apply in_cons, in_eq.
            * apply InMembers_app; right; apply InMembers_app; left.
              rewrite fst_InMembers, translate_param_fst, <-fst_InMembers in Hin; auto.
          + unfold var_names; rewrite <-fst_InMembers.
            intro Hin.
            apply (m_notreserved self caller).
            * apply in_eq.
            * apply InMembers_app; right; apply InMembers_app; left.
              rewrite fst_InMembers, translate_param_fst, <-fst_InMembers in Hin; auto.
      Qed.
      
      End MethodProperties.
  End ClassProperties.

  Theorem instance_methods_caract:
    forall ownerid owner prog' callerid caller,
      find_class ownerid prog = Some (owner, prog') ->
      find_method callerid owner.(c_methods) = Some caller ->
      Forall (fun xt => sizeof tge (snd xt) <= Int.modulus /\
                     (exists (id : AST.ident) (co : composite),
                         snd xt = Tstruct id noattr /\
                         gcenv ! id = Some co /\
                         co_su co = Struct /\
                         NoDupMembers (co_members co) /\
                         (forall (x' : AST.ident) (t' : Ctypes.type),
                             In (x', t') (co_members co) ->
                             exists chunk : AST.memory_chunk,
                               access_mode t' = By_value chunk /\
                               (align_chunk chunk | alignof gcenv t'))))
             (make_out_vars (instance_methods caller)).
  Proof.
    intros ** Findcl Findmth.
    induction_list (instance_methods caller) as [|((o, f), k)] with insts; simpl; auto.
    constructor; auto.
    clear IHinsts.
    assert (In (o, f, k) (instance_methods caller)) as Hin
        by (rewrite Hinsts; apply in_app; left; apply in_app; right; apply in_eq).
    edestruct well_formed_instance_methods as (c & cls & callee & Findc & Findcallee); eauto.
    pose proof (find_class_name _ _ _ _ Findc);
      pose proof (find_method_name _ _ _ Findcallee); subst.
    clear Findmth.
    edestruct global_out_struct as (co & Hco & ? & Hmembers & ?); try reflexivity; eauto.
    split.
    * simpl; change (prog_comp_env tprog) with gcenv.
      rewrite Hco.
      unfold co_sizeof. admit.
    *{ exists (prefix_fun (c_name c) (m_name callee)), co.
       repeat split; auto.
       - rewrite Hmembers.
         pose proof (m_nodupvars callee) as Nodup.
         do 2 apply NoDupMembers_app_r in Nodup; auto.
         rewrite fst_NoDupMembers, translate_param_fst, <-fst_NoDupMembers; auto.
       - rewrite Hmembers.
         intros x t Hinxt.
         unfold translate_param in Hinxt.
         apply in_map_iff in Hinxt;
           destruct Hinxt as ((x', t') & Eq & Hinxt); inv Eq.
         destruct t'; simpl.
         + destruct i, s; econstructor; split; eauto.
         + econstructor; split; eauto.
         + destruct f; econstructor; split; eauto.
     }
  Qed.
  
  Lemma type_pres:
    forall c m e, Clight.typeof (translate_exp c m e) = cltype (typeof e).
  Proof.
    induction e as [| |cst| |]; simpl; auto.
    - now case (mem_assoc_ident i (m_out m)). 
    - destruct cst; simpl; reflexivity.
    - destruct u; auto.
  Qed.
  
  Lemma acces_cltype:
    forall t, access_mode (cltype t) = By_value (type_chunk t).
  Proof.
    destruct t;
    (destruct i, s || destruct f || idtac); reflexivity.
  Qed.
  
  Hint Resolve (* sem_cast_same *) wt_val_load_result acces_cltype.
  Hint Constructors wt_stmt.

  Definition c_state := (Clight.env * Clight.temp_env)%type.

  Definition subrep_inst (xbt: ident * (block * Ctypes.type)) :=
    let '(_, (b, t)) := xbt in
    match t with
    | Tstruct id _ =>
      match gcenv ! id with
      | Some co =>
        blockrep gcenv sempty (co_members co) b
      | None => sepfalse
      end
    | _ => sepfalse
    end.

  Definition subrep_inst_env e (xt: ident * Ctypes.type) :=
    let (x, t) := xt in
    match e ! x with
    | Some (b, Tstruct id _ as t') =>
      if (type_eq t t') then
        match gcenv ! id with
        | Some co =>
          blockrep gcenv sempty (co_members co) b
        | None => sepfalse
        end
      else sepfalse
    | _ => sepfalse
    end.
    
  Definition drop_block (xbt: ident * (block * Ctypes.type)) :=
    let '(x, (b, t)) := xbt in
    (x, t).
  
  Definition subrep (f: method) (e: env) :=
    sepall (subrep_inst_env e)
           (make_out_vars (instance_methods f)).

  Lemma subrep_eqv:
    forall f e,
      Permutation (make_out_vars (instance_methods f))
                  (map drop_block (PTree.elements e)) ->
      subrep f e <-*-> sepall subrep_inst (PTree.elements e).
  Proof.
    intros ** Permut.
    unfold subrep.
    rewrite Permut.
    clear Permut.
    induction_list (PTree.elements e) as [|(x, (b, t))] with elems;
      simpl; auto.
    apply sepconj_eqv.
    - assert (e ! x = Some (b, t)) as Hx
          by (apply PTree.elements_complete; rewrite Helems;
              apply in_app; left; apply in_app; right; apply in_eq).
      rewrite Hx; auto.
      destruct t; auto.
      now rewrite type_eq_refl.
    - eapply IHelems; eauto.
  Qed.
  
  Definition range_inst (xbt: ident * (block * Ctypes.type)):=
    let '(x, (b, t)) := xbt in
    range b 0 (Ctypes.sizeof tge t).

  Definition range_inst_env e x :=
    match e ! x with
    | Some (b, t) => range b 0 (Ctypes.sizeof tge t)
    | None => sepfalse
    end.

  Definition subrep_range (e: env) :=
    sepall range_inst (PTree.elements e).
  
  Lemma subrep_range_eqv:
    forall e,
      subrep_range e <-*->
      sepall (range_inst_env e) (map fst (PTree.elements e)).
  Proof.
    intro e.
    unfold subrep_range.
    induction_list (PTree.elements e) as [|(x, (b, t))] with elems; auto; simpl.
    apply sepconj_eqv.
    - unfold range_inst_env.
      assert (In (x, (b, t)) (PTree.elements e)) as Hin
          by (rewrite Helems; apply in_or_app; left; apply in_or_app; right; apply in_eq).
      apply PTree.elements_complete in Hin.
      now rewrite Hin.
    - apply IHelems.
  Qed.

  Remark decidable_footprint_subrep_inst:
    forall x, decidable_footprint (subrep_inst x).
  Proof.
    intros (x, (b, t)).
    simpl; destruct t; auto. now destruct gcenv ! i.
  Qed.

   Lemma decidable_subrep:
    forall f e, decidable_footprint (subrep f e).
  Proof.
    intros.
    unfold subrep.
    induction (make_out_vars (instance_methods f)) as [|(x, t)]; simpl; auto.
    apply decidable_footprint_sepconj; auto.
    destruct (e ! x) as [(b, t')|]; auto.
    destruct t'; auto.
    destruct (type_eq t (Tstruct i a)); auto.
    now destruct (gcenv ! i).
  Qed.
  
  Remark footprint_perm_subrep_inst:
    forall x b lo hi,
      footprint_perm (subrep_inst x) b lo hi.
  Proof.
    intros (x, (b, t)) b' lo hi.
    simpl; destruct t; auto. now destruct gcenv ! i.
  Qed.
  
  Remark disjoint_footprint_range_inst:
    forall l b lo hi,
      ~ InMembers b (map snd l) ->
      disjoint_footprint (range b lo hi) (sepall range_inst l).
  Proof.
    induction l as [|(x, (b', t'))]; simpl;
    intros b lo hi Notin.
    - apply sepemp_disjoint. 
    - rewrite disjoint_footprint_sepconj; split.
      + intros blk ofs Hfp Hfp'.
        apply Notin.
        left.
        simpl in *.
        destruct Hfp', Hfp.
        now transitivity blk.
      + apply IHl.
        intro; apply Notin; now right.
  Qed.
  
  Hint Resolve decidable_footprint_subrep_inst decidable_subrep footprint_perm_subrep_inst.

  Lemma range_wand_equiv:
    forall e,
      Forall (fun xt: ident * Ctypes.type =>
                exists id co,
                  snd xt = Tstruct id noattr
                  /\ gcenv ! id = Some co
                  /\ co_su co = Struct
                  /\ NoDupMembers (co_members co)
                  /\ forall x' t',
                      In (x', t') (co_members co) ->
                      exists chunk : AST.memory_chunk,
                        access_mode t' = By_value chunk /\
                        (align_chunk chunk | alignof gcenv t'))
             (map drop_block (PTree.elements e)) ->
      NoDupMembers (map snd (PTree.elements e)) ->
      subrep_range e <-*->
      sepall subrep_inst (PTree.elements e)
      ** (sepall subrep_inst (PTree.elements e) -* subrep_range e).
  Proof.
    unfold subrep_range.
    intros ** Forall Nodup.
    split.
    2: now (rewrite sep_unwand; auto).
    induction (PTree.elements e) as [|(x, (b, t))]; simpl in *.
    - rewrite <-hide_in_sepwand; auto.
      now rewrite <-sepemp_right.
    - inversion_clear Forall as [|? ? Hidco Forall']; subst;
      rename Forall' into Forall. 
      destruct Hidco as (id & co & Ht & Hco & ? & ? & ?); simpl in Ht.
      inversion_clear Nodup as [|? ? ? Notin Nodup'].
      rewrite Ht, Hco.
      rewrite sep_assoc.
      rewrite IHl at 1; auto.
      rewrite <-unify_distinct_wands; auto.
      + repeat rewrite <-sep_assoc.
        apply sep_imp'; auto.
        rewrite sep_comm, sep_assoc, sep_swap.
        apply sep_imp'; auto.
        simpl range_inst.
        rewrite <-range_imp_with_wand; auto.
        simpl.
        change ((prog_comp_env tprog) ! id) with (gcenv ! id).
        rewrite Hco.
        eapply blockrep_empty; eauto.
      + now apply disjoint_footprint_range_inst. 
      + simpl. change ((prog_comp_env tprog) ! id) with (gcenv ! id); rewrite Hco.
        rewrite blockrep_empty; eauto.
        reflexivity.
      + apply subseteq_footprint_sepall.
        intros (x', (b', t')) Hin; simpl.
        assert (In (x', t') (map drop_block l))
          by (change (x', t') with (drop_block (x', (b', t'))); apply in_map; auto).
        eapply In_Forall in Forall; eauto.
        simpl in Forall.
        destruct Forall as (id' & co' & Ht' & Hco' & ? & ? & ?).
        rewrite Ht', Hco'. simpl.
        change ((prog_comp_env tprog) ! id') with (gcenv ! id').
        rewrite Hco'.        
        rewrite blockrep_empty; eauto.
        reflexivity.
  Qed.
  
  Definition varsrep (f: method) (ve: stack) (le: temp_env) :=
    pure (Forall (fun (xty: ident * Ctypes.type) =>
                    let (x, _) := xty in
                    match le ! x with
                    | Some v => match_value ve x v
                    | None => False
                    end) (map translate_param (f.(m_in) ++ f.(m_vars)))).

  Definition match_states
             (c: class) (f: method) (S: heap * stack) (CS: c_state)
             (sb: block) (sofs: int) (outb: block) (outco: composite): massert :=
    let (e, le) := CS in
    let (me, ve) := S in
    pure (wt_env ve (meth_vars f))
    ** pure (wt_mem me prog c)
    ** pure (le ! self = Some (Vptr sb sofs))
    ** pure (le ! out = Some (Vptr outb Int.zero))
    ** pure (gcenv ! (prefix_fun c.(c_name) f.(m_name)) = Some outco)
    ** pure (forall x b t, e ! x = Some (b, t) -> exists o f, x = prefix_out o f)
    ** pure (0 <= Int.unsigned sofs)
    ** staterep gcenv prog c.(c_name) me sb (Int.unsigned sofs)
    ** blockrep gcenv ve outco.(co_members) outb
    ** subrep f e
    ** varsrep f ve le
    ** (subrep f e -* subrep_range e).

  Lemma match_states_conj:
    forall c f me ve e le m sb sofs outb outco P,
      m |= match_states c f (me, ve) (e, le) sb sofs outb outco ** P <->
      m |= staterep gcenv prog c.(c_name) me sb (Int.unsigned sofs)
          ** blockrep gcenv ve outco.(co_members) outb
          ** subrep f e
          ** varsrep f ve le
          ** (subrep f e -* subrep_range e)
          ** P
      /\ wt_env ve (meth_vars f)
      /\ wt_mem me prog c
      /\ le ! self = Some (Vptr sb sofs)
      /\ le ! out = Some (Vptr outb Int.zero)
      /\ gcenv ! (prefix_fun c.(c_name) f.(m_name)) = Some outco
      /\ (forall x b t, e ! x = Some (b, t) -> exists o f, x = prefix_out o f)
      /\ 0 <= Int.unsigned sofs.
  Proof.
    unfold match_states; split; intros ** H.
    - repeat rewrite sep_assoc in H; repeat rewrite sep_pure in H; tauto.
    - repeat rewrite sep_assoc; repeat rewrite sep_pure; tauto. 
  Qed.
  
  Remark existsb_In:
    forall f x ty,
      existsb (fun out => ident_eqb (fst out) x) f.(m_out) = true ->
      In (x, ty) (meth_vars f) ->
      In (x, ty) f.(m_out).
  Proof.
    intros ** E ?.
    apply existsb_exists in E.
    destruct E as ((x' & ty') & Hin & E).
    rewrite ident_eqb_eq in E; simpl in E; subst.
    pose proof (m_nodupvars f) as Nodup.
    assert (In (x, ty') (meth_vars f))
      by (now apply in_or_app; right; apply in_or_app; right).
    now app_NoDupMembers_det.
  Qed.

  Remark not_existsb_In:
    forall f x ty,
      existsb (fun out => ident_eqb (fst out) x) f.(m_out) = false ->
      ~ In (x, ty) f.(m_out).
  Proof.
    intros ** E Hin.
    apply not_true_iff_false in E.
    apply E.
    apply existsb_exists.
    exists (x, ty); split; auto; simpl.
    apply ident_eqb_refl.
  Qed.

  Remark not_existsb_InMembers:
    forall f x ty,
      existsb (fun out => ident_eqb (fst out) x) f.(m_out) = false ->
      In (x, ty) (meth_vars f) ->
      ~ InMembers x f.(m_out).
  Proof.
    intros ** E ? Hin.
    apply not_true_iff_false in E.
    apply E.
    apply existsb_exists.
    exists (x, ty); split; simpl.
    - apply InMembers_In in Hin.
      destruct Hin as [ty' Hin].
      assert (In (x, ty') (meth_vars f))
        by (now apply in_or_app; right; apply in_or_app; right).
      pose proof (m_nodupvars f). 
      now app_NoDupMembers_det.
    - apply ident_eqb_refl.
  Qed.

  Section ExprCorrectness.
    Variables (ownerid: ident) (owner: class) (prog': program) (callerid: ident) (caller: method).
    Hypothesis Findcl: find_class ownerid prog = Some (owner, prog'). 
    Hypothesis Findmth: find_method callerid owner.(c_methods) = Some caller.

    Section OutField.
      Variables (m: Mem.mem) (ve: stack) (outco: composite) (outb: block) (P: massert)
                (le: temp_env) (x: ident) (ty: type).
      Hypothesis Hrep: m |= blockrep gcenv ve outco.(co_members) outb ** P.
      Hypothesis Get_out: le ! out = Some (Vptr outb Int.zero).
      Hypothesis Get_outco: gcenv ! (prefix_fun (c_name owner) (m_name caller)) = Some outco.
      Hypothesis Hin: In (x, ty) (meth_vars caller).
      
      Lemma evall_out_field:
        forall e,      
          existsb (fun out => ident_eqb (fst out) x) caller.(m_out) = true ->
          exists d,
            eval_lvalue tge e le m (deref_field out (prefix_fun (c_name owner) (m_name caller)) x (cltype ty))
                        outb (Int.add Int.zero (Int.repr d))
            /\ field_offset gcenv x (co_members outco) = Errors.OK d.
      Proof.
        intros ** E.
        eapply existsb_In in E; eauto.
        apply in_map with (f:=translate_param) in E.
        erewrite output_match in E; eauto.  
        edestruct blockrep_field_offset as (d & Hoffset & ?); eauto.
        exists d; split; auto.
        eapply eval_Efield_struct; eauto.
        - eapply eval_Elvalue; eauto.
          now apply deref_loc_copy.
        - simpl; unfold type_of_inst; eauto.
      Qed.
      
      Lemma eval_out_field:
        forall e v,
          mem_assoc_ident x (m_out caller) = true ->
          PM.find x ve = Some v ->
          eval_expr tge e le m (deref_field out (prefix_fun (c_name owner) (m_name caller)) x (cltype ty)) v.
      Proof.
        intros.
        edestruct evall_out_field with (e:=e) as (? & ? & ?); eauto.
        eapply eval_Elvalue; eauto.
        rewrite Int.add_zero_l.
        eapply blockrep_deref_mem; eauto.
        erewrite <-output_match; eauto.
        rewrite in_map_iff.
        exists (x, ty); split; auto.
        apply existsb_In; auto.
      Qed.
    End OutField.

    Lemma eval_temp_var:
      forall ve e le m x ty v P,
        m |= varsrep caller ve le ** P ->
        In (x, ty) (meth_vars caller) ->
        mem_assoc_ident x (m_out caller) = false ->
        PM.find x ve = Some v ->
        eval_expr tge e le m (Etempvar x (cltype ty)) v.
    Proof.
      intros ** Hrep Hvars E ?.
      apply sep_proj1, sep_pure' in Hrep.
      apply eval_Etempvar.
      assert (~ In (x, ty) caller.(m_out)) as HnIn.
      { apply not_true_iff_false in E.
        intro Hin; apply E.
        apply existsb_exists.
        exists (x, ty); split; auto.
        apply ident_eqb_refl. 
      }
      unfold meth_vars in Hvars.
      rewrite app_assoc in Hvars.
      eapply not_In_app in HnIn; eauto.
      apply in_map with (f:=translate_param) in HnIn.
      eapply In_Forall in Hrep; eauto.
      simpl in Hrep.
      destruct (le ! x);
        [now app_match_find_var_det | contradiction].
    Qed.

    Section SelfField.
      Variables (m: Mem.mem) (me: heap) (outco: composite) (sb: block) (sofs: Int.int) (P: massert)
                (le: temp_env) (x: ident) (ty: type).
      Hypothesis Hrep: m |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs) ** P.
      Hypothesis Hsofs: 0 <= Int.unsigned sofs.
      Hypothesis Get_self: le ! self = Some (Vptr sb sofs).
      Hypothesis Hmems: In (x, ty) owner.(c_mems).
      
      Lemma evall_self_field:
      forall e, exists d,
          eval_lvalue tge e le m (deref_field self (c_name owner) x (cltype ty))
                      sb (Int.add sofs (Int.repr d))
          /\ field_offset gcenv x (make_members owner) = Errors.OK d
          /\ 0 <= d <= Int.max_unsigned.
      Proof.
        intros.
        pose proof (find_class_name _ _ _ _ Findcl); subst.
        edestruct make_members_co as (? & Hco & ? & Eq & ? & ?); eauto.  
        rewrite staterep_skip in Hrep; eauto.
        edestruct staterep_field_offset as (d & ? & ?); eauto.
        exists d; split; [|split]; auto.
        - eapply eval_Efield_struct; eauto.
          + eapply eval_Elvalue; eauto.
            now apply deref_loc_copy.
          + simpl; unfold type_of_inst; eauto.
          + now rewrite Eq. 
        - split.
          + eapply field_offset_in_range'; eauto.
          + omega. 
      Qed.
  
      Lemma eval_self_field:
        forall e v,
          mfind_mem x me = Some v ->
          access_mode (cltype ty) = By_value (type_chunk ty) ->
          eval_expr tge e le m (deref_field self (c_name owner) x (cltype ty)) v.
      Proof.
        intros. 
        edestruct evall_self_field as (? & ? & Hoffset & (? & ?)); eauto.
        eapply eval_Elvalue; eauto.
        rewrite staterep_skip in Hrep; eauto.
        eapply staterep_deref_mem; eauto.
        rewrite Int.unsigned_repr; auto.
      Qed.

      Lemma eval_self_inst:
        forall e o c',
          In (o, c') (c_objs owner) ->
          exists d,
            eval_expr tge e le m (ptr_obj owner.(c_name) c' o) (Vptr sb (Int.add sofs (Int.repr d)))
            /\ field_offset gcenv o (make_members owner) = Errors.OK d
            /\ 0 <= Int.unsigned sofs + d <= Int.max_unsigned.
      Proof.
        intros ** Hin.
        pose proof (find_class_name _ _ _ _ Findcl); subst.
        edestruct make_members_co as (? & Hco & ? & Eq & ? & ?); eauto. 
        rewrite staterep_skip in Hrep; eauto.
        edestruct staterep_inst_offset as (d & ? & ?); eauto.
        exists d; split; [|split]; auto.
        apply eval_Eaddrof.
        eapply eval_Efield_struct; eauto.
        - eapply eval_Elvalue; eauto.
          now apply deref_loc_copy. 
        - simpl; unfold type_of_inst; eauto.
        - now rewrite Eq.
      Qed.
    End SelfField.

    Lemma evall_inst_field:
      forall x ty e le m o oblk instco ve P,
        m |= blockrep gcenv ve instco.(co_members) oblk ** P ->
        e ! o = Some (oblk, type_of_inst (prefix_fun ownerid callerid)) ->
        gcenv ! (prefix_fun ownerid callerid) = Some instco ->
        In (x, ty) caller.(m_out) ->
        exists d,
          eval_lvalue tge e le m (Efield (Evar o (type_of_inst (prefix_fun ownerid callerid))) x (cltype ty)) 
                      oblk (Int.add Int.zero (Int.repr d))
          /\ field_offset tge x instco.(co_members) = Errors.OK d
          /\ 0 <= d <= Int.max_unsigned.
    Proof.
      intros ** Hin.

      pose proof (find_class_name _ _ _ _ Findcl);
        pose proof (find_method_name _ _ _ Findmth); subst.
      apply in_map with (f:=translate_param) in Hin.
      erewrite output_match in Hin; eauto.

      edestruct blockrep_field_offset as (d & Hoffset & ?); eauto.
      exists d; split; [|split]; auto.
      eapply eval_Efield_struct; eauto.
      + eapply eval_Elvalue; eauto.
        now apply deref_loc_copy.
      + simpl; unfold type_of_inst; eauto.
    Qed.

    Lemma pres_sem_exp':
      forall c vars me ve e v,
        wt_mem me prog c ->
        wt_env ve vars ->
        wt_exp c.(c_mems) vars e ->
        exp_eval me ve e v ->
        wt_val v (typeof e).
    Proof.
      intros ** WT_mem ? ? ?.
      inv WT_mem.
      eapply pres_sem_exp with (vars:=vars); eauto.
    Qed.
    Hint Resolve pres_sem_exp'.    
    
    Lemma expr_eval_simu:
      forall me ve e le m sb sofs outb outco P ex v,
        m |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs)
            ** blockrep gcenv ve outco.(co_members) outb
            ** subrep caller e
            ** varsrep caller ve le
            ** P ->
        wt_env ve (meth_vars caller) ->
        wt_mem me prog owner ->
        le ! self = Some (Vptr sb sofs) ->
        le ! out = Some (Vptr outb Int.zero) ->
        gcenv ! (prefix_fun owner.(c_name) caller.(m_name)) = Some outco ->
        0 <= Int.unsigned sofs ->
        wt_exp owner.(c_mems) (meth_vars caller) ex ->
        exp_eval me ve ex v ->
        Clight.eval_expr tge e le m (translate_exp owner caller ex) v.
    Proof.
      intros ** Hrep ? ? ? ? ? ? WF EV;
      revert v EV; induction ex as [x| |cst|op|]; intros v EV;
      inv EV; inv WF.

      (* Var x ty : "x" *)
      - simpl; destruct (mem_assoc_ident x caller.(m_out)) eqn:E.
        + rewrite sep_swap in Hrep.
          eapply eval_out_field; eauto.
        + rewrite sep_swap4 in Hrep.
          eapply eval_temp_var; eauto.

      (* State x ty : "self->x" *)
      - eapply eval_self_field; eauto.
        
      (* Const c ty : "c" *)
      - destruct cst; constructor.

      (* Unop op e ty : "op e" *)
      - destruct op; simpl in *; econstructor; eauto.
        + rewrite type_pres.
          erewrite sem_unary_operation_any_mem; eauto.
<<<<<<< HEAD
          eapply wt_val_not_vundef_nor_vptr; eauto. 
=======
          admit.
>>>>>>> some modifs
        + rewrite type_pres.
          admit.                (* problème annotation Cast *)

      (* Binop op e1 e2 : "e1 op e2" *)
      - simpl in *. unfold translate_binop.
        econstructor; eauto.
        rewrite 2 type_pres.
<<<<<<< HEAD
        erewrite sem_binary_operation_any_cenv_mem; eauto;
        eapply wt_val_not_vundef_nor_vptr; eauto.
=======
        erewrite sem_binary_operation_any_cenv_mem; eauto.
        admit. admit.
>>>>>>> some modifs
    Qed.

    Lemma exp_eval_valid_s:
      forall c vars me ve es vs,
        wt_mem me prog c ->
        wt_env ve vars ->
        Forall (wt_exp c.(c_mems) vars) es ->
        Forall2 (exp_eval me ve) es vs ->
        Forall2 (fun e v => wt_val v (typeof e)) es vs.
    Proof.
      induction es, vs; intros ** Wt Ev; inv Wt; inv Ev; eauto.
    Qed.

  (* Lemma exp_eval_access: *)
  (*   forall me ve e v vars mems, *)
  (*     wt_env me.(mm_values) mems -> *)
  (*     wt_env ve vars -> *)
  (*     wt_exp mems vars e -> *)
  (*     exp_eval me ve e v -> *)
  (*     access_mode (cltype (typeof e)) = By_value (type_chunk (typeof e)). *)
  (* Proof. *)
  (*   eauto. *)
  (*   intros ** H. *)
  (*   eapply pres_sem_exp in H; eauto. *)
  (*   apply exp_eval_valid in H. *)
  (*   apply H. *)
  (* Qed. *)

  (* Lemma exp_eval_access_s: *)
  (*  forall S es vs, *)
  (*    Forall2 (exp_eval S) es vs -> *)
  (*    Forall (fun e => access_mode (typeof e) = By_value (type_chunk (typeof e))) es. *)
  (* Proof. *)
  (*   induction es, vs; intros ** H; inv H; auto. *)
  (*   constructor. *)
  (*   - eapply exp_eval_access; eauto. *)
  (*   - eapply IHes; eauto. *)
  (* Qed. *)
    
    Lemma exp_eval_lr:
      forall c vars me ve e v,
        wt_mem me prog c ->
        wt_env ve vars ->
        wt_exp c.(c_mems) vars e ->
        exp_eval me ve e v ->
        v = Val.load_result (type_chunk (typeof e)) v.
    Proof.
      intros.
      apply wt_val_load_result; eauto.
    Qed.

  (* Lemma exp_eval_lr_s: *)
  (*  forall S es vs, *)
  (*    Forall2 (exp_eval S) es vs -> *)
  (*    Forall2 (fun e v => v = Val.load_result (type_chunk (typeof e)) v) es vs. *)
  (* Proof. *)
  (*   induction es, vs; intros ** H; inv H; auto. *)
  (*   constructor. *)
  (*   - eapply exp_eval_lr; eauto. *)
  (*   - now apply IHes. *)
  (* Qed. *)
  
   (* exp_eval_access *)
       (* exp_eval_valid_s exp_eval_access_s exp_eval_lr *)

  Lemma exprs_eval_simu:
      forall me ve es es' vs e le m sb sofs outb outco P,
        m |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs)
            ** blockrep gcenv ve outco.(co_members) outb
            ** subrep caller e
            ** varsrep caller ve le
            ** P ->
        wt_env ve (meth_vars caller) ->
        wt_mem me prog owner ->
        le ! self = Some (Vptr sb sofs) ->
        le ! out = Some (Vptr outb Int.zero) ->
        gcenv ! (prefix_fun owner.(c_name) caller.(m_name)) = Some outco ->
        0 <= Int.unsigned sofs ->
        Forall (wt_exp owner.(c_mems) (meth_vars caller)) es ->
        Forall2 (exp_eval me ve) es vs ->
        es' = map (translate_exp owner caller) es ->
        Clight.eval_exprlist tge e le m es'
                             (list_type_to_typelist (map Clight.typeof es')) vs.
    Proof.
      Hint Constructors Clight.eval_exprlist.
      intros ** WF EV ?; subst es';
        induction EV; inv WF; econstructor;
        ((eapply expr_eval_simu; eauto) || (rewrite type_pres; apply sem_cast_same; eauto) || auto).
    Qed.
  End ExprCorrectness.

  Hint Resolve pres_sem_exp' expr_eval_simu exp_eval_lr exp_eval_valid_s.
  
  Remark eval_exprlist_app:
    forall e le m es es' vs vs',
      Clight.eval_exprlist tge e le m es
                           (list_type_to_typelist (map Clight.typeof es)) vs ->
      Clight.eval_exprlist tge e le m es'
                           (list_type_to_typelist (map Clight.typeof es')) vs' ->
      Clight.eval_exprlist tge e le m (es ++ es')
                           (list_type_to_typelist (map Clight.typeof (es ++ es'))) (vs ++ vs').
  Proof.
    induction es; intros ** Ev Ev'; inv Ev; auto.
    repeat rewrite <-app_comm_cons.
    simpl; econstructor; eauto.
  Qed.

  Lemma varsrep_corres_out:
    forall f ve le x t v,
      In (x, t) (m_out f) ->
      varsrep f ve le -*> varsrep f (PM.add x v ve) le.
  Proof.
    intros ** Hin.
    unfold varsrep.
    rewrite pure_imp.
    intro Hforall.
    assert (~InMembers x (f.(m_in) ++ f.(m_vars))) as Notin.
    { pose proof (m_nodupvars f) as Nodup.
      rewrite app_assoc in Nodup.
      rewrite NoDupMembers_app_assoc in Nodup.
      apply In_InMembers in Hin.
      eapply NoDupMembers_app_InMembers; eauto.
    }
    induction (m_in f ++ m_vars f) as [|(x', t')]; simpl in *; eauto.
    inv Hforall.
    constructor.
    - destruct le ! x'; auto.
      rewrite match_value_add; auto.
    - apply IHl; auto.
  Qed.

  Section MatchStatesAssign.
    Variables (ownerid: ident) (owner: class) (prog': program) (callerid: ident) (caller: method).
    Hypothesis Findcl: find_class ownerid prog = Some (owner, prog'). 
    Hypothesis Findmth: find_method callerid owner.(c_methods) = Some caller.

    Section OutField.
      Variables (m: Mem.mem) (ve: stack) (outco: composite) (outb: block) (P: massert)
                (le: temp_env) (x: ident) (ty: type).
      Hypothesis Hrep: m |= varsrep caller ve le ** blockrep gcenv ve outco.(co_members) outb ** P.
      Hypothesis Hco: gcenv ! (prefix_fun (c_name owner) (m_name caller)) = Some outco.
      Hypothesis Hvars: In (x, ty) (meth_vars caller).

      Lemma match_states_assign_out:
        forall v d,
          field_offset gcenv x (co_members outco) = Errors.OK d ->
          access_mode (cltype ty) = By_value (type_chunk ty) ->
          v = Values.Val.load_result (type_chunk ty) v ->
          mem_assoc_ident x (m_out caller) = true ->
          exists m', Memory.Mem.storev (type_chunk ty) m (Vptr outb (Int.repr d)) v = Some m'
                /\ m' |= varsrep caller (PM.add x v ve) le
                     ** blockrep gcenv (PM.add x v ve) outco.(co_members) outb ** P .
      Proof.
        intros ** Hoffset Haccess Hlr E.

        unfold mem_assoc_ident in E; eapply existsb_In in E; eauto.
        pose proof (output_match _ _ _ Findcl _ _ Findmth _ Hco) as Eq.
        pose proof E as Hin; apply in_map with (f:=translate_param) in Hin;
        rewrite Eq in Hin; eauto.
        pose proof (m_nodupvars caller) as Nodup.
        
        (* get the updated memory *)
        apply sepall_in in Hin.
        destruct Hin as [ws [ys [Hys Heq]]].
        unfold blockrep in Hrep.
        rewrite Heq in Hrep; simpl in *.
        rewrite Hoffset, Haccess, sep_assoc, sep_swap in Hrep.
        eapply Separation.storev_rule' with (v:=v) in Hrep; eauto.
        destruct Hrep as (m' & ? & Hrep'); clear Hrep; rename Hrep' into Hrep.
        exists m'; split; auto.
        unfold blockrep.
        rewrite Heq, Hoffset, Haccess, sep_assoc.
        rewrite sep_swap in Hrep.
        eapply sep_imp; eauto.
        - eapply varsrep_corres_out; eauto.
        - apply sep_imp'.
          + unfold hasvalue.
            unfold match_value; simpl.
            rewrite PM.gss.
            now rewrite <-Hlr.
          + do 2 apply NoDupMembers_app_r in Nodup.
            rewrite fst_NoDupMembers, <-translate_param_fst, <-fst_NoDupMembers in Nodup; auto.
            rewrite Eq, Hys in Nodup.
            apply NoDupMembers_app_cons in Nodup.
            destruct Nodup as (Notin & Nodup).
            rewrite sepall_swapp; eauto.  
            intros (x' & t') Hin.
            rewrite match_value_add; auto.
            intro; subst x'.
            apply Notin.
            eapply In_InMembers; eauto.
      Qed.
      
      Lemma match_states_assign_tempvar:
        forall v,
          mem_assoc_ident x (m_out caller) = false ->
          m |= varsrep caller (PM.add x v ve) (PTree.set x v le)
            ** blockrep gcenv (PM.add x v ve) outco.(co_members) outb ** P.
      Proof.
        intros ** E.
        pose proof (output_match _ _ _ Findcl _ _ Findmth _ Hco) as Eq_outco.
        unfold varsrep in *.
        rewrite sep_pure in *. 
        destruct Hrep as (Hpure & Hrep'); clear Hrep; rename Hrep' into Hrep;
        split; auto.
        - induction (m_in caller ++ m_vars caller); simpl in *; auto.
          inv Hpure; constructor; destruct (translate_param a) as (x' & t').
          + destruct (ident_eqb x' x) eqn: Eq.
            * apply ident_eqb_eq in Eq.
              subst x'.
              rewrite PTree.gss.
              unfold match_value.
              now rewrite PM.gss.
            * apply ident_eqb_neq in Eq.
              rewrite PTree.gso; auto.
              now rewrite match_value_add.
          + now apply IHl.
        - eapply sep_imp; eauto.
          unfold blockrep in *.
          rewrite sepall_swapp; eauto.
          intros (x', t') Hx'.
          rewrite match_value_add; auto.
          unfold mem_assoc_ident in E; eapply not_existsb_InMembers in E; eauto.
          apply In_InMembers in Hx'.
          intro Hxx'; subst x.
          apply E.
          rewrite fst_InMembers, <-translate_param_fst, <-fst_InMembers; auto.
          now rewrite Eq_outco.
      Qed.
    End OutField.

    Lemma match_states_assign_state:
      forall m me sb sofs P x ty v d,
        m |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs) ** P ->
        In (x, ty) owner.(c_mems) ->
        field_offset gcenv x (make_members owner) = Errors.OK d ->
        v = Values.Val.load_result (type_chunk ty) v ->
        exists m',
          Memory.Mem.storev (type_chunk ty) m (Vptr sb (Int.repr (Int.unsigned sofs + d))) v = Some m'
          /\ m' |= staterep gcenv prog owner.(c_name) (madd_mem x v me) sb (Int.unsigned sofs) ** P.
    Proof.
      intros ** Hrep Hmems Hoffset Hlr.
      
      (* get the updated memory *)
      apply sepall_in in Hmems.
      destruct Hmems as [ws [ys [Hys Heq]]].
      rewrite staterep_skip in Hrep; eauto.
      simpl staterep in Hrep.
      unfold staterep_mems in Hrep.
      rewrite ident_eqb_refl, Heq, Hoffset in Hrep.
      rewrite 2 sep_assoc in Hrep.
      eapply Separation.storev_rule' with (v:=v) in Hrep; eauto.
      destruct Hrep as (m' & ? & Hrep).
      exists m'; split; auto.
      rewrite staterep_skip; eauto.
      simpl staterep.
      unfold staterep_mems.
      rewrite ident_eqb_refl, Heq, Hoffset.
      rewrite 2 sep_assoc.
      eapply sep_imp; eauto.
      - unfold hasvalue.
        unfold match_value; simpl.
        rewrite PM.gss.
        now rewrite <-Hlr.
      - apply sep_imp'; auto.
        pose proof (c_nodupmems owner) as Nodup.
        rewrite Hys in Nodup.
        apply NoDupMembers_app_cons in Nodup.
        destruct Nodup as (Notin & Nodup).        
        rewrite sepall_swapp; eauto. 
        intros (x' & t') Hin.
        unfold madd_mem; simpl.
        rewrite match_value_add; auto.
        intro; subst x'.
        apply Notin.
        eapply In_InMembers; eauto.
    Qed.
        
    Lemma exec_funcall_assign:
      forall callee ys e1 le1 m1 c prog' o f clsid
        ve ve' sb sofs outb outco rvs binst instco P,  
        find_class clsid prog = Some (c, prog') ->
        find_method f c.(c_methods) = Some callee ->
        NoDup ys ->
        Forall2 (fun y xt => In (y, snd xt) (meth_vars caller)) ys
                callee.(m_out) ->
        le1 ! out = Some (Vptr outb Int.zero) ->
        le1 ! self = Some (Vptr sb sofs) ->
        gcenv ! (prefix_fun (c_name owner) (m_name caller)) = Some outco ->
        m1 |= blockrep gcenv (adds (map fst callee.(m_out)) rvs ve') instco.(co_members) binst
             ** blockrep gcenv ve outco.(co_members) outb
             ** varsrep caller ve le1
             ** P ->                                       
        Forall2 (fun v y => wt_val v (snd y)) rvs callee.(m_out) ->
        e1 ! (prefix_out o f) = Some (binst, type_of_inst (prefix_fun clsid f)) ->
        gcenv ! (prefix_fun clsid f) = Some instco ->
        exists le2 m2 T,
          exec_stmt tge (function_entry2 tge) e1 le1 m1
                    (funcall_assign ys owner.(c_name) caller (prefix_out o f)
                                                      (type_of_inst (prefix_fun clsid f)) callee)
                    T le2 m2 Out_normal
          /\ m2 |= blockrep gcenv (adds (map fst callee.(m_out)) rvs ve') instco.(co_members) binst
                 ** blockrep gcenv (adds ys rvs ve) outco.(co_members) outb
                 ** varsrep caller (adds ys rvs ve) le2
                 ** P
          /\ le2 ! out = Some (Vptr outb Int.zero) 
          /\ le2 ! self = Some (Vptr sb sofs). 
    Proof.
      unfold funcall_assign.
      intros ** Findc Findcallee Nodup Incl
             Hout Hself Houtco Hrep Valids Hinst Hinstco.
      assert (length ys = length callee.(m_out)) as Length1
          by (eapply Forall2_length; eauto).
      assert (length rvs = length callee.(m_out)) as Length2
          by (eapply Forall2_length; eauto).
      revert ve ve' le1 m1 ys rvs Hout Hself Hrep Incl Length1 Length2 Nodup Valids.
      pose proof (m_nodupvars callee) as Nodup'.
      do 2 apply NoDupMembers_app_r in Nodup'.
      induction_list (m_out callee) as [|(y', ty)] with outs; intros;
      destruct ys as [|y], rvs; try discriminate.
      - exists le1, m1, E0; split; auto.
        apply exec_Sskip.
      - inv Length1; inv Length2; inv Nodup; inv Nodup'.    
        inversion_clear Incl as [|? ? ? ? Hvars Incl'];
          rename Incl' into Incl; simpl in Hvars.
        inversion_clear Valids as [|? ? ? ? Valid Valids'];
          rename Valids' into Valids; simpl in Valid.

        pose proof (find_class_name _ _ _ _ Findc) as Eq.
        pose proof (find_method_name _ _ _ Findcallee) as Eq'.

        rewrite <-Eq, <-Eq' in Hinstco.
        pose proof (output_match _ _ _ Findc _ _ Findcallee _ Hinstco) as Eq_instco.
        pose proof (output_match _ _ _ Findcl _ _ Findmth _ Houtco) as Eq_outco. 
        
        (* get the o.y' value evaluation *)
        assert (In (y', ty) callee.(m_out)) as Hin
            by (rewrite Houts; apply in_or_app; left; apply in_or_app; right; apply in_eq).
        rewrite Eq, Eq' in Hinstco.
        edestruct (evall_inst_field _ _ _ _ _ Findc Findcallee y' ty e1 le1) as
            (dy' & Ev_o_y' & Hoffset_y' & ?); eauto.
        assert (eval_expr tge e1 le1 m1
                          (Efield (Evar (prefix_out o f)
                                        (type_of_inst (prefix_fun clsid f))) y' (cltype ty)) v).
        { eapply eval_Elvalue; eauto.
          eapply blockrep_deref_mem; eauto.
          - rewrite <-Eq, <-Eq' in Hinstco.
            apply in_map with (f:=translate_param) in Hin.
            erewrite output_match in Hin; eauto.
          - unfold adds; simpl.
            apply PM.gss.
          - rewrite Int.unsigned_zero; simpl.
            rewrite Int.unsigned_repr; auto.
        }    
        unfold assign.
        simpl fold_right.
        destruct (mem_assoc_ident y (m_out caller)) eqn: E.
        
        (* out->y = o.y' *)
        + (* get the 'out' variable left value evaluation *)
          rewrite sep_swap in Hrep.
          edestruct evall_out_field with (1:=Findcl) (e:=e1)
            as (dy & Ev_out_y & Hoffset_y); eauto.  
          
          (* get the updated memory *)
          rewrite sep_swap23, sep_swap in Hrep.
          edestruct match_states_assign_out with (v:=v)
            as (m2 & Store & Hm2); eauto.
          
          edestruct IHouts with (m1:=m2) (ve:= PM.add y v ve) (ve':=PM.add y' v ve')
            as (le' & m' & T' & Exec & Hm' & ? & ?); eauto.
          * rewrite sep_swap3.
            simpl in Hm2.
            rewrite adds_cons_cons in Hm2; auto.
            rewrite <-fst_InMembers; auto.
            
          *{ clear IHouts.            
             do 3 econstructor; split; [|split; [|split]]; eauto.
             - eapply exec_Sseq_1 with (m1:=m2); eauto.
               eapply ClightBigstep.exec_Sassign; eauto.
               eapply sem_cast_same; eauto.
               eapply assign_loc_value; eauto.
               + eapply acces_cltype; eauto.
               + rewrite Int.add_zero_l; auto. 
             - simpl; repeat rewrite adds_cons_cons; auto; rewrite <-fst_InMembers; auto.
           }
           
        (* y = o.y' *)
        + edestruct IHouts with (m1:=m1) (le1:=PTree.set y v le1) (ve:= PM.add y v ve) (ve':=PM.add y' v ve')
            as (le' & m' & T' & Exec & Hm' & ? & ?); eauto.
          *{ rewrite PTree.gso; auto.
             intro Heq.
             apply (m_notreserved out caller).
             - apply in_cons, in_eq.
             - subst y. apply In_InMembers in Hvars; auto.
           }
          *{ rewrite PTree.gso; auto.
             intro Heq.
             apply (m_notreserved self caller).
             - apply in_eq.
             - subst y. apply In_InMembers in Hvars; auto.
           }
          *{ rewrite sep_swap3 in *.
             simpl in Hrep.
             rewrite adds_cons_cons in Hrep; auto.
             - eapply match_states_assign_tempvar; eauto.
             - rewrite <-fst_InMembers; auto.
           }
          *{ clear IHouts.
             do 3 econstructor; split; [|split; [|split]]; eauto.
             - eapply exec_Sseq_1; eauto.
               apply ClightBigstep.exec_Sset; auto.
             - simpl; repeat rewrite adds_cons_cons; auto; rewrite <-fst_InMembers; auto.
           }
    Qed.
  End MatchStatesAssign.

  Theorem set_comm:
    forall {A} x x' (v v': A) m,
      x <> x' ->
      PTree.set x v (PTree.set x' v' m) = PTree.set x' v' (PTree.set x v m).
  Proof.
    induction x, x', m; simpl; intro Neq;
    ((f_equal; apply IHx; intro Eq; apply Neq; now inversion Eq) || now contradict Neq).
  Qed.
  
  Remark bind_parameter_temps_cons:
    forall x t xs v vs le le',
      bind_parameter_temps ((x, t) :: xs) (v :: vs) le = Some le' ->
      list_norepet (var_names ((x, t) :: xs)) ->
      PTree.get x le' = Some v.
  Proof.
    induction xs as [|[x' t']]; destruct vs;
    intros ** Bind Norep; inversion Bind as [Bind'].
    - apply PTree.gss.
    - inversion_clear Norep as [|? ? Notin Norep'].
      apply not_in_cons in Notin; destruct Notin as [? Notin].
      eapply IHxs; eauto.
      + simpl.
        erewrite set_comm in Bind'; eauto.
      + constructor.
        * apply Notin.
        * inversion_clear Norep' as [|? ? ? Norep''].
          apply Norep''.
  Qed.

  Remark bind_parameter_temps_comm:
    forall xs vs s ts o to vself vout x t v le le',
      x <> o ->
      x <> s ->
      (bind_parameter_temps ((s, ts) :: (o, to) :: (x, t) :: xs) (vself :: vout :: v :: vs) le = Some le' <->
      bind_parameter_temps ((x, t) :: (s, ts) :: (o, to) :: xs) (v :: vself :: vout :: vs) le = Some le').
  Proof.
    destruct xs as [|(y, ty)], vs; split; intros ** Bind; inv Bind; simpl.
    - f_equal. rewrite (set_comm s x); auto.
      apply set_comm; auto.
    - f_equal. rewrite (set_comm x o); auto.
      f_equal. apply set_comm; auto.
    - do 2 f_equal. rewrite (set_comm s x); auto.
      apply set_comm; auto.
    - do 2 f_equal. rewrite (set_comm x o); auto.
      f_equal. apply set_comm; auto.
  Qed.
  
  Remark bind_parameter_temps_implies':
    forall xs vs s ts vself o to vout le le',
      s <> o ->
      ~ InMembers s xs ->
      ~ InMembers o xs ->
      bind_parameter_temps ((s, ts) :: (o, to) :: xs)
                           (vself :: vout :: vs) le = Some le' ->
      PTree.get s le' = Some vself /\ PTree.get o le' = Some vout.
  Proof.
    induction xs as [|(x', t')]; destruct vs;
    intros ** Neq Notin_s Notin_o Bind.
    - inv Bind.
      split.
      + now rewrite PTree.gso, PTree.gss.
      + now rewrite PTree.gss.
    - inv Bind.
    - inv Bind.
    - rewrite bind_parameter_temps_comm in Bind.
      + remember ((s, ts)::(o, to)::xs) as xs' in Bind.
        remember (vself::vout::vs) as vs' in Bind.
        unfold bind_parameter_temps in Bind.
        fold Clight.bind_parameter_temps in Bind.
        rewrite Heqxs', Heqvs' in Bind; clear Heqxs' Heqvs'.
        eapply IHxs; eauto; eapply NotInMembers_cons; eauto.
      + intro Eq.
        apply Notin_o.
        subst o. apply inmembers_eq.
      + intro Eq.
        apply Notin_s.
        subst s. apply inmembers_eq.
  Qed.

  Remark bind_parameter_temps_cons':
    forall xs vs x ty v le le',
      ~ InMembers x xs ->
      bind_parameter_temps xs vs le = Some le' ->
      bind_parameter_temps ((x, ty) :: xs) (v :: vs) le = Some (PTree.set x v le').
  Proof.
    induction xs as [|(x', t')], vs; simpl; intros ** Notin Bind; try discriminate.
    - now inversion Bind.
    - simpl in IHxs.
      rewrite set_comm.
      + apply IHxs; auto.
      + intro; apply Notin; now left.
  Qed.
  
  Remark bind_parameter_temps_exists:
    forall xs s o ys vs ts to sptr optr,
      s <> o ->
      NoDupMembers xs ->
      ~ InMembers s xs ->
      ~ InMembers o xs ->
      ~ InMembers s ys ->
      ~ InMembers o ys ->
      length xs = length vs ->
      exists le',
        bind_parameter_temps ((s, ts) :: (o, to) :: xs)
                             (sptr :: optr :: vs)
                             (create_undef_temps ys) = Some le'
        /\ Forall (fun xty : ident * Ctypes.type =>
                    let (x, _) := xty in
                    match le' ! x with
                    | Some v => match_value (adds (map fst xs) vs sempty) x v
                    | None => False
                    end) (xs ++ ys).
  Proof.
    induction xs as [|(x, ty)]; destruct vs;
    intros ** Hso Nodup Nos Noo Nos' Noo' Hlengths; try discriminate.
    - simpl; econstructor; split; auto.
      unfold match_value, adds; simpl.
      induction ys as [|(y, t)]; simpl; auto.
      assert (y <> s) by (intro; subst; apply Nos'; apply inmembers_eq).
      assert (y <> o) by (intro; subst; apply Noo'; apply inmembers_eq).
      constructor.
      + rewrite PM.gempty.
        do 2 (rewrite PTree.gso; auto).
        now rewrite PTree.gss.
      + apply NotInMembers_cons in Nos'; destruct Nos' as [Nos'].
        apply NotInMembers_cons in Noo'; destruct Noo' as [Noo'].
        specialize (IHys Nos' Noo').
        eapply Forall_impl_In; eauto.
        intros (y', t') Hin Hmatch.
        assert (y' <> s) by (intro; subst; apply Nos'; eapply In_InMembers; eauto).
        assert (y' <> o) by (intro; subst; apply Noo'; eapply In_InMembers; eauto).
        rewrite 2 PTree.gso in *; auto.      
        destruct (ident_eqb y' y) eqn: E.
        * apply ident_eqb_eq in E; subst y'.
          rewrite PTree.gss.
          now rewrite PM.gempty.
        * apply ident_eqb_neq in E.
          now rewrite PTree.gso.
    - inv Hlengths; inv Nodup.
      edestruct IHxs with (s:=s) (ts:=ts) (o:=o) (to:=to) (sptr:=sptr) (optr:=optr)
        as (le' & Bind & ?); eauto.
      + eapply NotInMembers_cons; eauto.
      + eapply NotInMembers_cons; eauto.
      + assert (x <> s) by (intro; subst; apply Nos; apply inmembers_eq).
        assert (x <> o) by (intro; subst; apply Noo; apply inmembers_eq).      
        exists (PTree.set x v le'); split.
        * rewrite bind_parameter_temps_comm; auto.
          apply bind_parameter_temps_cons'; auto.
          simpl; intros [|[|]]; auto.
        *{ rewrite <-app_comm_cons.
           constructor.
           - rewrite PTree.gss.
             unfold match_value, adds; simpl.
             now rewrite PM.gss.
           - eapply Forall_impl_In; eauto.
             intros (x', t') Hin MV.
             destruct (ident_eqb x' x) eqn: E.
             + rewrite ident_eqb_eq in E; subst x'.
               rewrite PTree.gss; unfold match_value, adds; simpl.
               now rewrite PM.gss.
             + rewrite ident_eqb_neq in E.
               rewrite PTree.gso.
               destruct le' ! x'; try contradiction.
               unfold match_value, adds in MV.
               unfold match_value, adds; simpl.
               rewrite PM.gso; auto.
               exact E.
         }
  Qed.
  
  Remark alloc_implies:
    forall vars x b t e m e' m', 
      ~ InMembers x vars ->
      alloc_variables tge (PTree.set x (b, t) e) m vars e' m' ->
      e' ! x = Some (b, t).
  Proof.
    induction vars as [|(x', t')]; intros ** Notin H;
    inversion_clear H as [|? ? ? ? ? ? ? ? ? ? Halloc]; subst.
    - apply PTree.gss.
    - rewrite <-set_comm in Halloc.
      + eapply IHvars; eauto.
        eapply NotInMembers_cons; eauto.
      + intro; subst x; apply Notin; apply inmembers_eq.
  Qed.
  
  Remark In_drop_block:
    forall elts x t,
      In (x, t) (map drop_block elts) ->
      exists b, In (x, (b, t)) elts.
  Proof.
    induction elts as [|(x', (b', t'))]; simpl; intros ** Hin.
    - contradiction.
    - destruct Hin as [Eq|Hin].
      + inv Eq.
        exists b'; now left.
      + apply IHelts in Hin.
        destruct Hin as [b Hin].
        exists b; now right.
  Qed.

  Remark drop_block_In:
    forall elts x b t,
      In (x, (b, t)) elts ->
      In (x, t) (map drop_block elts).
  Proof.
    induction elts as [|(x', (b', t'))]; simpl; intros ** Hin.
    - contradiction.
    - destruct Hin as [Eq|Hin].
      + inv Eq.
        now left.
      + apply IHelts in Hin.
        now right.
  Qed.

  Remark alloc_In:
    forall vars e m e' m',
      alloc_variables tge e m vars e' m' ->
      NoDupMembers vars ->
      (forall x t,
          In (x, t) (map drop_block (PTree.elements e')) <->
          (In (x, t) (map drop_block (PTree.elements e)) /\ (forall t', In (x, t') vars -> t = t'))
          \/ In (x, t) vars).
  Proof.
    intro vars.
    induction_list vars as [|(y, ty)] with vars'; intros ** Alloc Nodup x t;
    inv Alloc; inv Nodup.
    - split; simpl.
      + intros. left; split; auto.
        intros; contradiction.
      + intros [[? ?]|?]; auto.
        contradiction.
    - edestruct IHvars' with (x:=x) (t:=t) as [In_Or Or_In]; eauto.
      clear IHvars'.
      split.
      + intro Hin.
        apply In_Or in Hin.
        destruct Hin as [[Hin Ht]|?].
        *{ destruct (ident_eqb x y) eqn: E.
           - apply ident_eqb_eq in E.
             subst y.
             apply In_drop_block in Hin.
             destruct Hin as [b Hin].
             apply PTree.elements_complete in Hin.
             rewrite PTree.gss in Hin.
             inv Hin.
             right; apply in_eq.
           - apply ident_eqb_neq in E.
             apply In_drop_block in Hin.
             destruct Hin as [b Hin].
             apply PTree.elements_complete in Hin.
             rewrite PTree.gso in Hin; auto.
             apply PTree.elements_correct in Hin.
             left; split.
             + eapply drop_block_In; eauto.
             + intros t' [Eq|Hin'].
               * inv Eq. now contradict E.
               * now apply Ht.
               
         }
        * right; now apply in_cons.
      + intros [[Hin Ht]|Hin]; apply Or_In.
        *{ left; split.
           - destruct (ident_eqb x y) eqn: E.
             + apply ident_eqb_eq in E.
               subst y.
               apply drop_block_In with (b:=b1).
               apply PTree.elements_correct.
               rewrite PTree.gss.
               repeat f_equal.
               symmetry; apply Ht.
               apply in_eq.
             + apply ident_eqb_neq in E.
               apply In_drop_block in Hin.
               destruct Hin as [b Hin].
               apply drop_block_In with (b:=b).
               apply PTree.elements_correct.
               rewrite PTree.gso; auto.
               now apply PTree.elements_complete.
           - intros.
             apply Ht.
             now apply in_cons.
         }
        *{ inversion_clear Hin as [Eq|?].
           - inv Eq.
             left; split.
             + apply drop_block_In with (b:=b1).
               apply PTree.elements_correct.
               now rewrite PTree.gss.
             + intros ** Hin.
               contradict Hin.
               apply NotInMembers_NotIn; auto. 
           - now right.
         }
  Qed.
  
  Remark alloc_mem_vars:
    forall vars e m e' m' P,
      m |= P ->
      NoDupMembers vars ->
      Forall (fun xt => sizeof tge (snd xt) <= Int.modulus) vars ->
      alloc_variables tge e m vars e' m' ->
      m' |= sepall (range_inst_env e') (var_names vars) ** P.
  Proof.
    induction vars as [|(y, t)];
    intros ** Hrep Nodup Forall Alloc;  
    inv Alloc; subst; simpl.
    - now rewrite <-sepemp_left.
    - inv Nodup; inv Forall.
      unfold range_inst_env at 1.
      erewrite alloc_implies; eauto.
      rewrite sep_assoc, sep_swap.
      eapply IHvars; eauto.
      eapply alloc_rule; eauto; omega.
  Qed.

  Remark alloc_permutation:
    forall vars m e' m',
      alloc_variables tge empty_env m vars e' m' ->
      NoDupMembers vars ->
      Permutation vars (map drop_block (PTree.elements e')).
  Proof.
    intros ** Alloc Nodup.
    pose proof (alloc_In _ _ _ _ _ Alloc) as H.
    apply NoDup_Permutation.
    - apply NoDupMembers_NoDup; auto.
    - pose proof (PTree.elements_keys_norepet e') as Norep.
      clear H.
      induction (PTree.elements e') as [|(x, (b, t))]; simpl in *; constructor.
      + inversion_clear Norep as [|? ? Notin Norep'].
        clear IHl.
        induction l as [|(x', (b', t'))]; simpl in *.
        * intro; contradiction.
        *{ intros [Eq | Hin].
           - inv Eq. apply Notin. now left.
           - inv Norep'. apply IHl; auto.
         }
      + inversion_clear Norep as [|? ? Notin Norep'].
        apply IHl; auto. 
    - intros (x, t).
      specialize (H Nodup x t).
      intuition. 
  Qed.

  Lemma Permutation_set:
    forall {A B} x (a:A) (b:B) e,
      ~InMembers x (PTree.elements e) ->
      Permutation (PTree.elements (PTree.set x (a, b) e))
                  ((x, (a, b)) :: PTree.elements e).
  Proof.
    intros ** Hin.
    apply NoDup_Permutation.
    - apply NoDup_map_inv with (f:=fst).
      apply NoDup_norepet.
      apply PTree.elements_keys_norepet.
    - constructor.
      now apply NotInMembers_NotIn.
      apply NoDup_map_inv with (f:=fst).
      apply NoDup_norepet.
      apply PTree.elements_keys_norepet.
    - intro y. destruct y as [y y'].
      split; intro HH.
      + apply PTree.elements_complete in HH.
        rewrite PTree.gsspec in HH.
        destruct (peq y x).
        * injection HH; intro; subst; now constructor.
        * apply PTree.elements_correct in HH; now constructor 2.
      + apply in_inv in HH.
        destruct HH as [HH|HH].
        * destruct y' as [y' y''].
          injection HH; intros; subst.
          apply PTree.elements_correct.
          rewrite PTree.gsspec.
          now rewrite peq_true.
        * apply PTree.elements_correct.
          rewrite PTree.gso.
          now apply PTree.elements_complete.
          intro Heq; rewrite Heq in *.
          apply Hin.
          apply In_InMembers with (1:=HH).
  Qed.
  
  Lemma set_nodupmembers:
    forall x (e: env) b1 t,
      NoDupMembers (map snd (PTree.elements e)) ->
      ~InMembers x (PTree.elements e) ->
      ~InMembers b1 (map snd (PTree.elements e)) -> 
      NoDupMembers (map snd (PTree.elements (PTree.set x (b1, t) e))).
  Proof.
    intros ** Nodup Notin Diff.
    assert (Permutation (map snd (PTree.elements (PTree.set x (b1, t) e)))
                        ((b1, t) :: (map snd (PTree.elements e)))) as Perm.
    { change (b1, t) with (snd (x, (b1, t))).
      rewrite <-map_cons.
      now apply Permutation_map, Permutation_set.     
    }
    rewrite Perm.
    simpl; constructor; auto.
  Qed.  

  Remark alloc_nodupmembers:
    forall vars e m e' m',
      alloc_variables tge e m vars e' m' ->
      NoDupMembers vars ->
      NoDupMembers (map snd (PTree.elements e)) ->
      Forall (fun xv => ~InMembers (fst xv) (PTree.elements e)) vars ->
      (forall b, InMembers b (map snd (PTree.elements e)) -> Mem.valid_block m b) ->
      NoDupMembers (map snd (PTree.elements e')).
  Proof.
    induction vars as [|(x, t)]; intros ** Alloc Nodupvars Nodup Forall Valid;
    inversion Nodupvars as [|? ? ? Notin Nodupvars']; clear Nodupvars;
    inversion Alloc as [|? ? ? ? ? ? ? ? ? Hmem Alloc']; clear Alloc;
    inversion Forall as [|? ? Hnin Hforall]; clear Forall; subst; auto.
    apply IHvars with (e:=PTree.set x (b1, t) e) (m:=m1) (m':=m'); auto.
    - apply set_nodupmembers; auto.
      intros Hinb. 
      apply Valid in Hinb.
      eapply Mem.valid_not_valid_diff; eauto.
      eapply Mem.fresh_block_alloc; eauto.
    - clear IHvars Alloc'.
      induction vars as [|(x', t')]; constructor;
      inv Hforall; inv Nodupvars'; apply NotInMembers_cons in Notin; destruct Notin.
      + rewrite Permutation_set; auto.
        apply NotInMembers_cons; split; auto.
      + apply IHvars; auto.
    - intros b Hinb.   
      destruct (eq_block b b1) as [Eq|Neq].
      + subst b1; eapply Mem.valid_new_block; eauto.
      + assert (InMembers b (map snd (PTree.elements e))) as Hin.
        { apply InMembers_snd_In in Hinb; destruct Hinb as (x' & t' & Hin).
          apply (In_InMembers_snd x' _ t'). 
          apply PTree.elements_complete in Hin.
          destruct (ident_eqb x x') eqn: E.
          - apply ident_eqb_eq in E; subst x'.
            rewrite PTree.gss in Hin.
            inv Hin. now contradict Neq.
          - apply ident_eqb_neq in E.
            rewrite PTree.gso in Hin; auto.
            now apply PTree.elements_correct. 
        }
        apply Valid in Hin.
        eapply Mem.valid_block_alloc; eauto.
  Qed.

  Remark alloc_exists:
    forall vars e m,
      NoDupMembers vars ->
      exists e' m',
        alloc_variables tge e m vars e' m'.
  Proof.
    induction vars as [|(x, t)]; intros ** Nodup.
    - exists e, m; constructor.  
    - inv Nodup.
      destruct (Mem.alloc m 0 (Ctypes.sizeof gcenv t)) as (m1 & b) eqn: Eq.
      edestruct IHvars with (e:=PTree.set x (b, t) e) (m:=m1)
        as (e' & m' & Halloc); eauto.
      exists e', m'; econstructor; eauto.
  Qed.

  Remark Permutation_fst:
    forall vars elems,
      Permutation vars elems ->
      Permutation (var_names vars) (map fst elems).
  Proof.
    intros ** Perm.
    induction Perm; simpl; try constructor; auto.
    transitivity (map fst l'); auto.
  Qed.

  Remark map_fst_drop_block:
    forall elems,
      map fst (map drop_block elems) = map fst elems.
  Proof.
    induction elems as [|(x, (b, t))]; simpl; auto.
    now f_equal.
  Qed.
  
  (* Lemma  *)
  Lemma alloc_result:
    forall f m P,
      let vars := instance_methods f in
      Forall (fun xt: positive * Ctypes.type =>
                sizeof tge (snd xt) <= Int.modulus
                /\ exists (id : AST.ident) (co : composite),
                  snd xt = Tstruct id noattr
                  /\ gcenv ! id = Some co
                  /\ co_su co = Struct
                  /\ NoDupMembers (co_members co)
                  /\ (forall (x' : AST.ident) (t' : Ctypes.type),
                        In (x', t') (co_members co) ->
                        exists chunk : AST.memory_chunk,
                          access_mode t' = By_value chunk
                          /\ (align_chunk chunk | alignof gcenv t')))
             (make_out_vars vars) ->
      NoDupMembers (make_out_vars vars) ->
      m |= P ->
      exists e' m',
        alloc_variables tge empty_env m (make_out_vars vars) e' m'
        /\ (forall x b t, e' ! x = Some (b, t) -> exists o f, x = prefix_out o f)
        /\ m' |= subrep f e'
             ** (subrep f e' -* subrep_range e')
             ** P.
  Proof.
    intros ** Hforall Nodup Hrep; subst.
    rewrite <-Forall_Forall' in Hforall; destruct Hforall.
    pose proof (alloc_exists _ empty_env m Nodup) as Alloc.
    destruct Alloc as (e' & m' & Alloc).
    eapply alloc_mem_vars in Hrep; eauto.
    pose proof Alloc as Perm.
    apply alloc_permutation in Perm; auto.
    exists e', m'; split; [auto|split].
    - intros ** Hget.
      apply PTree.elements_correct in Hget.
      apply in_map with (f:=drop_block) in Hget.
      apply Permutation_sym in Perm.
      rewrite Perm in Hget.
      unfold make_out_vars in Hget; simpl in Hget.
      apply in_map_iff in Hget.
      destruct Hget as (((o, f'), c) & Eq & Hget).
      inv Eq. now exists o, f'.
    - pose proof Perm as Perm_fst.
      apply Permutation_fst in Perm_fst.
      rewrite map_fst_drop_block in Perm_fst.
      rewrite Perm_fst in Hrep.
      rewrite <-subrep_range_eqv in Hrep.
      repeat rewrite subrep_eqv; auto.
      rewrite range_wand_equiv in Hrep.
      + now rewrite sep_assoc in Hrep.
      + eapply Permutation_Forall; eauto. 
      + eapply alloc_nodupmembers; eauto.
        * unfold PTree.elements; simpl; constructor.
        * unfold PTree.elements; simpl.
          clear H H0 Nodup Alloc Perm Perm_fst.
          induction (make_out_vars vars); constructor; auto.
        * intros ** Hin.
          unfold PTree.elements in Hin; simpl in Hin.
          contradiction.
  Qed.
  
  Lemma compat_funcall_pres:
    forall f sb sofs ob vs vargs c prog' prog'' o owner d me tself tout callee_id callee instco m P,
      c.(c_name) <> owner.(c_name) ->
      In (o, c.(c_name)) owner.(c_objs) ->
      field_offset gcenv o (make_members owner) = Errors.OK d ->
      0 <= (Int.unsigned sofs) + d <= Int.max_unsigned ->
      0 <= Int.unsigned sofs ->
      find_class owner.(c_name) prog = Some (owner, prog') ->
      find_class c.(c_name) prog = Some (c, prog'') ->
      find_method callee_id c.(c_methods) = Some callee ->
      length (fn_params f) = length vargs ->
      fn_params f = (self, tself) :: (out, tout) :: map translate_param (callee.(m_in)) ->
      fn_vars f = make_out_vars (instance_methods callee) ->
      fn_temps f = map translate_param (m_vars callee) ->
      list_norepet (var_names f.(fn_params)) ->
      list_norepet (var_names f.(fn_vars)) ->
      vargs = (Vptr sb (Int.add sofs (Int.repr d))) :: (Vptr ob Int.zero) :: vs ->
      gcenv ! (prefix_fun (c_name c) (m_name callee)) = Some instco ->
      m |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs)
          ** blockrep gcenv sempty (co_members instco) ob
          ** P ->
      exists e_fun le_fun m_fun ws xs,
        bind_parameter_temps f.(fn_params) vargs (create_undef_temps f.(fn_temps)) = Some le_fun
        /\ alloc_variables tge empty_env m f.(fn_vars) e_fun m_fun
        /\ (forall x b t, e_fun ! x = Some (b, t) -> exists o f, x = prefix_out o f)
        /\ le_fun ! self = Some (Vptr sb (Int.add sofs (Int.repr d)))
        /\ le_fun ! out = Some (Vptr ob Int.zero)
        /\ c_objs owner = ws ++ (o, c_name c) :: xs
        /\ m_fun |= sepall (staterep_mems gcenv owner me sb (Int.unsigned sofs)) (c_mems owner)
                  ** staterep gcenv prog (c_name c)
                              (match mfind_inst o me with Some om => om | None => hempty end)
                              sb (Int.unsigned (Int.add sofs (Int.repr d)))
                  ** sepall (staterep_objs gcenv prog' owner me sb (Int.unsigned sofs)) (ws ++ xs)
                  ** blockrep gcenv (adds (map fst (m_in callee)) vs sempty) (co_members instco) ob
                  ** subrep callee e_fun
                  ** (subrep callee e_fun -* subrep_range e_fun)
                  ** varsrep callee (adds (map fst (m_in callee)) vs sempty) le_fun
                  ** P
        /\ 0 <= Int.unsigned (Int.add sofs (Int.repr d)) <= Int.max_unsigned.     
  Proof.
    intros ** ? Hin Offs ? ? Findowner Findc Hcallee Hlengths
           Hparams Hvars Htemps Norep_par Norep_vars ? ? Hrep.
    subst vargs; rewrite Hparams, Hvars, Htemps in *.
    assert (~ InMembers self (meth_vars callee)) as Notin_s
        by apply m_notreserved, in_eq.
    assert (~ InMembers out (meth_vars callee)) as Notin_o
        by apply m_notreserved, in_cons, in_eq.
    assert (~ InMembers self (map translate_param (m_in callee))).
    { unfold meth_vars in Notin_s; apply NotInMembers_app in Notin_s.
      rewrite fst_InMembers, translate_param_fst, <-fst_InMembers; tauto. 
    }
    assert (~ InMembers out (map translate_param (m_in callee))).
    { unfold meth_vars in Notin_o; apply NotInMembers_app in Notin_o.
      rewrite fst_InMembers, translate_param_fst, <-fst_InMembers; tauto.
    }
    assert (~ InMembers self (map translate_param (m_vars callee))).
    { unfold meth_vars in Notin_s; rewrite NotInMembers_app_comm, <-app_assoc in Notin_s;
      apply NotInMembers_app in Notin_s.
      rewrite fst_InMembers, translate_param_fst, <-fst_InMembers; tauto.
    }    
    assert (~ InMembers out (map translate_param (m_vars callee))).
    { unfold meth_vars in Notin_o; rewrite NotInMembers_app_comm, <-app_assoc in Notin_o;
      apply NotInMembers_app in Notin_o.
      rewrite fst_InMembers, translate_param_fst, <-fst_InMembers; tauto.
    }
    assert (0 <= d <= Int.max_unsigned) by
        (split; [eapply field_offset_in_range'; eauto | omega]).
    
    edestruct
      (bind_parameter_temps_exists (map translate_param callee.(m_in)) self out
                                   (map translate_param callee.(m_vars)) vs
                                   tself tout (Vptr sb (Int.add sofs (Int.repr d))) (Vptr ob Int.zero))
    with (1:=self_not_out) as (le_fun & Bind & Hinputs); eauto.
    - pose proof (m_nodupvars callee) as Nodup.
      rewrite Permutation_app_comm in Nodup.
      apply NoDupMembers_app_r in Nodup.
      rewrite fst_NoDupMembers, translate_param_fst, <-fst_NoDupMembers; auto.
    - simpl in Hlengths. inversion Hlengths; eauto.
    - edestruct (alloc_result callee) as (e_fun & m_fun & ? & ? & Hm_fun); eauto.
      + eapply instance_methods_caract; eauto. 
      + unfold var_names in Norep_vars.
        now rewrite fst_NoDupMembers, NoDup_norepet. 
      + edestruct (bind_parameter_temps_implies' (map translate_param (m_in callee)))
        with (1:=self_not_out) as (? & ?); eauto.
        pose proof Hin as Hin'.
        apply sepall_in in Hin.
        destruct Hin as (ws & xs & Hin & Heq).             
        exists e_fun, le_fun, m_fun, ws, xs;
          split; [|split; [|split; [|split; [|split; [|split; [|split]]]]]]; auto.
        *{ rewrite <- 5 sep_assoc; rewrite sep_swap.
           rewrite <-map_app, translate_param_fst in Hinputs.
           apply sep_pure; split; auto.
           rewrite sep_assoc, sep_swap, sep_assoc, sep_swap23, sep_swap.
           eapply sep_imp; eauto.
           apply sep_imp'; auto.
           rewrite sep_assoc.
           apply sep_imp'; auto.
           - edestruct find_class_app with (1:=Findowner)
               as (pre_prog & Hprog & FindNone); eauto.
             rewrite Hprog in WT.
             eapply wt_program_not_class_in in WT; eauto.
             rewrite staterep_skip; eauto.
             simpl.
             rewrite ident_eqb_refl.
             rewrite sep_assoc.
             apply sep_imp'; auto.
             rewrite Heq, Offs.
             apply sep_imp'; auto.
             unfold instance_match.
             erewrite <-staterep_skip_cons; eauto.
             erewrite <-staterep_skip_app; eauto.
             rewrite <-Hprog.
             unfold Int.add; repeat (rewrite Int.unsigned_repr; auto).
           - apply sep_imp'; auto.
             rewrite <-translate_param_fst.
             erewrite <-output_match; eauto.
             apply blockrep_nodup.
             pose proof (m_nodupvars callee) as Nodup.
             rewrite app_assoc, Permutation_app_comm, app_assoc, Permutation_app_comm in Nodup.
             apply NoDupMembers_app_r in Nodup; rewrite Permutation_app_comm in Nodup.
             rewrite <-map_app, fst_NoDupMembers, translate_param_fst, <-fst_NoDupMembers; auto.
         }
        * split; unfold Int.add; repeat (rewrite Int.unsigned_repr; auto); omega.
  Qed.
  
  Remark type_pres':
    forall f c caller es,
      Forall2 (fun e x => typeof e = snd x) es f.(m_in) ->
      type_of_params (map translate_param f.(m_in)) =
      list_type_to_typelist (map Clight.typeof (map (translate_exp c caller) es)).
  Proof.
    intro f.
    induction (m_in f) as [|(x, t)]; intros ** Heq;
    inversion_clear Heq as [|? ? ? ? Ht]; simpl; auto.
    f_equal.
    - simpl in Ht; rewrite <-Ht.
      now rewrite type_pres.
    - now apply IHl.
  Qed.

  Lemma free_exists:
    forall e m P,
      m |= subrep_range e ** P ->
      exists m',
        Mem.free_list m (blocks_of_env tge e) = Some m'
        /\ m' |= P.
  Proof.
    intro e.
    unfold subrep_range, blocks_of_env.
    induction (PTree.elements e) as [|(x,(b,ty))];
      simpl; intros ** Hrep.
    - exists m; split; auto.
      now rewrite sepemp_left.
    - rewrite sep_assoc in Hrep.
      apply free_rule in Hrep.
      destruct Hrep as (m1 & Hfree & Hm1).
      rewrite Hfree.
      now apply IHl.
  Qed.

  (* rewrite <-sep_assoc, sep_unwand in Hrep; auto. *)
     
  Lemma subrep_extract:
    forall f f' e m o c' P,
      m |= subrep f e ** P ->
      In (o, f', c') (instance_methods f) ->
      exists b co ws xs,
        e ! (prefix_out o f') = Some (b, type_of_inst (prefix_fun c' f'))
        /\ gcenv ! (prefix_fun c' f') = Some co
        /\ make_out_vars (instance_methods f) = ws ++ (prefix_out o f', type_of_inst (prefix_fun c' f')) :: xs
        /\ m |= blockrep gcenv sempty (co_members co) b
            ** sepall (subrep_inst_env e) (ws ++ xs)
            ** P.
  Proof.
    intros ** Hrep Hin.
    unfold subrep, subrep_inst in *.
    assert (In (prefix_out o f', type_of_inst (prefix_fun c' f')) (make_out_vars (instance_methods f))) as Hin'.
    { apply in_map with
      (f:=fun x => let '(o0, f0, cid) := x in (prefix_out o0 f0, type_of_inst (prefix_fun cid f0))) in Hin.
      unfold make_out_vars; auto.
    }
    clear Hin.
    apply sepall_in in Hin'; destruct Hin' as (ws & xs & Hin & Heq). 
    repeat rewrite Heq in Hrep.
    pose proof Hrep as Hrep'.
    do 2 apply sep_proj1 in Hrep.
    unfold subrep_inst_env in *.
    destruct e ! (prefix_out o f'); [|contradict Hrep].
    destruct p as (oblk, t).
    destruct t; try now contradict Hrep.
    destruct (type_eq (type_of_inst (prefix_fun c' f')) (Tstruct i a)) as [Eq|]; [|contradict Hrep].
    unfold type_of_inst in Eq.
    inv Eq.
    destruct gcenv ! (prefix_fun c' f'); [|contradict Hrep].
    rewrite sep_assoc in Hrep'.
    exists oblk, c, ws, xs; split; auto.
  Qed.

  Lemma stmt_call_eval_sub_prog:
    forall p p' me clsid f vs ome rvs,
      stmt_call_eval p me clsid f vs ome rvs ->
      wt_program p' ->
      sub_prog p p' ->
      stmt_call_eval p' me clsid f vs ome rvs.
  Proof.
    intros ** Ev ? ?.
    induction Ev.
    econstructor; eauto.
    eapply find_class_sub_same; eauto.
  Qed.
  Hint Resolve stmt_call_eval_sub_prog.

  Lemma stmt_eval_sub_prog:
    forall p p' me ve s S,
      stmt_eval p me ve s S ->
      wt_program p' ->
      sub_prog p p' ->
      stmt_eval p' me ve s S.
  Proof.
    intros ** Ev ? ?.
    induction Ev; econstructor; eauto.
  Qed.
  Hint Resolve stmt_eval_sub_prog.
  
  Lemma wt_params:
    forall vs xs es,
      Forall2 (fun e v => wt_val v (typeof e)) es vs ->
      Forall2 (fun e (xt: ident * type) => typeof e = snd xt) es xs ->
      Forall2 (fun v xt => wt_val v (snd xt)) vs xs.
  Proof.
    induction vs, xs, es; intros ** Wt Eq; inv Wt;
    inversion_clear Eq as [|? ? ? ? E]; auto.
    constructor; eauto.
    now rewrite <- E.
  Qed.
  Hint Resolve wt_params.
  
  Theorem correctness:
    (forall p me1 ve1 s S2,
        stmt_eval p me1 ve1 s S2 ->
        sub_prog p prog ->
        forall c prog' f
          (Occurs: occurs_in s (m_body f))
          (WF: wt_stmt prog c.(c_objs) c.(c_mems) (meth_vars f) s)
          (Find: find_class c.(c_name) prog = Some (c, prog'))
          (Hf: find_method f.(m_name) c.(c_methods) = Some f),
        forall e1 le1 m1 sb sofs outb outco P
          (MS: m1 |= match_states c f (me1, ve1) (e1, le1) sb sofs outb outco ** P),
        exists le2 m2 T,
          exec_stmt tge (function_entry2 tge) e1 le1 m1
                    (translate_stmt prog c f s) T le2 m2 Out_normal
          /\ m2 |= match_states c f S2 (e1, le2) sb sofs outb outco ** P)
    /\
    (forall p me1 clsid fid vs me2 rvs,
        stmt_call_eval p me1 clsid fid vs me2 rvs ->
        sub_prog p prog ->
        forall owner c caller callee prog' prog'' me ve e1 le1 m1 o cf ptr_f sb
          d outb outco sofs binst instco P,
          let oty := type_of_inst (prefix_fun clsid fid) in
          find_class owner.(c_name) prog = Some (owner, prog'') ->
          find_method caller.(m_name) owner.(c_methods) = Some caller ->
          find_class clsid prog = Some (c, prog') ->
          find_method fid c.(c_methods) = Some callee ->
          m1 |= staterep gcenv prog owner.(c_name) me sb (Int.unsigned sofs)
               ** blockrep gcenv ve outco.(co_members) outb
               ** subrep caller e1
               ** varsrep caller ve le1
               ** P ->
          wt_mem me1 prog' c ->
          Forall2 (fun (v : val) (xt : ident * type) => wt_val v (snd xt)) 
     vs (m_in callee) ->
          Globalenvs.Genv.find_symbol tge (prefix_fun clsid fid) = Some ptr_f ->
          Globalenvs.Genv.find_funct_ptr tge ptr_f = Some (Ctypes.Internal cf) ->
          length cf.(fn_params) = (2 + length vs)%nat ->
          me1 = match mfind_inst o me with Some om => om | None => hempty end ->        
          e1 ! (prefix_out o fid) = Some (binst, oty) ->
          In (o, clsid) owner.(c_objs) ->
          In (o, fid, clsid) (instance_methods caller) ->
          field_offset gcenv o (make_members owner) = Errors.OK d ->
          0 <= Int.unsigned sofs + d <= Int.max_unsigned ->
          0 <= Int.unsigned sofs ->
          gcenv ! (prefix_fun clsid fid) = Some instco ->
          wt_stmt prog c.(c_objs) c.(c_mems) (meth_vars callee) callee.(m_body) ->
          eval_expr tge e1 le1 m1 (ptr_obj owner.(c_name) clsid o) (Vptr sb (Int.add sofs (Int.repr d))) ->
          exists m2 T ws xs,
            eval_funcall tge (function_entry2 tge) m1 (Internal cf)
                         ((Vptr sb (Int.add sofs (Int.repr d))) :: (Vptr binst Int.zero) :: vs) T m2 Vundef
            /\ make_out_vars (instance_methods caller) =
              ws ++ (prefix_out o fid, type_of_inst (prefix_fun clsid fid)) :: xs
            /\ m2 |= staterep gcenv prog owner.(c_name) (madd_obj o me2 me) sb (Int.unsigned sofs)
                   ** blockrep gcenv ve outco.(co_members) outb
                   ** blockrep gcenv (adds (map fst callee.(m_out)) rvs sempty)
                               instco.(co_members) binst
                   ** sepall (subrep_inst_env e1) (ws ++ xs)
                   ** varsrep caller ve le1
                   ** P).
  Proof.
    clear TRANSL.
    apply stmt_eval_call_ind; intros until 1;
    [| |intros Evs ? Hrec_eval ? ? ? owner ? caller
     |intros HS1 ? HS2|intros Hbool ? Hifte|
     |rename H into Find; intros Findmeth ? Hrec_exec Findvars Sub;
      intros ** Findowner ? Find' Findmeth' Hrep ? ? Hgetptrf Hgetcf ? Findinst
             Hbinst ? Hin Offs ? ? Hinstco ? ?]; intros;
      try inversion_clear WF as [? ? Hvars|? ? Hin| |
                                 |? ? ? ? ? callee ? ? Hin Find' Findmeth|];
      try (rewrite match_states_conj in MS;
            destruct MS as (Hrep & WT_env & WT_mem & Hself & Hout & Houtco & He & ?));
      subst.
    
    (* Assign x e : "x = e" *)
    - edestruct pres_sem_stmt with (stmt:=Assign x e); eauto.        

      (* get the 'self' variable left value evaluation *)
      simpl translate_stmt; unfold assign.
      destruct (mem_assoc_ident x (m_out f)) eqn: E.

      (* out->x = e *)
      + (* get the 'out' variable left value evaluation *)
        rewrite sep_swap in Hrep.
        edestruct evall_out_field with (e:=e1) as (? & ? & ?); eauto.
        
        (* get the updated memory *)
        rewrite sep_swap34, sep_swap23, sep_swap in Hrep.
        
        edestruct match_states_assign_out with (v:=v) as (m2 & ? & Hm2); eauto.
        rewrite sep_swap, sep_swap23, sep_swap34, sep_swap in Hrep.
        
        exists le1, m2, E0; split; auto.
        eapply ClightBigstep.exec_Sassign; eauto.
        * rewrite type_pres; eapply sem_cast_same; eauto.
        *{ eapply assign_loc_value.
           - simpl; eauto. 
           - rewrite Int.add_zero_l; auto.
         }
        * rewrite match_states_conj. 
          rewrite sep_swap34, sep_swap23, sep_swap, sep_swap23.
          repeat (split; auto).
          
      (* x = e *)
      + exists (PTree.set x v le1), m1, E0; split.
        * eapply ClightBigstep.exec_Sset; eauto.          
        *{ assert (~ InMembers self (meth_vars f))
             by apply m_notreserved, in_eq.
           assert (~ InMembers out (meth_vars f))
             by apply m_notreserved, in_cons, in_eq.
           rewrite match_states_conj; split; [|repeat (split; auto)]. 
           - rewrite sep_swap4 in *.
             eapply match_states_assign_tempvar; eauto.
           - rewrite PTree.gso; auto.
             eapply In_InMembers, InMembers_neq in Hvars; eauto.
           - rewrite PTree.gso; auto.
             eapply In_InMembers, InMembers_neq in Hvars; eauto.
         }
         
    (* AssignSt x e : "self->x = e"*)
    - edestruct pres_sem_stmt with (stmt:=AssignSt x e); eauto.

      edestruct evall_self_field with (e:=e1) as (? & ? & Hoffset & ?); eauto.

      (* get the updated memory *)
      edestruct match_states_assign_state as (m2 & ? & ?); eauto.
      
      exists le1, m2, E0; split.
      + eapply ClightBigstep.exec_Sassign; eauto.
        * rewrite type_pres; apply sem_cast_same; eauto.
        *{ eapply assign_loc_value.
           - simpl; eauto.
           - unfold Int.add.
             rewrite Int.unsigned_repr; auto.
         }
      + rewrite match_states_conj; repeat (split; auto).
        

    (* Call [y1; ...; yn] clsid o f [e1; ... ;em] : "clsid_f(&(self->o), &o, e1, ..., em); y1 = o.y1; ..." *)
    (* get the Clight corresponding function *)
    - edestruct pres_sem_stmt with (stmt:=Call ys clsid o f es); eauto.
      
      edestruct methods_corres
        as (ptr_f & cf & ? & ? & Hparams & Hreturn & Hcc & ?); eauto.

      pose proof (find_class_name _ _ _ _ Find') as Eq.
      pose proof (find_method_name _ _ _ Findmeth) as Eq'.
      subst. (* rewrite Eq, Eq' in *. *)

      (* the *self parameter *)
      edestruct eval_self_inst with (1:=Find) (e:=e1) as (? & ? & ? & ?); eauto.
      
      (* the *out parameter *)
      rewrite sep_swap3 in Hrep.
      apply occurs_in_instance_methods in Occurs.
      edestruct subrep_extract as (oblk & instco & ? & ? & Hoblk & Hinstco & ?); eauto.
      
      (* recursive funcall evaluation *)
      rewrite sep_swap3 in Hrep.
      edestruct Hrec_eval with (owner:=owner) (e1:=e1) (m1:=m1) (le1:=le1) (instco:=instco)
        as (m2 & T & xs & ws & ? & Heq & Hm2); eauto.
      + destruct (mfind_inst o menv).
        2: apply wt_hempty.
        admit.
      + symmetry; erewrite <-Forall2_length; eauto.
        rewrite Hparams; simpl; repeat f_equal.
        rewrite list_length_map.
        eapply Forall2_length; eauto.
      + destruct wt_program_find_class with (2:=Find') as [WT']; auto.
        eapply wt_class_find_method in WT'; eauto.
        unfold wt_method in WT'.
        eapply wt_stmt_sub, find_class_sub; eauto.
      + (* output assignments *)
        clear Hrec_eval.      
        rewrite sep_swap3, sep_swap45, sep_swap34 in Hm2.
        edestruct exec_funcall_assign with (1:=Find) (ys:=ys) (m1:=m2)
          as (le3 & m3 & ? & ? & Hm3 & ? & ?) ; eauto.

        edestruct pres_sem_stmt_call; eauto.
        destruct (mfind_inst o menv).
        2: apply wt_hempty.
        admit.

        exists le3, m3; econstructor; split; auto.
        *{ simpl.
           unfold binded_funcall.
           rewrite Find', Findmeth.
           eapply exec_Sseq_1 with (m1:=m2); eauto.
           assert (forall v, le1 = set_opttemp None v le1) as E by reflexivity.
           erewrite E at 2.
           eapply exec_Scall; eauto.
           - reflexivity.
           - simpl.
             eapply eval_Elvalue.
             + apply eval_Evar_global; eauto.
               rewrite <-not_Some_is_None.
               intros (b, t) Hget.
               apply He in Hget; destruct Hget as (o' & f' & Eqpref).
               unfold prefix_fun, prefix_out in Eqpref.
               apply prefix_injective in Eqpref; destruct Eqpref.
               apply fun_not_out; auto.
             + apply deref_loc_reference; auto.               
           - apply find_method_In in Findmeth.
             do 2 (econstructor; eauto).
             eapply exprs_eval_simu with (1:=Find); eauto.
           - unfold Genv.find_funct.
             destruct (Int.eq_dec Int.zero Int.zero) as [|Neq]; auto.
             exfalso; apply Neq; auto.
           - simpl. unfold type_of_function;
               rewrite Hparams, Hreturn, Hcc; simpl; repeat f_equal.
             apply type_pres'; auto.
         }
        * rewrite match_states_conj; split; [|repeat (split; auto)].
          rewrite sep_swap34.
          rewrite sep_swap4 in Hm3.
          eapply sep_imp; eauto.
          apply sep_imp'; auto.
          apply sep_imp'; auto.
          rewrite <-sep_assoc.
          apply sep_imp'; auto.
          unfold subrep.
          rewrite (sepall_breakout _ _ _ _ (subrep_inst_env e1) Heq).
          apply sep_imp'; auto.
          unfold subrep_inst_env.
          rewrite Hoblk.
          unfold type_of_inst.
          rewrite Hinstco.
          rewrite type_eq_refl.
          apply blockrep_any_empty.

    (* Comp s1 s2 : "s1; s2" *)
    - edestruct pres_sem_stmt with (stmt:=Comp a1 a2); eauto.
      
      apply occurs_in_comp in Occurs.
      edestruct HS1; destruct_conjs; eauto.
      + rewrite match_states_conj. repeat (split; eauto).
      + edestruct HS2; destruct_conjs; eauto.
        do 3 econstructor; split; eauto.
        eapply exec_Sseq_1; eauto.
          
    (* Ifte e s1 s2 : "if e then s1 else s2" *)
    - edestruct pres_sem_stmt with (stmt:=Ifte cond ifTrue ifFalse); eauto.

      apply occurs_in_ite in Occurs.
      edestruct Hifte; destruct_conjs; eauto; [(destruct b; auto)|(destruct b; auto)| |]. 
      + rewrite match_states_conj.
        repeat (split; eauto).
      + do 3 econstructor; split; eauto.
        eapply exec_Sifthenelse with (b:=b); eauto.
        *{ erewrite type_pres; eauto.
           match goal with H: typeof cond = bool_type |- _ => rewrite H end.
           unfold Cop.bool_val; simpl.
           destruct (val_to_bool v) eqn: E.
           - rewrite Hbool in E.
             destruct b.
<<<<<<< HEAD
             + apply val_to_bool_true' in E; subst; simpl.
               rewrite Int.eq_false; auto.
               apply Int.one_not_zero.
             + apply val_to_bool_false' in E; subst; simpl.
               rewrite Int.eq_true; auto.
=======
             + apply val_to_bool_true' in E; subst.
               unfold Cop.bool_val.
               admit.
             + apply val_to_bool_false' in E; subst.
               admit.
>>>>>>> some modifs
           - discriminate.
         }
        * destruct b; eauto.
         
    (* Skip : "skip" *)
    - exists le1, m1, E0; split.
      + eapply exec_Sskip.
      + rewrite match_states_conj; repeat (split; auto). 
        
    (* funcall *)
    - pose proof (find_class_sub_same _ _ _ _ _ Find WT Sub) as Find''.
      rewrite Find' in Find''; inversion Find''; subst prog'0 cls; clear Find''.
      rewrite Findmeth in Findmeth'; inversion Findmeth'; subst fm; clear Findmeth'.

      edestruct pres_sem_stmt_call; eauto.
      destruct (mfind_inst o me); econstructor; eauto.

      (* edestruct pres_sem_stmt with (stmt:=m_body callee); eauto. *)

      (* get the clight function *)
      edestruct methods_corres
        as (ptr_f' & cf' & Hgetptrf' & Hgetcf' & ? & Hret & ? & ? & ? & ? & ? & ? & Htr); eauto.
      rewrite Hgetptrf' in Hgetptrf; inversion Hgetptrf; subst ptr_f'; clear Hgetptrf.
      rewrite Hgetcf' in Hgetcf; inversion Hgetcf; subst cf'; clear Hgetcf.

      pose proof (find_class_name _ _ _ _ Find) as Eq.
      pose proof (find_method_name _ _ _ Findmeth) as Eq'.
      rewrite <-Eq, <-Eq' in *.

      edestruct find_class_app with (1:=Findowner)
        as (pre_prog & Hprog & FindNone); eauto.
      rewrite Hprog in WT.
      assert (c_name c <> c_name owner)
        by (eapply wt_program_not_same_name;
            eauto using (wt_program_app _ _ WT)).

      (* extract the out structure *)
      rewrite sep_swap23, sep_swap in Hrep.
      eapply subrep_extract in Hrep; eauto.
      destruct Hrep as (binst' & instco' & ws & xs & Hbinst' & Hinstco' & ? & Hrep).
      rewrite Hinstco' in Hinstco; inversion Hinstco; subst instco'; clear Hinstco.
      rewrite Hbinst' in Hbinst; inversion Hbinst; subst binst'; clear Hbinst.
      rewrite sep_swap23, sep_swap in Hrep.
      edestruct (compat_funcall_pres cf sb sofs binst vs)
        as (e_fun & le_fun & m_fun & ws' & xs' & Bind & Alloc & He_fun & ? & ? & Hobjs & Hm_fun & ? & ?);
        eauto; simpl; auto.
      pose proof (find_class_sub _ _ _ _ Find') as Hsub.
      specialize (Hrec_exec Hsub c).
      edestruct Hrec_exec with (le1:=le_fun) (e1:=e_fun) (m1:=m_fun)
        as (? & m_fun' & ? & ? & MS'); eauto.
      + rewrite match_states_conj; split; eauto; [|repeat split; eauto].
        simpl.
        rewrite sep_swap, sep_swap34, sep_swap23, sep_swap45, sep_swap34,
        <-sep_assoc, <-sep_assoc, sep_swap45, sep_swap34, sep_swap23,
        sep_swap45, sep_swap34, sep_assoc, sep_assoc in Hm_fun; eauto.
        admit.
        admit.
        admit.
      + rewrite match_states_conj in MS'; destruct MS' as (Hm_fun' & ?).
        rewrite sep_swap23, sep_swap5, sep_swap in Hm_fun'.
        rewrite <-sep_assoc, sep_unwand in Hm_fun'; auto.
        edestruct free_exists as (m_fun'' & Hfree & Hm_fun''); eauto.
        exists m_fun''; econstructor; exists ws, xs; split; [|split]; eauto.
        *{ eapply eval_funcall_internal; eauto.
           - constructor; eauto.
           - rewrite Htr.
             eapply exec_Sseq_1; eauto.
             apply exec_Sreturn_none.
           - rewrite Hret; reflexivity. 
         }
        *{ rewrite sep_swap5.
           rewrite <- 3 sep_assoc in Hm_fun''; rewrite sep_swap5 in Hm_fun'';
           rewrite 3 sep_assoc in Hm_fun''.          
           unfold varsrep in *; rewrite sep_pure in *.
           destruct Hm_fun'' as (Hpure & Hm_fun''); split; auto.
           rewrite sep_swap5, sep_pure in Hm_fun''.
           destruct Hm_fun'' as (Hpure' & Hm_fun'').             
           rewrite sep_swap23, sep_swap.
           eapply sep_imp; eauto.
           apply sep_imp'; auto.
           apply sep_imp'; auto.
           - erewrite <-output_match; eauto.
             rewrite <-translate_param_fst.
             apply blockrep_findvars. 
             rewrite translate_param_fst; auto.             
           - rewrite staterep_skip with (c:=owner); eauto. simpl.
             rewrite ident_eqb_refl. rewrite sep_assoc, sep_swap3.
             apply sep_imp'; auto.
             rewrite sepall_breakout with (ys:=c_objs owner); eauto; simpl.
             rewrite sep_assoc.
             apply sep_imp'.
             + rewrite Offs.
               unfold instance_match, mfind_inst, madd_obj; simpl.
               rewrite PM.gss.
               eapply wt_program_not_class_in in WT; eauto.
               rewrite <-staterep_skip_cons with (prog:=prog'') (cls:=owner); eauto.
               rewrite <-staterep_skip_app with (prog:=owner :: prog''); eauto.
               rewrite <-Hprog.
               unfold Int.add.
                assert (0 <= d <= Int.max_unsigned)
                 by (split; [eapply field_offset_in_range'; eauto | omega]).
               repeat (rewrite Int.unsigned_repr; auto).
             + apply sep_imp'; auto.
               unfold staterep_objs.
               apply sepall_swapp.
               intros (i, k) Hini.
               destruct (field_offset gcenv i (make_members owner)); auto.
               unfold instance_match, mfind_inst, madd_obj; simpl.
               destruct (ident_eqb i o) eqn: E.
               * exfalso.
                 apply ident_eqb_eq in E; subst i.
                 pose proof (c_nodupobjs owner) as Nodup.
                 rewrite Hobjs in Nodup.
                 rewrite NoDupMembers_app_cons in Nodup.
                 destruct Nodup as [Notin Nodup].
                 apply Notin.
                 eapply In_InMembers; eauto.
               * apply ident_eqb_neq in E. 
                 rewrite PM.gso; auto.
         }
  Qed.

End PRESERVATION.

