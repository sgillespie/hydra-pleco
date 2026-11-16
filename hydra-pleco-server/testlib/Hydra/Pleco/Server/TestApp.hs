module Hydra.Pleco.Server.TestApp
  ( mkTestEnv,
    withServerUsing,
    withPlecoServer,
    withPlecoServerCatching,
    withPlecoApp,
    withPlecoAppCatching,
    client,
    hasStatus,
    withProblemResponse,
  ) where

import Hydra.Pleco.Api (ProblemDetails (..), StatusCode (..), Subscription)
import Hydra.Pleco.Client (PlecoClient, PlecoClientError (..))
import Hydra.Pleco.Client qualified as Client
import Hydra.Pleco.Server (PlecoServerEnv (..), app)

import Hasql.Pool (Pool)
import Katip qualified
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Network.HTTP.Types (Status (..))
import Network.Wai.Handler.Warp (Port)
import Network.Wai.Handler.Warp qualified as Warp
import Servant.Client (BaseUrl (..), Scheme (..))
import Test.Hspec (Expectation, Selector)
import UnliftIO (throwIO)

mkTestEnv :: Text -> Pool -> [Subscription] -> IO PlecoServerEnv
mkTestEnv connInfo pool initialSubs = do
  -- No Katip scribes defined here to keep tests quiet
  logEnv <- Katip.initLogEnv "hydra-pleco" "test"
  subs <- newTVarIO initialSubs
  manager' <- newManager defaultManagerSettings

  pure
    PlecoServerEnv
      { pseLogNamespace = mempty,
        pseLogCtx = mempty,
        pseLogEnv = logEnv,
        pseSubscriptions = subs,
        pseClientManager = manager',
        pseDbConnInfo = connInfo,
        pseDbPool = pool
      }

-- | Start the test server, run an action, then shut it down
withPlecoServer :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withPlecoServer = withServerUsing withPlecoApp

-- | Same as 'withServer', but all exceptions are silently ignored
withPlecoServerCatching :: (Port -> IO a) -> ((Text, Pool) -> IO a)
withPlecoServerCatching = withServerUsing withPlecoAppCatching

-- | Initialize a test 'PlecoServerEnv', then pass it to the specified 'serve' and 'act'
-- actions
withServerUsing
  :: (PlecoServerEnv -> (Port -> IO a) -> IO a)
  -> (Port -> IO a)
  -> ((Text, Pool) -> IO a)
withServerUsing serve act (connInfo, pool) = do
  env <- mkTestEnv connInfo pool []
  serve env act

-- | Start an 'Application' on a free port, run an action, and shut it down
withPlecoApp :: PlecoServerEnv -> (Port -> IO a) -> IO a
withPlecoApp env = Warp.testWithApplication (pure (app env))

-- | Same as 'withPlecoApp', but all exceptions are silently ignored
withPlecoAppCatching :: PlecoServerEnv -> (Port -> IO a) -> IO a
withPlecoAppCatching env = Warp.withApplicationSettings quietSettings (pure (app env))

quietSettings :: Warp.Settings
quietSettings = Warp.setOnException (\_ _ -> pass) Warp.defaultSettings

-- | Run a real request against the test server and return the result
client :: Port -> PlecoClient a -> IO a
client port act = do
  env <- Client.mkPlecoClientEnv (BaseUrl Http "localhost" port "")
  Client.runPlecoClient env act

-- | Returns true if the error is a 'PlecoProblemResponse' and its status matches the one
-- specified.
hasStatus :: Status -> Selector PlecoClientError
hasStatus code (PlecoProblemResponse problem) =
  pdStatus problem == StatusCode (statusCode code)
hasStatus _ _ = False

-- | Checks an API result, expected to be a 'PlecoProblemResponse', then passes the
-- 'ProblemDetails' to the given 'Expectation'. If the result was successful or not a
-- problem response, it fails the test.
withProblemResponse
  :: Either PlecoClientError a
  -> (ProblemDetails -> Expectation)
  -> Expectation
withProblemResponse result expect =
  case result of
    Left (PlecoProblemResponse problem) -> expect problem
    Left err -> throwIO err
    Right _ -> fail "expected a failure response"
