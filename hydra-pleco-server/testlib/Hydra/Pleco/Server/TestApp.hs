module Hydra.Pleco.Server.TestApp
  ( mkTestEnv,
    withServerUsing,
    withPlecoServer,
    withPlecoServerCatching,
    withPlecoApp,
    withPlecoAppCatching,
  ) where

import Hydra.Pleco.Api (Subscription)
import Hydra.Pleco.Server (PlecoServerEnv (..), app)

import Hasql.Pool (Pool)
import Katip qualified
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Network.Wai.Handler.Warp (Port)
import Network.Wai.Handler.Warp qualified as Warp

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

