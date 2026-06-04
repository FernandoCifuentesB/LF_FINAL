@echo off
REM ============================================================
REM  compilar.bat — Script de compilación para Windows
REM  Usar este script si no tienes 'make' instalado.
REM
REM  REQUISITOS antes de ejecutar:
REM    1. win_flex y win_bison en el PATH
REM    2. gcc (w64devkit) en el PATH
REM
REM  MODO DE USO:
REM    Abrir CMD en la carpeta src\ y ejecutar:
REM      compilar.bat
REM ============================================================

echo === Paso 1: Generando parser con Bison ===
win_bison -d -v acceso.y
IF ERRORLEVEL 1 (
    echo ERROR en Bison. Revisa acceso.y
    pause
    exit /b 1
)

echo === Paso 2: Generando lexer con Flex ===
win_flex --wincompat -o acceso.lex.c acceso.l
IF ERRORLEVEL 1 (
    echo ERROR en Flex. Revisa acceso.l
    pause
    exit /b 1
)

echo === Paso 3: Compilando con GCC ===
gcc -Wall -g -o acceso.exe acceso.tab.c acceso.lex.c
IF ERRORLEVEL 1 (
    echo ERROR en GCC.
    pause
    exit /b 1
)

echo.
echo === Compilacion exitosa: acceso.exe generado ===
echo.
echo === Ejecutando pruebas ===
acceso.exe ..\tests\archivo_pruebas.txt

pause
