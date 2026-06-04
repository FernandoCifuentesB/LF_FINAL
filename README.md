# Analizador de Reglas de Acceso con Flex y Bison

## 1. Descripción general del proyecto

Este proyecto implementa un **analizador de reglas de acceso** usando dos herramientas clásicas de construcción de compiladores:

- **Flex**, encargado del análisis léxico.
- **Bison**, encargado del análisis sintáctico y de algunas validaciones semánticas.

El objetivo principal del programa es leer reglas escritas en texto plano y verificar si cumplen con una estructura válida para definir condiciones de acceso sobre usuarios, roles, horarios, días y recursos.

Una regla válida puede tener una forma como la siguiente:

```txt
user admin AND hour >= 9 AND day = 'Friday'
```

En este caso, la regla indica que el usuario con rol `admin` puede cumplir una condición de acceso cuando la hora es mayor o igual a `9` y el día es `Friday`.

El proyecto se encuentra organizado principalmente en la carpeta `src`, donde están los archivos más importantes:

```txt
Reglas_de_Control_de_Acceso_2_1/
├── src/
│   ├── acceso.l
│   ├── acceso.y
│   ├── Makefile
│   ├── compilar.bat
│   ├── acceso.lex.c
│   ├── acceso.tab.c
│   ├── acceso.tab.h
│   └── acceso.exe
└── tests/
    └── archivo_pruebas.txt
```

Los archivos generados como `acceso.lex.c`, `acceso.tab.c` y `acceso.tab.h` se producen automáticamente a partir de los archivos fuente `acceso.l` y `acceso.y`.

---

## 2. ¿Qué problema resuelve?

En entornos donde existen recursos digitales críticos, como archivos de configuración, bases de datos o servicios internos, las reglas de acceso escritas manualmente pueden generar errores si no tienen una estructura clara. Por ejemplo:

```txt
user admin AND hour >= 9
```

es una regla válida, pero una regla como:

```txt
user admin AND hour == 10
```

puede considerarse inválida si el lenguaje no admite el operador `==`.

Por esta razón, el proyecto define un lenguaje formal pequeño, o DSL, para expresar reglas de acceso. Este lenguaje permite identificar:

- Sujetos de acceso, como `user admin`, `user guest` o `user operator`.
- Operadores lógicos, como `AND`, `OR` y `NOT`.
- Condiciones sobre campos como `hour`, `day` y `resource`.
- Operadores de comparación como `>=`, `<=`, `>`, `<`, `=` y `!=`.
- Errores léxicos, sintácticos y semánticos.

---

## 3. Flujo de funcionamiento del analizador

El flujo general del programa es el siguiente:

```txt
Archivo de entrada
        │
        ▼
acceso.l  →  Analizador léxico con Flex
        │
        ▼
Tokens: TK_USER, TK_ADMIN, TK_HOUR, TK_NUMERO, etc.
        │
        ▼
acceso.y  →  Analizador sintáctico con Bison
        │
        ▼
Validación de reglas, acciones semánticas y conteo de resultados
        │
        ▼
Resumen final: reglas válidas, inválidas y total procesado
```

Flex no decide si una regla completa está bien escrita. Su función es separar el texto en unidades reconocibles llamadas **tokens**.

Bison recibe esos tokens y verifica si aparecen en un orden válido según la gramática definida.

---

# Tabla 7: Fragmento del archivo `.l` (Flex) para el analizador de reglas de acceso

## 4. Función del archivo `acceso.l`

El archivo `acceso.l` define el **analizador léxico**. Su responsabilidad es leer el archivo de entrada carácter por carácter y reconocer patrones importantes del lenguaje.

Por ejemplo, cuando Flex encuentra la palabra:

```txt
user
```

la convierte en el token:

```c
TK_USER
```

Cuando encuentra:

```txt
>=
```

la convierte en:

```c
TK_GEQ
```

