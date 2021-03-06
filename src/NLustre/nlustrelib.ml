(* *********************************************************************)
(*                                                                     *)
(*                 The Vélus verified Lustre compiler                  *)
(*                                                                     *)
(*             (c) 2019 Inria Paris (see the AUTHORS file)             *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique. All rights reserved. This file is distributed under   *)
(*  the terms of the INRIA Non-Commercial License Agreement (see the   *)
(*  LICENSE file).                                                     *)
(*                                                                     *)
(* *********************************************************************)

open Format
open Veluscommon

open BinNums
open BinPos
open FMapPositive

type ident = ClockDefs.ident
type idents = ident list

module type SYNTAX =
  sig
    type clock
    type typ
    type const
    type exp
    type cexp

    type equation =
    | EqDef of ident * clock * cexp
    | EqApp of idents * clock * ident * exp list * (ident * clock) option
    | EqFby of ident * clock * const * exp

    type node = {
      n_name : ident;
      n_in   : (ident * (typ * clock)) list;
      n_out  : (ident * (typ * clock)) list;
      n_vars : (ident * (typ * clock)) list;
      n_eqs  : equation list }

    type global = node list
  end

module PrintFun
    (CE: Coreexprlib.SYNTAX)
    (NL: SYNTAX with type clock = CE.clock
                 and type typ   = CE.typ
                 and type const = CE.const
                 and type exp   = CE.exp
                 and type cexp  = CE.cexp)
    (PrintOps: PRINT_OPS with type typ   = CE.typ
                          and type const = CE.const
                          and type unop  = CE.unop
                          and type binop = CE.binop) :
  sig
    val print_equation   : formatter -> NL.equation -> unit
    val print_node       : Format.formatter -> NL.node -> unit
    val print_global     : Format.formatter -> NL.global -> unit
    val print_fullclocks : bool ref
  end
  =
  struct

    include Coreexprlib.PrintFun (CE) (PrintOps)

    let rec print_equation p eq =
      match eq with
      | NL.EqDef (x, ck, e) ->
          fprintf p "@[<hov 2>%a =@ %a;@]"
            print_ident x
            print_cexp e
      | NL.EqApp (xs, ck, f, es, None) ->
          fprintf p "@[<hov 2>%a =@ %a(@[<hv 0>%a@]);@]"
            print_pattern xs
            print_ident f
            (print_comma_list print_exp) es
      | NL.EqApp (xs, ck, f, es, Some (r, ck_r)) ->
        fprintf p "@[<hov 2>%a =@ (restart@ %a@ every@ %a)(@[<hv 0>%a@]);@]"
          print_pattern xs
          print_ident f
          print_ident r
          (print_comma_list print_exp) es
      | NL.EqFby (x, ck, v0, e) ->
          fprintf p "@[<hov 2>%a =@ %a fby@ %a;@]"
            print_ident x
            PrintOps.print_const v0
            print_exp e

    let print_equations p =
      pp_print_list ~pp_sep:pp_force_newline print_equation p

    let print_node p { NL.n_name = name;
                       NL.n_in   = inputs;
                       NL.n_out  = outputs;
                       NL.n_vars = locals;
                       NL.n_eqs  = eqs } =
      fprintf p "@[<v>\
                 @[<hov 0>\
                 @[<h>node %a (%a)@]@;\
                 @[<h>returns (%a)@]@;\
                 @]@;\
                 %a\
                 @[<v 2>let@;%a@;<0 -2>@]\
                 tel@]"
        print_ident name
        print_decl_list inputs
        print_decl_list outputs
        (print_comma_list_as "var" print_decl) locals
        print_equations (List.rev eqs)

    let print_global p prog =
      fprintf p "@[<v 0>%a@]@."
        (pp_print_list ~pp_sep:(fun p () -> fprintf p "@;@;") print_node)
        (List.rev prog)
  end
