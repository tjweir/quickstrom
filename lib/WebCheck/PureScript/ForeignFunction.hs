{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module WebCheck.PureScript.ForeignFunction where

import Data.HashMap.Strict (HashMap)
import Data.Vector (Vector)
import qualified Data.Vector as Vector
import GHC.TypeNats (type (+))
import Language.PureScript.AST (SourceSpan)
import Language.PureScript.Names
import Protolude hiding (Selector)
import WebCheck.Action (Action (..))
import WebCheck.Element (Selector (..))
import WebCheck.Path
import WebCheck.PureScript.Eval
import WebCheck.PureScript.Eval.Error
import WebCheck.PureScript.Value

data ForeignFunction m arity where
  Base :: FromHaskellValue a => m a -> ForeignFunction m 0
  Ind :: ToHaskellValue m a => (a -> ForeignFunction m n) -> ForeignFunction m (n + 1)
  NotSupported :: Qualified Ident -> ForeignFunction m 0

evalForeignFunction :: MonadError EvalError m => ForeignFunction m arity -> SourceSpan -> [Value EvalAnn] -> m (Value EvalAnn)
evalForeignFunction (Base x) _ [] = fromHaskellValue <$> x
evalForeignFunction (Ind f) ss (arg : args) = do
  ff <- f <$> toHaskellValue ss arg
  evalForeignFunction ff ss args
evalForeignFunction (NotSupported qn) ss _ = throwError (ForeignFunctionNotSupported ss qn)
evalForeignFunction _ ss _ = foreignFunctionArityMismatch ss

foreignFunctionArity :: KnownNat arity => ForeignFunction m arity -> Int
foreignFunctionArity (_ :: ForeignFunction m arity) = fromIntegral (natVal (Proxy @arity))

type family FunctionArity (f :: *) where
  FunctionArity (a -> b) = FunctionArity b + 1
  FunctionArity a = 0

type family IsBaseCase (f :: *) where
  IsBaseCase (a -> b) = 'False
  IsBaseCase a = 'True

functionArity :: (KnownNat (FunctionArity f)) => Proxy f -> Int
functionArity (_ :: Proxy f) = fromIntegral (natVal (Proxy :: Proxy (FunctionArity f)))

foreignFunctionArityMismatch :: MonadError EvalError m => SourceSpan -> m a
foreignFunctionArityMismatch ss = throwError (ForeignFunctionError (Just ss) "Foreign function arity mismatch")

newtype Ret m a = Ret {unRet :: m a}
  deriving (Functor, Applicative, Monad)

class ToForeignFunction m arity f | f -> m arity where
  toForeignFunction :: f -> ForeignFunction m arity

instance
  ( Functor m,
    FromHaskellValue a,
    m ~ n
  ) =>
  ToForeignFunction m 0 (Ret m a)
  where
  toForeignFunction x = Base (unRet x)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    FromHaskellValue b
  ) =>
  ToForeignFunction m 1 (a -> Ret m b)
  where
  toForeignFunction f = Ind $ \a -> do
    toForeignFunction (f a)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    ToHaskellValue m b,
    FromHaskellValue c
  ) =>
  ToForeignFunction m 2 (a -> b -> Ret m c)
  where
  toForeignFunction f = Ind $ \a -> Ind $ \b -> do
    toForeignFunction (f a b)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    ToHaskellValue m b,
    ToHaskellValue m c,
    FromHaskellValue d
  ) =>
  ToForeignFunction m 3 (a -> b -> c -> Ret m d)
  where
  toForeignFunction f = Ind $ \a -> Ind $ \b -> Ind $ \c -> do
    toForeignFunction (f a b c)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    ToHaskellValue m b,
    ToHaskellValue m c,
    ToHaskellValue m d,
    FromHaskellValue e
  ) =>
  ToForeignFunction m 4 (a -> b -> c -> d -> Ret m e)
  where
  toForeignFunction f = Ind $ \a -> Ind $ \b -> Ind $ \c -> Ind $ \d -> do
    toForeignFunction (f a b c d)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    ToHaskellValue m b,
    ToHaskellValue m c,
    ToHaskellValue m d,
    ToHaskellValue m e,
    FromHaskellValue f
  ) =>
  ToForeignFunction m 5 (a -> b -> c -> d -> e-> Ret m f)
  where
  toForeignFunction f = Ind $ \a -> Ind $ \b -> Ind $ \c -> Ind $ \d -> Ind $ \e -> do
    toForeignFunction (f a b c d e)

