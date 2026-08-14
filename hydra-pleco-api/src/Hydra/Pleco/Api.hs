module Hydra.Pleco.Api
  ( HydraApi (..),
    HydraApp (..),
    HealthJSON,
    Health (..),
    hydraApi,
    hydraOpenApi,
  ) where

import Data.Aeson
  ( FromJSON,
    KeyValue (..),
    ToJSON,
    (.:),
  )
import Data.Aeson qualified as Aeson
import Data.OpenApi (OpenApi, ToSchema)
import Network.HTTP.Media ((//))
import Servant.API (Accept (..), GenericMode ((:-)), Get, MimeRender (..), MimeUnrender (..), NamedRoutes, (:>))
import Servant.OpenApi (HasOpenApi (..))
import Servant.Swagger.UI (SwaggerSchemaUI)

-- TODO[sgillespie]: Remove me!
{-# ANN module ("HLint: ignore Use newtype instead of data" :: String) #-}

-- | Documented API routes. OpenApi spec is generated from this.
data HydraApi mode = HydraApi
  { health :: mode :- "health" :> Get '[HealthJSON] Health
  }
  deriving stock (Generic)

-- | The full Rest API application: the documented routes plus the Swagger UI.
data HydraApp mode = HydraApp
  { api :: mode :- NamedRoutes HydraApi,
    docs :: mode :- SwaggerSchemaUI "swagger-ui" "swagger.json"
  }
  deriving stock (Generic)

newtype Health = Health
  {status :: Text}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToSchema)

data HealthJSON

instance ToJSON Health where
  toJSON Health {..} =
    Aeson.object
      [ "status" .= status
      ]

  toEncoding Health {..} =
    Aeson.pairs $
      "status" .= status

instance FromJSON Health where
  parseJSON = Aeson.withObject "Health" $ \val ->
    Health
      <$> val .: "status"

instance Accept HealthJSON where
  contentType _ = "application" // "health+json"

instance (ToJSON json) => MimeRender HealthJSON json where
  mimeRender _ = Aeson.encode

instance (FromJSON json) => MimeUnrender HealthJSON json where
  mimeUnrender _ = Aeson.eitherDecode

hydraApi :: Proxy HydraApi
hydraApi = Proxy

hydraOpenApi :: OpenApi
hydraOpenApi = toOpenApi (Proxy :: Proxy (NamedRoutes HydraApi))
