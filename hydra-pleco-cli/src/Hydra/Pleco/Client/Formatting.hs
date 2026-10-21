{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Hydra.Pleco.Client.Formatting
  ( TableOutputStyle (..),
    TableOrientation (..),
    HeaderStyle (..),
    ToTable (..),
    toTableFancy,
    toTablePlain,
    toTable,
  ) where

import Hydra.Pleco.Api
  ( Eval (..),
    EvalId (..),
    Health (..),
    Jobset (..),
    JobsetName (..),
    Project (..),
    ProjectId (..),
  )

import Data.Text qualified as Text
import System.Console.ANSI (ConsoleIntensity (..), SGR (..), Underlining (..), setSGRCode)
import Text.Layout.Table
  ( ColSpec,
    HeaderColSpec,
    HeaderSpec,
    LineStyle,
    RowGroup,
    TableSpec,
    TableStyle,
  )
import Text.Layout.Table qualified as Table
import Text.Layout.Table.Cell (Cell (..), CellView (..))
import Text.Layout.Table.Spec.HeaderSpec (HeaderSpec (..))
import Text.Layout.Table.StringBuilder (StringBuilder (..))

-- | Global table style; Indicates whether the output can contain ANSI escape sequences,
-- depending on:
--
--  * User passed '--plain', '--json'
--  * Program is running in a terminal
data TableOutputStyle
  = TsFancy
  | TsPlain
  deriving stock (Eq, Enum, Ord, Show)

data TableOrientation
  = TStandard
  | TTransposed
  deriving stock (Eq, Enum, Ord, Show)

-- | Header style for tables. Normal tables have headers underlined; Transposed tables are
-- bold.
data HeaderStyle
  = HsUnderline
  | HsBold
  | HsPlain
  deriving stock (Eq, Enum, Ord, Show)

-- | A header style paired with its text content
data HeaderCell = HeaderCell
  { hcStyle :: HeaderStyle,
    hcLabel :: Text
  }
  deriving stock (Eq, Ord, Show)

class ToTable a where
  {-# MINIMAL colSpecs, headerSpec, rowGroups #-}

  colSpecs :: Proxy a -> [ColSpec]

  headerSpec :: Proxy a -> HeaderStyle -> HeaderSpec LineStyle HeaderCell

  rowGroups :: a -> [RowGroup Text]

  tableOrientation :: Proxy a -> TableOrientation
  tableOrientation _ = TStandard

instance Cell HeaderCell where
  visibleLength = visibleLength . hcLabel
  measureAlignment f = measureAlignment f . hcLabel

  buildCellView :: (StringBuilder b) => CellView HeaderCell -> b
  buildCellView view@(CellView (HeaderCell style _) _ _) =
    withSgrStyle style (buildHeaderCellView view)
    where
      withSgrStyle :: (StringBuilder builder) => HeaderStyle -> builder -> builder
      withSgrStyle HsPlain text = text
      withSgrStyle style' text =
        stringB (setSGRCode $ sgrStyle style')
          <> text
          <> stringB (setSGRCode $ sgrReset style')

      sgrStyle HsUnderline = [SetUnderlining SingleUnderline]
      sgrStyle HsBold = [SetConsoleIntensity BoldIntensity]
      sgrStyle HsPlain = []

      sgrReset HsUnderline = [Reset]
      sgrReset HsBold = [Reset]
      sgrReset HsPlain = []

buildHeaderCellView :: (StringBuilder builder) => CellView HeaderCell -> builder
buildHeaderCellView (CellView (HeaderCell _ text) adjustL adjustR) =
  case (compare adjustL 0, compare adjustR 0) of
    (GT, GT) -> padB adjustL <> textB text <> padB adjustR
    (GT, LT) -> padB adjustL <> trimR (negate adjustR) text
    (GT, EQ) -> padB adjustL <> textB text
    (LT, GT) -> trimL (negate adjustL) text <> padB adjustR
    (LT, LT) -> trimBoth (negate adjustL) (negate adjustR) text
    (LT, EQ) -> trimL (negate adjustL) text
    (EQ, GT) -> textB text <> padB adjustR
    (EQ, LT) -> trimR (negate adjustR) text
    (EQ, EQ) -> textB text
  where
    trimL count = textB . Text.drop count
    trimR count = textB . Text.dropEnd count
    trimBoth left right = textB . Text.drop left . Text.dropEnd right

    padB size = replicateCharB size ' '

instance ToTable Health where
  colSpecs _ = [defColSpec']
  headerSpec _ style = titlesH' [HeaderCell style "Status"]
  rowGroups Health {..} = [Table.rowG [hlStatus]]
  tableOrientation _ = TTransposed

instance ToTable Project where
  colSpecs _ = [defColSpec']

  headerSpec _ style =
    titlesH'
      [ HeaderCell style "Project ID",
        HeaderCell style "Enabled",
        HeaderCell style "Visible",
        HeaderCell style "Description"
      ]

  rowGroups Project {..} =
    [ Table.rowG [unProjectId prjId],
      Table.rowG [formatBool prjEnabled],
      Table.rowG [formatBool prjVisible],
      Table.rowG [fromMaybe "<null>" prjDescription]
    ]

  tableOrientation _ = TTransposed

instance ToTable [Project] where
  colSpecs _ = replicate 4 defColSpec'

  headerSpec _ style =
    titlesH'
      [ HeaderCell style "Project ID",
        HeaderCell style "Enabled",
        HeaderCell style "Visible",
        HeaderCell style "Description"
      ]

  rowGroups projects =
    projects <&> \Project {..} ->
      Table.rowG
        [ unProjectId prjId,
          formatBool prjEnabled,
          formatBool prjVisible,
          fromMaybe "<null>" prjDescription
        ]

instance ToTable Jobset where
  colSpecs _ = replicate 6 defColSpec'

  headerSpec _ style =
    titlesH'
      [ HeaderCell style "Jobset Name",
        HeaderCell style "Project",
        HeaderCell style "Visible",
        HeaderCell style "Description",
        HeaderCell style "Last Checked",
        HeaderCell style "Last Evaluated"
      ]

  rowGroups Jobset {..} =
    [ Table.rowG [unJobsetName jsName],
      Table.rowG [unProjectId jsProject],
      Table.rowG [formatBool jsVisible],
      Table.rowG [fromMaybe "<null>" jsDescription],
      Table.rowG [maybe "<null>" Text.show jsLastCheckedTime],
      Table.rowG [maybe "<null>" Text.show jsLastEvalTime]
    ]

  tableOrientation _ = TTransposed

instance ToTable [Jobset] where
  colSpecs _ = replicate 6 defColSpec'
  headerSpec _ style =
    titlesH'
      [ HeaderCell style "JOBSET NAME",
        HeaderCell style "PROJECT",
        HeaderCell style "VISIBLE",
        HeaderCell style "DESCRIPTION",
        HeaderCell style "LAST CHECKED",
        HeaderCell style "LAST EVALUATED"
      ]

  rowGroups jobsets =
    jobsets <&> \Jobset {..} ->
      Table.rowG
        [ unJobsetName jsName,
          unProjectId jsProject,
          formatBool jsVisible,
          fromMaybe "<null>" jsDescription,
          maybe "<null>" Text.show jsLastCheckedTime,
          maybe "<null>" Text.show jsLastEvalTime
        ]

instance ToTable Eval where
  colSpecs _ = replicate 3 defColSpec'

  headerSpec _ style =
    titlesH'
      [ HeaderCell style "Eval ID",
        HeaderCell style "Builds",
        HeaderCell style "Succeeded"
      ]

  rowGroups Eval {..} =
    [ Table.rowG [Text.show (unEvalId evId)],
      Table.rowG [maybe "0" Text.show evNumBuilds],
      Table.rowG [maybe "0" Text.show evNumSucceeded]
    ]

  tableOrientation _ = TTransposed

instance ToTable [Eval] where
  colSpecs _ = replicate 3 defColSpec'

  headerSpec _ style =
    titlesH'
      [ HeaderCell style "ID",
        HeaderCell style "BUILDS",
        HeaderCell style "SUCCEEDED"
      ]

  rowGroups evals =
    evals <&> \Eval {..} ->
      Table.rowG
        [ Text.show (unEvalId evId),
          maybe "0" Text.show evNumBuilds,
          maybe "0" Text.show evNumSucceeded
        ]

toTable
  :: forall a
   . (ToTable a)
  => TableOutputStyle
  -> Maybe Text
  -> a
  -> Text
toTable style header =
  (mkHeader style header <>)
    . Table.tableStringB
    . mkTableSpec orientation colSpecs' headerSpec'
    . rowGroups
  where
    orientation = tableOrientation @a Proxy
    colSpecs' = colSpecs @a Proxy
    headerSpec' = headerSpec @a Proxy (mkTableHeaderStyle style orientation)

    mkHeader TsPlain _ = ""
    mkHeader TsFancy Nothing = ""
    mkHeader TsFancy (Just title) =
      toText (setSGRCode [SetUnderlining SingleUnderline])
        <> title
        <> toText (setSGRCode [Reset])
        <> "\n"

    mkTableSpec TStandard = columnHeaderTableS'
    mkTableSpec TTransposed = rowHeaderTableS'

    mkTableHeaderStyle TsPlain _ = HsPlain
    mkTableHeaderStyle TsFancy TStandard = HsUnderline
    mkTableHeaderStyle TsFancy TTransposed = HsBold

toTableFancy :: (ToTable a) => Maybe Text -> a -> Text
toTableFancy = toTable TsFancy

toTablePlain :: (ToTable a) => Maybe Text -> a -> Text
toTablePlain = toTable TsPlain

-- * 'ToTable'/'TableSpec' building blocks

formatBool :: Bool -> Text
formatBool True = textB "true"
formatBool False = textB "false"

titlesH' :: [a] -> HeaderSpec LineStyle a
titlesH' = Table.fullSepH Table.NoLine (repeat defHeaderColSpec')

defHeaderColSpec' :: HeaderColSpec
defHeaderColSpec' = Table.headerColumn Table.left Nothing

defColSpec' :: ColSpec
defColSpec' = Table.defColSpec

noneH' :: HeaderSpec LineStyle HeaderCell
noneH' = NoneHS Table.NoLine

rowHeaderTableS'
  :: [ColSpec]
  -> HeaderSpec LineStyle HeaderCell
  -> [RowGroup Text]
  -> TableSpec LineStyle LineStyle HeaderCell HeaderCell Text
rowHeaderTableS' cols headers = fullTableS' cols headers noneH'

columnHeaderTableS'
  :: [ColSpec]
  -> HeaderSpec LineStyle HeaderCell
  -> [RowGroup Text]
  -> TableSpec LineStyle LineStyle HeaderCell HeaderCell Text
columnHeaderTableS' cols = fullTableS' cols noneH'

fullTableS'
  :: [ColSpec]
  -> HeaderSpec LineStyle HeaderCell
  -> HeaderSpec LineStyle HeaderCell
  -> [RowGroup a]
  -> TableSpec LineStyle LineStyle HeaderCell HeaderCell a
fullTableS' cols = Table.fullTableS cols unicodeTableStyle'

unicodeTableStyle' :: TableStyle LineStyle LineStyle
unicodeTableStyle' =
  Table.unicodeTableStyleFromSpec $
    Table.setTableStyleSpecSeparator Table.NoLine $
      Table.simpleTableStyleSpec Table.NoLine Table.NoLine
