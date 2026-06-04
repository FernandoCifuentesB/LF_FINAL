/*
 * =============================================================================
 *  ARCHIVO: sql.y
 *  DESCRIPCIÓN: Analizador sintáctico (Bison/LALR(1)) para el lenguaje SQL
 *               simplificado.  Valida la estructura de la sentencia de inserción:
 *                 insertar en tabla <ID> valores: <campo>=<valor>,... fin;
 *               y, tras una reducción exitosa, construye y ejecuta la instrucción
 *               INSERT INTO ... VALUES (...) sobre una base de datos SQLite.
 *  HERRAMIENTA: Win Bison 3.8.2 / GNU Bison 3.8+
 *  COMPILADOR:  GCC 13.2.0 (MinGW-w64 / w64devkit)
 *  SISTEMA:     Windows 10/11 64-bit
 *  MOTOR BD:    SQLite 3.45.1 (sqlite3.c + sqlite3.h en amalgama)
 *  AUTOR:       Proyecto Analizador SQL Simplificado
 * =============================================================================
 */

/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 1 – PRÓLOGO (código C copiado al inicio del archivo generado)
 * ───────────────────────────────────────────────────────────────────────────── */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sqlite3.h"        /* API de SQLite (amalgamación embebida)             */

/* ── Prototipo de funciones que Bison espera externamente ─────────────────── */
void yyerror(const char *s);  /* manejador de errores sintácticos               */
extern int yylex(void);       /* función del analizador léxico generado por Flex */
extern int num_linea;         /* contador de línea, declarado en sql.l           */

/* ── Puntero global a la conexión SQLite ──────────────────────────────────── */
static sqlite3 *db = NULL;

/*
 * Buffers estáticos para acumular los componentes de la sentencia INSERT
 * a medida que Bison reduce las reglas de <asignacion>.
 *
 *   tabla_actual  → nombre de la tabla destino (extraído de TK_ID tras TK_TABLA)
 *   campos_buf    → lista de nombres de campo separados por coma  (ej: "nombre,cargo")
 *   valores_buf   → lista de valores separados por coma           (ej: "'Ana','dev'")
 *
 * Se usan buffers de tamaño fijo porque el lenguaje es simplificado; en un
 * analizador de producción se emplearían listas dinámicas (linked list, etc.).
 */
static char tabla_actual[64];
static char campos_buf[1024];
static char valores_buf[1024];

/* ── Prototipo de la función de inserción ────────────────────────────────── */
static void ejecutar_insert(const char *tabla,
                             const char *campos,
                             const char *valores);

/* ── Inicialización de la base de datos y las tablas predefinidas ─────────── */
static void inicializar_bd(void);

%}

/* ─────────────────────────────────────────────────────────────────────────────
 * DECLARACIÓN DE LA UNIÓN SEMÁNTICA
 *   Define los tipos de datos que pueden tomar los símbolos de la gramática.
 *     sval  → puntero a cadena de caracteres (para TK_ID, TK_CADENA, TK_BOOL)
 *     ival  → entero (para TK_ENTERO)
 * ───────────────────────────────────────────────────────────────────────────── */
%union {
    char *sval;   /* valor semántico de tipo cadena */
    int   ival;   /* valor semántico de tipo entero  */
}

/* ─────────────────────────────────────────────────────────────────────────────
 * DECLARACIÓN DE TOKENS
 *   Los tokens sin tipo semántico (<>) solo devuelven la constante numérica.
 *   Los tokens con tipo (<sval> / <ival>) también escriben en yylval.
 * ───────────────────────────────────────────────────────────────────────────── */

/* Palabras clave — sin valor semántico */
%token TK_INSERTAR
%token TK_EN
%token TK_TABLA
%token TK_VALORES
%token TK_FIN

/* Símbolos de puntuación — sin valor semántico */
%token TK_IGUAL
%token TK_COMA
%token TK_DOSPUNTOS
%token TK_PTOCOMA

