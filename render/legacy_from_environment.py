#!/usr/bin/env python3
"""Translate the legacy plone-backend environment contract onto INSTANCE_*.

This shim runs *before* the vendored ``transform_from_environment.py``. It prints
``export INSTANCE_<key>=<value>`` statements on stdout for the legacy variables
that are set and for which the matching ``INSTANCE_<key>`` is not already
present. ``transform_from_environment.py`` then overlays those onto the merged
``instance.yaml``.

The legacy backend defaults (``RELSTORAGE_*`` / ``ZEO_*``) are applied by the
entrypoint before this shim runs, so they are translated here too. When any
legacy variable is used, a single aggregated deprecation warning is printed on
stderr; nothing is printed when none are used.
"""

from __future__ import annotations

import os
import shlex
import sys

#: Legacy variable names that were actually used, in the order encountered.
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


def _set(key: str, value: str) -> None:
    """Export ``INSTANCE_<key>`` unless it is already set explicitly."""
    target = f"INSTANCE_{key}"
    if target in os.environ or target in _exports:
        return
    _exports[target] = value


def _mark(name: str) -> None:
    if name not in _warned:
        _warned.append(name)


def _map(name: str, key: str, transform=None) -> None:
    """Map legacy ``name`` (when present) onto ``INSTANCE_<key>``."""
    if name not in os.environ:
        return
    _mark(name)
    value = os.environ[name]
    _set(key, transform(value) if transform else value)


def _map_bool(name: str, key: str) -> None:
    _map(name, key, _as_bool)


def _blob_mode(name: str) -> None:
    """The legacy ``*_SHARED_BLOB_DIR`` flag inverts onto ``db_blob_mode``."""
    if name not in os.environ:
        return
    _mark(name)
    shared = str(os.environ[name]).strip().lower() in _TRUTHY
    _set("db_blob_mode", "shared" if shared else "cache")


def _backend() -> str:
    """The effective backend: an explicit ``INSTANCE_db_storage`` wins, else the
    presence of a legacy backend variable selects it (RelStorage over ZEO),
    else direct (the baked default)."""
    if "INSTANCE_db_storage" in os.environ:
        return os.environ["INSTANCE_db_storage"].strip().lower()
    if "RELSTORAGE_DSN" in os.environ:
        if "ZEO_ADDRESS" in os.environ:
            _mark("ZEO_ADDRESS")
            print(
                "WARNING: both RELSTORAGE_DSN and ZEO_ADDRESS are set; "
                "selecting RelStorage",
                file=sys.stderr,
            )
        return "relstorage"
    if "ZEO_ADDRESS" in os.environ:
        return "zeo"
    return "direct"


def _select_backend(backend: str) -> None:
    if backend in ("relstorage", "zeo") and "INSTANCE_db_storage" not in os.environ:
        _set("db_storage", backend)


def _map_relstorage() -> None:
    _map("RELSTORAGE_DSN", "db_relstorage_postgresql_dsn")
    _map("RELSTORAGE_NAME", "db_relstorage_name")
    _map_bool("RELSTORAGE_READ_ONLY", "db_relstorage_read_only")
    _map_bool("RELSTORAGE_KEEP_HISTORY", "db_relstorage_keep_history")
    _map("RELSTORAGE_COMMIT_LOCK_TIMEOUT", "db_relstorage_commit_lock_timeout")
    _map_bool("RELSTORAGE_CREATE_SCHEMA", "db_relstorage_create_schema")
    _blob_mode("RELSTORAGE_SHARED_BLOB_DIR")
    _map("RELSTORAGE_BLOB_CACHE_SIZE", "db_blob_cache_size")
    _map("RELSTORAGE_BLOB_CACHE_SIZE_CHECK", "db_blob_cache_size_check")
    _map_bool(
        "RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL",
        "db_relstorage_blob_cache_size_check_external",
    )
    _map("RELSTORAGE_BLOB_CHUNK_SIZE", "db_relstorage_blob_chunk_size")
    _map("RELSTORAGE_CACHE_LOCAL_MB", "db_relstorage_cache_local_mb")
    _map("RELSTORAGE_CACHE_LOCAL_OBJECT_MAX", "db_relstorage_cache_local_object_max")
    _map("RELSTORAGE_CACHE_LOCAL_COMPRESSION", "db_relstorage_cache_local_compression")


def _map_zeo() -> None:
    _map("ZEO_ADDRESS", "db_zeo_server")
    _blob_mode("ZEO_SHARED_BLOB_DIR")
    _map_bool("ZEO_READ_ONLY", "db_zeo_read_only")
    _map_bool("ZEO_CLIENT_READ_ONLY_FALLBACK", "db_zeo_read_only_fallback")
    _map("ZEO_STORAGE", "db_zeo_storage")
    _map("ZEO_CLIENT_CACHE_SIZE", "db_zeo_cache_size")
    _map_bool("ZEO_DROP_CACHE_RATHER_VERIFY", "db_zeo_drop_cache_rather_verify")


def main() -> int:
    backend = _backend()
    _select_backend(backend)

    # Only translate the tuning of the backend that is actually in use; mapping
    # another family's keys (e.g. a RelStorage blob mode onto direct) produces an
    # invalid combination.
    if backend == "relstorage":
        _map_relstorage()
    elif backend == "zeo":
        _map_zeo()

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
