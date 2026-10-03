"""Reference implementation, in Python, of the backend port protocol that `CasCatalogue/Port.lean`
specifies: frames are the ASCII decimal byte length of the payload, a newline, then that many bytes
of UTF-8 JSON; stdout carries only frames, stderr is the program's log stream. The core owns the
protocol, not backend programs: a leaf's program may use this module or speak the protocol in any
language."""

import json
import sys


def point_invocation(args, operation=None):
    """Read common invocation framing; endpoint meaning belongs to the formal caller.

    Return (id, parameters, arrow, domain, source, target, argument). No mathematical
    correctness, backend class membership, or law is established here.
    """
    if not isinstance(args, dict) or args.get("ctor") != "apply":
        raise ValueError("a point invocation requires the apply envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 7:
        raise ValueError("a point invocation requires all seven ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a point invocation has no released operation id")
    if operation is not None and fields[0] != operation:
        raise ValueError("the invocation id differs from the requested operation")
    if not isinstance(fields[1], list):
        raise ValueError("invocation parameters must be ordered data")
    return tuple(fields)


def value_data(data):
    """Supply inline computational data under the caller's fixed result contract."""
    return {"ctor": "valueData", "args": [data]}


def admitted_point(args):
    """Read an independently fixed admission context without certifying its data.

    Return (object id, parameters, domain, original target, admitted target, data).
    Formal evidence and the computational data's session remain with the caller.
    """
    if not isinstance(args, dict) or args.get("ctor") != "admittedPoint":
        raise ValueError("an admitted point requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 6:
        raise ValueError("an admitted point requires all six ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("an admitted point has no published object id")
    if not isinstance(fields[1], list):
        raise ValueError("admission parameters must be ordered data")
    return tuple(fields)


def operation_expression(args):
    """Read symbolic input operation data at the caller's selected structure.

    Return (registered operation id, full parameters, operand expressions).
    This framing helper executes no mathematical operation and asserts no law.
    """
    if not isinstance(args, dict) or args.get("ctor") != "operationExpression":
        raise ValueError("an operation expression requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("an operation expression requires all three ordered fields")
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("an operation expression has no registered operation id")
    if not isinstance(fields[1], list) or not isinstance(fields[2], list):
        raise ValueError("operation parameters and operands must be ordered data")
    return tuple(fields)


def opaque_data(token):
    """Supply a connection-local computational token, with no semantic authority.

    The kernel retains its supplying session and owner. The adapter keeps the native
    value alive on this connection and consumes it through its registered operations.
    """
    if not isinstance(token, str) or not token:
        raise ValueError("an opaque computational value has no token")
    return {"ctor": "opaqueData", "args": [token]}


def _read_exact(n):
    buf = b""
    while len(buf) < n:
        chunk = sys.stdin.buffer.read(n - len(buf))
        if not chunk:
            raise EOFError("EOF mid-frame (wanted %d bytes, got %d)" % (n, len(buf)))
        buf += chunk
    return buf


def read_frame():
    """One frame, or None on clean EOF at a frame boundary."""
    line = b""
    while True:
        ch = sys.stdin.buffer.read(1)
        if not ch:
            if line:
                raise EOFError("EOF inside frame length %r" % line)
            return None
        if ch == b"\n":
            break
        line += ch
    return json.loads(_read_exact(int(line)).decode("utf-8"))


def write_frame(obj):
    payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(str(len(payload)).encode("ascii") + b"\n" + payload)
    sys.stdout.buffer.flush()


def serve(backend, backend_version, adapter_version, ops, protocol=1):
    """Announce `ops` (keys: registered semantic operations) and answer requests until EOF."""
    write_frame({"op": "ready", "protocol": protocol, "backend": backend,
                 "backend_version": backend_version, "adapter_version": adapter_version,
                 "capabilities": sorted(ops)})
    while True:
        frame = read_frame()
        if frame is None:
            return
        rid, op = frame.get("request_id"), frame.get("op")
        if op not in ops:
            write_frame({"request_id": rid, "status": "unsupported", "op": op})
            continue
        try:
            write_frame({"request_id": rid, "status": "ok", "value": ops[op](frame.get("args") or {})})
        except Exception as exc:  # the caller decodes, and rejects, whatever comes back
            write_frame({"request_id": rid, "status": "error", "kind": type(exc).__name__,
                         "message": str(exc)})
