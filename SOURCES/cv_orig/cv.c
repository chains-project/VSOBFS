/* $Header: cv.c,v 1.2 92/02/20 17:30:48 philip Exp $ */
/*
 * (c) copyright 1987 by the Vrije Universiteit, Amsterdam, The Netherlands.
 * See the copyright notice in the ACK home directory, in the file "Copyright".
 *
 */

/*
 * Convert ACK a.out file to Minix i86 or i386 object format.
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#if __STDC__
#include <stdarg.h>
#else
#include <varargs.h>
#endif

#include <out.h>

struct mnx_hdr {
	unsigned char	a_magic[2];
	unsigned char	a_flags;
	unsigned char	a_cpu;
	unsigned char	a_hdrlen;
	unsigned char	a_unused;
	unsigned short	a_version;
	long		a_text;
	long		a_data;
	long		a_bss;
	long		a_entry;
	long		a_total;
	long		a_syms;
};

struct nlist			/* PC/IX style */
{
	char	n_name[8];
	long	n_value; 
	char	n_sclass;
	char	n_numaux;
	unsigned short	n_type;
};

struct sym {			/* BSD style */
	long	name;
	char	type;
	char	other;
	short	desc;
	long	value;
};

#define N_UNDF	0
#define	N_ABS	02
#define	N_TEXT	04
#define	N_DATA	06
#define	N_BSS	010
#define	N_EXT	01
#define N_FN	0x1f

/*
 * Header and section table of new format object file.
 */
struct outhead	outhead;
struct outsect	outsect[S_MAX];

char	*output_file;
int	outputfile_created;
long magic;

char *program ;

char flag ;

/* Output file definitions and such */

struct mnx_hdr mnx_h;

#define HCLICK_SIZE	  0x10		/* 8086 basic segment size */
#define PAGE_SIZE	0x1000		/* 80386 page size */

#define TOT_HDRSIZE	(sizeof(struct mnx_hdr))

#define TEXTSG	0
#define ROMSG	1
#define DATASG	2
#define BSSSG	3
#define LSECT	BSSSG+1
#define NSECT	LSECT+1

int		output;

int unresolved;
long	textsize ; 
long	datasize ;
long	bsssize;

#if __STDC__
long align(long a, long b);
int follows(struct outsect *pa, struct outsect *pb);
void usage(void);
int main(int argc, char *argv[]);
void rd_fatal(void);
void fatal(char *s, ...);
void emits(struct outsect *section);
void pcix_emit_symtab(void);
void bsd_emit_symtab(void);
void cvlong(long *l);
void cvshort(short *s);
void writef(char *addr, int sz, long cnt);
int is_rest_local(struct outname *A, int i);
void put _ARGS(( long l, int sz ));
#endif

long align(a,b)
	long a,b;
{
	a += b - 1;
	return a - a % b;
}

int
follows(pa, pb)
	register struct outsect *pa, *pb;
{
	/* return 1 if pa follows pb */

	return pa->os_base == align(pb->os_base+pb->os_size, pa->os_lign);
}

void usage()
{
	fatal(
"Usage: %s [-u] [-x] [-m<arch>] [-S stack] <ACK object> <Minix object>\n",
		program);
}

