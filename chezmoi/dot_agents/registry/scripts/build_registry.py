#!/usr/bin/env python3
"""Reconcile installed capabilities -> registry.jsonl (canonical).
Sources: .claude/skills, .codex/skills, .claude/agents, .codex/agents, plugins,
.skill-lock.json (provenance), GITHUB-STARS-LEDGER.md (stars), overrides.jsonl (manual).
Usage counts start at 0 (counting begins now). Run: python3 build_registry.py
"""
import json, os, re, math

HOME = os.path.expanduser("~")
AG = f"{HOME}/.agents"
CLA = f"{HOME}/.claude"
COD = f"{HOME}/.codex"
REG = f"{AG}/registry"
OUT = f"{REG}/registry.jsonl"
STARS_CEIL_LOG = math.log10(200000)  # ecc ~198k = normalization ceiling

# ---------- helpers ----------
def parse_frontmatter(path):
    try:
        txt = open(path, encoding="utf-8", errors="ignore").read(6000)
    except Exception:
        return None, ""
    m = re.match(r"^---\s*\n(.*?)\n---", txt, re.S)
    fm = m.group(1) if m else txt[:1500]
    nm = re.search(r"^name:\s*(.+)$", fm, re.M)
    name = nm.group(1).strip().strip("\"'") if nm else None
    dm = re.search(r"^description:\s*(.*)$", fm, re.M)
    desc = ""
    if dm:
        first = dm.group(1).strip()
        if first in ("|", ">", "|-", ">-", "|+", ">+"):
            for ln in fm[dm.end():].splitlines():
                if re.match(r"^\s+\S", ln):
                    desc += " " + ln.strip()
                elif ln.strip() == "":
                    continue
                else:
                    break
            desc = desc.strip()
        else:
            desc = first.strip("\"'")
    return name, re.sub(r"\s+", " ", desc)[:300]

def list_dirs(p):
    return set(os.listdir(p)) if os.path.isdir(p) else set()

# ---------- load provenance ----------
lock = {}
try:
    lock = json.load(open(f"{AG}/.skill-lock.json")).get("skills", {})
except Exception:
    pass

def norm_repo(u):
    return re.sub(r"\.git$", "", (u or "").strip().rstrip("/"))

# stars by repo from ledger
stars_by_repo = {}
ledger_path = f"{AG}/GITHUB-STARS-LEDGER.md"
if os.path.exists(ledger_path):
    for line in open(ledger_path, encoding="utf-8"):
        c = [x.strip() for x in line.split("|")]
        if len(c) > 6 and c[2].startswith("http"):
            try:
                stars_by_repo[norm_repo(c[2])] = int(c[4])
            except Exception:
                pass

# ---------- stars-cache overlay (from gh sync_stars.py; fresher than ledger) ----------
star_cache = {}
_cp = f"{REG}/stars-cache.json"
if os.path.exists(_cp):
    try:
        star_cache = json.load(open(_cp))
    except Exception:
        pass
def cache_get(url):
    m = re.search(r"github\.com/([^/]+/[^/]+)", url or "")
    return star_cache.get(m.group(1).replace(".git", "")) if m else None

# ---------- usage from log (single source of truth) ----------
from datetime import datetime, timezone, timedelta
usage_count_map, usage30_map, last_map = {}, {}, {}
logp = f"{REG}/usage.log"
if os.path.exists(logp):
    now = datetime.now(timezone.utc)
    cut = now - timedelta(days=30)
    for line in open(logp, encoding="utf-8"):
        p = line.rstrip("\n").split("\t")
        if len(p) < 3:
            continue
        ts, sid = p[0], p[2]
        usage_count_map[sid] = usage_count_map.get(sid, 0) + 1
        try:
            t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            if t >= cut:
                usage30_map[sid] = usage30_map.get(sid, 0) + 1
            if sid not in last_map or ts > last_map[sid]:
                last_map[sid] = ts
        except Exception:
            pass
MAXUSE = max(usage_count_map.values()) if usage_count_map else 1

# ---------- manual overrides ----------
overrides = {}
ovp = f"{REG}/overrides.jsonl"
if os.path.exists(ovp):
    for line in open(ovp, encoding="utf-8"):
        line = line.strip()
        if line:
            o = json.loads(line)
            overrides[o["id"]] = o

