"""Ansible callback plugin providing a short summary of skipped tasks.

This implements a small subset of behaviour expected by the CI pipeline
which references the historic ``skippy`` plugin.  The implementation keeps
track of the names of skipped tasks during the playbook run and prints a
concise summary at the end.  The plugin is intentionally lightweight so
that it can run in environments where the original plugin is unavailable.
"""

from __future__ import annotations

from ansible.plugins.callback import CallbackBase


class CallbackModule(CallbackBase):
    """Collect skipped tasks and report them at the end of the playbook."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "skippy"
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self) -> None:
        super().__init__()
        self._skipped_tasks: list[str] = []

    def v2_runner_on_skipped(self, result) -> None:  # type: ignore[override]
        """Record the name of tasks skipped during execution."""

        task_name = result._task.get_name()  # pylint: disable=protected-access
        if task_name:
            self._skipped_tasks.append(task_name)

    def v2_playbook_on_stats(self, stats) -> None:  # type: ignore[override]
        """Display a summary of skipped tasks at the end of the playbook."""

        if not self._skipped_tasks:
            return

        self._display.banner("Skipped tasks")
        for task in self._skipped_tasks:
            self._display.display(f"- {task}")
