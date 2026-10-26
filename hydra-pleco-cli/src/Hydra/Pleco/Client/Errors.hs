module Hydra.Pleco.Client.Errors
  ( PlecoClientError (..),
    fromClientError,
  ) where

import Data.Text qualified as Text
import Network.HTTP.Types (Status (..))
import Prettyprinter (Doc, (<+>))
import Prettyprinter qualified as Pretty
import Prettyprinter.Render.Text (renderStrict)
import Servant.Client (BaseUrl (..), ClientError (..), ResponseF (..), showBaseUrl)
import Servant.Client.Core (RequestF (..))

data PlecoClientError
  = PlecoJobsetParseError Text
  | PlecoConnectionFailure BaseUrl
  | PlecoFailureResponse BaseUrl Status ByteString
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
prettyError err =
  Pretty.vsep $
    case (errorDetailDoc err, errorHintDoc err) of
      (Nothing, Nothing) -> [description]
      (Nothing, Just hint) -> [description, hint]
      (Just detail, Nothing) -> [description, mempty, detail]
      (Just detail, Just hint) -> [description, mempty, detail, mempty, hint]
  where
    description = errorDescriptionDoc err

errorDescriptionDoc :: PlecoClientError -> Doc ann
errorDescriptionDoc (PlecoJobsetParseError spec) =
  "Cannot parse jobset" <+> quoted (Pretty.pretty spec) <> ": invalid format"
errorDescriptionDoc (PlecoConnectionFailure baseUrl) =
  "Could not connect to" <+> quoted (Pretty.pretty (showBaseUrl baseUrl))
errorDescriptionDoc (PlecoFailureResponse url status respBody) =
  failureResponseDoc url status respBody
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

errorDetailDoc :: PlecoClientError -> Maybe (Doc ann)
errorDetailDoc (PlecoJobsetParseError _) = Nothing
errorDetailDoc (PlecoConnectionFailure _) = Nothing
errorDetailDoc (PlecoFailureResponse _ _ respBody) =
  detailDoc (decodeUtf8 respBody)
errorDetailDoc (PlecoUnknownError _ clientErr) =
  detailDoc (toText $ displayException clientErr)
errorDetailDoc (PlecoInternalError detail) =
  detailDoc detail

errorHintDoc :: PlecoClientError -> Maybe (Doc ann)
errorHintDoc (PlecoJobsetParseError {}) = Nothing
errorHintDoc (PlecoConnectionFailure {}) = Just "Is the server running?"
errorHintDoc (PlecoFailureResponse {}) = Nothing
errorHintDoc (PlecoUnknownError {}) = Just bugReport
errorHintDoc (PlecoInternalError {}) = Just bugReport

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
  PlecoFailureResponse baseUrl' responseStatusCode (toStrict responseBody)
  where
    baseUrl' = baseUrl {baseUrlPath = decodeUtf8 $ snd requestPath}
