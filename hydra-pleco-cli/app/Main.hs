module Main (main) where

import Hydra.Pleco.Client
  ( BaseUrl (..),
    EvalId (..),
    JobsetSpec,
    PlecoClient,
    PlecoClientError,
    ProjectId (..),
    Scheme (..),
    ToJSON,
    ToTable,
    encodePretty,
    findJobset,
    getEval,
    getHealth,
    getProject,
    listEvals,
    listJobsets,
    listProjects,
    mkPlecoClientEnv,
    parseBaseUrl,
    runEchoServer,
    runPlecoClient,
  )

import Hydra.Pleco.Client qualified as Client
import Network.Wai.Handler.Warp (Port)
import Options.Applicative (Parser, ParserInfo, ReadM)
import Options.Applicative qualified as Opt
import System.IO (hPutStrLn)
import UnliftIO.Exception (Handler (Handler), catches)

data GlobalOpts = GlobalOpts
  { optUrl :: !BaseUrl,
    optFormat :: !OutputFormat,
    optCommand :: !Command
  }
  deriving stock (Show)

data OutputFormat
  = Json
  | Plain
  | Terminal
  deriving stock (Eq, Enum, Ord, Show)

data Command
  = CmdHealth
  | CmdEcho EchoCmdOpts
  | CmdProjects ProjectsSubCommand
  | CmdJobsets JobsetsSubCommand
  | CmdEvals EvalsSubCommand
  deriving stock (Eq, Ord, Show)

newtype EchoCmdOpts = EchoCmdOpts
  { echoOptPort :: Port
  }
  deriving stock (Eq, Ord, Show)

data ProjectsSubCommand
  = CmdProjectsList
  | CmdProjectsView ProjectId
  deriving stock (Eq, Ord, Show)

data JobsetsSubCommand
  = CmdJobsetsList ProjectId
  | CmdJobsetsView JobsetSpec
  deriving stock (Eq, Ord, Show)

data EvalsSubCommand
  = CmdEvalsList JobsetSpec
  | CmdEvalsView EvalId
  deriving stock (Eq, Ord, Show)

main :: IO ()
main = do
  outputFormat <- defaultOutputFormat
  opts <- Opt.execParser (globalOpts outputFormat)
  run opts
    `catches` [ Handler reportError,
                Handler reportInternalError
              ]

-- | Catch-all handler for any Exception that is not a 'PlecoClientError'
reportInternalError :: SomeException -> IO a
reportInternalError = reportError . Client.PlecoInternalError . toText . displayException

-- | Write an error to stderr and exit non-zero
reportError :: PlecoClientError -> IO a
reportError err = hPutStrLn stderr (displayException err) >> exitFailure

-- | Runs the 'PlecoClient' action
runClient :: PlecoClient a -> GlobalOpts -> IO a
runClient action opts = do
  env <- mkPlecoClientEnv (optUrl opts)
  runPlecoClient env action

-- | Same as @runClient@, but pretty prints the result as JSON
runClient'
  :: (ToJSON output, ToTable output)
  => PlecoClient output
  -> Maybe Text
  -> GlobalOpts
  -> IO ()
runClient' action title opts = prettyPrint title opts =<< runClient action opts

-- | Output the result in the requested format: JSON, Colorized Terminal Text, or Plain Text
prettyPrint :: (ToJSON output, ToTable output) => Maybe Text -> GlobalOpts -> output -> IO ()
prettyPrint title GlobalOpts {optFormat} output =
  case optFormat of
    Json -> putLBSLn (encodePretty output)
    Plain -> putTextLn (Client.renderPlain title output)
    Terminal -> putTextLn (Client.renderTerminal title output)

-- | The format used when the user names neither '--json' nor '--plain'
defaultOutputFormat :: IO OutputFormat
defaultOutputFormat = do
  noColor <- lookupEnv "NO_COLOR"
  pure $ case noColor of
    Just value | value /= "" -> Plain
    _ -> Terminal

run :: GlobalOpts -> IO ()
run opts@GlobalOpts {optCommand}
  | CmdHealth <- optCommand = runHealth opts
  | CmdEcho EchoCmdOpts {echoOptPort} <- optCommand = runEcho echoOptPort
  | CmdProjects subCmd <- optCommand = runProjects subCmd opts
  | CmdJobsets subCmd <- optCommand = runJobsets subCmd opts
  | CmdEvals subCmd <- optCommand = runEvals subCmd opts

