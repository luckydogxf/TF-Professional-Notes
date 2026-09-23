#!/usr/bin/env bash
set -Eeuo pipefail

# Alibaba Cloud WAF 3.0 policy-as-code orchestrator.
#
# Terraform owns: domain, TLS, origin, and optional global CC baseline.
# This script owns: whitelist, custom ACL, API CAPTCHA/rate-limit, Bot.
#
# Required environment:
#   WAF_REGION=ap-southeast-1
#   WAF_INSTANCE_ID=waf_v2_public_...
#   WAF_RESOURCES_JSON='["example.com-waf","api.example.com-waf"]'
#
# Commands:
#   ./waf-rules.sh resources
#   ./waf-rules.sh validate
#   ./waf-rules.sh plan
#   ./waf-rules.sh apply
#   ./waf-rules.sh list
#  ./waf-rules.sh enable  <rule-identity>
#  ./waf-rules.sh disable <rule-identity>
#  ./waf-rules.sh delete  <rule-identity> --yes

#
# Notes:
# - Policy rule identity is .name for custom ACL/whitelist and
#   .botRuleDetail.ruleKey for bot_manager.
# - apply is safe against duplicate creation: existing rules are updated.
# - Rule status is fixed at 1 in the supplied policies. Status changes should
#   use ModifyDefenseRuleStatus rather than ModifyDefenseRule.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

# Automatically load local config.env when present.
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/config.env"
fi

ALIYUN_CLI="${ALIYUN_CLI:-aliyun}"
API_VERSION="2021-10-01"

: "${WAF_REGION:?Set WAF_REGION, e.g. ap-southeast-1}"
: "${WAF_INSTANCE_ID:?Set WAF_INSTANCE_ID}"
: "${WAF_RESOURCES_JSON:?Set WAF_RESOURCES_JSON to a JSON array of protected object names}"

POLICY_WHITELIST="${POLICY_DIR}/whitelist.json"
POLICY_ACL="${POLICY_DIR}/acl.json"
POLICY_API="${POLICY_DIR}/api-rate-limit.json"
POLICY_BOT="${POLICY_DIR}/bot.json"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "command not found: $1"
}

validate_resources_json() {
  jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and length > 0)' \
    <<<"${WAF_RESOURCES_JSON}" >/dev/null \
    || die 'WAF_RESOURCES_JSON must be a non-empty JSON array of strings'
}

validate_policy_file() {
  local file="$1"
  [[ -f "$file" ]] || die "missing policy file: $file"
  jq empty "$file" >/dev/null 2>&1 || die "invalid JSON: $file"
  jq -e 'type == "array" and length > 0' "$file" >/dev/null \
    || die "policy must be a non-empty JSON array: $file"
}

