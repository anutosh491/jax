"""Declared inputs and installation paths for the Wasm jaxlib wheel."""

def _wheel_manifest_impl(ctx):
    sources = {}
    files = list(ctx.files.srcs)
    for src in files:
        destination = src.short_path
        if destination in ["jaxlib/README.md", "jaxlib/setup.py", "jaxlib/tools/LICENSE.txt"]:
            destination = src.basename
        elif destination == "jaxlib/init.py":
            destination = "jaxlib/__init__.py"
        elif not destination.startswith("jaxlib/"):
            fail("Unexpected wheel source: {}".format(destination))
        if destination in sources and sources[destination] != src.path:
            fail("Duplicate wheel destination: {}".format(destination))
        sources[destination] = src.path
    for target, destination in ctx.attr.extensions.items():
        modules = [f for f in target.files.to_list() if f.basename.endswith(".wasm") and not f.basename.endswith(".debug.wasm")]
        if len(modules) != 1:
            fail("Expected one Wasm module from {}".format(target.label))
        if destination in sources:
            fail("Duplicate wheel destination: {}".format(destination))
        sources[destination] = modules[0].path
        files.append(modules[0])
    ctx.actions.write(ctx.outputs.manifest, json.encode(sources))
    return [DefaultInfo(files = depset(files + [ctx.outputs.manifest]))]

wheel_manifest = rule(
    implementation = _wheel_manifest_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "extensions": attr.label_keyed_string_dict(),
    },
    outputs = {"manifest": "%{name}.json"},
)