/* Tokens con valor semántico de cadena */
%token <sval> TK_ID        /* identificador de tabla o campo          */
%token <sval> TK_CADENA    /* literal de cadena entre comillas simples */
%token <sval> TK_BOOL      /* "true" o "false"                         */

/* Token con valor semántico entero */
%token <ival> TK_ENTERO    /* literal numérico entero                  */

/* ─────────────────────────────────────────────────────────────────────────────
 * TIPOS DE NO TERMINALES
 *   Se declara el tipo semántico de los no terminales que producen un valor
 *   que necesita propagarse hacia arriba en el árbol de análisis.
 *     <valor>      → devuelve la representación textual del valor para SQL
 * ───────────────────────────────────────────────────────────────────────────── */
%type <sval> valor

/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 2 – REGLAS GRAMATICALES (gramática LALR(1))
 *   Formato:   no_terminal : producción  { acción semántica en C }
 *                          | producción  { acción semántica en C }
 *                          ;
 *   $n   → valor semántico del n-ésimo símbolo en la producción (1-indexado)
 *   $$   → valor semántico del no terminal en el lado izquierdo (LHS)
 * ───────────────────────────────────────────────────────────────────────────── */
%%

/*
 * ─── PROGRAMA ───────────────────────────────────────────────────────────────
 *   El símbolo inicial.  Acepta una o más sentencias consecutivas (el archivo
 *   puede contener múltiples inserciones separadas por fin;).
 *   La recursión izquierda es eficiente con LALR(1): no crece la pila.
 */
programa
    : sentencia
        {
            /* una sola sentencia en el archivo → reducción base */
        }
    | programa sentencia
        {
            /* más de una sentencia: se procesa la nueva sentencia
               después de haber procesado el programa anterior */
        }
    ;

/*
 * ─── SENTENCIA ──────────────────────────────────────────────────────────────
 *   Producción completa de la instrucción de inserción.
 *   Estructura esperada:
 *       insertar  en  tabla  <ID>  valores  :  <asignaciones>  fin  ;
 *       $1        $2  $3     $4    $5        $6  $7              $8   $9
 *
 *   Acción en $4 (mid-rule): en cuanto se reduce TK_ID se captura el nombre
 *   de la tabla y se limpian los buffers de campos/valores para esta sentencia.
 *   Acción final: se dispara ejecutar_insert() con los datos acumulados.
 */
sentencia
    : TK_INSERTAR TK_EN TK_TABLA TK_ID
        {
            /*
             * Acción de regla intermedia (mid-rule action):
             * Se ejecuta ANTES de parsear el resto de la producción.
             * En este punto $4 contiene el nombre de la tabla.
             */
            strncpy(tabla_actual, $4, sizeof(tabla_actual) - 1);
            tabla_actual[sizeof(tabla_actual) - 1] = '\0';
            campos_buf[0]  = '\0';   /* limpiar buffer de campos  */
            valores_buf[0] = '\0';   /* limpiar buffer de valores */
            free($4);                /* liberar la copia de strdup */
        }
      TK_VALORES TK_DOSPUNTOS asignaciones TK_FIN TK_PTOCOMA
        {
            /*
             * Acción final de la sentencia:
             * En este punto campos_buf y valores_buf contienen los pares
             * acumulados por las reducciones de <asignacion>.
             */
            ejecutar_insert(tabla_actual, campos_buf, valores_buf);
            printf("[OK] Inserción ejecutada en tabla '%s'\n", tabla_actual);
        }
    ;

/*
 * ─── ASIGNACIONES ───────────────────────────────────────────────────────────
 *   Lista de uno o más pares campo = valor separados por coma.
 *   Recursión izquierda: asignaciones → asignaciones , asignacion
 *   Esto construye la lista de izquierda a derecha, que es el orden
 *   en que deben aparecer los campos en la instrucción INSERT.
 */
