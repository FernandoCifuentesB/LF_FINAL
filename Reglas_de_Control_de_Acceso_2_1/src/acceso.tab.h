/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_ACCESO_TAB_H_INCLUDED
# define YY_YY_ACCESO_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    TK_USER = 258,                 /* TK_USER  */
    TK_ADMIN = 259,                /* TK_ADMIN  */
    TK_GUEST = 260,                /* TK_GUEST  */
    TK_OPERATOR = 261,             /* TK_OPERATOR  */
    TK_AND = 262,                  /* TK_AND  */
    TK_OR = 263,                   /* TK_OR  */
    TK_NOT = 264,                  /* TK_NOT  */
    TK_HOUR = 265,                 /* TK_HOUR  */
    TK_DAY = 266,                  /* TK_DAY  */
    TK_RESOURCE = 267,             /* TK_RESOURCE  */
    TK_EOL = 268,                  /* TK_EOL  */
    TK_SEMICOLON = 269,            /* TK_SEMICOLON  */
    TK_GEQ = 270,                  /* TK_GEQ  */
    TK_LEQ = 271,                  /* TK_LEQ  */
    TK_GT = 272,                   /* TK_GT  */
    TK_LT = 273,                   /* TK_LT  */
    TK_EQ = 274,                   /* TK_EQ  */
    TK_NEQ = 275,                  /* TK_NEQ  */
    TK_NUMERO = 276,               /* TK_NUMERO  */
    TK_CADENA = 277,               /* TK_CADENA  */
    TK_IDENT = 278,                /* TK_IDENT  */
    TK_ERROR = 279                 /* TK_ERROR  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 70 "acceso.y"

    int   ival;
    char *sval;

#line 93 "acceso.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_ACCESO_TAB_H_INCLUDED  */
