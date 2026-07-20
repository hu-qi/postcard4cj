# Test Layout

postcard4cj keeps executable Cangjie test packages under `src/` because `cjpm test` discovers and executes the current package-local `*_test` and compatibility packages in both Cangjie LTS 1.0.5 and STS 1.1.3.

This top-level directory exists to satisfy the cj-awesome project layout and to document how the test suite is organized. Moving test source files here without a validated `cjpm.toml` test-target configuration would risk silently reducing executed coverage, so the source layout remains unchanged until such a migration is verified on both compiler release lines.

## Executable test packages

- `src/postcard4cj_*_test.cj`: core codec and helper tests
- `src/postcard_macro_test/`: legacy codec, Schema and MaxSize macro tests
- `src/derive_ng_test/`: next-generation Schema and MaxSize macro tests
- `src/compatibility/`: fixed Postcard Golden Vectors and framing/remainder compatibility tests
- module-specific `*_test` packages under `src/`: schema, dynamic, IO, flavors, accumulator, fixint and postcard2 coverage

## Running the suite

Activate exactly one Cangjie SDK environment, then run:

```bash
cjpm build -V
cjpm test -V
```

Repeat under:

- Cangjie LTS 1.0.5
- Cangjie STS 1.1.3

The GitHub Actions matrix performs both validations automatically.

## Test contribution rules

1. Every new public behavior requires a positive test.
2. Every new parser/decoder branch requires malformed or truncated input coverage where applicable.
3. Wire-format changes require a fixed Golden Vector.
4. New length-prefixed decoders require a malicious-length allocation regression test.
5. Macro features require compilation and behavior tests under both release lines.
6. A test relocation is complete only when the before/after executed test count and package list are verified on LTS and STS.
