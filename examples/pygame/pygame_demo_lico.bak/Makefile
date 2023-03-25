CC = gcc
DEFAULTFLAGS = -Wall 
CFLAGS = -O2 $(DEFAULTFLAGS)
CFLAGSUNOPT = -O0 $(DEFAULTFLAGS)
CFLAGS+ = -g -O2 $(DEFAULTFLAGS)
CYFLAGS = -Os -I /Users/sabard/.pyenv/versions/3.8.12/include/python3.8 -I /Users/sabard/.pyenv/versions/3.8.12/envs/licorice/lib/python3.8/site-packages/numpy/core/include
LDFLAGS = -levent -pthread -lsqlite3 
LDTESTFLAGS = -lsqlite3 -pthread
CYLDFLAGS = -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -lsqlite3  -lpython3.8 -lintl -ldl -framework CoreFoundation  # -lpthread -lm -lutil -ldl should be included in py_link_flags

all: timer drivers pygame_demo  #drivers

timer: timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c
	$(CC) $(CFLAGS) timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c -o timer $(LDFLAGS)

pygame_demo:  pygame_demo.pyx utilityFunctions.c sqlite3async.c sqlHelpers.c  #networkUtilities.c
	cython --embed -3 -o pygame_demo.c pygame_demo.pyx
	$(CC) $(CYFLAGS) -Wno-cpp pygame_demo.c utilityFunctions.c sqlite3async.c sqlHelpers.c  -o pygame_demo $(CYLDFLAGS)

drivers:
	python setup_drivers.py build_ext --inplace

clean:
	rm -f timer pygame_demo vis_pygame  