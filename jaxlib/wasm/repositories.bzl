"""Target headers and the installed Emscripten compiler for cross-compilation."""

load("@emsdk//:emscripten_build_file.bzl", "EMSCRIPTEN_BUILD_FILE_CONTENT_TEMPLATE")

def _headers_impl(ctx):
    directory = ctx.os.environ.get(ctx.attr.environment)
    if not directory:
        fail("Set {} to the target header directory".format(ctx.attr.environment))
    ctx.symlink(directory, "include")
    ctx.file("BUILD.bazel", """
cc_library(
    name = "headers",
    hdrs = glob(["include/**/*.h"]),
    includes = ["include"],
    visibility = ["//visibility:public"],
)
""")

wasm_headers = repository_rule(
    implementation = _headers_impl,
    attrs = {"environment": attr.string(mandatory = True)},
    environ = ["JAX_WASM_PYTHON_INCLUDE", "JAX_WASM_NUMPY_INCLUDE"],
)

def _emscripten_impl(ctx):
    directory = ctx.os.environ.get("JAX_WASM_EMSDK")
    if not directory:
        fail("Set JAX_WASM_EMSDK to the installed Emscripten upstream directory")
    for name in ["bin", "lib", "emscripten"]:
        ctx.symlink(ctx.path(directory).get_child(name), name)
    ctx.file("BUILD.bazel", EMSCRIPTEN_BUILD_FILE_CONTENT_TEMPLATE.format(bin_extension = ""))

installed_emscripten = repository_rule(
    implementation = _emscripten_impl,
    environ = ["JAX_WASM_EMSDK"],
)

def _installed_llvm_impl(ctx):
    directory = ctx.os.environ.get("JAX_WASM_LLVM_REPOSITORY")
    if not directory:
        fail("Set JAX_WASM_LLVM_REPOSITORY to the configured installed LLVM 23.1.2 repository")
    for entry in ctx.path(directory).readdir():
        if entry.basename not in ["WORKSPACE.bazel", "MODULE.bazel"]:
            ctx.symlink(entry, entry.basename)

installed_llvm = repository_rule(
    implementation = _installed_llvm_impl,
    environ = ["JAX_WASM_LLVM_REPOSITORY"],
)
