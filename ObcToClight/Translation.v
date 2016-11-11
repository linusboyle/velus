Require cfrontend.Clight.
Require Import lib.Integers.
Require Import common.Errors.
Require Import lib.Maps.

Require Import Rustre.Common.
Require Import Rustre.ObcToClight.Interface.
Require Import Rustre.Ident.

Require Import Instantiator.
Import Obc.Syn.

Require Import ZArith.BinInt.
Require Import String.
Require Import List.
Import List.ListNotations.
Open Scope list_scope.
Open Scope error_monad_scope.
Open Scope Z.

(* TRANSLATION *)
Definition type_of_inst (o: ident): Ctypes.type :=
  Ctypes.Tstruct o Ctypes.noattr.
Definition pointer_of (ty: Ctypes.type): Ctypes.type :=
  Ctypes.Tpointer ty Ctypes.noattr.
Definition type_of_inst_p (o: ident): Ctypes.type :=
  pointer_of (type_of_inst o).

Definition deref_field (id cls x: ident) (xty: Ctypes.type): Clight.expr :=
  let ty_deref := type_of_inst cls in
  let ty_ptr := pointer_of ty_deref in
  Clight.Efield (Clight.Ederef (Clight.Etempvar id ty_ptr) ty_deref) x xty.

Definition translate_const (c: const): Clight.expr :=
  (match c with
  | Cint i sz sg => Clight.Econst_int (Cop.cast_int_int sz sg i)
  | Clong l _ => Clight.Econst_long l
  | Cfloat f => Clight.Econst_float f
  | Csingle s => Clight.Econst_single s
  end) (cltype (type_const c)).

Definition translate_unop (op: unop) (e: Clight.expr) (ty: Ctypes.type): Clight.expr :=
  match op with
  | UnaryOp cop => Clight.Eunop cop e ty
  | CastOp _ => Clight.Ecast e ty
  end.

Definition translate_binop (op: binop): Clight.expr -> Clight.expr -> Ctypes.type -> Clight.expr :=
  Clight.Ebinop op.

(** Straightforward expression translation *)
Fixpoint translate_exp (c: class) (m: method) (e: exp): Clight.expr :=
  match e with
  | Var x ty =>
    let ty := cltype ty in
    if mem_assoc_ident x m.(m_out) then
      deref_field out (prefix_fun c.(c_name) m.(m_name)) x ty
    else
      Clight.Etempvar x ty  
  | State x ty =>
    deref_field self c.(c_name) x (cltype ty)
  | Const c =>
    translate_const c
  | Unop op e ty =>
    translate_unop op (translate_exp c m e) (cltype ty)
  | Binop op e1 e2 ty =>
    translate_binop op (translate_exp c m e1) (translate_exp c m e2) (cltype ty)
  end.

Fixpoint list_type_to_typelist (tys: list Ctypes.type): Ctypes.typelist :=
  match tys with
  | [] => Ctypes.Tnil
  | ty :: tys => Ctypes.Tcons ty (list_type_to_typelist tys)
  end.

Definition funcall (f: ident) (args: list Clight.expr) : Clight.statement :=
  let tys := map Clight.typeof args in
  let sig := Ctypes.Tfunction (list_type_to_typelist tys) Ctypes.Tvoid AST.cc_default in
  Clight.Scall None (Clight.Evar f sig) args.

Definition assign (x: ident) (ty: Ctypes.type) (clsid: ident) (m: method): Clight.expr -> Clight.statement :=
  if mem_assoc_ident x m.(m_out) then
    Clight.Sassign (deref_field out (prefix_fun clsid m.(m_name)) x ty)
  else
    Clight.Sset x.

Definition ptr_obj (owner: ident) (cls obj: ident): Clight.expr :=
  Clight.Eaddrof (deref_field self owner obj (type_of_inst cls)) (type_of_inst_p cls).  

