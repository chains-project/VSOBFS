/* mkproto - make an mkfs prototype	Author: Andrew Cagney */
/* cagney@chook.ua.oz (Andrew Cagney - aka Noid) */

/* modified 2023 by an to create reproducible proto files */

#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>

/* The default values for the prototype file */
#define DEF_UID		2	/* bin */
#define DEF_GID		1	/* daemon group */
#define DEF_PROT	0555	/* a=re */
#define DEF_BLOCKS	360
#define DEF_INODES	63
#define DEF_INDENTSTR	"\t"

#define major(x) ( (x>>8) & 0377)
#define minor(x) (x & 0377)

/* Globals. */
int origlen, tabs;
int gid, uid, prot, same_uid, same_gid, same_prot, blocks, inodes;
int block_given, inode_given, dprot;
char *indentstr;
char *proto_file, *top;
FILE *outfile;

extern int optind;
extern char *optarg;

_PROTOTYPE(int main, (int argc, char **argv));
_PROTOTYPE(void descend, (char *dirname));
_PROTOTYPE(void display_attrib, (char *name, struct stat *st));
_PROTOTYPE(void usage, (char *binname));
_PROTOTYPE(void open_outfile, (void));

int main(argc, argv)
int argc;
char *argv[];
{
  char *dir;
  struct stat st;
  int op;

  gid = DEF_GID;
  uid = DEF_UID;
  prot = DEF_PROT;
  blocks = DEF_BLOCKS;
  inodes = DEF_INODES;
  indentstr = DEF_INDENTSTR;
  inode_given = 0;
  block_given = 0;
  top = 0;
  same_uid = 0;
  same_gid = 0;
  same_prot = 0;
  while ((op = getopt(argc, argv, "b:g:i:p:t:u:d:s")) != EOF) {
	switch (op) {
	    case 'b':
		blocks = atoi(optarg);
		block_given = 1;
		break;
	    case 'g':
		gid = atoi(optarg);
		if (gid == 0) usage(argv[0]);
		same_gid = 0;
		break;
	    case 'i':
		inodes = atoi(optarg);
		inode_given = 1;
		break;
	    case 'p':
		sscanf(optarg, "%o", &prot);
		if (prot == 0) usage(argv[0]);
		same_prot = 0;
		break;
	    case 's':
		same_prot = 1;
		same_uid = 1;
		same_gid = 1;
		break;
	    case 't':	top = optarg;	break;
	    case 'u':
		uid = atoi(optarg);
		if (uid == 0) usage(argv[0]);
		same_uid = 0;
		break;
	    case 'd':	indentstr = optarg;	break;
	    default:		/* Illegal options */
		usage(argv[0]);
	}
  }

  if (optind >= argc) {
	usage(argv[0]);
  } else {
	dir = argv[optind];
	optind++;
	proto_file = argv[optind];
  }
  if (!top) top = dir;
  open_outfile();
  if (block_given && !inode_given) inodes = (blocks / 3) + 8;
  if (!block_given && inode_given) usage(argv[0]);
  tabs = 0;
  origlen = strlen(dir);

  /* Check that it really is a directory */
  stat(dir, &st);
  if ((st.st_mode & S_IFMT) != S_IFDIR) {
	fprintf(stderr, "mkproto: %s must be a directory\n", dir);
	usage(argv[0]);
  }
  fprintf(outfile, "boot\n%d %d\n", blocks, inodes);
  display_attrib("", &st);
  fprintf(outfile, "\n");
  descend(dir);
  fprintf(outfile, "$\n");
  return(0);
}

int sortcmp(s1, s2)
void *s1; void *s2;
{
  return strcmp(*(char **)s1, *(char **)s2);
}


