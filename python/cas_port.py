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


def presentation_invocation(args):
    """Read parameters, inverse flag, source, target and point data, in that order.

    The enclosing request's op identifies the published comparison. This helper
    checks framing only and does not identify endpoints or prove inverse laws.
    """
    if not isinstance(args, dict) or args.get("ctor") != "presentationApply":
        raise ValueError("a comparison invocation requires the presentationApply envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 5:
        raise ValueError("a comparison invocation requires all five ordered fields")
    if not isinstance(fields[0], list):
        raise ValueError("comparison parameters must be ordered data")
    if not isinstance(fields[1], bool):
        raise ValueError("the comparison direction must be a boolean")
    return tuple(fields)


def _selected_parameter(args, kind):
    if not isinstance(args, dict) or args.get("ctor") != kind:
        raise ValueError("a selected %s requires the %s envelope" % (kind, kind))
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a selected %s requires its registered id and ordered parameters" % kind)
    if not isinstance(fields[0], str) or not fields[0]:
        raise ValueError("a selected %s has no registered id" % kind)
    if not isinstance(fields[1], list):
        raise ValueError("selected %s parameters must be ordered data" % kind)
    return tuple(fields)


def category_parameter(args):
    """Read (registered category id, ordered parameters), retaining the selection.

    The formal caller checks the complete category dictionary. Parsing establishes
    no category laws and does not identify categories from shared carriers.
    """
    return _selected_parameter(args, "category")


def functor_parameter(args):
    """Read (registered functor id, ordered parameters) without choosing an action.

    Full source and target dictionaries belong to the formal declaration and caller.
    """
    return _selected_parameter(args, "functor")


def core_object(args):
    """Read the complete underlying object of the caller's selected Core source."""
    if not isinstance(args, dict) or args.get("ctor") != "coreObject":
        raise ValueError("a core object requires the coreObject envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 1:
        raise ValueError("a core object requires one complete receiver")
    return fields[0]


def core_iso(args):
    """Read (source, target, forward, backward), retaining both map directions.

    This frames the caller's independently selected comparison; it does not prove
    inverse equations, map laws, equality of endpoints, or mathematical correctness.
    """
    if not isinstance(args, dict) or args.get("ctor") != "coreIso":
        raise ValueError("a core comparison requires the coreIso envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 4:
        raise ValueError("a core comparison requires both complete endpoints and both directions")
    return tuple(fields)


def construction_invocation(args, operation):
    """Read (construction id, ordered parameters, complete source receiver).

    Use the exact dispatched construction operation id. The formal caller checks
    the dependent signature; no parameter or source is inferred from backend data.
    """
    if not isinstance(operation, str) or not operation:
        raise ValueError("a construction invocation has no registered id")
    if not isinstance(args, dict) or args.get("ctor") != operation:
        raise ValueError("the construction invocation differs from the dispatched operation")
    parameters = args.get("args")
    if not isinstance(parameters, list):
        raise ValueError("construction parameters must be ordered data")
    if "receiver" not in args:
        raise ValueError("a construction invocation has no complete source receiver")
    return operation, parameters, args["receiver"]


def value_data(data):
    """Supply inline computational data under the caller's fixed result contract."""
    return {"ctor": "valueData", "args": [data]}


def typed_map(args):
    """Read complete actual source, target and callable data, in that order.

    The caller checks these against its selected endpoint descriptions. This helper
    supplies framing only; it does not establish equations or transfer token owners.
    """
    if not isinstance(args, dict) or args.get("ctor") != "typedMap":
        raise ValueError("a computational map requires the typedMap envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 3:
        raise ValueError("a computational map requires its complete source, target and callable")
    return tuple(fields)


def map_data(source, target, callable_data):
    """Supply a map's actual complete endpoints and callable representation."""
    return {"ctor": "typedMap", "args": [source, target, callable_data]}


def object_product(args):
    """Read ordered endpoint descriptors for a caller-fixed public binary product.

    This is concrete framing for the declared Prod source, not a semantic registry
    entry or a claim that its computational data satisfy product laws.
    """
    if not isinstance(args, dict) or args.get("ctor") != "objectProduct":
        raise ValueError("a product endpoint requires its declared envelope")
    fields = args.get("args")
    if not isinstance(fields, list) or len(fields) != 2:
        raise ValueError("a product endpoint requires both ordered object descriptors")
    return tuple(fields)


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
    if not line or any(ch < ord("0") or ch > ord("9") for ch in line):
        raise ValueError("bad frame length %r" % line)
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
            if "args" not in frame:
                raise ValueError("the request omitted its args field")
            write_frame({"request_id": rid, "status": "ok", "value": ops[op](frame["args"])})
        except Exception as exc:  # the caller decodes, and rejects, whatever comes back
            write_frame({"request_id": rid, "status": "error", "kind": type(exc).__name__,
                         "message": str(exc)})
