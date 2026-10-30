module Hydra.Pleco.Client.Errors
  ( PlecoClientError (..),
    fromClientError,
  ) where

import Hydra.Pleco.Api
  ( ProblemDetails (..),
    ProblemJSON,
    ProblemType (..),
    StatusCode (..),
    parseProblemType,
  )

import Data.Text qualified as Text
import Network.HTTP.Media qualified as Media
import Network.HTTP.Types (Status (..), hContentType)
import Prettyprinter (Doc, (<+>))
import Prettyprinter qualified as Pretty
import Prettyprinter.Render.Text (renderStrict)
import Servant.API (Accept (..), MimeUnrender (..))
import Servant.Client (BaseUrl (..), ClientError (..), ResponseF (..), showBaseUrl)
import Servant.Client.Core (RequestF (..))

data PlecoClientError
  = PlecoJobsetParseError Text
  | PlecoConnectionFailure BaseUrl
  | PlecoFailureResponse BaseUrl Status ByteString
  | PlecoProblemResponse ProblemDetails
  | PlecoUnknownError BaseUrl ClientError
  | PlecoInternalError Text
  deriving stock (Eq, Show)

instance Exception PlecoClientError where
  displayException =
    toString
      . renderStrict
      . Pretty.layoutPretty Pretty.defaultLayoutOptions
      . prettyError

-- | Pretty print a 'PlecoClientError' with the textual components:
--
--    * a description
--    * an optional detail
--    * an optional hint
--
-- separated by a blank line. If present, detail is indented.
prettyError :: PlecoClientError -> Doc ann
prettyError err = Pretty.vsep $ description : intersperse mempty extraDetails
  where
    description = errorDescriptionDoc err

    -- detail and hint as a list if they exist, separated by blank lines
    extraDetails =
      catMaybes
        [ padDetail (errorDetailDoc err),
          errorHintDoc err
        ]

    -- Add an extra line between description and detail
    padDetail doc = (Pretty.line <>) <$> doc

errorDescriptionDoc :: PlecoClientError -> Doc ann
errorDescriptionDoc (PlecoJobsetParseError spec) =
  "Cannot parse jobset" <+> quoted (Pretty.pretty spec) <> ": invalid format"
errorDescriptionDoc (PlecoConnectionFailure baseUrl) =
  "Could not connect to" <+> quoted (Pretty.pretty (showBaseUrl baseUrl))
errorDescriptionDoc (PlecoFailureResponse url status respBody) =
  failureResponseDoc url status respBody
errorDescriptionDoc (PlecoProblemResponse problem) =
  problemDoc problem
errorDescriptionDoc (PlecoUnknownError url _) =
  "Unexpected error from" <+> quoted (Pretty.pretty (showBaseUrl url))
errorDescriptionDoc (PlecoInternalError _) =
  "Unexpected error"

failureResponseDoc :: BaseUrl -> Status -> ByteString -> Doc ann
failureResponseDoc url status _ =
  Pretty.vsep
    [ "Received failure response from" <+> quoted (Pretty.pretty (showBaseUrl url)),
      httpStatus
    ]
  where
    httpStatus =
      "HTTP"
        <+> Pretty.pretty (statusCode status)
        <> ":"
        <+> Pretty.pretty (decodeUtf8 @Text (statusMessage status))

-- | Render the 'ProblemDetails' verbatim from the server. Use detail if it exists,
-- otherwise use title, and if that doesn't exist use a generic HTTP failure message.
problemDoc :: ProblemDetails -> Doc ann
problemDoc ProblemDetails {..}
  | not (Text.null detail) = Pretty.pretty detail
  | not (Text.null title) = Pretty.pretty title
  | otherwise = "Request failed: HTTP" <+> Pretty.pretty (unStatusCode pdStatus)
  where
    detail = unwords (words pdDetail)
    title = unwords (words pdTitle)

errorDetailDoc :: PlecoClientError -> Maybe (Doc ann)
errorDetailDoc (PlecoJobsetParseError _) = Nothing
errorDetailDoc (PlecoConnectionFailure _) = Nothing
errorDetailDoc (PlecoFailureResponse _ _ respBody) =
  detailDoc (decodeUtf8 respBody)
errorDetailDoc (PlecoProblemResponse _) = Nothing
errorDetailDoc (PlecoUnknownError _ clientErr) =
  detailDoc (toText $ displayException clientErr)
errorDetailDoc (PlecoInternalError detail) =
  detailDoc detail

errorHintDoc :: PlecoClientError -> Maybe (Doc ann)
errorHintDoc (PlecoJobsetParseError {}) = Nothing
errorHintDoc (PlecoConnectionFailure {}) = Just "Is the server running?"
errorHintDoc (PlecoFailureResponse {}) = Nothing
errorHintDoc (PlecoProblemResponse problem) =
  problemHint =<< parseProblemType (pdType problem)
errorHintDoc (PlecoUnknownError {}) = Just bugReport
errorHintDoc (PlecoInternalError {}) = Just bugReport

-- | Generate a hint from a 'ProblemType'
problemHint :: ProblemType -> Maybe (Doc ann)
problemHint NoSuchProject = Just "Run `pleco project list' to see the available projects."

bugReport :: Doc ann
bugReport = "Please report this bug at https://github.com/sgillespie/hydra-pleco/issues"

-- | Detail text, indented, if nonempty.
detailDoc :: Text -> Maybe (Doc ann)
detailDoc txt
  | null lines' = Nothing
  | otherwise = Just $ Pretty.indent 2 (Pretty.vsep (map Pretty.pretty lines'))
  where
    -- Split the 'txt' into lines, remove all trailing whitespace, and remove blank lines
    lines' = filter (not . isBlank) . map Text.stripEnd . lines $ txt
    isBlank = Text.null . Text.strip

-- | GNU-style quoting (`quoted string')
quoted :: Doc ann -> Doc ann
quoted doc = "`" <> doc <> "'"

-- | Transform a Servant 'ClientError' to a 'PlecoClientError'
fromClientError :: BaseUrl -> ClientError -> PlecoClientError
fromClientError baseUrl (ConnectionError _) =
  PlecoConnectionFailure baseUrl
fromClientError baseUrl (FailureResponse request response) =
  fromFailureResponse baseUrl request response
fromClientError baseUrl unknownErr =
  PlecoUnknownError baseUrl unknownErr

fromFailureResponse
  :: BaseUrl
  -> RequestF body (url, ByteString)
  -> ResponseF LByteString
  -> PlecoClientError
fromFailureResponse baseUrl Request {..} Response {..} =
  let -- The response document, if its content-type is problem+json
      problemDetails
        | isProblemJson = rightToMaybe $ mimeUnrender (Proxy @ProblemJSON) responseBody
        | otherwise = Nothing

      failureResponse =
        PlecoFailureResponse
          (baseUrl {baseUrlPath = decodeUtf8 $ snd requestPath})
          responseStatusCode
          (toStrict responseBody)
  in  maybe failureResponse PlecoProblemResponse problemDetails
  where
    isProblemJson = isJust $ do
      (_, contentTy) <- find ((== hContentType) . fst) responseHeaders
      mediaTy <- Media.parseAccept contentTy
      guard $ mediaTy `Media.matches` contentType @ProblemJSON Proxy
