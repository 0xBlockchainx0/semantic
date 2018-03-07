{-# LANGUAGE DataKinds, GeneralizedNewtypeDeriving, MultiParamTypeClasses, ScopedTypeVariables, StandaloneDeriving, TypeApplications, TypeFamilies, TypeOperators, UndecidableInstances #-}
module Analysis.Abstract.Dead where

import Control.Abstract.Addressable
import Control.Abstract.Evaluator
import Data.Abstract.Evaluatable
import Data.Abstract.Value
import Data.Semigroup.Reducer as Reducer
import Data.Set (delete)
import Prologue

-- | The effects necessary for dead code analysis.
type DeadCodeEffects term value = State (Dead term) ': EvaluatorEffects term value


-- | Run a dead code analysis of the given program.
evaluateDead :: forall term value
             .  ( Corecursive term
                , Evaluatable (Base term)
                , Foldable (Base term)
                , FreeVariables term
                , MonadAddressable (LocationFor value) (DeadCodeAnalysis term value)
                , MonadValue value (DeadCodeAnalysis term value)
                , Ord (LocationFor value)
                , Ord term
                , Recursive term
                , Semigroup (CellFor value)
                )
             => term
             -> Final (DeadCodeEffects term value) value
evaluateDead term = run @(DeadCodeEffects term value) . runEvaluator . runDeadCodeAnalysis $ do
  killAll (subterms term)
  evaluateTerm term


-- | A newtype wrapping 'Evaluator' which performs a dead code analysis on evaluation.
newtype DeadCodeAnalysis term value a = DeadCodeAnalysis { runDeadCodeAnalysis :: Evaluator term value (DeadCodeEffects term value) a }
  deriving (Applicative, Functor, Monad, MonadFail)

deriving instance Ord (LocationFor value) => MonadEvaluator (DeadCodeAnalysis term value)


-- | A set of “dead” (unreachable) terms.
newtype Dead term = Dead { unDead :: Set term }
  deriving (Eq, Foldable, Semigroup, Monoid, Ord, Show)

deriving instance Ord term => Reducer term (Dead term)

-- | Update the current 'Dead' set.
killAll :: Dead term -> DeadCodeAnalysis term value ()
killAll = DeadCodeAnalysis . Evaluator . put

-- | Revive a single term, removing it from the current 'Dead' set.
revive :: Ord term => term -> DeadCodeAnalysis term value ()
revive t = DeadCodeAnalysis (Evaluator (modify (Dead . delete t . unDead)))

-- | Compute the set of all subterms recursively.
subterms :: (Ord term, Recursive term, Foldable (Base term)) => term -> Dead term
subterms term = term `cons` para (foldMap (uncurry cons)) term


instance ( Corecursive term
         , Evaluatable (Base term)
         , FreeVariables term
         , MonadAddressable (LocationFor value) (DeadCodeAnalysis term value)
         , MonadValue value (DeadCodeAnalysis term value)
         , Ord term
         , Recursive term
         , Semigroup (CellFor value)
         )
         => MonadAnalysis (DeadCodeAnalysis term value) where
  analyzeTerm term = do
    revive (embedSubterm term)
    eval term

type instance TermFor (DeadCodeAnalysis term value) = term
type instance ValueFor (DeadCodeAnalysis term value) = value
