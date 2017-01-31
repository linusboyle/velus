(* *********************************************************************)
(*                    The Velus Lustre compiler                        *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the GNU General Public License as published by  *)
(*  the Free Software Foundation, either version 2 of the License, or  *)
(*  (at your option) any later version.  This file is also distributed *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(* This pretty-printer draws on the work of Xavier Leroy for the CompCert
   project (CompCert/cfrontend/PrintCsyntax.ml/PrintClight.ml). *)

open Format
open Camlcoq
open Veluscommon

module ClightOpNames =
  struct
    let name_unop ty = PrintCsyntax.name_unop
    let name_binop ty = PrintCsyntax.name_binop
  end

module LustreOpNames =
  struct
    let is_bool = function
    | Interface.Op.Tint (Ctypes.IBool, _) -> true
    | _ -> false

    let name_unop ty = function
      | Cop.Onotbool -> "not"
      | Cop.Onotint  -> "lnot"
      | Cop.Oneg     -> "-"
      | Cop.Oabsfloat -> "__builtin_fabs"

    let name_binop ty = function
      | Cop.Oadd -> "+"
      | Cop.Osub -> "-"
      | Cop.Omul -> "*"
      | Cop.Odiv -> "/"
      | Cop.Omod -> "mod"
      | Cop.Oand -> if is_bool ty then "and" else "land"
      | Cop.Oor  -> if is_bool ty then "or"  else "lor"
      | Cop.Oxor -> if is_bool ty then "xor" else "lxor"
      | Cop.Oshl -> "lsl"
      | Cop.Oshr -> "lsr"
      | Cop.Oeq  -> "="
      | Cop.One  -> "<>"
      | Cop.Olt  -> "<"
      | Cop.Ogt  -> ">"
      | Cop.Ole  -> "<="
      | Cop.Oge  -> ">="
  end

module PrintClightOpsFun (OpNames : sig
    val name_unop  : Interface.Op.coq_type -> Cop.unary_operation -> string
    val name_binop : Interface.Op.coq_type -> Cop.binary_operation -> string
  end) =
  struct
    module Ops = Interface.Op

    type typ   = Ops.coq_type
    type const = Ops.const
    type unop  = Ops.unop
    type binop = Ops.binop

    let print_typ p ty = Ops.string_of_type ty |> fmt_coqstring p

    let print_const p c =
      match c with
      | Ops.Cint (n, Ctypes.I32, Ctypes.Unsigned) ->
          fprintf p "%luU"   (camlint_of_coqint n)
      | Ops.Cint (n, _, _) ->
          fprintf p "%ld"    (camlint_of_coqint n)
      | Ops.Cfloat f ->
          fprintf p "%.15F"  (camlfloat_of_coqfloat f)
      | Ops.Csingle f ->
          fprintf p "%.15Ff"   (camlfloat_of_coqfloat32 f)
      | Ops.Clong (n, Ctypes.Unsigned) ->
          fprintf p "%LuLLU" (camlint64_of_coqint n)
      | Ops.Clong (n, _) ->
          fprintf p "%LdLL"  (camlint64_of_coqint n)

    let print_unop p uop ty print_exp e =
      match uop with
      | Ops.UnaryOp op ->
          fprintf p "%s %a" (OpNames.name_unop ty op) print_exp e
      | Ops.CastOp ty ->
          fprintf p "(%a : %a)" print_exp e print_typ ty

    let print_binop p op ty print_exp e1 e2 =
      fprintf p "%a@ %s %a" print_exp e1
                            (OpNames.name_binop ty op)
                            print_exp e2
      
    let prec_unop op = (15, RtoL)
    let prec_binop =
      let open Cop in function
        | Omul|Odiv|Omod  -> (13, LtoR)
        | Oadd|Osub       -> (12, LtoR)
        | Oshl|Oshr       -> (11, LtoR)
        | Olt|Ogt|Ole|Oge -> (10, LtoR)
        | Oeq|One         -> ( 9, LtoR)
        | Oand            -> ( 8, LtoR)
        | Oxor            -> ( 7, LtoR)
        | Oor             -> ( 6, LtoR)
  end

module PrintNLustre = Nlustrelib.PrintFun
  (struct
      include Instantiator.Clks
      include Instantiator.NL.Syn
      type typ   = Interface.Op.coq_type
      type const = Interface.Op.const
      type unop  = Interface.Op.unop
      type binop = Interface.Op.binop
   end) (PrintClightOpsFun (ClightOpNames))

module PrintObc = Obclib.PrintFun
  (struct
      include Instantiator.Obc.Syn
      type typ   = Interface.Op.coq_type
      type const = Interface.Op.const
      type unop  = Interface.Op.unop
      type binop = Interface.Op.binop
   end) (PrintClightOpsFun (ClightOpNames))

module Scheduler = Nlustrelib.SchedulerFun
  (struct
      include Instantiator.Clks
      include Instantiator.NL.Syn
      type typ   = Interface.Op.coq_type
      type const = Interface.Op.const
      type unop  = Interface.Op.unop
      type binop = Interface.Op.binop
   end)

