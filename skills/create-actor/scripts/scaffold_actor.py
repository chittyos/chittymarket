#!/usr/bin/env python3
"""Scaffold a ChittyOS Actor that consumes chittysdks/actor-base."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f"refusing to overwrite existing file: {path}")
    path.write_text(content, encoding="utf-8")


def title_from_name(name: str) -> str:
    return " ".join(part.capitalize() for part in name.split("-"))


def action_files(name: str, title: str) -> dict[str, str]:
    class_name = "".join(part.capitalize() for part in name.split("-")) + "Client"
    actor_json = {
        "actorSpecification": 1,
        "name": f"chittyactor-{name}",
        "title": f"{title} Actor",
        "description": f"Bounded {title} data-acquisition Actor.",
        "version": "0.1",
        "dockerContextDir": "../../..",
        "dockerfile": "../Dockerfile",
        "runTemplate": {"contextType": "python-script", "entrypoint": "python3 -m src.server"},
        "usesStandbyMode": True,
        "meta": {"author": "ChittyOS"},
    }
    return {
        ".actor/actor.json": json.dumps(actor_json, indent=4) + "\n",
        "requirements.txt": "apify>=2.0.0\nrequests>=2.31.0\nfastapi>=0.100.0\nuvicorn>=0.22.0\n",
        "Dockerfile": f'''FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY chittysdks/actor-base /tmp/chitty-actor-base
RUN pip install --no-cache-dir /tmp/chitty-actor-base

COPY chittyactors/{name}/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY chittyactors/{name}/ ./

CMD ["python3", "-m", "src.server"]
''',
        "src/__init__.py": "",
        "src/__main__.py": '''from chitty_actor_base.entrypoint import entrypoint

if __name__ == "__main__":
    entrypoint(server_module="src.server", main_module="src.main")
''',
        "src/main.py": f'''import asyncio

from chitty_actor_base.actor_runner import run_actor
from .actions import ACTION_REGISTRY
from .client import {class_name}


async def main():
    await run_actor({class_name}, ACTION_REGISTRY, default_action="health")


if __name__ == "__main__":
    asyncio.run(main())
''',
        "src/client.py": f'''class {class_name}:
    """Portal/API client. Replace placeholders with the real bounded acquisition contract."""

    def __init__(self, email=None, password=None, session_token=None, proxy_url=None):
        self.email = email
        self.password = password
        self.session_token = session_token
        self.proxy_url = proxy_url

    def health(self, payload=None):
        return {{"ok": True, "actor": "{name}"}}
''',
        "src/actions.py": '''ACTION_REGISTRY = {
    "health": lambda client, payload: client.health(payload),
}
''',
        "src/server.py": '''from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/health")
def health():
    return {"ok": True}

def run(port: int = 8000):
    uvicorn.run(app, host="0.0.0.0", port=port)
''',
    }


def batch_files(name: str, title: str) -> dict[str, str]:
    actor_json = {
        "actorSpecification": 1,
        "name": f"chittyactor-{name}",
        "title": f"{title} Batch Actor",
        "description": f"Bounded resumable {title} acquisition Actor.",
        "version": "0.1",
        "dockerContextDir": "../../..",
        "dockerfile": "../Dockerfile",
        "runTemplate": {"contextType": "python-script", "entrypoint": "python3 -m src.main"},
        "meta": {"author": "ChittyOS"},
    }
    return {
        ".actor/actor.json": json.dumps(actor_json, indent=4) + "\n",
        "requirements.txt": "apify>=2.0.0\nrequests>=2.31.0\n",
        "Dockerfile": f'''FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY chittysdks/actor-base /tmp/chitty-actor-base
RUN pip install --no-cache-dir /tmp/chitty-actor-base
COPY chittyactors/{name}/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY chittyactors/{name}/ ./

CMD ["python3", "-m", "src.main"]
''',
        "src/__init__.py": "",
        "src/main.py": f'''from apify import Actor
from chitty_actor_base.error_envelope import ActorError, wrap_exception
from chitty_actor_base.trace import get_trace_id


async def main():
    trace_id = get_trace_id()
    async with Actor:
        actor_input = await Actor.get_input() or {{}}
        try:
            # Implement the bounded resumable acquisition loop here.
            await Actor.set_value("OUTPUT", {{"status": "success", "trace_id": trace_id, "input": actor_input}})
        except ActorError as exc:
            output = exc.to_envelope()
            output["trace_id"] = trace_id
            await Actor.set_value("OUTPUT", output)
            await Actor.fail(status_message=str(exc))
        except Exception as exc:
            output = wrap_exception(exc)
            output["trace_id"] = trace_id
            await Actor.set_value("OUTPUT", output)
            await Actor.fail(status_message=str(exc))


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
''',
    }


def governance_files(name: str, title: str, profile: str) -> dict[str, str]:
    return {
        "CHARTER.md": f'''# CHARTER — chittyactor-{name}

## Purpose

Bounded {title} data acquisition/execution.

## Responsibilities

- TODO: list the exact external data sources and operations.
- Return structured output without goal-directed policy.

## Boundaries

- No routing or business-policy decisions.
- No hardcoded credentials or long-lived secret persistence.
- Invocation must come through the documented ChittyAgent/integration owner.
- Shared runtime primitives come from `chittysdks/actor-base`.

## Runtime profile

`{profile}`
''',
        "CHITTY.md": f'''---
name: chittyactor-{name}
agent_role: executor
tier: 3
owner: chittyos
runtime: apify-docker
---

# {title} Actor

Bounded execution projection. Canonical shared Actor mechanics are provided by `chittysdks/actor-base`.
''',
        "CLAUDE.md": f'''# {title} Actor development

## Local

```bash
python3 -m pip install -e ../../chittysdks/actor-base
python3 -m pip install -r requirements.txt
python3 -m src.main
```

## Deployment

Use the Git-backed Apify monorepo source path. Do not use actor-local `apify push` when the Actor requires the repository-root Docker context.

## Rules

- Keep policy in the calling ChittyAgent.
- Do not duplicate `chitty_actor_base` primitives.
- Never hardcode credentials.
- Replace scaffold placeholders with real first-party contract logic before deployment.
''',
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--profile", choices=["action", "batch"], default="action")
    parser.add_argument("--title")
    parser.add_argument("--output-root", default="chittyactors")
    args = parser.parse_args()

    if not NAME_RE.fullmatch(args.name):
        parser.error("name must be bare kebab-case: ^[a-z0-9][a-z0-9-]{0,63}$")

    title = args.title or title_from_name(args.name)
    root = Path(args.output_root) / args.name
    if root.exists() and any(root.iterdir()):
        raise SystemExit(f"refusing to scaffold into non-empty directory: {root}")

    files = action_files(args.name, title) if args.profile == "action" else batch_files(args.name, title)
    files.update(governance_files(args.name, title, args.profile))

    for rel, content in files.items():
        write(root / rel, content)

    print(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
