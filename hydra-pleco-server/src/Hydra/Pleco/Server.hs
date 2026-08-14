module Hydra.Pleco.Server
  ( PlecoServerT (..),
    PlecoServerEnv (..),
    runPlecoServerT,
    app,
  ) where

import Hydra.Pleco.Api (Healthz (..), HydraApi (..))

import Servant
import Servant.Server.Generic (genericServeT)
import UnliftIO (MonadUnliftIO)

-- | The application monad stack
newtype PlecoServerT m a = PlecoServerT {unPlecoServerT :: ReaderT PlecoServerEnv m a}
  deriving newtype
    ( Functor,
      Applicative,
      Monad,
      MonadReader PlecoServerEnv,
      MonadIO,
      MonadUnliftIO
    )

-- | The reader environment
data PlecoServerEnv = PlecoServerEnv
  deriving stock (Eq, Show)

runPlecoServerT :: PlecoServerEnv -> PlecoServerT m a -> m a
runPlecoServerT env = usingReaderT env . unPlecoServerT

app :: PlecoServerEnv -> Application
app env = genericServeT (runPlecoServerT env) server

server :: ServerT (NamedRoutes HydraApi) (PlecoServerT Handler)
server =
  HydraApi
    { healthz = healthzHandler
    }

healthzHandler :: PlecoServerT Handler Healthz
healthzHandler = pure (Healthz "running")