runHealth :: GlobalOpts -> IO ()
runHealth = runClient' getHealth (Just "Server Health")

runEcho :: Port -> IO ()
runEcho = runEchoServer

runProjects :: ProjectsSubCommand -> GlobalOpts -> IO ()
runProjects CmdProjectsList = runClient' listProjects Nothing
runProjects (CmdProjectsView p) = runClient' (getProject p) (Just header)
  where
    header = "Project " <> unProjectId p

runJobsets :: JobsetsSubCommand -> GlobalOpts -> IO ()
runJobsets (CmdJobsetsList projectId) opts =
  runClient' (listJobsets projectId Nothing) Nothing opts
runJobsets (CmdJobsetsView jobset) opts = do
  res <- runClient (findJobset jobset) opts
  maybe
    (putTextLn $ "Jobset `" <> Client.renderJobsetSpec jobset <> "' not found!")
    (prettyPrint (Just header) opts)
    res
  where
    header = "Jobset " <> Client.renderJobsetSpec jobset

runEvals :: EvalsSubCommand -> GlobalOpts -> IO ()
runEvals (CmdEvalsList jobset) = runClient' (listEvals jobset) Nothing
runEvals (CmdEvalsView evalId) = runClient' (getEval evalId) (Just header)
  where
    header = "Eval #" <> show (unEvalId evalId)

globalOpts :: OutputFormat -> ParserInfo GlobalOpts
globalOpts defFormat =
  Opt.info (parser defFormat <**> Opt.helper) $
    Opt.fullDesc
      <> Opt.progDesc "Command line client for hydra-pleco API"
      <> Opt.header "hydra-pleco command-line client"

parser :: OutputFormat -> Parser GlobalOpts
parser defFormat = do
  GlobalOpts
    <$> parseUrlOpt
    <*> parseOutputFormat defFormat
    <*> parseCommand

parseUrlOpt :: Parser BaseUrl
parseUrlOpt =
  Opt.option readBaseUrl $
    Opt.long "url"
      <> Opt.short 'u'
      <> Opt.value (BaseUrl Http "localhost" 8081 "")
      <> Opt.help "Pleco server endpoint URL"
  where
    readBaseUrl :: ReadM BaseUrl
    readBaseUrl = Opt.eitherReader $ first displayException . parseBaseUrl

parseOutputFormat :: OutputFormat -> Parser OutputFormat
parseOutputFormat defFormat =
  fromMaybe defFormat <$> optional (parseJsonOpt <|> parsePlainOpt)

parseJsonOpt :: Parser OutputFormat
parseJsonOpt =
  Opt.flag' Json $
    Opt.long "json"
      <> Opt.short 'j'
      <> Opt.help "Display output as formatted JSON"

parsePlainOpt :: Parser OutputFormat
parsePlainOpt =
  Opt.flag' Plain $
    Opt.long "plain"
      <> Opt.short 'p'
      <> Opt.help "Display output as plain text"

parseCommand :: Parser Command
parseCommand =
  Opt.hsubparser $
    Opt.command "health" parseHealthCmd
      <> Opt.command "echo" parseEchoCmd
      <> Opt.command "project" projectsOpts
      <> Opt.command "jobset" jobsetsOpts
      <> Opt.command "eval" evalsOpts

parseHealthCmd :: ParserInfo Command
parseHealthCmd = Opt.info parseHealthOpt healthCmdInfo
  where
    parseHealthOpt = pure CmdHealth
    healthCmdInfo = Opt.progDesc "Check the server's health"

parseEchoCmd :: ParserInfo Command
parseEchoCmd = Opt.info (CmdEcho <$> parseEchoOpt) echoCmdInfo
  where
    echoCmdInfo = Opt.progDesc "Receive jobset event callbacks and print them"

parseEchoOpt :: Parser EchoCmdOpts
parseEchoOpt = EchoCmdOpts <$> parseEchoPortOpt

parseEchoPortOpt :: Parser Port
parseEchoPortOpt =
  Opt.option Opt.auto $
    Opt.long "port"
      <> Opt.short 'p'
      <> Opt.value 8888
      <> Opt.showDefault
      <> Opt.metavar "PORT"
      <> Opt.help "Port to listen on"

