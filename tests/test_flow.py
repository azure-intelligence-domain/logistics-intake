"""The flow against its contract: it handles exactly what asyncapi.yaml says it receives, and it
calls only its own domain's System API, through the gateway, as its runtime identity."""

import json
from pathlib import Path

import yaml

ROOT = Path(__file__).parent.parent
FLOW = json.loads((ROOT / "workflow.json").read_text())
CONTRACT = yaml.safe_load((ROOT / "asyncapi.yaml").read_text())


def calls(actions):
    for name, action in actions.items():
        if action["type"] == "Http":
            yield name, action
        for nested in ("actions",):
            if nested in action:
                yield from calls(action[nested])


def test_handles_exactly_what_the_contract_receives():
    received = {c["x-configurations"]["demo"]["eventGrid"]["eventType"] for c in CONTRACT["channels"].values()}
    handled = {case["case"] for case in FLOW["actions"]["Route"]["cases"].values()}
    assert handled == received


def test_calls_only_its_own_system_api_through_the_gateway():
    for case in FLOW["actions"]["Route"]["cases"].values():
        for name, action in calls(case["actions"]):
            inputs = action["inputs"]
            assert inputs["uri"].startswith("@{parameters('gateway')}/3pl/"), name
            assert inputs["authentication"]["type"] == "ManagedServiceIdentity", name
            assert inputs["headers"]["Correlation-Id"], name
            assert inputs["retryPolicy"] == {"type": "none"}, "Event Grid retries the delivery, not the flow"


def test_a_failure_is_a_5xx_so_event_grid_retries():
    failed = FLOW["actions"]["Failed"]
    assert failed["runAfter"] == {"Route": ["Failed", "TimedOut"]} and failed["inputs"]["statusCode"] >= 500
