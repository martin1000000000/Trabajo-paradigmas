module Automata
  ( Automata(..), Regla, Celdas
  , crearAutomataCentrado, crearAutomataAleatorio
  , pasoPuro, paso, simular, ejecutarSimulacion, renderCeldas
  ) where

import Control.Monad (replicateM_)
import Control.Monad.State (State, gets, modify, evalState)
import Data.Bits (testBit, xor, shiftL, shiftR)
import Data.Word (Word64)

type Regla  = Int
type Celdas = [Bool]

data Automata = Automata
  { celdas     :: Celdas
  , regla      :: Regla
  , generacion :: Int
  , historial  :: [Celdas]
  } deriving (Show, Eq)

aplicarRegla :: Regla -> Bool -> Bool -> Bool -> Bool
aplicarRegla r izq centro der =
  testBit r (4 * fromEnum izq + 2 * fromEnum centro + fromEnum der)

siguienteGeneracion :: Regla -> Celdas -> Celdas
siguienteGeneracion _ []        = []
siguienteGeneracion r xs@(c:cs) =
  zipWith3 (aplicarRegla r) (last xs : xs) xs (cs ++ [c])

pasoPuro :: Automata -> Automata
pasoPuro aut =
  let nuevas = siguienteGeneracion (regla aut) (celdas aut)
  in aut { celdas = nuevas, generacion = generacion aut + 1, historial = nuevas : historial aut }

paso :: State Automata ()
paso = modify pasoPuro

simular :: Int -> State Automata ()
simular n = replicateM_ (max 0 (n - 1)) paso

ejecutarSimulacion :: Automata -> Int -> [Celdas]
ejecutarSimulacion aut n = evalState (simular n >> gets (reverse . historial)) aut

nuevoAutomata :: Regla -> Celdas -> Automata
nuevoAutomata r c0 = Automata c0 r 0 [c0]

crearAutomataCentrado :: Regla -> Int -> Automata
crearAutomataCentrado r ancho
  | ancho <= 0 = nuevoAutomata r []
  | otherwise  =
      let c = ancho `div` 2
      in nuevoAutomata r (replicate c False ++ [True] ++ replicate (ancho - c - 1) False)

xorshift64 :: Word64 -> Word64
xorshift64 s0 =
  let s1 = s0 `xor` (s0 `shiftL` 13)
      s2 = s1 `xor` (s1 `shiftR` 7)
  in s2 `xor` (s2 `shiftL` 17)

crearAutomataAleatorio :: Regla -> Int -> Word64 -> Automata
crearAutomataAleatorio r ancho semilla =
  let s0 = if semilla == 0 then 0x853c49e6748fea9b else semilla
      c0 = take (max 0 ancho) . map (`testBit` 0) . drop 1 $ iterate xorshift64 s0
  in nuevoAutomata r c0

renderCeldas :: Celdas -> String
renderCeldas = map (\v -> if v then '#' else ' ')
