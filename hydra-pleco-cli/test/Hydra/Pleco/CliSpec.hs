module Hydra.Pleco.CliSpec (spec) where

import Hydra.Pleco.Client

import Servant.Client (ClientEnv (..))
import Test.Hspec

spec :: Spec
spec = do
  describe "mkPlecoClientEnv" $ do
    it "sets expected BaseUrl" $ do
      let baseUrl' = BaseUrl Http "localhost" 8081 ""
      manager' <- newManager defaultManagerSettings

      let env = mkPlecoClientEnv manager' baseUrl'

      baseUrl (pceClientEnv env) `shouldBe` baseUrl'
