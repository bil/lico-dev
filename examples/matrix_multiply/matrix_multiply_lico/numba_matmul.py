import numba.pycc
import numpy as np

cc = numba.pycc.CC('numba_matmul')

# create function signatures for overloaded inputs/ouputs of different types
@cc.export('numba_matmul', 'i8(f8[:,:],f8[:,:],f8[:,:])')
def numba_matmul(m1,m2,matmul_out):  
  matmul_out[:, :] = np.dot(m1, m2)[:, :]
  # the [:,:] notation must be used or Python will create a new matmul_out
  # variable instead of copying the data into the array mapped by matmul_out
  

  return 1


if __name__ == "__main__":
  cc.compile()