# ---------- domain heuristic ----------
# ordered (specific first); first match wins, plus always-eligible 'any'
# Ordered specific->general; first 2 matches win. id-based. Tuned to misc=0, max domain ~200.
DOMAIN_RULES = [
    ("gsd",           r"^gsd-"),
    ("redteam",       r"(exploit-|pentest|red-team|evilginx|metasploit|impacket|covenant|pass-the-hash|pass-the-ticket|lateral-movement-with-wmi|kerberoasting-with|nopac|zerologon|ms17-010|eternal-|initial-access-with|hash-cracking|wifi-password-crack|phishing-simulation|spearphishing-simulation|social-engineering-pentest|social-engineering-pretext|building-c2-|building-red-team|building-attack-pattern|executing-red-team|conducting-full-scope|conducting-man-in-the-middle|conducting-pass-the|conducting-social-engineering|performing-red-team|performing-purple-team|performing-physical-intrusion|performing-wireless-network-pentest|performing-wireless-security-assess|performing-bluetooth-security|performing-wifi|performing-lateral-movement-with-wmiexec|bypassing-authentication|intercepting-mobile|executing-phishing|performing-adversary-in-the-middle|performing-credential-access-with-lazagne|analyzing-heap-spray|performing-bandwidth-throttling|performing-arp-spoof|performing-packet-inject|performing-vlan-hop|performing-privilege-escal|conducting-mobile-app-penetration|performing-thick-client|performing-binary-exploit|exploiting-api-injection|exploiting-bgp-hijack|exploiting-constrained|exploiting-deeplink|exploiting-ipv6|exploiting-server-side-request|exploiting-template-inject|exploiting-websocket-vuln|building-adversary-infra)"),
    ("detection",     r"(detecting-|hunting-for-|triaging-security|correlating-security|analyzing-security-logs|building-detection|building-soc|building-cloud-siem|implementing-alert-fatigue|implementing-siem|implementing-soar|implementing-endpoint-detection|performing-alert-triage|performing-threat-hunting|performing-lateral-movement-detection|performing-user-behavior-analytics|performing-false-positive-reduction|performing-log-source-onboarding|analyzing-api-gateway-access-logs|analyzing-azure-activity-logs|analyzing-cloud-storage-access|analyzing-command-and-control|analyzing-dns-logs|analyzing-email-headers|analyzing-kubernetes-audit|analyzing-linux-audit-logs|analyzing-network-traffic-for|analyzing-network-flow|analyzing-network-covert|analyzing-office365-audit|analyzing-persistence-mechanisms|analyzing-powershell-script|analyzing-web-server-logs|hunting-advanced-persistent|hunting-credential-stuffing|performing-dns-tunneling-detect|investigating-insider-threat|investigating-phishing-email|building-incident-response|performing-soc-tabletop|implementing-deception-based-detect|performing-deception-technology|deploying-active-directory-honeytokens|performing-yara-rule|implementing-honeytokens|analyzing-powershell-empire|analyzing-cyber-kill|configuring-host-based-intrusion|configuring-windows-defender|implementing-file-integrity|implementing-log-integrity|implementing-security-monitoring-with-datadog|implementing-syslog|performing-insider-threat|performing-network-traffic-analysis|performing-network-packet-capture|correlating-threat-campaigns|implementing-security-chaos|implementing-llm-guardrails)"),
    ("forensics",     r"(forensic|volatility|autopsy|memory-dump|disk-image|timeline|file-carv|rekall|hindsight|plaso|cellebrite|prefetch|shellbag|lnk-file|amcache|windows-event-log|outlook-pst|browser-history|sqlite-forensic|extracting-browser|extracting-credentials|extracting-memory|extracting-ioc|extracting-windows|extracting-config|recovering-deleted|analyzing-mft|acquiring-disk|conducting-memory-forensics|performing-disk-forensic|performing-endpoint-forensic|performing-linux-log-forensic|performing-log-analysis-for-forensic|performing-mobile-device-forensic|performing-network-forensic|performing-timeline|performing-windows-artifact|collecting-volatile-evidence|analyzing-usb-device|performing-steganography|analyzing-windows-registry-for-artifacts|performing-firmware-extraction)"),
    ("malware",       r"(malware|ransomware|rootkit|bootkit|trojan|deobfuscat|reverse-engineer|analyzing-cobalt|analyzing-cobaltstrike|analyzing-golang-malware|analyzing-linux-elf|analyzing-linux-kernel-rootkit|analyzing-macro-malware|analyzing-malicious-pdf|analyzing-malicious-url|analyzing-malware|analyzing-packed-malware|analyzing-pdf-malware|analyzing-android-malware|analyzing-ios-app-security-with-objection|performing-static-malware|performing-dynamic-analysis-with|performing-firmware-malware|eradicating-malware|recovering-from-ransomware|implementing-ransomware-|deploying-decoy|analyzing-ethereum-smart-contract|defi-amm-security|analyzing-sbom|performing-supply-chain-attack-simul|building-automated-malware|automating-ioc-enrichment|performing-ioc-enrichment|analyzing-network-traffic-of-malware|analyzing-malware-network|analyzing-ransomware|building-phishing-reporting|implementing-anti-phishing|implementing-mimecast|implementing-email-sandboxing|implementing-proofpoint|performing-dmarc-policy|implementing-dmarc)"),
    ("iam",           r"(active-directory|bloodhound|dcsync|golden-ticket|kerberoast|privilege-escal|access-control|rbac|saml-sso|sso-with-okta|okta|sailpoint|cyberark|pam-for|ldap|zero-standing|just-in-time|identity-governance|identity-federation|identity-aware-proxy|access-recertif|access-review|entitlement-review|service-account-audit|privileged-account|configuring-multi-factor|managing-cloud-identity|implementing-saml|implementing-scim|implementing-conditional-access|implementing-just-in-time|implementing-identity-governance|implementing-passwordless|implementing-hardware-security-key|implementing-zero-standing|implementing-privileged-access|implementing-azure-ad-privileged|conducting-domain-persistence|conducting-internal-reconnais|auditing-gcp-iam|securing-aws-iam|building-identity|implementing-beyondcorp|deploying-cloudflare-access|deploying-software-defined-perimeter|deploying-tailscale|configuring-aws-verified-access|configuring-identity-aware-proxy|configuring-zscaler|implementing-cisa-zero-trust|implementing-browser-isolation|implementing-device-posture|implementing-identity-verification|implementing-zero-trust|auditing-azure-active-directory|performing-access-recertif|performing-access-review|performing-entitlement|performing-service-account|performing-active-directory|configuring-active-directory|performing-privileged-account|implementing-delinea|implementing-mtls|configuring-oauth2|performing-oauth-scope|implementing-privileged-session|implementing-google-workspace-sso|implementing-google-workspace-admin|implementing-google-workspace-phishing)"),
    ("cloud-sec",     r"(aws-security|azure-security|gcp-security|aws-guardduty|azure-defender|aws-macie|aws-security-hub|cloud-incident|cloud-forensic|cloud-penetration|cloud-native-threat|performing-cloud-|performing-aws-account|performing-gcp-|performing-aws-privilege|implementing-aws-config|implementing-aws-iam-permission|implementing-aws-nitro|implementing-azure-defender|implementing-cloud-security|implementing-cloud-trail|implementing-cloud-waf|implementing-cloud-workload|implementing-gcp-binary|implementing-gcp-organization|implementing-gcp-vpc|implementing-cloud-dlp|implementing-cloud-vulnerability|detecting-aws|detecting-azure|detecting-cloud|detecting-compromised-cloud|detecting-misconfigured-azure|detecting-cryptomining-in-cloud|detecting-s3-|auditing-aws-s3|remediating-s3|securing-azure|conducting-cloud-incident|conducting-cloud-penetration|securing-aws-lambda|deploying-edr|deploying-osquery|implementing-aws-macie|building-cloud-siem|analyzing-azure-activity|analyzing-cloud-storage|implementing-attack-surface-management|implementing-attack-path|performing-cloud-asset|securing-serverless|securing-github-actions|implementing-infrastructure-as-code-security|building-devsecops-pipeline)"),
    ("compliance",    r"(compliance|iso-27001|pci-dss|hipaa|gdpr|nerc-cip|nist-csf|soc2|cis-benchmark|iec-62443|performing-nist-csf|performing-privacy-impact|healthcare-phi|implementing-iso|implementing-pci|implementing-gdpr|implementing-nerc|performing-oil-gas-cybersecurity|performing-power-grid-cybersecurity|prioritizing-vulnerabilities|implementing-epss|implementing-rapid7|implementing-vulnerability-management|implementing-vulnerability-remediation|implementing-vulnerability-sla|building-vulnerability|triaging-vulnerabilities|implementing-patch-management|performing-cve-prioritization|performing-asset-criticality|scanning-infrastructure-with-nessus|performing-endpoint-vulnerability|implementing-continuous-security-validation|implementing-application-whitelisting|implementing-usb-device|implementing-endpoint-dlp|performing-agentless-vulnerability|performing-authenticated-scan|performing-authenticated-vulnerability|performing-vulnerability-scanning)"),
    ("osint",         r"(osint|open-source-intelligence|spiderfoot|certificate-transparen|brand-monit|dark-web|paste-site|threat-intelligence|threat-actor|threat-feed|threat-hunt-hypothesis|threat-landscape|threat-emul|mitre-attack|mitre-navigator|diamond-model|stix|taxii|analyzing-apt|analyzing-campaign|analyzing-threat-actor|profiling-threat|building-threat|building-ioc|collecting-indicators|collecting-open-source|collecting-threat|managing-intelligence|processing-stix|performing-osint|performing-ip-reputation|performing-dark-web|performing-indicator|monitoring-darkweb|tracking-threat|correlating-threat-campaigns|performing-brand-monitor|performing-open-source-intelligence|performing-ai-driven-osint|performing-paste-site|analyzing-typosquatting|implementing-security-information-sharing|implementing-stix-taxii|implementing-taxii|implementing-threat-intelligence|building-threat-feed|building-threat-actor|building-threat-intelligence|analyzing-indicators-of-compromise|performing-malware-ioc|performing-malware-hash|performing-subdomain-enumeration|performing-dns-enumeration)"),
    ("appsec",        r"(owasp|xss|csrf|ssrf|graphql-sec|websocket-sec|second-order-sql|sql-injection|api-fuzzing|api-inventory|api-rate-limiting-bypass|api-security-testing|api-security-posture|api-abuse-detection|api-schema-valid|api-threat-protect|api-enum|broken-access|broken-function|broken-object|broken-link|mass-assign|idor|deseri|prototype-poll|race-condition|type-juggling|clickjacking|cors-misc|host-header|content-security-policy-bypass|http-request-smuggl|open-redirect|xml-inject|jwt-none|jwt-algorithm|oauth-misc|implementing-api-gateway-security|implementing-api-key-security|implementing-api-rate-lim|implementing-api-schema|implementing-api-security|securing-api-gateway|performing-api-fuzzing|performing-api-inventory|performing-api-rate-limiting-bypass|performing-graphql|performing-content-security-policy|performing-http-param|implementing-runtime-application-self|implementing-web-application|implementing-semgrep|implementing-github-advanced-security|integrating-dast|integrating-sast|performing-sca-dependency|web-application-firewall|web-application-penetration|web-application-logging|web-application-vuln|web-application-scanning|web-application-security|performing-security-headers|performing-ssl-strip|testing-api-authentication|testing-for-broken|testing-for-business-logic|testing-for-json-web-token|testing-jwt|testing-mobile-api|testing-websocket|testing-oauth2|testing-cors|testing-for-host-header|testing-for-open-redirect|testing-for-xml|testing-for-xss|testing-for-xxe|testing-for-sensitive|testing-for-email|performing-soap-web|performing-directory-traversal|performing-second-order-sql|performing-ssrf|performing-blind-ssrf|performing-jwt-|performing-web-cache|performing-graphql-depth|performing-graphql-introspection|performing-serverless-function-security|implementing-fuzz-testing-in-cicd|performing-fuzzing-with|django-security|laravel-security|quarkus-security|perl-security|springboot-security|security-review$|security-reviewer|security-scan$|security-bounty|implementing-devsecops-security|implementing-secrets-management|implementing-secret-scanning|performing-mobile-app-certificate|implementing-jwt-sign)"),
    ("crypto",        r"(encrypt|aes-encrypt|rsa-key|ed25519|digital-signature|zero-knowledge|certificate-authority|configuring-tls|tls-1-3|tls-certificate|ssl-certificate|ssl-tls-security|implementing-aes|implementing-rsa|implementing-digital|implementing-envelope|implementing-end-to-end|implementing-hardware-security-module|performing-cryptographic|performing-hash-cracking|performing-ssl-certificate|performing-post-quantum|configuring-certificate|implementing-code-signing|implementing-sigstore|implementing-supply-chain-security-with-in-toto|implementing-image-provenance|nodejs-keccak256|evm-token-decimals|configuring-hsm|implementing-hashicorp-vault|performing-hardware-security-module|performing-ssl-tls-inspect)"),
    ("network-sec",   r"(firewall|ddos-mitigation|bgp-security|implementing-bgp|implementing-ddos|implementing-network-intrusion|implementing-network-access-control|implementing-next-generation-firewall|network-deception|implementing-network-traffic|implementing-network-segmentation|configuring-pfsense|configuring-snort|configuring-suricata|configuring-microsegmentation|implementing-microsegmentation|scanning-network-with-nmap|network-penetration-test|detecting-ntlm-relay|detecting-arp-poison|detecting-port-scanning|implementing-canary-token|implementing-network-deception|homelab-network|network-bgp-diagnostics|network-config-validation|network-interface-health|performing-external-network|conducting-network-pentest|conducting-internal-network|conducting-wireless-network|configuring-network-segmentation-with-vlans|analyzing-network-packets|analyzing-network-traffic-with-wireshark|analyzing-network-flow-data|analyzing-network-covert|implementing-network-policies-for-kubernetes|implementing-policy-as-code|network-architect|network-troubleshooter|network-config-reviewer)"),
    ("ot-ics",        r"(scada|modbus|ot-|ics-|plc-|s7comm|dnp3|historian|conduit-security|dragos|claroty|nozomi|purdue-model|monitoring-scada|performing-s7comm|performing-scada|performing-ics|implementing-conduit|implementing-dragos|implementing-nerc-cip|implementing-patch-management-for-ot|securing-historian|securing-remote-access-to-ot|detecting-anomalies-in-industrial|detecting-attacks-on-historian|detecting-attacks-on-scada|detecting-dnp3|detecting-modbus|detecting-stuxnet|implementing-iec-62443)"),
    ("incident-response", r"(incident-response|ir-playbook|containing-active|eradicating-malware|recovering-from-ransomware|performing-ransomware-response|performing-ransomware-tabletop|conducting-post-incident|triaging-security-incident|building-ransomware-playbook|implementing-ticketing-system-for-incident|implementing-ot-incident|implementing-velociraptor|implementing-immutable-backup|validating-backup-integrity|implementing-ransomware-backup|testing-ransomware-recovery|building-patch-tuesday|conducting-malware-incident|investigating-ransomware|implementing-log-forwarding)"),
    ("container-sec", r"(container-escape|container-drift|container-image-hardening|scanning-container|scanning-docker|scanning-kubernetes|performing-container-escape|performing-container-image|performing-container-security|performing-docker-bench|performing-kubernetes-|implementing-aqua|implementing-container|implementing-pod|implementing-rbac-hardening|implementing-opa-gatekeeper|securing-container|securing-helm|securing-kubernetes|hardening-docker|deploying-crowdstrike|deploying-edr-agent|implementing-ebpf|detecting-container|implementing-kubernetes-network|implementing-kubernetes-pod|implementing-runtime-security-with-tetragon)"),
    ("3d",            r"(threejs|three-|webgl|3d-|spatial|gltf|blender|typegpu|^three$)"),
    ("design",        r"(design|ui-|ux-|brand|figma|visual|typograph|animation-designer|frontend-design|nothing-design|stitch|penpot|liquid-glass|shadcn|tailwind|framer-motion|css-animation|lottie|waapi|gsap|^animejs$|theme-factory|^prototype$|usability-tester|canvas-design|premium-frontend|web-design-review|design-html|design-md|a11y-architect)"),
    ("web",           r"(frontend|web-design|react-|vue-|next-|accessibility|seo-|core-web|performance-opt|webapp-testing|browser-testing|playwright|chrome-devtools|lighthouse|web-quality|windows-desktop-e2e|vercel-|^seo$|^screenshot$|hyperframes|remotion|^website-builder-setup$|website-to-hyperframes)"),
    ("video",         r"(video|ffmpeg|moviepy|elevenlabs|voice|redub|manim|clip|ltx2|acestep|fal-ai-media|gpt-image-2|runpod|scene-review)"),
    ("finance",       r"(dcf|lbo|comps|valuation|equity|bond|earnings|merger|portfolio|nav-|kyc|accrual|gl-|fsi-|3-statement|tax-loss|fx-carry|swap-curve|option-vol|catalyst-calendar|deal-|buyer-list|cim-|ic-memo|tear-sheet|ib-check|prediction-market|initiating-coverage|sector-overview|macro-rates|morning-note|funding-digest|ito-basket|ito-market|ito-trade|returns-analysis|returns-reverse|unit-economics|value-creation|variance-commentary|financial-plan|finance-billing|customer-billing|inventory-demand|carrier-relationship|logistics-exception|energy-procurement|production-scheduling|quality-nonconformance)"),
    ("research",      r"(firecrawl|exa-|deep-research|scientific-|pubmed|market-research|competitive-anal|scientific-pkg|scientific-thinking|article-writing|iterative-retrieval|search-first|^scrape$|^browse$|fact-checker|lead-intelligence|landing-report|content-engine)"),
    ("data",          r"(data-|xls|clickhouse|postgres|mysql|prisma|jpa-|database|sql-pattern|clean-data|datapack|dashboard-builder|nav-tieout|roll-forward|regex-vs-llm)"),
    ("docs",          r"(doc-|writing-|pptx|pdf|book|copywrit|humaniz|non-fiction|pptx-author|xlsx-|make-pdf|notebooklm|guizang-ppt|client-report|pitch-deck|deck-refresh|document-generate|document-release|edit-article|process-letter|teaser|to-issues|to-prd|^spec$|nutrient-document|ppt-template|ralphinho-rfc|^client-review$)"),
    ("mobile",        r"(ios-|android|swift-|flutter|kotlin|harmonyos|arkts|watchos|tvos|ipados|visionos|macos-design|foundation-models-on-device|mobile-application-management)"),
    ("agentops",      r"(agent-|skill-|^loop-|^loop$|orchestrat|harness|swarm|council|hook|memory|capability|mcp-builder|context-|continuous-learning|subagent|team-builder|autonomous|agentic|cost-tracking|token-budget|benchmark-model|caveman|sync-|instinct-|gsd-list|dispatching-parallel|claude-devfleet|^codex$|^gstack$|gstack-|kb-pipeline|pair-agent|parallel-execution|cost-aware-llm|^ai-first-engineering$|^ai-readiness$|^benchmark$|^skillify$|^skills$|write-a-skill|using-superpowers|^canary$|^guard$|^freeze$|^unfreeze$|^health$|^versions$|^contribute$|configure-ecc|^ecc$|ecc-tools|model-update|improve-codebase|^benchmark-models$|^kb$|^autoplan$|code-tour|\.md$|\.toml$|^qa-only$|^setup$|verification-loop|^hatch-pet$)"),
    ("devops",        r"(build-|deploy-|docker-pattern|terraform|ci-cd|pm2|^setup-|migrat|github-ops|netmiko|land-and-deploy|git-guardrails|finishing-a-development|deployment-patterns|using-git-worktrees|validated-build|verification-before|systematic-debug|^diagnose$|^error-handling$|latency-critical|production-audit|^performance$|^ship$|^review$|^triage$|^investigate$|^retro$|executing-plans|requesting-code-review|receiving-code-review|request-refactor-plan|^record-demo$|plankton-code-quality|api-connector-builder|^template$|terminal-ops|^learn$|content-hash-cache|^break-trace$|^connect-chrome$|^connections-optimizer$|^cso$|^office-hours$|^workspace-surface-audit$|^ax-audit$|^automation-audit-ops$|^devex-review$|thesis-tracker|recursive-decision-ledger|scaffold-exercises|^plan-ceo|^plan-devex|^plan-eng|^plan-tune$|^dd-checklist$|^dd-meeting-prep$|project-flow|project-builder|research-ops|^strategic-compact$)"),
    ("testing",       r"(test-|tdd|e2e-|webapp-testing|regression|eval-|playwright-generate|playwright-explore|playwright-recording|browser-testing|benchmark-optim|^qa$)"),
    ("comms",         r"(email-ops|messages-ops|slack|notification|chief-of-staff|crosspost|x-api|google-workspace-ops|knowledge-ops|obsidian-vault|social-graph|lead-intelligence|investor-outreach|investor-materials|investment-proposal|^handoff$|grill-me|grill-with-docs|^idea-generation$|brainstorming|best-practices|^impeccable$|cheat-on-content|prompt-master|prompt-optimizer|enhance-prompt|qwen-edit|quill-context|^careful$|asset-manager|jira-integration|^blueprint$|marketing-agent)"),
]
def domains_for(sid, desc):
    hay = sid.lower()  # id only — ids here are highly descriptive; desc adds verb noise
    hits = [d for d, pat in DOMAIN_RULES if re.search(pat, hay)]
    return hits[:2] if hits else ["misc"]

