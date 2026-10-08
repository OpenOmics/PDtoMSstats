# Data directory

`example/` contains a small, de-identified dataset that is deliberately tracked
so the complete MSstats and time-course workflow can be tested.

Put private project inputs in another subdirectory under `data/`. Git ignores
those files by default. Never change `.gitignore` to track identifiable sample
metadata, raw project workbooks, or generated analysis outputs.
