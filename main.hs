{-|
Module      : Main
Description : Punto de entrada y procesamiento de CLI para el Autómata Celular 1D.
Copyright   : (c) INFO188 - Paradigmas de Programación
Maintainer  : Estudiantes INFO188
-}
module Main where

import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.Word (Word64)
import Text.Read (readMaybe)

import Automata
  ( Automata
  , Regla
  , crearAutomataCentrado
  , crearAutomataAleatorio
  , ejecutarSimulacion
  , renderCeldas
  )

-- | Imprime el mensaje de ayuda y uso del programa.
mostrarAyuda :: String -> IO ()
mostrarAyuda progName = do
  putStrLn $ "Uso: ./" ++ progName ++ " <regla> <ancho> <generaciones> [modo_inicial]"
  putStrLn ""
  putStrLn "Parámetros obligatorios:"
  putStrLn "  <regla>         Número de regla de Wolfram (entero entre 0 y 255)"
  putStrLn "  <ancho>         Ancho de la rejilla de células (entero positivo)"
  putStrLn "  <generaciones>  Número de generaciones a proyectar (entero positivo)"
  putStrLn ""
  putStrLn "Condición inicial (opcional):"
  putStrLn "  (omitido)       Célula viva única centrada (modo estándar pauta)"
  putStrLn "  random | -r     Generación aleatoria usando reloj del sistema (Puntos extras A)"
  putStrLn "  <semilla>       Generación aleatoria reproducible con semilla entera fija"
  putStrLn ""
  putStrLn "Ejemplos:"
  putStrLn $ "  ./" ++ progName ++ " 90 31 8"
  putStrLn $ "  ./" ++ progName ++ " 30 50 25 random"
  putStrLn $ "  ./" ++ progName ++ " 110 40 20 42"

-- | Obtiene una semilla pseudo-aleatoria a partir de los microsegundos del reloj POSIX.
obtenerSemillaTiempo :: IO Word64
obtenerSemillaTiempo = do
  t <- getPOSIXTime
  let micros = round (t * 1000000) :: Integer
  return (fromIntegral micros)

-- | Valida y procesa los argumentos de línea de comandos.
main :: IO ()
main = do
  args <- getArgs
  progName <- getProgName

  case args of
    ["--help"] -> mostrarAyuda progName >> exitSuccess
    ["-h"]     -> mostrarAyuda progName >> exitSuccess

    [rStr, wStr, gStr] -> do
      case parsearParametros rStr wStr gStr of
        Left err -> reportarError progName err
        Right (r, w, g) -> do
          let aut = crearAutomataCentrado r w
          ejecutarYMostrar aut g

    [rStr, wStr, gStr, modoStr] -> do
      case parsearParametros rStr wStr gStr of
        Left err -> reportarError progName err
        Right (r, w, g) -> do
          semilla <- case modoStr of
            "random"   -> obtenerSemillaTiempo
            "-r"       -> obtenerSemillaTiempo
            "--random" -> obtenerSemillaTiempo
            otra -> case readMaybe otra of
              Just s  -> return (fromIntegral (s :: Integer))
              Nothing -> do
                hPutStrLn stderr $ "Aviso: argumento '" ++ otra ++ "' no reconocido como semilla; usando reloj."
                obtenerSemillaTiempo
          let aut = crearAutomataAleatorio r w semilla
          ejecutarYMostrar aut g

    _ -> do
      hPutStrLn stderr "Error: Número incorrecto de argumentos."
      mostrarAyuda progName
      exitFailure

-- | Parsea y valida los tres parámetros fundamentales (regla, ancho, generaciones).
parsearParametros :: String -> String -> String -> Either String (Regla, Int, Int)
parsearParametros rStr wStr gStr = do
  r <- maybe (Left "La regla debe ser un número entero.") Right (readMaybe rStr)
  w <- maybe (Left "El ancho debe ser un número entero.") Right (readMaybe wStr)
  g <- maybe (Left "Las generaciones deben ser un número entero.") Right (readMaybe gStr)

  if r < 0 || r > 255
    then Left "La regla de Wolfram debe estar comprendida en el rango [0, 255]."
    else if w <= 0
      then Left "El ancho de la rejilla debe ser estrictamente mayor que cero."
      else if g <= 0
        then Left "El número de generaciones debe ser estrictamente mayor que cero."
        else Right (r, w, g)

-- | Emite un mensaje de error a stderr y finaliza con código de salida 1.
reportarError :: String -> String -> IO ()
reportarError progName msg = do
  hPutStrLn stderr $ "Error: " ++ msg
  hPutStrLn stderr $ "Ejecute './" ++ progName ++ " --help' para ver la guía de uso."
  exitFailure

-- | Ejecuta la simulación usando la mónada State y vuelca las filas a la terminal.
ejecutarYMostrar :: Automata -> Int -> IO ()
ejecutarYMostrar aut g = do
  let filas = ejecutarSimulacion aut g
  mapM_ (putStrLn . renderCeldas) filas