def stars_norm(s):
    return (math.log10(s + 1) / STARS_CEIL_LOG) if s else 0.0

def effectiveness(stars, rating, parity_warn, usage_norm=0.0,
                  success_rate=None, runs=0, archived=False, fresh=0.7):
    """Effectiveness score 0-100 — QUALITY-led, not popularity.
    Goal: best product outcome per token. quality(rating) dominates; stars demoted
    to weak proof. proven uses real success-rate once runs accrue, else stars proxy.
    Token-efficiency + project-fit + right-sizing are applied at SELECTION time
    (see REGISTRY.md Selection Policy), not bakeable into a context-free number."""
    quality = (rating or 3) / 5            # real output quality (my judgement)
    reach = stars_norm(stars)              # community proof — weak signal
    proven = success_rate if (runs >= 3 and success_rate is not None) else reach
    val = round(100 * (0.42 * quality + 0.25 * proven + 0.18 * reach
                       + 0.10 * usage_norm + 0.05 * fresh))
    if parity_warn:
        val -= 10
    if archived:
        val -= 30
    return max(0, val)

COST_HEAVY = re.compile(
    r"(deep-research|full-scope|end-to-end|comprehensive|engagement|pipeline|playbook|"
    r"tabletop|workstream|multi-file|swarm|orchestrat|harness|autonomous|dispatching-parallel|"
    r"council|board|spawn|subagent|multi-agent|conducting-full|executing-red-team|"
    r"performing-purple-team|building-soc|building-incident|building-threat-intelligence|"
    r"implementing-zero-trust|performing-cloud-penetration|firecrawl-agent|firecrawl-crawl|"
    r"firecrawl-deep|3-statement|lbo-model|dcf-model|merger-model|non-fiction-book|"
    r"manim-video|remotion-video|gsd-ultraplan|gsd-workstream|gsd-autonomous|agent-harness|agent-sort)")
