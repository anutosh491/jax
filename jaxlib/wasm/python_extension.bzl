load("@emsdk//emscripten_toolchain:wasm_rules.bzl", "wasm_cc_binary")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")


def wasm_python_extension(name, module_name, implementation, wrapped=True):
    """Links one native-style JAX pywrap implementation as a Wasm side module."""
    cc_library(
        name = name + "_impl",
        srcs = ["python_extension_stub.c"] if wrapped else [],
        copts = [
            "-DMODULE_NAME=" + module_name,
            "-fwasm-exceptions",
        ],
        deps = [
            implementation,
            "@emscripten_python_headers//:headers",
        ],
    )

    cc_binary(
        name = name + "_side_module",
        deps = [name + "_impl"],
        linkopts = [
            "-fwasm-exceptions",
            "-shared",
            "--oformat=wasm",
            "-Wl,-Bsymbolic",
            "-Wl,--export=PyInit_" + module_name,
        ],
    )

    wasm_cc_binary(
        name = name + "-wasm",
        cc_target = name + "_side_module",
        threads = "off",
    )


def wasm_python_facade(name, module_name):
    """Builds a tiny extension facade resolved by the global JAX runtime."""
    cc_library(
        name = name + "_impl",
        srcs = ["python_extension_stub.c"],
        copts = [
            "-DMODULE_NAME=" + module_name,
            "-fwasm-exceptions",
        ],
        deps = ["@emscripten_python_headers//:headers"],
    )

    cc_binary(
        name = name + "_side_module",
        deps = [name + "_impl"],
        linkopts = [
            "-fwasm-exceptions",
            "-shared",
            "--oformat=wasm",
            "-Wl,--export=PyInit_" + module_name,
        ],
    )

    wasm_cc_binary(
        name = name + "-wasm",
        cc_target = name + "_side_module",
        threads = "off",
    )