asignaciones
    : asignacion
        {
            /* primera (y posiblemente única) asignación de la lista */
        }
    | asignaciones TK_COMA asignacion
        {
            /* se agrega la nueva asignación a la lista ya acumulada */
        }
    ;

/*
 * ─── ASIGNACION ─────────────────────────────────────────────────────────────
 *   Par individual campo = valor.
 *     $1 → TK_ID  (nombre del campo)
 *     $3 → valor  (cadena, entero, booleano o identificador)
 *
 *   Acumulación en buffers:
 *     • Si ya hay contenido en campos_buf se agrega una coma antes.
 *     • Se usa strncat con límites para evitar desbordamiento de buffer.
 */
asignacion
    : TK_ID TK_IGUAL valor
        {
            /*
             * Acumular nombre del campo en campos_buf.
             * Se concatena directamente porque TK_ID es un identificador
             * simple (sin comillas).
             */
            if (campos_buf[0] != '\0') {
                strncat(campos_buf, ",",
                        sizeof(campos_buf) - strlen(campos_buf) - 1);
            }
            strncat(campos_buf, $1,
                    sizeof(campos_buf) - strlen(campos_buf) - 1);

            /*
             * Acumular valor en valores_buf.
             * $3 contiene la representación ya formateada devuelta por <valor>:
             *   - cadenas:   'texto'   (con comillas simples, listas para SQL)
             *   - enteros:   42        (representación decimal como texto)
             *   - booleanos: 1 ó 0     (SQLite usa INTEGER para booleanos)
             */
            if (valores_buf[0] != '\0') {
                strncat(valores_buf, ",",
                        sizeof(valores_buf) - strlen(valores_buf) - 1);
            }
            strncat(valores_buf, $3,
                    sizeof(valores_buf) - strlen(valores_buf) - 1);

            free($1);   /* liberar copia de strdup del campo  */
            free($3);   /* liberar copia de strdup del valor  */
        }
    ;

/*
 * ─── VALOR ──────────────────────────────────────────────────────────────────
 *   Devuelve ($$ = sval) una cadena de caracteres lista para incluir en
 *   la instrucción INSERT INTO ... VALUES (...).
 *
 *   TK_CADENA → ya viene con comillas simples: "'texto'"  → se usa directamente
 *   TK_ENTERO → se convierte a su representación decimal en texto
 *   TK_BOOL   → "true" → "1", "false" → "0"  (SQLite almacena como INTEGER)
 *   TK_ID     → identificador simbólico; se usa sin comillas (para extensión)
 */
valor
    : TK_CADENA
        {
            /*
             * El lexer devuelve la cadena con sus comillas simples incluidas,
             * por ejemplo  'Juan'.  SQLite acepta exactamente este formato.
             */
            $$ = $1;   /* propagamos el sval directamente */
        }
    | TK_ENTERO
        {
            /*
             * Convertir el entero (yylval.ival) a su representación textual.
             * Se reserva memoria suficiente para un int de 32 bits (máx 11 dígitos).
             */
            char *buf = malloc(16);
            if (buf == NULL) { yyerror("sin memoria"); exit(1); }
            snprintf(buf, 16, "%d", $1);
            $$ = buf;
        }
    | TK_BOOL
        {
            /*
             * SQLite no tiene tipo BOOLEAN nativo; la convención estándar es
             * almacenar 1 (true) o 0 (false) como INTEGER.
             */
            if (strcmp($1, "true") == 0) {
                $$ = strdup("1");
            } else {
                $$ = strdup("0");
            }
            free($1);
        }
    | TK_ID
        {
            /*
             * Identificador como valor (p.ej. un nombre simbólico).
             * Se propaga sin comillas; útil para extensiones futuras.
             */
            $$ = $1;
        }
    ;

%%

