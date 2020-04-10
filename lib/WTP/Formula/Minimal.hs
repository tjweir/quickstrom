{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module WTP.Formula.Minimal where

import Control.Monad.Freer
import WTP.Query
import WTP.Assertion
import Prelude hiding (False, True)

type IsQuery eff = Members '[Query] eff

data Formula where
  True :: Formula
  Not :: Formula -> Formula
  Or :: Formula -> Formula -> Formula
  Until :: Formula -> Formula -> Formula
  Assert :: Show a => Eff '[Query] a -> Assertion a -> Formula

withQueries :: Monad m => (forall a. Eff '[Query] a -> m b) -> Formula -> m [b]
withQueries f = \case
  True -> pure []
  Not p -> withQueries f p
  Or p q -> (<>) <$> withQueries f p <*> withQueries f q
  Until p q -> (<>) <$> withQueries f p <*> withQueries f q
  Assert q _ -> (: []) <$> f q

instance Show Formula where
  show = \case
    True -> "True"
    Not p -> "(Not " <> show p <> ")"
    Or p q -> "(Or " <> show p <> " " <> show q <> ")"
    Until p q -> "(Until " <> show p <> " " <> show q <> ")"
    Assert _ assertion -> "(Assert _ " <> show assertion <> ")"