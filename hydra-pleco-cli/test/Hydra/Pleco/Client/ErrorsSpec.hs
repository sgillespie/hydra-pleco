module Hydra.Pleco.Client.ErrorsSpec (spec) where

import Hydra.Pleco.Client.Errors (PlecoClientError (..), fromClientError)
import Hydra.Pleco.Client.Gen qualified as Gen

import Data.Text qualified as Text
import Network.HTTP.Types (http11)
import Servant.Client (BaseUrl (..), ClientError (..))
import Servant.Client.Core (RequestF (..), ResponseF (..))
import Test.Hspec (Spec, describe, it)
import Test.Hspec.Hedgehog (assert, failure, forAll, hedgehog, (===))

data DummyException = DummyException
  deriving stock (Eq, Show)

instance Exception DummyException

spec :: Spec
spec = describe "Hydra.Pleco.Client.Errors" $ do
  describe "fromClientError" $ do
    it "maps ConnectionError to PlecoConnectionFailure" $
      hedgehog $ do
        baseUrl <- forAll Gen.baseUrl
        let servantErr = ConnectionError (SomeException DummyException)
        fromClientError baseUrl servantErr === PlecoConnectionFailure baseUrl

    it "maps FailureResponse to PlecoFailureResponse" $
      hedgehog $ do
        baseUrl <- forAll Gen.baseUrl
        status <- forAll Gen.status
        body <- forAll Gen.responseBody

        let servantErr = FailureResponse req resp
            req = Gen.failureRequest baseUrl
            resp = Response status mempty http11 (toLazy body)

            expectedBaseUrl = baseUrl {baseUrlPath = decodeUtf8 $ snd (requestPath req)}

        fromClientError baseUrl servantErr
          === PlecoFailureResponse expectedBaseUrl status body

    it "maps other ClientErrors to PlecoUnknownError" $
      hedgehog $ do
        baseUrl <- forAll Gen.baseUrl
        servantErr <- forAll Gen.unknownClientError

        fromClientError baseUrl servantErr === PlecoUnknownError baseUrl servantErr

    it "never produces PlecoInternalError" $
      hedgehog $ do
        baseUrl <- forAll Gen.baseUrl
        servantErr <- forAll Gen.clientError

        assert $ case fromClientError baseUrl servantErr of
          PlecoInternalError _ -> False
          _ -> True

  describe "displayException" $ do
    it "never indents the description" $
      hedgehog $ do
        err <- forAll Gen.plecoClientError
        case parseSections err of
          [] -> failure
          description : _ -> assert $ not (any isIndented (lines description))

    it "indents every line of the detail" $
      hedgehog $ do
        err <- forAll Gen.plecoClientError
        for_ (parseSections err) $ \section ->
          when (any isIndented (lines section)) $
            assert $
              all (isIndentedBy 2) (lines section)

    it "renders at most one indented section" $
      hedgehog $ do
        err <- forAll Gen.plecoClientError
        let detail = filter (any isIndented . lines) (parseSections err)
        assert $ length detail <= 1

    it "never renders more than one consecutive blank line" $
      hedgehog $ do
        err <- forAll Gen.plecoClientError
        assert $ not ("\n\n\n" `Text.isInfixOf` renderError err)

    it "never renders an empty section" $
      hedgehog $ do
        err <- forAll Gen.plecoClientError
        for_ (parseSections err) $ \section ->
          assert $ not (Text.null (Text.strip section))

-- | The rendered sections of an error, split on the blank lines around the detail
parseSections :: PlecoClientError -> [Text]
parseSections = Text.splitOn "\n\n" . renderError

-- | Render a 'PlecoClientError' as Text
renderError :: PlecoClientError -> Text
renderError = toText . displayException

-- | True if the text begins with a space
isIndented :: Text -> Bool
isIndented = Text.isPrefixOf " "

-- | True if the text begins with the specified number of spaces
isIndentedBy :: Int -> Text -> Bool
isIndentedBy n = Text.isPrefixOf (Text.replicate n " ")
