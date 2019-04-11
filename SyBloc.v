Require Export Velus.CoreExpr.
Require Export Velus.SyBloc.SBSyntax.
Require Export Velus.SyBloc.SBIsBlock.
Require Export Velus.SyBloc.SBOrdered.
Require Export Velus.SyBloc.SBSemantics.
Require Export Velus.SyBloc.SBIsLast.
Require Export Velus.SyBloc.SBIsVariable.
Require Export Velus.SyBloc.SBIsDefined.
Require Export Velus.SyBloc.SBIsFree.
Require Export Velus.SyBloc.SBWellDefined.
Require Export Velus.SyBloc.SBSchedule.
Require Export Velus.SyBloc.SBTyping.
Require Export Velus.SyBloc.SBClocking.
Require Export Velus.SyBloc.SBClockingSemantics.

Require Import Velus.Common.

Module Type SYBLOC
       (Ids   : IDS)
       (Op    : OPERATORS)
       (OpAux : OPERATORS_AUX Op)
       (Str   : STREAM        Op OpAux)
       (CE    : COREEXPR Ids  Op OpAux Str).

  Declare Module Export Syn  : SBSYNTAX      Ids Op       CE.Syn.
  Declare Module Export Block: SBISBLOCK     Ids Op       CE.Syn Syn.
  Declare Module Export Ord  : SBORDERED     Ids Op       CE.Syn Syn Block.
  Declare Module Export Sem  : SBSEMANTICS   Ids Op OpAux CE.Syn Syn Block Ord Str CE.Sem.
  Declare Module Export Last : SBISLAST      Ids Op       CE.Syn Syn.
  Declare Module Export Var  : SBISVARIABLE  Ids Op       CE.Syn Syn.
  Declare Module Export Def  : SBISDEFINED   Ids Op       CE.Syn Syn Var Last.
  Declare Module Export Free : SBISFREE      Ids Op       CE.Syn Syn CE.IsF.
  Declare Module Export Wdef : SBWELLDEFINED Ids Op       CE.Syn Syn Block Ord Var Last Def CE.IsF Free.
  Declare Module Export Typ  : SBTYPING      Ids Op       CE.Syn Syn CE.Typ.
  Declare Module Export Clo  : SBCLOCKING    Ids Op       CE.Syn Syn Last Var Def Block Ord CE.Clo.
  Declare Module Export CloSem : SBCLOCKINGSEMANTICS Ids Op OpAux CE.Syn Syn Str Last Var Def Block Ord
                                                     CE.Sem Sem CE.Clo Clo CE.CloSem.

  Declare Module Scheduler   : SBSCHEDULE    Ids Op OpAux Str CE Syn Block Ord Sem Typ Var Last Def Clo.

End SYBLOC.

Module SyBlocFun
       (Ids   : IDS)
       (Op    : OPERATORS)
       (OpAux : OPERATORS_AUX Op)
       (Str   : STREAM        Op OpAux)
       (CE    : COREEXPR Ids  Op OpAux Str)
<: SYBLOC Ids Op OpAux Str CE.

  Module Export Syn   := SBSyntaxFun      Ids Op       CE.Syn.
  Module Export Block := SBIsBlockFun     Ids Op       CE.Syn Syn.
  Module Export Ord   := SBOrderedFun     Ids Op       CE.Syn Syn Block.
  Module Export Sem   := SBSemanticsFun   Ids Op OpAux CE.Syn Syn Block Ord Str CE.Sem.
  Module Export Last  := SBIsLastFun      Ids Op       CE.Syn Syn.
  Module Export Var   := SBIsVariableFun  Ids Op       CE.Syn Syn.
  Module Export Def   := SBIsDefinedFun   Ids Op       CE.Syn Syn Var Last.
  Module Export Free  := SBIsFreeFun      Ids Op       CE.Syn Syn CE.IsF.
  Module Export Wdef  := SBWellDefinedFun Ids Op       CE.Syn Syn Block Ord Var Last Def CE.IsF Free.
  Module Export Typ   := SBTypingFun      Ids Op       CE.Syn Syn CE.Typ.
  Module Export Clo   := SBClockingFun    Ids Op       CE.Syn Syn Last Var Def Block Ord CE.Clo.
  Module Export CloSem := SBClockingSemanticsFun Ids Op OpAux CE.Syn Syn Str Last Var Def Block Ord
                                                     CE.Sem Sem CE.Clo Clo CE.CloSem.

  Module Scheduler    := SBScheduleFun    Ids Op OpAux Str CE Syn Block Ord Sem Typ Var Last Def Clo.
End SyBlocFun.
