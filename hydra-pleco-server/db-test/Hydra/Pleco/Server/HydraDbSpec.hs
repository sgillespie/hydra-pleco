module Hydra.Pleco.Server.HydraDbSpec (spec) where

import Hydra.Pleco.Server.DB (jobsetEvalById, jobsetEvalsByJobset, runSession, statement)
import Hydra.Pleco.Server.DB.Hydra
  ( Jobset (..),
    JobsetEval (..),
    JobsetEvalId (..),
    JobsetId (..),
    Project (..),
    eachProject,
    jobsetById,
    jobsetsByProject,
    jobsetsByProjectAndName,
    projectByName,
  )

import Hasql.Pool (Pool, UsageError)
import Hasql.Statement (Statement)
import Test.Hspec

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.DB.Hydra" $ do
  describe "eachProject" $ do
    it "selects every project" $ \(_, pool) -> do
      projects <- runStatement pool eachProject
      map prjName projects `shouldMatchList` ["pleco", "hidden", "paused"]

    it "decodes the scalar columns" $ \(_, pool) -> do
      prj <- runStatement pool (projectByName "pleco")
      prj
        `shouldBe` Just
          Project
            { prjName = "pleco",
              prjDisplayName = "Pleco",
              prjDescription = Just "A visible, enabled project",
              prjEnabled = True,
              prjHidden = False,
              prjOwner = "alice",
              prjHomepage = Just "https://example.org",
              prjDeclFile = Nothing,
              prjDeclType = Nothing,
              prjEnableDynCmd = False
            }

  describe "projectByName" $ do
    it "selects the expected project" $ \(_, pool) -> do
      prj <- runStatement pool (projectByName "hidden")
      fmap prjName prj `shouldBe` Just "hidden"

    it "returns nothing when the project does not exist" $ \(_, pool) -> do
      prj <- runStatement pool (projectByName "bogus-project")
      prj `shouldBe` Nothing

  describe "jobsetById" $ do
    it "selects the expected jobset" $ \(_, pool) -> do
      jobset <- runStatement pool (jobsetById (JobsetId 1))
      jsName jobset `shouldBe` "main"
      jsProject jobset `shouldBe` "pleco"

    it "decodes the scalar columns" $ \(_, pool) -> do
      jobset <- runStatement pool (jobsetById (JobsetId 1))
      jobset
        `shouldBe` Jobset
          { jsName = "main",
            jsId = JobsetId 1,
            jsProject = "pleco",
            jsDescription = Just "The main jobset",
            jsNixExprInput = Nothing,
            jsNixExprPath = Nothing,
            jsErrorMsg = Nothing,
            jsErrorTime = Nothing,
            jsLastCheckedTime = Nothing,
            jsTriggerTime = Nothing,
            jsEnabled = 1,
            jsEnableEmail = False,
            jsEmailOverride = "",
            jsKeepNumEvals = 3,
            jsHidden = False,
            jsCheckInterval = 300,
            jsSchedulingShares = 100,
            jsFetchErrorMsg = Nothing,
            jsForceEval = Nothing,
            jsStartTime = Nothing,
            jsType = 1,
            jsFlake = Just "github:sgillespie/hydra-pleco",
            jsEnableDynCmd = False
          }

  describe "jobsetsByProject" $
    it "selects expected jobsets" $ \(_, pool) -> do
      jobsets <- runStatement pool (jobsetsByProject "pleco")
      map jsName jobsets `shouldMatchList` ["main", "staging"]

  describe "jobsetsByProjectAndName" $
    it "selects expected jobsets" $ \(_, pool) -> do
      jobset <- runStatement pool (jobsetsByProjectAndName "pleco" "staging")
      map jsName jobset `shouldMatchList` ["staging"]

  describe "jobsetEvalById" $
    it "decodes the scalar columns" $ \(_, pool) -> do
      eval <- runStatement pool $ jobsetEvalById (JobsetEvalId 1)
      eval
        `shouldBe` JobsetEval
          { jseId = JobsetEvalId 1,
            jseJobsetId = JobsetId 1,
            jseTimestamp = 1700000000,
            jseCheckoutTime = 2,
            jseEvalTime = 3,
            jseHasNewBuilds = 1,
            jseHash = "deadbeef",
            jseNumBuilds = Just 5,
            jseNumSucceeded = Just 5,
            jseFlake = Just "github:sgillespie/hydra-pleco"
          }

  describe "jobsetEvalsByJobset" $
    it "selects expected evals" $ \(_, pool) -> do
      evals <- runStatement pool $ jobsetEvalsByJobset (JobsetId 1)
      map jseId evals `shouldMatchList` [JobsetEvalId 1, JobsetEvalId 2]

runStatement :: Pool -> Statement () a -> IO a
runStatement pool stmt = runSession pool (statement () stmt)

isUsageError :: Selector UsageError
isUsageError = const True
