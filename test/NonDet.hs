{-# LANGUAGE RankNTypes #-}
module NonDet
( tests
, gen
, test
) where

import qualified Choose
import Control.Carrier
import qualified Control.Carrier.NonDet.Church as Church.NonDetC
import qualified Control.Carrier.NonDet.Maybe as Maybe.NonDetC
import Control.Effect.Choose
import Control.Effect.Empty
import Control.Effect.NonDet (NonDet)
import qualified Control.Monad.Trans.Maybe as MaybeT
import Data.Maybe (listToMaybe, maybeToList)
import qualified Empty
import Gen
import Hedgehog (Gen, (===))
import Hedgehog.Function
import Hedgehog.Gen
import Test.Tasty
import Test.Tasty.Hedgehog

tests :: TestTree
tests = testGroup "NonDet"
  [ testGroup "NonDetC (Church)" $ test (m gen) a b Church.NonDetC.runNonDetA
  , testGroup "NonDetC (Maybe)"  $ test (m gen) a b (fmap maybeToList . Maybe.NonDetC.runNonDet)
  , testGroup "MaybeT"           $ test (m gen) a b (fmap maybeToList . MaybeT.runMaybeT)
  , testGroup "[]"               $ test (m gen) a b pure
  ]


gen :: (Has NonDet sig m, Show a) => (forall a . Show a => Gen a -> Gen (With (m a))) -> Gen a -> Gen (With (m a))
gen m a = choice [ Empty.gen m a, Choose.gen m a ]


test
  :: (Has NonDet sig m, Arg a, Eq a, Eq b, Show a, Show b, Vary a)
  => (forall a . Show a => Gen a -> Gen (With (m a)))
  -> Gen a
  -> Gen b
  -> (forall a . m a -> PureC [a])
  -> [TestTree]
test m a b runNonDet
  =  testProperty "empty is the left identity of <|>"  (forall (m a :. Nil)
    (\ (With m) -> runNonDet (empty <|> m) === runNonDet m))
  :  testProperty "empty is the right identity of <|>" (forall (m a :. Nil)
    (\ (With m) -> runNonDet (m <|> empty) === runNonDet m))
  :  Empty.test  m a b (fmap listToMaybe . runNonDet)
  ++ Choose.test m a b runNonDet