COST_LIGHT = re.compile(
    r"(lint|format|prettier|eslint|stylelint|tsc-check|^versions$|^health$|^freeze$|^unfreeze$|"
    r"^canary$|^guard$|caveman|token-budget|cost-report|cost-tracking|fact-checker|best-practices|"
    r"code-simplifier|refactor-cleaner|code-tour|screenshot|^scrape$|^browse$|search-first|"
    r"lookup|quick|single|guideline|checklist|^template$|^spec$|^learn$|regex-vs-llm|"
    r"nodejs-keccak256|evm-token-decimals|gsd-note|gsd-quick|gsd-stats|gsd-progress|gsd-next|"
    r"^retro$|^handoff$|^ship$)")
def cost_tier(sid, typ, purpose):
    """Token/effort footprint of RUNNING the skill (for right-sizing)."""
    hay = (sid + " " + (purpose or "")).lower()
    if COST_HEAVY.search(hay):
        return "heavy"
    if COST_LIGHT.search(hay):
        return "light"
    return "medium"

def freshness(pushed, archived):
    """0-1 maintenance signal from upstream push date (sync_stars). Unknown -> 0.7."""
    if archived:
        return 0.0
    if not pushed:
        return 0.7
    try:
        days = (datetime.now(timezone.utc) - datetime.fromisoformat(pushed.replace("Z", "+00:00"))).days
    except Exception:
        return 0.7
    return 1.0 if days < 180 else 0.7 if days < 365 else 0.4 if days < 730 else 0.2

