#!/usr/bin/env python3
"""Offline checks for overload-constraint ownership triage."""
import unittest
from audit_overload_constraints import classify


class ConstraintAuditTest(unittest.TestCase):
    def setUp(self):
        self.ddox = [
            {"module":"geodesy.test", "symbol":"foo","overload":"1",
             "signature":"int foo(int x);"},
            {"module":"geodesy.test", "symbol":"foo","overload":"2",
             "signature":"int foo(double x);"},
        ]
        self.functions = [
            {"module":"geodesy.test","symbol":"foo","kind":"function","line":"10",
             "parameters":'[{"type":"int","name":"x"}]'},
            {"module":"geodesy.test","symbol":"foo","kind":"function","line":"20",
             "parameters":'[{"type":"double","name":"x"}]'},
        ]

    def test_same_line_template_constraint_candidate(self):
        wrappers = [{"module":"geodesy.test","symbol":"foo","kind":"template",
                     "line":"20","constraint":"is(T == double)"}]
        result = classify(self.ddox, self.functions + wrappers)
        self.assertEqual(result[0]["status"], "template_wrapper_ownership_unresolved")
        self.assertEqual(result[1]["status"], "wrapper_line_pair_constraint_available")
        self.assertEqual(result[1]["dmd_constraint"], "is(T == double)")

    def test_distinct_line_remains_unresolved(self):
        wrappers = [{"module":"geodesy.test","symbol":"foo","kind":"template",
                     "line":"19","constraint":"is(T == double)"}]
        result = classify(self.ddox, self.functions + wrappers)
        self.assertTrue(all(r["status"] == "template_wrapper_ownership_unresolved"
                            for r in result))


if __name__ == "__main__":
    unittest.main()
