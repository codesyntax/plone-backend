#!/usr/bin/env python3
"""Translate the legacy plone-backend environment contract onto INSTANCE_*.

This shim runs *before* the vendored ``transform_from_environment.py``. It prints
``export INSTANCE_<key>=<value>`` statements on stdout for the legacy variables
that are set and for which the matching ``INSTANCE_<key>`` is not already
present. ``transform_from_environment.py`` then overlays those onto the merged
``instance.yaml``.

When the backend is selected by the legacy presence variables
(``RELSTORAGE_DSN`` / ``ZEO_ADDRESS``), the legacy backend defaults are filled
too, for byte-for-byte parity with the skeleton. Pure ``INSTANCE_*`` users get
cookiecutter's own defaults. When any legacy variable is used, a single
aggregated deprecation warning is printed on stderr naming them; nothing is
printed when none are used.
"""

from __future__ import annotations

import os
import shlex
import sys

#: Legacy variable names that were actually set, in the order encountered.
_warned: list[str] = []
#: ``INSTANCE_*`` assignments to emit, keyed by target variable name.
_exports: dict[str, str] = {}

_TRUTHY = frozenset({"1", "true", "yes", "on", "t", "y"})


def _as_bool(value: str) -> str:
    """Normalise a legacy boolean to the literal ``true`` / ``false``.

    The vendored transform only coerces those two strings; ``on``/``off``
    would otherwise pass through as truthy strings.
    """
    return "true" if str(value).strip().lower() in _TRUTHY else "false"


def _blob_mode(value: str) -> str:
    """The legacy ``*_SHARED_BLOB_DIR`` flag inverts onto ``db_blob_mode``."""
    return "shared" if str(value).strip().lower() in _TRUTHY else "cache"


def _set(key: str, value: str) -> None:
    """Export ``INSTANCE_<key>`` unless it is already set explicitly."""
    target = f"INSTANCE_{key}"
    if target in os.environ or target in _exports:
        return
    _exports[target] = value


def _mark(name: str) -> None:
    if name not in _warned:
        _warned.append(name)


#: ``(legacy name, INSTANCE_* key, value transform, legacy default)``.
_RELSTORAGE = (
    ("RELSTORAGE_DSN", "db_relstorage_postgresql_dsn", None, None),
    ("RELSTORAGE_NAME", "db_relstorage_name", None, "storage"),
    ("RELSTORAGE_READ_ONLY", "db_relstorage_read_only", _as_bool, "false"),
    ("RELSTORAGE_KEEP_HISTORY", "db_relstorage_keep_history", _as_bool, "true"),
    ("RELSTORAGE_COMMIT_LOCK_TIMEOUT", "db_relstorage_commit_lock_timeout", None, "30"),
    ("RELSTORAGE_CREATE_SCHEMA", "db_relstorage_create_schema", _as_bool, "true"),
    ("RELSTORAGE_SHARED_BLOB_DIR", "db_blob_mode", _blob_mode, "false"),
    ("RELSTORAGE_BLOB_CACHE_SIZE", "db_blob_cache_size", None, "100mb"),
    ("RELSTORAGE_BLOB_CACHE_SIZE_CHECK", "db_blob_cache_size_check", None, "10"),
    (
        "RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL",
        "db_relstorage_blob_cache_size_check_external",
        _as_bool,
        "false",
    ),
    ("RELSTORAGE_BLOB_CHUNK_SIZE", "db_relstorage_blob_chunk_size", None, "1048576"),
    ("RELSTORAGE_CACHE_LOCAL_MB", "db_relstorage_cache_local_mb", None, "10"),
    ("RELSTORAGE_CACHE_LOCAL_OBJECT_MAX", "db_relstorage_cache_local_object_max", None, "16384"),
    ("RELSTORAGE_CACHE_LOCAL_COMPRESSION", "db_relstorage_cache_local_compression", None, "none"),
)

_ZEO = (
    ("ZEO_ADDRESS", "db_zeo_server", None, None),
    ("ZEO_SHARED_BLOB_DIR", "db_blob_mode", _blob_mode, "off"),
    ("ZEO_READ_ONLY", "db_zeo_read_only", _as_bool, "false"),
    ("ZEO_CLIENT_READ_ONLY_FALLBACK", "db_zeo_read_only_fallback", _as_bool, "false"),
    ("ZEO_STORAGE", "db_zeo_storage", None, "1"),
    ("ZEO_CLIENT_CACHE_SIZE", "db_zeo_cache_size", None, "128MB"),
    ("ZEO_DROP_CACHE_RATHER_VERIFY", "db_zeo_drop_cache_rather_verify", _as_bool, "false"),
)


def _backend() -> tuple[str, bool]:
    """Return ``(effective backend, selected by a legacy variable)``.

    An explicit ``INSTANCE_db_storage`` wins; otherwise ``RELSTORAGE_DSN`` wins
    over ``ZEO_ADDRESS`` (with a warning); direct is the baked default.
    """
    if "INSTANCE_db_storage" in os.environ:
        return os.environ["INSTANCE_db_storage"].strip().lower(), False
    if "RELSTORAGE_DSN" in os.environ:
        if "ZEO_ADDRESS" in os.environ:
            _mark("ZEO_ADDRESS")
            print(
                "WARNING: both RELSTORAGE_DSN and ZEO_ADDRESS are set; "
                "selecting RelStorage",
                file=sys.stderr,
            )
        return "relstorage", True
    if "ZEO_ADDRESS" in os.environ:
        return "zeo", True
    return "direct", False


def _apply(table, fill_defaults: bool) -> None:
    """Translate one backend family. Only translate the active family: mapping
    another family's keys (e.g. a RelStorage blob mode onto direct) produces an
    invalid combination."""
    for name, key, transform, default in table:
        if name in os.environ:
            _mark(name)
            value = os.environ[name]
        elif fill_defaults and default is not None:
            value = default
        else:
            continue
        _set(key, transform(value) if transform else value)


def main() -> int:
    backend, legacy_selected = _backend()
    if legacy_selected and backend in ("relstorage", "zeo"):
        _set("db_storage", backend)

    if backend == "relstorage":
        _apply(_RELSTORAGE, fill_defaults=legacy_selected)
    elif backend == "zeo":
        _apply(_ZEO, fill_defaults=legacy_selected)

    for target, value in _exports.items():
        print(f"export {target}={shlex.quote(value)}")

    if _warned:
        print(
            "DEPRECATION: the legacy environment variables "
            + ", ".join(_warned)
            + " are deprecated; use INSTANCE_* variables or a mounted "
            "instance.yaml instead.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