Definition funcall_assign
           (ys: list ident) (owner: ident) (caller: method)
           (obj: ident) (tyout: Ctypes.type) (callee: method)
           : Clight.statement :=
  fold_right
    (fun y s =>
       let '(y, (y', ty)) := y in
       let ty := cltype ty in 
       let assign_out := assign y ty owner caller (Clight.Efield (Clight.Evar obj tyout) y' ty) in
       Clight.Ssequence assign_out s
    ) Clight.Sskip (combine ys callee.(m_out)).

Definition binded_funcall
           (prog: program) (ys: list ident) (owner: ident)
           (caller: method) (cls obj f: ident) (args: list Clight.expr)
  : Clight.statement :=
  match find_class cls prog with
  | Some (c, _) =>
    match find_method f c.(c_methods) with
    | Some m =>
      let tyout := type_of_inst (prefix_fun cls f) in
      let out := Clight.Eaddrof (Clight.Evar (prefix_out obj f) tyout) (pointer_of tyout) in 
      let args := ptr_obj owner cls obj :: out :: args in
      Clight.Ssequence
        (funcall (prefix_fun cls f) args)
        (funcall_assign ys owner caller (prefix_out obj f) tyout m)
    | None => Clight.Sskip
    end
  | None => Clight.Sskip
  end.

Definition translate_param (yt: ident * type): ident * Ctypes.type :=
  let (y, t) := yt in
  (y, cltype t).

(** 
Statement conversion keeps track of the produced temporaries (function calls).
[c] represents the current class.
 *)
Fixpoint translate_stmt (prog: program) (c: class) (m: method) (s: stmt)
  : Clight.statement :=
  match s with
  | Assign x e =>
    assign x (cltype (typeof e)) c.(c_name) m (translate_exp c m e)
  | AssignSt x e =>
    Clight.Sassign (deref_field self c.(c_name) x (cltype (typeof e))) (translate_exp c m e)
  | Ifte e s1 s2 =>
    Clight.Sifthenelse (translate_exp c m e) (translate_stmt prog c m s1) (translate_stmt prog c m s2) 
  | Comp s1 s2 =>
    Clight.Ssequence (translate_stmt prog c m s1) (translate_stmt prog c m s2)
  | Call ys cls o f es =>
    binded_funcall prog ys c.(c_name) m cls o f (map (translate_exp c m) es)  
  | Skip => Clight.Sskip
  end.

Definition return_none (s: Clight.statement): Clight.statement :=
  Clight.Ssequence s (Clight.Sreturn None).
Definition cl_zero: Clight.expr :=
  Clight.Econst_int Int.zero Ctypes.type_int32s.
Definition return_zero (s: Clight.statement): Clight.statement :=
  Clight.Ssequence s (Clight.Sreturn (Some cl_zero)).

Definition fundef
           (ins vars temps: list (ident * Ctypes.type))
           (ty: Ctypes.type) (body: Clight.statement)
  : AST.globdef Clight.fundef Ctypes.type :=
  let f := Clight.mkfunction ty AST.cc_default ins vars temps body in
  @AST.Gfun Clight.fundef Ctypes.type (Ctypes.Internal f).

Require Import FMapAVL.
Require Export Coq.Structures.OrderedTypeEx.

Module IdentPair := PairOrderedType Positive_as_OT Positive_as_OT.
Module M := FMapAVL.Make(IdentPair).

Definition make_out_vars (out_vars: M.t ident): list (ident * Ctypes.type) :=
  map (fun ofc =>
         let '(o, f, cid) := ofc in
         (prefix_out o f, type_of_inst (prefix_fun cid f))
      ) (M.elements out_vars).

Fixpoint rec_instance_methods (s: stmt) (m: M.t ident): M.t ident :=
  match s with
  | Ifte _ s1 s2  
  | Comp s1 s2 => rec_instance_methods s2 (rec_instance_methods s1 m)
  | Call _ cls o f _ => M.add (o, f) cls m 
  | _ => m
  end.
  
Definition instance_methods (m: method): M.t ident :=
  rec_instance_methods m.(m_body) (@M.empty ident).

