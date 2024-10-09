# Copyright (c) 2024 Microsoft Corporation.
# Licensed under the MIT License

"""Rich-based progress reporter for CLI use."""

# Print iterations progress
import asyncio
import sys

from datashaper import Progress as DSProgress
from rich.console import Console, Group
from rich.live import Live
from rich.progress import Progress, TaskID, TimeElapsedColumn
from rich.spinner import Spinner
from rich.tree import Tree

from .types import ProgressReporter
import time

# https://stackoverflow.com/a/34325723
class RichProgressReporter(ProgressReporter):
    """A rich-based progress reporter for CLI use."""

    _console: Console
    _group: Group
    _tree: Tree
    _live: Live
    _task: TaskID | None = None
    _prefix: str
    _transient: bool
    _disposing: bool = False
    _progressbar: Progress
    _last_refresh: float = 0
    is_redirected: bool = not sys.stdout.isatty()
    _last_reported_percent: int = 0
    _last_reported_time: float = 0
    def dispose(self) -> None:
        """Dispose of the progress reporter."""
        self._disposing = True
        self._live.stop()

    @property
    def console(self) -> Console:
        """Get the console."""
        return self._console

    @property
    def group(self) -> Group:
        """Get the group."""
        return self._group

    @property
    def tree(self) -> Tree:
        """Get the tree."""
        return self._tree

    @property
    def live(self) -> Live:
        """Get the live."""
        return self._live

    def __init__(
        self,
        prefix: str,
        parent: "RichProgressReporter | None" = None,
        transient: bool = True,
    ) -> None:
        """Create a new rich-based progress reporter."""
        self._prefix = prefix

        if parent is None:
            console = Console()
            group = Group(Spinner("dots", prefix), fit=True)
            tree = Tree(group)
            live = Live(
                tree, console=console, refresh_per_second=1, vertical_overflow="crop"
            )
            live.start()

            self._console = console
            self._group = group
            self._tree = tree
            self._live = live
            self._transient = False
        else:
            self._console = parent.console
            self._group = parent.group
            progress_columns = [*Progress.get_default_columns(), TimeElapsedColumn()]
            self._progressbar = Progress(
                *progress_columns, console=self._console, transient=transient
            )

            tree = Tree(prefix)
            tree.add(self._progressbar)
            tree.hide_root = True

            if parent is not None:
                parent_tree = parent.tree
                parent_tree.hide_root = False
                parent_tree.add(tree)

            self._tree = tree
            self._live = parent.live
            self._transient = transient

        self.refresh()

    def refresh(self) -> None:
        """Perform a debounced refresh."""
        if not self._is_redirected():
            now = asyncio.get_event_loop().time()
            duration = now - self._last_refresh
            if duration > 0.1:
                self._last_refresh = now
                self.force_refresh()

    def force_refresh(self) -> None:
        """Force a refresh."""
        if not self._is_redirected():
            self.live.refresh()

    def stop(self) -> None:
        """Stop the progress reporter."""
        if not self._is_redirected():
            self._live.stop()

    def child(self, prefix: str, transient: bool = True) -> ProgressReporter:
        """Create a child progress bar."""
        return RichProgressReporter(parent=self, prefix=prefix, transient=transient)

    def error(self, message: str) -> None:
        """Report an error."""
        self._print_message(message, "❌", "red")

    def warning(self, message: str) -> None:
        """Report a warning."""
        self._print_message(message, "⚠️", "yellow")

    def success(self, message: str) -> None:
        """Report success."""
        self._print_message(message, "🚀", "green")

    def info(self, message: str) -> None:
        """Report information."""
        self._print_message(message, "ℹ️")

    def __call__(self, progress_update: DSProgress) -> None:
        """Update progress."""
        if self._disposing:
            return

        if self._is_redirected():
            # Simple text-based progress reporting
            completed = progress_update.completed_items or progress_update.percent
            total = progress_update.total_items or 1
            percentage = (completed / total) * 100
            current_percent = int(percentage)
            if self._last_reported_percent == 0:
                self._last_reported_time = time.time()
            if current_percent > self._last_reported_percent:
                remain_time = (time.time() - self._last_reported_time) * (100 - current_percent) / 1 ## this is 1 percent speed
                print(f"{self._prefix}: {percentage:.1f}% completed (remain: {remain_time:.2f} seconds)", flush=True)
                self._last_reported_time = time.time()
                self._last_reported_percent = current_percent
        else:
            # Rich progress reporting (existing code)
            progressbar = self._progressbar
            if self._task is None:
                self._task = progressbar.add_task(self._prefix)
            progress_description = ""
            if progress_update.description is not None:
                progress_description = f" - {progress_update.description}"

            completed = progress_update.completed_items or progress_update.percent
            total = progress_update.total_items or 1
            progressbar.update(
                self._task,
                completed=completed,
                total=total,
                description=f"{self._prefix}{progress_description}",
            )
            if completed == total and self._transient:
                progressbar.update(self._task, visible=False)

            self.refresh()
            
    def _is_redirected(self):
        return self.is_redirected
    
    def _print_message(self, message: str, prefix: str, color: str = "") -> None:
        if self._is_redirected():
            print(f"{prefix} {message}", flush=True)
        else:
            self._console.print(f"{prefix} [{color}]{message}[/{color}]")