Cuando encuentra un número como:

```txt
17
```

lo convierte en:

```c
TK_NUMERO
```

y además guarda su valor entero para que Bison pueda usarlo después.

---

## 4.1 Sección de definiciones C en Flex

La primera parte importante del archivo `.l` es la sección de definiciones C.

```c
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "acceso.tab.h"

/*
 * Variable global usada para reportar errores indicando
 * la línea exacta del archivo de pruebas.
 */
int numero_linea = 1;
%}
```

### Explicación

Esta sección aparece encerrada entre `%{` y `%}`. Todo lo que esté dentro de este bloque se copia directamente al archivo C generado por Flex.

Los elementos más importantes son:

| Elemento | Explicación |
|---|---|
| `#include <stdio.h>` | Permite usar funciones de entrada y salida como `printf` y `fprintf`. |
| `#include <stdlib.h>` | Permite usar funciones como `atoi`, útil para convertir texto en números. |
| `#include <string.h>` | Permite manipular cadenas de texto. |
| `#include "acceso.tab.h"` | Conecta Flex con Bison, porque este archivo contiene los tokens generados por Bison. |
| `int numero_linea = 1;` | Controla la línea actual para mostrar errores más claros. |

La inclusión de `acceso.tab.h` es fundamental, porque Flex necesita conocer los nombres de los tokens que retornará al parser de Bison.

---

## 4.2 Opciones de Flex

```c
%option noyywrap noinput nounput
```

### Explicación

Estas opciones controlan el comportamiento del código generado por Flex.

| Opción | Función |
|---|---|
| `noyywrap` | Evita tener que declarar manualmente la función `yywrap()`. |
| `noinput` | Evita generar una función auxiliar que no se usa. |
| `nounput` | Evita generar otra función auxiliar innecesaria. |

Estas opciones ayudan a que la compilación sea más limpia y con menos advertencias.

---

## 4.3 Macros de patrones reutilizables

En Flex, una macro permite dar nombre a una expresión regular para reutilizarla dentro de las reglas léxicas.

```c
DIGITO      [0-9]
LETRA       [a-zA-Z]
NUMERO      {DIGITO}+
IDENT       {LETRA}({LETRA}|{DIGITO}|[_.\/])*
CADENA      '([^'\r\n\\]|\\.)*'
CADENA_ERROR '([^'\r\n\\]|\\.)*
ESPACIO     [ \t\r]+
COMENTARIO  ";"[^\r\n]*
```

### Explicación de cada patrón

| Macro | Qué reconoce | Ejemplo |
|---|---|---|
| `DIGITO` | Un número del 0 al 9. | `5` |
| `LETRA` | Una letra mayúscula o minúscula. | `A`, `z` |
| `NUMERO` | Uno o más dígitos. | `9`, `17`, `2026` |
| `IDENT` | Identificadores que empiezan por letra y pueden contener letras, números, `_`, `.`, `/`. | `superuser`, `etc/nginx` |
| `CADENA` | Texto entre comillas simples. | `'Monday'`, `'config.xml'` |
| `CADENA_ERROR` | Cadena iniciada con comilla simple pero sin cierre. | `'archivo_sin_cerrar` |
| `ESPACIO` | Espacios, tabuladores o retornos de carro. | `   ` |
| `COMENTARIO` | Todo lo que empieza con `;` hasta el fin de línea. | `; comentario` |

Una parte importante es el patrón `COMENTARIO`, porque permite que el archivo de pruebas tenga comentarios descriptivos. También permite que una regla termine con punto y coma:

```txt
user guest AND day = 'Sunday';
```

En ese caso, el punto y coma y el contenido posterior se ignoran.

---

## 4.4 Reglas léxicas y acciones

Después del separador `%%`, Flex define las reglas que indican qué hacer cuando se reconoce cada patrón.

