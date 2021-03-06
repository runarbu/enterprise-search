#include <sys/types.h>

#include <stdio.h>
#include <string.h>
#include <zlib.h>
#include <ctype.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <unistd.h>
#include <dirent.h>

#include "../common/lot.h"
#include "../common/define.h"
#include "../common/stdlib.h"
#include "../common/bstr.h"
#include "../common/boithohome.h"
#include "../common/ht.h"


#include "../3pLibs/keyValueHash/hashtable.h"
#include "../3pLibs/keyValueHash/hashtable_itr.h"

#include "set.h"
#include "acl.h"

typedef struct {
	int hits;
	set acl_allow;
	set acl_denied;
	set collections;
} dictcontent_t;

static unsigned int fileshashfromkey(void *ky)
{
	char *p = ky;
	unsigned int hash = 5381;
	int c;

	while (c = *p++)
		hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

	return hash;
}

static int filesequalkeys(void *k1, void *k2)
{
    char *c1, *c2;

    c1 = k1;
    c2 = k2;

    return (strcmp(c1, c2) == 0);
}
void
dolot(unsigned int lotNr, char *subname, struct hashtable *h, struct hashtable *aclshash)
{
	FILE *FH;
	char line[64*1024];
	char word[maxWordlLen +1];
	char *filesKey;
	unsigned int nr;


	if ((FH = lotOpenFileNoCasheByLotNr(lotNr,"dictionarywords_raw","r",'r',subname)) == NULL)
		return;
	while(fgets(line, sizeof(line), FH) != NULL) {
		char acl_allow[DICT_ACL_LENGTH], acl_denied[DICT_ACL_LENGTH];
		dictcontent_t *dc;


		chomp(line);
		//printf("line \"%s\"\n",line);

		if (!dictionarywordLineSplit(line, word, &nr, acl_allow, acl_denied)) {
			printf("Error: %s\n", line);
			continue;
		}

		//printf("word \"%s\", nr %u\n",word,nr);

		if ((dc = hashtable_search(h, word)) == NULL) {
                        filesKey = strdup(word);
			dc = malloc(sizeof(*dc));
			dc->hits = nr;
			set_init(&dc->acl_allow);
			set_init(&dc->acl_denied);
			set_init(&dc->collections);
			add_acls(acl_allow, &dc->acl_allow, aclshash);
			add_acls(acl_denied, &dc->acl_denied, aclshash);
			add_acls(subname, &dc->collections, aclshash);

                        if (!hashtable_insert(h, filesKey, dc)) {
                        	printf("cant insert\n");
                                exit(-1);
                        }

                }
                else {
			add_acls(acl_allow, &dc->acl_allow, aclshash);
			add_acls(acl_denied, &dc->acl_denied, aclshash);
			add_acls(subname, &dc->collections, aclshash);
			dc->hits += nr;
                }
	}

	fclose(FH);
}

int main (int argc, char *argv[]) {
	FILE *resultFH;
	char *filesKey;
	struct hashtable *h;
	struct hashtable_itr *itr;
	int all = 0;
	struct hashtable *aclshash;


	if (argc >= 2 && strcmp(argv[1], "all") == 0) {
		all = 1;
	} else if (argc != 3) {
		printf("usage: dictionarywordsLot lotnr subname\n");
		printf("usage: dictionarywordsLot all\n");
		exit(1);
	}

	h = create_hashtable(200, fileshashfromkey, filesequalkeys);
	aclshash = create_hashtable(101, ht_stringhash, ht_stringcmp);
	if (all == 0) {
		unsigned int lotNr = atou(argv[1]);
		char *subname = argv[2];

		dolot(lotNr, subname, h, aclshash);
	} else {
		char pathname[PATH_MAX];
		FILE *map;
		char *line;
		size_t linelen;

		if ((map = fopen(bfile("config/maplist.conf"), "r")) == NULL)
			err(1, "fopen(maplist)");

		line = NULL;
		while (getline(&line, &linelen, map) > 0) {
			DIR *d2;
			struct dirent *de2;

			line[strlen(line)-1] = '\0';
			strcpy(pathname, line);
			if ((d2 = opendir(pathname)) == NULL) {
				warn("opendir(%s)", pathname);
				free(line);
				line = NULL;
				continue;
			}

			while ((de2 = readdir(d2))) {
				DIR *d3;
				struct dirent *de3;

				if (de2->d_name[0] == '.' || !isdigit(de2->d_name[0])) 
					continue;

				sprintf(pathname, "%s/%s", line, de2->d_name);

				if ((d3 = opendir(pathname)) == NULL) {
					warn("opendir(%s)", pathname);
					continue;
				}

				while ((de3 = readdir(d3))) {
					FILE *tmpfh;

					if (de3->d_name[0] == '.')
						continue;

					sprintf(pathname, "%s/%s/%s/dictionarywords_raw",
					    line, de2->d_name, de3->d_name);
					printf("found dictionary: %s\n", pathname);
					/* XXX: Use stat(2) instead? */
					if ((tmpfh = fopen(pathname, "r")) != NULL) {
						fclose(tmpfh);
						dolot(atoi(de2->d_name), de3->d_name, h, aclshash);
					}
				}
				closedir(d3);
			}
			closedir(d2);
			free(line);
			line = NULL;
		}
		fclose(map);
	}

	//resultFH = lotOpenFileNoCasheByLotNr(lotNr,"dictionarywords","w",'r',subname);
	resultFH = fopen(bfile("var/dictionarywords"), "w");
	if (resultFH == NULL)
		err(1, "fopen()");

	if (hashtable_count(h) > 0) {
		printf("Writing %d words.\n", hashtable_count(h));
                itr = hashtable_iterator(h);
               	do {
			char *p;
			int i;

			dictcontent_t *dc;
                	filesKey = hashtable_iterator_key(itr);
                        dc = hashtable_iterator_value(itr);

                        //printf("\"%s\": %i\n",filesKey,dc->hits);
			fprintf(resultFH,"%s %u ",filesKey,dc->hits);
			//printf("acl allow:\n");
			SET_FOREACH(i, &dc->acl_allow, p) {
				if (i > 0)
					fprintf(resultFH, ",");
				fprintf(resultFH, "%s", p);
				//printf("Got soemthing here: %s\n", p);
				//printf("\t%s\n", p);
			}
			fprintf(resultFH, " ");
			//printf("acl denied:\n");
			SET_FOREACH(i, &dc->acl_denied, p) {
				if (i > 0)
					fprintf(resultFH, ",");
				fprintf(resultFH, "%s", p);
				//printf("\t%s\n", p);
			}

			fprintf(resultFH, " ");
			//printf("acl denied:\n");
			SET_FOREACH(i, &dc->collections, p) {
				if (i > 0)
					fprintf(resultFH, ",");
				fprintf(resultFH, "%s", p);
				//printf("\t%s\n", p);
			}
			fprintf(resultFH, "\n");
			//set_free_all(&dc->acl_allow);
			//set_free_all(&dc->acl_denied);
                } while (hashtable_iterator_advance(itr));
                free(itr);
	}

	hashtable_destroy(h,1);

	fclose(resultFH);

	return 0;
}

