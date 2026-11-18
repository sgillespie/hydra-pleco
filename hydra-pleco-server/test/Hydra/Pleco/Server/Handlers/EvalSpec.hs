module Hydra.Pleco.Server.Handlers.EvalSpec (spec) where

import Hydra.Pleco.Api.Gen qualified as ApiGen
import Hydra.Pleco.Server.DB.Hydra (JobsetEval (..))
import Hydra.Pleco.Server.Gen qualified as Gen
import Hydra.Pleco.Server.Handlers.Evals.DB (fromEval, toEval)

import Hedgehog (forAll)
import Hydra.Pleco.Api.Eval qualified as Api
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Hedgehog (hedgehog, tripping, (===))

spec :: Spec
spec = describe "Eval" $ do
  it "round-trips through the API type" $
    hedgehog $ do
      eval <- forAll Gen.jobsetEval
      tripping eval fromEval (Identity . toEval)

  describe "fromEval" $
    it "sets has new builds to a non-zero flag" $
      hedgehog $ do
        eval@JobsetEval {jseHasNewBuilds} <- forAll Gen.jobsetEval
        Api.evHasNewBuilds (fromEval eval) === (jseHasNewBuilds /= 0)

  describe "toEval" $
    it "sets the has new builds flag from the boolean" $
      hedgehog $ do
        eval@Api.Eval {evHasNewBuilds} <- forAll ApiGen.eval
        (jseHasNewBuilds (toEval eval) /= 0) === evHasNewBuilds
