# __DRIVER_CODE__ imports
import time

# __DRIVER_CODE__ variables


# __DRIVER_CODE__ setup

sleep_func = getattr(np.random, "normal")
sleep_kwargs = {'loc': 0.001, 'scale': 0.00025}
sig_name = "test_sa_out"
sa_sig = sa.attach(sig_name)
sa_index = 0

# __DRIVER_CODE__ write
  if uint64_signalLen == 0:
    continue
  for i in range (uint64_signalLen):
    sa_sig[sa_index] = <uint64_t>outBuf[0+i]
    sa_index += 1
    if sa_index >= sa_sig.size:
      sa_index = 0
  sleep_duration = sleep_func(**sleep_kwargs)
  if sleep_duration < 0:
    sleep_duration = 0
  time.sleep(sleep_duration)

# __DRIVER_CODE__ exit_handler