/* ─────────────────────────────────────────────────────────────────────────────
 * SECCIÓN 3 – EPÍLOGO (funciones auxiliares en C)
 * ───────────────────────────────────────────────────────────────────────────── */

/*
 * yyerror()
 * ─────────────────────────────────────────────────────────────────────────────
 * Función de reporte de errores sintácticos, invocada automáticamente por Bison
 * cuando la tabla de análisis no puede desplazar ni reducir el token actual.
 *
 * Parámetros:
 *   s → mensaje de error generado por Bison (normalmente "syntax error")
 *
 * Comportamiento:
 *   Imprime el mensaje junto con la línea actual (num_linea) a stderr.
 *   No aborta el análisis; Bison intentará recuperarse si la gramática
 *   incluye la producción de error especial (aquí no se usa para simplificar).
 */
void yyerror(const char *s) {
    fprintf(stderr, "[ERROR SINTÁCTICO] Línea %d: %s\n", num_linea, s);
}

/*
 * inicializar_bd()
 * ─────────────────────────────────────────────────────────────────────────────
 * Abre (o crea si no existe) el archivo de base de datos SQLite "bd_sql.db"
 * y crea las tres tablas predefinidas si aún no existen:
 *
 *   empleados  (id, nombre, cargo, salario)
 *   productos  (id, nombre, precio, activo)
 *   pedidos    (id, cliente, producto, cantidad)
 *
 * Cada tabla tiene un campo id con PRIMARY KEY AUTOINCREMENT para no requerir
 * que el usuario de la gramática proporcione el ID explícitamente (aunque puede
 * hacerlo; INSERT con lista de campos lo ignora si no se especifica).
 *
 * La opción "IF NOT EXISTS" garantiza idempotencia: ejecutar el analizador
 * varias veces no destruye los datos existentes.
 */
static void inicializar_bd(void) {
    int rc;
    char *err_msg = NULL;

    /* Abrir / crear el archivo de base de datos */
    rc = sqlite3_open("bd_sql.db", &db);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "[BD ERROR] No se pudo abrir bd_sql.db: %s\n",
                sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(1);
    }
    printf("[BD] Base de datos 'bd_sql.db' abierta correctamente.\n");

    /*
     * SQL para crear las tres tablas predefinidas.
     * Se usa una sola llamada a sqlite3_exec() con sentencias separadas por ';'.
     * Los tipos siguen el sistema de afinidad de SQLite:
     *   TEXT    → cadenas de longitud variable
     *   INTEGER → enteros (también almacena booleanos como 0/1)
     */
    const char *sql_create =
        /* ── Tabla empleados ──────────────────────────────────────────── */
        "CREATE TABLE IF NOT EXISTS empleados ("
        "  id      INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  nombre  TEXT    NOT NULL,"
        "  cargo   TEXT    NOT NULL,"
        "  salario INTEGER NOT NULL"
        ");"

        /* ── Tabla productos ──────────────────────────────────────────── */
        "CREATE TABLE IF NOT EXISTS productos ("
        "  id      INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  nombre  TEXT    NOT NULL,"
        "  precio  INTEGER NOT NULL,"
        "  activo  INTEGER NOT NULL DEFAULT 1"   /* 1=true, 0=false */
        ");"

        /* ── Tabla pedidos ────────────────────────────────────────────── */
        "CREATE TABLE IF NOT EXISTS pedidos ("
        "  id       INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  cliente  TEXT    NOT NULL,"
        "  producto TEXT    NOT NULL,"
        "  cantidad INTEGER NOT NULL"
        ");";

    rc = sqlite3_exec(db, sql_create, NULL, NULL, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "[BD ERROR] Al crear tablas: %s\n", err_msg);
        sqlite3_free(err_msg);
        sqlite3_close(db);
        exit(1);
    }
    printf("[BD] Tablas 'empleados', 'productos', 'pedidos' verificadas/creadas.\n");
}

