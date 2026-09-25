#!/bin/bash
# Builds the throwaway HOME the README recordings run in: a small git project,
# an "agent" that edits three files from outside the editor, and a stand-in for
# the claude CLI so the recordings never call a real one.
set -euo pipefail

D=/tmp/volley-demo
rm -rf "$D"
mkdir -p "$D/app/src" "$D/bin" "$D/steps"

cat >"$D/app/src/billing.py" <<'EOF'
from decimal import Decimal

TAX_RATE = Decimal("0.2")


def subtotal(items):
    return sum(item.price for item in items)


def tax(amount):
    return amount * TAX_RATE


def total(items):
    net = subtotal(items)
    return net + tax(net)
EOF

cat >"$D/app/src/routes.py" <<'EOF'
from flask import Blueprint, request

from .billing import total

bp = Blueprint("checkout", __name__)


@bp.post("/checkout")
def checkout():
    items = request.json["items"]
    return {"total": str(total(items))}
EOF

cat >"$D/app/README.md" <<'EOF'
# checkout

A small billing service.
EOF

git -C "$D/app" init -q -b main
git -C "$D/app" add -A
git -C "$D/app" -c user.name=demo -c user.email=demo@example.com commit -q -m "init"

# What the agent leaves behind: discounts in billing, a code on the route, and
# a new settings file. These live outside the project, or they would show up
# in the review as files of their own.
cat >"$D/steps/billing.py" <<'EOF'
from decimal import Decimal

TAX_RATE = Decimal("0.2")


def subtotal(items):
    return sum(item.price for item in items)


def tax(amount):
    return amount * TAX_RATE


def discount(amount, code):
    if code == "WELCOME":
        return amount * Decimal("0.1")
    return Decimal(0)


def total(items, code=None):
    """Net + tax, minus any discount."""
    net = subtotal(items) - discount(subtotal(items), code)
    return net + tax(net)
EOF

cat >"$D/steps/routes.py" <<'EOF'
from flask import Blueprint, request

from .billing import total

bp = Blueprint("checkout", __name__)


@bp.post("/checkout")
def checkout():
    items = request.json["items"]
    code = request.json.get("discount_code")
    return {"total": str(total(items, code))}
EOF

cat >"$D/steps/settings.py" <<'EOF'
DISCOUNT_CODES = {"WELCOME": "0.1"}
EOF


# Stands in for `claude --continue --print`. Prints what the real CLI prints.
cat >"$D/bin/claude-demo" <<'EOF'
#!/bin/sh
sleep 2
cat <<'JSON'
{"result":"1. src/billing.py:16  the 0.1 was a placeholder. It now reads DISCOUNT_CODES from src/settings.py.\n\n2. src/routes.py:11  added two tests, one for a missing code and one for a code nobody knows. Both pass.\n\nWant the VAT case as well?","session_id":"demo","total_cost_usd":0.041}
JSON
EOF
chmod +x "$D/bin/claude-demo"
