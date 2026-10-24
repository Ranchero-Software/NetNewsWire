"""The aggregate runner must execute every platform and propagate its failure."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReaderRunnerTests(unittest.TestCase):
    def run_runner(self, failure):
        with tempfile.TemporaryDirectory(prefix="reader-runner-test-") as directory:
            folder = Path(directory)
            fake = folder / "xcodebuild"
            fake.write_text("""#!/bin/bash
printf '%s\\n' "$*" >> "$READER_TEST_CALLS"
if [[ "$*" == *test-without-building* && "$*" == *"$READER_TEST_FAILURE"* && -n "$READER_TEST_FAILURE" ]]; then
    exit 73
fi
""")
            fake.chmod(0o755)
            log = folder / "calls"
            env = {**os.environ, "READER_XCODEBUILD": str(fake), "READER_RESULTS_DIR": str(folder / "results"),
                   "READER_SKIP_GENERATION": "1", "READER_SKIP_SIGNATURE_CHECK": "1",
                   "READER_IOS_DESTINATION": "platform=iOS Simulator,id=iphone-test",
                   "READER_IPAD_DESTINATION": "platform=iOS Simulator,id=ipad-test",
                   "READER_TEST_CALLS": str(log), "READER_TEST_FAILURE": failure}
            result = subprocess.run(["bash", str(ROOT / "scripts/test-reader.sh"), "all"], env=env,
                                    capture_output=True, text=True, check=False)
            return result, log.read_text()

    def test_all_platforms_really_execute(self):
        result, calls = self.run_runner("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls.count("test-without-building"), 3)
        self.assertIn("iphone-test", calls)
        self.assertIn("ipad-test", calls)
        self.assertIn("Reader-Prüfung erfolgreich", result.stdout)

    def test_ios_failure_stops_and_has_no_success_message(self):
        result, calls = self.run_runner("iphone-test")
        self.assertEqual(result.returncode, 73)
        self.assertNotIn("ipad-test", calls)
        self.assertNotIn("Reader-Prüfung erfolgreich", result.stdout)


if __name__ == "__main__":
    unittest.main()
