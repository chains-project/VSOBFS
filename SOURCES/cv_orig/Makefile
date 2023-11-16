# Makefile for ACK cv - the program that converts ACK executables for Minix.

STD_CFLAGS=	-D_MINIX -D_POSIX_SOURCE -I. $(OPT) -wo
VMD_CFLAGS=	-D_MINIX -I. $(OPT) -fnone -wo

SRC =	cv.c rd.c rd_bytes.c

all install:
	@case `uname` in \
	Minix-vmd)	$(MAKE) -$(MAKEFLAGS) vmd_$@ ;; \
	Minix)		$(MAKE) -$(MAKEFLAGS) std_$@ ;; \
	*)		echo "Don't know how to make cv for `uname`" >&2 ;; \
	esac

std_all:	std_cv
vmd_all:	vmd_cv

std_cv:	$(SRC)
	$(CC) $(STD_CFLAGS) -o $@ $(SRC)

vmd_cv:	$(SRC)
	$(CC) $(VMD_CFLAGS) -o $@ $(SRC)

std_install:	/usr/lib/cv

/usr/lib/cv:	std_cv
	install -cs -m 555 $? $@

vmd_install:	/usr/lib/ack/cv

/usr/lib/ack/cv:	vmd_cv
	install -c -m 555 $? $@

clean:
	rm -rf $(OBJ) ???_cv core