int
main(argc, argv)
	int	argc;
	char	*argv[];
{
	register int		nsect;
	long text_off, entry, total;
	int cpu, pal, uzp, pcix_sym= 0;
	long stack= 32768L;
	int wordpow= 1;

	program= argv[0] ;
	cpu = sizeof(int) == 2 ? 0x04 : 0x10;
	while ( argc>1 && argv[1][0]=='-' ) {
		flag=argv[1][1] ;
		if (flag == 'u') unresolved++;
		if (flag == 'x') pcix_sym++;
		if (strcmp(argv[1], "-mi86") == 0) cpu = 0x04;
		if (strcmp(argv[1], "-mi386") == 0) cpu = 0x10;
		if (strcmp(argv[1], "-S") == 0) {
			char *p, *end;
			long num;
			int wp;

			argv++; argc--;
			if (argc < 1) usage();
			p= argv[1];
			if (*p == 0) usage();
			stack= strtol(p, &end, 0);
			wp= 0;
			if (end == p || stack < 0) usage();
			p= end;
			while (*p != 0) {
				switch (*p++) {
				case 'm':
				case 'M': num= 1024 * 1024L; break;
				case 'k':
				case 'K': num= 1024; break;
				case 'w':
				case 'W': num= 4; wp++; break;
				case 'b':
				case 'B': num= 1; break;
				default: usage();
				}
				if (stack > LONG_MAX / num) usage();
				stack*= num;
			}
			wordpow= 0;
			while (wp > 0) { stack /= 4; wordpow++; wp--; }
		}
		argc-- ; argv++ ;
	}
	switch (argc) {
	case 3:	output = open(argv[2], O_RDWR | O_CREAT | O_TRUNC, 0644);
		if (output < 0)
			fatal("Can't write %s.\n", argv[2]);
		output_file = argv[2];
		outputfile_created = 1;
		if (! rd_open(argv[1]))
			fatal("Can't read %s.\n", argv[1]);
		break;
	default:usage();
	}
	rd_ohead(&outhead);
	if (BADMAGIC(outhead))
		fatal("Not an ack object file.\n");
	if (outhead.oh_flags & HF_LINK)
		fatal("Contains unresolved references.\n");
	if (outhead.oh_nrelo > 0)
		fatal("Relocation information present.\n");
	if ( outhead.oh_nsect!=LSECT && outhead.oh_nsect!=NSECT )
		fatal("Input file must have %d sections, not %ld\n",
			NSECT,outhead.oh_nsect) ;
	rd_sect(outsect, outhead.oh_nsect);

	/* Determine the UZP and PAL flags. */
	entry= outsect[TEXTSG].os_base;
	text_off= entry & ~(long)(PAGE_SIZE-1);
	uzp= text_off > 0;
	pal= entry > text_off;

	/* A few checks */
	if ( pal && entry != text_off + sizeof(struct mnx_hdr) ) {
		fatal(
	"PAL displacement should equal the Minix header size, not %ld\n",
			entry - text_off);
	}
	if ( outsect[BSSSG].os_flen != 0 )
		fatal("bss space contains initialized data\n") ;
	if ( ! follows(&outsect[BSSSG], &outsect[DATASG]))
		fatal("bss segment must follow data segment\n") ;
	if (! follows(&outsect[DATASG], &outsect[ROMSG]))
		fatal("data segment must follow rom\n") ;
	outsect[ROMSG].os_size = outsect[DATASG].os_base - 
							outsect[ROMSG].os_base;
	outsect[DATASG].os_size = outsect[BSSSG].os_base -
							outsect[DATASG].os_base;
	
	mnx_h.a_magic[0]= 0x1;
	mnx_h.a_magic[1]= 0x3;
	mnx_h.a_flags= (uzp ? 0x01 : 0) | (pal ? 0x02 : 0);
	mnx_h.a_cpu= cpu;
	mnx_h.a_hdrlen= sizeof(mnx_h);
	mnx_h.a_unused= 0;
	mnx_h.a_version= 0;
	mnx_h.a_data= outsect[ROMSG].os_size + outsect[DATASG].os_size;
	mnx_h.a_bss=  outsect[BSSSG].os_size;
	mnx_h.a_entry= entry;

	while (wordpow > 0) {
		stack *= cpu == 0x04 ? 2 : 4;
		wordpow--;
	}

	total= outsect[ROMSG].os_size + outsect[DATASG].os_size +
		outsect[BSSSG].os_size + stack;

	if (outsect[ROMSG].os_base == text_off)
	{	/* separate I&D */
		mnx_h.a_flags |= 0x20;
		outsect[TEXTSG].os_size = mnx_h.a_text=
			align(outsect[TEXTSG].os_size, (long)HCLICK_SIZE);
	}
	else
	{
		outsect[TEXTSG].os_size = mnx_h.a_text =
			outsect[ROMSG].os_base - outsect[TEXTSG].os_base;
		if (! follows(&outsect[ROMSG], &outsect[TEXTSG]))
			fatal("rom segment must follow text\n") ;
		total += mnx_h.a_text;
	}
	if ( outhead.oh_nsect==NSECT ) 
	{
		if (! follows(&outsect[LSECT], &outsect[BSSSG]))
			fatal("end segment must follow bss\n") ;
		if ( outsect[LSECT].os_size != 0 )
			fatal("end segment must be empty\n") ;
	}

	if (cpu == 0x04 && total > 64 * 1024L) total= 64 * 1024L;
	mnx_h.a_total= total;

	/* Action at last */
	lseek(output,(long) sizeof(mnx_h),0);
	emits(&outsect[TEXTSG]) ;
	emits(&outsect[ROMSG]) ;
	emits(&outsect[DATASG]) ;
	if (pcix_sym) {
		pcix_emit_symtab();
		mnx_h.a_syms = outhead.oh_nname * sizeof(struct nlist);
	} else {
		bsd_emit_symtab();
		mnx_h.a_syms = outhead.oh_nname * sizeof(struct sym);
		if (mnx_h.a_syms != 0) mnx_h.a_flags |= 0x04;
	}
	lseek(output,0L,0);
	cvlong(&(mnx_h.a_text));
	cvlong(&(mnx_h.a_data));
	cvlong(&(mnx_h.a_bss));
	cvlong(&(mnx_h.a_entry));
	cvlong(&(mnx_h.a_total));
	cvlong(&(mnx_h.a_syms));
	writef((char *)&mnx_h, 1, (long) sizeof(mnx_h));
	if ( outputfile_created  ) chmod(argv[2],0755);
	return 0;
}

