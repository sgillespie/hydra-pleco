module Hydra.Pleco.Api.Gen
  ( health,
    subscription,
  ) where

import Hydra.Pleco.Api (Health (..), Subscription (..))

import Hedgehog (Gen)
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range

health :: Gen Health
health = Health <$> Gen.element ["pass", "fail", "warn"]

subscription :: Gen Subscription
subscription = Subscription <$> Gen.text len chars
  where
    -- maximum length of URL is essentially 2048
    len = Range.linear 0 2048
    -- latin1 should cover any URL-encoded string
    chars = Gen.latin1
