"""Category interfaces from the accepted declaration export.

These descriptors retain native signatures and build the released protocol's
packets. They neither choose a realization nor infer a codec from a Lean type.
The kernel checks dependent arguments, selected structures, and result owners.
"""

from __future__ import annotations

import json
from pathlib import Path
from types import MappingProxyType

import cas_port
import cas_session


def _copy(value):

    return json.loads(json.dumps(value, ensure_ascii=False, allow_nan=False))


def _unique(rows, key):
    result = {}
    for row in rows:
        identity = key(row)
        if identity in result:
            raise ValueError(f"ambiguous published interface: {identity!r}")
        result[identity] = row
    return result


def _addresses(value):
    """Read addresses actually emitted by the public exporter."""
    result = set()
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ("operation", "objectOperation", "mapOperation"):
                if not isinstance(item, str) or not item:
                    raise ValueError("a public operation address must be nonempty text")
                result.add(item)
            else:
                result.update(_addresses(item))
    elif isinstance(value, (list, tuple)):
        for item in value:
            result.update(_addresses(item))
    return result


class ResultInterface:
    """An actual scoped result and its original, uninstantiated family metadata."""

    def __init__(self, family, value):
        if not isinstance(value, cas_session.Proxy):
            raise TypeError("result access requires a supplied scoped Proxy")

        value.reference()
        self.family = family
        self.value = value

    def reference(self):
        return self.value.reference()

    def project(self, field):
        """Describe access by the kernel's computational field index."""
        return self.value.project(field)

    def apply(self, arguments):
        """Describe application at the actual dependent callable interface."""
        return self.value.apply(arguments)


class FamilyInterface:
    """One exact typed registry row, with its complete original declaration family."""

    def __init__(self, api, record, details=()):
        self._api = api
        self._record = record
        self._details = tuple(details)
        self.kind, self.id = record["kind"], record["id"]
        addresses = _addresses(self._details)
        if self.id in api._operations:
            addresses.add(self.id)
        self.operations = tuple(sorted(addresses & api._operations))

    @property
    def metadata(self):
        return _copy(self._record)

    @property
    def signatures(self):
        return _copy(self._record["declarations"])

    @property
    def details(self):
        return _copy(self._details)

    def construct(self, parameters):
        """Select this object/morphism with complete ordered argument descriptors."""
        if self.kind not in ("object", "morphism"):
            raise ValueError("only object and morphism families use this constructor")
        if not isinstance(parameters, list):
            raise TypeError("constructor parameters must be an ordered list")
        return {"ctor": self.id, "args": _copy(parameters)}

    def field(self, field, parameters):
        """Select an actually declared object map, retaining all its parameters."""
        if self.kind != "object":
            raise ValueError("an object field requires an object family")
        allowed = {name for detail in self._details for name in detail.get("fields", [])}
        if field not in allowed:
            raise ValueError(f"object {self.id} does not publish the field {field!r}")
        packet = {"ctor": "objectField", "args": [self.id, field, _copy(parameters)]}
        cas_port.object_field(packet)
        return packet

    def call(self, input_form, arguments, *, operation=None):
        """Describe a published call; retain the explicit input and whole packet."""
        selected = self.id if operation is None else operation
        if selected not in self.operations:
            raise ValueError(f"{selected!r} is not a published operation of {self.kind} {self.id}")
        return self._api.call(selected, input_form, arguments)

    def result(self, value):
        return ResultInterface(self, value)


class CategoryConstructor:
    """A category constructor, separate from object and morphism families."""

    def __init__(self, api, record):
        self._api, self._record = api, record
        self.id = record["id"]

    @property
    def metadata(self):
        return _copy(self._record)

    def construct(self, arguments):
        if not isinstance(arguments, list) or len(arguments) != len(self._record["signature"]):
            raise ValueError("category arguments must match the published ordered signature")
        arguments = _copy(arguments)
        for kind, argument in zip(self._record["signature"], arguments, strict=True):
            if kind == "category":
                self._api._check_category(argument)
        packet = {"ctor": "constructedCategory", "args": [self.id, arguments]}
        cas_port.constructed_category(packet)
        return packet


