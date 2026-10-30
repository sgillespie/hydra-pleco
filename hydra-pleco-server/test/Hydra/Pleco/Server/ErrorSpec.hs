module Hydra.Pleco.Server.ErrorSpec (spec) where

import Hydra.Pleco.Api (ProblemDetails (..), ProjectId (..), StatusCode (..))
import Hydra.Pleco.Api.Gen qualified as ApiGen
import Hydra.Pleco.Server.Error (noSuchProjectError, serverError)
import Hydra.Pleco.Server.Gen qualified as Gen

import Data.Aeson qualified as Aeson
import Data.List (lookup)
import Network.HTTP.Types (hContentType)
import Servant.Server (ServerError (..))
import Test.Hspec
import Test.Hspec.Hedgehog (evalEither, forAll, hedgehog, (===))

spec :: Spec
spec = describe "Hydra.Pleco.Server.Error" $ do
  let project = ProjectId "bogus-project"

  describe "serverError" $
    it "reports the response status in pdStatus" $
      hedgehog $ do
        problemTy <- forAll Gen.problemType
        detail <- forAll ApiGen.title

        let err = serverError problemTy detail
        problem <- evalEither $ Aeson.eitherDecode (errBody err)

        pdStatus problem === StatusCode (errHTTPCode err)

  describe "noSuchProjectError" $ do
    it "returns a 404" $
      errHTTPCode (noSuchProjectError project) `shouldBe` 404

    it "serves problem+json" $
      lookup hContentType (errHeaders (noSuchProjectError project))
        `shouldBe` Just "application/problem+json"
