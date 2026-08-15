module Hydra.Pleco.Api.Gen (health) where

import Hydra.Pleco.Api (Health (..))

import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen

health :: Gen Health
health = Health <$> Gen.element ["pass", "fail", "warn"]
