
/**
 *	(C) Copyleft 2006, Magnus Gal�en
 *
 *	dcontainer.h: Basic containers.
 *
 *	Dette er under utvikling.
 */

#ifndef _DCONTAINER_H_
#define _DCONTAINER_H_


#include <stdarg.h>

typedef union
{
    int		i;
    char	c;
    double	d;
    void	*ptr;
} value;

typedef struct alloc_data
{
    value	v;
    va_list	ap;
} alloc_data;

typedef struct container container;

struct container
{
    int		(*compare)( container *C, value a, value b );
    alloc_data	(*ap_allocate)( container *C, va_list ap );
    void	(*deallocate)( container *C, value a );
    void	(*destroy)( container *C );
    void	*priv;
};


/* fancy allocate: */

int compare( container *C, value a, value b );

value allocate( container *C, ... );

void deallocate( container *C, value v );

void destroy( container *C );


/* int_container: */

container* int_container();

/* string_container: */

container* string_container();

/* custom_container: */

//container* custom_container(int obj_size, int(*compare)(container*, value, value));

#endif	// _DCONTAINER_H_
