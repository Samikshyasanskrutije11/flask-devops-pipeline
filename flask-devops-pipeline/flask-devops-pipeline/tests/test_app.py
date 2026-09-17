import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))

from app import create_app  # noqa: E402


@pytest.fixture()
def client():
    flask_app = create_app()
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as c:
        yield c


def test_index_returns_html(client):
    res = client.get("/")
    assert res.status_code == 200
    assert b"Flask DevOps Pipeline" in res.data


def test_health_is_healthy(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "healthy"


def test_info_contains_expected_keys(client):
    body = client.get("/api/info").get_json()
    for key in ("app", "version", "environment", "hostname", "python"):
        assert key in body


def test_unknown_route_returns_404_json(client):
    res = client.get("/does-not-exist")
    assert res.status_code == 404
    assert res.get_json()["error"] == "not found"
