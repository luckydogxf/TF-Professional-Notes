# WAF policy-as-code

## Layout

```text
waf/
├── config.env.example
├── config.env                 # local only; do not commit
├── policies/
│   ├── whitelist.json
│   ├── acl.json
│   ├── api-rate-limit.json
│   └── bot.json
└── waf-rules.sh
```

## Normal workflow

```bash
cp config.env.example config.env
chmod 600 config.env
vim config.env

./waf-rules.sh resources
./waf-rules.sh validate
./waf-rules.sh plan
./waf-rules.sh apply
./waf-rules.sh list
```

`waf-rules.sh` automatically loads `config.env` when present.

## Enable / disable

Rule identity for whitelist/custom ACL/API policies is the JSON `.name`.
Bot rule identity is `.botRuleDetail.ruleKey`.

```bash
./waf-rules.sh enable admin-default-deny
./waf-rules.sh disable admin-default-deny
./waf-rules.sh enable api-40qps-captcha
./waf-rules.sh disable suspicious_development_tool_python
```

These commands call Alibaba WAF `ModifyDefenseRuleStatus` and change only status.
They do not recreate or modify the rule configuration.

## Delete

Deletion is deliberately protected by an explicit confirmation flag:

```bash
./waf-rules.sh delete api-40qps-captcha --yes
```

This calls `DeleteDefenseRule`. The containing template is kept.

## Important safety note

`enable` means "activate the configured action". It does **not** mean "safe from false positives".

Examples:

- `admin-office-bypass-all`: enabling it can over-bypass WAF if the IP condition is too broad.
- `admin-default-deny`: enabling it can block legitimate non-office `/admin` users.
- `scanner-user-agent-block`: can false-positive if a legitimate client uses one of the listed UA strings.
- `api-40qps-captcha`: can challenge legitimate shared-NAT/high-throughput clients.
- `human_machine_challenge`: can challenge legitimate traffic classified as human-machine suspicious.
- `malicious_crawler_python`: CAPTCHA is disruptive to any matching client.
- `normal_intelligence_search_spider`: bypass reduces protection for traffic classified as a normal search spider.
- `suspicious_development_tool_python`: monitor does not block; this is the lowest-impact rule in the supplied set.

For staged rollout, use `monitor` where the scenario supports it, inspect rule-hit/log data, then move to a blocking/challenge action.
