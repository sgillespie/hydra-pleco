module Hydra.Pleco.Api.OpenApi
  ( hydraOpenApi,
  ) where

import Hydra.Pleco.Api (HydraApi, JobsetEvent, ProblemDetails)

import Data.HashMap.Strict.InsOrd.Compat qualified as InsOrd
import Data.OpenApi
  ( Callback,
    Definitions,
    OpenApi,
    Operation,
    Referenced,
    RequestBody,
    Response,
    Schema,
  )
import Data.OpenApi qualified as OpenApi
import Data.OpenApi.Declare (evalDeclare, execDeclare)
import Optics (At (..), (%), (%~), (.~), (?~))
import Optics.Extra (_Just)
import Servant.API (NamedRoutes)
import Servant.OpenApi (HasOpenApi (..))

hydraOpenApi :: OpenApi
hydraOpenApi =
  toOpenApi (Proxy :: Proxy (NamedRoutes HydraApi))
    & #components % #schemas %~ (<> mkProblemSchema <> mkEventSchema)
    & #components % #callbacks % at "jobsetEvent" ?~ mkEventCallback
    & pathCallbacks "/webhooks" % at "jobsetEvent" ?~ mkCallbackEventRef
    & #components % #responses % at "Problem" ?~ mkProblemResponse "Problem details"
    & pathGetResponses "/projects/{id}" % at 404
      ?~ OpenApi.Inline (mkProblemResponse "No such project with `id`.")
    & pathGetResponses "/projects/{id}/jobsets" % at 404
      ?~ OpenApi.Inline (mkProblemResponse "No such project with `id`.")
    & pathGetResponses "/jobsets/{id}" % at 404
      ?~ OpenApi.Inline (mkProblemResponse "No such jobset with `id`.")
    & pathGetResponses "/jobsets/{id}/evals" % at 404
      ?~ OpenApi.Inline (mkProblemResponse "No such jobset with `id`.")
    & pathGetResponses "/evals/{id}" % at 404
      ?~ OpenApi.Inline (mkProblemResponse "No such eval with `id`.")
  where
    pathCallbacks path = #paths % at path % _Just % #post % _Just % #callbacks
    pathGetResponses path = #paths % at path % _Just % #get % _Just % #responses

    mkProblemSchema :: Definitions Schema
    mkProblemSchema = execDeclare (OpenApi.declareSchemaRef @ProblemDetails Proxy) mempty

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

    mkProblemResponse :: Text -> Response
    mkProblemResponse desc =
      mempty
        & evalDeclare
          (OpenApi.declareResponse @ProblemDetails "application/problem+json" Proxy)
        & #description .~ desc
