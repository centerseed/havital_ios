"""Run the real shell runner with isolated fake Xcode/simulator processes."""
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest


class TestRunnerExitTests(unittest.TestCase):
    def run_case(self, output, exit_code):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / "Scripts"
            scripts.mkdir()
            shutil.copyfile(Path(__file__).with_name("test.sh"), scripts / "test.sh")
            wrapper = scripts / "run_xcodebuild.sh"
            wrapper.write_text("#!/bin/bash\nprintf '%s\\n' "+shlex.quote(output)+"\nexit "+str(exit_code)+"\n")
            wrapper.chmod(0o755)
            xcrun = root / "xcrun"
            xcrun.write_text("#!/bin/bash\necho 'Paceriz Tests (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Booted)'\n")
            xcrun.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ["PATH"], PACERIZ_TEST_SIMULATOR="Paceriz Tests")
            return subprocess.run(["bash", str(scripts / "test.sh"), "unit", "--filter", "Fixture", "--verbose"], env=env, text=True, capture_output=True)

    def test_success(self):
        self.assertEqual(self.run_case("Executed 1 tests, with 0 failures", 0).returncode, 0)

    def test_xcode_error_is_not_hidden_by_tee(self):
        self.assertNotEqual(self.run_case("error: compiler failed", 65).returncode, 0)

    def test_singular_failure_cannot_report_success(self):
        result = self.run_case("Executed 1 tests, with 1 failure", 0)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("All Tests Passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
