# ============================================================
#  Makefile — Proyecto 3.1: Analizador de Reglas de Acceso
#  Compatible con Windows usando win_flex, win_bison y gcc
#
#  Comandos disponibles:
#    make all      → compilar todo el proyecto
#    make test     → ejecutar con el archivo de pruebas
#    make clean    → eliminar archivos generados
# ============================================================

# Nombre del ejecutable final
TARGET = acceso.exe

# Herramientas (ajustar si están en otro PATH)
FLEX   = win_flex
BISON  = win_bison
CC     = gcc

# Flags de compilación:
#   -Wall  → todos los warnings
#   -g     → información de debug
CFLAGS = -Wall -g

# ── Regla principal ──────────────────────────────────────────
all: $(TARGET)

# Paso 1: Bison genera acceso.tab.c y acceso.tab.h
#   -d  → generar el archivo .h con los #define de tokens
#   -v  → generar acceso.output con tablas de parsing (debug)
acceso.tab.c acceso.tab.h: acceso.y
	$(BISON) -d -v acceso.y

# Paso 2: Flex genera lex.yy.c
#   --wincompat → compatibilidad con Windows
acceso.lex.c: acceso.l acceso.tab.h
	$(FLEX) --wincompat -o acceso.lex.c acceso.l

# Paso 3: GCC compila todo junto en el ejecutable
#   Se incluye acceso.tab.h implícitamente via #include
$(TARGET): acceso.tab.c acceso.lex.c
	$(CC) $(CFLAGS) -o $(TARGET) acceso.tab.c acceso.lex.c

# ── Prueba rápida ────────────────────────────────────────────
test: $(TARGET)
	./$(TARGET) ../tests/archivo_pruebas.txt

# ── Limpieza ─────────────────────────────────────────────────
clean:
	del /Q $(TARGET) acceso.tab.c acceso.tab.h acceso.lex.c acceso.output 2>nul || true