```c
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

{CADENA_ERROR}      {
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

.                   {
                       fprintf(stderr,
                               "[ERROR LEXICO] Linea %d: caracter invalido '%s'\n",
                               numero_linea,
                               yytext);
                       return TK_ERROR;
                    }
%%
```

---

## 4.5 Explicación de las acciones léxicas

### Reconocimiento de palabras reservadas

```c
"user" { return TK_USER; }
"admin" { return TK_ADMIN; }
"guest" { return TK_GUEST; }
"operator" { return TK_OPERATOR; }
```

Estas reglas reconocen las palabras principales del lenguaje. Por ejemplo, si el archivo contiene:

```txt
user admin
```

Flex devuelve primero `TK_USER` y luego `TK_ADMIN`.

Esto permite que Bison interprete la estructura como un sujeto válido.

---

### Reconocimiento de operadores lógicos

```c
"AND" { return TK_AND; }
"OR"  { return TK_OR; }
"NOT" { return TK_NOT; }
```

Estos tokens permiten combinar condiciones.

Ejemplo:

```txt
user admin AND hour >= 9
```

Aquí `AND` conecta el sujeto con una condición de hora.

---

### Reconocimiento de campos válidos

```c
"hour"     { return TK_HOUR; }
"day"      { return TK_DAY; }
"resource" { return TK_RESOURCE; }
```

El lenguaje admite condiciones sobre tres campos principales:

| Campo | Uso |
|---|---|
| `hour` | Validar una condición horaria. |
| `day` | Validar el día de acceso. |
| `resource` | Validar el recurso al que se intenta acceder. |

---

### Reconocimiento de operadores de comparación

```c
">=" { return TK_GEQ; }
"<=" { return TK_LEQ; }
"!=" { return TK_NEQ; }
">"  { return TK_GT; }
"<"  { return TK_LT; }
"="  { return TK_EQ; }
```

Estos operadores permiten construir condiciones como:

```txt
hour >= 9
hour <= 17
resource != 'secrets.env'
day = 'Monday'
```

Un detalle importante es que el operador `==` no está definido. Por eso una regla como:

```txt
user admin AND hour == 10
```

se considera inválida.

---

### Reconocimiento de números

```c
{NUMERO} {
    yylval.ival = atoi(yytext);
    return TK_NUMERO;
}
```

Cuando Flex encuentra un número, lo convierte a entero usando `atoi`.

Por ejemplo:

```txt
9
```

se guarda en:

```c
yylval.ival
```

Esto es importante porque Bison puede usar ese valor en una acción semántica:

```c
printf("Condicion: hour [op] %d\n", $3);
```

---

### Reconocimiento de cadenas

```c
{CADENA} {
    yylval.sval = strdup(yytext);
    return TK_CADENA;
}
```

Las cadenas representan valores textuales, como días o recursos.

Ejemplos:

```txt
'Monday'
'config.xml'
'etc/nginx/nginx.conf'
```

El valor se guarda en `yylval.sval`, para que Bison pueda leerlo y liberarlo posteriormente con `free`.

---

### Manejo de cadenas sin cerrar

```c
{CADENA_ERROR} {
    fprintf(stderr,
            "[ERROR LEXICO] Linea %d: cadena sin cerrar: %s\n",
            numero_linea,
            yytext);
    return TK_ERROR;
}
```

Esta regla detecta errores como:

```txt
user guest AND resource = 'archivo_sin_cerrar
```

En este caso, el lexer identifica que se abrió una comilla simple, pero nunca se cerró.

---

### Manejo de caracteres inválidos

```c
. {
    fprintf(stderr,
            "[ERROR LEXICO] Linea %d: caracter invalido '%s'\n",
            numero_linea,
            yytext);
    return TK_ERROR;
}
```

El punto `.` funciona como regla final de captura. Si ningún patrón anterior coincide, Flex toma el carácter como inválido.

Por ejemplo, en la regla:

```txt
user admin AND @recurso = 'test.txt'
```

