# =============================================================================
#  Makefile — Analizador SQL Simplificado (Flex + Bison + SQLite)
#  Compatible con: Windows (win_flex / win_bison + MinGW-w64)
#                  Linux   (flex / bison + GCC)
# =============================================================================
#
# INSTRUCCIONES DE USO:
#
#   Windows (w64devkit / MinGW-w64):
#     make                  → compilar todo
#     make run              → compilar y ejecutar con entrada de prueba
#     make clean            → eliminar archivos generados
#
#   Linux / macOS:
#     make FLEX=flex BISON=bison
#
# DEPENDENCIAS:
#   - win_flex  (o flex en Linux)
#   - win_bison (o bison en Linux)
#   - GCC
#   - sqlite3.c + sqlite3.h  (amalgamación; descargar de https://sqlite.org/download.html)
#
# =============================================================================

# ── Herramientas ──────────────────────────────────────────────────────────────
# Cambiar a 'flex' y 'bison' en Linux/macOS
FLEX    = win_flex
BISON   = win_bison
CC      = gcc

# ── Flags de compilación ──────────────────────────────────────────────────────
# -std=c99      → estándar C99 (requerido por sqlite3 amalgamado)
# -Wall         → activar todos los warnings del compilador
# -Wno-unused-function → suprimir warning de yywrap en algunos entornos
# -lm           → enlazar con la biblioteca matemática (requerida por SQLite)
CFLAGS  = -std=c99 -Wall -Wno-unused-function
LDFLAGS = -lm

# ── Archivos fuente y objetivo ────────────────────────────────────────────────
TARGET  = sql
LEX_SRC = sql.l
PAR_SRC = sql.y
# Archivos generados por Flex y Bison:
LEX_GEN = lex.yy.c
PAR_GEN = sql.tab.c
PAR_HDR = sql.tab.h
# Amalgamación SQLite:
SQLITE  = sqlite3.c

# =============================================================================
# REGLA PRINCIPAL
# =============================================================================
all: $(TARGET)

# ── Paso 1: generar el parser con Bison ──────────────────────────────────────
# Opciones de Bison:
#   -d  → generar sql.tab.h con las constantes de tokens (necesario para Flex)
#   -v  → generar sql.output con el informe del autómata LALR(1) (opcional, útil
#         para depurar conflictos shift/reduce)
$(PAR_GEN) $(PAR_HDR): $(PAR_SRC)
	$(BISON) -d -v $(PAR_SRC)

# ── Paso 2: generar el lexer con Flex ────────────────────────────────────────
# Opciones de Flex:
#   (ninguna extra; las directivas %option están dentro de sql.l)
# NOTA: sql.tab.h debe generarse ANTES que lex.yy.c porque sql.l lo incluye.
$(LEX_GEN): $(LEX_SRC) $(PAR_HDR)
	$(FLEX) $(LEX_SRC)

# ── Paso 3: compilar y enlazar todo ──────────────────────────────────────────
# Se compilan los tres archivos C en un solo paso (simple y sin archivos .o):
#   lex.yy.c     → analizador léxico generado por Flex
#   sql.tab.c    → analizador sintáctico generado por Bison
#   sqlite3.c    → motor de base de datos SQLite (amalgamación de un solo archivo)
$(TARGET): $(LEX_GEN) $(PAR_GEN) $(SQLITE)
	$(CC) $(CFLAGS) -o $(TARGET) $(LEX_GEN) $(PAR_GEN) $(SQLITE) $(LDFLAGS)
	@echo "==> Compilación exitosa: ./$(TARGET)"

# =============================================================================
# REGLA DE PRUEBA
#   Crea un archivo de consultas de ejemplo y lo procesa con el analizador.
# =============================================================================
run: $(TARGET)
	@echo "==> Ejecutando pruebas de inserción..."
	@echo "insertar en tabla empleados valores: nombre = 'Ana', cargo = 'dev', salario = 3000 fin;"      >  prueba.txt
	@echo "insertar en tabla productos valores: nombre = 'Laptop', precio = 1500, activo = true fin;"    >> prueba.txt
	@echo "insertar en tabla pedidos valores: cliente = 'Luis', producto = 'Mouse', cantidad = 5 fin;"  >> prueba.txt
	@echo "-- caso de error sintáctico:"                                                                  >> prueba.txt
	@echo "insertar en tabla empleados valores nombre = 'Error' fin;"                                    >> prueba.txt
	./$(TARGET) < prueba.txt

# =============================================================================
# LIMPIEZA
# =============================================================================
clean:
	del /Q $(LEX_GEN) $(PAR_GEN) $(PAR_HDR) sql.output $(TARGET).exe prueba.txt bd_sql.db 2>NUL || \
	rm -f  $(LEX_GEN) $(PAR_GEN) $(PAR_HDR) sql.output $(TARGET)    prueba.txt bd_sql.db
	@echo "==> Archivos generados eliminados."

.PHONY: all run clean
