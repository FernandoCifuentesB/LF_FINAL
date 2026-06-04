/*
 * =============================================================================
 *  ARCHIVO: sql.l
 *  DESCRIPCIÓN: Analizador léxico (Flex) para el lenguaje SQL simplificado.
 *               Reconoce los tokens de la instrucción de inserción canónica:
 *                 insertar en tabla <ID> valores: <campo>=<valor>,... fin;
 *  HERRAMIENTA: Win Flex 2.6.4 / GNU Flex 2.6+
 *  COMPILADOR:  GCC 13.2.0 (MinGW-w64 / w64devkit)
 *  SISTEMA:     Windows 10/11 64-bit
 *  AUTOR:       Proyecto Analizador SQL Simplificado
 * =============================================================================
 */

/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 1 – DEFINICIONES
 *   Se incluyen los encabezados necesarios y se declaran macros (definiciones
 *   de nombre) que simplifican las expresiones regulares de la sección de reglas.
 * ───────────────────────────────────────────────────────────────────────────── */
%{
/*
 * sql.tab.h  → generado automáticamente por Bison; contiene las constantes
 *              numéricas de los tokens (TK_INSERTAR, TK_ID, etc.) y la
 *              declaración del tipo semántico YYSTYPE (unión yylval).
 * string.h   → strdup(), strncpy()
 * stdlib.h   → atoi()
 * stdio.h    → fprintf(), printf()
 */
#include "sql.tab.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

/*
 * num_linea   → contador de líneas que se incrementa en la regla de saltos de
 *               línea; permite reportar la posición exacta de un error léxico.
 * num_col     → contador de columna; se reinicia en cada salto de línea.
 */
int num_linea = 1;
int num_col   = 1;

/* Macro auxiliar para actualizar la columna tras consumir yytext. */
#define AVANZAR_COL  (num_col += (int)yyleng)
%}

/*
 * ── OPCIONES FLEX ─────────────────────────────────────────────────────────
 *   noyywrap  → no se requiere la función yywrap(); Flex no intentará abrir
 *               un segundo archivo de entrada al llegar al EOF.
 *   yylineno  → activa el contador automático de líneas de Flex (opcional;
 *               aquí también se lleva manualmente para la columna).
 */
%option noyywrap
%option yylineno

/* ── MACROS DE PATRONES ───────────────────────────────────────────────────
 *   Cada macro define un fragmento de expresión regular con nombre,
 *   lo que aumenta la legibilidad y facilita el mantenimiento.
 *
 *   DIGITO  → cualquier dígito decimal [0-9]
 *   LETRA   → cualquier letra ASCII (mayúscula o minúscula) o guion bajo
 *   IDENT   → identificador: empieza con LETRA, continúa con LETRA o DIGITO
 *             (no puede iniciar con dígito para evitar ambigüedad con TK_ENTERO)
 */
DIGITO      [0-9]
LETRA       [a-zA-Z_]
IDENT       {LETRA}({LETRA}|{DIGITO})*

/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 2 – REGLAS
 *   Formato:   <patrón>   { <acción en C> }
 *   Prioridad: Flex aplica la regla cuyo patrón coincide con la subcadena más
 *              larga; en caso de empate de longitud, gana la regla que aparece
 *              primero en el archivo.
 *   IMPORTANTE: Las palabras clave DEBEN preceder a la regla de IDENT, porque
 *               "insertar", "tabla", etc. también satisfacen {IDENT}; al estar
 *               primero, la regla más específica tiene prioridad.
 * ───────────────────────────────────────────────────────────────────────────── */
%%

    /* ── PALABRAS CLAVE ──────────────────────────────────────────────────
     *   Se comparan literalmente contra la cadena de entrada.
     *   Solo se devuelve el token; no se almacena valor semántico porque
     *   su semántica está completamente determinada por el tipo de token.
     */

"insertar"  {
                /* TK_INSERTAR → palabra clave que inicia la sentencia */
                AVANZAR_COL;
                return TK_INSERTAR;
            }

"en"        {
                /* TK_EN → preposición obligatoria que precede a "tabla" */
                AVANZAR_COL;
                return TK_EN;
            }

"tabla"     {
                /* TK_TABLA → marca que el siguiente token es un nombre de tabla */
                AVANZAR_COL;
                return TK_TABLA;
            }

"valores"   {
                /* TK_VALORES → indica el inicio del bloque de asignaciones */
                AVANZAR_COL;
                return TK_VALORES;
            }

