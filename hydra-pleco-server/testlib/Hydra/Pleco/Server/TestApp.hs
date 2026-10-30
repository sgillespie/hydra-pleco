module Hydra.Pleco.Server.TestApp
  ( mkTestEnv,
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

-- | Start an 'Application' on a free port, run an action, and shut it down
withPlecoApp :: PlecoServerEnv -> (Port -> IO a) -> IO a
withPlecoApp env = Warp.testWithApplication (pure (app env))

-- | Same as 'withPlecoApp', but all exceptions are silently ignored
withPlecoAppCatching :: PlecoServerEnv -> (Port -> IO a) -> IO a
withPlecoAppCatching env = Warp.withApplicationSettings quietSettings (pure (app env))

quietSettings :: Warp.Settings
quietSettings = Warp.setOnException (\_ _ -> pass) Warp.defaultSettings
