/*
 * ============================================================
 *  acceso.y  —  Analizador SINTÁCTICO para reglas de acceso
 *  Herramienta: Bison (win_bison en Windows)
 *  Autor: Proyecto 3.1 — Compiladores
 *
 *  Este archivo define la gramática del lenguaje de reglas de
 *  acceso y las acciones semánticas que se ejecutan cuando una
 *  regla es reconocida correctamente.
 * ============================================================
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Contadores globales del análisis.
 */
int reglas_validas   = 0;
int reglas_invalidas = 0;

/*
 * Bandera de control:
 *
 * 0 = la regla actual no tiene errores controlados.
 * 1 = la regla actual tuvo un error sintáctico, léxico o semántico.
 */
int regla_actual_invalida = 0;

/*
 * Elementos externos generados o usados por Flex.
 */
extern int yylex(void);
extern int numero_linea;
extern char *yytext;
extern FILE *yyin;

/*
 * Función auxiliar para contar la regla al cerrar la línea.
 */
static void contabilizar_regla_actual(void) {
    if (regla_actual_invalida) {
        reglas_invalidas++;
        regla_actual_invalida = 0;
    } else {
        reglas_validas++;
        printf("[OK] Regla valida (linea ~%d)\n", numero_linea);
    }
}

/*
 * yyerror:
 * Bison llama esta función cuando encuentra un error sintáctico.
 *
 * No se suma aquí directamente.
 * Solo se marca la regla actual como inválida.
 */
void yyerror(const char *msg) {
    fprintf(stderr,
        "[ERROR SINTACTICO] Linea %d: %s (token: '%s')\n",
        numero_linea, msg, yytext);

    regla_actual_invalida = 1;
}
%}

/* ── Tipos semánticos ────────────────────────────────────── */
%union {
    int   ival;
    char *sval;
}

/* ── Tokens ──────────────────────────────────────────────── */

/* Palabras reservadas */
%token TK_USER
%token TK_ADMIN
%token TK_GUEST
%token TK_OPERATOR

/* Operadores lógicos */
%token TK_AND
%token TK_OR
%token TK_NOT

/* Campos válidos */
%token TK_HOUR
%token TK_DAY
%token TK_RESOURCE

/* Salto de línea */
%token TK_EOL

/* Punto y coma, declarado por compatibilidad */
%token TK_SEMICOLON

/* Operadores de comparación */
%token TK_GEQ
%token TK_LEQ
%token TK_GT
%token TK_LT
%token TK_EQ
%token TK_NEQ

/* Literales */
%token <ival> TK_NUMERO
%token <sval> TK_CADENA
%token <sval> TK_IDENT

/* Error léxico */
%token TK_ERROR

%%

/*
 * programa:
 * Archivo completo de entrada.
 */
programa
    : lineas
    ;

/*
 * lineas:
 * Lista de líneas.
 */
lineas
    : lineas linea
    | /* vacío */
    ;

/*
 * linea:
 * Cada línea puede ser:
 * - regla válida
 * - regla inválida controlada
 * - línea vacía o comentario
 * - línea con error sintáctico
 */
linea
    : regla TK_EOL
        {
            contabilizar_regla_actual();
        }
    | regla
        {
            /*
             * Permite contar la última regla si el archivo no
             * termina con salto de línea.
             */
            contabilizar_regla_actual();
        }
    | TK_EOL
        {
            /*
             * Línea vacía o comentario.
             * No cuenta como válida ni inválida.
             */
            regla_actual_invalida = 0;
        }
    | error TK_EOL
        {
            /*
             * Línea inválida recuperada hasta salto de línea.
             */
            reglas_invalidas++;
            regla_actual_invalida = 0;
            yyerrok;
        }
    ;

/*
 * regla:
 * Toda regla debe iniciar con sujeto y luego tener condiciones.
 */
regla
    : sujeto condicion_lista
    ;

/*
 * sujeto:
 * Usuario base o sujeto alternativo con OR.
 */
sujeto
    : TK_USER rol
    ;

/*
 * rol:
 * Roles válidos.
 */
