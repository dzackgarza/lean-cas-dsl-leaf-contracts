# Explicit v1 process bridge

`python/cas_v1_bridge.py` runs an unchanged protocol-v1 backend through the native
v2 SDK. Prepare a separate execution manifest:

```bash
uv run --frozen --project "$CAS_CONTRACT_ROOT" python \
  "$CAS_CONTRACT_ROOT/python/cas_v1_bridge.py" \
  --manifest "$ORIGINAL_LEAVES" \
  --legacy-contract "$LEGACY_CONTRACT_ROOT" \
  --output-manifest "$RUN_DIRECTORY/legacy-v2/leaves.json"
```

The legacy checkout must be clean at
`f0431bebeb01c93cc65bb3fdc5bd23d9613e4b31`. Its `python/cas_port.py` SHA-256 must be
`1a061bfbc3dc40dadc157deaeb11dbd838d7f2710e53f1fe8f369bd60d43e6f5`.
Preparation checks these identities. The output must be outside the original
manifest directory and both contract checkouts. Existing output files reject.

The execution manifest preserves every registration triple and its order.
Each backend command becomes an absolute Python executable, this bridge's
absolute script path, and `--legacy-command-json` with an absolute descriptor
path. The original manifest and backend source remain unchanged.

## Launch descriptors

Each descriptor has format `cas-v1-command/1` and records:

| Field | Value |
| --- | --- |
| `backend` | Original name, executable spelling and ordered argument vector |
| `manifest` | Original absolute manifest path and SHA-256 |
| `launcher` | Resolved Python executable path and SHA-256 |
| `inputs` | Executable and existing file arguments, with paths and SHA-256 |
| `runtime` | Bridge, framing helper and native SDK source receipts |
| `legacy` | Pinned legacy root, revision and helper receipt |
| `cwd` | Original manifest directory |
| `environment` | Exact environment at preparation |

Descriptors and the execution manifest have owner-only file permissions.
Launch checks the receipts and compares the backend with the original manifest.
The caller records the execution manifest and descriptor hashes with its source
repository identities. Imported backend modules and engine installations remain
part of that caller's source/environment freeze.

Verify a prepared manifest before freezing a run:

```bash
uv run --frozen --project "$CAS_CONTRACT_ROOT" python \
  "$CAS_CONTRACT_ROOT/python/cas_v1_bridge.py" \
  --manifest "$ORIGINAL_LEAVES" \
  --execution-manifest "$RUN_DIRECTORY/legacy-v2/leaves.json"
```

Verification checks the ordered registrations, backend identities, wrapper
commands and descriptor receipts. It emits a `cas-v1-execution/1` JSON receipt
with source paths and hashes. Runners retain these guards through execution.

The child receives the recorded command vector and cwd. Its environment retains
the recorded values, with `CAS_LEAF_CONTRACT_PATH` set to the pinned legacy root
and `PYTHONPATH` set to that root's `python` directory. Script-local imports and
the original engine interpreter selection remain in effect.

## Connection and values

The bridge validates the child's actual v1 ready frame before native v2
negotiation. The child remains the same process for the connection lifetime.
Child loss closes the bridge, including while idle.

| Input or result | Behaviour |
| --- | --- |
| Ordinary released packets | Preserve their data and exact input address |
| Native `opaqueData` | Return an SDK export lease for the actual child token |
| Published native invocation | Restore the actual child token and complete invocation context |
| Retained capture slot | Reuse the native data retained for that declared capture |
| Structured or deferred result | Translate recursively; retain ordered calls and references |
| Foreign proxy without a v1 representation | Return `unsupported` for the consumed operation |
| Generic dependent invocation | Return `unsupported` for `$cas.invoke_export` |
| Unissued continuation | Return the SDK's absent-continuation error |

The SDK owns export leases. `$cas.discard` revokes aliases from its named request
and preserves other requests' leases. A revoked alias cannot return through an
ordinary request. Native memory stays under the original engine's lifetime rules.

Deferred groups return to the kernel as groups. The bridge does not execute their
child recipes. Computational error kinds and messages remain those of the child.
The bridge supplies neither mathematical decoding nor a representation relation.
