#!/usr/bin/env python3
"""Admin utility for resetting and patching Havital dev Firestore users."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any
from urllib import error, parse, request


PROJECT_ID = "havital-dev"
DEMO_UID = "ZyIP5VxEapePp0P2erZx18WYGK92"
API_ROOT = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)"
DOCUMENTS_ROOT = f"{API_ROOT}/documents"
RUN_QUERY_URL = f"{DOCUMENTS_ROOT}:runQuery"
DEV_API_BASE_URL = "https://api-service-364865009192.asia-east1.run.app"
KNOWN_CONNECTION_DOCS = ("garmin", "strava", "apple_health", "polar", "suunto")
LEGACY_USER_COLLECTIONS = ("workouts", "training_plans", "targets")
TOP_LEVEL_USER_FILTERS = (
    ("user_connections", "user_id"),
    ("user_connections", "firebase_user_id"),
    ("connect_accounts", "user_id"),
    ("connect_accounts", "firebase_user_id"),
)


@dataclass(frozen=True)
class TargetUser:
    uid: str
    source: str


class FirestoreRestClient:
    def __init__(self, project_id: str) -> None:
        self.project_id = project_id
        self._token: str | None = None

    @property
    def token(self) -> str:
        if self._token is None:
            completed = subprocess.run(
                ["gcloud", "auth", "application-default", "print-access-token"],
                check=True,
                capture_output=True,
                text=True,
            )
            self._token = completed.stdout.strip()
            if not self._token:
                raise RuntimeError("gcloud returned an empty application-default access token")
        return self._token

    def _request(self, method: str, url: str, payload: dict[str, Any] | None = None) -> Any:
        body = None
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")

        req = request.Request(
            url,
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
        )

        try:
            with request.urlopen(req, timeout=30) as response:
                raw = response.read()
        except error.HTTPError as exc:
            if exc.code == 404:
                return None
            details = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Firestore REST {method} {url} failed: {exc.code} {details}") from exc

        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def get_document(self, doc_path: str) -> dict[str, Any] | None:
        return self._request("GET", f"{DOCUMENTS_ROOT}/{doc_path}")

    def delete_document(self, doc_path: str) -> None:
        self._request("DELETE", f"{DOCUMENTS_ROOT}/{doc_path}")

    def list_collection_ids(self, doc_path: str) -> list[str]:
        payload = self._request(
            "POST",
            f"{DOCUMENTS_ROOT}/{doc_path}:listCollectionIds",
            {"pageSize": 100},
        )
        if payload is None:
            return []
        return payload.get("collectionIds", [])

    def list_documents(self, collection_path: str, page_size: int = 200) -> list[dict[str, Any]]:
        response = self._request("GET", f"{DOCUMENTS_ROOT}/{collection_path}?pageSize={page_size}")
        if response is None:
            return []
        return response.get("documents", [])

    def query_collection(self, collection_name: str, field_name: str, value: Any, limit: int = 50) -> list[dict[str, Any]]:
        payload = {
            "structuredQuery": {
                "from": [{"collectionId": collection_name}],
                "where": {
                    "fieldFilter": {
                        "field": {"fieldPath": field_name},
                        "op": "EQUAL",
                        "value": encode_value(value),
                    }
                },
                "limit": limit,
            }
        }
        response = self._request("POST", RUN_QUERY_URL, payload) or []
        return [entry["document"] for entry in response if "document" in entry]

    def patch_document(self, doc_path: str, set_updates: dict[str, Any], delete_fields: list[str]) -> None:
        field_paths = sorted(set(set_updates.keys()) | set(delete_fields))
        if not field_paths:
            raise ValueError("patch_document requires at least one field")

        query = parse.urlencode([("updateMask.fieldPaths", path) for path in field_paths])
        body: dict[str, Any] = {"name": absolute_document_name(doc_path)}
        if set_updates:
            body["fields"] = {key: encode_value(value) for key, value in set_updates.items()}

        self._request("PATCH", f"{DOCUMENTS_ROOT}/{doc_path}?{query}", body)


def absolute_document_name(doc_path: str) -> str:
    return f"projects/{PROJECT_ID}/databases/(default)/documents/{doc_path}"


def relative_document_path(document_name: str) -> str:
    prefix = "projects/"
    if document_name.startswith(prefix):
        marker = "/documents/"
        _, tail = document_name.split(marker, 1)
        return tail
    return document_name


def encode_value(value: Any) -> dict[str, Any]:
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int) and not isinstance(value, bool):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, datetime):
        ts = value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        return {"timestampValue": ts}
    if isinstance(value, list):
        return {"arrayValue": {"values": [encode_value(item) for item in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {key: encode_value(item) for key, item in value.items()}}}
    raise TypeError(f"unsupported value type: {type(value).__name__}")


def decode_value(encoded: dict[str, Any]) -> Any:
    if "nullValue" in encoded:
        return None
    if "booleanValue" in encoded:
        return encoded["booleanValue"]
    if "integerValue" in encoded:
        return int(encoded["integerValue"])
    if "doubleValue" in encoded:
        return encoded["doubleValue"]
    if "stringValue" in encoded:
        return encoded["stringValue"]
    if "timestampValue" in encoded:
        return encoded["timestampValue"]
    if "arrayValue" in encoded:
        return [decode_value(item) for item in encoded["arrayValue"].get("values", [])]
    if "mapValue" in encoded:
        return {
            key: decode_value(item)
            for key, item in encoded["mapValue"].get("fields", {}).items()
        }
    return encoded


def decode_document_fields(document: dict[str, Any] | None) -> dict[str, Any] | None:
    if not document:
        return None
    return {
        key: decode_value(value)
        for key, value in document.get("fields", {}).items()
    }


def parse_scalar(raw: str) -> Any:
    lowered = raw.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered in {"null", "none"}:
        return None

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def parse_setters(entries: list[str]) -> dict[str, Any]:
    updates: dict[str, Any] = {}
    for entry in entries:
        if "=" not in entry:
            raise ValueError(f"invalid --set value: {entry!r} (expected key=value)")
        key, raw_value = entry.split("=", 1)
        key = key.strip()
        if not key:
            raise ValueError(f"invalid --set key in {entry!r}")
        updates[key] = parse_scalar(raw_value.strip())
    return updates


def resolve_target_user(client: FirestoreRestClient, args: argparse.Namespace) -> TargetUser:
    if args.demo:
        return TargetUser(uid=DEMO_UID, source="demo")
    if args.uid:
        return TargetUser(uid=args.uid, source="uid")
    if args.email:
        docs = client.query_collection("users", "email", args.email, limit=2)
        if not docs:
            raise ValueError(f"no Firestore user document found for email {args.email}")
        if len(docs) > 1:
            raise ValueError(f"multiple Firestore user documents found for email {args.email}")
        uid = relative_document_path(docs[0]["name"]).split("/")[-1]
        return TargetUser(uid=uid, source=f"email:{args.email}")
    raise ValueError("one of --uid / --email / --demo is required")


def delete_collection_tree(client: FirestoreRestClient, collection_path: str, counters: Counter[str]) -> None:
    while True:
        documents = client.list_documents(collection_path, page_size=200)
        if not documents:
            return

        for document in documents:
            counters["documents_scanned"] += 1
            delete_document_tree(client, relative_document_path(document["name"]), counters)


def delete_document_tree(client: FirestoreRestClient, doc_path: str, counters: Counter[str]) -> None:
    for collection_id in client.list_collection_ids(doc_path):
        counters["collections_scanned"] += 1
        delete_collection_tree(client, f"{doc_path}/{collection_id}", counters)

    client.delete_document(doc_path)
    counters["documents_deleted"] += 1


def delete_document_if_exists(client: FirestoreRestClient, doc_path: str, counters: Counter[str]) -> bool:
    document = client.get_document(doc_path)
    if document is None:
        return False
    delete_document_tree(client, doc_path, counters)
    return True


def delete_top_level_matches(
    client: FirestoreRestClient,
    collection_name: str,
    field_name: str,
    value: Any,
    counters: Counter[str],
) -> int:
    total = 0
    while True:
        documents = client.query_collection(collection_name, field_name, value, limit=200)
        if not documents:
            return total

        for document in documents:
            total += 1
            counters["documents_scanned"] += 1
            delete_document_tree(client, relative_document_path(document["name"]), counters)


def summarize_user(client: FirestoreRestClient, uid: str) -> dict[str, Any]:
    user_doc = client.get_document(f"users/{uid}")
    user_fields = decode_document_fields(user_doc)

    summary: dict[str, Any] = {
        "uid": uid,
        "user_doc_exists": user_doc is not None,
        "user_doc": None,
        "subcollections": {},
        "user_connections": [],
    }

    if user_fields is not None:
        summary["user_doc"] = {
            "email": user_fields.get("email"),
            "data_source": user_fields.get("data_source"),
            "active_training_id": user_fields.get("active_training_id"),
            "training_version": user_fields.get("training_version"),
            "onboarding_completed_at": user_fields.get("onboarding_completed_at"),
            "updated_at": user_fields.get("updated_at"),
        }
        for collection_id in client.list_collection_ids(f"users/{uid}"):
            summary["subcollections"][collection_id] = len(
                client.list_documents(f"users/{uid}/{collection_id}", page_size=200)
            )

    connection_docs: list[dict[str, Any]] = []
    for field_name in ("user_id", "firebase_user_id"):
        for document in client.query_collection("user_connections", field_name, uid, limit=50):
            data = decode_document_fields(document) or {}
            connection_docs.append(
                {
                    "id": relative_document_path(document["name"]).split("/")[-1],
                    "provider": data.get("provider"),
                    "status": data.get("status"),
                    "provider_user_id": data.get("provider_user_id"),
                }
            )

    summary["user_connections"] = list({doc["id"]: doc for doc in connection_docs}.values())
    return summary


def reset_fresh_user(client: FirestoreRestClient, uid: str) -> Counter[str]:
    counters: Counter[str] = Counter()

    if delete_user_via_dev_api(uid):
        counters["backend_delete_invoked"] += 1

    if delete_document_if_exists(client, f"users/{uid}", counters):
        counters["user_documents_deleted"] += 1

    for provider in KNOWN_CONNECTION_DOCS:
        if delete_document_if_exists(client, f"user_connections/{uid}_{provider}", counters):
            counters["connection_documents_deleted"] += 1

    for collection_name, field_name in TOP_LEVEL_USER_FILTERS:
        deleted = delete_top_level_matches(client, collection_name, field_name, uid, counters)
        if deleted:
            counters[f"{collection_name}_matches_deleted"] += deleted

    for collection_name in LEGACY_USER_COLLECTIONS:
        deleted = delete_top_level_matches(client, collection_name, "user_id", uid, counters)
        if deleted:
            counters[f"{collection_name}_matches_deleted"] += deleted

    return counters


def delete_user_via_dev_api(uid: str) -> bool:
    req = request.Request(
        f"{DEV_API_BASE_URL}/user/{uid}",
        method="DELETE",
        headers={
            "Authorization": f"Bearer {uid}",
            "Accept-Language": "zh-TW",
        },
    )

    try:
        with request.urlopen(req, timeout=60) as response:
            raw = response.read()
    except error.HTTPError as exc:
        if exc.code == 404:
            return False
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"dev API delete-user failed: {exc.code} {details}") from exc

    if not raw:
        return True

    payload = json.loads(raw.decode("utf-8"))
    return bool(payload.get("success", True))


def print_json(data: Any) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Show, reset, and patch Havital dev Firestore users without touching the auth account."
    )

    target = parser.add_argument_group("target")
    target.add_argument("--uid", help="Firestore/Firebase UID")
    target.add_argument("--email", help="Resolve UID from users.email")
    target.add_argument("--demo", action="store_true", help="Use the reviewer demo account")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("show", help="Show user summary")

    subparsers.add_parser("reset-fresh", help="Delete Firestore state for the target user")

    patch_parser = subparsers.add_parser("patch", help="Merge top-level fields into users/{uid}")
    patch_parser.add_argument("--set", action="append", default=[], help="Field update in key=value form")
    patch_parser.add_argument("--delete-field", action="append", default=[], help="Delete a top-level field")
    patch_parser.add_argument("--json", help="Raw JSON object merged into users/{uid}")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    client = FirestoreRestClient(PROJECT_ID)

    try:
        target = resolve_target_user(client, args)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.command == "show":
        print_json(summarize_user(client, target.uid))
        return 0

    if args.command == "reset-fresh":
        payload = {
            "uid": target.uid,
            "source": target.source,
            "auth_account_preserved": True,
            "cleanup": dict(reset_fresh_user(client, target.uid)),
            "post_reset": summarize_user(client, target.uid),
        }
        print_json(payload)
        return 0

    if args.command == "patch":
        try:
            set_updates = parse_setters(args.set)
        except ValueError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

        if args.json:
            try:
                raw_json = json.loads(args.json)
            except json.JSONDecodeError as exc:
                print(f"error: invalid --json payload: {exc}", file=sys.stderr)
                return 1
            if not isinstance(raw_json, dict):
                print("error: --json must decode to an object", file=sys.stderr)
                return 1
            set_updates.update(raw_json)

        delete_fields = args.delete_field
        if not set_updates and not delete_fields:
            print("error: patch needs --set, --delete-field, or --json", file=sys.stderr)
            return 1

        client.patch_document(f"users/{target.uid}", set_updates, delete_fields)
        print_json(
            {
                "uid": target.uid,
                "source": target.source,
                "applied_fields": sorted(set(set_updates.keys()) | set(delete_fields)),
                "post_patch": summarize_user(client, target.uid),
            }
        )
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
