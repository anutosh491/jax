#include <Python.h>

PyMODINIT_FUNC Wrapped_PyInit__jax(void);

PyMODINIT_FUNC PyInit__jax(void) { return Wrapped_PyInit__jax(); }
