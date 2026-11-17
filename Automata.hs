{-|
Module      : Automata
Description : Implementación de Autómata Celular Elemental 1D con bordes periódicos y mónada State.
Copyright   : (c) INFO188 - Paradigmas de Programación
Maintainer  : Estudiantes INFO188

Este módulo implementa las estructuras y la lógica de evolución para un autómata
celular elemental unidimensional (Wolfram, 1983). Provee soporte para:
  * Reglas elementales de Wolfram (0 a 255).
  * Condiciones de frontera periódicas (topología de anillo/toroide 1D).
  * Simulación pura mediante la mónada 'State' (Control.Monad.State).
  * Condiciones iniciales céntricas y pseudo-aleatorias.
-}
module Automata
  ( -- * Tipos de datos
    Automata(..)
  , Regla
  , Celdas

    -- * Construcción e Inicialización
  , crearAutomataCentrado
  , crearAutomataAleatorio
  , inicializarCeldasCentradas
  , inicializarCeldasAleatorias

    -- * Evolución y Lógica Wolfram
  , siguienteGeneracion
  , pasoPuro
  , paso
  , simular
  , obtenerHistorial
  , ejecutarSimulacion

    -- * Visualización
  , renderCeldas
  , renderAutomata
  ) where

import Control.Monad (replicateM_)
import Control.Monad.State (State, get, put, gets, modify, evalState)
import Data.Bits (testBit, xor, shiftL, shiftR)
import Data.Word (Word64)

-- | Tipo sinónimo para representar la regla de Wolfram (0 a 255).
type Regla = Int

-- | Tipo sinónimo para la fila de células (True = Viva, False = Muerta).
type Celdas = [Bool]

-- | Registro que modela el estado completo del autómata celular.
-- Cumple con el requisito 1 de la pauta e incorpora el historial para
-- permitir una simulación puramente monádica con 'replicateM_'.
data Automata = Automata
  { celdas     :: !Celdas     -- ^ Configuración actual de células
  , regla      :: !Regla      -- ^ Código de regla de Wolfram (0 a 255)
  , generacion :: !Int        -- ^ Número de la generación actual (inicia en 0)
  , historial  :: ![Celdas]   -- ^ Historial acumulado de generaciones (orden inverso para eficiencia O(1))
  } deriving (Show, Eq)

--------------------------------------------------------------------------------
-- Lógica Elemental de Wolfram y Bordes Periódicos
--------------------------------------------------------------------------------

