"""Optional bundled admin portal works from the repository's web build."""
import pytest
from httpx import ASGITransport, AsyncClient

from app import main


@pytest.mark.asyncio
@pytest.mark.parametrize("bundled", [True, False])
async def test_optional_admin_portal_uses_repository_web_directory(tmp_path, monkeypatch, bundled):
    repository = tmp_path / "stepsy"
    entrypoint = repository / "backend" / "app" / "main.py"
    entrypoint.parent.mkdir(parents=True)
    entrypoint.touch()
    monkeypatch.setattr(main, "__file__", str(entrypoint))

    if bundled:
        web = repository / "web" / "dist"
        (web / "assets").mkdir(parents=True)
        (web / "index.html").write_text("<html>Stepsy admin</html>", encoding="utf-8")
        (web / "assets" / "portal.js").write_text("window.stepsy = true;", encoding="utf-8")

    async with AsyncClient(transport=ASGITransport(app=main.create_app()), base_url="http://test") as client:
        portal = await client.get("/portal/stores")
        asset = await client.get("/assets/portal.js")
        assert portal.status_code == (200 if bundled else 404)
        assert asset.status_code == (200 if bundled else 404)
        if bundled:
            assert "Stepsy admin" in portal.text
            assert asset.text == "window.stepsy = true;"
        assert (await client.get("/health")).status_code == 200
