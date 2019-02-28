This test run only works with a [specific experimental
branch](https://github.com/Xalgorithms/lib-rules-int-scala/tree/refine.add.take.last)
of the rules interpreter that _accumulates_ row data during refinement, allowing
the interpreter to evaluate `TAKE` refinement functions like `last()`.