validate_bot_labels() {
  local labels_json
  labels_json="$(waf_api DescribeBotRuleLabels --InstanceId "$WAF_INSTANCE_ID" --MaxResults 200)"

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    jq -e --arg key "$key" '
      any(.RuleLabels[]?;
        .LabelKey == $key
        and ((.SubScene // "") | ascii_downcase | contains("web"))
      )
    ' <<<"$labels_json" >/dev/null \
      || die "Bot rule label '$key' is not available in the WAF web scenario"
  done < <(jq -r '.[].botRuleDetail.ruleKey' "$POLICY_BOT")
}

validate_all_policies() {
  validate_policy_file "$POLICY_WHITELIST"
  validate_policy_file "$POLICY_ACL"
  validate_policy_file "$POLICY_API"
  validate_policy_file "$POLICY_BOT"

  # Required identity fields.
  jq -e 'all(.[]; (.name | type) == "string" and (.name | length) > 0)' "$POLICY_WHITELIST" >/dev/null \
    || die "whitelist.json: every rule needs .name"
  jq -e 'all(.[]; (.name | type) == "string" and (.name | length) > 0)' "$POLICY_ACL" >/dev/null \
    || die "acl.json: every rule needs .name"
  jq -e 'all(.[]; (.name | type) == "string" and (.name | length) > 0)' "$POLICY_API" >/dev/null \
    || die "api-rate-limit.json: every rule needs .name"
  jq -e 'all(.[]; (.botRuleDetail.ruleKey | type) == "string" and (.botRuleDetail.ruleKey | length) > 0)' "$POLICY_BOT" >/dev/null \
    || die "bot.json: every rule needs .botRuleDetail.ruleKey"

  if grep -R -qE 'REPLACE_WITH_|__REPLACE|CHANGE_ME' "$POLICY_DIR"; then
    die "policy contains placeholder values; replace them before apply"
  fi

  validate_bot_labels
}

waf_api() {
  local action="$1"
  shift
  "$ALIYUN_CLI" waf-openapi "$action" \
    --version "$API_VERSION" \
    --force \
    --region "$WAF_REGION" \
    --RegionId "$WAF_REGION" \
    "$@"
}

describe_templates() {
  waf_api DescribeDefenseTemplates \
    --InstanceId "$WAF_INSTANCE_ID" \
    --PageNumber 1 \
    --PageSize 100
}

describe_resources() {
  waf_api DescribeDefenseResources \
    --InstanceId "$WAF_INSTANCE_ID" \
    --PageNumber 1 \
    --PageSize 100
}

find_template_id() {
  local name="$1"
  local scene="$2"
  local subscene="${3:-}"

  describe_templates | jq -r \
    --arg name "$name" \
    --arg scene "$scene" \
    --arg subscene "$subscene" '
      .Templates[]?
      | select(.TemplateName == $name)
      | select(.DefenseScene == $scene)
      | select((.DefenseSubScene // "") == $subscene)
      | .TemplateId
    ' | head -n1
}

ensure_template() {
  local name="$1"
  local scene="$2"
  local subscene="${3:-}"
  local id

  id="$(find_template_id "$name" "$scene" "$subscene")"
  if [[ -n "$id" ]]; then
    echo "$id"
    return 0
  fi

  log "CREATE TEMPLATE: $name / $scene / ${subscene:-none}" >&2

  local args=(
    --InstanceId "$WAF_INSTANCE_ID"
    --TemplateName "$name"
    --TemplateType user_custom
    --TemplateStatus 1
    --DefenseScene "$scene"
    --TemplateOrigin custom
  )
  [[ -n "$subscene" ]] && args+=(--DefenseSubScene "$subscene")

  local response
  response="$(waf_api CreateDefenseTemplate "${args[@]}")"
  id="$(jq -r '.TemplateId // empty' <<<"$response")"
  [[ -n "$id" ]] || die "CreateDefenseTemplate did not return TemplateId"
  echo "$id"
}

bind_template() {
  local template_id="$1"
  waf_api ModifyTemplateResources \
    --InstanceId "$WAF_INSTANCE_ID" \
    --TemplateId "$template_id" \
    --BindResources "$WAF_RESOURCES_JSON" \
    >/dev/null
}

rule_type_for_scene() {
  local scene="$1"
  if [[ "$scene" == "whitelist" ]]; then
    echo "whitelist"
  else
    echo "defense"
  fi
}

describe_rules() {
  local template_id="$1"
  local scene="$2"
  local rule_type
  rule_type="$(rule_type_for_scene "$scene")"

  local query
  query="$(jq -cn --argjson templateId "$template_id" --arg scene "$scene" '{templateId:$templateId,scene:$scene}')"

  waf_api DescribeDefenseRules \
    --InstanceId "$WAF_INSTANCE_ID" \
    --RuleType "$rule_type" \
    --DefenseType template \
    --Query "$query" \
    --PageNumber 1 \
    --PageSize 100
}

policy_identity() {
  local scene="$1"
  local rule_json="$2"

  if [[ "$scene" == "bot_manager" ]]; then
    jq -r '.botRuleDetail.ruleKey // empty' <<<"$rule_json"
  else
    jq -r '.name // empty' <<<"$rule_json"
  fi
}

find_existing_rule() {
  local scene="$1"
  local rules_json="$2"
  local identity="$3"

  if [[ "$scene" == "bot_manager" ]]; then
    jq -c --arg key "$identity" '
      .Rules[]?
      | . as $r
      | (if (($r.Config // null) | type) == "string" then ($r.Config | fromjson?) else ($r.Config // {}) end) as $cfg
      | select(($cfg.botRuleDetail.ruleKey // $r.botRuleDetail.ruleKey // "") == $key)
    ' <<<"$rules_json" | head -n1
  else
    jq -c --arg name "$identity" '
      .Rules[]?
      | . as $r
      | (if (($r.Config // null) | type) == "string" then ($r.Config | fromjson?) else ($r.Config // {}) end) as $cfg
      | select(($r.RuleName // $r.ruleName // $cfg.name // "") == $name)
    ' <<<"$rules_json" | head -n1
  fi
}

rule_id() {
  jq -r '.RuleId // .ruleId // .Id // .id // empty' <<<"$1"
}

create_rule() {
  local template_id="$1"
  local scene="$2"
  local rule_json="$3"
  local payload
  payload="$(jq -cn --argjson r "$rule_json" '[$r]')"

  log "CREATE ${scene}: $(policy_identity "$scene" "$rule_json")"
  waf_api CreateDefenseRule \
    --InstanceId "$WAF_INSTANCE_ID" \
    --TemplateId "$template_id" \
    --DefenseScene "$scene" \
    --DefenseType template \
    --Rules "$payload" \
    >/dev/null
}

modify_rule() {
  local template_id="$1"
  local scene="$2"
  local existing_id="$3"
  local rule_json="$4"
  local update payload

  # The API documents status as a create-time field; status changes
  # should use ModifyDefenseRuleStatus. Keep an emergency disable intact
  # across a normal config reconciliation.
  update="$(jq -cn --argjson r "$rule_json" --argjson id "$existing_id" '$r + {id:$id} | del(.status, .RuleStatus)')"
  payload="$(jq -cn --argjson r "$update" '[$r]')"

  log "UPDATE ${scene}: $(policy_identity "$scene" "$rule_json") (RuleId=${existing_id})"
  waf_api ModifyDefenseRule \
    --InstanceId "$WAF_INSTANCE_ID" \
    --TemplateId "$template_id" \
    --DefenseScene "$scene" \
    --DefenseType template \
    --Rules "$payload" \
    >/dev/null
}

reconcile_policy() {
  local template_name="$1"
  local scene="$2"
  local policy_file="$3"
  local subscene="${4:-}"

  local template_id current_rules count i desired identity existing id

  log ""
  log "=== ${template_name} (${scene}${subscene:+/${subscene})} ==="

  template_id="$(ensure_template "$template_name" "$scene" "$subscene")"
  log "TemplateId=${template_id}"

  bind_template "$template_id"
  current_rules="$(describe_rules "$template_id" "$scene")"

  count="$(jq 'length' "$policy_file")"
  for ((i=0; i<count; i++)); do
    desired="$(jq -c ".[$i]" "$policy_file")"
    identity="$(policy_identity "$scene" "$desired")"
    [[ -n "$identity" ]] || die "cannot determine identity for ${policy_file} item $i"

    existing="$(find_existing_rule "$scene" "$current_rules" "$identity" || true)"
    if [[ -z "$existing" ]]; then
      create_rule "$template_id" "$scene" "$desired"
      continue
    fi

    id="$(rule_id "$existing")"
    [[ -n "$id" ]] || die "existing rule '$identity' has no RuleId"
    modify_rule "$template_id" "$scene" "$id" "$desired"
  done
}

# ------------------------------------------------------------
# Managed policy specifications
# ------------------------------------------------------------
# name | scene | subscene | policy file
# ------------------------------------------------------------
managed_specs() {
  cat <<'EOF'
tf-admin-whitelist|whitelist||whitelist.json
tf-custom-acl|custom_acl||acl.json
tf-api-rate-limit|custom_acl||api-rate-limit.json
tf-bot-web|bot_manager|web|bot.json
EOF
}

# ------------------------------------------------------------
# Locate exactly one managed rule by policy identity.
# Outputs TSV:
#   template_id\tscene\trule_id\tstatus\tidentity\ttemplate_name
# ------------------------------------------------------------
find_managed_rule() {
  local identity="$1"
  local found=()
  local name scene subscene policy_file tid rules existing rid status

  while IFS='|' read -r name scene subscene policy_file; do
    [[ -n "$name" ]] || continue

    tid="$(find_template_id "$name" "$scene" "$subscene")"
    [[ -n "$tid" ]] || continue

    rules="$(describe_rules "$tid" "$scene")"
    existing="$(find_existing_rule "$scene" "$rules" "$identity" || true)"
    [[ -n "$existing" ]] || continue

    rid="$(rule_id "$existing")"
    status="$(jq -r '.Status // .RuleStatus // empty' <<<"$existing")"

    [[ -n "$rid" ]] || die "Found managed rule '$identity' without RuleId"

    found+=("${tid}\t${scene}\t${rid}\t${status}\t${identity}\t${name}")
  done < <(managed_specs)

  if (( ${#found[@]} == 0 )); then
    return 1
  fi

  if (( ${#found[@]} > 1 )); then
    printf '%s\n' "${found[@]}" >&2
    die "Multiple managed rules match identity '$identity'; use a unique identity"
  fi

  printf '%b\n' "${found[0]}"
}

# ------------------------------------------------------------
# Enable / disable a managed rule.
# Alibaba WAF provides ModifyDefenseRuleStatus specifically for
# changing status. It accepts RuleStatus=0 or 1.
# ------------------------------------------------------------
set_rule_status() {
  local identity="$1"
  local desired_status="$2"

  [[ "$desired_status" == "0" || "$desired_status" == "1" ]] ||
    die "desired status must be 0 or 1"

  local line template_id scene rule_id current_status template_name
  line="$(find_managed_rule "$identity" || true)"
  [[ -n "$line" ]] || die "Managed rule not found: $identity"

  IFS=$'\t' read -r template_id scene rule_id current_status _ template_name <<<"$line"

  if [[ "$current_status" == "$desired_status" ]]; then
    if [[ "$desired_status" == "1" ]]; then
      log "Already ENABLED: ${identity} (RuleId=${rule_id})"
    else
      log "Already DISABLED: ${identity} (RuleId=${rule_id})"
    fi
    return 0
  fi

  if [[ "$desired_status" == "1" ]]; then
    log "ENABLE: ${identity} (RuleId=${rule_id}, Template=${template_name})"
  else
    log "DISABLE: ${identity} (RuleId=${rule_id}, Template=${template_name})"
  fi

  waf_api ModifyDefenseRuleStatus \
    --InstanceId "$WAF_INSTANCE_ID" \
    --TemplateId "$template_id" \
    --RuleId "$rule_id" \
    --RuleStatus "$desired_status" \
    --DefenseType template \
    >/dev/null
}

# ------------------------------------------------------------
# Delete one managed rule.
# This is intentionally protected by an explicit --yes flag.
# Alibaba WAF DeleteDefenseRule accepts RuleIds as a comma-separated
# string. We only delete template-level rules in our managed templates.
# ------------------------------------------------------------
remove_rule() {
  local identity="$1"
  local confirmation="${2:-}"

  [[ "$confirmation" == "--yes" ]] ||
    die "delete requires explicit confirmation: ./waf-rules.sh delete <rule> --yes"

  local line template_id scene rule_id current_status template_name
  line="$(find_managed_rule "$identity" || true)"
  [[ -n "$line" ]] || die "Managed rule not found: $identity"

  IFS=$'\t' read -r template_id scene rule_id current_status _ template_name <<<"$line"

  warn "DELETE ${identity} (RuleId=${rule_id}, Template=${template_name})"
  warn "This action removes the WAF rule; it is not just a disable."

  waf_api DeleteDefenseRule \
    --InstanceId "$WAF_INSTANCE_ID" \
    --TemplateId "$template_id" \
    --RuleIds "$rule_id" \
    --DefenseType template \
    >/dev/null

  log "DELETED: ${identity} (RuleId=${rule_id})"
}


validate() {
  validate_resources_json
  validate_all_policies
  log "Validation OK."
}

plan_policy() {
  local template_name="$1"
  local scene="$2"
  local policy_file="$3"
  local subscene="${4:-}"

  local template_id current_rules count i desired identity existing id
  template_id="$(find_template_id "$template_name" "$scene" "$subscene")"

  if [[ -z "$template_id" ]]; then
    echo "[CREATE TEMPLATE] $template_name ($scene${subscene:+/$subscene})"
    jq -r '.[] | "[CREATE] " + (if has("name") then .name else .botRuleDetail.ruleKey end)' "$policy_file"
    return 0
  fi

  echo "[EXISTS TEMPLATE] $template_name -> $template_id"
  current_rules="$(describe_rules "$template_id" "$scene")"
  count="$(jq 'length' "$policy_file")"

  for ((i=0; i<count; i++)); do
    desired="$(jq -c ".[$i]" "$policy_file")"
    identity="$(policy_identity "$scene" "$desired")"
    existing="$(find_existing_rule "$scene" "$current_rules" "$identity" || true)"
    if [[ -z "$existing" ]]; then
      echo "[CREATE] $identity"
    else
      id="$(rule_id "$existing")"
      echo "[UPDATE] $identity (RuleId=$id)"
    fi
  done
}

plan() {
  validate
  echo
  echo "WAF POLICY PLAN"
  echo "Region   : $WAF_REGION"
  echo "Instance : $WAF_INSTANCE_ID"
  echo "Resources: $WAF_RESOURCES_JSON"
  echo

  plan_policy "tf-admin-whitelist" "whitelist" "$POLICY_WHITELIST"
  plan_policy "tf-custom-acl" "custom_acl" "$POLICY_ACL"
  plan_policy "tf-api-rate-limit" "custom_acl" "$POLICY_API"
  plan_policy "tf-bot-web" "bot_manager" "$POLICY_BOT" "web"

  echo
  echo "No WAF configuration was changed."
}

apply() {
  validate

  reconcile_policy "tf-admin-whitelist" "whitelist" "$POLICY_WHITELIST"
  reconcile_policy "tf-custom-acl" "custom_acl" "$POLICY_ACL"
  reconcile_policy "tf-api-rate-limit" "custom_acl" "$POLICY_API"
  reconcile_policy "tf-bot-web" "bot_manager" "$POLICY_BOT" "web"

  log "WAF policy apply complete."
}

list_rules() {
  describe_templates |
    jq -r '.Templates[]? | [.TemplateId,.TemplateName,.DefenseScene,(.DefenseSubScene // "-"),.TemplateStatus] | @tsv'

  echo
  local specs=(
    'tf-admin-whitelist|whitelist|'
    'tf-custom-acl|custom_acl|'
    'tf-api-rate-limit|custom_acl|'
    'tf-bot-web|bot_manager|web'
  )
  local spec name scene subscene tid

  for spec in "${specs[@]}"; do
    IFS='|' read -r name scene subscene <<<"$spec"
    tid="$(find_template_id "$name" "$scene" "$subscene")"
    [[ -n "$tid" ]] || continue
    echo "# $name ($tid)"
    describe_rules "$tid" "$scene" |
      jq -r --arg scene "$scene" '
        .Rules[]?
        | . as $r
        | (if (($r.Config // null) | type) == "string" then ($r.Config | fromjson?) else ($r.Config // {}) end) as $cfg
        | (if $scene == "bot_manager" then ($cfg.botRuleDetail.ruleKey // $r.botRuleDetail.ruleKey // "-") else ($r.RuleName // $r.ruleName // $cfg.name // "-") end) as $identity
        | [(.RuleId // "-"), $identity, (.Status // .RuleStatus // "-"), (.Action // $cfg.action // "-")]
        | @tsv
      '
    echo
  done
}

resources() {
  describe_resources |
    jq -r '.Resources[]? | [.Resource,.Product,(.Detail.domain // ""),(.ResourceStatus // "")] | @tsv'
}

usage() {
  cat <<'USAGE'
Usage:
  ./waf-rules.sh resources
  ./waf-rules.sh validate
  ./waf-rules.sh plan
  ./waf-rules.sh apply
  ./waf-rules.sh list
  ./waf-rules.sh enable  <rule-identity>
  ./waf-rules.sh disable <rule-identity>
  ./waf-rules.sh delete  <rule-identity> --yes

Rule identity:
  custom ACL / whitelist / API rules -> .name
  Bot rules                     -> botRuleDetail.ruleKey

Examples:
  ./waf-rules.sh enable  admin-default-deny
  ./waf-rules.sh disable scanner-user-agent-block
  ./waf-rules.sh enable  api-40qps-captcha
  ./waf-rules.sh disable suspicious_development_tool_python
  ./waf-rules.sh delete  api-40qps-captcha --yes

Required environment:
  WAF_REGION
  WAF_INSTANCE_ID
  WAF_RESOURCES_JSON='["resource-1-waf","resource-2-waf"]'
USAGE
}

require_command "$ALIYUN_CLI"
require_command jq

case "${1:-}" in
  resources)
    resources
    ;;
  validate)
    validate
    ;;
  plan)
    plan
    ;;
  apply)
    apply
    ;;
  list)
    list_rules
    ;;
  enable)
    [[ $# -eq 2 ]] || die "usage: $0 enable <rule-identity>"
    set_rule_status "$2" 1
    ;;
  disable)
    [[ $# -eq 2 ]] || die "usage: $0 disable <rule-identity>"
    set_rule_status "$2" 0
    ;;
  delete)
    [[ $# -eq 3 ]] || die "usage: $0 delete <rule-identity> --yes"
    remove_rule "$2" "$3"
    ;;
  *)
    usage
    exit 2
    ;;
esac
