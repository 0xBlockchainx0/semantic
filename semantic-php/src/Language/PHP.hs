{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}

-- | Semantic functionality for PHP programs.
module Language.PHP
  ( Term (..),
    TreeSitter.PHP.tree_sitter_php,
  )
where

import AST.Marshal.JSON
import qualified AST.Unmarshal as TS
import Data.Proxy
import qualified Language.PHP.AST as PHP
import qualified Language.PHP.Tags as PHPTags
import Scope.Graph.Convert
import qualified Tags.Tagging.Precise as Tags
import qualified TreeSitter.PHP (tree_sitter_php)

newtype Term a = Term {getTerm :: PHP.Program a}
  deriving (MarshalJSON)

instance TS.SymbolMatching Term where
  matchedSymbols _ = TS.matchedSymbols (Proxy :: Proxy PHP.Program)
  showFailure _ = TS.showFailure (Proxy :: Proxy PHP.Program)

instance TS.Unmarshal Term where
  matchers = fmap (fmap (TS.hoist Term)) TS.matchers

instance Tags.ToTags Term where
  tags src = Tags.runTagging src . PHPTags.tags . getTerm

instance ToScopeGraph Term where
  type FocalPoint Term _ = ()
  scopeGraph _ = todo "Implement scope graphs for PHP"
