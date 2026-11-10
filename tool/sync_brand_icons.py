"""Download SVGL brand logos used by Auth No Ads and write brand_catalog.dart."""

from __future__ import annotations

import json
import re
import ssl
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "brands"
CATALOG_PATH = Path(
    r"C:\Users\PC\.cursor\projects\c-Users-PC-Downloads-abdelrahman-gasser-projects-playground-my-authenticator-app\agent-tools\68e6e311-7641-44bc-b9ff-9e6b004572a7.txt"
)
DART_OUT = ROOT / "lib" / "core" / "brand_catalog.dart"

# Exact SVGL titles plus issuer aliases people actually scan.
BRANDS = [
    ("github", "GitHub", 0xFF24292F, "G", ["github"]),
    ("gitlab", "GitLab", 0xFFFC6D26, "G", ["gitlab"]),
    ("google", "Google", 0xFF4285F4, "G", ["google"]),
    ("gmail", "Gmail", 0xFFEA4335, "G", ["gmail"]),
    ("google-drive", "Google Drive", 0xFF4285F4, "D", ["google drive", "drive.google"]),
    ("google-cloud", "Google Cloud", 0xFF4285F4, "C", ["google cloud", "gcp"]),
    ("google-calendar", "Google Calendar", 0xFF4285F4, "C", ["google calendar"]),
    ("google-meet", "Google Meet", 0xFF00897B, "M", ["google meet"]),
    ("google-analytics", "Google Analytics", 0xFFF9AB00, "A", ["google analytics"]),
    ("youtube", "YouTube", 0xFFFF0000, "Y", ["youtube"]),
    ("aws", "Amazon Web Services", 0xFFFF9900, "A", ["amazon web services", "amazonaws", "aws"]),
    ("amazon", "Amazon Web Services", 0xFFFF9900, "A", ["amazon"]),
    ("microsoft", "Microsoft", 0xFF00A4EF, "M", ["microsoft"]),
    ("outlook", "Microsoft Outlook", 0xFF0078D4, "O", ["microsoft outlook", "outlook", "hotmail", "live.com"]),
    ("azure", "Microsoft Azure", 0xFF0078D4, "A", ["microsoft azure", "azure"]),
    ("teams", "Microsoft Teams", 0xFF6264A7, "T", ["microsoft teams", "teams"]),
    ("onedrive", "Microsoft OneDrive", 0xFF0078D4, "O", ["microsoft onedrive", "onedrive"]),
    ("excel", "Microsoft Excel", 0xFF217346, "X", ["microsoft excel", "excel"]),
    ("word", "Microsoft Word", 0xFF2B579A, "W", ["microsoft word"]),
    ("powerpoint", "Microsoft PowerPoint", 0xFFD24726, "P", ["microsoft powerpoint", "powerpoint"]),
    ("office", "Microsoft Office", 0xFFD83B01, "O", ["office 365", "microsoft 365", "office"]),
    ("apple", "Apple", 0xFF111111, "A", ["apple", "icloud", "appleid"]),
    ("apple-music", "Apple Music", 0xFFFA243C, "M", ["apple music"]),
    ("discord", "Discord", 0xFF5865F2, "D", ["discord"]),
    ("facebook", "Facebook", 0xFF1877F2, "f", ["facebook", "meta"]),
    ("instagram", "Instagram", 0xFFE4405F, "I", ["instagram"]),
    ("twitter", "Twitter", 0xFF1DA1F2, "X", ["twitter"]),
    ("x", "X (formerly Twitter)", 0xFF111111, "X", ["x.com"]),
    ("linkedin", "LinkedIn", 0xFF0A66C6, "in", ["linkedin"]),
    ("telegram", "Telegram", 0xFF26A5E4, "T", ["telegram"]),
    ("whatsapp", "WhatsApp", 0xFF25D366, "W", ["whatsapp"]),
    ("spotify", "Spotify", 0xFF1DB954, "S", ["spotify"]),
    ("netflix", "Netflix", 0xFFE50914, "N", ["netflix"]),
    ("paypal", "PayPal", 0xFF003087, "P", ["paypal"]),
    ("coinbase", "Coinbase", 0xFF0052FF, "C", ["coinbase"]),
    ("binance", "Binance", 0xFFF0B90B, "B", ["binance"]),
    ("authy", "Authy", 0xFFEC1C24, "A", ["authy"]),
    ("auth0", "Auth0", 0xFFEB5424, "A", ["auth0"]),
    ("railway", "Railway", 0xFF0B0D0E, "R", ["railway"]),
    ("twitch", "Twitch", 0xFF9146FF, "T", ["twitch"]),
    ("godaddy", "GoDaddy", 0xFF1BDBDB, "G", ["godaddy"]),
    ("docker", "Docker", 0xFF2496ED, "D", ["docker"]),
    ("atlassian", "Atlassian", 0xFF0052CC, "A", ["atlassian", "jira", "confluence", "bitbucket"]),
    ("figma", "Figma", 0xFFF24E1E, "F", ["figma"]),
    ("notion", "Notion", 0xFF111111, "N", ["notion"]),
    ("slack", "Slack", 0xFF4A154B, "S", ["slack"]),
    ("dropbox", "Dropbox", 0xFF0061FF, "D", ["dropbox"]),
    ("vercel", "Vercel", 0xFF000000, "V", ["vercel"]),
    ("netlify", "Netlify", 0xFF00C7B7, "N", ["netlify"]),
    ("digitalocean", "Digital Ocean", 0xFF0080FF, "D", ["digitalocean", "digital ocean"]),
    ("cloudflare", "Cloudflare", 0xFFF38020, "C", ["cloudflare"]),
    ("npm", "NPM", 0xFFCB3837, "n", ["npm"]),
    ("stripe", "Stripe", 0xFF635BFF, "S", ["stripe"]),
    ("shopify", "Shopify", 0xFF96BF48, "S", ["shopify"]),
    ("wordpress", "WordPress", 0xFF21759B, "W", ["wordpress"]),
    ("zoom", "Zoom", 0xFF2D8CFF, "Z", ["zoom"]),
    ("adobe", "Adobe", 0xFFEB1000, "A", ["adobe"]),
    ("keycloak", "Keycloak", 0xFFE0E0E0, "K", ["keycloak"]),
    ("clerk", "Clerk", 0xFF6C47FF, "C", ["clerk"]),
    ("proton-mail", "Proton Mail", 0xFF6D4AFF, "P", ["protonmail", "proton mail", "proton.me"]),
    ("proton-vpn", "Proton VPN", 0xFF6D4AFF, "P", ["protonvpn", "proton vpn"]),
    ("steam", "Steam", 0xFF171A21, "S", ["steam"]),
    ("openai", "OpenAI", 0xFF10A37F, "O", ["openai", "chatgpt", "chat.openai"]),
    ("cursor", "Cursor", 0xFF000000, "C", ["cursor"]),
    ("reddit", "Reddit", 0xFFFF4500, "R", ["reddit"]),
    ("snapchat", "Snapchat", 0xFFFFFC00, "S", ["snapchat"]),
    ("tiktok", "TikTok", 0xFF010101, "T", ["tiktok"]),
    ("pinterest", "Pinterest", 0xFFE60023, "P", ["pinterest"]),
    ("threads", "Threads", 0xFF000000, "T", ["threads"]),
    ("bluesky", "Bluesky", 0xFF1185FE, "B", ["bluesky", "bsky"]),
    ("mastodon", "Mastodon", 0xFF6364FF, "M", ["mastodon"]),
    ("playstation", "PlayStation", 0xFF003791, "P", ["playstation", "psn", "sony"]),
    ("epic", "Epic Games", 0xFF000000, "E", ["epic games", "epicgames", "fortnite"]),
    ("unity", "Unity", 0xFF111111, "U", ["unity"]),
    ("trello", "Trello", 0xFF0052CC, "T", ["trello"]),
    ("clickup", "ClickUp", 0xFF7B68EE, "C", ["clickup"]),
    ("linear", "Linear", 0xFF5E6AD2, "L", ["linear"]),
    ("asana", "Asana", 0xFFF06A6A, "A", ["asana"]),
    ("todoist", "Todoist", 0xFFE44332, "T", ["todoist"]),
    ("canva", "Canva", 0xFF00C4CC, "C", ["canva"]),
    ("webflow", "Webflow", 0xFF4353FF, "W", ["webflow"]),
    ("patreon", "Patreon", 0xFFFF424D, "P", ["patreon"]),
    ("salesforce", "Salesforce", 0xFF00A1E0, "S", ["salesforce"]),
    ("twilio", "Twilio", 0xFFF22F46, "T", ["twilio"]),
    ("postman", "Postman", 0xFFFF6C37, "P", ["postman"]),
    ("mongodb", "MongoDB", 0xFF47A248, "M", ["mongodb"]),
    ("redis", "Redis", 0xFFDC382D, "R", ["redis"]),
    ("postgres", "PostgreSQL", 0xFF4169E1, "P", ["postgres", "postgresql"]),
    ("mysql", "MySQL", 0xFF4479A1, "M", ["mysql"]),
    ("firebase", "Firebase", 0xFFFFCA28, "F", ["firebase"]),
    ("supabase", "Supabase", 0xFF3ECF8E, "S", ["supabase"]),
    ("planetscale", "PlanetScale", 0xFF111111, "P", ["planetscale"]),
    ("render", "Render", 0xFF000000, "R", ["render.com", "render"]),
    ("fly", "Fly", 0xFF7C3AED, "F", ["fly.io", "flyio"]),
    ("heroku", "Heroku", 0xFF430098, "H", ["heroku"]),
    ("bitwarden", "Bitwarden", 0xFF175DDC, "B", ["bitwarden"]),
    ("onepassword", "1Password", 0xFF1A67F4, "1", ["1password", "onepassword"]),
    ("workos", "WorkOS", 0xFF6366F1, "W", ["workos"]),
    ("android", "Android", 0xFF3DDC84, "A", ["android"]),
    ("ibm", "IBM", 0xFF0F62FE, "I", ["ibm"]),
    ("ebay", "Ebay", 0xFFE53238, "e", ["ebay"]),
    ("opensea", "OpenSea", 0xFF2081E2, "O", ["opensea"]),
    ("gemini", "Gemini", 0xFF8E74E8, "G", ["gemini"]),
    ("anthropic", "Anthropic", 0xFF111111, "A", ["anthropic"]),
    ("claude", "Claude AI", 0xFFD97757, "C", ["claude"]),
    ("deepseek", "DeepSeek", 0xFF4D6BFE, "D", ["deepseek"]),
    ("replit", "Replit", 0xFFF26207, "R", ["replit"]),
    ("n8n", "n8n", 0xFFEA4B71, "n", ["n8n"]),
    ("soundcloud", "SoundCloud", 0xFFFF5500, "S", ["soundcloud"]),
    ("disney", "Disney+", 0xFF113CCF, "D", ["disney"]),
    ("vscode", "Visual Studio Code", 0xFF007ACC, "V", ["visual studio code", "vscode"]),
    ("git", "Git", 0xFFF05032, "G", ["git"]),
    ("flutter", "Flutter", 0xFF02569B, "F", ["flutter"]),
    ("expo", "Expo", 0xFF000020, "E", ["expo"]),
    ("laravel", "Laravel", 0xFFFF2D20, "L", ["laravel"]),
    ("cpanel", "cPanel", 0xFFFF6C2C, "c", ["cpanel"]),
    ("matrix", "Matrix", 0xFF000000, "M", ["matrix"]),
    ("discourse", "Discourse", 0xFFFF9E00, "D", ["discourse"]),
    ("devto", "Devto", 0xFF0A0A0A, "D", ["dev.to", "devto"]),
    ("firefox", "Firefox", 0xFFFF7139, "F", ["firefox"]),
    ("duckduckgo", "DuckDuckGo", 0xFFDE5833, "D", ["duckduckgo"]),
    ("hashnode", "Hashnode", 0xFF2962FF, "H", ["hashnode"]),
    ("homeassistant", "Home Assistant", 0xFF18BCF2, "H", ["home assistant", "homeassistant"]),
    ("jetbrains", "JetBrains", 0xFF000000, "J", ["jetbrains", "intellij"]),
]


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def route_of(item: dict) -> str | None:
    route = item.get("route")
    if isinstance(route, str):
        return route
    if isinstance(route, dict):
        return route.get("light") or route.get("dark")
    return None


