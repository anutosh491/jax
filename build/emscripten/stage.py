"""Assemble wheel sources using JAX's existing setuptools metadata."""

import argparse
from pathlib import Path
import re
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("component", choices=("jax", "jaxlib"))
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--bazel-out", type=Path)
    parser.add_argument("--xla", type=Path)
    parser.add_argument("--arch", choices=("wasm32", "wasm64"))
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2]
    output = args.destination.resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError(f"Use an empty staging directory: {output}")

    def copy(original, relative):
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)

    if args.component == "jax":
        output.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source / "jax", output / "jax", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__"))
        for name in ("setup.py", "pyproject.toml", "README.md", "LICENSE", "AUTHORS"):
            if (source / name).exists():
                copy(source / name, name)
        version_file = output / "jax/version.py"
    else:
        if not args.bazel_out or not args.xla or not args.arch:
            parser.error("jaxlib requires --bazel-out, --xla and --arch")
        extensions = {
            "jax-extension-wasm/jax_extension_side_module.wasm": "jaxlib/_jax.so",
            "xla-extension-wasm/xla_extension_side_module.wasm": "jaxlib/_xla.so",
            "hlo-extension-wasm/hlo_extension_side_module.wasm": "jaxlib/_hlo.so",
        }
        for name, module, directory in [
            ("ifrt-proxy", "_ifrt_proxy", "jaxlib"),
            ("cpu-feature-guard", "cpu_feature_guard", "jaxlib"),
            ("lapack", "_lapack", "jaxlib/cpu"),
            ("sparse", "_sparse", "jaxlib/cpu"),
            ("utils", "utils", "jaxlib"),
            ("weakref-lru-cache", "weakref_lru_cache", "jaxlib"),
            ("pretty-printer", "_pretty_printer", "jaxlib"),
            ("profiler", "_profiler", "jaxlib"),
            ("profile-data", "_profile_data", "jaxlib"),
            ("mlir", "_mlir", "jaxlib/mlir/_mlir_libs"),
            ("jax-mlir-ext", "_jax_mlir_ext", "jaxlib/mlir/_mlir_libs"),
            ("chlo", "_chlo", "jaxlib/mlir/_mlir_libs"),
            ("stablehlo", "_stablehlo", "jaxlib/mlir/_mlir_libs"),
            ("sdy", "_sdy", "jaxlib/mlir/_mlir_libs"),
            ("sdy-mpmd", "_sdyMpmd", "jaxlib/mlir/_mlir_libs"),
            ("mlir-hlo", "_mlirHlo", "jaxlib/mlir/_mlir_libs"),
        ]:
            target = name + "-extension"
            extensions[f"{target}-wasm/{target}_side_module.wasm"] = f"{directory}/{module}.so"
        binaries = {}
        for name, installed in extensions.items():
            matches = list(args.bazel_out.glob(f"*/bin/jaxlib/wasm/{name}"))
            if len(matches) != 1:
                raise RuntimeError(f"Expected one compiled {name}: {matches}")
            with matches[0].open("rb") as stream:
                if stream.read(8) != b"\0asm\x01\0\0\0":
                    raise RuntimeError(f"Not a Wasm module: {matches[0]}")
            binaries[installed] = matches[0]
        generated = list(args.bazel_out.glob("*/bin/jaxlib/mlir/ir.py"))
        if len(generated) != 1:
            raise RuntimeError("Build //jaxlib/wasm:browser-python before packaging")
        generated_jaxlib = generated[0].parent.parent
        if not (generated_jaxlib / "mlir/_mlir_libs/__init__.py").is_file():
            raise RuntimeError("Missing generated MLIR package initializer")
        output.mkdir(parents=True, exist_ok=True)
        jaxlib = source / "jaxlib"
        for path in jaxlib.rglob("*"):
            relative = path.relative_to(jaxlib)
            if (path.is_file() and path.suffix in (".py", ".pyi")
                    and relative.parts[0] not in ("tools", "wasm")
                    and relative.name != "setup.py" and "__pycache__" not in relative.parts):
                copy(path, Path("jaxlib") / relative)
        copy(jaxlib / "init.py", "jaxlib/__init__.py")
        (output / "jaxlib/init.py").unlink()
        copy(source / "jax/version.py", "jaxlib/version.py")
        for path in generated_jaxlib.rglob("*"):
            relative = path.relative_to(generated_jaxlib)
            if path.is_file() and relative.parts[0] == "mlir" and path.suffix in (".py", ".pyi"):
                target = output / "jaxlib" / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(re.sub(r"^from mlir(\..*)? import (.*)",
                                         r"from jaxlib.mlir\1 import \2", path.read_text(), flags=re.M))
        for installed, binary in binaries.items():
            copy(binary, installed)
        for name in ("c_api.h", "ffi.h", "api.h"):
            copy(args.xla / "xla/ffi/api" / name, Path("jaxlib/include/xla/ffi/api") / name)
        for original, name in [(jaxlib / "setup.py", "setup.py"),
                               (jaxlib / "README.md", "README.md"),
                               (jaxlib / "tools/LICENSE.txt", "LICENSE.txt")]:
            copy(original, name)
        (output / "setup.cfg").write_text(
            "[metadata]\nlicense_files = LICENSE.txt\n\n[bdist_wheel]\n"
            f"plat_name = emscripten_6_0_8_{args.arch}\n")
        version_file = output / "jaxlib/version.py"
    text = version_file.read_text()
    previous = "_release_version: str | None = None"
    if previous not in text:
        raise RuntimeError("Unexpected JAX version source")
    version_file.write_text(text.replace(previous, f"_release_version: str = {args.version!r}", 1))
    print(output)


if __name__ == "__main__":
    main()
