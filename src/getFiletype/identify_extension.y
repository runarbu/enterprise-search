%{
// (C) Copyright SearchDaimon AS 2008, Magnus Gal�en (mg@searchdaimon.com)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../ds/dcontainer.h"
#include "../ds/dvector.h"

#include "identify_extension.h"


// --- fra flex:
typedef void* yyscan_t;
typedef struct fte_buffer_state *YY_BUFFER_STATE;
YY_BUFFER_STATE fte_scan_bytes( const char *bytes, int len, yyscan_t yyscanner );
struct fte_yy_extra *fteget_extra( yyscan_t yyscanner );
// ---


static inline int fte_findc(container *V, char *str)
{
    int		i;

    for (i=0; i<vector_size(V); i++)
	if (!strcmp(vector_get(V,i).ptr, str))
	    return i;

    return -1;
}

static inline int fte_find(char **A, int size, char *str)
{
    int		i;

    for (i=0; i<size; i++)
	if (!strcmp(A[i], str))
	    return i;

    return -1;
}

struct fte_ext
{
    char	*ext;
    int		descr, group;
};


struct fte_yacc_data
{
    int		modus;
    int		lang_size, group_size, descr_size;
    container	*lang, *ext, *version;
    container	**group, **descr;
    char	**default_group, **default_descr;
};

%}

%pure-parser
%parse-param { struct fte_yacc_data *data }
%parse-param { yyscan_t yyscanner }
%lex-param { yyscan_t yyscanner }
%token EQUALS_ID STRING_ID BRACKET_BEGIN BRACKET_CLOSE COMMA_ID SEMICOLON_ID LANG_ID GROUP_ID FILE_ID NAME_ID EXT_ID VERSION_ID DEFAULT_ID POSTFIX_ID

%%
doc	: lang default list_of_groups
	;
lang	: lang_id EQUALS_ID string_list SEMICOLON_ID
	{
	    int		i;

	    data->lang_size = vector_size( data->lang );
	    data->modus++;

	    printf("lang = {");
	    for (i=0; i<data->lang_size; i++)
		{
		    if (i>0) printf(",");
		    printf("%s", vector_get( data->lang, i ).ptr);
		}
	    printf("}\n");

	    data->group = malloc(sizeof(container*) * data->lang_size);
	    data->descr = malloc(sizeof(container*) * data->lang_size);
	    data->default_group = malloc(sizeof(char*) * data->lang_size);
	    data->default_descr = malloc(sizeof(char*) * data->lang_size);

	    for (i=0; i<data->lang_size; i++)
		{
		    data->group[i] = vector_container( string_container() );
		    data->descr[i] = vector_container( string_container() );
		    data->default_group[i] = NULL;
		    data->default_descr[i] = NULL;
		}

	    data->ext = vector_container( ptr_container() );
	    data->version = vector_container( string_container() );

	    data->group_size = 0;
	    data->descr_size = 0;
	}
	;
lang_id	: LANG_ID
	{
	    data->modus = 1;
	    data->lang = vector_container( string_container() );
	}
	;
default	: DEFAULT_ID BRACKET_BEGIN def_ids BRACKET_CLOSE
	;
def_ids	:
	| def_ids NAME_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    data->default_group[0] = strdup((char*)$4);
	}
	| def_ids NAME_ID STRING_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    int		lang_no = fte_findc(data->lang, (char*)$3);

	    if (lang_no<0) fprintf(stderr, "getfiletype: Parse error! Invalid lang-specifier.\n");
	    else data->default_group[lang_no] = strdup((char*)$5);
	}
	| def_ids POSTFIX_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    data->default_descr[0] = strdup((char*)$4);
	}
	| def_ids POSTFIX_ID STRING_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    int		lang_no = fte_findc(data->lang, (char*)$3);

	    if (lang_no<0) fprintf(stderr, "getfiletype: Parse error! Invalid lang-specifier.\n");
	    else data->default_descr[lang_no] = strdup((char*)$5);
	}
	;
