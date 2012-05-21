%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Core seen as Ty, for System F generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs module {%{EH}Core.SysF.AsTy} import({%{EH}Base.Common},{%{EH}Opts.Base},{%{EH}Error})
%%]

%%[(8 codegen) hs import(qualified {%{EH}Core} as C, qualified {%{EH}Ty} as T)
%%]

%%[(8 codegen) hs import({%{EH}AbstractCore})
%%]

%%[(8 codegen) hs import({%{EH}Core.BindExtract})
%%]

%%[(8 codegen coresysf) hs import({%{EH}Ty.ToSysfTy}) export(module {%{EH}Ty.ToSysfTy})
%%]
 
%%[(8 codegen) hs import({%{EH}Gam})
%%]

%%[(8 codegen) hs import(qualified Data.Map as Map,Data.Maybe)
%%]

%%[(8 codegen) hs import(EH.Util.Pretty,qualified EH.Util.FastSeq as Seq)
%%]

%%[doesWhat doclatex
This module wraps Core in such a way that it behaves as Ty,
i.e. provides the same API.
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Explicit name for Ty
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 hmtyinfer || hmtyast) hs export(Ty)
-- | The type, represented by a term CExpr
type Ty     		= C.SysfTy			-- base ty

-- | Binding the bound
type TyBind			= C.SysfTyBind
type TyBound		= C.SysfTyBound

-- | A sequence of parameters (for now just a single type)
type TySeq			= C.SysfTySeq

