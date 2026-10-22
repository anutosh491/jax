#include <Python.h>

PyMODINIT_FUNC Wrapped_PyInit__hlo(void);

PyMODINIT_FUNC PyInit__hlo(void) { return Wrapped_PyInit__hlo(); }