el carácter `@` no pertenece al lenguaje, por lo tanto se reporta como error léxico.

---

## 4.6 Importancia del archivo Flex

El archivo `acceso.l` es importante porque:

1. Define el vocabulario válido del lenguaje.
2. Reconoce palabras reservadas, operadores, números y cadenas.
3. Ignora espacios y comentarios.
4. Reporta errores léxicos.
5. Envía tokens al parser de Bison.
6. Lleva control del número de línea para mejorar los mensajes de error.

En resumen, Flex transforma texto plano en tokens estructurados.

---

# Tabla 8: Fragmento del archivo `.y` (Bison) para el analizador de reglas de acceso

## 5. Función del archivo `acceso.y`

El archivo `acceso.y` define el **analizador sintáctico**. Este archivo recibe los tokens generados por Flex y verifica si forman una regla válida.

Por ejemplo, Bison puede aceptar:

```txt
user admin AND hour >= 9
```

porque sigue esta estructura:

```txt
sujeto + conector + condición
```

Pero puede rechazar:

```txt
admin AND hour >= 9
```

porque falta la palabra inicial `user`.

---

## 5.1 Sección de código C inicial

```c
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Contadores globales del análisis.
 */
int reglas_validas = 0;
int reglas_invalidas = 0;

/*
 * Bandera de control:
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
%}
```

### Explicación

Esta sección prepara el entorno del parser.

| Elemento | Función |
|---|---|
| `reglas_validas` | Cuenta cuántas reglas fueron aceptadas. |
| `reglas_invalidas` | Cuenta cuántas reglas fueron rechazadas. |
| `regla_actual_invalida` | Marca si la regla actual tuvo algún error. |
| `extern int yylex(void);` | Permite que Bison llame al lexer generado por Flex. |
| `extern int numero_linea;` | Usa la línea actual reportada por Flex. |
| `extern char *yytext;` | Permite mostrar el token que causó un error. |
| `extern FILE *yyin;` | Permite leer desde un archivo externo. |

---

## 5.2 Función para contabilizar reglas

```c
static void contabilizar_regla_actual(void) {
    if (regla_actual_invalida) {
        reglas_invalidas++;
        regla_actual_invalida = 0;
    } else {
        reglas_validas++;
        printf("[OK] Regla valida (linea ~%d)\n", numero_linea);
    }
}
```

### Explicación

Esta función se ejecuta cuando termina una línea que contiene una regla.

Su tarea es decidir si la regla se cuenta como válida o inválida:

- Si `regla_actual_invalida` vale `1`, se suma una regla inválida.
- Si `regla_actual_invalida` vale `0`, se suma una regla válida.

Esto evita contar la regla varias veces mientras Bison procesa sus condiciones internas.

---

## 5.3 Manejo de errores sintácticos

```c
void yyerror(const char *msg) {
    fprintf(stderr,
            "[ERROR SINTACTICO] Linea %d: %s (token: '%s')\n",
            numero_linea,
            msg,
            yytext);
    regla_actual_invalida = 1;
}
```

### Explicación

Bison llama automáticamente a `yyerror` cuando encuentra una secuencia de tokens que no cumple la gramática.

Por ejemplo:

```txt
user operator AND hour >=
```

Esta regla está incompleta porque después de `>=` falta un valor numérico.

La función no incrementa directamente el contador de inválidas. Solo marca la regla actual como inválida mediante:

```c
regla_actual_invalida = 1;
```

La contabilización final ocurre cuando se llega al fin de línea.

---

## 5.4 Unión semántica

```c
%union {
    int ival;
    char *sval;
}
```

### Explicación

La unión semántica define los tipos de datos que pueden transportar los tokens.

| Campo | Tipo | Uso |
|---|---|---|
| `ival` | `int` | Se usa para números como `9`, `17`, `2026`. |
| `sval` | `char *` | Se usa para cadenas o identificadores. |