def main() -> None:
    with CATALOG_PATH.open(encoding="utf-8") as f:
        catalog = json.load(f)
    by_title: dict[str, dict] = {}
    for item in catalog:
        title = item.get("title")
        if title and title not in by_title:
            by_title[title] = item

    ASSETS.mkdir(parents=True, exist_ok=True)
    ctx = ssl.create_default_context()
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ctx),
    )
    opener.addheaders = [("User-Agent", "AuthNoAds/1.0 (personal authenticator)")]

    written: list[tuple] = []
    seen_files: set[str] = set()
    for brand_id, title, color, letter, aliases in BRANDS:
        item = by_title.get(title)
        if item is None:
            print(f"skip missing SVGL title: {title}")
            continue
        url = route_of(item)
        if not url:
            print(f"skip no route: {title}")
            continue
        filename = f"{brand_id}.svg"
        dest = ASSETS / filename
        if filename not in seen_files:
            print(f"get {title} <- {url}")
            try:
                with opener.open(url, timeout=30) as resp:
                    data = resp.read()
            except Exception as exc:  # noqa: BLE001
                print(f"  FAIL {exc}")
                continue
            if b"<svg" not in data[:400].lower() and b"<svg" not in data.lower():
                print(f"  not svg ({len(data)} bytes)")
                continue
            dest.write_bytes(data)
            seen_files.add(filename)
        written.append((brand_id, title, color, letter, aliases, filename))

    lines = [
        "// Generated from https://svgl.app — do not edit by hand.",
        "// Re-run: python tool/sync_brand_icons.py",
        "",
        "class BrandDef {",
        "  const BrandDef({",
        "    required this.id,",
        "    required this.color,",
        "    required this.letter,",
        "    required this.asset,",
        "    required this.aliases,",
        "  });",
        "",
        "  final String id;",
        "  final int color;",
        "  final String letter;",
        "  final String asset;",
        "  final List<String> aliases;",
        "}",
        "",
        "const brandCatalog = <BrandDef>[",
    ]
    for brand_id, title, color, letter, aliases, filename in written:
        alias_lit = ", ".join(json.dumps(a) for a in aliases)
        lines.append(
            f"  BrandDef(id: {json.dumps(brand_id)}, color: 0x{color:08X}, "
            f"letter: {json.dumps(letter)}, asset: 'assets/brands/{filename}', "
            f"aliases: [{alias_lit}]),"
        )
    lines.append("];")
    lines.append("")
    DART_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(written)} brands -> {DART_OUT}")


if __name__ == "__main__":
    main()
