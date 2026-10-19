module Main (main) where

import Hydra.Pleco.Client
  ( BaseUrl (..),
    EvalId (..),
    JobsetSpec,
    PlecoClient,
    PlecoClientEnv,
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

data GlobalOpts = GlobalOpts
  { optUrl :: !BaseUrl,
    optJson :: !OutputJson,
    optPlain :: !OutputPlain,
    optCommand :: !Command
  }
  deriving stock (Show)

newtype OutputJson = OutputJson {unOutputJson :: Bool}
  deriving stock (Show)

newtype OutputPlain = OutputPlain {unOutputPlain :: Bool}
  deriving stock (Show)

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
main = Opt.execParser globalOpts >>= run

-- | Runs the 'PlecoClient' action
runClient :: PlecoClient a -> GlobalOpts -> IO a
runClient action opts = flip runPlecoClient action =<< fromGlobalOpts opts
  where
    fromGlobalOpts :: GlobalOpts -> IO PlecoClientEnv
    fromGlobalOpts GlobalOpts {optUrl} = mkPlecoClientEnv optUrl

-- | Same as @runClient@, but pretty prints the result as JSON
runClient' :: (ToJSON output, ToTable output) => PlecoClient output -> GlobalOpts -> IO ()
runClient' action opts = prettyPrint opts =<< runClient action opts

prettyPrint :: (ToJSON output, ToTable output) => GlobalOpts -> output -> IO ()
prettyPrint GlobalOpts {..}
  | unOutputJson optJson = putLBSLn . encodePretty
  | unOutputPlain optPlain = putTextLn . Client.renderPlain
  | otherwise = putTextLn . Client.renderTerminal

run :: GlobalOpts -> IO ()
run opts@GlobalOpts {optCommand}
  | CmdHealth <- optCommand = runHealth opts
  | CmdEcho EchoCmdOpts {echoOptPort} <- optCommand = runEcho echoOptPort
  | CmdProjects subCmd <- optCommand = runProjects subCmd opts
  | CmdJobsets subCmd <- optCommand = runJobsets subCmd opts
  | CmdEvals subCmd <- optCommand = runEvals subCmd opts

runHealth :: GlobalOpts -> IO ()
runHealth = runClient' getHealth

runEcho :: Port -> IO ()
runEcho = runEchoServer

runProjects :: ProjectsSubCommand -> GlobalOpts -> IO ()
runProjects CmdProjectsList = runClient' listProjects
runProjects (CmdProjectsView p) = runClient' (getProject p)

runJobsets :: JobsetsSubCommand -> GlobalOpts -> IO ()
runJobsets (CmdJobsetsList projectId) opts = runClient' (listJobsets projectId Nothing) opts
runJobsets (CmdJobsetsView jobset) opts = do
  res <- runClient (findJobset jobset) opts
  maybe
    (putTextLn $ "Jobset `" <> Client.renderJobsetSpec jobset <> "' not found!")
    (prettyPrint opts)
    res

runEvals :: EvalsSubCommand -> GlobalOpts -> IO ()
runEvals (CmdEvalsList jobset) = runClient' (listEvals jobset)
runEvals (CmdEvalsView evalId) = runClient' (getEval evalId)

globalOpts :: ParserInfo GlobalOpts
globalOpts =
  Opt.info (parser <**> Opt.helper) $
    Opt.fullDesc
      <> Opt.progDesc "Command line client for hydra-pleco API"
      <> Opt.header "hydra-pleco command-line client"

parser :: Parser GlobalOpts
parser = do
  GlobalOpts
    <$> parseUrlOpt
    <*> parseJsonOpt
    <*> parsePlainOpt
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

parseJsonOpt :: Parser OutputJson
parseJsonOpt =
  switch' $
    Opt.long "json"
      <> Opt.short 'j'
      <> Opt.help "Display output as formatted JSON"
  where
    switch' = fmap OutputJson . Opt.switch

parsePlainOpt :: Parser OutputPlain
parsePlainOpt =
  switch' $
    Opt.long "plain"
      <> Opt.short 'p'
      <> Opt.help "Display output as plain text"
  where
    switch' = fmap OutputPlain . Opt.switch

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
    Opt.metavar "PROJECT:NAME"
      <> Opt.help "Hydra jobset descriptor"
  where
    jsSpec :: ReadM JobsetSpec
    jsSpec = Opt.eitherReader $ withText Client.parseJobsetSpec

    withText :: (Text -> Either Text a) -> String -> Either String a
    withText f = first toString . f . toText

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