Por ejemplo, cuando Flex reconoce un número:

```c
yylval.ival = atoi(yytext);
```

Bison lo recibe como un valor entero.

Cuando Flex reconoce una cadena:

```c
yylval.sval = strdup(yytext);
```

Bison la recibe como texto.

---

## 5.5 Declaración de tokens

```c
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
```

### Explicación

Estos tokens son las unidades que Bison espera recibir desde Flex.

Por ejemplo:

```txt
user admin AND hour >= 9
```

se transforma aproximadamente en:

```txt
TK_USER TK_ADMIN TK_AND TK_HOUR TK_GEQ TK_NUMERO
```

Los tokens `TK_NUMERO`, `TK_CADENA` y `TK_IDENT` tienen tipos asociados porque transportan valores:

| Token | Tipo | Ejemplo |
|---|---|---|
| `TK_NUMERO` | `ival` | `9` |
| `TK_CADENA` | `sval` | `'Monday'` |
| `TK_IDENT` | `sval` | `superuser` |

---

## 5.6 Reglas de producción principales

Las reglas de producción aparecen después del separador `%%`.

```c
%%
programa
    : lineas
    ;

lineas
    : lineas linea
    | /* vacío */
    ;

linea
    : regla TK_EOL {
          contabilizar_regla_actual();
      }
    | regla {
          /*
           * Permite contar la última regla si el archivo
           * no termina con salto de línea.
           */
          contabilizar_regla_actual();
      }
    | TK_EOL {
          /*
           * Línea vacía o comentario.
           * No cuenta como válida ni inválida.
           */
          regla_actual_invalida = 0;
      }
    | error TK_EOL {
          /*
           * Línea inválida recuperada hasta salto de línea.
           */
          reglas_invalidas++;
          regla_actual_invalida = 0;
          yyerrok;
      }
    ;
```

### Explicación

Estas reglas indican cómo se procesa el archivo completo.

| Regla | Función |
|---|---|
| `programa : lineas` | El archivo completo está formado por una lista de líneas. |
| `lineas : lineas linea` | Permite procesar muchas líneas. |
| `lineas : vacío` | Permite que el archivo no tenga reglas. |
| `linea : regla TK_EOL` | Una regla termina con salto de línea. |
| `linea : regla` | Permite que la última regla no tenga salto final. |
| `linea : TK_EOL` | Permite líneas vacías o comentarios. |
| `linea : error TK_EOL` | Permite recuperarse de errores y continuar analizando. |

La recuperación con `error TK_EOL` es muy importante porque evita que el programa se detenga en la primera regla inválida. En lugar de eso, marca la línea como incorrecta y continúa con la siguiente.

---

## 5.7 Regla principal de acceso

```c
regla
    : sujeto condicion_lista
    ;
```

### Explicación

Esta producción define la estructura básica de una regla válida.

Toda regla debe tener:

1. Un sujeto.
2. Una lista de condiciones.

Ejemplo:

```txt
user admin AND hour >= 9
```

Aquí:

```txt
user admin
```

es el sujeto, y:

```txt
AND hour >= 9
```

es la lista de condiciones.

---

## 5.8 Producción del sujeto y roles

```c
sujeto
    : TK_USER rol
    ;

rol
    : TK_ADMIN {
          printf(" Rol: admin\n");
      }
    | TK_GUEST {
          printf(" Rol: guest\n");
      }
    | TK_OPERATOR {
          printf(" Rol: operator\n");
      }
    ;
```

### Explicación

El sujeto siempre debe iniciar con `user` y luego debe incluir un rol válido.

Los roles aceptados por la gramática son:

| Rol | Token |
|---|---|
| `admin` | `TK_ADMIN` |
| `guest` | `TK_GUEST` |
| `operator` | `TK_OPERATOR` |

Por ejemplo, estas reglas tienen sujetos válidos:

```txt
user admin
user guest
user operator
```

Pero esta regla no es válida:

```txt
user superuser AND hour >= 9
```

porque `superuser` no está definido como rol válido.

---

## 5.9 Lista de condiciones y conectores

```c
condicion_lista
    : condicion_lista conector condicion
    | conector condicion
    ;

conector
    : TK_AND {
          printf(" Operador logico: AND\n");
      }
    | TK_OR {
          printf(" Operador logico: OR\n");
      }
    ;
```

### Explicación

Una regla puede tener una o varias condiciones conectadas mediante `AND` u `OR`.

Ejemplo con una condición:

```txt
user admin AND hour >= 9
```

Ejemplo con varias condiciones:

```txt
user admin AND hour >= 9 AND hour <= 17 AND day = 'Friday'
```

La producción recursiva:

```c
condicion_lista : condicion_lista conector condicion
```

permite que una regla crezca agregando más condiciones.

---

## 5.10 Producción de condiciones

```c
condicion
    : condicion_simple
    | TK_NOT condicion_simple {
          printf(" Negacion (NOT) aplicada\n");
      }
    | sujeto {
          printf(" Condicion: sujeto alternativo\n");
      }
    ;
```

### Explicación

Una condición puede ser:

1. Una condición simple.
2. Una condición negada con `NOT`.
3. Un sujeto alternativo.

Ejemplo de condición simple:

```txt
AND hour >= 9
```

Ejemplo con negación:

```txt
AND NOT resource = 'config.xml'
```

Ejemplo de sujeto alternativo:

```txt
user guest OR user operator AND resource = 'logs.txt'
```

Esta última estructura permite expresar alternativas entre sujetos.

---

## 5.11 Condiciones simples

```c
condicion_simple
    : TK_HOUR operador TK_NUMERO {
          printf(" Condicion: hour [op] %d\n", $3);
      }
    | TK_HOUR operador TK_CADENA {
          fprintf(stderr,
                  "[ERROR SEMANTICO] Linea %d: hour debe compararse con un numero, no con %s\n",
                  numero_linea,
                  $3);
          regla_actual_invalida = 1;
          free($3);
      }
    | TK_HOUR operador TK_IDENT {
          fprintf(stderr,
                  "[ERROR SEMANTICO] Linea %d: hour debe compararse con un numero, no con '%s'\n",
                  numero_linea,
                  $3);
          regla_actual_invalida = 1;
          free($3);
      }
    | TK_DAY TK_EQ TK_CADENA {
          printf(" Condicion: day = %s\n", $3);
          free($3);
      }
    | TK_RESOURCE TK_EQ TK_CADENA {
          printf(" Condicion: resource = %s\n", $3);
          free($3);
      }
    | TK_RESOURCE TK_NEQ TK_CADENA {
          printf(" Condicion: resource != %s\n", $3);
          free($3);
      }
    ;
```

### Explicación

Esta sección es una de las más importantes del archivo Bison porque define las condiciones que el lenguaje acepta.

---

### Condición válida sobre hora

```c
TK_HOUR operador TK_NUMERO
```

Acepta reglas como:

```txt
user admin AND hour >= 9
user operator AND hour < 18
```

La acción semántica imprime el valor numérico recibido:

```c
printf(" Condicion: hour [op] %d\n", $3);
```

Aquí `$3` representa el tercer elemento de la producción, es decir, el número.

---

### Error semántico: hora comparada con cadena

```c
TK_HOUR operador TK_CADENA
```

Esta producción detecta una regla sintácticamente reconocible, pero semánticamente incorrecta.

Ejemplo:

```txt
user admin AND hour >= 'nueve'
```

Aunque la estructura parece similar a una condición válida, el campo `hour` debe compararse con un número, no con una cadena.

Por eso se marca:

```c
regla_actual_invalida = 1;
```

Este es un error semántico porque la regla tiene forma reconocible, pero el tipo de dato no corresponde.

