# ==============================================================================
# Makefile para INFO188 - Tarea 1: Autómata Celular 1D (Haskell)
# ==============================================================================

GHC       = ghc
GHCFLAGS  = -O2 -Wall
TARGET    = prog
SOURCES   = Automata.hs main.hs

.PHONY: all clean run test help

# Regla por defecto: compilar el ejecutable 'prog'
all: $(TARGET)

$(TARGET): $(SOURCES)
	$(GHC) $(GHCFLAGS) main.hs -o $(TARGET)

# Ejecuta una batería de pruebas con casos notables
test: $(TARGET)
	@echo "=== Prueba 1: Ejemplo oficial (Regla 90, ancho 31, 8 generaciones) ==="
	./$(TARGET) 90 31 8
	@echo "\n=== Prueba 2: Regla 30 (Caos) ==="
	./$(TARGET) 30 31 8
	@echo "\n=== Prueba 3: Regla 110 (Turing-Completa) ==="
	./$(TARGET) 110 31 8
	@echo "\n=== Prueba 4: Condición inicial aleatoria (Bonus A) ==="
	./$(TARGET) 90 31 8 random

# Limpieza de binarios y archivos temporales generados por GHC
clean:
	rm -f $(TARGET) *.o *.hi *.exe

help:
	@echo "Opciones disponibles en el Makefile:"
	@echo "  make        - Compila el proyecto generando el ejecutable 'prog'"
	@echo "  make run    - Ejecuta el caso de ejemplo oficial (./prog 90 31 8)"
	@echo "  make test   - Ejecuta casos de prueba de verificación"
	@echo "  make clean  - Elimina binarios y archivos intermedios de compilación (.o, .hi)"