%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Conversion interface: only for FFI types, already expanded etc (for now)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen) hs export(ty2TyCforFFI)
-- | Construct a type for use by AbstractCore, specifically for use by FFI
ty2TyCforFFI :: EHCOpts -> T.Ty -> C.CTy
%%[[(8 coresysf)
ty2TyCforFFI o t = C.mkCTy o t (tyToSysfTyBase t)
%%][8
ty2TyCforFFI o t = C.mkCTy o t                 t
%%]]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Construction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen coresysf) hs export(mkTySeq,unTySeq)
-- lift & unlift to TySeq, with mkTySeq . unTySeq == id for singleton sequences
mkTySeq :: Ty -> TySeq
mkTySeq = id -- mkExprSeq
{-# INLINE mkTySeq #-}

unTySeq :: TySeq -> Ty
unTySeq = id -- unExprSeq
{-# INLINE unTySeq #-}
%%]

%%[(8 codegen coresysf) hs export(mkTySeq1,unTySeq1)
mkTySeq1 :: Ty -> TySeq
mkTySeq1 = id -- mkExprSeq1
{-# INLINE mkTySeq1 #-}

unTySeq1 :: TySeq -> Ty
unTySeq1 = id -- unExprSeq1
{-# INLINE unTySeq1 #-}
%%]

%%[(8 codegen coresysf) hs export(mkTyThunk)
mkTySeqThunk :: TySeq -> Ty
mkTySeqThunk t = t -- mkTySeqArrow1Ty [] t
{-# INLINE mkTySeqThunk #-}

mkTyThunk :: Ty -> Ty
mkTyThunk t = t -- mkTyArrow1Ty [] t
{-# INLINE mkTyThunk #-}
%%]

%%[(8 codegen coresysf) hs export(tyUnThunkTySeq,tyUnThunkTy)
tyUnThunkTySeq :: Ty -> TySeq
-- tyUnThunkTySeq (Expr_Arrow (Expr_Seq []) r) = r
tyUnThunkTySeq t                            = t -- tyErr "TyCore.tyUnThunkTySeq"
{-# INLINE tyUnThunkTySeq #-}

tyUnThunkTy :: Ty -> Ty
tyUnThunkTy = unTySeq . tyUnThunkTySeq
{-# INLINE tyUnThunkTy #-}
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Deconstruction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Code substitution
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

??

%%[(8 codegen coresysf) hs export(CSubst)
type CSubstInfo = CSubstInfo' C.CExpr C.CMetaVal C.CBind C.CBound C.CTy
type CSubst     = CSubst'     C.CExpr C.CMetaVal C.CBind C.CBound C.CTy
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Type manipulation: deriving type structures, e.g. from signature to actual application
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8888 codegen coresysf) hs export(tyStripL1Args)
-- strip L1 argument bindings of an arrow type
tyStripL1Args :: Ty -> Ty
tyStripL1Args t
  = foldr Expr_Arrow r $ filter (\x -> case unSeq x of {ExprSeq1_L0Bind _ _ -> False ; _ -> True}) as
  where (as,r) = appUnArr t
%%]

%%[(8 codegen coresysf) hs
-- convert bind to bound
tyBindToBound
  :: (ACoreBindAspectKeyS -> MetaLev -> CLbl -> Bool)		-- selection
     -> (HsName -> TyBound -> x)							-- when found
     -> (HsName -> TyBound -> x)							-- when not found
     -> TyBind
     -> x
tyBindToBound sel convYes convNo bind@(C.CBind_Bind n bbs)
  | null bs   = convNo  n $ head bbs
  | otherwise = convYes n $ head bs
  where bs = cbindExtract (noBoundSel {selVal = sel}) bind
%%]

%%[(8 codegen coresysf) hs export(tyL0BindToL1Val)
-- convert type level l<n-1> binding to l<n> argument, used to convert from type signature to value application
tyL0BindToL1Val :: MetaLev -> TyBind -> TyBound
tyL0BindToL1Val mlev
  = tyBindToBound
      (\a m l -> a == acbaspkeyDefault) --  && (m-1) == mlev)
      (\n (C.CBound_Val a m l _) -> C.CBound_Val a m l (acoreVar n))
      (\_ b                      -> b                                  )
%%]
  where tosq (ExprSeq1_L0Bind n   _) = ExprSeq1_L1Val (Expr_Var n)
        tosq (ExprSeq1_L1Bind n   _) = ExprSeq1_L2Val (Expr_Var n)
        tosq s                       = s
        to   (Expr_Seq  s) = Expr_Seq  (map tosq s)
        to   (Expr_Seq1 s) = Expr_Seq1 (    tosq s)
        to   t             = t

%%[(8 codegen coresysf) hs export(tyL0BindToL1Bind)
-- convert type level l0 binding to l1 binding, used to convert from type signature to value abstraction
tyL0BindToL1Bind :: TyBind -> TyBind
tyL0BindToL1Bind
  = tyBindToBound
      (\a _ _ -> a == acbaspkeyDefault)
      (\n (C.CBound_Val a m l e) -> C.CBind_Bind n [C.CBound_Val a (m+1) l e])
      (\n b                      -> C.CBind_Bind n [b                       ])
%%]
  = to t
  where tosq (ExprSeq1_L0Bind n   t) = ExprSeq1_L1Bind n t
        tosq (ExprSeq1_L1Bind n   t) = ExprSeq1_L2Bind n t
        tosq s                       = s
        to   (Expr_Seq  s) = Expr_Seq  (map tosq s)
        to   (Expr_Seq1 s) = Expr_Seq1 (    tosq s)
        to   t             = t

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Checking: environment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen coresysf) hs export(SysfGam,emptySysfGam)
type SysfGam = Gam ACoreBindRef Ty

emptySysfGam :: SysfGam
emptySysfGam = emptyGam
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Matching: input/output flow via records
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[(8 codegen coresysf) hs export(MatchIn(..),emptyMatchIn)
-- match input/options
data MatchIn
  = MatchIn
      { minAllowLBind       :: Bool     -- allow tvars in left/first type to bind
      , minAllowRL0BindBind :: Bool     --
      , minAllowAlphaRename :: Bool     --
      , minMetaLev          :: MetaLev  -- the base meta level
      , minEnv              :: SysfGam      -- introduced bindings
      }

emptyMatchIn :: MatchIn
emptyMatchIn = MatchIn False False False metaLevVal emptySysfGam
%%]

%%[(8 codegen coresysf) hs export(allowLBindMatchIn)
allowLBindMatchIn :: MatchIn
allowLBindMatchIn = emptyMatchIn {minAllowLBind = True}

allowRL0BindMatchIn :: MatchIn
allowRL0BindMatchIn = emptyMatchIn {minAllowRL0BindBind = True}
%%]

%%[(8 codegen coresysf) hs export(MatchOut(..))
-- match output/result
data MatchOut
  = MatchOut
      { moutErrL            :: [Err]    -- errors
      , moutCSubst          :: CSubst   -- tvar bindings, possibly
      , moutEnv             :: SysfGam      -- introduced bindings
      }

emptyMatchOut :: MatchOut
emptyMatchOut = MatchOut [] emptyCSubst emptySysfGam

moutHasErr :: MatchOut -> Bool
moutHasErr = not . null . moutErrL

moutErrs :: MatchOut -> ErrSq
moutErrs = Seq.fromList . moutErrL
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Matching
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[doesWhat.match doclatex
Matching is asymmetric in the following:
\begin{itemize}
\item
 When tyvar binding is allowed, a var in the first (left) param may bind.
 Used by TyCore generation to find instantiated types.
\item
 When toplevel L0Bind binding is allowed, a var in the toplevel second (right) may bind.
 Used by TyCore checking to match actual param to formal param of a function.
\end{itemize}
For the rest, all matches are exact on syntactic structure.
%%]

%%[(8 codegen coresysf) hs
match' :: MatchIn -> Ty -> Ty -> MatchOut
match' min ex1 ex2
  = m min emptyMatchOut ex1 ex2
  where -- matching: var
        m min mout      t1@(C.CExpr_Var v1)             t2@(C.CExpr_Var v2)
            | v1 == v2                                                        =   mout

        m min mout      t1@(C.CExpr_Var v1)             t2
            | isJust mbv                                                        =   m min mout (fromJust mbv) t2
            where mbv = gamLookupMetaLev (minMetaLev min) v1 (minEnv min)
{-
        m min mout      t1                              t2@(Expr_Var v2)
            | isJust mbv                                                        =   m min mout t1 (fromJust mbv)
            where mbv = envLookup' v2 (minMetaLev min) (minEnv min)

        m min mout      t1@(Expr_Var v1)                t2@(Expr_Var v2)
            | v1 == v2                                                          =   mout
            | minAllowLBind min                                                 =   bind mout v1 t2
-}
{- NO?
        -- matching: constant
        m min mout      t1@(Expr_Tup n1)                t2@(Expr_Tup n2)
            | n1 == n2                                                          =   mout
-}
{-
        -- matching: annotations are ignored
        m min mout      t1@(Expr_Ann _ t1')             t2                      =   m min mout t1' t2
        m min mout      t1                              t2@(Expr_Ann _ t2')     =   m min mout t1  t2'
        
        -- matching: structure with binding intro's
        m min mout      t1@(Expr_Arrow  a1 r1)          t2@(Expr_Arrow  a2 r2)  =   mm' ( \i o -> i {minEnv = moutEnv o `envUnion` minEnv i}
                                                                                        , \o -> o {moutEnv = moutEnv mout}
                                                                                        )
                                                                                        m min mout [(a1,a2),(r1,r2)]
        -- matching: structure without binding intro's
        m min mout      t1@(Expr_App    f1 a1)          t2@(Expr_App    f2 a2)  =   mm m min mout [(f1,f2),(a1,a2)]
%%[[1010
        m min mout      t1@(Ty_ExtRec e1 b1)            t2@(Ty_ExtRec e2 b2)    =   mm m min mout [(e1,e2),(b1,b2)]
%%]]
        m min mout      t1@(Expr_Seq1   s1)             t2@(Expr_Seq1   s2)     =   ms1 min mout s1 s2
        m min mout      t1@(Expr_Seq    s1)             t2@(Expr_Seq    s2)     =   mm ms1 min mout (zip s1 s2)
        m min mout      t1@(Expr_Prod   s1)             t2@(Expr_Prod   s2)     =   mm ms1 min mout (zip s1 s2)
        m min mout      t1@(Expr_Sum    s1)             t2@(Expr_Sum    s2)     =   mm ms1 min mout (zip s1 s2)
        m min mout      t1@(Expr_Node   s1)             t2@(Expr_Node   s2)     =   mm ms1 min mout (zip s1 s2)
-}
{- NO?
        m min mout      t1@(Expr_Node tg1 s1)           t2@(Expr_Node tg2 s2)  
            | tg1 == tg2                                                        =   mm ms1 min mout (zip s1 s2)
        m min mout      t1@(Ty_Rec    f1)               t2@(Ty_Rec    f2)       =   mm mf1 mout (zip f1 f2)
-}

        -- error
        m min mout      t1                              t2                      =   err mout t1 t2

        -- matching: 1 record field
{-
        mf1 mout    s1@(TyFld_Fld n1 t1)            s2@(TyFld_Fld n2 t2)
            | n1 == n2                                                          =   m min mout t1 t2
            | otherwise                                                         =   err' mout (pp n1) (pp n2)
-}
{-
        -- matching: 1 sequence element
        ms1 min mout    s1@(ExprSeq1_L0Val t1  )        s2@(ExprSeq1_L0Bind n2   _)
            | minAllowRL0BindBind min                                               =   m (min {minAllowLBind=True}) mout (Expr_Var n2) t1
        ms1 min mout    s1@(ExprSeq1_L0Val t1  )        s2@(ExprSeq1_L0Val t2  )    =   m min mout t1 t2
        ms1 min mout    s1@(ExprSeq1_L0LblVal _ t1)     s2@(ExprSeq1_L0LblVal _ t2) =   m min mout t1 t2
        ms1 min mout    s1@(ExprSeq1_L0TagVal _ t1)     s2@(ExprSeq1_L0TagVal _ t2) =   m min mout t1 t2
        ms1 min mout    s1@(ExprSeq1_L0Bind n1   t1)    s2@(ExprSeq1_L0Bind n2   t2)
            | n1 == n2                                                              =   m (min {minMetaLev = minMetaLev min + 1}) mout t1 t2
            | minAllowAlphaRename min                                               =   let mout' = m (min {minMetaLev = minMetaLev min + 1}) mout t1 t2
                                                                                        in  mout' {moutEnv = envSingleton n1 (minMetaLev min) (Expr_Var n2) `envUnion` moutEnv mout' }
            | otherwise                                                             =   err' mout (pp n1) (pp n2)
        ms1 min mout    s1@(ExprSeq1_L1Val t1)          s2@(ExprSeq1_L1Val t2)      =   m (min {minMetaLev = minMetaLev min + 1}) mout t1 t2
        ms1 min mout    s1@(ExprSeq1_L1Bind v1 k1)      s2@(ExprSeq1_L1Bind v2 k2)
            | v1 == v2                                                              =   m (min {minMetaLev = minMetaLev min + 2}) mout k1 k2
            | otherwise                                                             =   err' mout (pp v1) (pp v2)
        ms1 min mout    s1@(ExprSeq1_L2Val t1)          s2@(ExprSeq1_L2Val t2)      =   m (min {minMetaLev = minMetaLev min + 2}) mout t1 t2
        ms1 min mout    s1@(ExprSeq1_L2Bind v1 k1)      s2@(ExprSeq1_L2Bind v2 k2)
            | v1 == v2                                                              =   m (min {minMetaLev = minMetaLev min + 3}) mout k1 k2
            | otherwise                                                             =   err' mout (pp v1) (pp v2)
        ms1 min mout    s1                              s2                          =   err' mout (pp s1) (pp s2)

        -- match multiple
        mm' (mout2min,finalize) m min mout   ((t1,t2):tts)     
            | moutHasErr mout'              = finalize mout'
            | otherwise                     = mm m (mout2min min mout') mout' tts
            where mout' = m min mout t1 t2
        mm' (_       ,finalize) m min mout   _
                                            = finalize mout
        mm                                  = mm' (const,id)

        -- binding of tvar for output
        bind mout v t = mout {moutCSubst = acoreCSubstFromNmTyL [(v,t)] `cSubstApp` moutCSubst mout}
-}
        -- error
        err' mout pp1 pp2 = mout {moutErrL = [rngLift emptyRange Err_TyCoreMatchClash (pp ex1) (pp ex2) pp1 pp2]}
        err  mout t1  t2  = err' mout (pp t1) (pp t2)
%%]

%%[(8 codegen coresysf) hs export(matchBind)
matchBind :: Ty -> Ty -> MatchOut
matchBind = match' allowLBindMatchIn

matchRL0Bind :: MetaLev -> Ty -> Ty -> MatchOut
matchRL0Bind l = match' (allowRL0BindMatchIn {minMetaLev = l})

match :: MetaLev -> Ty -> Ty -> MatchOut
match l = match' (emptyMatchIn {minMetaLev = l, minAllowAlphaRename = True})
%%]

