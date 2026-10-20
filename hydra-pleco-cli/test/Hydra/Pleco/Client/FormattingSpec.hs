module Hydra.Pleco.Client.FormattingSpec (spec) where

import Hydra.Pleco.Api
  ( Eval (..),
    EvalId (..),
    Health (..),
    Jobset (..),
    JobsetId (..),
    JobsetName (..),
    JobsetState (..),
    JobsetType (..),
    Project (..),
    ProjectId (..),
  )
import Hydra.Pleco.Api.Golden (goldenText)
import Hydra.Pleco.Client.Formatting (toTablePlain)

import Test.Hspec

spec :: Spec
spec = describe "Hydra.Pleco.Client.Formatting" $ do
  describe "toTablePlain" $ do
    it "renders Health" $
      goldenText "health" (toTablePlain Nothing health)

    it "renders a Project" $
      goldenText "project" (toTablePlain Nothing sparseProject)

    it "renders list of Projects" $
      goldenText "projects" (toTablePlain Nothing [sparseProject, fullProject])

    it "renders Jobset" $
      goldenText "jobset" (toTablePlain Nothing sparseJobset)

    it "renders list of Jobsets" $
      goldenText "jobsets" (toTablePlain Nothing [sparseJobset, fullJobset])

    it "renders Eval" $
      goldenText "eval" (toTablePlain Nothing sparseEval)

    it "renders list of Evals" $
      goldenText "evals" (toTablePlain Nothing [sparseEval, fullEval])

-- * Fixtures

-- Intended to cover most interesting cases, such as missing description, missing
-- timestamp and cells wider than their header.

health :: Health
health = Health {hlStatus = "status"}

sparseProject :: Project
sparseProject =
  Project
    { prjId = ProjectId "project-a",
      prjEnabled = True,
      prjVisible = True,
      prjDisplayName = "Project A",
      prjDescription = Nothing,
      prjHomepage = Nothing,
      prjOwner = "owner",
      prjEnableDynRunCmd = False,
      prjDeclSpecFile = Nothing,
      prjDeclInputType = Nothing
    }

fullProject :: Project
fullProject =
  sparseProject
    { prjId = ProjectId "project-b",
      prjEnabled = False,
      prjDisplayName = "Project B",
      prjDescription = Just "a description wider than its header",
      prjHomepage = Just "https://example.com"
    }

sparseJobset :: Jobset
sparseJobset =
  Jobset
    { jsName = JobsetName "jobset-a",
      jsProject = ProjectId "project-a",
      jsId = JobsetId 1,
      jsState = JssEnabled,
      jsVisible = True,
      jsType = JstFlake,
      jsFlake = Nothing,
      jsNixExprInput = Nothing,
      jsNixExprPath = Nothing,
      jsDescription = Nothing,
      jsCheckInterval = 300,
      jsSchedulingShares = 100,
      jsEnableDynRunCmd = False,
      jsEnableEmail = False,
      jsEmailOverride = Nothing,
      jsKeepNumEvals = 3,
      jsLastCheckedTime = Nothing,
      jsLastEvalTime = Just 1000000000,
      jsErrorMsg = Nothing,
      jsErrorTime = Nothing
    }

fullJobset :: Jobset
fullJobset =
  sparseJobset
    { jsName = JobsetName "jobset-b",
      jsId = JobsetId 2,
      jsVisible = False,
      jsFlake = Just "github:example/repo",
      jsDescription = Just "a description",
      jsLastCheckedTime = Just 1000003600,
      jsLastEvalTime = Nothing
    }

sparseEval :: Eval
sparseEval =
  Eval
    { evId = EvalId 1,
      evJobsetId = JobsetId 1,
      evTimestamp = 1000000000,
      evCheckoutTime = 0,
      evEvalTime = 0,
      evHasNewBuilds = True,
      evHash = "hash",
      evNumBuilds = Nothing,
      evNumSucceeded = Nothing,
      evFlake = Nothing
    }

fullEval :: Eval
fullEval =
  sparseEval
    { evId = EvalId 2,
      evNumBuilds = Just 20,
      evNumSucceeded = Just 18,
      evFlake = Just "github:example/repo"
    }