void
writef(addr,sz,cnt)
	char *addr;
	int sz;
	long cnt;
{
	cnt *= sz;

	while (cnt) {
		int i = cnt >= 0x4000 ? 0x4000 : cnt;

		cnt -= i;
		if (write(output, addr, i) < i) {
			fatal("write error\n");
		}
		addr += i;
	}
}

/*
 * Transfer the emitted byted from one file to another.
 */
void
emits(section) 
struct outsect *section ; 
{
	char		*p;
	long sz = section->os_flen;

	rd_outsect(section - outsect);
	while (sz) {
		unsigned int i = (sz >= 0x4000 ? 0x4000 : sz);
		if (!(p = malloc(i))) {
			fatal("No memory.\n");
		}
		rd_emit(p, i);
		if (write(output, p, i) < i) {
			fatal("write error.\n");
		}
		free(p);
		sz -= i;
	}

	sz = section->os_size - section->os_flen;
	if (sz) {
		if (!(p = calloc(0x4000, 1))) {
			fatal("No memory.\n");
		}
		while (sz) {
			unsigned int i = (sz >= 0x4000 ? 0x4000 : sz);
			if (write(output, p, i) < i) {
				fatal("write error.\n");
			}
			sz -= i;
		}
		free(p);
	}
}

struct outname *ACKnames;

#if 0
void
emit_relo()
{
	struct outrelo *ACKrelo;
	struct machrelo *MACHtrelo,*MACHdrelo;
	register struct outrelo *ap;
	register struct machrelo *mtp, *mdp;
	unsigned int cnt = outhead.oh_nrelo;

	ACKrelo = (struct outrelo *) calloc(cnt, sizeof(struct outrelo));
	MACHtrelo = (struct machrelo *) calloc(cnt, sizeof(struct machrelo));
	MACHdrelo = (struct machrelo *) calloc(cnt, sizeof(struct machrelo));
	ACKnames = (struct outname *) calloc(outhead.oh_nname, sizeof(struct outname));
	if (!(ap = ACKrelo) || !(mtp = MACHtrelo) || !(mdp = MACHdrelo) ||
	    !ACKnames) {
		fatal("No memory.\n");
	}
	rd_relo(ACKrelo, cnt);
	rd_name(ACKnames, outhead.oh_nname);
	while (cnt-- != 0) {
		register struct machrelo *mp;

		if (ap->or_sect - S_MIN <= ROMSG) mp = mtp++;
		else mp = mdp++;
		setlength(mp->relodata,(ap->or_type&RELSZ) >> 1);
		setpcrel(mp->relodata,(ap->or_type&RELPC != 0));
		mp->address = ap->or_addr;
		if (ap->or_sect == ROMSG+S_MIN) {
			mp->address += outsect[TEXTSG].os_size;
		}
		if (ap->or_nami < outhead.oh_nname) {
			if (ACKnames[ap->or_nami].on_type & S_EXT) {
				setsymbolnum(mp->relodata, ap->or_nami);
				setextern(mp->relodata,1);
			}
			else {
				patch(ap, &ACKnames[ap->or_nami], mp);
			}
		}
		else {
			setsymbolnum(mp->relodata, N_ABS);
		}
		cvlong(&(mp->address));
		cvlong(&(mp->relodata));
		ap++;
	}
	bh.rtsize = (char *) mtp - (char *) MACHtrelo;
	bh.rdsize = (char *) mdp - (char *) MACHdrelo;
	writef(MACHtrelo, 1, bh.rtsize);
	writef(MACHdrelo, 1, bh.rdsize);
	free(ACKrelo);
	free(MACHtrelo);
	free(MACHdrelo);
}

long
get(sz)
{
	char buf[10];
	long l = 0;
	register char *p = buf;

	read(output,buf,sz);
	while (sz--) {
		l = (l << 8) | (*p++ & 0377);
	}
	return l;
}
#endif

