#include <Python.h>

#ifndef MODULE_NAME
#error "MODULE_NAME must name the Python extension without the PyInit_ prefix"
#endif

#define CONCAT_IMPL(a, b) a##b
#define CONCAT(a, b) CONCAT_IMPL(a, b)

PyMODINIT_FUNC CONCAT(Wrapped_PyInit_, MODULE_NAME)(void);

PyMODINIT_FUNC CONCAT(PyInit_, MODULE_NAME)(void) {
  return CONCAT(Wrapped_PyInit_, MODULE_NAME)();
}
