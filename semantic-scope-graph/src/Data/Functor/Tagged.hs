{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TypeApplications #-}
-- | A functor associating an 'Int' tag value with a datum. Useful for describing unique IDs.
module Data.Functor.Tagged
  ( Tagged (..)
  , Tag
  -- * Lenses
  , identifier
  , contents
  -- * Monadic creation functions
  , taggedM
  , taggedIO
  , unsafeTagged
  -- * Reexports
  , extract
  ) where

import Control.Comonad
import Control.Effect.Fresh
import Control.Lens.Getter
import Control.Lens.Lens
import Data.Function
import Data.Generics.Product
import Data.Int
import Data.Unique
import GHC.Generics
import System.IO.Unsafe

-- | Most identificatory fields are pinned to protobuf id's, which by convention
-- are signed 64-bit values, so that we can convert them efficiently between
-- Int and Int64 (that is, all calls to fromIntegral are eliminated)
type Tag = Int64

-- | If creating 'Tagged' values manually, it is your responsibility
-- to ensure that the provided 'Tag' is actually unique. Consider using 'taggedM'.
data Tagged a = a :# !Tag
  deriving (Functor, Foldable, Traversable, Generic, Show)

infixl 7 :#

contents :: Lens (Tagged a) (Tagged b) a b
contents = position @1

identifier :: Lens' (Tagged a) Tag
identifier = position @2

-- | This is marked as overlappable so that custom types can define
-- their own definitions of equality when wrapped in a Tagged. This
-- may come back to bite us later.
instance {-# OVERLAPPABLE #-} Eq (Tagged a) where
  (==) = (==) `on` view identifier

-- | 'extract' is a handy shortcut for 'view' 'contents'
instance Comonad Tagged where
  extract = view contents
  duplicate (x :# tag) = x :# tag :# tag

-- | Tag a new value by drawing on a 'Fresh' supply.
taggedM :: Has Fresh sig m => a -> m (Tagged a)
taggedM a = (a :#) . fromIntegral <$> fresh

-- | Tag a new value in 'IO'. The supplied values will not be numerically
-- ordered, but are guaranteed to be unique throughout the life of the program.
taggedIO :: a -> IO (Tagged a)
taggedIO a = (a :#) . fromIntegral . hashUnique <$> newUnique

-- This is bad. Don't use it.
unsafeTagged :: a -> Tagged a
unsafeTagged = unsafePerformIO . taggedIO
{-# NOINLINE unsafeTagged #-}
