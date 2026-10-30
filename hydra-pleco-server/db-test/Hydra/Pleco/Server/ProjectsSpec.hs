module Hydra.Pleco.Server.ProjectsSpec (spec) where

import Hydra.Pleco.Api (Project (..), ProjectId (..))
import Hydra.Pleco.Client
  ( PlecoClient,
    PlecoClientError,
    listProjects,
    mkPlecoClientEnv,
    runPlecoClient,
  )
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server (PlecoServerEnv)
import Hydra.Pleco.Server.TestApp (mkTestEnv, withPlecoApp, withPlecoAppCatching)

import Hasql.Pool (Pool)
import Network.HTTP.Types (Status)
import Network.HTTP.Types.Status (status404)
import Network.Wai.Handler.Warp (Port)
import Servant.Client (BaseUrl (..), Scheme (Http))
import Test.Hspec

spec :: SpecWith (Text, Pool)
spec = describe "Hydra.Pleco.Server.Projects" $ do
  describe "projects" $ do
    describe "listProjects" $ do
      it "lists every project" $
        withServer $ \port -> do
          projects <- client port listProjects
          map prjId projects `shouldMatchList` map ProjectId ["pleco", "hidden", "paused"]

    describe "getProject" $ do
      it "serves the expected project" $
        withServer $ \port -> do
          project <- client port (Client.getProject (ProjectId "pleco"))
          prjId project `shouldBe` ProjectId "pleco"

      it "returns 404 on project that does not exist" $
        withServerCatching $ \port ->
          client port (Client.getProject (ProjectId "bogus-project"))
            `shouldThrow` hasStatus status404

withServer :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withServer = withServerUsing withPlecoApp

withServerCatching :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withServerCatching = withServerUsing withPlecoAppCatching

withServerUsing
  :: (PlecoServerEnv -> (Port -> IO a) -> IO a)
  -> (Port -> IO a)
  -> ((Text, Pool) -> IO a)
withServerUsing serve act (connInfo, pool) = do
  env <- mkTestEnv connInfo pool []
  serve env act

client :: Port -> PlecoClient a -> IO a
client port act = do
  env <- mkPlecoClientEnv (BaseUrl Http "localhost" port "")
  runPlecoClient env act

hasStatus :: Status -> Selector PlecoClientError
hasStatus code (Client.PlecoFailureResponse _ status _) = status == code
hasStatus _ _ = False
