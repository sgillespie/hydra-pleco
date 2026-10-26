module Hydra.Pleco.Client.Gen
  ( baseUrl,
    clientError,
    jobsetSpec,
    plecoClientError,
    response,
    responseBody,
    status,
    unknownClientError,
    failureRequest,
  ) where

import Hydra.Pleco.Api.Gen qualified as ApiGen
import Hydra.Pleco.Client
  ( BaseUrl (..),
    JobsetName (..),
    JobsetSpec (..),
    PlecoClientError (..),
    ProjectId (..),
    Scheme (..),
  )

import Data.Text qualified as Text
import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Network.HTTP.Types (Status (..), http11)
import Servant.Client.Core (ClientError, RequestF, Response)
import Servant.Client.Core qualified as Servant
import System.IO.Error (userError)

baseUrl :: Gen BaseUrl
baseUrl =
  BaseUrl
    <$> Gen.element [Http, Https]
    <*> Gen.string (Range.linear 1 32) Gen.alphaNum
    <*> Gen.int (Range.linear 1 65535)
    <*> Gen.string (Range.linear 0 32) Gen.alphaNum

jobsetSpec :: Gen JobsetSpec
jobsetSpec = JobsetSpec . ProjectId <$> title <*> (JobsetName <$> title)
  where
    -- A 'ProjectId' or 'JobsetName', excluding colons, since they break our adhoc parser.
    -- Update this if it ever becomes a problem.
    title :: Gen Text
    title = Gen.text (Range.linear 0 255) (Gen.filter (/= ':') Gen.unicode)

-- | An HTTP status, between 100 and 599
status :: Gen Status
status = Status <$> Gen.int (Range.linear 100 599) <*> (encodeUtf8 <$> ApiGen.title)

-- | An HTTP response body
responseBody :: Gen ByteString
responseBody = encodeUtf8 . Text.intercalate "\n" <$> Gen.list (Range.linear 0 12) line
  where
    line = Gen.frequency [(1, pure ""), (1, ApiGen.title)]

-- | An HTTP response with no headers and the HTTP version fixed to 1.1
response :: Gen Response
response =
  Servant.Response
    <$> status
    <*> pure mempty
    <*> pure http11
    <*> (toLazy <$> responseBody)

plecoClientError :: Gen PlecoClientError
plecoClientError =
  Gen.choice
    [ PlecoJobsetParseError <$> ApiGen.title,
      PlecoConnectionFailure <$> baseUrl,
      PlecoFailureResponse <$> baseUrl <*> status <*> responseBody,
      PlecoUnknownError <$> baseUrl <*> unknownClientError,
      PlecoInternalError <$> ApiGen.title
    ]

-- | Any 'ClientError'
clientError :: Gen ClientError
clientError =
  Gen.choice
    [ pure (Servant.ConnectionError (SomeException (userError "connection failed"))),
      Servant.FailureResponse <$> failedRequest <*> response,
      unknownClientError
    ]
  where
    failedRequest = do
      url <- baseUrl
      pure $ bimap (const ()) (const (url, "")) Servant.defaultRequest

-- | Servant errors that get classified as 'PlecoUnknownError'
unknownClientError :: Gen ClientError
unknownClientError =
  Gen.choice
    [ Servant.DecodeFailure <$> ApiGen.title <*> response,
      Servant.UnsupportedContentType <$> Gen.element contentTypes <*> response,
      Servant.InvalidContentTypeHeader <$> response
    ]
  where
    contentTypes = ["application/json", "text/plain", "text/html"]

-- | Build a request that can be passed to 'FailureResponse'
failureRequest :: BaseUrl -> RequestF () (BaseUrl, ByteString)
failureRequest url = bimap (const ()) (const (url, "")) Servant.defaultRequest
