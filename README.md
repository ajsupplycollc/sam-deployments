# sam-deployments

Private monorepo powering every SAM client stack. Each client has their own subfolder under `clients/<name>/` containing their seeded context, MCP configs, scripts, and client-facing update log.

## Layout

```
sam-deployments/
├── template/                # Base scaffold copied into every new client
│   ├── context/             # Context bible — brand voice, products, SOPs
│   ├── mcp_configs/         # MCP server configs (shopify, postiz, gmail, etc.)
│   ├── scripts/             # Bootstrap + maintenance scripts (install, update, backup)
│   └── .sam-updates/        # Changelog entries surfaced in client morning brief
│
└── clients/
    ├── gotbedlam/           # Joshua Tolen — Got Bedlam Beard Co.
    ├── <next_client>/
    └── ...
```

## How updates reach a client

1. SAM edits files in `clients/<client>/`
2. SAM pushes a commit
3. Client laptop runs `git pull --ff-only` at 3 AM ET via scheduled task (sparse-checkout on their folder only, authenticated with read-only deploy key)
4. Morning-brief hook reads new entries in `.sam-updates/` with `client_facing: true` frontmatter, surfaces them to the client's daily briefing

Client never logs into GitHub. Client never needs to know GitHub exists.

## Provisioning a new client

```bash
cp -r template/ clients/<new_client>/
# Fill out context/, configure mcp_configs/, seed .sam-updates/
```

Then add the client to the deploy-key access list and hand them the bootstrap installer.

## Status

- [ ] Private GitHub repo created (pending Jereme approval)
- [x] Local scaffold built
- [x] Got Bedlam (Josh Tolen) context seeded
- [ ] macOS bootstrap script (Josh is on Mac)
- [ ] Windows bootstrap script (template for future clients)
- [ ] Deploy key system
- [ ] Morning-brief hook
