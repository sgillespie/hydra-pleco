module Hydra.Pleco.Api
  ( HydraApi (..),
    WebhooksApi (..),
    HydraApp (..),
    HealthJSON,
    Health (..),
    Subscription (..),
    JobsetEvent (..),
    EventType (..),
    Project (..),
    Jobset (..),
    hydraApi,
    hydraOpenApi,
  ) where

import Hydra.Pleco.Api.Event
  ( EventType (..),
    Jobset (..),
    JobsetEvent (..),
    Project (..),
  )

import Data.Aeson
  ( FromJSON,
    KeyValue (..),
    ToJSON,
    (.:),
  )
import Data.Aeson qualified as Aeson
import Data.HashMap.Strict.InsOrd.Compat qualified as InsOrd
import Data.OpenApi
  ( Callback,
    Definitions,
    OpenApi,
    Operation,
    Referenced,
    RequestBody,
    Schema,
    ToSchema,
  )
import Data.OpenApi qualified as OpenApi
import Data.OpenApi.Declare (execDeclare)
import Network.HTTP.Media ((//))
import Optics (At (..), (%), (%~), (?~))
import Optics.Extra (_Just)
import Servant.API
import Servant.OpenApi (HasOpenApi (..))
import Servant.Swagger.UI (SwaggerSchemaUI)

-- | Documented API routes. OpenApi spec is generated from this.
data HydraApi mode = HydraApi
  { health :: mode :- "health" :> Get '[HealthJSON] Health,
    webhooks :: mode :- "webhooks" :> NamedRoutes WebhooksApi
  }
  deriving stock (Generic)

data WebhooksApi mode = WebhooksApi
  { subscribe :: mode :- ReqBody '[JSON] Subscription :> PostCreated '[JSON] Subscription,
    list :: mode :- Get '[JSON] [Subscription]
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

newtype Subscription = Subscription
  {url :: Text}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToSchema)

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

instance ToJSON Subscription where
  toJSON Subscription {url} = Aeson.object ["url" .= url]
  toEncoding Subscription {url} = Aeson.pairs $ "url" .= url

instance FromJSON Subscription where
  parseJSON = Aeson.withObject "Subscription" $ \val ->
    Subscription <$> val .: "url"

hydraApi :: Proxy HydraApi
hydraApi = Proxy

hydraOpenApi :: OpenApi
hydraOpenApi =
  toOpenApi (Proxy :: Proxy (NamedRoutes HydraApi))
    & #components % #schemas %~ (<> mkEventSchema)
    & #components % #callbacks % at "jobsetEvent" ?~ mkEventCallback
    & pathCallbacks "/webhooks" % at "jobsetEvent" ?~ mkCallbackEventRef
  where
    pathCallbacks path = #paths % at path % _Just % #post % _Just % #callbacks

    mkEventSchema :: Definitions Schema
    mkEventSchema =
      execDeclare (OpenApi.declareSchemaRef (Proxy @JobsetEvent)) mempty

    mkEventCallback :: Callback
    mkEventCallback =
      OpenApi.Callback $
        InsOrd.fromList [("{$request.body#/url}", mempty & #post ?~ mkEventOp)]

    mkEventOp :: Operation
    mkEventOp =
      mempty
        & #summary ?~ "Hydra Jobset event notification"
        & #description ?~ "Posted to each registered url on Hydra jobset events."
        & #requestBody ?~ OpenApi.Inline mkReqBody
        & #responses % at 200 ?~ OpenApi.Inline mempty

    mkReqBody :: RequestBody
    mkReqBody =
      mempty
        & #required ?~ True
        & #content % at "application/json" ?~ mkMediaType

    mkMediaType = mempty & #schema ?~ OpenApi.Ref (OpenApi.Reference "JobsetEvent")

    mkCallbackEventRef :: Referenced Callback
    mkCallbackEventRef = OpenApi.Ref (OpenApi.Reference "jobsetEvent")