/*
 * ejecutar_insert()
 * ─────────────────────────────────────────────────────────────────────────────
 * Construye dinámicamente la instrucción SQL nativa:
 *     INSERT INTO <tabla> (<campos>) VALUES (<valores>);
 * y la ejecuta mediante sqlite3_exec().
 *
 * Parámetros:
 *   tabla   → nombre de la tabla destino (ej: "empleados")
 *   campos  → lista de campos separados por coma (ej: "nombre,cargo,salario")
 *   valores → lista de valores separados por coma (ej: "'Ana','dev',3000")
 *
 * Manejo de errores:
 *   Si la instrucción falla (campo inexistente, tipo incorrecto, etc.) se
 *   imprime el mensaje de error de SQLite en stderr pero NO se aborta el
 *   programa; el analizador continúa procesando las sentencias siguientes.
 *
 * Seguridad:
 *   En un sistema de producción se usarían sentencias preparadas
 *   (sqlite3_prepare_v2 + sqlite3_bind_*) para prevenir inyección SQL.
 *   Aquí se construye la cadena directamente porque los valores ya han sido
 *   validados léxica y sintácticamente por Flex/Bison.
 */
static void ejecutar_insert(const char *tabla,
                             const char *campos,
                             const char *valores) {
    /*
     * Buffer para la instrucción SQL completa.
     * Tamaño: 2048 bytes cubre instrucciones razonables dentro del lenguaje
     * simplificado (máximo ~4 campos con valores de texto).
     */
    char sql[2048];
    char *err_msg = NULL;
    int   rc;

    /* Construir la cadena SQL con snprintf (seguro, evita desbordamiento) */
    snprintf(sql, sizeof(sql),
             "INSERT INTO %s (%s) VALUES (%s);",
             tabla, campos, valores);

    printf("[SQL] Ejecutando: %s\n", sql);

    /* Ejecutar la instrucción en la base de datos abierta */
    rc = sqlite3_exec(db, sql, NULL, NULL, &err_msg);
    if (rc != SQLITE_OK) {
        fprintf(stderr, "[BD ERROR] Inserción fallida: %s\n", err_msg);
        sqlite3_free(err_msg);
        /* No se llama exit(); se continúa con la siguiente sentencia */
    } else {
        printf("[BD] Registro insertado correctamente. "
               "Filas afectadas: %d\n",
               (int)sqlite3_changes(db));
    }
}

/*
 * main()
 * ─────────────────────────────────────────────────────────────────────────────
 * Punto de entrada del programa.
 *
 * Uso:
 *   ./sql                    → lee de stdin (entrada interactiva o redirección)
 *   ./sql < consultas.txt    → procesa el archivo consultas.txt
 *   echo "insertar ..." | ./sql
 *
 * Secuencia:
 *   1. Inicializar la base de datos (abrir/crear bd_sql.db + tablas).
 *   2. Llamar a yyparse() que consume tokens de yylex() hasta EOF o error fatal.
 *   3. Cerrar la conexión SQLite.
 *   4. Devolver 0 (éxito) o 1 si yyparse() reportó errores.
 */
int main(void) {
    int resultado;

    printf("=== Analizador Léxico-Sintáctico SQL Simplificado ===\n");
    printf("Ingrese sentencias de inserción (Ctrl+D / Ctrl+Z para terminar):\n\n");

    /* Paso 1: inicializar la base de datos SQLite */
    inicializar_bd();

    /* Paso 2: invocar el analizador sintáctico generado por Bison */
    resultado = yyparse();

    /* Paso 3: cerrar la conexión de forma limpia */
    if (db != NULL) {
        sqlite3_close(db);
        printf("\n[BD] Conexión cerrada.\n");
    }

    /* Paso 4: código de salida */
    if (resultado == 0) {
        printf("[FIN] Análisis completado sin errores fatales.\n");
    } else {
        fprintf(stderr, "[FIN] Análisis completado con errores.\n");
    }

    return resultado;
}
