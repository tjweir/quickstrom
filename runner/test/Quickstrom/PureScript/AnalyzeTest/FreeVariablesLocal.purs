module Spec where

import Quickstrom
import Data.Maybe (Maybe(..))

readyWhen = "body"

actions = []

proposition :: Boolean
proposition =
  let
    sel = "p"
  in
    queryOne sel { display: cssValue "display" } == Just { display: "none" }