# ---------- enumerate ----------
claude_skills = list_dirs(f"{CLA}/skills")
codex_skills = list_dirs(f"{COD}/skills")
claude_agents = list_dirs(f"{CLA}/agents")
codex_agents = list_dirs(f"{COD}/agents")

records = []

def build(sid, kind, base_claude, base_codex, in_claude, in_codex):
    lk = lock.get(sid, {})
    repo = norm_repo(lk.get("sourceUrl")) if lk.get("sourceUrl") else None
    stars = stars_by_repo.get(repo) if repo else None
    cd = cache_get(lk.get("sourceUrl") or "")
    pushed = checked = None
    archived = False
    if cd:
        if cd.get("stars") is not None:
            stars = cd["stars"]
        pushed, checked, archived = cd.get("pushed"), cd.get("checked_at"), cd.get("archived", False)
    # description from claude copy preferred
    path = None
    if kind == "skill":
        p1 = f"{CLA}/skills/{sid}/SKILL.md"
        p2 = f"{COD}/skills/{sid}/SKILL.md"
        path = p1 if os.path.exists(p1) else (p2 if os.path.exists(p2) else None)
    else:
        p1 = f"{CLA}/agents/{sid}"
        p2 = f"{COD}/agents/{sid}"
        path = p1 if os.path.exists(p1) else (p2 if os.path.exists(p2) else None)
    _, desc = parse_frontmatter(path) if path else (None, "")
    ov = overrides.get(sid, {})
    parity_warn = not (in_claude and in_codex)
    rating = ov.get("rating")
    doms = ov.get("domains") or domains_for(sid, desc)
    uc = usage_count_map.get(sid, 0)
    un = uc / MAXUSE
    rec = {
        "id": sid,
        "type": ov.get("type", kind),
        "purpose": ov.get("purpose") or (desc[:120] if desc else ""),
        "use_when": ov.get("use_when") or desc[:160],
        "domains": doms,
        "projects": ov.get("projects", ["any"]),
        "model": ov.get("model", "S"),
        "harness": {"claude": "installed" if in_claude else "missing",
                     "codex": "installed" if in_codex else "missing"},
        "parity": "synced" if in_claude and in_codex else ("claude-only" if in_claude else "codex-only"),
        "source": lk.get("source"),
        "repo_url": (f"https://github.com/{lk['source']}" if lk.get("source") else None),
        "local_path": lk.get("skillPath"),
        "installed_at": (lk.get("installedAt") or "")[:10] or None,
        "updated_at_local": (lk.get("updatedAt") or "")[:10] or None,
        "stars": stars,
        "repo_pushed_at": pushed,
        "stars_checked_at": checked,
        "usage_count": uc,
        "usage_30d": usage30_map.get(sid, 0),
        "last_used_at": last_map.get(sid),
        "success_runs": 0,
        "rating": rating,
        "status": "stale" if archived else "active",
        "health": "unknown",
        "cost_tier": cost_tier(sid, ov.get("type", kind), ov.get("purpose") or desc),
        "score": effectiveness(stars, rating, parity_warn, un, None, uc, archived,
                               freshness(pushed, archived)),
    }
    records.append(rec)