"fin"       {
                /* TK_FIN → cierra la sentencia (equivalente a END en SQL clásico) */
                AVANZAR_COL;
                return TK_FIN;
            }

    /* ── LITERALES BOOLEANOS ─────────────────────────────────────────────
     *   Se capturan ANTES que IDENT porque "true"/"false" satisfacen
     *   {IDENT}; sin esta precedencia serían clasificados como identificadores.
     *   Se almacena una copia de la cadena en yylval.sval para que Bison pueda
     *   incorporarla directamente en la instrucción SQL de inserción.
     */
"true"|"false" {
                AVANZAR_COL;
                yylval.sval = strdup(yytext);   /* copia dinámica de "true"/"false" */
                return TK_BOOL;
            }

    /* ── IDENTIFICADORES ─────────────────────────────────────────────────
     *   Nombres de tabla y de campo.  Se almacena la cadena en yylval.sval
     *   para que el parser pueda recuperar el nombre exacto.
     *   strdup() reserva memoria en el heap; el parser es responsable de
     *   liberar esa memoria (o acumularla en buffers estáticos).
     */
{IDENT}     {
                AVANZAR_COL;
                yylval.sval = strdup(yytext);
                return TK_ID;
            }

    /* ── LITERAL DE CADENA ───────────────────────────────────────────────
     *   Sintaxis: comilla simple, cero o más caracteres que NO sean comilla
     *   simple ni salto de línea, comilla simple de cierre.
     *   El patrón '[^'\n]*'  captura las comillas delimitadoras junto con el
     *   contenido; el parser almacenará el token completo (con comillas) en la
     *   instrucción SQL de inserción para respetar la sintaxis SQLite.
     *   Si el programador no cierra la cadena antes del fin de línea,
     *   la regla de error léxico (.  catch-all) capturará la comilla suelta.
     */
'[^'\n]*'   {
                AVANZAR_COL;
                yylval.sval = strdup(yytext);   /* ej: "'Juan'" (con comillas) */
                return TK_CADENA;
            }

    /* ── LITERAL ENTERO ──────────────────────────────────────────────────
     *   Uno o más dígitos decimales; se convierte a int con atoi() y se
     *   almacena en yylval.ival.
     */
{DIGITO}+   {
                AVANZAR_COL;
                yylval.ival = atoi(yytext);
                return TK_ENTERO;
            }

    /* ── SÍMBOLOS DE PUNTUACIÓN ──────────────────────────────────────────
     *   Cada símbolo devuelve su token correspondiente.
     *   No se almacena valor semántico; su aparición es estructural.
     */
"="         { AVANZAR_COL; return TK_IGUAL;     }  /* asignación campo-valor  */
","         { AVANZAR_COL; return TK_COMA;      }  /* separador de pares      */
":"         { AVANZAR_COL; return TK_DOSPUNTOS; }  /* delimitador tras valores */
";"         { AVANZAR_COL; return TK_PTOCOMA;   }  /* terminador de sentencia  */

    /* ── ESPACIOS EN BLANCO ──────────────────────────────────────────────
     *   Espacios, tabulaciones y retornos de carro se ignoran.
     *   El salto de línea \n se trata aparte para mantener num_linea y
     *   reiniciar num_col.
     */
[ \t\r]+    {
                AVANZAR_COL;
                /* sin acción: se descarta el token de espacio */
            }

\n          {
                /* salto de línea: avanzar contador de línea y reiniciar columna */
                num_linea++;
                num_col = 1;
            }

    /* ── COMENTARIOS DE LÍNEA (extensión) ───────────────────────────────
     *   Permite que el archivo de entrada incluya comentarios estilo C++.
     *   El patrón .* consume todo hasta el fin de línea (sin incluir \n).
     */
"--"[^\n]*  {
                /* línea de comentario SQL: se descarta completamente */
                AVANZAR_COL;
            }

    /* ── CATCH-ALL: CARÁCTER NO RECONOCIDO ──────────────────────────────
     *   El punto (.) en Flex coincide con cualquier carácter excepto \n.
     *   Si ninguna regla anterior coincide, se emite un mensaje de error
     *   léxico con la posición exacta (línea y columna) y se continúa el
     *   análisis para reportar más errores en la misma pasada.
     */
.           {
                fprintf(stderr,
                    "[ERROR LÉXICO] Línea %d, col %d: carácter no reconocido '%s'\n",
                    num_linea, num_col, yytext);
                AVANZAR_COL;
                /* NO se retorna token; Flex continúa con el siguiente carácter */
            }

%%
/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 3 – CÓDIGO AUXILIAR
 *   Código C que se copia literalmente al final del archivo generado por Flex.
 *   Aquí no se necesita ninguna función adicional porque:
 *   - yywrap() está desactivado con %option noyywrap.
 *   - main() está definido en sql.y (Bison).
 * ───────────────────────────────────────────────────────────────────────────── */
/* (sección vacía intencionalmente; toda la lógica vive en sql.y) */