list_of_groups :
	| list_of_groups group
	;
group	: GROUP_ID BRACKET_BEGIN group_ids BRACKET_CLOSE
	{
	    int		i;

	    data->group_size++;

	    for (i=0; i<data->lang_size; i++)
		{
		    if (vector_size(data->group[i]) < data->group_size)
			vector_pushback(data->group[i], NULL);
		}
	}
	;
group_ids :
	| group_ids NAME_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
//	    printf("  group_name = \"%s\"\n", $4);
	    vector_pushback( data->group[0], $4 );
	}
	| group_ids NAME_ID STRING_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    int		lang_no = fte_findc(data->lang, (char*)$3);

	    if (lang_no<0) fprintf(stderr, "getfiletype: Parse error! Invalid lang-specifier.\n");
	    else vector_pushback( data->group[lang_no], $5 );
	}
	| group_ids file
	;
file	: FILE_ID BRACKET_BEGIN file_ids BRACKET_CLOSE
	{
	    int		i;

	    data->descr_size++;

	    for (i=0; i<data->lang_size; i++)
		{
		    if (vector_size(data->descr[i]) < data->descr_size)
			vector_pushback(data->descr[i], NULL);
		}

	    if (vector_size(data->version) < data->descr_size)
		vector_pushback(data->version, NULL);
	}
	;
file_ids :
	| file_ids NAME_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    vector_pushback( data->descr[0], $4 );
	}
	| file_ids NAME_ID STRING_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    int		lang_no = fte_findc(data->lang, (char*)$3);

	    if (lang_no<0) fprintf(stderr, "getfiletype: Parse error! Invalid lang-specifier.\n");
	    else vector_pushback( data->descr[lang_no], $5 );
	}
	| file_ids EXT_ID EQUALS_ID string_list SEMICOLON_ID
	{
	}
	| file_ids VERSION_ID EQUALS_ID STRING_ID SEMICOLON_ID
	{
	    vector_pushback( data->version, $4 );
	}
	;
string_list : STRING_ID
	{
	    if (data->modus == 1)
	        vector_pushback( data->lang, $1 );
	    else
		{
		    struct fte_ext	*fe = malloc(sizeof(struct fte_ext));
		    fe->ext = strdup((char*)$1);
		    fe->group = data->group_size;
		    fe->descr = data->descr_size;
	    	    vector_pushback( data->ext, fe );
		}
	}
	| string_list COMMA_ID STRING_ID
	{
	    if (data->modus == 1)
	        vector_pushback( data->lang, $3 );
	    else
		{
		    struct fte_ext	*fe = malloc(sizeof(struct fte_ext));
		    fe->ext = strdup((char*)$3);
		    fe->group = data->group_size;
		    fe->descr = data->descr_size;
	    	    vector_pushback( data->ext, fe );
		}
	}
	;
%%


struct fte_data* fte_init( char *conf_file )
{
    FILE	*fyyin = fopen(conf_file, "r");

    if (fyyin==NULL)
	{
    	    fprintf(stderr, "getfiletype: Error! Could not open file '%s'.\n", conf_file);
	    return NULL;
	}

    struct fte_yacc_data	*data = malloc(sizeof(struct fte_yacc_data));

    yyscan_t		scanner;

    ftelex_init(&scanner);
    fteset_extra(data, scanner);
    fteset_in(fyyin, scanner);

    printf("getfiletype: Running scanner...\n");

    fteparse(data, scanner);

    printf("getfiletype: Done.\n");

    ftelex_destroy(scanner);
    fclose(fyyin);
/*
struct fte_data
{
    int		lang_size, group_size, descr_size, ext_size;
    char	**lang, **ext, **version;
    int		*ext2descr, *ext2group;
    char	***group, ***descr;
};
*/

    struct fte_data	*fdata = malloc(sizeof(struct fte_data));
    int			i, j;

    fdata->lang_size = data->lang_size;
    fdata->group_size = data->group_size;
    fdata->descr_size = data->descr_size;
    fdata->ext_size = vector_size(data->ext);

