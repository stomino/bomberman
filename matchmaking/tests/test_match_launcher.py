from unittest.mock import MagicMock, patch

import pytest

from matchmaking.match_launcher import MatchLauncher, NoPortsAvailableError


def _make_launcher(start=9000, end=9099):
    return MatchLauncher(
        port_range_start=start,
        port_range_end=end,
        godot_executable="godot",
        godot_project_path=".",
    )


def test_allocate_port_returns_first_in_range():
    launcher = _make_launcher()
    assert launcher.allocate_port() == 9000


def test_allocate_port_does_not_reuse_allocated_ports():
    launcher = _make_launcher()
    first = launcher.allocate_port()
    second = launcher.allocate_port()
    assert first != second


def test_release_port_makes_it_allocatable_again():
    launcher = _make_launcher(start=9000, end=9001)
    port = launcher.allocate_port()
    launcher.release_port(port)
    assert launcher.allocate_port() == port


def test_allocate_port_raises_when_range_exhausted():
    launcher = _make_launcher(start=9000, end=9000)
    launcher.allocate_port()
    with pytest.raises(NoPortsAvailableError):
        launcher.allocate_port()


@patch("matchmaking.match_launcher.subprocess.Popen")
def test_launch_match_builds_expected_command(mock_popen):
    mock_popen.return_value = MagicMock()
    launcher = MatchLauncher(
        port_range_start=9000,
        port_range_end=9099,
        godot_executable="/path/to/godot",
        godot_project_path="/path/to/project",
    )

    launcher.launch_match(9005)

    mock_popen.assert_called_once_with(
        [
            "/path/to/godot",
            "--headless",
            "--path",
            "/path/to/project",
            "scenes/server.tscn",
            "--",
            "--port=9005",
        ]
    )
