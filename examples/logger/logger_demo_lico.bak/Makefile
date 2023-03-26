CC = gcc
DEFAULTFLAGS = -Wall 
CFLAGS = -O2 $(DEFAULTFLAGS)
CFLAGSUNOPT = -O0 $(DEFAULTFLAGS)
CYFLAGS = -Os -I /Users/sabard/.pyenv/versions/3.8.12/include/python3.8 -I /Users/sabard/.pyenv/versions/3.8.12/envs/licorice/lib/python3.8/site-packages/numpy/core/include -I sink_drivers/disk
LDFLAGS = -levent -pthread -lsqlite3 
LDTESTFLAGS = -lsqlite3 -pthread
CYLDFLAGS = -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -lsqlite3  -lpython3.8 -lintl -ldl -framework CoreFoundation  # -lpthread -lm -lutil -ldl should be included in py_link_flags

all: timer drivers logger logger_async_writer logger_sigout  #drivers

timer: timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c
	$(CC) $(CFLAGS) timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c -o timer $(LDFLAGS)

logger:  logger.pyx utilityFunctions.c  #networkUtilities.c
	cython --embed -3 -o logger.c logger.pyx
	$(CC) $(CYFLAGS) -Wno-cpp logger.c utilityFunctions.c  -o logger $(CYLDFLAGS)

logger_async_writer:  logger_async_writer.pyx utilityFunctions.c  #networkUtilities.c
	cython --embed -3 -o logger_async_writer.c logger_async_writer.pyx
	$(CC) $(CYFLAGS) -Wno-cpp logger_async_writer.c utilityFunctions.c   -o logger_async_writer $(CYLDFLAGS)

drivers:
	python setup_drivers.py build_ext --inplace

logger_sigout: logger_sigout.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o logger_sigout.c logger_sigout.pyx
	$(CC) $(CYFLAGS) -Wno-cpp logger_sigout.c  utilityFunctions.c -o logger_sigout $(CYLDFLAGS) #networkUtilities.c
clean:
	rm -f timer logger logger_async_writer disk  logger_sigout 