/* Output the prototype spec for this directory. */
void descend(dirname)
char *dirname;
{
  struct dirent *dp;
  DIR *dirp;
  char *name, *temp, *tempend;
  int i;
  struct stat st;
  mode_t mode;

  char **names; /* the pointer to an array of entry names */
  int nnames;   /* the number of names */
  int namenum;  /* index among the names */

  dirp = opendir(dirname);
  if (dirp == NULL) {
	fprintf(stderr, "unable to open directory %s\n", dirname);
	return;
  }
  names = 0;
  nnames = 0;

  for (dp = readdir(dirp); dp != NULL; dp = readdir(dirp)) {
    ++nnames;
    names = (char**)realloc(names, sizeof(char*) * nnames); /* inefficient but simple */
    names[nnames-1] = (char *)malloc(sizeof(char) * strlen(dp->d_name) +1);
    strcpy(names[nnames-1], dp->d_name);
  }
  closedir(dirp);
  qsort(names, nnames, sizeof(char *), sortcmp);
  /* now we have got a sorted contents of the directory */

  tabs++;
  temp = (char *) malloc(sizeof(char) * strlen(dirname) +1 + PATH_MAX);
  strcpy(temp, dirname);
  strcat(temp, "/");
  tempend = &temp[strlen(temp)];

  for (namenum = 0; namenum < nnames; ++namenum) {
	name = names[namenum];

	if (name[0] == '.' && (name[1] == 0 ||
	    (name[1] == '.' && name[2] == 0)))
		continue;

	strcpy(tempend, name);

	if (stat(temp, &st) == -1) {
		fprintf(stderr, "cant get status of '%s' \n", temp);
		free(name);
		continue;
	}

	display_attrib(name, &st);
	free(name);

	mode = st.st_mode & S_IFMT;
	if (mode == S_IFDIR) {
		fprintf(outfile, "\n");
		descend(temp);
		for (i = 0; i < tabs; i++) {
			fprintf(outfile, "%s", indentstr);
		}
		fprintf(outfile, "$\n");
		continue;
	}
	if (mode == S_IFBLK || mode == S_IFCHR) {
		fprintf(outfile, " %d %d\n", major(st.st_rdev), minor(st.st_rdev));
		continue;
	}
	if (mode == S_IFREG) {
		i = origlen;
		fprintf(outfile, "%s%s", indentstr, top);
		while (temp[i] != '\0') {
			fputc(temp[i], outfile);
			i++;
		}
		fprintf(outfile, "\n");
		continue;
	}
	fprintf(outfile, " /dev/null\n");
	fprintf(stderr,"File\n\t%s\n has an invalid mode, made empty.\n",temp);
  }
  free(names);
  free(temp);
  tabs--;
}


void display_attrib(name, st)
char *name;
struct stat *st;
{
/* Output the specification for a single file */

  int i;

  if (same_uid) uid = st->st_uid;
  if (same_gid) gid = st->st_gid;
  if (same_prot)
	prot = st->st_mode & 0777;	/***** This one is a bit shady *****/
  for (i = 0; i < tabs; i++) fprintf(outfile, "%s", indentstr);
  fprintf(outfile, "%s%s%c%c%c%3o %d %d",
	name,
	*name == '\0' ? "" : indentstr,	/* stop the tab for a null name */
	(st->st_mode & S_IFMT) == S_IFDIR ? 'd' :
	(st->st_mode & S_IFMT) == S_IFCHR ? 'c' :
	(st->st_mode & S_IFMT) == S_IFBLK ? 'b' :
	'-',			/* file type */
	(st->st_mode & S_ISUID) ? 'u' : '-',	/* set uid */
	(st->st_mode & S_ISGID) ? 'g' : '-',	/* set gid */
	prot,
	uid,
	gid);
}

void usage(binname)
char *binname;
{
  fprintf(stderr, "Usage: %s [options] source_directory [prototype_file]\n", binname);
  fprintf(stderr, "options:\n");
  fprintf(stderr, "   -b n\t\t file system size is n blocks (default %d)\n", DEF_BLOCKS);
  fprintf(stderr, "   -d STRING\t define the indentation characters (default %s)\n", "(none)");
  fprintf(stderr, "   -g n\t\t use n as the gid on all files (default %d)\n", DEF_GID);
  fprintf(stderr, "   -i n\t\t file system gets n i-nodes (default %d)\n", DEF_INODES);
  fprintf(stderr, "   -p nnn\t use nnn (octal) as mode on all files (default %o)\n", DEF_PROT);
  fprintf(stderr, "   -s  \t\t use the same uid, gid and mode as originals have\n");
  fprintf(stderr, "   -t ROOT\t inital path prefix for each entry\n");
  fprintf(stderr, "   -u n\t\t use nnn as the uid on all files (default %d)\n", DEF_UID);
  exit(1);
}

void open_outfile()
{
  if (proto_file == NULL)
	outfile = stdout;
  else if ((outfile = fopen(proto_file, "w")) == NULL)
	fprintf(stderr, "Cannot create %s\n ", proto_file);
}