class CategoryInterface:
    """Direct access to the rows at one complete declared category expression."""

    _sections = {
        "object": "objects", "functor": "functors", "construction": "constructions",
        "cell": "cells", "lift": "lifts", "limit": "limits",
        "categoryFamily": "categoryFamilies",
    }

    def __init__(self, api, record, selected_id=None):
        self._api, self._record, self.id = api, record, selected_id
        self.expression = record["expression"]
        families = {}
        for row in record["entries"]:
            key = (row["kind"], row["id"])
            if key in families:
                raise ValueError(f"ambiguous category member: {key!r}")
            section = self._sections.get(row["kind"])
            details = [item for item in record.get(section, []) if item["id"] == row["id"]] \
                if section is not None else []
            families[key] = FamilyInterface(api, row, details)
        self._families = families

    @property
    def metadata(self):
        return _copy(self._record)

    @property
    def signatures(self):
        return _copy(self._record["categories"])

    def families(self, kind):
        return MappingProxyType({identity: family for (tag, identity), family in
                                 self._families.items() if tag == kind})

    def family(self, kind, identity):
        if (kind, identity) not in self._families:
            raise KeyError(f"no {kind} {identity!r} at the selected category")
        return self._families[kind, identity]

    def select(self, parameters):
        if self.id is None:
            raise ValueError("an unnamed expression needs its published constructor descriptor")
        packet = {"ctor": "category", "args": [self.id, _copy(parameters)]}
        cas_port.category_parameter(packet)
        return packet


class CategoryAPI:
    """Load the generated view without reconstructing owners from global rows."""

    def __init__(self, document):
        document = _copy(document)
        if document.get("categoryInterfaceVersion") != 1:
            raise ValueError("the declaration export has no supported category interface")
        self._document = document
        self._operations = set(_unique(document["operations"], lambda row: row["operation"]))
        self._inputs = set(_unique(document["inputForms"], lambda row: row["input"]))
        self._expressions = _unique(document["categoryInterfaces"], lambda row: row["expression"])
        self._categories = {}
        for record in document["categoryInterfaces"]:
            for category in record["categories"]:
                identity = category["id"]
                if identity in self._categories:
                    raise ValueError(f"ambiguous category id: {identity!r}")
                self._categories[identity] = CategoryInterface(self, record, identity)
        self.category_constructors = MappingProxyType({
            identity: CategoryConstructor(self, row) for identity, row in
            _unique(document["categoryConstructors"], lambda row: row["id"]).items()
        })
        self.generic_families = MappingProxyType({
            key: FamilyInterface(self, row) for key, row in
            _unique(document["genericEntries"], lambda row: (row["kind"], row["id"])).items()
        })
        self._datatypes = _unique(document["datatypes"], lambda row: row["declaration"])
        self._type_aliases = _unique(document["typeAliases"], lambda row: row["declaration"])

    @property
    def datatypes(self):
        return MappingProxyType(_copy(self._datatypes))

    @property
    def type_aliases(self):
        return MappingProxyType(_copy(self._type_aliases))

    @property
    def provenance(self):
        return _copy(self._document["provenance"])

    @property
    def categories(self):
        return MappingProxyType(self._categories)

    def category(self, identity):
        return self._categories[identity]

    def category_expression(self, expression):
        return CategoryInterface(self, self._expressions[expression])

    def _check_category(self, packet):
        if isinstance(packet, dict) and packet.get("ctor") == "category":
            identity, parameters = cas_port.category_parameter(packet)
            self.category(identity).select(parameters)
        else:
            identity, arguments = cas_port.constructed_category(packet)
            self.category_constructors[identity].construct(arguments)

    def call(self, operation, input_form, arguments):
        if operation not in self._operations or input_form not in self._inputs:
            raise ValueError("a call requires the exact published operation and input addresses")
        return cas_port.deferred_call(operation, input_form, _copy(arguments))


def load_interfaces(source):
    """Read a published JSON path, stream, or document; never fetch or execute it."""
    if isinstance(source, dict):
        document = source
    elif hasattr(source, "read"):
        document = json.load(source)
    else:
        with Path(source).open(encoding="utf-8") as stream:
            document = json.load(stream)
    return CategoryAPI(document)
