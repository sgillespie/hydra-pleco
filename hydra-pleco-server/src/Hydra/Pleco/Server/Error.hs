module Hydra.Pleco.Server.Error
  ( PlecoServerError (..),
    ProblemType (..),
    problemTypeUri,
    problemTypeTitle,
    serverError,
    noSuchProjectError,
  ) where

import Hydra.Pleco.Api (ProblemDetails (..), ProblemJSON, ProjectId (..), StatusCode (..))

import Data.Aeson.Encode.Pretty qualified as Aeson
import Hasql.Connection (ConnectionError)
import Network.HTTP.Media (RenderHeader (..))
import Network.HTTP.Types (hContentType)
import Network.URI (nullURI)
import Servant (Accept (..), ServerError (..), URI (..), err404)
import Servant.Client (ClientError)

data PlecoServerError
  = ServerDbConnectionError ConnectionError
  | ServerClientError ClientError
  | ServerParsingError Text
  | ServerUnknownError Text
  deriving stock (Eq, Show)

instance Exception PlecoServerError

data ProblemType
  = NoSuchProject
  deriving stock (Bounded, Eq, Enum, Ord, Show)

problemTypeUri :: ProblemType -> URI
problemTypeUri NoSuchProject = nullURI {uriPath = "/problems/no-such-project"}

problemTypeTitle :: ProblemType -> Text
problemTypeTitle NoSuchProject = "No such project"

problemTypeServerErr :: ProblemType -> ServerError
problemTypeServerErr NoSuchProject = err404

noSuchProjectError :: ProjectId -> ServerError
noSuchProjectError (ProjectId project) =
  serverError NoSuchProject $ "Project `" <> project <> "' does not exist"

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
