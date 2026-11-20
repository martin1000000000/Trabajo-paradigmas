module Main where

import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.Word (Word64)
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)
import Automata

obtenerSemilla :: IO Word64
obtenerSemilla = do
  t <- getPOSIXTime
  return . fromIntegral $ (round (t * 1000000) :: Integer)

parsear :: [String] -> Either String (Regla, Int, Int, Maybe String)
parsear [rS, wS, gS]       = parsear3 rS wS gS Nothing
parsear [rS, wS, gS, modo] = parsear3 rS wS gS (Just modo)
parsear _                  = Left "Uso: <regla 0-255> <ancho> <generaciones> [random | semilla]"

parsear3 :: String -> String -> String -> Maybe String -> Either String (Regla, Int, Int, Maybe String)
parsear3 rS wS gS modo = do
  r <- maybe (Left "Regla invalida.") Right (readMaybe rS)
  w <- maybe (Left "Ancho invalido.") Right (readMaybe wS)
  g <- maybe (Left "Generaciones invalidas.") Right (readMaybe gS)
  if r < 0 || r > 255 then Left "La regla debe estar entre 0 y 255."
    else if w <= 0 || g <= 0 then Left "Ancho y generaciones deben ser > 0."
    else Right (r, w, g, modo)

main :: IO ()
main = do
  args <- getArgs
  prog <- getProgName
  case parsear args of
    Left err -> hPutStrLn stderr ("Error (" ++ prog ++ "): " ++ err) >> exitFailure
    Right (r, w, g, Nothing) ->
      mapM_ (putStrLn . renderCeldas) (ejecutarSimulacion (crearAutomataCentrado r w) g)
    Right (r, w, g, Just modo) -> do
      semilla <- case modo of
        "random"   -> obtenerSemilla
        "-r"       -> obtenerSemilla
        "--random" -> obtenerSemilla
        s          -> maybe obtenerSemilla (return . fromInteger) (readMaybe s)
      mapM_ (putStrLn . renderCeldas) (ejecutarSimulacion (crearAutomataAleatorio r w semilla) g)
