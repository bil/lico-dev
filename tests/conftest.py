import os
import sys

import pytest

REPO_DIR = os.path.realpath(f"{os.path.dirname(__file__)}/..")
EXAMPLES_DIR = os.path.realpath(f"{os.path.dirname(__file__)}/../examples")

sys.path.append(REPO_DIR)

def pytest_configure():
    pytest.repor_dir = REPO_DIR
    pytest.examples_dir = EXAMPLES_DIR
