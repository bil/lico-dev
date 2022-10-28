CC = gcc
DEFAULTFLAGS = -Wall 
CFLAGS = -O2 $(DEFAULTFLAGS)
CFLAGSUNOPT = -O0 $(DEFAULTFLAGS)
CFLAGS+ = -g -O2 $(DEFAULTFLAGS)
CYFLAGS = -Os -I /Users/sabard/.pyenv/versions/3.8.12/include/python3.8 -I /Users/sabard/.pyenv/versions/3.8.12/envs/licorice/lib/python3.8/site-packages/numpy/core/include
LDFLAGS = -levent -pthread -lsqlite3 
LDTESTFLAGS = -lsqlite3 -pthread
CYLDFLAGS = -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -lsqlite3  -lpython3.8 -lintl -ldl -framework CoreFoundation  # -lpthread -lm -lutil -ldl should be included in py_link_flags

all: timer matmul_init matmul matmul_print 

timer: timer.c utilityFunctions.c 
	$(CC) $(CFLAGS) timer.c utilityFunctions.c -o timer $(LDFLAGS)


matmul_init: matmul_init.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o matmul_init.c matmul_init.pyx
	$(CC) $(CYFLAGS) -Wno-cpp matmul_init.c  utilityFunctions.c -o matmul_init $(CYLDFLAGS) #networkUtilities.c

matmul: matmul.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o matmul.c matmul.pyx
	$(CC) $(CYFLAGS) -Wno-cpp matmul.c  utilityFunctions.c -o matmul $(CYLDFLAGS) #networkUtilities.c

matmul_print: matmul_print.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o matmul_print.c matmul_print.pyx
	$(CC) $(CYFLAGS) -Wno-cpp matmul_print.c  utilityFunctions.c -o matmul_print $(CYLDFLAGS) #networkUtilities.c
clean:
	rm -f timer matmul_init matmul matmul_print 

clean:
	rm -f timer  matmul_init matmul matmul_print 