PROG=   initwrapper
CFLAGS= -g -W -Wall
CC = gcc

all: $(PROG)

#$(PROG): ../common/exeoc.c
$(PROG): initwrapper.c ../common/exeoc.c
	$(CC) $(CFLAGS) -o $(PROG) $< ../common/exeoc.c
	#chown root $(PROG)
	#chmod +s $(PROG)

clean:
	rm -f $(PROG)
