# Feature specifications

One file per user-visible feature of the test framework, describing its
current behaviour. Its users are test authors and the scripts that read its
output. Update the spec with every change to that behaviour.

| Spec | Covers |
|---|---|
| [running.md](running.md) | `run_tests.sh`, the tests folder setting, running tests in parallel, running one test through `runner.gd`, importing, hung tests, exit codes, the output lines, the self-tests |
| [editor.md](editor.md) | The editor plugin's Tests main screen: listing, filtering, running and stopping tests, results and output |
| [steps.md](steps.md) | `spec()`, `describe` bodies and `it`, misplaced calls, hooks and their order, `STEP` paths, tests without steps, `run()` tests |
| [checks.md](checks.md) | `check()`, `expect` / `expect_within` / `expect_throughout`, `all_of` / `each_of`, messages, unchecked assertions, pages |

Each spec has a short summary, behaviour sections with concrete numbers, a
Controls table when the feature has input, and the main Code and Tests files.
