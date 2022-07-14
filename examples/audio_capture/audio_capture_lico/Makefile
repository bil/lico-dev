CC = gcc
DEFAULTFLAGS = -Wall 
CFLAGS = -O2 $(DEFAULTFLAGS)
CFLAGSUNOPT = -O0 $(DEFAULTFLAGS)
CFLAGS+ = -g -O2 $(DEFAULTFLAGS)
CYFLAGS = -Os -I /home/sabar/.pyenv/versions/3.8.12/include/python3.8 -I /home/sabar/.pyenv/versions/3.8.12/envs/licorice/lib/python3.8/site-packages/numpy/core/include
LDFLAGS = -levent -pthread -lsqlite3 -lrt
LDTESTFLAGS = -lsqlite3 -pthread
CYLDFLAGS = -L/home/sabar/.pyenv/versions/3.8.12/lib -Wl,-rpath=/home/sabar/.pyenv/versions/3.8.12/lib -L/home/sabar/.pyenv/versions/3.8.12/lib -Wl,-rpath=/home/sabar/.pyenv/versions/3.8.12/lib -lsqlite3 -lasound -L/home/sabar/.pyenv/versions/3.8.12/lib -lpython3.8 -lcrypt -lpthread -ldl  -lutil -lm -lm -lrt # -lpthread -lm -lutil -ldl should be included in py_link_flags

all: timer audio_in audio_in_line audio_out audio_out_line   audio_process 

timer: timer.c utilityFunctions.c 
	$(CC) $(CFLAGS) timer.c utilityFunctions.c -o timer $(LDFLAGS)

audio_in: audio_in.pyx sourceUtils.c utilityFunctions.c lineUtilities.c
	cython --embed -3 -o audio_in.c audio_in.pyx
	$(CC) $(CYFLAGS) -Wno-cpp audio_in.c sourceUtils.c utilityFunctions.c lineUtilities.c -o audio_in $(CYLDFLAGS) # remove not a line source

audio_in_line: source_drivers/audio_in_line.pyx sourceUtils.c utilityFunctions.c lineUtilities.c
# 	cython --embed -3 -o source_drivers/audio_in_line.c source_drivers/audio_in_line.pyx
	$(CC) $(CYFLAGS) -Wno-cpp source_drivers/audio_in_line.c sourceUtils.c utilityFunctions.c lineUtilities.c -o source_drivers/audio_in_line $(CYLDFLAGS)

audio_out:  audio_out.pyx utilityFunctions.c sqlite3async.c sqlHelpers.c lineUtilities.c #networkUtilities.c
	cython --embed -3 -o audio_out.c audio_out.pyx
	$(CC) $(CYFLAGS) -Wno-cpp audio_out.c utilityFunctions.c sqlite3async.c sqlHelpers.c lineUtilities.c -o audio_out $(CYLDFLAGS)

audio_out_line: sink_drivers/audio_out_line.pyx sqlite3async.c sqlHelpers.c lineUtilities.c
# 	cython --embed -3 -o sink_drivers/audio_out_line.c sink_drivers/audio_out_line.pyx
	$(CC) $(CYFLAGS) -Wno-cpp sink_drivers/audio_out_line.c utilityFunctions.c sqlite3async.c sqlHelpers.c lineUtilities.c -o sink_drivers/audio_out_line $(CYLDFLAGS)

audio_process: audio_process.pyx utilityFunctions.c #networkUtilities.c
	cython --embed -3 -o audio_process.c audio_process.pyx
	$(CC) $(CYFLAGS) -Wno-cpp audio_process.c  utilityFunctions.c -o audio_process $(CYLDFLAGS) #networkUtilities.c
clean:
	rm -f timer audio_in audio_out audio_process 