---

### Condición válida sobre día

```c
TK_DAY TK_EQ TK_CADENA
```

Acepta reglas como:

```txt
user operator AND day = 'Monday'
```

En este caso, el campo `day` solo se compara con cadenas usando el operador `=`.

---

### Condición válida sobre recurso

```c
TK_RESOURCE TK_EQ TK_CADENA
TK_RESOURCE TK_NEQ TK_CADENA
```

Acepta reglas como:

```txt
user operator AND resource = 'database.db'
user guest AND resource != 'secrets.env'
```

Para `resource`, la gramática permite igualdad `=` y diferencia `!=`.

---

## 5.12 Operadores permitidos para hora

```c
operador
    : TK_GEQ {
          printf(" Operador: >=\n");
      }
    | TK_LEQ {
          printf(" Operador: <=\n");
      }
    | TK_GT {
          printf(" Operador: >\n");
      }
    | TK_LT {
          printf(" Operador: <\n");
      }
    | TK_EQ {
          printf(" Operador: =\n");
      }
    ;
```

### Explicación

Esta producción define los operadores válidos para condiciones de hora.

| Operador | Token | Ejemplo |
|---|---|---|
| `>=` | `TK_GEQ` | `hour >= 9` |
| `<=` | `TK_LEQ` | `hour <= 17` |
| `>` | `TK_GT` | `hour > 7` |
| `<` | `TK_LT` | `hour < 18` |
| `=` | `TK_EQ` | `hour = 12` |

El operador `!=` está definido como token, pero no aparece dentro de esta producción de operadores para `hour`. En este diseño, `!=` se usa especialmente para `resource`.

---

## 5.13 Función principal `main`

```c
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

    if (regla_actual_invalida) {
        reglas_invalidas++;
        regla_actual_invalida = 0;
    }

    printf("\n=== Resumen del Analisis ===\n");
    printf("Reglas validas : %d\n", reglas_validas);
    printf("Reglas invalidas: %d\n", reglas_invalidas);
    printf("Total procesadas: %d\n", reglas_validas + reglas_invalidas);

    if (entrada) {
        fclose(entrada);
    }

    return (reglas_invalidas > 0) ? 1 : 0;
}
```

### Explicación

La función `main` es el punto de entrada del programa.

Su funcionamiento es:

1. Verifica si el usuario envió un archivo como argumento.
2. Intenta abrir ese archivo.
3. Asigna el archivo a `yyin`, que es la entrada usada por Flex.
4. Ejecuta `yyparse()`, que inicia el análisis sintáctico.
5. Cuenta un posible error pendiente al final del archivo.
6. Imprime el resumen final.
7. Cierra el archivo.
8. Retorna `1` si hubo reglas inválidas y `0` si todas fueron válidas.

---

## 6. Relación entre Flex y Bison

La comunicación entre ambos archivos se da de la siguiente manera:

```txt
acceso.l reconoce texto
        │
        ▼
retorna tokens como TK_USER, TK_ADMIN, TK_HOUR
        │
        ▼
acceso.y recibe esos tokens
        │
        ▼
Bison valida si la secuencia cumple la gramática
```

Ejemplo:

```txt
user admin AND hour >= 9
```

Flex produce:

```txt
TK_USER TK_ADMIN TK_AND TK_HOUR TK_GEQ TK_NUMERO
```

Bison interpreta esa secuencia así:

```txt
sujeto condicion_lista
```

y la regla se considera válida.

---

## 7. Ejemplos de reglas válidas

```txt
user admin AND hour >= 9
user admin AND hour >= 9 AND hour <= 17
user guest AND NOT resource = 'config.xml'
user operator AND day = 'Monday'
user operator AND resource = 'database.db'
user guest AND resource != 'secrets.env'
user admin AND NOT resource = 'root.key' AND hour >= 9
```

Estas reglas son válidas porque:

