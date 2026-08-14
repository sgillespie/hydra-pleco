module Hydra.Pleco.Client
  ( PlecoClient (..),
    PlecoClientEnv (..),
    hoistClientM,
    runPlecoClient,
    mkPlecoClientEnv,
    plecoClient,
    getHealth,

    -- * Re-exports
    Manager,
    newManager,
    defaultManagerSettings,
    BaseUrl (..),
    Servant.Scheme (..),
  ) where

import Hydra.Pleco.Api (Healthz, HydraApi, healthz)

import Network.HTTP.Client (Manager, defaultManagerSettings, newManager)
import Servant.Client (AsClientT, BaseUrl, ClientEnv, ClientError, ClientM, (//))
import Servant.Client qualified as Servant
import Servant.Client.Generic (genericClientHoist)

-- TODO[sgillespie]: Remove me!
{-# ANN module ("HLint: ignore Use newtype instead of data" :: String) #-}

-- | Client application monad stack
newtype PlecoClient a = PlecoClient {unPlecoClient :: ReaderT PlecoClientEnv ClientM a}
  deriving newtype
    ( Functor,
      Applicative,
      Monad,
      MonadReader PlecoClientEnv,
      MonadIO
    )

data PlecoClientEnv = PlecoClientEnv
  { pceClientEnv :: ClientEnv
  }

hoistClientM :: ClientM a -> PlecoClient a
hoistClientM = PlecoClient . lift

runPlecoClient :: PlecoClientEnv -> PlecoClient a -> IO (Either ClientError a)
runPlecoClient env@PlecoClientEnv {..} action =
  Servant.runClientM (runReaderT (unPlecoClient action) env) pceClientEnv

mkPlecoClientEnv :: Manager -> BaseUrl -> PlecoClientEnv
mkPlecoClientEnv manager url =
  PlecoClientEnv
    { pceClientEnv = Servant.mkClientEnv manager url
    }

plecoClient :: HydraApi (AsClientT PlecoClient)
plecoClient = genericClientHoist hoistClientM

getHealth :: PlecoClient Healthz
getHealth = plecoClient // healthz
