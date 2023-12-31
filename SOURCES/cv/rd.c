/* $Header: rd.c,v 1.7 91/01/18 09:54:34 ceriel Exp $ */
/*
 * (c) copyright 1987 by the Vrije Universiteit, Amsterdam, The Netherlands.
 * See the copyright notice in the ACK home directory, in the file "Copyright".
 */

#include <sys/types.h>
#include <unistd.h>

#include "out.h"
#include "object.h"

/*
 * Parts of the output file.
 */
#undef PARTEMIT
#undef PARTRELO
#undef PARTNAME
#undef PARTCHAR
#undef PARTDBUG
#undef NPARTS

#define	PARTEMIT	0
#define	PARTRELO	1
#define	PARTNAME	2
#define	PARTCHAR	3
#ifdef SYMDBUG
#define PARTDBUG	4
#else
#define PARTDBUG	3
#endif
#define	NPARTS		(PARTDBUG + 1)

static off_t		offset[MAXSECT];

static int		outfile;
static off_t		outseek[NPARTS];
static off_t		currpos;
static off_t		rd_base;
#define OUTSECT(i) \
	(outseek[PARTEMIT] = offset[i])
#define BEGINSEEK(p, o) \
	(outseek[(p)] = (o))

static int sectionnr;

static
OUTREAD(p, b, n)
	char *b;
	i32_t n;
{
	register off_t l = outseek[p];

	if (currpos != l) {
		lseek(outfile, l, 0);
	}
	rd_bytes(outfile, b, n);
	l += n;
	currpos = l;
	outseek[p] = l;
}

/*
 * Open the output file according to the chosen strategy.
 */
int
rd_open(f)
	char *f;
{

	if ((outfile = open(f, 0)) < 0)
		return 0;
	return rd_fdopen(outfile);
}

static int offcnt;

rd_fdopen(fd)
{
	register int i;

	for (i = 0; i < NPARTS; i++) outseek[i] = 0;
	offcnt = 0;
	rd_base = lseek(fd, (off_t)0, 1);
	if (rd_base < 0) {
		return 0;
	}
	currpos = rd_base;
	outseek[PARTEMIT] = currpos;
	outfile = fd;
	sectionnr = 0;
	return 1;
}

rd_close()
{

	close(outfile);
	outfile = -1;
}

rd_fd()
{
	return outfile;
}

rd_ohead(head)
	register struct outhead	*head;
{
	register i32_t off;

	OUTREAD(PARTEMIT, (char *) head, (i32_t) SZ_HEAD);
	{
		register char *c = (char *) head + (SZ_HEAD-4);
		
		head->oh_nchar = get4(c);
		c -= 4; head->oh_nemit = get4(c);
		c -= 2; head->oh_nname = uget2(c);
		c -= 2; head->oh_nrelo = uget2(c);
		c -= 2; head->oh_nsect = uget2(c);
		c -= 2; head->oh_flags = uget2(c);
		c -= 2; head->oh_stamp = uget2(c);
		c -= 2; head->oh_magic = uget2(c);
	}
	off = OFF_RELO(*head) + rd_base;
	BEGINSEEK(PARTRELO, off);
	off += (i32_t) head->oh_nrelo * SZ_RELO;
	BEGINSEEK(PARTNAME, off);
	off += (i32_t) head->oh_nname * SZ_NAME;
	BEGINSEEK(PARTCHAR, off);
#ifdef SYMDBUG
	off += head->oh_nchar;
	BEGINSEEK(PARTDBUG, off);
#endif
}

rd_rew_relos(head)
	register struct outhead *head;
{
	register i32_t off = OFF_RELO(*head) + rd_base;

	BEGINSEEK(PARTRELO, off);
}

rd_sect(sect, cnt)
	register struct outsect	*sect;
	register unsigned int	cnt;
{
	register char *c = (char *) sect + cnt * SZ_SECT;

	OUTREAD(PARTEMIT, (char *) sect, (i32_t)cnt * SZ_SECT);
	sect += cnt;
	offcnt += cnt;
	while (cnt--) {
		sect--;
		{
			c -= 4; sect->os_lign = get4(c);
			c -= 4; sect->os_flen = get4(c);
			c -= 4; sect->os_foff = get4(c);
		}
		offset[--offcnt] = sect->os_foff + rd_base;
		{
			c -= 4; sect->os_size = get4(c);
			c -= 4; sect->os_base = get4(c);
		}
	}
}

rd_outsect(s)
{
	OUTSECT(s);
	sectionnr = s;
}

/*
 * We don't have to worry about byte order here.
 */
rd_emit(emit, cnt)
	char		*emit;
	i32_t		cnt;
{
	OUTREAD(PARTEMIT, emit, cnt);
	offset[sectionnr] += cnt;
}

rd_relo(relo, cnt)
	register struct outrelo	*relo;
	register unsigned int cnt;
{

	OUTREAD(PARTRELO, (char *) relo, (i32_t) cnt * SZ_RELO);
	{
		register char *c = (char *) relo + (i32_t) cnt * SZ_RELO;

		relo += cnt;
		while (cnt--) {
			relo--;
			c -= 4; relo->or_addr = get4(c);
			c -= 2; relo->or_nami = uget2(c);
			relo->or_sect = *--c;
			relo->or_type = *--c;
		}
	}
}

rd_name(name, cnt)
	register struct outname	*name;
	register unsigned int cnt;
{

	OUTREAD(PARTNAME, (char *) name, (i32_t) cnt * SZ_NAME);
	{
		register char *c = (char *) name + (i32_t) cnt * SZ_NAME;

		name += cnt;
		while (cnt--) {
			name--;
			c -= 4; name->on_valu = get4(c);
			c -= 2; name->on_desc = uget2(c);
			c -= 2; name->on_type = uget2(c);
			c -= 4; name->on_foff = get4(c);
		}
	}
}

rd_string(addr, len)
	char *addr;
	i32_t len;
{
	
	OUTREAD(PARTCHAR, addr, len);
}

#ifdef SYMDBUG
rd_dbug(buf, size)
	char		*buf;
	i32_t		size;
{
	OUTREAD(PARTDBUG, buf, size);
}
#endif
