CC = gcc
DEFAULTFLAGS = -Wall 
CFLAGS = -O2 $(DEFAULTFLAGS)
CFLAGSUNOPT = -O0 $(DEFAULTFLAGS)
CFLAGS+ = -g -O2 $(DEFAULTFLAGS)
CYFLAGS = -Os -I /Users/sabard/.pyenv/versions/3.8.12/include/python3.8 -I /Users/sabard/.pyenv/versions/3.8.12/envs/licorice/lib/python3.8/site-packages/numpy/core/include
LDFLAGS = -levent -pthread -lsqlite3 
LDTESTFLAGS = -lsqlite3 -pthread
CYLDFLAGS = -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/readline/lib -L/Users/sabard/.pyenv/versions/3.8.12/lib  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib -lsqlite3  -lpython3.8 -lintl -ldl -framework CoreFoundation  # -lpthread -lm -lutil -ldl should be included in py_link_flags

all: timer shared_array_out shared_array_out_async_writer shared_array_out_shared_array_test signal_generator 

timer: timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c
	$(CC) $(CFLAGS) timer.c utilityFunctions.c darwin_compat/clock_nanosleep.c -o timer $(LDFLAGS)


shared_array_out:  shared_array_out.pyx utilityFunctions.c sqlite3async.c sqlHelpers.c  #networkUtilities.c
	cython --embed -3 -o shared_array_out.c shared_array_out.pyx
	$(CC) $(CYFLAGS) -Wno-cpp shared_array_out.c utilityFunctions.c sqlite3async.c sqlHelpers.c  -o shared_array_out $(CYLDFLAGS)

shared_array_out_async_writer:  shared_array_out_async_writer.pyx utilityFunctions.c sqlite3async.c sqlHelpers.c  #networkUtilities.c
	cython --embed -3 -o shared_array_out_async_writer.c shared_array_out_async_writer.pyx
	$(CC) $(CYFLAGS) -Wno-cpp shared_array_out_async_writer.c utilityFunctions.c sqlite3async.c sqlHelpers.c  -o shared_array_out_async_writer $(CYLDFLAGS)

shared_array_out_shared_array_test: sink_drivers/shared_array_out_shared_array_test.pyx sqlite3async.c sqlHelpers.c 
	cython --embed -3 -o sink_drivers/shared_array_out_shared_array_test.c sink_drivers/shared_array_out_shared_array_test.pyx
	$(CC) $(CYFLAGS) -Wno-cpp sink_drivers/shared_array_out_shared_array_test.c utilityFunctions.c sqlite3async.c sqlHelpers.c  -o sink_drivers/shared_array_out_shared_array_test $(CYLDFLAGS)

signal_generator: signal_generator.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o signal_generator.c signal_generator.pyx
	$(CC) $(CYFLAGS) -Wno-cpp signal_generator.c  utilityFunctions.c -o signal_generator $(CYLDFLAGS) #networkUtilities.c
clean:
	rm -f timer shared_array_out signal_generator 

clean:
	rm -f timer shared_array_out shared_array_out_shared_array_test  signal_generator 