# Checks

A test acts and checks through pages. The test says what it intends, and the
page's check says what it saw, so a failure reads as a sentence:
`FAIL Expected to <intent>, but <what was seen>`. Checks can be looked at on
one frame or over many.

## Assertions

- A page's check (`should_...()`) returns a `RTAssertion` made with
  `_assert(probe)`. The probe returns `""` while the check holds, else what
  was seen, with actual values (`"the player had 470 wood"`).
- A check does its actions and takes its baselines when it's called. Only
  the probe runs again, on every frame it's looked at, so a check that acts
  acts once however long it's polled.

## Expect calls

| Call | Passes when | Printed |
|---|---|---|
| `expect(intent, a)` | `a` holds now | `PASS Expected to <intent>` / `FAIL Expected to <intent>, but <seen>` |
| `await expect_within(s, intent, a)` | `a` holds on some frame within `s` game seconds | `PASS Expected within <s> s to <intent>` / `FAIL Expected within <s> s to <intent>, but <seen>` |
| `await expect_throughout(s, intent, a)` | `a` holds on every frame for `s` game seconds | `PASS Expected to <intent> for <s> s` / `FAIL Expected to <intent> for <s> s, but after <t> s <seen>` |

- Seconds are game seconds at 60 frames each, and print as the float that
  was passed (`1.0 s`, `0.25 s`).
- `expect_within` looks first on the frame it's called, and passes on the
  first frame the assertion holds; on failure `<seen>` is from the last
  frame.
- `expect_throughout` fails on the first frame the assertion stops holding.
  `<t>` is the game time by then, with two decimals (`after 0.25 s`).

## Combining

- `all_of(a, b, ...)` is one assertion of several. It holds when all of them
  hold, and reports what the first failing part saw.
- `each_of(items, func(x): return x.should_...())` makes one assertion per
  item, as one `all_of`.
- The parts count as checked once they're combined; the combined assertion
  still has to reach an expect call.

## Unchecked assertions

Every assertion made through `_assert()` or `all_of()` is tracked. One that
never reaches an expect call fails the step or hook it was made in, once that
ends:

- `FAIL every check is passed to an expect call (one wasn't: <seen>)` when it
  didn't hold, or `(one wasn't)` when it did.
- A test that overrides `run()` gets these failures when it ends.

## Plain checks

`check(description, condition)` prints `PASS <description>` or
`FAIL <description>` and counts it. It is meant for checks of how the game is
put together (scene wiring, components, data) and for `run()` tests.

## Pages

- A page extends `RTPage`, is made with the test (`Page.new(self)`) and
  reaches it as `t`, an `RTTest`.
- Checks start with `should_` and return `_assert(...)`. Actions and queries
  are plain methods.
- A probe doesn't call `should_` checks; those would be tracked and never
  checked.

## Code

- `src/expect.gd` (`RTExpect`): the expect calls, `all_of()`, tracking unchecked
  assertions
- `src/assertion.gd` (`RTAssertion`): an assertion and its probe
- `src/page.gd` (`RTPage`): the base of a page, `_assert()`
- `src/base_test.gd` (`RTTest`): `check()`, `expect()`, `expect_within()`,
  `expect_throughout()`, `all_of()`, `each_of()`

## Tests

- `tests/expect_messages.gd`
- `tests/expect_waiting.gd`
- `tests/expect_unused.gd`, `tests/expect_unused_run.gd`
- `tests/page_checks.gd`