void
put(l,sz)
	long l;
	int sz;
{
	char buf[10];
	register char *p = buf;

	*p++ = l;
	*p++ = l >> 8;
	*p++ = l >> 16;
	*p++ = l >> 24;
	p -= sz;
	if (write(output, p, sz) < sz) {
		fatal("write error.\n");
	}
}

#if 0
patch(ap, an, mp)
	register struct outrelo *ap;
	register struct outname *an;
	register struct machrelo *mp;
{
	int whichsect = (an->on_type & S_TYP) - S_MIN;
	long correction = 0;
	long where = TOT_HDRSIZE+ap->or_addr;
	long X;
	long here;
	int sz;

	if (!(an->on_type & S_SCT)) {
		fprintf(stderr,"funny on_type %x\n", an->on_type);
	}
	switch(whichsect) {
	case TEXTSG:
		setsymbolnum(mp->relodata,N_TEXT);
		return;
	case DATASG:
		correction = outsect[ROMSG].os_size + outsect[TEXTSG].os_size;
		setsymbolnum(mp->relodata,N_DATA);
		break;
	case ROMSG:
		correction = outsect[TEXTSG].os_size;
		setsymbolnum(mp->relodata,N_TEXT);
		break;
	case BSSSG:
		correction = outsect[ROMSG].os_size + outsect[TEXTSG].os_size+
				outsect[DATASG].os_size;
		setsymbolnum(mp->relodata,N_BSS);
		break;
	default:
		assert(0);
	}

	switch(ap->or_sect - S_MIN) {
	case DATASG:
		where += outsect[ROMSG].os_size;
	case ROMSG:
		where += outsect[TEXTSG].os_size;
	case TEXTSG:
		break;
	default:
		assert(0);
	}
	here = lseek(output, 0L, 1);
	lseek(output, where, 0);
	sz = ap->or_type & RELSZ;
	X = get(sz) + correction;
	lseek(output, where, 0);
	put(X,sz);
	lseek(output, here, 0);
}
#endif

void
cvlong(l)
	long *l;
{
	long x = *l;
	char *p = (char *) l;

	*p++ = x;
	*p++ = x >> 8;
	*p++ = x >> 16;
	*p++ = x >> 24;
}

void
cvshort(s)
	short *s;
{
	short x = *s;
	char *p = (char *) s;

	*p++ = x;
	*p++ = x >> 8;
}

int
is_rest_local(A, i)
	register struct outname *A;
	register int i;
{
	while (i--) {
		if (A->on_type & S_EXT) return 0;
		A++;
	}
	return 1;
}

void
pcix_emit_symtab()
{
	struct outname ACK_name;  /* symbol table entry in ACK format */
	struct nlist IX_name;	  /* symbol table entry in PC/IX format */
	register unsigned short i;

	long l;
	long off = OFF_CHAR(outhead);
	int j;
	char *p, *chars;

	if (outhead.oh_nname == 0) return;	/* no symbol table to emit */

	if (((unsigned) outhead.oh_nchar != outhead.oh_nchar) ||
	     (outhead.oh_nchar != 0 &&
	      (chars = malloc((unsigned)outhead.oh_nchar)) == 0)) {
		fatal("No memory.\n");
	}

	rd_string(chars,outhead.oh_nchar);
	for (i = 0; i < outhead.oh_nname; i++) {
		rd_name(&ACK_name, 1);
		switch(ACK_name.on_type & S_TYP) {
			case S_UND:
				IX_name.n_sclass = 0;
				break;
			case S_ABS:
				IX_name.n_sclass = 01;
				break;
			case S_MIN + TEXTSG:
				IX_name.n_sclass = 02; 
				break;
			case S_MIN + ROMSG:
			case S_MIN + DATASG:
				IX_name.n_sclass = 03;
				break;
			case S_MIN + BSSSG:
			case S_MIN + LSECT:
				IX_name.n_sclass = 04;
				break;
			default:
				fprintf(stderr,"warning: unknown s_type: %d\n",
					ACK_name.on_type & S_TYP);
		}
		if (ACK_name.on_type & S_EXT) IX_name.n_sclass |= 020;
		IX_name.n_value = ACK_name.on_valu;
		if (ACK_name.on_foff == 0) {
			p = "\0\0";
		}
		else {
			l = ACK_name.on_foff - off;
			if (l < 0 || l >= outhead.oh_nchar) {
				fatal("bad on_off: %ld\n",l);
			}
			p = &chars[l];
		}
		for (j = 0; j < 8; j++) {
			IX_name.n_name[j] = *p++;
			if (*p == '\0') break;
		}
		for (j++; j < 8; j++) {
			IX_name.n_name[j] = 0;
		}
		cvlong((long *) &IX_name.n_value);
		cvshort((short *) &IX_name.n_type);
		writef((char *) &IX_name, 1, (long) sizeof(IX_name));
	}
}

