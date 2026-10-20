module Hydra.Pleco.Api.Golden
  ( goldenText,
  ) where

import System.FilePath ((</>))
import Test.Hspec.Golden (Golden (..))

-- | Golden tests where the output is 'String' and files are written to 'data'
goldenText :: FilePath -> Text -> Golden Text
goldenText name output =
  Golden
    { output = output,
      encodePretty = show,
      writeToFile = writeToFile',
      readFromFile = fmap decodeUtf8 . readFileBS,
      goldenFile = "data" </> name </> "golden",
      actualFile = Just ("data" </> name </> "actual"),
      failFirstTime = False
    }
  where
    writeToFile' path = writeFileBS path . encodeUtf8