rol
    : TK_ADMIN
        {
            printf("  Rol: admin\n");
        }
    | TK_GUEST
        {
            printf("  Rol: guest\n");
        }
    | TK_OPERATOR
        {
            printf("  Rol: operator\n");
        }
    ;

/*
 * condicion_lista:
 * Lista de condiciones conectadas con AND u OR.
 */
condicion_lista
    : condicion_lista conector condicion
    | conector condicion
    ;

/*
 * conector:
 * Operador lógico.
 */
conector
    : TK_AND
        {
            printf("  Operador logico: AND\n");
        }
    | TK_OR
        {
            printf("  Operador logico: OR\n");
        }
    ;

/*
 * condicion:
 * Condición simple, negada o sujeto alternativo.
 */
condicion
    : condicion_simple
    | TK_NOT condicion_simple
        {
            printf("  Negacion (NOT) aplicada\n");
        }
    | sujeto
        {
            printf("  Condicion: sujeto alternativo\n");
        }
    ;

/*
 * condicion_simple:
 * Condiciones básicas del lenguaje.
 */
condicion_simple
    : TK_HOUR operador TK_NUMERO
        {
            printf("  Condicion: hour [op] %d\n", $3);
        }

    | TK_HOUR operador TK_CADENA
        {
            /*
             * Error semántico:
             * hour debe compararse con número, no con cadena.
             */
            fprintf(stderr,
                "[ERROR SEMANTICO] Linea %d: hour debe compararse con un numero, no con %s\n",
                numero_linea, $3);

            regla_actual_invalida = 1;
            free($3);
        }

    | TK_HOUR operador TK_IDENT
        {
            /*
             * Error semántico:
             * hour debe compararse con número, no con identificador.
             */
            fprintf(stderr,
                "[ERROR SEMANTICO] Linea %d: hour debe compararse con un numero, no con '%s'\n",
                numero_linea, $3);

            regla_actual_invalida = 1;
            free($3);
        }

    | TK_DAY TK_EQ TK_CADENA
        {
            printf("  Condicion: day = %s\n", $3);
            free($3);
        }

    | TK_RESOURCE TK_EQ TK_CADENA
        {
            printf("  Condicion: resource = %s\n", $3);
            free($3);
        }

    | TK_RESOURCE TK_NEQ TK_CADENA
        {
            printf("  Condicion: resource != %s\n", $3);
            free($3);
        }
    ;

/*
 * operador:
 * Operadores válidos para condiciones de hora.
 */
operador
    : TK_GEQ
        {
            printf("  Operador: >=\n");
        }
    | TK_LEQ
        {
            printf("  Operador: <=\n");
        }
    | TK_GT
        {
            printf("  Operador: >\n");
        }
    | TK_LT
        {
            printf("  Operador: <\n");
        }
    | TK_EQ
        {
            printf("  Operador: =\n");
        }
    ;

%%

/*
 * main:
 * Punto de entrada del programa.
 */
int main(int argc, char *argv[]) {
    FILE *entrada = NULL;

    if (argc > 1) {
        entrada = fopen(argv[1], "r");

        if (!entrada) {
            fprintf(stderr, "Error: no se pudo abrir '%s'\n", argv[1]);
            return 1;
        }

        yyin = entrada;
    }

    printf("=== Analizador de Reglas de Acceso ===\n\n");

    yyparse();

    /*
     * CASO IMPORTANTE:
     * Si el archivo termina con una regla inválida y NO tiene salto
     * de línea final, Bison alcanza EOF sin reducir error TK_EOL.
     *
     * Este bloque cuenta ese último error pendiente.
     *
     * En tu caso, esto arregla la regla 25:
     * user admin AND @recurso = 'test.txt'
     */
    if (regla_actual_invalida) {
        reglas_invalidas++;
        regla_actual_invalida = 0;
    }

    printf("\n=== Resumen del Analisis ===\n");
    printf("Reglas validas  : %d\n", reglas_validas);
    printf("Reglas invalidas: %d\n", reglas_invalidas);
    printf("Total procesadas: %d\n", reglas_validas + reglas_invalidas);

    if (entrada) {
        fclose(entrada);
    }

    return (reglas_invalidas > 0) ? 1 : 0;
}