    fdata->lang = malloc(sizeof(char*) * fdata->lang_size);
    fdata->ext = malloc(sizeof(char*) * fdata->ext_size);
    fdata->ext2descr = malloc(sizeof(int) * fdata->ext_size);
    fdata->ext2group = malloc(sizeof(int) * fdata->ext_size);
    fdata->version = malloc(sizeof(char*) * fdata->descr_size);

    fdata->group = malloc(sizeof(char**) * fdata->lang_size);
    fdata->descr = malloc(sizeof(char**) * fdata->lang_size);

    for (i=0; i<fdata->lang_size; i++)
	{
	    fdata->group[i] = malloc(sizeof(char*) * fdata->group_size);
	    fdata->descr[i] = malloc(sizeof(char*) * fdata->descr_size);
	}

    for (i=0; i<fdata->lang_size; i++)
	fdata->lang[i] = strdup(vector_get(data->lang,i).ptr);

    for (i=0; i<fdata->ext_size; i++)
	{
	    struct fte_ext	*fext = vector_get(data->ext,i).ptr;

	    fdata->ext[i] = fext->ext;
	    fdata->ext2descr[i] = fext->descr;
	    fdata->ext2group[i] = fext->group;

	    free(fext);
	}

    for (i=0; i<fdata->descr_size; i++)
	{
	    char	*ptr = vector_get(data->version,i).ptr;
	    if (ptr!=NULL) fdata->version[i] = strdup(ptr);
	    else fdata->version[i] = NULL;
	}


    for (i=0; i<fdata->lang_size; i++)
	{
    	    for (j=0; j<data->group_size; j++)
		{
		    char	*ptr = vector_get(data->group[i],j).ptr;
		    if (ptr!=NULL) fdata->group[i][j] = strdup(ptr);
		    else fdata->group[i][j] = NULL;
		}

    	    for (j=0; j<data->descr_size; j++)
		{
		    char	*ptr = vector_get(data->descr[i],j).ptr;
		    if (ptr!=NULL)
			{
			    if (fdata->version[j] != NULL)
				{
				    char	buf[1024];
				    snprintf(buf, 1023, "%s %s", ptr, fdata->version[j]);
				    buf[1023] = '\0';
				    fdata->descr[i][j] = strdup(buf);
				}
			    else
				{
				    fdata->descr[i][j] = strdup(ptr);
				}
			}
		    else fdata->descr[i][j] = NULL;
		}
	}

    fdata->default_group = data->default_group;
    fdata->default_descr = data->default_descr;

    // Deallocate internal memory used:
    destroy(data->lang);
    destroy(data->ext);
    destroy(data->version);

    for (i=0; i<data->lang_size; i++)
	{
	    destroy(data->group[i]);
	    destroy(data->descr[i]);
	}

    free(data->group);
    free(data->descr);

    free(data);

    return fdata;
}

/*
struct fte_data
{
    int		lang_size, group_size, descr_size, ext_size;
    char	**lang, **ext, **version;
    int		*ext2descr, *ext2group;
    char	***group, ***descr;
};
*/
void fte_destroy(struct fte_data *fdata)
{
    int		i, j;

    for (i=0; i<fdata->lang_size; i++)
	free(fdata->lang[i]);

    for (i=0; i<fdata->descr_size; i++)
	free(fdata->version[i]);

    for (i=0; i<fdata->ext_size; i++)
	free(fdata->ext[i]);

    for (i=0; i<fdata->lang_size; i++)
	{
	    for (j=0; j<fdata->group_size; j++)
		free(fdata->group[i][j]);

	    for (j=0; j<fdata->descr_size; j++)
		free(fdata->descr[i][j]);

	    free(fdata->group[i]);
	    free(fdata->descr[i]);
	    free(fdata->default_group[i]);
	    free(fdata->default_descr[i]);
	}

    free(fdata->lang);
    free(fdata->version);
    free(fdata->ext);
    free(fdata->ext2descr);
    free(fdata->ext2group);
    free(fdata->descr);
    free(fdata->group);
    free(fdata->default_descr);
    free(fdata->default_group);
    free(fdata);
}


