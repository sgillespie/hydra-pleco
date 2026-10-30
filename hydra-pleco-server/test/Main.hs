module Main (main) where

import Hydra.Pleco.Server.DB.HydraSpec qualified as HydraSpec
import Hydra.Pleco.Server.ErrorSpec qualified as ErrorSpec
import Hydra.Pleco.Server.EvalSpec qualified as EvalSpec
import Hydra.Pleco.Server.ProjectSpec qualified as ProjectSpec
import Hydra.Pleco.ServerSpec qualified as ServerSpec

import Test.Hspec

main :: IO ()
main = hspec $ do
  ServerSpec.spec
  ProjectSpec.spec
  EvalSpec.spec
  ErrorSpec.spec
  HydraSpec.spec
