#ifdef WITH_CONFIG


#include <mysql.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <pthread.h>

#include "define.h"
#include "config.h"
#include "debug.h"


struct _configdataFormat *_configdata = NULL;
int _configdatanr = 0;
time_t lastConfigRead = 0;

/* M� ha lock b�de da mysql bibloteket ikke er trs�kert, og for � hindre at vi flusher configen mens en annen tr�d leser fra den */
#ifdef WITH_THREAD
pthread_mutex_t config_lock = PTHREAD_MUTEX_INITIALIZER;
#endif

//int bconfig_init(int mode) {
int
bconfig_flush(int mode) {
	time_t now = time(NULL);

	//sjekker om vi har den alerede
	if ((lastConfigRead != 0) && (mode == CONFIG_CACHE_IS_OK) && ((lastConfigRead + cache_time) > now)) {
		debug("have config in cache. Won't query db again\n");
		return 0;
	}

#ifdef WITH_THREAD
	pthread_mutex_lock(&config_lock);
#endif
	//bb har confg i mysql
#ifdef BLACK_BOKS

	//selecter fra db
	char mysql_query[5][2048];
        static MYSQL demo_db;
	int i, j;	

        MYSQL_RES *mysqlres; /* To be used to fetch information into */
        MYSQL_ROW mysqlrow;

#ifdef WITH_THREAD
	my_init();

	#ifdef DEBUG
	if (mysql_thread_safe() == 0) {
		fprintf(stderr, "The MYSQL client isn't compiled as thread safe! And will probably crash.\n");
	}
	#endif

#else
#endif

	if (mysql_init(&demo_db) == NULL) {
		fprintf(stderr, "Unable to connect to mysqld\n");
		goto _free_and_return_error;
	}

        if(!mysql_real_connect(&demo_db, "localhost", "boitho", "G7J7v5L5Y7", BOITHO_MYSQL_DB, 3306, NULL, 0)){
                printf(mysql_error(&demo_db));
		goto _free_and_return_error;
        }

	char ad_select_tpl[] = "SELECT '%s' AS configkey, systemParamValue.value AS configvalue \
		FROM system, systemParamValue \
		WHERE systemParamValue.param = \"%s\" \
		AND system.is_primary = 1 \
		AND system.id = systemParamValue.system";
	char selectbfr[512];
	sprintf(mysql_query[0], "SELECT configkey, configvalue FROM config");
	sprintf(mysql_query[1], "SELECT param AS configkey, value AS configvalue FROM system, systemParamValue WHERE system.is_primary = 1 AND system.id = systemParamValue.system");


	i=0;
	_configdatanr = 0;
	for (j = 0; j < 2; j++) {

		if (mysql_real_query(&demo_db, mysql_query[j], strlen(mysql_query[j]))){ /* Execute query */
			printf(mysql_error(&demo_db));
			goto _free_and_return_error;
		}

		mysqlres=mysql_store_result(&demo_db); /* Download result from server */

		_configdatanr += (int)mysql_num_rows(mysqlres);
		debug("nrofrows %i\n",_configdatanr);

		if ((_configdata = realloc(_configdata, sizeof(struct _configdataFormat) * _configdatanr)) == NULL) {
			perror("Malloc _configdata");
			exit(-1);
		}

		while ((mysqlrow=mysql_fetch_row(mysqlres)) != NULL) { /* Get a row from the results */
			debug("\tconfig %s => \"%s\"",mysqlrow[0],mysqlrow[1]);
			strcpy(_configdata[i].configkey,mysqlrow[0]);
			strcpy(_configdata[i].configvalue,mysqlrow[1]);
			++i;
		}


		mysql_free_result(mysqlres);
	}
	mysql_close(&demo_db);
#endif

	lastConfigRead = now;

#ifdef WITH_THREAD
	pthread_mutex_unlock(&config_lock);
#endif
	return 1;

//firgj�r lock og returnerer feil.
_free_and_return_error:
#ifdef WITH_THREAD
	pthread_mutex_unlock(&config_lock);
#endif
	return 0;

}


const char *bconfig_getentrystr(char vantkey[]) {

	int i;
	char *ret = NULL;
	#ifdef WITH_THREAD
	        pthread_mutex_lock(&config_lock);
	#endif

	if (_configdata == NULL) {
		fprintf(stderr, "bconfig_getentrystr: _configdata is NULL! You MOST run bconfig_init first.\n");
		exit(-1);
	}

	for(i=0;i<_configdatanr;i++) {
		//printf("config %s: %s\n",_configdata[i].configkey,_configdata[i].configvalue);

		if (strcmp(vantkey,_configdata[i].configkey) == 0) {
			ret = _configdata[i].configvalue;
		}

	}

	#ifdef WITH_THREAD
		pthread_mutex_unlock(&config_lock);
	#endif

	return ret;
}

int bconfig_getentryint(char vantkey[], int *val) {
	const char *cp;

	if ((cp = bconfig_getentrystr(vantkey)) == NULL) {
		return 0;
	}
	else {
		*val = atoi(cp);
		return 1;
	}


}
int bconfig_getentryuint(char vantkey[], unsigned int *val) {
	const char *cp;

	if ((cp = bconfig_getentrystr(vantkey)) == NULL) {
		return 0;
	}
	else {
		*val = atou(cp);
		return 1;
	}


}
#endif

