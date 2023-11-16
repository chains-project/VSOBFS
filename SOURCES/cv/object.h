/* $Header: object.h,v 1.7 91/01/18 09:54:23 ceriel Exp $ */
/*
 * (c) copyright 1987 by the Vrije Universiteit, Amsterdam, The Netherlands.
 * See the copyright notice in the ACK home directory, in the file "Copyright".
 */
#include <stdio.h>

#define Xchar(ch)	((ch) & 0xff)

#define uget2(c)	((Xchar((c)[0]) | (Xchar((c)[1]) << 8)) & 0xffff)
#define get4(c)		((uget2(c) | ((i32_t) uget2((c)+2) << 16)) & 0xffffffff)

#define Xput2(i, c)	(((c)[0] = (i)), ((c)[1] = (i) >> 8))

/* avoiding multiple evaluations of the first argument: */
#define put2(i, c)	do { int j = (i); Xput2(j, c); } while(0)
#define put4(l, c)	do { i32_t x=(l); \
			     Xput2((int)x,c); \
			     Xput2((int)(x>>16),(c)+2); \
			} while(0)

#define SECTCNT	3	/* number of sections with own output buffer */
#define WBUFSIZ	BUFSIZ

struct fil {
	int	cnt;
	char	*pnow;
	char	*pbegin;
	i32_t	currpos;
	int	fd;
	char	pbuf[WBUFSIZ];
};

extern struct fil __parts[];

#define	PARTEMIT	0
#define	PARTRELO	(PARTEMIT+SECTCNT)
#define	PARTNAME	(PARTRELO+1)
#define	PARTCHAR	(PARTNAME+1)
#ifdef SYMDBUG
#define PARTDBUG	(PARTCHAR+1)
#else
#define PARTDBUG	(PARTCHAR+0)
#endif
#define	NPARTS		(PARTDBUG + 1)

#define getsect(s)      (PARTEMIT+((s)>=(SECTCNT-1)?(SECTCNT-1):(s)))
