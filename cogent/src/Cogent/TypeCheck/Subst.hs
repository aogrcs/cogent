--
-- Copyright 2016, NICTA
--
-- This software may be distributed and modified according to the terms of
-- the GNU General Public License version 2. Note that NO WARRANTY is provided.
-- See "LICENSE_GPLv2.txt" for details.
--
-- @TAG(NICTA_GPL)
--

module Cogent.TypeCheck.Subst where

import Cogent.Surface
import Cogent.TypeCheck.Base
-- import Cogent.TypeCheck.Util
import Cogent.Util

import qualified Data.IntMap as M
import Data.Maybe
import Data.Monoid hiding (Alt)
import Prelude hiding (lookup)

newtype Subst = Subst (M.IntMap TCType)

lookup :: Subst -> Int -> TCType
lookup s@(Subst m) i = maybe (U i) (apply s) (M.lookup i m)

instance Monoid Subst where
  mempty = Subst M.empty
  mappend a@(Subst a') b@(Subst b')
    = Subst (a' <> b')

apply :: Subst -> TCType -> TCType
apply = forFlexes . lookup

applyAlts :: Subst -> [Alt TCName TCExpr] -> [Alt TCName TCExpr]
applyAlts = map . applyAlt

applyAlt :: Subst -> Alt TCName TCExpr -> Alt TCName TCExpr
applyAlt s = fmap (applyE s) . ffmap (fmap (apply s))

applyCtx :: Subst -> ErrorContext -> ErrorContext
applyCtx s (SolvingConstraint c) = SolvingConstraint (applyC s c)
applyCtx s (InExpression e t) = InExpression e (apply s t)
applyCtx s c = c

applyErr :: Subst -> TypeError -> TypeError
applyErr s (TypeMismatch t1 t2)     = TypeMismatch (fmap (apply s) t1) (fmap (apply s) t2)
applyErr s (RequiredTakenField f t) = RequiredTakenField f (apply s t)
applyErr s (TypeNotShareable t m)   = TypeNotShareable (apply s t) m
applyErr s (TypeNotEscapable t m)   = TypeNotEscapable (apply s t) m
applyErr s (TypeNotDiscardable t m) = TypeNotDiscardable (apply s t) m
applyErr s (PatternsNotExhaustive t ts) = PatternsNotExhaustive (apply s t) ts
applyErr s (UnsolvedConstraint c os) = UnsolvedConstraint (applyC s c) os
applyErr s (NotAFunctionType t) = NotAFunctionType (apply s t)
applyErr s e = e

applyC :: Subst -> Constraint -> Constraint
applyC s (a :< b) = fmap (apply s) a :< fmap (apply s) b
applyC s (a :& b) = applyC s a :& applyC s b
applyC s (a :@ c) = applyC s a :@ applyCtx s c
applyC s (Upcastable a b) = apply s a `Upcastable` apply s b
applyC s (Share t m) = Share (apply s t) m
applyC s (Drop t m) = Drop (apply s t) m
applyC s (Escape t m) = Escape (apply s t) m
applyC s (Unsat e) = Unsat (applyErr s e)
applyC s Sat = Sat
applyC s (Exhaustive t ps) = Exhaustive (apply s t) (fmap (fmap (fmap (apply s))) ps)

applyE :: Subst -> TCExpr -> TCExpr
applyE s (TE t x p) = TE (apply s t)
                      ( fmap (fmap (apply s))
                      $ ffmap (fmap (apply s))
                      $ fffmap (apply s) x)
                      p

singleton :: Int -> TCType -> Subst
singleton i t = Subst (M.fromList [(i, t)])

null :: Subst -> Bool
null (Subst x) = M.null x