Definition translate_method (prog: program) (c: class) (m: method)
  : ident * AST.globdef Clight.fundef Ctypes.type :=
  let body := translate_stmt prog c m m.(m_body) in
  let out_vars := instance_methods m in
  let self := (self, type_of_inst_p c.(c_name)) in
  let ins := map translate_param m.(m_in) in
  let out := (out, type_of_inst_p (prefix_fun c.(c_name) m.(m_name))) in
  let vars := map translate_param m.(m_vars) in
  (prefix_fun c.(c_name) m.(m_name),
   fundef (self :: out :: ins) (make_out_vars out_vars) vars Ctypes.Tvoid (return_none body)).

Definition make_methods (prog: program) (c: class)
  : list (ident * AST.globdef Clight.fundef Ctypes.type) :=
  map (translate_method prog c) c.(c_methods).

Definition translate_obj (obj: ident * ident): (ident * Ctypes.type) :=
  let (o, c) := obj in
  (o, type_of_inst c).

Definition make_members (c: class): Ctypes.members :=
  map translate_param c.(c_mems) ++ map translate_obj c.(c_objs).

Definition make_struct (c: class): Ctypes.composite_definition :=
  Ctypes.Composite c.(c_name) Ctypes.Struct (make_members c) Ctypes.noattr.

Definition translate_out (c: class) (m: method): Ctypes.composite_definition :=
  Ctypes.Composite
    (prefix_fun c.(c_name) m.(m_name))
    Ctypes.Struct
    (map translate_param m.(m_out))
    Ctypes.noattr.

Definition make_out (c: class): list Ctypes.composite_definition :=
  map (translate_out c) c.(c_methods).

Definition translate_class (prog: program) (c: class)
  : list Ctypes.composite_definition * list (ident * AST.globdef Clight.fundef Ctypes.type) :=
  let methods := make_methods prog c in
  let class_struct := make_struct c in
  let out_structs := make_out c in   
  (class_struct :: out_structs, methods).

Definition glob_bind (bind: ident * type): ident * Ctypes.type :=
  let (x, ty) := bind in
  (glob_id x, cltype ty).

Definition make_in_arg (arg: ident * Ctypes.type): Clight.expr :=
  let (x, ty) := arg in
  Clight.Evar x ty.

Definition make_main
           (prog: program) (node: ident) (ins: list (ident * Ctypes.type))
           (outs: list (ident * Ctypes.type)) (m: method)
  : AST.globdef Clight.fundef Ctypes.type :=
  let out_step_struct := prefix_out node step in
  let tyout_step := type_of_inst (prefix_fun node step) in
  let glob_step_out := Clight.Eaddrof (Clight.Evar (glob_id out_step_struct) tyout_step)
                                      (pointer_of tyout_step) in
  
  let out_reset_struct := prefix_out node reset in
  let tyout_reset := type_of_inst (prefix_fun node reset) in
  let glob_reset_out := Clight.Eaddrof (Clight.Evar (glob_id out_reset_struct) tyout_reset)
                                       (pointer_of  tyout_reset) in
  
  let args_step_in := map make_in_arg ins in
  let glob_self := Clight.Eaddrof (Clight.Evar (glob_id self) (type_of_inst node)) (type_of_inst_p node) in
  let v_self := Clight.Etempvar self (type_of_inst_p node) in
  let v_out := Clight.Etempvar out (pointer_of tyout_step) in
  let args_step := v_self :: v_out :: args_step_in in
  
  let init := Clight.Ssequence (Clight.Sset self glob_self) (Clight.Sset out glob_step_out) in
  let reset := funcall (prefix_fun node reset) [v_self; glob_reset_out] in
  let step := Clight.Ssequence
                (funcall (prefix_fun node step) args_step)
                (fold_right
                   (fun y s =>
                      let '((y, ty), (y', _)) := y in
                      let assign_out :=
                          Clight.Sassign (Clight.Evar y ty)
                                         (Clight.Efield (Clight.Ederef v_out tyout_step) y' ty) in
                      Clight.Ssequence assign_out s
                   ) Clight.Sskip (combine outs m.(m_out))) in
  let loop := Clight.Sloop ((* Clight.Ssequence wait *) step) Clight.Sskip in
  let body := return_zero (Clight.Ssequence init (Clight.Ssequence reset loop)) in
  fundef [] [(* (out_reset_struct, tyout_reset); (out_step_struct, tyout_step) *)] [(self, type_of_inst_p node); (out, pointer_of tyout_step)] Ctypes.type_int32s body.

