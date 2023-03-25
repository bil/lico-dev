# __DRIVER_CODE__ imports
import time

import SharedArray as sa

# __DRIVER_CODE__ variables


# __DRIVER_CODE__ setup


sig_name = "test_sa_in"
sa_sig = sa.attach(sig_name)
sa_index = 0

# __DRIVER_CODE__ read

  inBuf[0] = sa_sig[sa_index]
  sa_index += 1
  if sa_index >= sa_sig.size:
    sa_index = 0
