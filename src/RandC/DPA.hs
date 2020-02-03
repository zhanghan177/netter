module RandC.DPA where

import RandC.Var
import RandC.Dice.Expr

import qualified Data.Map as M

data Program = Program { pVarDecls :: M.Map Var (Int, Int)
                       , pDice :: M.Map Die [Double]
                       , pAssns :: M.Map Var Expr }
  deriving (Show, Eq)
