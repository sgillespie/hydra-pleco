module Hydra.Pleco.Server.Error
  ( PlecoServerError (..),
    serverError,
    noSuchProjectError,
    noSuchJobsetError,
    noSuchEvalError,
  ) where

import Hydra.Pleco.Api
  ( EvalId (..),
    JobsetId (..),
    ProblemDetails (..),
    ProblemJSON,
    ProblemType (..),
    ProjectId (..),
    StatusCode (..),
    problemTypeTitle,
    problemTypeUri,
  )

import Data.Aeson.Encode.Pretty qualified as Aeson
import Hasql.Connection (ConnectionError)
import Network.HTTP.Media (RenderHeader (..))
import Network.HTTP.Types (hContentType)
import Servant (Accept (..), ServerError (..), err404)
import Servant.Client (ClientError)

data PlecoServerError
  = ServerDbConnectionError ConnectionError
  | ServerClientError ClientError
  | ServerParsingError Text
  | ServerUnknownError Text
  deriving stock (Eq, Show)

instance Exception PlecoServerError

problemTypeServerErr :: ProblemType -> ServerError
problemTypeServerErr NoSuchProject = err404
problemTypeServerErr NoSuchJobset = err404
problemTypeServerErr NoSuchEval = err404

noSuchProjectError :: ProjectId -> ServerError
noSuchProjectError (ProjectId project) =
  serverError NoSuchProject $ "Project `" <> project <> "' does not exist"

noSuchJobsetError :: JobsetId -> ServerError
noSuchJobsetError (JobsetId jobset) =
  serverError NoSuchJobset $ "Jobset `" <> show jobset <> "' does not exist"

noSuchEvalError :: EvalId -> ServerError
noSuchEvalError (EvalId eval) =
  serverError NoSuchEval $ "Eval `" <> show eval <> "' does not exist"

serverError :: ProblemType -> Text -> ServerError
serverError problemTy detailText =
  serverError'
    { errBody = Aeson.encodePretty problemDetails',
      errHeaders = [(hContentType, renderHeader $ contentType @ProblemJSON Proxy)]
    }
  where
    problemDetails' =
      ProblemDetails
        { pdType = problemTypeUri problemTy,
          pdStatus = StatusCode . errHTTPCode . problemTypeServerErr $ problemTy,
          pdTitle = problemTypeTitle problemTy,
          pdDetail = detailText
        }

    serverError' = problemTypeServerErr problemTy
