/*
 * ============================================================
 *  acceso.l  —  Analizador LÉXICO para reglas de acceso
 *  Herramienta: Flex (win_flex en Windows)
 *  Autor: Proyecto 3.1 — Compiladores
 *
 *  Este archivo define los TOKENS del lenguaje de reglas de
 *  acceso. Flex lee las expresiones regulares y genera un
 *  autómata finito determinista en C que reconoce cada token
 *  y lo pasa al parser generado por Bison.
 *
 *  IMPORTANTE:
 *  Este archivo fue ajustado para soportar comentarios con ';'
 *  en el archivo de pruebas.
 *
 *  Ejemplo de comentario válido:
 *    ; Regla 1 — Restricción horaria
 *
 *  También permite que una regla termine con punto y coma:
 *    user guest AND day = 'Sunday';
 *
 *  En ambos casos, todo lo que aparece desde ';' hasta el final
 *  de la línea se ignora.
 * ============================================================
 */

/* ── SECCIÓN 1: Definiciones C ───────────────────────────── */
%{
/*
 * Este bloque de código C se copia literalmente al inicio del
 * archivo generado por Flex.
 *
 * Aquí se incluyen las librerías necesarias y el archivo
 * acceso.tab.h, que contiene los tokens generados por Bison.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "acceso.tab.h"

/*
 * numero_linea:
 * Variable global usada para reportar errores indicando la línea
 * exacta del archivo de pruebas.
 *
 * Se incrementa cada vez que el lexer reconoce un salto de línea.
 */
int numero_linea = 1;
%}

/*
 * noyywrap:
 * Evita que Flex exija la función yywrap().
 *
 * noinput y nounput:
 * Evitan que Flex genere funciones auxiliares que no se usan,
 * reduciendo advertencias al compilar.
 */
%option noyywrap noinput nounput

/* ── SECCIÓN 2: Macros de patrones reutilizables ─────────── */

/*
 * Dígito decimal.
 */
DIGITO      [0-9]

/*
 * Letra mayúscula o minúscula.
 */
LETRA       [a-zA-Z]

/*
 * Número entero compuesto por uno o más dígitos.
 *
 * Ejemplos:
 *   9
 *   17
 *   2026
 */
NUMERO      {DIGITO}+

/*
 * Identificador genérico.
 *
 * Comienza con una letra y luego permite:
 * - letras
 * - dígitos
 * - guion bajo _
 * - punto .
 * - slash /
 *
 * Se incluye slash para que el lexer pueda reconocer textos tipo:
 * etc/nginx/nginx.conf
 *
 * Normalmente los recursos vienen entre comillas, pero esto ayuda
 * a capturar identificadores no válidos sin romper el programa.
 */
IDENT       {LETRA}({LETRA}|{DIGITO}|[_.\/])*

/*
 * Cadena entre comillas simples.
 *
 * Este patrón permite:
 * - texto normal entre comillas simples
 * - caracteres escapados con backslash
 *
 * Ejemplos válidos:
 *   'Monday'
 *   'config.xml'
 *   'etc/nginx/nginx.conf'
 */
CADENA       '([^'\r\n\\]|\\.)*'
CADENA_ERROR '([^'\r\n\\]|\\.)*

/*
 * Espacios en blanco que no tienen significado sintáctico.
 *
 * Incluye:
 * - espacio
 * - tabulador
 * - retorno de carro
 */
ESPACIO     [ \t\r]+

/*
 * Comentario de línea.
 *
 * Reconoce cualquier punto y coma ';' y todo lo que venga después
 * hasta antes del salto de línea.
 *
 * Esto permite conservar comentarios como:
 *   ; Regla 1 — Restricción horaria
 *
 * También permite cerrar reglas así:
 *   user guest AND day = 'Sunday';
 *
 * En ese caso, el ';' final y lo que venga después se ignora.
 */
COMENTARIO  ";"[^\r\n]*

/* ── SECCIÓN 3: Reglas léxicas ───────────────────────────── */
%%

\xEF\xBB\xBF        { /* Se ignora BOM UTF-8. */ }

{COMENTARIO}        { /* Se ignora comentario o punto y coma final. */ }

"user"              { return TK_USER; }
"admin"             { return TK_ADMIN; }
"guest"             { return TK_GUEST; }
"operator"          { return TK_OPERATOR; }

"AND"               { return TK_AND; }
"OR"                { return TK_OR; }
"NOT"               { return TK_NOT; }

"hour"              { return TK_HOUR; }
"day"               { return TK_DAY; }
"resource"          { return TK_RESOURCE; }

">="                { return TK_GEQ; }
"<="                { return TK_LEQ; }
"!="                { return TK_NEQ; }
">"                 { return TK_GT; }
"<"                 { return TK_LT; }
"="                 { return TK_EQ; }

{NUMERO}            {
                        yylval.ival = atoi(yytext);
                        return TK_NUMERO;
                    }

{CADENA}            {
                        yylval.sval = strdup(yytext);
                        return TK_CADENA;
                    }

{CADENA_ERROR}       {
                        fprintf(stderr,
                            "[ERROR LEXICO] Linea %d: cadena sin cerrar: %s\n",
                            numero_linea,
                            yytext);
                        return TK_ERROR;
                    }

{IDENT}             {
                        yylval.sval = strdup(yytext);
                        return TK_IDENT;
                    }

{ESPACIO}           { /* Se ignoran espacios. */ }

\n                  {
                        numero_linea++;
                        return TK_EOL;
                    }

.               {
                        fprintf(stderr,
                            "[ERROR LEXICO] Linea %d: caracter invalido '%s'\n",
                            numero_linea,
                            yytext);
                        return TK_ERROR;
                    }
%%

/*
 * SECCIÓN FINAL:
 * No se agregan funciones auxiliares porque el flujo principal
 * del programa está en acceso.y.
 */