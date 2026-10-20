module Hydra.Pleco.Api.OpenApiSpec (spec) where

import Hydra.Pleco.Api (hydraOpenApi)
import Hydra.Pleco.Api.Golden (goldenText)

import Data.Aeson.Encode.Pretty qualified as Pretty
import Optics (At (..), (%), (^?))
import Optics.Extra (_Just)
import Test.Hspec

spec :: Spec
spec = describe "hydraOpenApi" $ do
  it "matches the golden output" $ do
    let prettyOut = decodeUtf8 (Pretty.encodePretty hydraOpenApi)
    goldenText "openapi.json" prettyOut

  it "adds webhooks callback" $ do
    let webhooksCallback =
          #paths
            % at "/webhooks"
            % _Just
            % #post
            % _Just
            % #callbacks
            % at "jobsetEvent"
            % _Just

    hydraOpenApi ^? webhooksCallback `shouldSatisfy` isJust
