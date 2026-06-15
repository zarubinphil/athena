# MCP — переавторизация на новой машине

`~/.claude/mcp.json` (конфиги) приедет с дотфайлами, но серверы с OAuth требуют интерактивного входа заново. Токен-серверы — подхватят ключ из env/Keychain.

## Нужен интерактивный re-auth (OAuth/вход)
- **Supabase** — `/login` или MCP-флоу авторизации
- **Figma** — десктоп/токен
- **Adobe** (Firefly/Express MCP) — вход в аккаунт
- **Higgsfield** — вход в аккаунт
- **Zapier** — OAuth
- **Sentry** — OAuth/токен
- **claude.ai connectors** — могут отсутствовать в headless/cron (интерактивная авторизация)

## Достаточно env-ключа (из Keychain → secrets-checklist)
- **Firecrawl** — `FIRECRAWL_API_KEY`
- **Tavily** — `TAVILY_API_KEY`

## Локальные, без auth
- playwright · memory · markitdown — работают сразу.

## Проверка
После разворота: `claude` → проверь, что нужные MCP подняты; `mcp-needs-auth-cache.json` подскажет, что ждёт логина. Headless/cron — отдельно (часть MCP недоступна без интерактива).
