#!/usr/bin/env bash
set -euo pipefail

: "${PREFIX:?Set the target package prefix}"
: "${BUILD_PREFIX:?Set the native build prefix}"
: "${JAX_WASM_XLA_SOURCE:?Set the matching XLA source directory}"
: "${LLVM_SOURCE_DIR:?Set the LLVM 23.1.2 source directory}"
task_arch="${1:?Expected wasm32 or wasm64}"
case "$task_arch" in
  wasm32) task_arch_flags=(--copt=-m32 --linkopt=-m32) ;;
  wasm64) task_arch_flags=(--copt=-m64 --linkopt=-m64) ;;
  *) echo "Expected wasm32 or wasm64" >&2; exit 2 ;;
esac
task_source="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="${JAX_WASM_BUILD_DIR:-$task_source/build/emscripten-$task_arch}"
task_python_version="${PY_VER:-3.14}"
mkdir -p "$task_build"
task_build="$(cd "$task_build" && pwd)"
export JAX_WASM_PYTHON_INCLUDE="$PREFIX/include/python$task_python_version"
export JAX_WASM_NUMPY_INCLUDE="$PREFIX/lib/python$task_python_version/site-packages/numpy/_core/include"
export JAX_WASM_EMSDK="${JAX_WASM_EMSDK:-$BUILD_PREFIX/opt/emsdk/upstream}"
export JAX_WASM_LLVM_REPOSITORY="$task_build/installed-llvm"
export PATH="$BUILD_PREFIX/bin:$PATH"

python "$task_source/build/emscripten/configure_llvm.py" \
  --prefix "$PREFIX" --native-prefix "$BUILD_PREFIX" \
  --overlay "$LLVM_SOURCE_DIR/utils/bazel/llvm-project-overlay" \
  --runtime-sources "$LLVM_SOURCE_DIR/mlir/lib/ExecutionEngine" \
  --python-version "$task_python_version" --output "$JAX_WASM_LLVM_REPOSITORY"

cd "$task_source"
exec bazel --output_base="$task_build/bazel" build \
  --override_module=xla="$JAX_WASM_XLA_SOURCE" \
  --enable_platform_specific_config=false \
  --incompatible_enable_cc_toolchain_resolution \
  --features=wasm_exceptions \
  --repo_env=USE_HERMETIC_CC_TOOLCHAIN=0 \
  --repo_env=APPLE_SUPPORT_LAYERING_CHECK_BETA=0 \
  --repo_env=HERMETIC_PYTHON_VERSION="$task_python_version" \
  --repo_env=JAX_WASM_PYTHON_INCLUDE --repo_env=JAX_WASM_NUMPY_INCLUDE \
  --repo_env=JAX_WASM_EMSDK --repo_env=JAX_WASM_LLVM_REPOSITORY \
  --@xla//xla/tsl/framework/contraction:disable_onednn_contraction_kernel=true \
  --copt=-sSUPPORT_LONGJMP=wasm \
  --copt=-fPIC --copt=-msimd128 --copt=-O2 --copt=-g0 \
  --copt=-mno-tail-call --copt=-fvisibility=hidden \
  --per_file_copt='.*(stablehlo|shardy|mlir_hlo)/.*,-.*integrations/python/.*@-fno-rtti' \
  --per_file_copt='.*xla/(codegen|backends/cpu/codegen)/.*@-fno-rtti' \
  --per_file_copt='.*jaxlib/mosaic/dialect/.*@-fno-rtti' \
  --per_file_copt='.*jaxlib/mosaic/gpu/(serde|passes)\.cc@-fno-rtti' \
  --per_file_copt='.*xla/backends/gpu/codegen/emitters/ir/.*@-fno-rtti' \
  --per_file_copt='.*xla/python/refine_polymorphic_shapes\.cc@-fno-rtti' \
  --per_file_copt='.*xla/python/ifrt/ir/(transforms/|ifrt_dialect\.cc|ifrt_ops\.cc).*@-fno-rtti' \
  --per_file_copt='.*(integrations|bindings)/python/.*@-frtti' \
  --per_file_copt='.*xla/codegen/tiling/(symbolic_tile_analysis|tiled_hlo_schedule)\.cc@-frtti' \
  --per_file_copt='.*xla/codegen/emitters/fusion_wrapper_base\.cc@-frtti' \
  --linkopt=-sSUPPORT_LONGJMP=wasm --linkopt=-mno-tail-call --linkopt=-Wl,--no-entry \
  --jobs="${CPU_COUNT:-3}" --strip=never "${task_arch_flags[@]}" \
  //jaxlib/wasm:browser-extensions //jaxlib/wasm:browser-python