Definition vardef (env: Ctypes.composite_env) (volatile: bool) (x: ident * Ctypes.type)
  : ident * AST.globdef Clight.fundef Ctypes.type :=
  let (x, ty) := x in
  let ty' := Ctypes.merge_attributes ty (Ctypes.mk_attr volatile None) in
  (x, @AST.Gvar Clight.fundef _
                (AST.mkglobvar ty' [AST.Init_space (Ctypes.sizeof env ty')] false volatile)).

Definition build_composite_env' (types: list Ctypes.composite_definition) :
  { ce | Ctypes.build_composite_env types = Errors.OK ce } + Errors.errmsg.
Proof.
  destruct (Ctypes.build_composite_env types) as [ce|msg].
  - left. exists ce; auto.
  - right. exact msg.
Defined.

Definition check_size (env: Ctypes.composite_env) (id: AST.ident) :=
  match env ! id with
  | Some co =>
    if (Ctypes.co_sizeof co) <=? Int.modulus
    then Errors.OK tt else Errors.Error (Errors.msg "2big")
  | None => Errors.Error (Errors.msg "unknown")
  end.

Fixpoint check_size_env (env: Ctypes.composite_env) (types: list Ctypes.composite_definition)
  : res unit :=
  match types with
  | nil => OK tt
  | Ctypes.Composite id _ _ _ :: types =>
      do _ <- check_size env id;
      check_size_env env types
  end.

Definition make_program'
           (types: list Ctypes.composite_definition)
           (gvars gvars_vol: list (ident * Ctypes.type))
           (defs: list (ident * AST.globdef Clight.fundef Ctypes.type))
           (public: list ident)
           (main: ident) : Errors.res (Ctypes.program Clight.function) :=
  match build_composite_env' types with
  | inl (exist ce P) => 
    do _ <- check_size_env ce types;
    Errors.OK {| Ctypes.prog_defs := map (vardef ce false) gvars ++ map (vardef ce true) gvars_vol ++ defs;
                 Ctypes.prog_public := public;
                 Ctypes.prog_main := main;
                 Ctypes.prog_types := types;
                 Ctypes.prog_comp_env := ce;
                 Ctypes.prog_comp_env_eq := P |}
  | inr msg => Errors.Error msg
  end.

Definition translate (prog: program) (main_node: ident): Errors.res Clight.program :=
  match find_class main_node prog with
  | Some (c, _) =>
    match find_method step c.(c_methods) with
    | Some m =>
      match find_method reset c.(c_methods) with
      | Some _ =>
        let f := glob_id self in
        let step_out := glob_id (prefix_out main_node step) in
        let reset_out := glob_id (prefix_out main_node reset) in
        let ins := map glob_bind m.(m_in) in
        let outs := map glob_bind m.(m_out) in
        let main := make_main prog main_node ins outs m in
        let cs := map (translate_class prog) prog in
        let f_gvar := (f, type_of_inst main_node) in
        let step_out_gvar := (step_out, type_of_inst (prefix_fun main_node step)) in
        let reset_out_gvar := (reset_out, type_of_inst (prefix_fun main_node reset)) in
        let (structs, funs) := split cs in
        let gdefs := concat funs ++ [(main_id, main)] in
        make_program' (concat structs) [f_gvar; step_out_gvar; reset_out_gvar] (outs ++ ins) gdefs [] main_id
      | None => Errors.Error
                  (Errors.msg "ObcToClight: reset function not found")
      end
    | None => Errors.Error
                (Errors.msg "ObcToClight: step function not found")
    end
  | None => Errors.Error [Errors.MSG "ObcToClight: undefined node: '";
                          Errors.CTX main_node; Errors.MSG "'." ]
  end.
