import tempfile
import unittest
from pathlib import Path
import zipfile

from tools.fetch_web_templates import template_ready


class TemplateCacheTests(unittest.TestCase):
    def test_rejects_missing_and_corrupt_templates(self):
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "web_nothreads_release.zip"
            self.assertFalse(template_ready(template))
            template.write_bytes(b"truncated")
            self.assertFalse(template_ready(template))

    def test_accepts_valid_zip_template(self):
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "web_nothreads_release.zip"
            with zipfile.ZipFile(template, "w") as archive:
                archive.writestr("godot.html", b"html")
                archive.writestr("godot.js", b"javascript")
                archive.writestr("godot.wasm", b"webassembly")
            self.assertTrue(template_ready(template))

    def test_rejects_unrelated_and_crc_damaged_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "web_nothreads_release.zip"
            with zipfile.ZipFile(template, "w") as archive:
                archive.writestr("unrelated.txt", b"not a template")
            self.assertFalse(template_ready(template))

            with zipfile.ZipFile(template, "w") as archive:
                archive.writestr("godot.html", b"html")
                archive.writestr("godot.js", b"javascript")
                archive.writestr("godot.wasm", b"webassembly")
            damaged = bytearray(template.read_bytes())
            payload = damaged.find(b"webassembly")
            self.assertGreaterEqual(payload, 0)
            damaged[payload] ^= 0xFF
            template.write_bytes(damaged)
            self.assertFalse(template_ready(template))


if __name__ == "__main__":
    unittest.main()