for sid in sorted(claude_skills | codex_skills):
    if sid.startswith("."):
        continue
    build(sid, "skill", claude_skills, codex_skills, sid in claude_skills, sid in codex_skills)

for sid in sorted(claude_agents | codex_agents):
    if sid.startswith("."):
        continue
    build(sid, "agent", claude_agents, codex_agents, sid in claude_agents, sid in codex_agents)

# plugin caveman: installed on Claude as plugin (active). Upsert -> claude installed.
if os.path.isdir(f"{CLA}/plugins/cache/caveman"):
    cav = next((r for r in records if r["id"] == "caveman"), None)
    codex_has = "caveman" in codex_skills or os.path.isdir(f"{COD}/skills/caveman")
    cav_un = usage_count_map.get("caveman", 0) / MAXUSE
    if cav:
        cav["type"] = "plugin"
        cav["harness"] = {"claude": "installed", "codex": "installed" if codex_has else "partial"}
        cav["parity"] = "synced" if codex_has else "claude-primary"
        cav["cost_tier"] = "light"
        cav["score"] = effectiveness(cav.get("stars"), cav.get("rating"), not codex_has, cav_un)
    else:
        ov = overrides.get("caveman", {})
        records.append({
            "id": "caveman", "type": "plugin",
            "purpose": ov.get("purpose", "Terse inter-agent/user comms, token save"),
            "use_when": ov.get("use_when", "be brief, caveman mode, less tokens"),
            "domains": ov.get("domains", ["comms"]), "projects": ["any"],
            "model": ov.get("model", "H"),
            "harness": {"claude": "installed", "codex": "installed" if codex_has else "partial"},
            "parity": "synced" if codex_has else "claude-primary",
            "source": "plugin-marketplace", "repo_url": None, "local_path": None,
            "installed_at": None, "updated_at_local": None,
            "stars": None, "repo_pushed_at": None, "stars_checked_at": None,
            "usage_count": usage_count_map.get("caveman", 0),
            "usage_30d": usage30_map.get("caveman", 0),
            "last_used_at": last_map.get("caveman"), "success_runs": 0,
            "rating": ov.get("rating", 5), "status": "active", "health": "ok",
            "cost_tier": "light",
            "score": effectiveness(None, ov.get("rating", 5), not codex_has, cav_un),
        })

# ---------- write ----------
with open(OUT, "w", encoding="utf-8") as f:
    for r in sorted(records, key=lambda x: (-x["score"], x["id"])):
        f.write(json.dumps(r, ensure_ascii=False) + "\n")

# ---------- report ----------
from collections import Counter
dc = Counter(d for r in records for d in r["domains"])
tc = Counter(r["type"] for r in records)
withstars = sum(1 for r in records if r["stars"])
print(f"records: {len(records)}  types: {dict(tc)}")
print(f"with stars: {withstars}  with usage: 0 (reset)")
print("top domains:", dict(dc.most_common(12)))
print("sample top-5 by score:")
for r in sorted(records, key=lambda x: -x["score"])[:5]:
    print(f"  {r['score']:>3} {r['id']:32} ★{r['stars']} dom={r['domains']}")
