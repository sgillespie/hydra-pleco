module Hydra.Pleco.App
  ( App (..),
    Env (..),
    runApp,
  ) where

import UnliftIO (MonadUnliftIO)

-- | The daemon's application monad: @ReaderT Env IO@.
newtype App a = App {unApp :: ReaderT Env IO a}
  deriving newtype
    ( Functor,
      Applicative,
      Monad,
      MonadReader Env,
      MonadIO,
      MonadUnliftIO
    )

-- | The runtime environment threaded through 'App'. A placeholder for now;
-- the DB pool, config, and listener handle land here.
data Env = Env
  deriving stock (Eq, Show)

runApp :: (MonadIO io) => App a -> Env -> io a
runApp act env = liftIO $ runReaderT (unApp act) env