projectsOpts :: ParserInfo Command
projectsOpts = Opt.info (CmdProjects <$> parseProjectsCmd) projectsCmdInfo
  where
    projectsCmdInfo = Opt.progDesc "List or view Hydra projects"

parseProjectsCmd :: Parser ProjectsSubCommand
parseProjectsCmd =
  Opt.hsubparser $
    Opt.command "list" parseProjectsListCmd
      <> Opt.command "view" parseProjectsViewCmd

parseProjectsListCmd :: ParserInfo ProjectsSubCommand
parseProjectsListCmd = Opt.info (pure CmdProjectsList) projectsListCmdInfo
  where
    projectsListCmdInfo = Opt.progDesc "List all Hydra projects"

parseProjectsViewCmd :: ParserInfo ProjectsSubCommand
parseProjectsViewCmd = Opt.info parseCmd cmdInfo
  where
    cmdInfo = Opt.progDesc "View a Hydra project"
    parseCmd = CmdProjectsView <$> parseProjectId

parseProjectId :: Parser ProjectId
parseProjectId =
  Opt.argument (ProjectId <$> Opt.str) $
    Opt.metavar "NAME"
      <> Opt.help "Hydra project identifier"

jobsetsOpts :: ParserInfo Command
jobsetsOpts = Opt.info (CmdJobsets <$> parseJobsetsCmd) jobsetsCmdInfo
  where
    jobsetsCmdInfo = Opt.progDesc "List or view Hydra jobsets"

parseJobsetsCmd :: Parser JobsetsSubCommand
parseJobsetsCmd =
  Opt.hsubparser $
    Opt.command "list" parseJobsetsListCmd
      <> Opt.command "view" parseJobsetsViewCmd

parseJobsetsListCmd :: ParserInfo JobsetsSubCommand
parseJobsetsListCmd =
  Opt.info (CmdJobsetsList <$> parseProjectId) jobsetsListCmdInfo
  where
    jobsetsListCmdInfo = Opt.progDesc "List a Hydra jobsets for a project"

parseJobsetsViewCmd :: ParserInfo JobsetsSubCommand
parseJobsetsViewCmd =
  Opt.info (CmdJobsetsView <$> parseJobsetSpec') jobsetsViewCmdInfo
  where
    jobsetsViewCmdInfo = Opt.progDesc "View a Hydra jobset"

parseJobsetSpec' :: Parser JobsetSpec
parseJobsetSpec' =
  Opt.argument jsSpec $
    Opt.metavar "PROJECT:JOBSET_NAME"
      <> Opt.help "Hydra jobset descriptor"
  where
    jsSpec :: ReadM JobsetSpec
    jsSpec = Opt.eitherReader (withText Client.parseJobsetSpec)

    withText :: (Text -> Either PlecoClientError a) -> String -> Either String a
    withText f = first displayException . f . toText

evalsOpts :: ParserInfo Command
evalsOpts = Opt.info (CmdEvals <$> parseEvalsCmd) evalsCmdInfo
  where
    evalsCmdInfo = Opt.progDesc "List or view Hydra jobset evaluations"

parseEvalsCmd :: Parser EvalsSubCommand
parseEvalsCmd =
  Opt.hsubparser $
    Opt.command "list" parseEvalsListCmd
      <> Opt.command "view" parseEvalsViewCmd

parseEvalsListCmd :: ParserInfo EvalsSubCommand
parseEvalsListCmd =
  Opt.info (CmdEvalsList <$> parseJobsetSpec') evalsListCmdInfo
  where
    evalsListCmdInfo = Opt.progDesc "List the evaluations of a Hydra jobset"

parseEvalsViewCmd :: ParserInfo EvalsSubCommand
parseEvalsViewCmd =
  Opt.info (CmdEvalsView <$> parseEvalId) evalsViewCmdInfo
  where
    evalsViewCmdInfo = Opt.progDesc "View a Hydra jobset evaluation"

parseEvalId :: Parser EvalId
parseEvalId =
  Opt.argument (EvalId <$> Opt.auto) $
    Opt.metavar "ID"
      <> Opt.help "Hydra jobset evaluation identifier"
