/* Generated by Cython 0.29.28 */

#ifndef __PYX_HAVE__audio_capture_lico__audio_process
#define __PYX_HAVE__audio_capture_lico__audio_process

#include "Python.h"

#ifndef __PYX_HAVE_API__audio_capture_lico__audio_process

#ifndef __PYX_EXTERN_C
  #ifdef __cplusplus
    #define __PYX_EXTERN_C extern "C"
  #else
    #define __PYX_EXTERN_C extern
  #endif
#endif

#ifndef DL_IMPORT
  #define DL_IMPORT(_T) _T
#endif

__PYX_EXTERN_C sigset_t exitMask;

#endif /* !__PYX_HAVE_API__audio_capture_lico__audio_process */

/* WARNING: the interface of the module init function changed in CPython 3.5. */
/* It now returns a PyModuleDef instance instead of a PyModule instance. */

#if PY_MAJOR_VERSION < 3
PyMODINIT_FUNC initaudio_process(void);
#else
PyMODINIT_FUNC PyInit_audio_process(void);
#endif

#endif /* !__PYX_HAVE__audio_capture_lico__audio_process */