- Inician con `user`.
- Usan un rol permitido.
- Usan conectores válidos.
- Comparan `hour` con números.
- Comparan `day` y `resource` con cadenas.
- Usan operadores admitidos por la gramática.

---

## 8. Ejemplos de reglas inválidas

```txt
user AND hour >= 9
user superuser AND hour >= 9
user admin AND hour == 10
user operator AND hour >=
user guest AND resource = 'archivo_sin_cerrar
admin AND hour >= 9
user admin AND hour >= 'nueve'
user operator AND NOT NOT resource = 'data.csv'
user guest AND day =
user admin AND @recurso = 'test.txt'
```

### Explicación de errores

| Regla | Motivo |
|---|---|
| `user AND hour >= 9` | Falta el rol después de `user`. |
| `user superuser AND hour >= 9` | `superuser` no es un rol válido. |
| `user admin AND hour == 10` | El operador `==` no está definido. |
| `user operator AND hour >=` | Falta el valor después del operador. |
| `user guest AND resource = 'archivo_sin_cerrar` | Cadena sin cerrar. |
| `admin AND hour >= 9` | Falta `user` al inicio. |
| `user admin AND hour >= 'nueve'` | Error semántico: `hour` debe compararse con número. |
| `user operator AND NOT NOT resource = 'data.csv'` | La gramática no soporta doble negación. |
| `user guest AND day =` | Falta el valor de la condición. |
| `user admin AND @recurso = 'test.txt'` | `@` es un carácter inválido. |

---

## 9. Compilación y ejecución

El proyecto incluye un `Makefile` para compilar automáticamente los archivos de Flex y Bison.

El flujo de compilación es:

```txt
acceso.y  →  win_bison  →  acceso.tab.c y acceso.tab.h
acceso.l  →  win_flex   →  acceso.lex.c
archivos C generados → gcc → acceso.exe
```

Comando para compilar:

```bash
make all
```

Comando para ejecutar las pruebas:

```bash
make test
```

También se puede ejecutar manualmente:

```bash
./acceso.exe ../tests/archivo_pruebas.txt
```

---

## 10. Importancia de los fragmentos seleccionados

Los fragmentos seleccionados del archivo `.l` y del archivo `.y` son pertinentes porque muestran las partes centrales del analizador:

| Archivo | Fragmento seleccionado | Importancia |
|---|---|---|
| `acceso.l` | Definiciones C | Conecta Flex con Bison mediante `acceso.tab.h`. |
| `acceso.l` | Macros léxicas | Define cómo reconocer números, cadenas, identificadores y comentarios. |
| `acceso.l` | Reglas léxicas | Convierte texto en tokens. |
| `acceso.l` | Manejo de errores | Detecta cadenas sin cerrar y caracteres inválidos. |
| `acceso.y` | Declaración de tokens | Define los símbolos que Bison espera recibir. |
| `acceso.y` | Reglas de producción | Define la estructura válida del lenguaje. |
| `acceso.y` | Acciones semánticas | Valida tipos de datos y reporta errores. |
| `acceso.y` | Función `main` | Ejecuta el análisis y muestra el resumen final. |

---

## 11. Conclusión

El proyecto implementa un analizador completo para reglas de acceso mediante la separación clásica entre análisis léxico y análisis sintáctico.

El archivo `acceso.l` se encarga de identificar las unidades básicas del lenguaje, como palabras reservadas, operadores, números, cadenas y errores léxicos.

El archivo `acceso.y` se encarga de validar que esas unidades aparezcan en un orden correcto, formando reglas válidas. Además, incorpora acciones semánticas para detectar errores de tipo, como comparar `hour` con una cadena en lugar de un número.

Gracias a esta arquitectura, el analizador puede procesar múltiples reglas, reportar errores por línea, continuar después de encontrar errores y generar un resumen final con la cantidad de reglas válidas e inválidas.
