module Main (main) where

import Hydra.Pleco.Server.EvalsSpec qualified as EvalsSpec
import Hydra.Pleco.Server.HydraDbSpec qualified as HydraDbSpec
import Hydra.Pleco.Server.JobsetsSpec qualified as JobsetsSpec
import Hydra.Pleco.Server.ProjectsSpec qualified as ProjectsSpec
import Hydra.Pleco.Server.TestDb (lookupTestDb, withHydraDb)
import Hydra.Pleco.Server.WebhookSpec qualified as WebhookSpec

import Hasql.Pool (Pool)
import Test.Hspec

main :: IO ()
main = do
  hspec $
    aroundAll withDb $ do
      HydraDbSpec.spec
      ProjectsSpec.spec
      JobsetsSpec.spec
      EvalsSpec.spec
      WebhookSpec.spec

withDb :: ((Text, Pool) -> IO ()) -> IO ()
withDb f = do
  db <- lookupTestDb
  case db of
    Nothing -> expectationFailure "Missing required PLECO_TEST_HYDRA_SCHEMA environment variable!"
    Just testDb -> withHydraDb testDb (curry f)
