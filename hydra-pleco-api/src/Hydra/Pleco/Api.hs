module Hydra.Pleco.Api
  ( HydraApi (..),
    Healthz (..),
    hydraApi,
  ) where

import Data.Aeson
  ( -- Types
    FromJSON,
    -- Operators
    KeyValue (..),
    ToJSON,
    (.:),
  )
import Data.Aeson qualified as Aeson
import Servant.API (GenericMode ((:-)), Get, (:>))
import Servant.API.ContentTypes (JSON)

-- TODO[sgillespie]: Remove me!
{-# ANN module ("HLint: ignore Use newtype instead of data" :: String) #-}

data HydraApi mode = HydraApi
  { healthz :: mode :- "healthz" :> Get '[JSON] Healthz
  }
  deriving stock (Generic)

data Healthz = Healthz
  {status :: Text}
  deriving stock (Eq, Show, Generic)

instance ToJSON Healthz where
  toJSON Healthz {..} =
    Aeson.object
      [ "status" .= status
      ]

  toEncoding Healthz {..} =
    Aeson.pairs $
      "status" .= status

instance FromJSON Healthz where
  parseJSON = Aeson.withObject "Healthz" $ \val ->
    Healthz
      <$> val .: "status"

hydraApi :: Proxy HydraApi
hydraApi = Proxy