void
bsd_emit_symtab()
{
	register unsigned short i = outhead.oh_nname;
	register struct outname *A;
	struct sym *MACHnames;
	register struct sym *M;
	char *chars;
	long offX = OFF_CHAR(outhead) - 4;

	if (i == 0) return;	/* no symbol table to emit */

	if (!(A = ACKnames)) {
	    	if (!(A = (struct outname *)
			calloc(i, sizeof(struct outname)))) {
			fatal("No memory.\n");
		}
		rd_name(A, outhead.oh_nname);
	}
	if (!(M = (struct sym *) calloc(i, sizeof(struct sym)))) {
		fatal("No memory.\n");
	}
	MACHnames = M;
	ACKnames = A;
	for (; i; i--, A++) {
		M->value = A->on_valu;
		M->desc = A->on_desc;
		if ((A->on_type & S_SCT) ||
		    (A->on_type & S_ETC) == S_FIL) {
			static int rest_local;
			if (! unresolved || rest_local || (rest_local = is_rest_local(A, i))) {
				outhead.oh_nname--;
				continue;
			}
		}
		if (A->on_type & S_STB) {
			M->type = A->on_type >> 8;
		}
		else if (A->on_type & S_COM) {
			M->type = N_UNDF | N_EXT;
		}
		else switch(A->on_type & S_TYP) {
			case S_UND:
				switch(A->on_type & S_ETC) {
				default:
					M->type = N_UNDF;
					break;
				case S_MOD:
					M->type = N_FN;
					break;
				case S_LIN:
					M->type = N_ABS;
					break;
				}
				break;
			case S_ABS:
				M->type = N_ABS;
				break;
			case S_MIN + TEXTSG:
				M->type = N_TEXT; 
				break;
			case S_MIN + ROMSG:
				if (unresolved) {
					M->value += outsect[TEXTSG].os_size;
				}
				M->type = N_DATA;
				break;
			case S_MIN + DATASG:
				if (unresolved) {
					M->value += outsect[TEXTSG].os_size +
						    outsect[ROMSG].os_size;
				}
				M->type = N_DATA;
				break;
			case S_MIN + BSSSG:
				if (unresolved) {
					M->value += outsect[TEXTSG].os_size +
						    outsect[ROMSG].os_size +
						    outsect[DATASG].os_size;
				}
				M->type = N_BSS;
				break;
			case S_MIN + LSECT:
				M->type = N_BSS;
				break;
			default:
				fprintf(stderr,"warning: unknown s_type: %d\n",
					A->on_type & S_TYP);
		}
		if (A->on_type & S_EXT) M->type |= N_EXT;
		M->name = A->on_foff;
		M++;
	}
	M = MACHnames;
	for (i = outhead.oh_nname; i; i--, M++) {
		if (M->name) {
			M->name -= offX;
		}
		else M->name = outhead.oh_nchar + 3;	/* pointer to nullbyte */
		cvlong(&(M->name));
		cvlong(&(M->value));
		cvshort(&(M->desc));
	}
	writef((char *)MACHnames, sizeof(struct sym), (long) outhead.oh_nname);
	free(MACHnames);
	free(ACKnames);
	if ((unsigned) outhead.oh_nchar != outhead.oh_nchar ||
	    !( chars = malloc((unsigned) outhead.oh_nchar))) {
		fatal("No memory\n.");
	}
	put(outhead.oh_nchar+4,4);
	rd_string(chars,outhead.oh_nchar);
	writef(chars, 1, outhead.oh_nchar);
	free(chars);
}

/* VARARGS1 */
#if __STDC__
void
fatal(char *s, ...)
#else
void
fatal(s, va_alist)
	char	*s;
	va_dcl
#endif
{
	va_list ap;

#if __STDC__
	va_start(ap, s);
#else
	va_start(ap);
#endif
	fprintf(stderr,"%s: ",program) ;
	vfprintf(stderr, s, ap);
	va_end(ap);
	if (outputfile_created)
		unlink(output_file);
	exit(-1);
}

void
rd_fatal() { fatal("read error.\n"); }
