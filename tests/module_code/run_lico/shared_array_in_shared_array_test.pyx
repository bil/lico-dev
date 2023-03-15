# __DRIVER_CODE__ imports
import time

import SharedArray as sa

# __DRIVER_CODE__ variables


# __DRIVER_CODE__ setup

sleep_func = getattr(np.random, "normal")
sleep_kwargs = {'loc': 0.001, 'scale': 0.00025}
sig_name = "test_sa_in"
sa_sig = sa.attach(sig_name)
sa_index = 0

# __DRIVER_CODE__ read

  inBuf[0] = sa_sig[sa_index]
  sa_index += 1
  if sa_index >= sa_sig.size:
    sa_index = 0
  sleep_duration = sleep_func(**sleep_kwargs)
  if sleep_duration < 0:
    sleep_duration = 0
  time.sleep(sleep_duration)