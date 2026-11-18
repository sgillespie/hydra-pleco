module Hydra.Pleco.Server.Handlers.ProjectSpec (spec) where

import Hydra.Pleco.Api.Gen qualified as ApiGen
import Hydra.Pleco.Server.DB.Hydra (Project (..))
import Hydra.Pleco.Server.Gen qualified as Gen
import Hydra.Pleco.Server.Handlers.Projects.DB (fromProject, toProject)

import Hedgehog (forAll)
import Hydra.Pleco.Api.Project qualified as Api
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Hedgehog (hedgehog, tripping, (===))

spec :: Spec
spec = describe "Project" $ do
  it "round-trips through the Aeson" $
    hedgehog $ do
      prj <- forAll Gen.project
      tripping prj fromProject (Identity . toProject)

  describe "fromProject" $ do
    it "sets visible to not hidden" $
      hedgehog $ do
        prj@Project {prjHidden} <- forAll Gen.project
        Api.prjVisible (fromProject prj) === not prjHidden

  describe "toProject" $
    it "sets hidden to not visible" $ do
      hedgehog $ do
        prj@Api.Project {prjVisible} <- forAll ApiGen.project
        prjHidden (toProject prj) === not prjVisible
