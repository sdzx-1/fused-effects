{-# LANGUAGE DefaultSignatures, EmptyCase, FlexibleContexts, FlexibleInstances, MultiParamTypeClasses, RankNTypes, TypeOperators #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-} -- for the default signature for hmap

-- | Provides the 'HFunctor' and 'Effect' classes that effect types implement.
--
-- @since 1.0.0.0
module Control.Effect.Class
( HFunctor(..)
, hmapDefault
, handleCoercible
, Effect(..)
-- * Generic deriving of 'Effect' instances.
, GEffect(..)
) where

import Data.Coerce
import Data.Functor.Identity
import GHC.Generics

-- | Higher-order functors of kind @(* -> *) -> (* -> *)@ map functors to functors.
--
--   All effects must be 'HFunctor's.
--
-- @since 1.0.0.0
class HFunctor h where
  -- | Higher-order functor map of a natural transformation over higher-order positions within the effect.
  --
  -- A definition for 'hmap' over first-order effects can be derived automatically provided a 'Generic1' instance is available.
  hmap :: (Monad m, Functor n) => (forall x . m x -> n x) -> (h m a -> h n a)
  default hmap :: (Monad m, Functor n, Functor (h n), Effect h) => (forall x . m x -> n x) -> (h m a -> h n a)
  hmap = hmapDefault
  {-# INLINE hmap #-}


hmapDefault :: (Effect sig, Functor n, Functor (sig n), Monad m) => (forall x . m x -> n x) -> (sig m a -> sig n a)
hmapDefault f = fmap runIdentity . handle (Identity ()) (fmap Identity . f . runIdentity)


-- | Thread a 'Coercible' carrier through an 'HFunctor'.
--
--   This is applicable whenever @f@ is 'Coercible' to @g@, e.g. simple @newtype@s.
--
-- @since 1.0.0.0
handleCoercible :: (HFunctor sig, Monad f, Functor g, Coercible f g) => sig f a -> sig g a
handleCoercible = hmap coerce
{-# INLINE handleCoercible #-}


-- | The class of effect types, which must:
--
--   1. Be functorial in their last two arguments, and
--   2. Support threading effects in higher-order positions through using the carrier’s suspended state.
--
-- All first-order effects (those without existential occurrences of @m@) admit a default definition of 'handle' provided a 'Generic1' instance is available for the effect.
--
-- @since 1.0.0.0
class HFunctor sig => Effect sig where
  -- | Handle any effects in a signature by threading the carrier’s state all the way through to the continuation.
  handle :: (Functor f, Monad m)
         => f ()
         -> (forall x . f (m x) -> n (f x))
         -> sig m a
         -> sig n (f a)
  default handle :: (Functor f, Monad m, Generic1 (sig m), Generic1 (sig n), GEffect m n (Rep1 (sig m)) (Rep1 (sig n)))
                 => f ()
                 -> (forall x . f (m x) -> n (f x))
                 -> sig m a
                 -> sig n (f a)
  handle state handler = to1 . ghandle state handler . from1
  {-# INLINE handle #-}


-- | Generic implementation of 'Effect'.
class GEffect m m' rep rep' where
  -- | Generic implementation of 'handle'.
  ghandle :: (Functor f, Monad m)
          => f ()
          -> (forall x . f (m x) -> m' (f x))
          -> rep a
          -> rep' (f a)

instance GEffect m m' rep rep' => GEffect m m' (M1 i c rep) (M1 i c rep') where
  ghandle state handler = M1 . ghandle state handler . unM1
  {-# INLINE ghandle #-}

instance (GEffect m m' l l', GEffect m m' r r') => GEffect m m' (l :+: r) (l' :+: r') where
  ghandle state handler (L1 l) = L1 (ghandle state handler l)
  ghandle state handler (R1 r) = R1 (ghandle state handler r)
  {-# INLINE ghandle #-}

instance (GEffect m m' l l', GEffect m m' r r') => GEffect m m' (l :*: r) (l' :*: r') where
  ghandle state handler (l :*: r) = ghandle state handler l :*: ghandle state handler r
  {-# INLINE ghandle #-}

instance GEffect m m' V1 V1 where
  ghandle _ _ v = case v of {}
  {-# INLINE ghandle #-}

instance GEffect m m' U1 U1 where
  ghandle _ _ = coerce
  {-# INLINE ghandle #-}

instance GEffect m m' (K1 R c) (K1 R c) where
  ghandle _ _ = coerce
  {-# INLINE ghandle #-}

instance GEffect m m' Par1 Par1 where
  ghandle state _ = Par1 . (<$ state) . unPar1
  {-# INLINE ghandle #-}

instance (Functor f, GEffect m m' g g') => GEffect m m' (f :.: g) (f :.: g') where
  ghandle state handler = Comp1 . fmap (ghandle state handler) . unComp1
  {-# INLINE ghandle #-}

instance GEffect m m' (Rec1 m) (Rec1 m') where
  ghandle state handler = Rec1 . handler . (<$ state) . unRec1
  {-# INLINE ghandle #-}

instance Effect f => GEffect m m' (Rec1 (f m)) (Rec1 (f m')) where
  ghandle state handler = Rec1 . handle state handler . unRec1
  {-# INLINE ghandle #-}