int fte_getdescription(struct fte_data *fdata, char *lang, char *ext, char **group, char **descr)
{
    int		lang_no = fte_find(fdata->lang, fdata->lang_size, lang);

    if (lang_no<0)
	{
	    fprintf(stderr, "getfiletype: Warning! Unknown language \"%s\". Using default language \"%s\" instead.\n", lang, fdata->lang[0]);
	    lang_no = 0;
	}

    int		ext_no = fte_find(fdata->ext, fdata->ext_size, ext);

    if (ext_no<0)
	{
	    if (fdata->default_group[lang_no] == NULL) *group = fdata->default_group[0];
	    else *group = fdata->default_group[lang_no];

	    if (fdata->default_descr[lang_no] == NULL) snprintf(fdata->_default_descr_array_, 32, "%s%s", ext, fdata->default_descr[0]);
	    else snprintf(fdata->_default_descr_array_, 32, "%s%s", ext, fdata->default_descr[lang_no]);

	    fdata->_default_descr_array_[31] = '\0';
	    *descr = fdata->_default_descr_array_;

	    int		ret=0, i;	// Simple hash:
	    for (i=0; ext[i]!='\0'; i++) ret+= ext[i]<<((i%3)*8 + (i/3));

	    return ret<<8;
	}

    int		ret;
    int		id;

    id = fdata->ext2group[ext_no];
    ret = (id+1);
    if (fdata->group[lang_no][id] == NULL) *group = fdata->group[0][id];
    else *group = fdata->group[lang_no][id];

    id = fdata->ext2descr[ext_no];
    ret+= (id+1)<<8;
    if (fdata->descr[lang_no][id] == NULL) *descr = fdata->descr[0][id];
    else *descr = fdata->descr[lang_no][id];

    return ret;
}


int fte_getextension(struct fte_data *fdata, char *lang, char *group, char ***ptr1, char ***ptr2)
{
    int		i, j;
    int		lang_no = fte_find(fdata->lang, fdata->lang_size, lang);

    if (lang_no<0)
	{
	    fprintf(stderr, "getfiletype: Warning! Unknown language \"%s\". Using default language \"%s\" instead.\n", lang, fdata->lang[0]);
	    lang_no = 0;
	}


    int		group_no = -1;

    for (i=0; i<fdata->group_size; i++)
	if (fdata->group[lang_no][i]==NULL)
	    {
		if (!strcmp(fdata->group[0][i], group))
		    {
			group_no = i;
			break;
		    }
	    }
	else
	    {
	        if (!strcmp(fdata->group[lang_no][i], group))
		    {
		        group_no = i;
			break;
		    }
	    }


    if (group_no<0) return 0;

    for (i=0; i<fdata->ext_size && (fdata->ext2group[i] != group_no); i++);

    *ptr1 = &(fdata->ext[i]);

    for (; i<fdata->ext_size && (fdata->ext2group[i] == group_no); i++);

    *ptr2 = &(fdata->ext[i]);

    return 1;
}



int fte_getext_from_ext(struct fte_data *fdata, char *ext, char ***ptr1, char ***ptr2)
{
    int		ext_no = fte_find(fdata->ext, fdata->ext_size, ext);

    if (ext_no<0) return 0;

    int		descr_no = fdata->ext2descr[ext_no];
    int		i;

    for (i=ext_no-1; i>=0 && (fdata->ext2descr[i] == descr_no); i--);

    *ptr1 = &(fdata->ext[i+1]);

    for (i=ext_no+1; i<fdata->ext_size && (fdata->ext2descr[i] == descr_no); i++);

    *ptr2 = &(fdata->ext[i]);

    return 1;
}





fteerror( struct fte_yacc_data *data, void *yyscan_t, char *s )
{
    fprintf(stderr, "getfiletype: Parse error! %s\n", s);
}
