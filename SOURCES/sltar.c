/* sltar - suckless tar
 *
 * (c) 2012 Enno Boland <g s01 de>
 *
 * This modified version has received substantial changes
 * by other developers, for bug fixes, functionality, portability
 * and to generate reproducible archives: it does not descend into
 * directories and assigns all objects to superuser, with mtime 0.
 *
MIT/X Consortium License

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
 */
#define VERSION "0.3.1-repro"

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
/* #include <limits.h> */

#define MIN(a, b) (((a)<(b))?(a):(b))

#ifndef major
#define major(x) (((x)>>8)&0xff)
#endif
#ifndef minor
#define minor(x) ((x)&0xff)
#endif
#ifndef makedev
#define makedev(M,m) (((M)<<8)|((m)&0xff))
#endif

enum Header {
        NAME=0, MODE = 100, UID = 108, GID = 116, SIZE = 124, MTIME = 136, CHKSUM=148,
        TYPE = 156, LINK = 157, MAGIC=257, VERS=263, UNAME=265, GNAME=297, MAJ = 329,
        MIN = 337, END = 512
};

enum Type {
        REG = '0', HARDLINK = '1', SYMLINK = '2', CHARDEV='3', BLOCKDEV='4',
        DIRECTORY='5', FIFO='6'
};

int archive(const char* path){
        mode_t mode;
        unsigned sum, x;
        int l;
        char b[END];
        FILE *f = NULL;
        struct stat s, *st = &s;
        lstat(path, st);
        memset(b, 0, END);
        snprintf(b+NAME, 100, "%s", path);
        snprintf(b+MODE, 8, "%.7o", (unsigned)st->st_mode&0777);
        snprintf(b+UID,  8, "%.7o", (unsigned)0);
        snprintf(b+GID,  8, "%.7o", (unsigned)0);
        snprintf(b+SIZE, 12, "%.11o", 0);
        snprintf(b+MTIME,12, "%.11o", (unsigned)0);
        memcpy(b+MAGIC, "ustar", strlen("ustar")+1);
        memcpy(b+VERS, "00", strlen("00"));
        snprintf(b+UNAME, 32, "%s", "root");
        snprintf(b+GNAME, 32, "%s", "root");
        mode = st->st_mode;
        if(S_ISREG(mode)){
                b[TYPE] = REG;
                snprintf(b+SIZE, 12, "%.11o", (unsigned)st->st_size);
                f = fopen(path, "r");
                if(!f){
                  perror(path);
                  return EXIT_FAILURE;
                }
        }else if(S_ISDIR(mode)){
                b[TYPE] = DIRECTORY;
        }else if(S_ISLNK(mode)){
                b[TYPE] = SYMLINK;
                readlink(path, b+LINK, 99);
        }else if(S_ISCHR(mode)){
                b[TYPE] = CHARDEV;
                snprintf(b+MAJ,  8, "%.7o", (unsigned)major(st->st_dev));
                snprintf(b+MIN,  8, "%.7o", (unsigned)minor(st->st_dev));
        }else if(S_ISBLK(mode)){
                b[TYPE] = BLOCKDEV;
                snprintf(b+MAJ,  8, "%.7o", (unsigned)major(st->st_dev));
                snprintf(b+MIN,  8, "%.7o", (unsigned)minor(st->st_dev));
        }else if(S_ISFIFO(mode)){
                b[TYPE] = FIFO;
        }
        sum=0;
        memset(b+CHKSUM, ' ', 8);
        for(x=0; x<END; x++)
                sum+=b[x];
        snprintf(b+CHKSUM, 8, "%.7o", sum);
        fwrite(b, END, 1, stdout);
        if(f){
          while((l = fread(b, 1, END, f))>0){
                if(l<END)
                        memset(b+l, 0, END-l);
                fwrite(b, END, 1, stdout);
          }
          fclose(f);
        }
        return EXIT_SUCCESS;
}

int unarchive(char *fname, int l, char b[END]){
        static char lname[101] = {0};
        FILE *f = NULL;
        memcpy(lname, b+LINK, 100);

        unlink(fname);
        switch(b[TYPE]) {
        case REG:
                if(!(f = fopen(fname,"w")) || chmod(fname,strtoul(b + MODE,0,8)))
                        perror(fname);
                break;
        case HARDLINK:
                if(link(lname,fname))
                        perror(fname);
                break;
        case SYMLINK:
                if(symlink(lname,fname))
                        perror(fname);
                break;
        case DIRECTORY:
                if(mkdir(fname,(mode_t) strtoul(b + MODE,0,8)))
                        perror(fname);
                break;
        case CHARDEV:
        case BLOCKDEV:
                if(mknod(fname, (b[TYPE] == '3' ? S_IFCHR : S_IFBLK) | strtoul(b + MODE,0,8),
                                makedev(strtoul(b + MAJ,0,8),
                                        strtoul(b + MIN,0,8))))
                        perror(fname);
                break;
        case FIFO:
                if(mknod(fname, S_IFIFO | strtoul(b + MODE,0,8), 0))
                        perror(fname);
                break;
        default:
                fprintf(stderr,"not supported filetype %c\n",b[TYPE]);
        }
        if(getuid() == 0 && chown(fname, strtoul(b + UID,0,8),strtoul(b + GID,0,8)))
                perror(fname);

        for(;l>0; l-=END){
                fread(b, END, 1, stdin);
                if(f)
                        fwrite(b, MIN(l, 512), 1, f);
        }
        if(f)
                fclose(f);
        return EXIT_SUCCESS;
}

int print(char * fname, int l, char b[END]){
        puts(fname);
        for(;l>0; l-=END)
                fread(b, END, 1, stdin);
        return 0;
}

int xt(int (*fn)(char*, int, char[END])) {
        int l;
        char b[END],fname[101];
        fname[100] = '\0';

        while(fread(b, END, 1, stdin)){
                if(*b == '\0')
                        break;
                memcpy(fname, b, 100);
                l = strtol(b+SIZE, 0, 8);
                fn(fname, l, b);
        }
        return EXIT_SUCCESS;
}

void usage(void){
        fputs("sltar-" VERSION " - suckless tar for reproducible archives\nsltar {{t|x} <archive | c ... >archive}\n",stderr);
        exit(EXIT_FAILURE);
}

int main(int argc, char *argv[]) {
        if(argc < 2 || strlen(argv[1])!=1)
                usage();
        if(argv[1][0] == 'c') { int status = EXIT_SUCCESS;
                argv += 2;
                --argc;
                while (--argc && (status=archive(*argv++)) == EXIT_SUCCESS) ;
                return status;
        }
        if(argc != 2 )
                usage();
        switch(argv[1][0]) {
        case 'x':
                return xt(unarchive);
        case 't':
                return xt(print);
        default:
                usage();
        }
        return EXIT_FAILURE;
}