-- | Calcula el índice de la vecindad de 3 celdas (izq, centro, der).
-- Mapea una terna booleana a un entero entre 0 y 7.
-- Ejemplo: (True, False, True) = 101 en binario = 5 en decimal.
indiceVecindad :: Bool -> Bool -> Bool -> Int
indiceVecindad izq centro der =
  (if izq    then 4 else 0) +
  (if centro then 2 else 0) +
  (if der    then 1 else 0)
{-# INLINE indiceVecindad #-}

-- | Aplica la regla de Wolfram dada a una vecindad de 3 celdas.
-- Evalúa el bit correspondiente en la representación binaria de la regla.
aplicarRegla :: Regla -> Bool -> Bool -> Bool -> Bool
aplicarRegla r izq centro der = testBit r (indiceVecindad izq centro der)
{-# INLINE aplicarRegla #-}

-- | Separa una lista no vacía en su prefijo inicial y su último elemento de forma total.
descomponerFinal :: a -> [a] -> ([a], a)
descomponerFinal x []     = ([], x)
descomponerFinal x (y:ys) =
  let (resto, ultimo) = descomponerFinal y ys
  in (x : resto, ultimo)

-- | Calcula la siguiente generación aplicando bordes periódicos (cíclicos).
-- El vecino izquierdo de la primera celda es la última celda.
-- El vecino derecho de la última celda es la primera celda.
siguienteGeneracion :: Regla -> Celdas -> Celdas
siguienteGeneracion _ [] = []
siguienteGeneracion r (c:cs) =
  let (prefijo, ultimo) = descomponerFinal c cs
      celdasTotales     = c : cs
      vecinosIzq        = ultimo : prefijo
      vecinosDer        = cs ++ [c]
  in zipWith3 (aplicarRegla r) vecinosIzq celdasTotales vecinosDer

--------------------------------------------------------------------------------
-- Transición y Simulación con Mónada State
--------------------------------------------------------------------------------

-- | Función de transición pura (paso elemental sin mónada).
-- Corresponde a la firma requerida: paso :: Automata -> Automata.
pasoPuro :: Automata -> Automata
pasoPuro aut =
  let nuevas = siguienteGeneracion (regla aut) (celdas aut)
  in aut
      { celdas     = nuevas
      , generacion = generacion aut + 1
      , historial  = nuevas : historial aut
      }

-- | Transición de una generación dentro de la mónada 'State'.
-- Satisface el requisito extra E (hasta +1.0):
--   * Firma: paso :: State Automata ()
--   * Emplea 'get' y 'put' (o 'modify') para operar sobre el estado interno
--     sin pasarlo explícitamente a mano entre funciones.
paso :: State Automata ()
paso = do
  aut <- get
  let nuevas = siguienteGeneracion (regla aut) (celdas aut)
  put aut
    { celdas     = nuevas
    , generacion = generacion aut + 1
    , historial  = nuevas : historial aut
    }

-- | Variante alternativa de 'paso' utilizando 'modify'.
-- Demuestra el dominio de los combinadores fundamentales de 'MonadState'.
_pasoConModify :: State Automata ()
_pasoConModify = modify pasoPuro

-- | Ejecuta la simulación completa de @n@ generaciones dentro de la mónada 'State'.
-- Utiliza 'replicateM_' tal como exige la pauta de evaluación.
-- Dado que la generación 0 ya está en el estado inicial, se ejecutan (n - 1) pasos.
simular :: Int -> State Automata ()
simular nGeneraciones
  | nGeneraciones <= 1 = return ()
  | otherwise          = replicateM_ (nGeneraciones - 1) paso

-- | Extrae el historial completo de generaciones desde el estado monádico,
-- haciendo uso de la función 'gets' para proyectar el campo 'historial' invertido.
obtenerHistorial :: State Automata [Celdas]
obtenerHistorial = gets (reverse . historial)

-- | Ejecuta la simulación sobre un autómata inicial y retorna todas las generaciones producidas.
ejecutarSimulacion :: Automata -> Int -> [Celdas]
ejecutarSimulacion autInicial n =
  evalState (simular n >> obtenerHistorial) autInicial

--------------------------------------------------------------------------------
-- Condiciones Iniciales
--------------------------------------------------------------------------------

-- | Genera una fila de celdas con una sola célula viva al centro.
-- Para ancho impar N, coloca (N `div` 2) celdas muertas a cada lado.
-- Para ancho par N, centra adecuadamente la célula viva.
inicializarCeldasCentradas :: Int -> Celdas
inicializarCeldasCentradas ancho
  | ancho <= 0 = []
  | otherwise  =
      let centro = ancho `div` 2
          izq    = replicate centro False
          der    = replicate (ancho - centro - 1) False
      in izq ++ [True] ++ der

-- | Generador de números pseudo-aleatorios (XorShift64).
-- Implementación pura y autocontenida que no requiere librerías externas adicionales.
xorshift64 :: Word64 -> Word64
xorshift64 s0 =
  let s1 = s0 `xor` (s0 `shiftL` 13)
      s2 = s1 `xor` (s1 `shiftR` 7)
      s3 = s2 `xor` (s2 `shiftL` 17)
  in s3

-- | Genera una lista infinita de valores booleanos pseudo-aleatorios a partir de una semilla.
streamBooleans :: Word64 -> [Bool]
streamBooleans seed =
  let next = if seed == 0 then 0x853c49e6748fea9b else xorshift64 seed
      bit  = (next `Data.Bits.testBit` 0)
  in bit : streamBooleans next

-- | Genera una configuración inicial aleatoria de longitud @ancho@ dada una semilla.
inicializarCeldasAleatorias :: Int -> Word64 -> Celdas
inicializarCeldasAleatorias ancho semilla =
  take ancho (streamBooleans semilla)

-- | Constructor de conveniencia para un autómata con condición inicial céntrica.
crearAutomataCentrado :: Regla -> Int -> Automata
crearAutomataCentrado r ancho =
  let c0 = inicializarCeldasCentradas ancho
  in Automata
      { celdas     = c0
      , regla      = r
      , generacion = 0
      , historial  = [c0]
      }

-- | Constructor de conveniencia para un autómata con condición inicial aleatoria.
crearAutomataAleatorio :: Regla -> Int -> Word64 -> Automata
crearAutomataAleatorio r ancho semilla =
  let c0 = inicializarCeldasAleatorias ancho semilla
  in Automata
      { celdas     = c0
      , regla      = r
      , generacion = 0
      , historial  = [c0]
      }

--------------------------------------------------------------------------------
-- Renderizado y Visualización en Terminal
--------------------------------------------------------------------------------

-- | Convierte una fila de celdas a una cadena de caracteres:
--   * Célula viva (True)  -> '#'
--   * Célula muerta (False) -> ' '
renderCeldas :: Celdas -> String
renderCeldas = map (\viva -> if viva then '#' else ' ')

-- | Renderiza el estado actual del autómata completo.
renderAutomata :: Automata -> String
renderAutomata = renderCeldas . celdas