instance
  ( MonadError EvalError m,
    ToHaskellValue m a,
    ToHaskellValue m b,
    ToHaskellValue m c,
    ToHaskellValue m d,
    ToHaskellValue m e,
    ToHaskellValue m f,
    FromHaskellValue g
  ) =>
  ToForeignFunction m 6 (a -> b -> c -> d -> e -> f -> Ret m g)
  where
  toForeignFunction f' = Ind $ \a -> Ind $ \b -> Ind $ \c -> Ind $ \d -> Ind $ \e -> Ind $ \f -> do
    toForeignFunction (f' a b c d e f)

class MonadError EvalError m => ToHaskellValue m r where
  toHaskellValue :: SourceSpan -> Value EvalAnn -> m r

instance (MonadError EvalError m) => ToHaskellValue m (Value EvalAnn) where
  toHaskellValue _ = pure

instance MonadError EvalError m => ToHaskellValue m Bool where
  toHaskellValue ss = require ss (Proxy @"VBool")

instance MonadError EvalError m => ToHaskellValue m Text where
  toHaskellValue ss = require ss (Proxy @"VString")

instance MonadError EvalError m => ToHaskellValue m Char where
  toHaskellValue ss = require ss (Proxy @"VChar")

instance MonadError EvalError m => ToHaskellValue m Int where
  toHaskellValue ss = require ss (Proxy @"VInt")

instance MonadError EvalError m => ToHaskellValue m Double where
  toHaskellValue ss = require ss (Proxy @"VNumber")

instance ToHaskellValue m a => ToHaskellValue m (Vector a) where
  toHaskellValue ss = traverse (toHaskellValue ss) <=< require ss (Proxy @"VArray")

instance ToHaskellValue m a => ToHaskellValue m [a] where
  toHaskellValue ss x = Vector.toList <$> toHaskellValue ss x

instance ToHaskellValue m a => ToHaskellValue m (HashMap Text a) where
  toHaskellValue ss = traverse (toHaskellValue ss) <=< require ss (Proxy @"VObject")

instance MonadError EvalError m => ToHaskellValue m (Action Selector) where
  toHaskellValue ss v = do
    obj <- require ss (Proxy @"VObject") v
    ctor <- require ss (Proxy @"VString") =<< accessField ss "constructor" obj
    value <- Vector.head <$> (require ss (Proxy @"VArray") =<< accessField ss "fields" obj)
    case ctor of
      "Focus" -> Focus . Selector <$> toHaskellValue ss value
      "KeyPress" -> KeyPress <$> toHaskellValue ss value
      "Click" -> Click . Selector <$> toHaskellValue ss value
      "Navigate" -> Navigate . Path <$> toHaskellValue ss value
      _ -> throwError (ForeignFunctionError (Just ss) ("Unknown Action constructor: " <> ctor))

instance (MonadEval m, FromHaskellValue a, ToHaskellValue m b) => ToHaskellValue m (a -> m b) where
  toHaskellValue ss fn =
    pure
      ( \x -> do
          fn' <- require ss (Proxy @"VFunction") fn
          b <- evalFunc fn' (fromHaskellValue x)
          toHaskellValue ss b
      )

instance (MonadEval m, FromHaskellValue a, FromHaskellValue b, ToHaskellValue m c) => ToHaskellValue m (a -> b -> m c) where
  toHaskellValue ss fn = do
    pure
      ( \a b -> do
          fn' <- require ss (Proxy @"VFunction") fn
          fn'' <- require ss (Proxy @"VFunction") =<< evalFunc fn' (fromHaskellValue a)
          c <- evalFunc fn'' (fromHaskellValue b)
          toHaskellValue ss c
      )

class FromHaskellValue a where
  fromHaskellValue :: a -> Value EvalAnn

instance FromHaskellValue Bool where
  fromHaskellValue = VBool

instance FromHaskellValue Int where
  fromHaskellValue = VInt

instance FromHaskellValue Double where
  fromHaskellValue = VNumber

instance FromHaskellValue Char where
  fromHaskellValue = VChar

instance FromHaskellValue Text where
  fromHaskellValue = VString

instance FromHaskellValue a => FromHaskellValue (Vector a) where
  fromHaskellValue xs = VArray (fromHaskellValue <$> xs)

instance FromHaskellValue a => FromHaskellValue [a] where
  fromHaskellValue = fromHaskellValue . Vector.fromList

instance FromHaskellValue (Value EvalAnn) where
  fromHaskellValue = identity

-- foo :: MonadEval m => ForeignFunction m
-- foo = ForeignFunction 1 (evalForeignFunction arrayBind)

-- arrayBind :: (MonadEval m, a ~ Value EvalAnn, b ~ Value EvalAnn) => Vector a -> (a -> m (Vector b)) -> Ret (m (Vector b))
-- arrayBind xs f = Ret $ join <$> traverse f xs

-- bar :: MonadEval m => Proxy m -> ForeignFunction m
-- bar (Proxy :: Proxy m) = ForeignFunction 0 (evalForeignFunction bar2 :: SourceSpan -> [Value EvalAnn] -> m (Value EvalAnn))

bar1 :: Monad m => Ret m Int
bar1 = Ret (pure 1)

bar2 :: Monad m => Int -> Ret m Int
bar2 n = Ret (pure (succ n))

bar22 :: MonadError EvalError m => ForeignFunction m 1
bar22 = Ind $ \n -> Base (pure (n + 1 :: Int))

bar3 :: Monad m => Int -> Int -> Ret m Int
bar3 x y = pure (x + y)

data SomeForeignFunction m where
  SomeForeignFunction :: KnownNat arity => ForeignFunction m arity -> SomeForeignFunction m

foreignFunction :: (KnownNat arity, ToForeignFunction m arity f) => f -> SomeForeignFunction m
foreignFunction (f :: f) = SomeForeignFunction (toForeignFunction f)
