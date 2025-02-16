/*****************************************************************************
 * json/lexicon.l: JSON tokeniser
 *****************************************************************************
 * Copyright © 2020 Rémi Denis-Courmont
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

%option 8bit
%option bison-bridge
%option nodefault
%option noinput
%option reentrant
%option nostdinit
%option nounput
%option noyywrap
%option prefix="json" outfile="lex.yy.c"

%{

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdbool.h>
#include <stdlib.h>
#include "json.h"
#include "grammar.h"

#define YY_INPUT(buf,result,size) \
{ \
    size_t len = json_read(yyextra, buf, size); \
    result = (len > 0) ? len : YY_NULL; \
}

%}

%%

[\t\r\n ]		;

"null" {		return VALUE_NULL; }

"false"	{		yylval->boolean = false;
			return BOOLEAN; }

"true" {		yylval->boolean = true;
			return BOOLEAN; }

-?(0|([1-9][0-9]*))(\.[0-9]+)?(e[+-]?[0-9]+)? {
			yylval->number = atof(yytext);
			return NUMBER; }

\"([^"\\]|\\[\"\\/bfnrt]|\\u[0-9A-Fa-f]{4})*\" {
			yylval->string = json_unescape(yytext + 1, yyleng - 2);
			return STRING; }

[{}:,[\]] {		return *yytext; }

. {			return *yytext; }

<<EOF>> {		return 0; }

%%
